classdef hNRUE < hNRNode
%hNRUE Create a UE node object that manages the RLC, MAC and Phy layers
%   The class creates a UE node containing the RLC, MAC and Phy layers of
%   NR protocol stack. Additionally, it models the interaction between
%   those layers through callbacks.

% Copyright 2019-2020 The MathWorks, Inc.

    methods (Access = public)
        function obj = hNRUE(param, rnti)
            %hNRUE Create a UE node
            %
            % OBJ = hNRUE(PARAM, RNTI) creates a UE node containing
            % RLC and MAC.
            % PARAM is a structure including the following fields:
            %
            % SCS                      - Subcarrier spacing
            % DuplexMode               - Duplexing mode: FDD (value 0) or TDD (value 1)
            % BSRPeriodicity           - Periodicity for the BSR packet generation
            % NumRBs                   - Number of RBs in PUSCH and PDSCH bandwidth
            % NumHARQ                  - Number of HARQ processes on UEs
            % DLULPeriodicity          - Duration of the DL-UL pattern in ms (for TDD mode)
            % NumDLSlots               - Number of full DL slots at the start of DL-UL pattern (for TDD mode)
            % NumDLSyms                - Number of DL symbols after full DL slots of DL-UL pattern (for TDD mode)
            % NumULSyms                - Number of UL symbols before full UL slots of DL-UL pattern (for TDD mode)
            % NumULSlots               - Number of full UL slots at the end of DL-UL pattern (for TDD mode)
            % SchedulingType(optional) - Slot based scheduling (value 0) or symbol based scheduling (value 1). Default value is 0
            % MaxLogicalChannels       - Maximum number of logical channels that can be configured
            % RBGSizeConfig(optional)  - RBG size configuration as 1 (configuration-1 RBG table) or 2 (configuration-2 RBG table)
            %                            as defined in 3GPP TS 38.214 Section 5.1.2.2.1. It defines the
            %                            number of RBs in an RBG. Default value is 1
            % Position                 - Position of UE in (x,y,z) coordinates
            %
            % The second input, RNTI, is the radio network temporary
            % identifier, specified within [1, 65519]. Refer table 7.1-1 in
            % 3GPP TS 38.321.
            
            % Validate UE position
            validateattributes(param.Position, {'numeric'}, {'numel', 3, 'nonempty', 'finite', 'nonnan'}, 'param.Position', 'Position');
            
            % Create the UE MAC instance
            obj.MACEntity = hNRUEMAC(param, rnti);
            % Initialize RLC entities cell array
            obj.RLCEntities = cell(1, obj.MaxLogicalChannels);
            % Initialize application cell array
            obj.Applications = cell(obj.MaxApplications, 1);
            % Register the callback to implement the interaction between
            % MAC and RLC. 'sendRLCPDUs' is the callback to RLC by MAC to
            % get RLC PDUs for the uplink transmissions. 'receiveRLCPDUs'
            % is the callback to RLC by MAC to receive RLC PDUs, for the
            % received downlink packets
            obj.MACEntity.registerRLCInterfaceFcn(@obj.sendRLCPDUs, @obj.receiveRLCPDUs);

            obj.Position = param.Position;
        end

        function configurePhy(obj, configParam)
            %configurePhy Configure the physical layer
            %
            %   configurePhy(OBJ, CONFIGPARAM) sets the physical layer
            %   configuration.

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
            % Validate uplink and downlink carrier frequencies
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
            
            % Register MAC callback function at Phy for:
            % (1) Sending the packets to MAC
            % (2) Sending the measured DL channel quality to MAC
            registerMACInterfaceFcn(obj.PhyEntity, @macEntity.rxIndication, @macEntity.csirsIndication);
            
            % Register callback function on Phy for getting node position
            registerGetPositionFcn(obj.PhyEntity, @obj.getPosition);
        end
    end
end