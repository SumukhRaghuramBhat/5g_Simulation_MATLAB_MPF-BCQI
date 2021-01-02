classdef hNRGNB < hNRNode
%hNRGNB Create a gNB node object that manages the RLC, MAC and Phy layers
%   The class creates a gNB node containing the RLC, MAC and Phy layers of
%   NR protocol stack. Additionally, it models the interaction between
%   those layers through callbacks.

% Copyright 2019-2020 The MathWorks, Inc.

    methods (Access = public)
        function obj = hNRGNB(param)
            %hNRGNB Create a gNB node
            %
            %   OBJ = hNRGNB(PARAM) creates a gNB node containing RLC and MAC.
            %   PARAM is a structure with following fields:
            %       NumUEs                   - Number of UEs in the cell
            %       SCS                      - Subcarrier spacing used
            %       NumHARQ                  - Number of HARQ processes
            %       MaxLogicalChannels       - Maximum number of logical channels that can be configured
            %       Position                 - Position of gNB in (x,y,z) coordinates
            
            % Validate the number of UEs
            validateattributes(param.NumUEs, {'numeric'}, {'nonempty', ...
                'integer', 'scalar', '>', 0, '<=', 65519}, 'param.NumUEs', 'NumUEs');
            % Validate gNB position
            validateattributes(param.Position, {'numeric'}, {'numel', 3, ...
                'nonempty', 'finite', 'nonnan'}, 'param.Position', 'Position');

            % Create the gNB MAC instance
            obj.MACEntity = hNRGNBMAC(param);
            % Initialize RLC entities cell array
            numUEs = param.NumUEs;
            obj.RLCEntities = cell(numUEs, obj.MaxLogicalChannels);
            % Initialize application cell array
            obj.Applications = cell(numUEs * obj.MaxApplications, 1);
            % Register the callback to implement the interaction between
            % MAC and RLC. 'sendRLCPDUs' is the callback to RLC by MAC to
            % get RLC PDUs for the downlink transmissions. 'receiveRLCPDUs'
            % is the callback to RLC by MAC to receive RLC PDUs, for the
            % received uplink packets
            registerRLCInterfaceFcn(obj.MACEntity, @obj.sendRLCPDUs, @obj.receiveRLCPDUs);

            obj.Position = param.Position;
        end

        function configurePhy(obj, configParam)
            %configurePhy Configure the physical layer
            %
            %   configurePhy(OBJ, CONFIGPARAM) sets the physical layer
            %   configuration.
            
            % Validate number of RBs
            validateattributes(configParam.NumRBs, {'numeric'}, {'integer', 'scalar', '>=', 1, '<=', 275}, 'configParam.NumRBs', 'NumRBs');

            if isfield(configParam , 'NCellID')
                % Validate cell ID
                validateattributes(configParam.NCellID, {'numeric'}, {'nonempty', 'integer', 'scalar', '>=', 0, '<=', 1007}, 'configParam.NCellID', 'NCellID');
                cellConfig.NCellID = configParam.NCellID;
            else
                cellConfig.NCellID = 1;
            end
            if isfield(configParam , 'DuplexMode')
                % Validate duplex mode
                validateattributes(configParam.DuplexMode, {'numeric'}, {'nonempty', 'integer', 'scalar', '>=', 0, '<', 2}, 'configParam.DuplexMode', 'DuplexMode');
                cellConfig.DuplexMode = configParam.DuplexMode;
            else
                cellConfig.DuplexMode = 0;
            end
            % Set cell configuration on Phy layer instance
            setCellConfig(obj.PhyEntity, cellConfig);

            % Validate the subcarrier spacing
            if ~ismember(configParam.SCS, [15 30 60 120 240])
                error('nr5g:hNRGNB:InvalidSCS', 'The subcarrier spacing ( %d ) must be one of the set (15, 30, 60, 120, 240).', configParam.SCS);
            end

            carrierInformation.SubcarrierSpacing = configParam.SCS;
            carrierInformation.NRBsDL = configParam.NumRBs;
            carrierInformation.NRBsUL = configParam.NumRBs;
            if isfield(configParam, 'NTxAnts')
                % Validate the number of transmitter antennas
                validateattributes(configParam.NTxAnts, {'numeric'}, {'nonempty', 'integer', 'scalar', 'finite', '>', 0}, 'configParam.NTxAnts', 'NTxAnts');
                carrierInformation.NTxAnts = configParam.NTxAnts;
            else
                carrierInformation.NTxAnts = 1;
            end
            if isfield(configParam, 'NRxAnts')
                % Validate the number of receiver antennas
                validateattributes(configParam.NRxAnts, {'numeric'}, {'nonempty', 'integer', 'scalar', 'finite', '>', 0}, 'configParam.NRxAnts', 'NRxAnts');
                carrierInformation.NRxAnts = configParam.NRxAnts;
            else
                carrierInformation.NRxAnts = 1;
            end

            % Validate the uplink and downlink carrier frequencies
            if isfield(configParam, 'ULCarrierFreq')
                validateattributes(configParam.ULCarrierFreq, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'configParam.ULCarrierFreq', 'ULCarrierFreq');
                carrierInformation.ULFreq = configParam.ULCarrierFreq;
            end
            if isfield(configParam, 'DLCarrierFreq')
                validateattributes(configParam.DLCarrierFreq, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'configParam.DLCarrierFreq', 'DLCarrierFreq');
                carrierInformation.DLFreq = configParam.DLCarrierFreq;
            end
            % Validate uplink and downlink bandwidth
            if isfield(configParam, 'ULBandwidth')
                validateattributes(configParam.ULBandwidth, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'configParam.ULBandwidth', 'ULBandwidth');
                carrierInformation.ULBandwidth = configParam.ULBandwidth;
            end
            if isfield(configParam, 'DLBandwidth')
                validateattributes(configParam.DLBandwidth, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'configParam.DLBandwidth', 'DLBandwidth');
                carrierInformation.DLBandwidth = configParam.DLBandwidth;
            end
            % Set carrier configuration on Phy layer instance
            setCarrierInformation(obj.PhyEntity, carrierInformation);
        end

        function setPhyInterface(obj)
            %setPhyInterface Set the interface to Phy

            phyEntity = obj.PhyEntity;
            macEntity = obj.MACEntity;

            % Register Phy interface functions at MAC for:
            % (1) Sending packets to Phy
            % (2) Sending Rx request to Phy
            % (3) Sending DL-TTI request to Phy
            registerPhyInterfaceFcn(obj.MACEntity, @phyEntity.txDataRequest, ...
                @phyEntity.rxDataRequest, @phyEntity.dlTTIRequest);

            % Register MAC callback function at Phy for sending the packets to MAC
            registerMACInterfaceFcn(obj.PhyEntity, @macEntity.rxIndication);

            % Register callback function on Phy for getting node position
            registerGetPositionFcn(obj.PhyEntity, @obj.getPosition);
        end

        function addScheduler(obj, scheduler)
            %addScheduler Add scheduler object to MAC
            %   addScheduler(OBJ, SCHEDULER) adds scheduler to the MAC
            %
            %   SCHEDULER Scheduler object
            addScheduler(obj.MACEntity, scheduler);
        end
    end
end