classdef hNRUEPhy < hNRPhyInterface
    %hNRUEPhy 5G NR Phy Tx and Rx processing chains at UE
    %   The class implements the Phy Tx and Rx processing chains of 5G NR
    %   at UE. It also implements the interfaces for information exchange
    %   between Phy and higher layers. It only supports transmission of
    %   physical uplink shared channel (PUSCH) along with its demodulation
    %   reference signals (DM-RS). It only supports reception of physical
    %   downlink shared channel (PDSCH) along with its DM-RS. A single
    %   bandwidth part is assumed to cover the entire carrier bandwidth.
    
    %   Copyright 2020 The MathWorks, Inc.
    
    properties (Access = private)
        %RNTI RNTI of the UE
        RNTI (1, 1){mustBeInRange(RNTI, 1, 65519)} = 1;
        
        %ULSCHEncoder Uplink shared channel (UL-SCH) encoder system object
        % It is an object of type nrULSCH
        ULSCHEncoder
        
        %DLSCHDecoder Downlink shared channel (DL-SCH) decoder system object
        % It is an object of type nrDLSCHDecoder
        DLSCHDecoder
        
        %WaveformInfoDL Downlink waveform information
        WaveformInfoDL
        
        %WaveformInfoUL Uplink waveform information
        WaveformInfoUL
        
        %TxPower Tx power in dBm
        TxPower(1, 1) {mustBeFinite, mustBeNonnegative, mustBeNonNan} = 23;
        
        %PUSCHPDU Physical uplink shared channel (PUSCH) information sent by MAC for the current slot
        % PUSCH PDU is an object of type hNRPUSCHInfo. It has the
        % information required by Phy to transmit the MAC PDU stored in
        % object property MacPDU
        PUSCHPDU = {}
        
        %MacPDU PDU sent by MAC which is scheduled to be transmitted in the currrent slot
        % The information required to transmit this PDU is stored in object
        % property PUSCHPDU
        MacPDU = {}
        
        %CSIRSContext Rx context for the channel state information reference signals (CSI-RS)
        % This information is populated by MAC and is used by Phy to
        % receive UE's scheduled CSI-RS. It is a cell array of size 'N'
        % where N is the number of slots in a 10 ms frame. The cell
        % elements are populated with objects of type nrCSIRSConfig. An
        % element at index 'i' contains the context of CSI-RS which is sent
        % at slot index 'i-1'. Cell element at index 'i' is empty if no
        % CSI-RS reception was scheduled for the UE in the slot index 'i-1'
        CSIRSContext
        
        %CSIRSIndicationFcn Function handle to send the measured DL channel quality to MAC
        CSIRSIndicationFcn
        
        %CQIConfig Structure containing CQI measurement configuration
        CQIConfig
        
        %DLBlkErr Downlink block error information
        % It is an array of two elements containing the number of
        % erroneously received packets and total received packets,
        % respectively
        DLBlkErr
        
        %NoiseFigure Noise figure at the receiver
        NoiseFigure = 1;
        
        %Temperature at node in Kelvin
        % It is used for thermal noise calculation
        Temperature = 300
        
        %ChannelModel Information about the propagation channel model
        % This property is an object of type nrCDLChannel if the
        % ChannelModelType is specified as 'CDL', otherwise empty
        ChannelModel
        
        %MaxChannelDelay Maximum delay introduced due to multipath components and implementation delays
        MaxChannelDelay = 0;
        
        %RxBuffer Reception buffer object to store received waveforms
        RxBuffer
        
        %SendWaveformFcn Function handle to send the waveform
        SendWaveformFcn
        
        %PacketLogger Contains handle of the PCAP object
        PacketLogger
        
        %PacketMetaData Contains the information required for logging MAC
        %packets into PCAP
        PacketMetaData
    end
    
    methods
        function obj = hNRUEPhy(param, rnti)
            %hNRUEPhy Construct a UE Phy object
            %   OBJ = hNRUEPHY(PARAM, RNTI) constructs a UE Phy object. It
            %   also creates the context of UL-SCH encoder system object
            %   and DL-SCH decoder system object.
            %
            %   PARAM is structure with the fields:
            %       SchedulingType   - Slot based scheduling (value 0) or 
            %                          symbol based scheduling (value 1). Only
            %                          slot based scheduling is supported
            %       SCS              - Subcarrier spacing
            %       UETxPower        - UE Tx Power in dBm
            %       SINR90pc         - SINR to CQI look up table. An array of
            %                          16 SINR values correspond to 16 CQI
            %                          values (0 to 15). The look up table
            %                          contains the CQI resulting in a
            %                          maximum of 0.1 BLER for the
            %                          corresponding SINR.
            %       NumRBs           - Number of resource blocks
            %       DLCarrierFreq    - Downlink carrier frequency in Hz
            %       SubbandSize      - Size of CQI measurement sub-band in RBs
            %       UERxBufferSize   - Maximum number of waveforms to be
            %                          stored
            %       ChannelModelType - Propagation channel model type         
            %
            %   RNTI - RNTI of the UE
            
            % Verify scheduling type
            if isfield(param, 'SchedulingType') && param.SchedulingType == 1
                error('nr5g:hNRUEPhy:InvalidSchedulingType', 'Symbol based scheduling is not supported for this class. Set SchedulingType to 0');
            end
            
            % Validate the subcarrier spacing
            if ~ismember(param.SCS, [15 30 60 120 240])
                error('nr5g:hNRUEPhy:InvalidSCS', 'The subcarrier spacing ( %d ) must be one of the set (15, 30, 60, 120, 240).', param.SCS);
            end
            
            obj.RNTI = rnti;
            
            % Create UL-SCH encoder system object
            ulschEncoder = nrULSCH;
            ulschEncoder.MultipleHARQProcesses = true;
            obj.ULSCHEncoder = ulschEncoder;
            
            % Create DL-SCH decoder system object
            dlschDecoder = nrDLSCHDecoder;
            dlschDecoder.MultipleHARQProcesses = true;
            dlschDecoder.LDPCDecodingAlgorithm = 'Normalized min-sum';
            dlschDecoder.MaximumLDPCIterationCount = 6;
            obj.DLSCHDecoder = dlschDecoder;
            
            % Set the number of erroneous packets and total number of
            % packets received by the UE to zero
            obj.DLBlkErr = zeros(1, 2);
            
            obj.CSIRSContext = cell(10*(param.SCS/15), 1); % Create the context for all slots in the frame
            if isfield(param, 'SINR90pc')
                % Set SINR vs CQI lookup table
                obj.CQIConfig.SINR90pc = param.SINR90pc;
            else
                obj.CQIConfig.SINR90pc = [-5.46 -0.46 4.54 9.05 11.54 14.04 15.54 18.04 ...
                    20.04 22.43 24.93 25.43 27.43 30.43 33.43];
            end
            
            obj.CQIConfig.CQIMode = 'Subband'; % 'Subband' CQI measurement
            
            % Set size of Subband in resource blocks
            if isfield(param, 'SubbandSize')
                obj.CQIConfig.NSBPRB =  param.SubbandSize;
            else
                obj.CQIConfig.NSBPRB = 8;
            end
            
            % Set Tx power in dBm
            if isfield(param, 'UETxPower')
                obj.TxPower = param.UETxPower;
            end
            
            waveformInfo = nrOFDMInfo(param.NumRBs, param.SCS);
            % Create channel model object
            if isfield(param, 'ChannelModelType')
                if strcmpi(param.ChannelModelType, 'CDL')
                    obj.ChannelModel = nrCDLChannel; % CDL channel object
                    obj.ChannelModel.DelayProfile = 'CDL-C';
                    obj.ChannelModel.DelaySpread = 300e-9;
                    % Set the carrier frequency to downlink
                    obj.ChannelModel.CarrierFrequency = param.DLCarrierFreq;
                    % Size of antenna array [M N P Mg Ng], where:
                    %    - M and N are the number of rows and columns in
                    %      the antenna array, respectively.
                    %    - P is the number of polarizations (1 or 2).
                    %    - Mg and Ng are the number of row and column
                    %      array panels, respectively.
                    % Set all elements in antenna array to 1 to indicate
                    % SISO configuration
                    obj.ChannelModel.TransmitAntennaArray.Size = [1 1 1 1 1];
                    obj.ChannelModel.ReceiveAntennaArray.Size = [1 1 1 1 1];
                    obj.ChannelModel.SampleRate = waveformInfo.SampleRate;
                    chInfo = info(obj.ChannelModel);
                    % Update the maximum delay caused due to CDL channel model
                    obj.MaxChannelDelay = ceil(max(chInfo.PathDelays*obj.ChannelModel.SampleRate)) + chInfo.ChannelFilterDelay;
                end
            end
            
            % Set receiver noise figure
            if isfield(param, 'NoiseFigure')
                obj.NoiseFigure = param.NoiseFigure;
            end
            
            % Create reception buffer object
            if isfield(param, 'UERxBufferSize')
                obj.RxBuffer = hNRPhyRxBuffer('BufferSize', param.UERxBufferSize);
            else
                obj.RxBuffer = hNRPhyRxBuffer();
            end
        end
        
        function run(obj)
            %run Run the UE Phy layer operations
            
            % Phy processing and transmission of PUSCH (along with its DM-RS).
            % It assumes that MAC has already loaded the Phy Tx
            % context for anything scheduled to be transmitted at the
            % current symbol
            phyTx(obj);
            
            % Phy reception of PDSCH (along with its DM-RS) and CSI-RS, and then sending the decoded information to MAC.
            % PDSCH Rx is done in the symbol after the last symbol in PDSCH
            % duration (till then the packets are queued in Rx buffer). Phy
            % calculates the last symbol of PDSCH duration based on
            % 'rxDataRequest' call from MAC (which comes at the first
            % symbol of PDSCH Rx time) and the PDSCH duration. CSI-RS
            % reception is done at the start of slot which is after the
            % scheduled CSI-RS reception slot
            phyRx(obj);
        end
        
        function setCarrierInformation(obj, carrierInformation)
            %setCarrierInformation Set the carrier configuration
            %   setCarrierInformation(OBJ, CARRIERINFORMATION) sets the
            %   carrier configuration, CARRIERINFORMATION.
            %   CARRIERINFORMATION is a structure including the following
            %   fields:
            %       SubcarrierSpacing  - Sub carrier spacing used. Assuming
            %                            single bandwidth part in the whole
            %                            carrier
            %       NRBsDL             - Downlink bandwidth in terms of
            %                            number of resource blocks
            %       NRBsUL             - Uplink bandwidth in terms of
            %                            number of resource blocks
            %       DLBandwidth        - Downlink bandwidth in Hz
            %       ULBandwidth        - Uplink bandwidth in Hz
            %       DLFreq             - Downlink carrier frequency in Hz
            %       ULFreq             - Uplink carrier frequency in Hz
            %       NTxAnts            - Number of Tx antennas
            %       NRxAnts            - Number of Rx antennas
            
            setCarrierInformation@hNRPhyInterface(obj, carrierInformation);
            
            % Initialize data Rx context
            obj.DataRxContext = cell(obj.CarrierInformation.SymbolsPerFrame, 1);
            % Initialize data Rx start context
            obj.DataRxStartSymbol = zeros(obj.CarrierInformation.SymbolsPerFrame, 1);
            % Set waveform properties
            setWaveformProperties(obj, obj.CarrierInformation);
        end
        
        function enablePacketLogging(obj, fileName)
            %enablePacketLogging Enable packet logging
            %
            % FILENAME - Name of the PCAP file
            
            % Create packet logging object
            obj.PacketLogger = hNRPacketWriter('FileName', fileName, 'FileExtension', 'pcap');
            obj.PacketMetaData = hNRPacketInfo;
            if obj.CellConfig.DuplexMode % Radio type
                obj.PacketMetaData.RadioType = obj.PacketLogger.RadioTDD;
            else
                obj.PacketMetaData.RadioType = obj.PacketLogger.RadioFDD;
            end
            obj.PacketMetaData.RNTIType = obj.PacketLogger.CellRNTI;
            obj.PacketMetaData.RNTI = obj.RNTI;
        end
        
        function registerMACInterfaceFcn(obj, sendMACPDUFcn, sendDLChannelQualityFcn)
            %registerMACInterfaceFcn Register MAC interface functions at Phy, for sending information to MAC
            %   registerMACInterfaceFcn(OBJ, SENDMACPDUFCN,
            %   SENDDLCHANNELQUALITYFCN) registers the callback function to
            %   send decoded MAC PDUs and measured DL channel quality to MAC.
            %
            %   SENDMACPDUFCN Function handle provided by MAC to Phy for
            %   sending PDUs to MAC.
            %
            %   SENDDLCHANNELQUALITYFCN Function handle provided by MAC to Phy for
            %   sending the measured DL channel quality (measured on CSI-RS).
            
            obj.RxIndicationFcn = sendMACPDUFcn;
            obj.CSIRSIndicationFcn = sendDLChannelQualityFcn;
        end
        
        function registerInBandTxFcn(obj, sendWaveformFcn)
            %registerInBandTxFcn Register callback for transmission on PUSCH
            %
            %   SENDWAVEFORMFCN Function handle provided by packet
            %   distribution object for sending packets to nodes.
            
            obj.SendWaveformFcn = sendWaveformFcn;
        end
        
        function txDataRequest(obj, PUSCHInfo, macPDU)
            %txDataRequest Tx request from MAC to Phy for starting PUSCH transmission
            %  txDataRequest(OBJ, PUSCHINFO, MACPDU) sets the Tx context to
            %  indicate PUSCH transmission in the current slot
            %
            %  PUSCHInfo is an object of type hNRPUSCHInfo sent by MAC. It
            %  contains the information required by the Phy for the
            %  transmission.
            %
            %  MACPDU is the uplink MAC PDU sent by MAC for transmission.
            
            obj.PUSCHPDU = PUSCHInfo;
            obj.MacPDU = macPDU;
        end
        
        function dlTTIRequest(obj, pduType, dlTTIPDU)
            %dlTTIRequest Downlink reception request (non-data) from MAC to Phy
            %   dlTTIRequest(OBJ, PDUTYPES, DLTTIPDUS) is a request from
            %   MAC for downlink receptions. MAC sends it at the start of a
            %   DL slot for all the scheduled non-data DL receptions in the
            %   slot (Data i.e. PDSCH reception information is sent by MAC
            %   using rxDataRequest interface of this class).
            %
            %   PDUTYPE is an array of packet types. Currently, only
            %   packet type 0 (CSI-RS) is supported.
            %
            %   DLTTIPDU is an array of DL TTI information PDUs,
            %   corresponding to packet types in PDUTYPE. Currently
            %   supported information CSI-RS PDU is an object of type
            %   nrCSIRSConfig.
            
            % Update the Rx context for DL receptions
            for i = 1:length(pduType)
                switch(pduType(i))
                    case obj.CSIRSPDUType
                        % CSI-RS would be read at the start of next slot
                        nextSlot = mod(obj.CurrSlot+1, obj.CarrierInformation.SlotsPerSubframe*10);
                        obj.CSIRSContext{nextSlot+1} = dlTTIPDU{i};
                end
                % Current symbol number w.r.t start of 10 ms frame
                symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol;
                % Update the counter to indicate new reception in current symbol
                obj.DataRxStartSymbol(symbolNumFrame+1) = obj.DataRxStartSymbol(symbolNumFrame+1) + 1;
            end
        end
        
        function rxDataRequest(obj, pdschInfo)
            %rxDataRequest Rx request from MAC to Phy for starting PDSCH reception
            %   rxDataRequest(OBJ, PDSCHINFO) is a request to start PDSCH
            %   reception. It starts a timer for PDSCH end time (which on
            %   triggering receives the complete PDSCH). The Phy expects
            %   the MAC to send this request at the start of reception
            %   time.
            %
            %   PDSCHInfo is an object of type hNRPDSCHInfo. It contains the
            %   information required by the Phy for the reception.
            
            symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol; % Current symbol number w.r.t start of 10 ms frame
            
            % PDSCH to be read in the symbol after the last symbol in
            % PDSCH reception
            numPDSCHSym =  pdschInfo.PDSCHConfig.SymbolAllocation(2);
            pdschRxSymbolFrame = mod(symbolNumFrame + numPDSCHSym, obj.CarrierInformation.SymbolsPerFrame);
            
            % Add the PDSCH RX information at the index corresponding to
            % the symbol just after PDSCH end time
            obj.DataRxContext{pdschRxSymbolFrame+1} = pdschInfo;
            
            % Update the counter to indicate new reception in current symbol
            obj.DataRxStartSymbol(symbolNumFrame+1) = obj.DataRxStartSymbol(symbolNumFrame+1) + 1; % 1-based indexing in MATLAB
        end
        
        function phyTx(obj)
            %phyTx Physical layer processing and transmission
            
            if ~isempty(obj.PUSCHPDU)
                % Initialize Tx grid
                txSlotGrid = zeros(obj.CarrierInformation.NRBsUL*12, obj.WaveformInfoUL.SymbolsPerSlot, obj.CarrierInformation.NTxAnts);
                
                % Fill PUSCH symbols in the grid
                txSlotGrid = populatePUSCH(obj, obj.PUSCHPDU, obj.MacPDU, txSlotGrid);
                
                % OFDM modulation
                carrier = nrCarrierConfig;
                carrier.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
                carrier.NSizeGrid = obj.CarrierInformation.NRBsDL;
                carrier.NSlot = obj.CurrSlot;
                txWaveform = nrOFDMModulate(carrier, txSlotGrid);
                
                % Apply Tx power and gain
                gain = 0;
                txWaveform = applyTxPowerLevelAndGain(obj, txWaveform, gain);
                
                % Construct packet information
                packetInfo.Waveform = txWaveform;
                packetInfo.RNTI = obj.RNTI;
                packetInfo.Position = obj.GetPositionFcn();
                packetInfo.CarrierFreq = obj.CarrierInformation.ULFreq;
                packetInfo.TxPower = obj.TxPower;
                packetInfo.NTxAnts = obj.CarrierInformation.NTxAnts;
                packetInfo.SampleRate = obj.WaveformInfoUL.SampleRate;
                
                % Waveform transmission by sending it to packet
                % distribution entity
                obj.SendWaveformFcn(packetInfo);
            end
            
            % Clear the Tx contexts
            obj.PUSCHPDU = {};
            obj.MacPDU = {};
        end
        
        function storeReception(obj, waveformInfo)
            %storeReception Receive the waveform and add it to the reception
            % buffer
            
            % Apply channel model
            rxWaveform = applyChannelModel(obj, waveformInfo);
            currTime = getCurrentTime(obj);
            rxWaveformInfo = struct('Waveform', rxWaveform, ...
                'NumSamples', numel(rxWaveform), ...
                'SampleRate', waveformInfo.SampleRate, ...
                'StartTime', currTime);
            
            % Store the received waveform in the buffer
            addWaveform(obj.RxBuffer, rxWaveformInfo);
        end
        
        function phyRx(obj)
            %phyRx Physical layer reception and sending of decoded information to MAC layer
            
            symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol; % Current symbol number w.r.t start of 10 ms frame
            pdschInfo = obj.DataRxContext{symbolNumFrame + 1};
            csirsInfo = obj.CSIRSContext{obj.CurrSlot + 1};
            currentTime = getCurrentTime(obj);
            
            if ~isempty(pdschInfo) || ~isempty(csirsInfo) % If anything is scheduled to be received
                % Calculate the reception duration
                if ~isempty(pdschInfo)
                    startSymPDSCH = pdschInfo.PDSCHConfig.SymbolAllocation(1);
                    numSymPDSCH = pdschInfo.PDSCHConfig.SymbolAllocation(2);
                    % Reception start symbol number w.r.t start of 10 ms frame
                    rxStartSymbolNumFrame = pdschInfo.NSlot*14 + startSymPDSCH;
                    % Calculate the symbol start index w.r.t start of 1 ms sub frame
                    slotNumSubFrame = mod(pdschInfo.NSlot, obj.WaveformInfoDL.SlotsPerSubframe);
                    pdschSymbolSet = startSymPDSCH : startSymPDSCH+numSymPDSCH-1;
                    symbolSetSubFrame = (slotNumSubFrame * 14) + pdschSymbolSet + 1;
                    duration = 1e6 * (1/obj.WaveformInfoDL.SampleRate) * ...
                        sum(obj.WaveformInfoDL.SymbolLengths(symbolSetSubFrame));
                    obj.DataRxStartSymbol(rxStartSymbolNumFrame+1) = obj.DataRxStartSymbol(rxStartSymbolNumFrame+1) - 1; % 1-based indexing in MATLAB
                end
                if ~isempty(csirsInfo)
                    % Calculate slot number of CSI-RS Rx start (i.e.
                    % previous slot)
                    if obj.CurrSlot > 0
                        prevSlot = obj.CurrSlot-1;
                    else
                        prevSlot = obj.WaveformInfoDL.SlotsPerSubframe*10-1;
                    end
                    % Reception start symbol number w.r.t start of 10 ms frame
                    rxStartSymbolNumFrame = prevSlot*14 + obj.CurrSymbol;
                    duration = 1e6 * (1e-3 / obj.WaveformInfoDL.SlotsPerSubframe);
                    obj.DataRxStartSymbol(rxStartSymbolNumFrame+1) = obj.DataRxStartSymbol(rxStartSymbolNumFrame+1) - 1; % 1-based indexing in MATLAB
                end
                
                % Convert channel delay into microseconds
                maxChannelDelay = 1e6 * (1/obj.WaveformInfoDL.SampleRate) * obj.MaxChannelDelay;
                
                % Get the received waveform
                duration = duration + maxChannelDelay;
                rxWaveform = getReceivedWaveform(obj.RxBuffer, currentTime + maxChannelDelay - duration, duration, obj.WaveformInfoDL.SampleRate);
                
                % Process the waveform and send the decoded information to MAC
                phyRxProcessing(obj, rxWaveform, pdschInfo, csirsInfo);
                
                % Update the reception status
                if obj.DataRxStartSymbol(rxStartSymbolNumFrame+1) == 0
                    % Set the reception off
                    setReceptionOff(obj.RxBuffer);
                end
            end
            
            if obj.DataRxStartSymbol(symbolNumFrame+1) > 0
                % New reception starts in the current symbol
                setReceptionOn(obj.RxBuffer, currentTime);
            end
            
            % Clear the Rx contexts
            obj.DataRxContext{symbolNumFrame + 1} = {};
            obj.CSIRSContext{obj.CurrSlot + 1} = {};
        end
        
        function dlBLER = getDLBLER(obj)
            %getDLBLER Get the block error statistics of the current slot
            
            dlBLER = obj.DLBlkErr;
            % Reset stats for the next slot
            obj.DLBlkErr = zeros(1, 2);
        end
    end
    
    methods (Access = private)
        function setWaveformProperties(obj, carrierInformation)
            %setWaveformProperties Set the UL and DL waveform properties
            %   setWaveformProperties(OBJ, CARRIERINFORMATION) sets the UL
            %   and DL waveform properties ae per the information in
            %   CARRIERINFORMATION. CARRIERINFORMATION is a structure
            %   including the following fields:
            %       SubcarrierSpacing  - Subcarrier spacing used
            %       NRBsDL             - Downlink bandwidth in terms of number of resource blocks
            %       NRBsUL             - Uplink bandwidth in terms of number of resource blocks
            
            % Set the UL waveform properties
            obj.WaveformInfoUL = nrOFDMInfo(carrierInformation.NRBsUL, carrierInformation.SubcarrierSpacing);
            
            % Set the DL waveform properties
            obj.WaveformInfoDL = nrOFDMInfo(carrierInformation.NRBsDL, carrierInformation.SubcarrierSpacing);
        end
        
        function updatedSlotGrid = populatePUSCH(obj, puschInfo, macPDU, txSlotGrid)
            %populatePUSCH Populate PUSCH symbols in the Tx grid and return the updated grid
            
            % Set transport block in the encoder. In case of empty MAC PDU
            % sent from MAC (indicating retransmission), no need to set
            % transport block as it is already buffered in UL-SCH encoder
            % object
            if ~isempty(macPDU)
                % A non-empty MAC PDU is sent by MAC which indicates new
                % transmission
                macPDUBitmap = de2bi(macPDU, 8);
                macPDUBitmap = reshape(macPDUBitmap', [], 1); % Convert to column vector
                setTransportBlock(obj.ULSCHEncoder, macPDUBitmap, puschInfo.HARQId);
            end
            
            if ~isempty(obj.PacketLogger) % Packet capture enabled
                % Log uplink packets
                if isempty(macPDU)
                    tbID = 0; % Transport block id
                    macPDUBitmap = getTransportBlock(obj.ULSCHEncoder, tbID, puschInfo.HARQId);
                    macPDUBitmap = reshape(macPDUBitmap, 8, [])';
                    macPDU = bi2de(macPDUBitmap);
                end
                logPackets(obj, puschInfo, macPDU, 1)
            end
            
            % Calculate PUSCH and DM-RS information
            carrierConfig = nrCarrierConfig;
            carrierConfig.NSizeGrid = obj.CarrierInformation.NRBsUL;
            carrierConfig.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
            carrierConfig.NSlot = puschInfo.NSlot;
            carrierConfig.NCellID = puschInfo.PUSCHConfig.NID;
            [puschIndices, puschIndicesInfo] = nrPUSCHIndices(carrierConfig, puschInfo.PUSCHConfig);
            dmrsSymbols = nrPUSCHDMRS(carrierConfig, puschInfo.PUSCHConfig);
            dmrsIndices = nrPUSCHDMRSIndices(carrierConfig, puschInfo.PUSCHConfig);
            
            % UL-SCH encoding
            obj.ULSCHEncoder.TargetCodeRate = puschInfo.TargetCodeRate;
            codedTrBlock = obj.ULSCHEncoder(puschInfo.PUSCHConfig.Modulation, puschInfo.PUSCHConfig.NumLayers, ...
                puschIndicesInfo.G, puschInfo.RV, puschInfo.HARQId);
            
            % PUSCH modulation
            puschSymbols = nrPUSCH(carrierConfig, puschInfo.PUSCHConfig, codedTrBlock);
            
            % PUSCH mapping in the grid
            [~,puschAntIndices] = nrExtractResources(puschIndices,txSlotGrid);
            txSlotGrid(puschAntIndices) = puschSymbols;
            
            % PUSCH DM-RS precoding and mapping
            [~,dmrsAntIndices] = nrExtractResources(dmrsIndices(:,1),txSlotGrid);
            txSlotGrid(dmrsAntIndices) = txSlotGrid(dmrsAntIndices) + dmrsSymbols(:,1);
            
            updatedSlotGrid = txSlotGrid;
        end
        
        function rxWaveform = applyChannelModel(obj, pktInfo)
            %applyChannelModel Return the waveform after applying channel model
            
            rxWaveform = pktInfo.Waveform;
            % Check if channel model is specified between gNB and UE
            if ~isempty(obj.ChannelModel)
                rxWaveform = [rxWaveform; zeros(obj.MaxChannelDelay, size(rxWaveform,2))];
                rxWaveform = obj.ChannelModel(rxWaveform);
            end
            
            % Apply path loss on the waveform
            selfInfo.Position = obj.GetPositionFcn();
            [rxWaveform, pathloss] = applyPathLoss(obj, rxWaveform, pktInfo, selfInfo);
            pktInfo.TxPower = pktInfo.TxPower - pathloss;
            
            % Add thermal noise to the waveform
            selfInfo.Temperature = obj.Temperature;
            selfInfo.Bandwidth = obj.CarrierInformation.DLBandwidth;
            rxWaveform = applyThermalNoise(obj, rxWaveform, pktInfo, selfInfo);
        end
        
        function phyRxProcessing(obj, rxWaveform, pdschInfo, csirsInfo)
            %phyRxProcessing Process the waveform and send the decoded information to MAC
            
            carrier = nrCarrierConfig;
            carrier.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
            carrier.NSizeGrid = obj.CarrierInformation.NRBsDL;
            
            % Get previous slot i.e the Tx slot. Reception ended at the
            % end of previous slot
            if obj.CurrSlot > 0
                prevSlot = obj.CurrSlot-1;
                prevSlotAFN = obj.AFN; % Previous slot was in the current frame
            else
                prevSlot = obj.WaveformInfoDL.SlotsPerSubframe*10-1;
                % Previous slot was in the previous frame
                prevSlotAFN = obj.AFN - 1;
            end
            carrier.NSlot = prevSlot;
            carrier.NFrame = prevSlotAFN;
            
            if ~isempty(pdschInfo)
                % If PDSCH is scheduled to be received in the waveform
                if ~isempty(csirsInfo)
                    % If CSIRS is scheduled to be received in the waveform
                    
                    % Generate 0-based carrier-oriented CSI-RS indices in
                    % linear indexed form.
                    pdschInfo.PDSCHConfig.ReservedRE = nrCSIRSIndices(carrier, csirsInfo, 'IndexBase', '0based');
                end
                
                % Calculate PDSCH and DM-RS information
                carrier.NCellID = pdschInfo.PDSCHConfig.NID;
                [pdschIndices, ~] = nrPDSCHIndices(carrier, pdschInfo.PDSCHConfig);
                dmrsSymbols = nrPDSCHDMRS(carrier, pdschInfo.PDSCHConfig);
                dmrsIndices = nrPDSCHDMRSIndices(carrier, pdschInfo.PDSCHConfig);
                
                % Calculate timing offset
                [t,mag] = nrTimingEstimate(carrier, rxWaveform, dmrsIndices, dmrsSymbols);
                offset = 0;
                offset = hSkipWeakTimingOffset(offset,t,mag);
            else
                % If only CSI-RS is present in the waveform
                csirsInd = nrCSIRSIndices(carrier, csirsInfo);
                csirsSym = nrCSIRS(carrier, csirsInfo);
                % Calculate timing offset
                offset = 0;
                [t,mag] = nrTimingEstimate(carrier, rxWaveform, csirsInd, csirsSym);
                offset = hSkipWeakTimingOffset(offset, t, mag);
            end
            
            rxWaveform = rxWaveform(1+offset:end, :);
            % Perform OFDM demodulation on the received data to recreate the
            % resource grid, including padding in the event that practical
            % synchronization results in an incomplete slot being demodulated
            rxGrid = nrOFDMDemodulate(carrier, rxWaveform);
            [K,L,R] = size(rxGrid);
            if (L < obj.WaveformInfoDL.SymbolsPerSlot)
                rxGrid = cat(2,rxGrid,zeros(K, obj.WaveformInfoDL.SymbolsPerSlot-L, R));
            end
            
            % Decode MAC PDU if PDSCH is present in waveform
            if ~isempty(pdschInfo)
                obj.DLSCHDecoder.TransportBlockLength = pdschInfo.TBS*8;
                obj.DLSCHDecoder.TargetCodeRate = pdschInfo.TargetCodeRate;
                [estChannelGrid,noiseEst] = nrChannelEstimate(rxGrid, dmrsIndices, dmrsSymbols);
                % Get PDSCH resource elements from the received grid
                [pdschRx,pdschHest] = nrExtractResources(pdschIndices,rxGrid,estChannelGrid);
                
                % Equalization
                [pdschEq,csi] = nrEqualizeMMSE(pdschRx,pdschHest,noiseEst);
                
                % PDSCH decoding
                [dlschLLRs,rxSymbols] = nrPDSCHDecode(pdschEq, pdschInfo.PDSCHConfig.Modulation, pdschInfo.PDSCHConfig.NID, ...
                    pdschInfo.PDSCHConfig.RNTI, noiseEst);
                
                % Scale LLRs by CSI
                csi = nrLayerDemap(csi); % CSI layer demapping
                
                cwIdx = 1;
                Qm = length(dlschLLRs{1})/length(rxSymbols{cwIdx}); % bits per symbol
                csi{cwIdx} = repmat(csi{cwIdx}.',Qm,1);   % expand by each bit per symbol
                dlschLLRs{cwIdx} = dlschLLRs{cwIdx} .* csi{cwIdx}(:);   % scale
                
                [decbits, crcFlag] = obj.DLSCHDecoder(dlschLLRs, pdschInfo.PDSCHConfig.Modulation, ...
                    pdschInfo.PDSCHConfig.NumLayers, pdschInfo.RV, pdschInfo.HARQId);
                if pdschInfo.RV == 1
                    % The last redundancy version as per the order [0 2 3
                    % 1] failed. Reset the soft buffer
                    resetSoftBuffer(obj.DLSCHDecoder, 0, pdschInfo.HARQId);
                end
                
                % Convert bit stream to byte stream
                decbits = (reshape(decbits, 8, []))';
                macPDU = bi2de(decbits);
                
                % Rx callback to MAC
                macPDUInfo = hNRRxIndicationInfo;
                macPDUInfo.RNTI = pdschInfo.PDSCHConfig.RNTI;
                macPDUInfo.TBS = pdschInfo.TBS;
                macPDUInfo.HARQId = pdschInfo.HARQId;
                obj.RxIndicationFcn(macPDU, crcFlag, macPDUInfo); % Send PDU to MAC
                
                % Increment the number of erroneous packets
                obj.DLBlkErr(1) = obj.DLBlkErr(1) + crcFlag;
                % Increment the total number of received packets
                obj.DLBlkErr(2) = obj.DLBlkErr(2) + 1;
                
                if ~isempty(obj.PacketLogger) % Packet capture enabled
                    logPackets(obj, pdschInfo, macPDU, 0); % Log DL packets
                end
            end
            
            % If CSI-RS is present in waveform, measure DL channel quality
            if ~isempty(csirsInfo)
                cqiConfig = obj.CQIConfig;
                bwp.NSizeBWP = obj.CarrierInformation.NRBsDL;
                bwp.NStartBWP = carrier.NStartGrid; % Consider the start of BWP aligning with the start of the carrier
                
                csirsSym = nrCSIRS(carrier, csirsInfo);
                csirsRefInd = nrCSIRSIndices(carrier, csirsInfo);
                if ~isempty(csirsRefInd)
                    % Perform channel estimate by considering 'AveragingWindow' as [5 1]
                    [Hest,nVar] = nrChannelEstimate(rxGrid(:,1:obj.WaveformInfoDL.SymbolsPerSlot),csirsRefInd,csirsSym,'AveragingWindow',[5 1]);
                    
                    % CQI value reported for each slot is stored in a new column
                    % In subband case, a column of CQI values is reported, where each element corresponds to each subband
                    cqi = hCQISelect(carrier, bwp, cqiConfig, csirsRefInd, Hest, nVar);
                    % Convert CQI of sub-bands to per-RB CQI
                    cqiRBs = zeros(obj.CarrierInformation.NRBsDL, 1);
                    for i = 1:obj.CarrierInformation.NRBsDL/cqiConfig.NSBPRB
                        % Fill same CQI for all the RBs in the sub-band
                        cqiRBs((i-1)*cqiConfig.NSBPRB+1 : i*cqiConfig.NSBPRB) = cqi(i);
                    end
                    
                    if mod(obj.CarrierInformation.NRBsDL, cqiConfig.NSBPRB)
                        cqiRBs((length(cqi)-1)*cqiConfig.NSBPRB+1 : end) = cqi(end);
                    end
                    cqiRBs(cqiRBs<=1) = 1; % Ensuring minimum CQI as 1
                    
                    % Report the CQI to MAC
                    obj.CSIRSIndicationFcn(cqiRBs);
                end
            end
        end
        
        function waveformOut = applyTxPowerLevelAndGain(obj, waverformIn, gain)
            %applyTxPowerLevel Apply Tx power level to IQ samples
            
            % Apply Tx power to IQ samples
            scale = 10.^((-30 + obj.TxPower + gain)/20);
            waveformOut = waverformIn * scale;
        end
        
        function [waveformOut, pathloss] = applyPathLoss(~, waveformIn, txInfo, selfInfo)
            %applyPathloss Apply free space path loss to the received waveform
            
            % Calculate the distance between source and destination nodes
            distance = norm(txInfo.Position - selfInfo.Position);
            % Wavelength
            lambda = physconst('LightSpeed')/txInfo.CarrierFreq;
            % Calculate the path loss
            pathloss = fspl(distance, lambda);
            % Apply path loss on IQ samples
            scale = 10.^(-pathloss/20);
            waveformOut = waveformIn * scale;
        end
        
        function waveformOut = applyThermalNoise(obj, waveformIn, pktInfo, selfInfo)
            %applyThermalNoise Apply thermal noise
            
            % Thermal noise(in Watts) = BoltzmannConstant * Temperature (in Kelvin) * bandwidth of the channel.
            Nt = physconst('Boltzmann') * selfInfo.Temperature * selfInfo.Bandwidth;
            thermalNoise = (10^(obj.NoiseFigure/10)) * Nt; % In watts
            totalnoise = thermalNoise;
            % Calculate SNR
            SNR = pktInfo.TxPower - ((10*log10(totalnoise)) + 30);
            % Add noise
            waveformOut = awgn(waveformIn,SNR,pktInfo.TxPower-30,'db');
        end
        
        function timestamp = getCurrentTime(obj)
            %getCurrentTime  Return the current timestamp of node in microseconds
            
            % Calculate number of samples till the current symbol from the
            % beginning of the current frame
            numSubFrames = floor(obj.CurrSlot / obj.WaveformInfoDL.SlotsPerSubframe);
            numSlotSubFrame = mod(obj.CurrSlot, obj.WaveformInfoDL.SlotsPerSubframe);
            numSamples = (numSubFrames * sum(obj.WaveformInfoDL.SymbolLengths))...
                + sum(obj.WaveformInfoDL.SymbolLengths(1:numSlotSubFrame * obj.WaveformInfoDL.SymbolsPerSlot)) ...
                + sum(obj.WaveformInfoDL.SymbolLengths(1:obj.CurrSymbol));
            
            % Timestamp in microseconds
            timestamp = (obj.AFN * 0.01) + (numSamples *  1 / obj.WaveformInfoDL.SampleRate);
            timestamp = (1e6 * timestamp);
        end
        
        function logPackets(obj, info, macPDU, linkDir)
            %logPackets Capture the MAC packets to a PCAP file
            %
            % logPackets(OBJ, INFO, MACPDU, LINKDIR)
            %
            % INFO - Contains the PUSCH/PDSCH information
            %
            % MACPDU - MAC PDU
            %
            % LINKDIR - 1 represents UL and 0 represents DL direction
            
            timestamp = round(obj.getCurrentTime());
            obj.PacketMetaData.HARQId = info.HARQId;
            obj.PacketMetaData.SlotNumber = info.NSlot;
            
            if linkDir % Uplink
                obj.PacketMetaData.SystemFrameNumber = mod(obj.AFN, 1024);
                obj.PacketMetaData.LinkDir = obj.PacketLogger.Uplink;
            else % Downlink
                % Get frame number of previous slot i.e the Tx slot. Reception ended at the
                % end of previous slot
                if obj.CurrSlot > 0
                    prevSlotAFN = obj.AFN; % Previous slot was in the current frame
                else
                    % Previous slot was in the previous frame
                    prevSlotAFN = obj.AFN - 1;
                end
                obj.PacketMetaData.SystemFrameNumber = mod(prevSlotAFN, 1024);
                obj.PacketMetaData.LinkDir = obj.PacketLogger.Downlink;
            end
            write(obj.PacketLogger, macPDU, timestamp, 'PacketInfo', obj.PacketMetaData);
        end
    end
end