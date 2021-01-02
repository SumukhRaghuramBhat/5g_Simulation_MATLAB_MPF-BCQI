classdef (Abstract) hNRPhyInterface < handle
    %hNRPhyInterface Define NR physical layer interface class
    %   The class acts as a base class for all the physical layer types. It
    %   defines the interface to physical layer. It declares the methods to
    %   be used by higher layers to interact with the physical layer. It
    %   also allows higher layers to install callbacks on physical layer
    %   which are used to send information to higher layers
    
    %   Copyright 2020 The MathWorks, Inc.
    
    properties (Access = protected)
        %CellConfig Cell configuration
        CellConfig
        
        %CarrierInformation Carrier information
        CarrierInformation
        
        %DataRxContext Rx context for the Phy
        % Cell array of size 'N' where N is the number of symbols in a 10 ms
        % frame. The cell elements are populated with structures of type
        % hNRPDSCHInfo (for UE) or hNRPUSCHInfo (for gNB). The information in
        % the structure is used by the receiver (UE or gNB) for Rx reception
        % and processing. A node reads the complete packet at the start of the
        % symbol which is just after the symbol in which reception ends. So,
        % an element at index 'i' contains the information for reception which
        % ends at symbol index 'i-1' w.r.t the start of the frame. There can
        % be array of structures at index 'i', if multiple receptions were
        % scheduled to end at symbol index 'i-1'. Cell element at 'i' is
        % empty, if no reception was scheduled to end at symbol index 'i-1'
        DataRxContext
        
        % DataRxStartSymbol Rx start symbol for the Phy
        % Array of size 'N' where N is the number of symbols in a 10 ms frame.
        % Counter to keep track of reception started in the current symbol
        DataRxStartSymbol
        
        %CurrSlot Current running slot number in the 10 ms frame
        CurrSlot = 0;
        
        %CurrSymbol Current running symbol number of the current slot
        CurrSymbol = 0;
        
        %AFN Absolute frame number
        AFN = 0;
        
        %RxIndicationFcn Function handle to send data to MAC
        RxIndicationFcn
        
        %GetPositionFcn Function handle to get the current position of node
        GetPositionFcn
    end
    
    properties (Constant)
        %CSIRSPDUType CSI-RS PDU type
        CSIRSPDUType = 0;
    end
    
    methods(Access = public)
        function setCellConfig(obj, cellConfig)
            %setCellConfig Set the cell configuration
            %  setCellConfig(OBJ, CELLCONFIG) sets the cell configuration,
            %  CELLCONFIG.
            %  CELLCONFIG is a structure including the following fields:
            %      NCellID     - Physical cell ID. Values: 0 to 1007 (TS 38.211, sec 7.4.2.1)
            %      DuplexMode  - Duplexing mode. FDD (value 0) or TDD (value 1)
            
            % Validate NCellID
            if isfield(cellConfig, 'NCellID')
                validateattributes(cellConfig.NCellID, {'numeric'}, {'nonempty', 'integer', 'scalar', '>=', 0, '<=', 1007}, 'cellConfig.NCellID', 'NCellID');
            end
            
            % Validate duplex mode
            if isfield(cellConfig, 'DuplexMode')
                validateattributes(cellConfig.DuplexMode, {'numeric'}, {'nonempty', 'integer', 'scalar', '>=', 0, '<=', 1}, 'cellConfig.DuplexMode', 'DuplexMode');
            end
            
            obj.CellConfig = cellConfig;
        end
        
        function setCarrierInformation(obj, carrierInformation)
            %setCarrierInformation Set the carrier configuration
            %  setCarrierInformation(OBJ, CARRIERINFORMATION) sets the carrier
            %  configuration, CARRIERINFORMATION.
            %  CARRIERINFORMATION is a structure including the following 
            %  fields:
            %      SubcarrierSpacing  - Sub carrier spacing used. Assuming 
            %                           single bandwidth part in the whole
            %                           carrier
            %      NRBsDL             - Downlink bandwidth in terms of 
            %                           number of resource blocks
            %      NRBsUL             - Uplink bandwidth in terms of number
            %                           of resource blocks
            %      DLBandwidth        - Downlink bandwidth in Hz
            %      ULBandwidth        - Uplink bandwidth in Hz
            %      DLFreq             - Downlink carrier frequency in Hz
            %      ULFreq             - Uplink carrier frequency in Hz
            %      NTxAnts            - Number of Tx antennas
            %      NRxAnts            - Number of Rx antennas
            
            % Validate the subcarrier spacing
            if ~ismember(carrierInformation.SubcarrierSpacing, [15 30 60 120 240])
                error('nr5g:hNRPhyInterface:InvalidSCS', 'The subcarrier spacing ( %d ) must be one of the set (15, 30, 60, 120, 240).', carrierInformation.SubcarrierSpacing);
            end
            
            % Validate the number of RBs in the uplink and downlink
            % direction
            if isfield(carrierInformation, 'NRBsUL')
                validateattributes(carrierInformation.NRBsUL, {'numeric'}, {'real', 'integer', 'scalar', '>=', 1, '<=', 275}, 'carrierInformation.NRBsUL', 'NRBsUL');
            end
            if isfield(carrierInformation, 'NRBsDL')
                validateattributes(carrierInformation.NRBsDL, {'numeric'}, {'real', 'integer', 'scalar', '>=', 1, '<=', 275}, 'carrierInformation.NRBsDL', 'NRBsDL');
            end
            
            % Validate uplink and downlink bandwidth
            if isfield(carrierInformation, 'ULBandwidth')
                validateattributes(carrierInformation.ULBandwidth, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'carrierInformation.ULBandwidth', 'ULBandwidth');
            end
            if isfield(carrierInformation, 'DLBandwidth')
                validateattributes(carrierInformation.DLBandwidth, {'numeric'}, {'nonempty', 'scalar', 'finite', '>=', 0}, 'carrierInformation.DLBandwidth', 'DLBandwidth');
            end
            
            % Validate uplink and downlink carrier frequencies
            if isfield(carrierInformation, 'ULFreq')
                validateattributes(carrierInformation.ULFreq, {'numeric'}, {'nonempty', 'scalar', 'finite', '>', 0}, 'carrierInformation.ULFreq', 'ULFreq');
            end
            if isfield(carrierInformation, 'DLFreq')
                validateattributes(carrierInformation.DLFreq, {'numeric'}, {'nonempty', 'scalar', 'finite', '>', 0}, 'carrierInformation.DLFreq', 'DLFreq');              
            end
            
            if isfield(carrierInformation, 'NTxAnts')
                % Validate the number of transmitter antennas
                validateattributes(carrierInformation.NTxAnts, {'numeric'}, {'nonempty', 'integer', 'scalar', 'finite', '>', 0}, 'carrierInformation.NTxAnts', 'NTxAnts');
            else
                carrierInformation.NTxAnts = 1;
            end
            if isfield(carrierInformation, 'NRxAnts')
                % Validate the number of receiver antennas
                validateattributes(carrierInformation.NRxAnts, {'numeric'}, {'nonempty', 'integer', 'scalar', 'finite', '>', 0}, 'carrierInformation.NRxAnts', 'NRxAnts');
            else
                carrierInformation.NRxAnts = 1;
            end
            
            slotDuration = 1/(carrierInformation.SubcarrierSpacing/15); % In ms
            carrierInformation.SlotsPerSubframe = 1/slotDuration; % Number of slots per 1 ms subframe
            slotsPerFrame = carrierInformation.SlotsPerSubframe*10;
            carrierInformation.SymbolsPerFrame = slotsPerFrame*14;
            obj.CarrierInformation = carrierInformation;
            
            % Initialize data Rx context
            obj.DataRxContext = cell(obj.CarrierInformation.SymbolsPerFrame, 1);
            obj.DataRxStartSymbol = zeros(obj.CarrierInformation.SymbolsPerFrame, 1);
        end
        
        function advanceTimer(obj, numSym)
            %advanceTimer Advance the timer ticks by specified number of symbols
            %   advanceTimer(OBJ, NUMSYM) advances the timer by specified
            %   number of symbols. Time is advanced by 1 symbol for
            %   symbol-based scheduling and by 14 symbols for slot based
            %   scheduling.
            %
            %   NUMSYM is the number of symbols to be advanced.
            
            obj.CurrSymbol = mod(obj.CurrSymbol + numSym, 14);
            if obj.CurrSymbol == 0 % Reached slot-boundary
                % Current slot number in 10 ms frame
                obj.CurrSlot = mod(obj.CurrSlot + 1, obj.CarrierInformation.SlotsPerSubframe*10);
                if obj.CurrSlot == 0 % Reached frame boundary
                    obj.AFN = obj.AFN + 1;
                end
            end
        end
        
        function registerGetPositionFcn(obj, getPositionFcn)
            %registerGetPositionFcn Register interface function at Phy to get position of node
            %   registerGetPosFn(OBJ, GETPOSITIONFCN) sets the function handle at
            %   Phy for getting node position
            %
            %   GETPOSITIONFCN Function handle provided by node object to Phy for
            %   getting position
            
            obj.GetPositionFcn = getPositionFcn;
        end
    end
    
    methods(Abstract)
        %txDataRequest Data Tx request from MAC to Phy
        %  txDataRequest(OBJ, TXINFO, MACPDU) is the request from MAC to Phy
        %  to transmit PDSCH (for gNB) or PUSCH (for UE). MAC calls it at the
        %  start of Tx time.
        %
        %  TXINFO is the information sent by MAC which is required for Phy
        %  processing and transmission.
        %
        %  MACPDU is the MAC transport block.
        txDataRequest(obj, txInfo, macPDU)
        
        %rxDataRequest Data Rx request from MAC to Phy
        %  rxDataRequest(OBJ, RXINFO) is the request from MAC to Phy
        %  to receive PUSCH (for gNB) or PDSCH (for UE).The Phy expects to
        %  receive it at the start of reception time
        %
        %  RXINFO is the information sent by MAC which is required by Phy to
        %  receive the packet.
        rxDataRequest(obj, rxInfo)
        
        %dlTTIRequest Downlink transmission time interval (TTI) request from MAC to Phy
        %  dlTTIRequest(OBJ, PDUTYPES, DLTTIPDUS) is an indication from MAC
        %  for downlink transmissions/receptions. For gNB, it is sent by gNB
        %  MAC for DL transmissions. For UE, it is sent by UE MAC for DL
        %  receptions. MAC sends it at the start of a DL slot for all the
        %  scheduled DL transmission/receptions in the slot.
        %
        %  PDUTYPES is an array of DL packet types.
        %
        %  DLTTIPDUS is an array of DL TTI PDUs corresponding to PDUTYPES.
        %
        %  This interface is used for all other DL transmission/reception except for PDSCH transmission/reception.
        dlTTIRequest(obj, pduTypes, dlTTIPDUs)
        
        %registerMACInterfaceFcn Register MAC interface functions at Phy for sending information to MAC
        %  registerMACInterfaceFcn(OBJ, SENDMACPDUFCN, VARARGIN) registers MAC
        %  interface functions at Phy for sending information to MAC. MAC
        %  needs to provide a callback SENDMACPDUFCN to Phy, which Phy would
        %  use to send PDUs up the stack to MAC. Additional callbacks can also
        %  be installed on Phy, as conveyed by variable input arguments, VARARGIN.
        registerMACInterfaceFcn(obj, sendMACPDUFcn, varargin)
    end
end