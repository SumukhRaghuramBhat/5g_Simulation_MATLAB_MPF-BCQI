classdef hNRGNBPhy < hNRPhyInterface
    %hNRGNBPhy 5G NR Phy Tx and Rx processing chains at gNB
    %   The class implements the Phy Tx and Rx processing chains of 5G NR
    %   at gNB. It also implements the interfaces for information exchange
    %   between Phy and higher layers. It supports transmission of physical
    %   downlink shared channel (PDSCH) along with its demodulation
    %   reference signals (DM-RS), and channel state information reference
    %   signals (CSI-RS). It only supports reception of physical uplink
    %   shared channel (PUSCH) along with its DM-RS. gNB is assumed to
    %   serve a single cell. A single bandwidth part is assumed to cover
    %   the entire carrier bandwidth.
    
    %   Copyright 2020 The MathWorks, Inc.
    
    properties (Access = private)
        %UEs RNTIs in the cell
        UEs
        
        %DLSCHEncoders Downlink shared channel (DL-SCH) encoder system objects for the UEs
        % Vector of length equal to the number of UEs in the cell. Each
        % element is an object of type nrDLSCH
        DLSCHEncoders
        
        %ULSCHDecoders Uplink shared channel (UL-SCH) decoder system objects for the UEs
        % Vector of length equal to the number of UEs in the cell. Each
        % element is an object of type nrULSCHDecoder
        ULSCHDecoders
        
        %WaveformInfoDL Downlink waveform information
        WaveformInfoDL
        
        %WaveformInfoUL Uplink waveform information
        WaveformInfoUL
        
        %TxPower Tx power in dBm
        TxPower(1, 1) {mustBeFinite, mustBeNonnegative, mustBeNonNan} = 29;
        
        %RxGain Rx antenna gain in dBi
        RxGain(1, 1) {mustBeFinite, mustBeNonnegative, mustBeNonNan} = 11;
        
        %CSIRSPDU CSI-RS information PDU sent by MAC for the current slot
        % It is an object of type nrCSIRSConfig containing the
        % configuration of CSI-RS to be sent in current slot. If empty,
        % then CSI-RS is not scheduled for the current slot
        CSIRSPDU = {}
        
        %PDSCHPDU PDSCH information sent by MAC for the current slot
        % It is an array of objects of type hNRPDSCHInfo. An object at
        % index 'i' contains the information required by Phy to transmit a
        % MAC PDU stored at index 'i' of object property 'MacPDU'
        PDSCHPDU = {}
        
        %MacPDU PDUs sent by MAC which are scheduled to be sent in the currrent slot
        % It is an array of downlink MAC PDUs to be sent in the current
        % slot. Each object in the array corresponds to one object in
        % object property PDSCHPDU
        MacPDU = {}
        
        %ULBlkErr Uplink block error information
        % It is an array of size N-by-2 where N is the number of UEs,
        % columns 1 and 2 contains the number of erroneously received
        % packets and total received packets, respectively
        ULBlkErr
        
        %ChannelModel Information about the propagation channel model
        % It is a cell array of length equal to the number of UEs. The
        % array contains objects of type nrCDLChannel, if the channel model
        % type is specified as 'CDL', otherwise empty. An object at index
        % 'i' models the channel between the gNB and UE with RNTI 'i'
        ChannelModel
        
        %MaxChannelDelay Maximum delay introduced by multipath components and implementation delays
        % It is an array of length equal to the number of UEs. Each element
        % at index 'i' corresponds to maximum channel delay between the gNB
        % and UE with RNTI 'i'
        MaxChannelDelay
        
        %NoiseFigure Noise figure at the receiver
        NoiseFigure = 1;
        
        %RxBuffer Reception buffer object to store received waveforms
        RxBuffer
        
        %SendWaveformFcn Function handle to transmit the waveform
        SendWaveformFcn
        
        %Temperature Temperature at node in Kelvin
        % It is used for thermal noise calculation
        Temperature = 300
        
        %PacketLogger Contains handle of the packet capture (PCAP) object
        PacketLogger
        
        %PacketMetaData Contains the information required for logging MAC packets into PCAP file
        PacketMetaData
    end
    
    methods
        function obj = hNRGNBPhy(param)
            %hNRGNBPhy Construct a gNB Phy object
            %   OBJ = hNRGNBPHY(numUEs) constructs a gNB Phy object. It
            %   also creates the context of DL-SCH encoders system objects
            %   and UL-SCH decoders system objects for all the UEs.
            %
            %   PARAM is structure with the fields:
            %       SchedulingType   - Slot based scheduling (value 0) or 
            %                          symbol based scheduling (value 1). Only
            %                          slot based scheduling is supported
            %       NumUEs           - Number of UEs in the cell
            %       SCS              - Subcarrier spacing
            %       NumRBs           - Number of resource blocks
            %       GNBTxPower       - Tx Power in dBm
            %       RxGain           - Receiver antenna gain at gNB in dBi
            %       GNBRxBufferSize  - Maximum number of waveforms to be
            %                          stored
            %       ULCarrierFreq    - Uplink carrier frequency in Hz
            %       ChannelModelType - Propagation channel model type
            
            % Verify scheduling type
            if isfield(param, 'SchedulingType') && param.SchedulingType == 1
                error('nr5g:hNRGNBPhy:InvalidSchedulingType', 'Symbol based scheduling is not supported for this class. Set SchedulingType to 0');
            end
            
            % Validate the number of UEs
            validateattributes(param.NumUEs, {'numeric'}, {'nonempty', 'integer', 'scalar', '>', 0, '<=', 65519}, 'param.NumUEs', 'NumUEs')
            
            obj.UEs = 1:param.NumUEs;
            
            % Create DL-SCH encoder system objects for the UEs
            obj.DLSCHEncoders = cell(param.NumUEs, 1);
            for i=1:param.NumUEs
                obj.DLSCHEncoders{i} = nrDLSCH;
                obj.DLSCHEncoders{i}.MultipleHARQProcesses = true;
            end
            
            % Create UL-SCH decoder system objects for the UEs
            obj.ULSCHDecoders = cell(param.NumUEs, 1);
            for i=1:param.NumUEs
                obj.ULSCHDecoders{i} = nrULSCHDecoder;
                obj.ULSCHDecoders{i}.MultipleHARQProcesses = true;
                obj.ULSCHDecoders{i}.LDPCDecodingAlgorithm = 'Normalized min-sum';
                obj.ULSCHDecoders{i}.MaximumLDPCIterationCount = 6;
            end
            
            % Set the number of erroneous packets and the total number of
            % packets received from each UE to zero
            obj.ULBlkErr = zeros(param.NumUEs, 2);
            
            % Set Tx power in dBm
            if isfield(param, 'GNBTxPower')
                obj.TxPower = param.GNBTxPower;
            end
            % Set Rx antenna gain in dBi
            if isfield(param, 'RxGain')
                obj.RxGain = param.RxGain;
            end
            
            % Initialize the ChannelModel and MaxChannelDelay properties
            obj.ChannelModel = cell(1, param.NumUEs);
            obj.MaxChannelDelay = zeros(1, param.NumUEs);
            
            waveformInfo = nrOFDMInfo(param.NumRBs, param.SCS);
            if isfield(param, 'ChannelModelType')
                if strcmpi(param.ChannelModelType, 'CDL')
                    for ueIdx = 1:param.NumUEs
                        channel = nrCDLChannel; % CDL channel object
                        channel.DelayProfile = 'CDL-C';
                        channel.DelaySpread = 300e-9;
                        % Set the carrier frequency to uplink
                        channel.CarrierFrequency = param.ULCarrierFreq;
                        % Size of antenna array [M N P Mg Ng], where:
                        %    - M and N are the number of rows and columns in
                        %      the antenna array, respectively.
                        %    - P is the number of polarizations (1 or 2).
                        %    - Mg and Ng are the number of row and column
                        %      array panels, respectively.
                        % Set all elements in antenna array to 1 to
                        % indicate SISO configuration
                        channel.TransmitAntennaArray.Size = [1 1 1 1 1];
                        channel.ReceiveAntennaArray.Size = [1 1 1 1 1];
                        channel.SampleRate = waveformInfo.SampleRate;
                        chInfo = info(channel);
                        obj.ChannelModel{ueIdx} = channel;
                        % Update the maximum delay caused due to CDL channel model
                        obj.MaxChannelDelay(ueIdx) = ceil(max(chInfo.PathDelays*channel.SampleRate)) + chInfo.ChannelFilterDelay;
                    end
                end
            end
            
            % Set receiver noise figure
            if isfield(param, 'NoiseFigure')
                obj.NoiseFigure = param.NoiseFigure;
            end
            
            % Create reception buffer object
            if isfield(param, 'GNBRxBufferSize')
                obj.RxBuffer = hNRPhyRxBuffer('BufferSize', param.GNBRxBufferSize);
            else
                % Initialize the buffer size with twice the number of UEs
                obj.RxBuffer = hNRPhyRxBuffer('BufferSize', 2 * param.NumUEs);
            end
        end
        
        function run(obj)
            %run Run the gNB Phy layer operations
            
            % Phy processing and transmission of PDSCH (along with its
            % DM-RS) and CSI-RS. It is assumed that MAC has already loaded
            % the Phy Tx context for anything scheduled to be transmitted
            % at the current symbol
            phyTx(obj);
            
            % Phy reception of PUSCH and sending decoded information to
            % MAC. Receive the PUSCHs which ended in the last symbol.
            % Reception as well as processing is done in the symbol after
            % the last symbol in PUSCH duration (till then the packets are
            % queued in Rx buffer). Phy calculates the last symbol of PUSCH
            % duration based on 'rxDataRequest' call from MAC (which comes
            % at the first symbol of PUSCH Rx time) and the PUSCH duration
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
        end
        
        function registerMACInterfaceFcn(obj, sendMACPDUFcn)
            %registerMACInterfaceFcn Register MAC interface functions at Phy, for sending information to MAC
            %   registerMACInterfaceFcn(OBJ, SENDMACPDUFCN) registers the
            %   callback function to send decoded MAC PDUs to MAC.
            %
            %   SENDMACPDUFCN Function handle provided by MAC to Phy for
            %   sending PDUs to MAC.
            
            obj.RxIndicationFcn = sendMACPDUFcn;
        end
        
        function registerInBandTxFcn(obj, sendWaveformFcn)
            %registerInBandTxFcn Register callback for transmission on PDSCH
            %
            %   SENDWAVEFORMFCN Function handle provided by packet
            %   distribution object for packet transmission
            
            obj.SendWaveformFcn = sendWaveformFcn;
        end
        
        function txDataRequest(obj, PDSCHInfo, macPDU)
            %txDataRequest Tx request from MAC to Phy for starting PDSCH transmission
            %  txDataRequest(OBJ, PDSCHINFO, MACPDU) sets the Tx context to
            %  indicate PDSCH transmission in the current slot
            %
            %  PDSCHInfo is an object of type hNRPDSCHInfo, sent by MAC. It
            %  contains the information required by the Phy for the
            %  transmission.
            %
            %  MACPDU is the downlink MAC PDU sent by MAC for transmission.
            
            % Update the Tx context. There can be multiple simultaneous
            % PDSCH transmissions for different UEs
            obj.MacPDU{end+1} = macPDU;
            obj.PDSCHPDU{end+1} = PDSCHInfo;
        end
        
        function dlTTIRequest(obj, pduType, dlTTIPDU)
            %dlTTIRequest Downlink transmission (non-data) request from MAC to Phy
            %   dlTTIRequest(OBJ, PDUTYPES, DLTTIPDUS) is a request from
            %   MAC for downlink transmission. MAC sends it at the start of
            %   a DL slot for all the scheduled non-data DL transmission in
            %   the slot (Data i.e. PDSCH is sent by MAC using
            %   txDataRequest interface of this class).
            %
            %   PDUTYPE is an array of packet types. Currently, only packet
            %   type 0 (CSI-RS) is supported.
            %
            %   DLTTIPDU is an array of DL TTI information PDUs. Each PDU
            %   is stored at the index corresponding to its type in
            %   PDUTYPE. Currently supported CSI-RS information PDU is an object of
            %   type nrCSIRSConfig.
            
            % Update the Tx context
            for i = 1:length(pduType)
                switch(pduType(i))
                    case obj.CSIRSPDUType
                        obj.CSIRSPDU = dlTTIPDU{i};
                end
            end
        end
        
        function rxDataRequest(obj, puschInfo)
            %rxDataRequest Rx request from MAC to Phy for starting PUSCH reception
            %   rxDataRequest(OBJ, PUSCHINFO) is a request to start PUSCH
            %   reception. It starts a timer for PUSCH end time (which on
            %   triggering receives the complete PUSCH). The Phy expects
            %   the MAC to send this request at the start of reception
            %   time.
            %
            %   PUSCHInfo is an object of type hNRPUSCHInfo. It contains
            %   the information required by the Phy for the reception.
            
            symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol; % Current symbol number w.r.t start of 10 ms frame
            
            % PUSCH to be read in the symbol after the last symbol in
            % PUSCH reception
            numPUSCHSym =  puschInfo.PUSCHConfig.SymbolAllocation(2);
            puschRxSymbolFrame = mod(symbolNumFrame + numPUSCHSym, obj.CarrierInformation.SymbolsPerFrame);
            
            % Add the PUSCH Rx information at the index corresponding to
            % the symbol just after PUSCH end time
            obj.DataRxContext{puschRxSymbolFrame+1}{end+1} = puschInfo;
            
            % Update the counter to indicate new reception in current symbol
            obj.DataRxStartSymbol(symbolNumFrame+1) = obj.DataRxStartSymbol(symbolNumFrame+1) + 1; % 1-based indexing in MATLAB
        end
        
        function phyTx(obj)
            %phyTx Physical layer processing and transmission
            
            % Initialize Tx grid
            txSlotGrid = zeros(obj.CarrierInformation.NRBsDL*12, obj.WaveformInfoDL.SymbolsPerSlot, obj.CarrierInformation.NTxAnts);
            
            % Set carrier configuration object
            carrier = nrCarrierConfig;
            carrier.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
            carrier.NSizeGrid = obj.CarrierInformation.NRBsDL;
            carrier.NSlot = obj.CurrSlot;
            carrier.NFrame = obj.AFN;
            
            reservedREs = [];
            % Fill CSI-RS in the grid (if scheduled for current slot)
            if ~isempty(obj.CSIRSPDU)
                csirsInd = nrCSIRSIndices(carrier, obj.CSIRSPDU);
                csirsSym = nrCSIRS(carrier, obj.CSIRSPDU);
                % Placing the CSI-RS in the Tx grid
                txSlotGrid(csirsInd) = csirsSym;
                
                % Generate 0-based carrier oriented CSI-RS indices in
                % linear indexed form. These REs are not
                % available for PDSCH
                reservedREs = nrCSIRSIndices(carrier,obj.CSIRSPDU, 'IndexBase', '0based');
            end
            
            % Fill PDSCH symbols in the grid (if scheduled for current slot)
            if ~isempty(obj.PDSCHPDU)
                txSlotGrid = populatePDSCH(obj, obj.PDSCHPDU, obj.MacPDU, txSlotGrid, reservedREs);
            end
            
            if ~isempty(obj.PDSCHPDU) || ~isempty(obj.CSIRSPDU)
                % OFDM modulation
                txWaveform = nrOFDMModulate(carrier, txSlotGrid);
                
                % Apply Tx power and gain
                gain = 0;
                txWaveform = applyTxPowerLevelAndGain(obj, txWaveform, gain);
                
                % Construct packet information
                packetInfo.Waveform = txWaveform;
                packetInfo.Position = obj.GetPositionFcn();
                packetInfo.CarrierFreq = obj.CarrierInformation.DLFreq;
                packetInfo.TxPower = obj.TxPower;
                packetInfo.NTxAnts = obj.CarrierInformation.NTxAnts;
                packetInfo.SampleRate = obj.WaveformInfoDL.SampleRate;
                
                % Waveform transmission by sending it to packet
                % distribution entity
                obj.SendWaveformFcn(packetInfo);
            end
            
            % Clear the Tx contexts
            obj.PDSCHPDU = {};
            obj.CSIRSPDU = {};
            obj.MacPDU = {};
        end
        
        function storeReception(obj, waveformInfo)
            %storeReception Receive the incoming waveform and add it to the reception
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
            puschInfoList = obj.DataRxContext{symbolNumFrame + 1};
            currentTime = getCurrentTime(obj);
            
            for i = 1:length(puschInfoList) % For all PUSCH receptions which ended in the last symbol
                puschInfo = puschInfoList{i};
                startSymPUSCH = puschInfo.PUSCHConfig.SymbolAllocation(1);
                numSymPUSCH = puschInfo.PUSCHConfig.SymbolAllocation(2);
                % Reception start symbol number w.r.t start of 10 ms frame
                rxStartSymbolNumFrame = puschInfo.NSlot * 14 + startSymPUSCH;
                % Calculate the symbol start index w.r.t start of 1 ms sub frame
                slotNumSubFrame = mod(puschInfo.NSlot, obj.WaveformInfoUL.SlotsPerSubframe);
                % Calculate PUSCH duration
                puschSymbolSet = startSymPUSCH : startSymPUSCH+numSymPUSCH-1;
                symbolSetSubFrame = (slotNumSubFrame * 14) + puschSymbolSet + 1;
                duration = 1e6 * (1/obj.WaveformInfoUL.SampleRate) * ...
                    sum(obj.WaveformInfoUL.SymbolLengths(symbolSetSubFrame));
                
                % Convert channel delay into microseconds
                maxChannelDelay = 1e6 * (1/obj.WaveformInfoUL.SampleRate) * obj.MaxChannelDelay(puschInfo.PUSCHConfig.RNTI);
                
                % Get the received waveform
                duration = duration + maxChannelDelay;
                rxWaveform = getReceivedWaveform(obj.RxBuffer, currentTime + maxChannelDelay - duration, duration, obj.WaveformInfoUL.SampleRate);
                
                % Process the waveform and send the decoded information to MAC
                phyRxProcessing(obj, rxWaveform, puschInfo);
                
                obj.DataRxStartSymbol(rxStartSymbolNumFrame+1) = obj.DataRxStartSymbol(rxStartSymbolNumFrame+1) - 1; % 1-based indexing in MATLAB
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
            
            % Clear the Rx context
            obj.DataRxContext{symbolNumFrame + 1} = {};
        end
        
        function ulBLER = getULBLER(obj)
            %getULBLER Get block error statistics of the slot for each UE
            
            ulBLER = obj.ULBlkErr;
            % Reset stats for the next slot
            obj.ULBlkErr(:) = 0;
        end
    end
    
    methods (Access = private)
        function setWaveformProperties(obj, carrierInformation)
            %setWaveformProperties Set the UL and DL waveform properties
            %   setWaveformProperties(OBJ, CARRIERINFORMATION) sets the UL
            %   and DL waveform properties as per the information in
            %   CARRIERINFORMATION. CARRIERINFORMATION is a structure
            %   including the following fields:
            %       SubcarrierSpacing  - Subcarrier spacing used
            %       NRBsDL             - Downlink bandwidth in terms of
            %                            number of resource blocks
            %       NRBsUL             - Uplink bandwidth in terms of
            %                            number of resource blocks
            
            % Set the UL waveform properties
            obj.WaveformInfoUL = nrOFDMInfo(carrierInformation.NRBsUL, carrierInformation.SubcarrierSpacing);
            
            % Set the DL waveform properties
            obj.WaveformInfoDL = nrOFDMInfo(carrierInformation.NRBsDL, carrierInformation.SubcarrierSpacing);
        end
        
        function updatedSlotGrid = populatePDSCH(obj, pdschPDU, macPDU, txSlotGrid, reservedREs)
            %populatePDSCH Populate PDSCH symbols in the Tx grid and return the updated grid
            
            for i=1:length(pdschPDU) % For each PDSCH scheduled for this slot
                pdschInfo = pdschPDU{i};
                % Set transport block in the encoder. In case of empty MAC
                % PDU sent from MAC (indicating retransmission), no need to set transport
                % block as it is already buffered in DL-SCH encoder object
                if ~isempty(macPDU{i})
                    % A non-empty MAC PDU is sent by MAC which indicates new
                    % transmission
                    macPDUBitmap = de2bi(macPDU{i}, 8);
                    macPDUBitmap = reshape(macPDUBitmap', [], 1); % Convert to column vector
                    setTransportBlock(obj.DLSCHEncoders{pdschInfo.PDSCHConfig.RNTI}, macPDUBitmap, 0, pdschInfo.HARQId);
                end
                
                if ~isempty(obj.PacketLogger) % Packet capture enabled
                    % Log downlink packets
                    if isempty(macPDU{i})
                        tbID = 0; % Transport block id
                        macPDUBitmap = getTransportBlock(obj.DLSCHEncoders{pdschInfo.PDSCHConfig.RNTI}, tbID, pdschInfo.HARQId);
                        macPDUBitmap = reshape(macPDUBitmap, 8, [])';
                        macPacket = bi2de(macPDUBitmap);
                        logPackets(obj, pdschInfo, macPacket, 0);
                    else
                        logPackets(obj, pdschInfo, macPDU{i}, 0);
                    end
                end
                
                % Calculate PDSCH and DM-RS information
                carrierConfig = nrCarrierConfig;
                carrierConfig.NSizeGrid = obj.CarrierInformation.NRBsDL;
                carrierConfig.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
                carrierConfig.NSlot = pdschInfo.NSlot;
                carrierConfig.NCellID = pdschInfo.PDSCHConfig.NID;
                pdschInfo.PDSCHConfig.ReservedRE = reservedREs;
                [pdschIndices, pdschIndicesInfo] = nrPDSCHIndices(carrierConfig, pdschInfo.PDSCHConfig);
                dmrsSymbols = nrPDSCHDMRS(carrierConfig, pdschInfo.PDSCHConfig);
                dmrsIndices = nrPDSCHDMRSIndices(carrierConfig, pdschInfo.PDSCHConfig);
                
                % Encode the DL-SCH transport blocks
                obj.DLSCHEncoders{pdschInfo.PDSCHConfig.RNTI}.TargetCodeRate = pdschInfo.TargetCodeRate;
                codedTrBlock = step(obj.DLSCHEncoders{pdschInfo.PDSCHConfig.RNTI}, pdschInfo.PDSCHConfig.Modulation, ...
                    pdschInfo.PDSCHConfig.NumLayers, pdschIndicesInfo.G, pdschInfo.RV,pdschInfo.HARQId);
                
                % Get wtx (precoding matrix). Assuming SISO
                wtx = 1;
                
                % PDSCH modulation and precoding
                pdschSymbols = nrPDSCH(carrierConfig, pdschInfo.PDSCHConfig, codedTrBlock);
                pdschSymbols = pdschSymbols*wtx;
                
                % PDSCH mapping in the grid
                [~,pdschAntIndices] = nrExtractResources(pdschIndices,txSlotGrid);
                txSlotGrid(pdschAntIndices) = pdschSymbols;
                
                % PDSCH DM-RS precoding and mapping
                for p = 1:size(dmrsSymbols,2)
                    [~,dmrsAntIndices] = nrExtractResources(dmrsIndices(:,p),txSlotGrid);
                    txSlotGrid(dmrsAntIndices) = txSlotGrid(dmrsAntIndices) + dmrsSymbols(:,p)*wtx(p,:);
                end
            end
            updatedSlotGrid = txSlotGrid;
        end
        
        function rxWaveform = applyChannelModel(obj, pktInfo)
            %applyChannelModel Return the waveform after applying channel model
            
            rxWaveform = pktInfo.Waveform;
            % Check if channel model is specified between gNB and a
            % particular UE
            if ~isempty(obj.ChannelModel{pktInfo.RNTI})
                rxWaveform = [rxWaveform; zeros(obj.MaxChannelDelay(pktInfo.RNTI), size(rxWaveform,2))];
                rxWaveform = obj.ChannelModel{pktInfo.RNTI}(rxWaveform);
            end
            
            % Apply path loss on the waveform
            selfInfo.Position = obj.GetPositionFcn();
            [rxWaveform, pathloss] = applyPathLoss(obj, rxWaveform, pktInfo, selfInfo);
            pktInfo.TxPower = pktInfo.TxPower - pathloss;
            
            % Apply receiver antenna gain
            rxWaveform = applyRxGain(obj, rxWaveform);
            pktInfo.TxPower = pktInfo.TxPower + obj.RxGain;
            
            % Add thermal noise to the waveform
            selfInfo.Temperature = obj.Temperature;
            selfInfo.Bandwidth = obj.CarrierInformation.ULBandwidth;
            rxWaveform = applyThermalNoise(obj, rxWaveform, pktInfo, selfInfo);
        end
        
        function phyRxProcessing(obj, rxWaveform, puschInfo)
            %phyRxProcessing Read the PUSCH as per the passed PUSCH information and send the decoded information to MAC
            
            carrier = nrCarrierConfig;
            carrier.SubcarrierSpacing = obj.CarrierInformation.SubcarrierSpacing;
            carrier.NSizeGrid = obj.CarrierInformation.NRBsUL;
            % Get previous slot i.e the Tx slot. Reception ended at the
            % end of previous slot
            if obj.CurrSlot > 0
                prevSlot = obj.CurrSlot-1;
                prevSlotAFN = obj.AFN; % Previous slot was in the current frame
            else
                prevSlot = obj.WaveformInfoUL.SlotsPerSubframe*10-1;
                % Previous slot was in the previous frame
                prevSlotAFN = obj.AFN - 1;
            end
            carrier.NSlot = prevSlot;
            carrier.NFrame = prevSlotAFN;
            carrier.NCellID = puschInfo.PUSCHConfig.NID;
            
            % Get PUSCH and DM-RS information
            [puschIndices, ~] = nrPUSCHIndices(carrier, puschInfo.PUSCHConfig);
            dmrsSymbols = nrPUSCHDMRS(carrier, puschInfo.PUSCHConfig);
            dmrsIndices = nrPUSCHDMRSIndices(carrier, puschInfo.PUSCHConfig);
            
            % Set TBS
            obj.ULSCHDecoders{puschInfo.PUSCHConfig.RNTI}.TransportBlockLength = puschInfo.TBS*8;
            
            % Practical synchronization. Correlate the received waveform
            % with the PUSCH DM-RS to give timing offset estimate 't' and
            % correlation magnitude 'mag'
            [t,mag] = nrTimingEstimate(carrier, rxWaveform, dmrsIndices, dmrsSymbols);
            offset = 0;
            offset = hSkipWeakTimingOffset(offset, t, mag);
            
            rxWaveform = rxWaveform(1+offset:end, :);
            % Perform OFDM demodulation on the received data to recreate the
            % resource grid, including padding in the event that practical
            % synchronization results in an incomplete slot being demodulated
            rxGrid = nrOFDMDemodulate(carrier, rxWaveform);
            [K, L, R] = size(rxGrid);
            if (L < obj.WaveformInfoUL.SymbolsPerSlot)
                rxGrid = cat(2, rxGrid, zeros(K, obj.WaveformInfoUL.SymbolsPerSlot-L, R));
            end
            
            % Practical channel estimation between the received grid
            % and each transmission layer, using the PUSCH DM-RS for
            % each layer
            [estChannelGrid, noiseEst] = nrChannelEstimate(rxGrid, dmrsIndices, dmrsSymbols);
            
            % Get PUSCH resource elements from the received grid
            [puschRx,puschHest] = nrExtractResources(puschIndices,rxGrid,estChannelGrid);
            
            % Equalization
            [puschEq,csi] = nrEqualizeMMSE(puschRx,puschHest,noiseEst);
            
            % Decode PUSCH physical channel
            [ulschLLRs,rxSymbols] = nrPUSCHDecode(carrier, puschInfo.PUSCHConfig, puschEq, noiseEst);
            
            csi = nrLayerDemap(csi);
            Qm = length(ulschLLRs) / length(rxSymbols);
            csi = reshape(repmat(csi{1}.',Qm,1),[],1);
            ulschLLRs = ulschLLRs .* csi;
            
            % Decode the UL-SCH transport channel
            obj.ULSCHDecoders{puschInfo.PUSCHConfig.RNTI}.TargetCodeRate = puschInfo.TargetCodeRate;
            [decbits, crcFlag] = step(obj.ULSCHDecoders{puschInfo.PUSCHConfig.RNTI}, ulschLLRs, ...
                puschInfo.PUSCHConfig.Modulation, puschInfo.PUSCHConfig.NumLayers, puschInfo.RV, puschInfo.HARQId);
            
            if puschInfo.RV == 1
                % The last redundancy version as per the order [0 2 3 1]
                % failed. Reset the soft buffer
                resetSoftBuffer(obj.ULSCHDecoders{puschInfo.PUSCHConfig.RNTI}, puschInfo.HARQId);
            end
            % Convert bit stream to byte stream
            decbits = (reshape(decbits, 8, []))';
            macPDU = bi2de(decbits);
            
            % Rx callback to MAC
            macPDUInfo = hNRRxIndicationInfo;
            macPDUInfo.RNTI = puschInfo.PUSCHConfig.RNTI;
            macPDUInfo.TBS = puschInfo.TBS;
            macPDUInfo.HARQId = puschInfo.HARQId;
            obj.RxIndicationFcn(macPDU, crcFlag, macPDUInfo); % Send PDU to MAC
            
            % Increment the number of erroneous packets received for UE
            obj.ULBlkErr(puschInfo.PUSCHConfig.RNTI, 1) = obj.ULBlkErr(puschInfo.PUSCHConfig.RNTI, 1) + crcFlag;
            % Increment the number of received packets for UE
            obj.ULBlkErr(puschInfo.PUSCHConfig.RNTI, 2) = obj.ULBlkErr(puschInfo.PUSCHConfig.RNTI, 2) + 1;
            
            if ~isempty(obj.PacketLogger) % Packet capture enabled
                logPackets(obj, puschInfo, macPDU, 1); % Log UL packets
            end
        end
        
        function waveformOut = applyTxPowerLevelAndGain(obj, waverformIn, gain)
            %applyTxPowerLevel Applies Tx power level to IQ samples
            
            % Apply Tx power to IQ samples.
            scale = 10.^((-30 + obj.TxPower + gain)/20);
            waveformOut = waverformIn * scale;
        end
        
        function [waveformOut, pathloss] = applyPathLoss(~, waveformIn, txInfo, selfInfo)
            %applyPathloss Apply free space path loss to the received waveform
            
            % Calculate the distance between source and destination nodes
            distance = norm(txInfo.Position - selfInfo.Position);
            % Wavelength
            lambda = physconst('LightSpeed')/txInfo.CarrierFreq;
            % Calculate the pathloss
            pathloss = fspl(distance, lambda);
            % Apply pathloss on IQ samples
            scale = 10.^(-pathloss/20);
            waveformOut = waveformIn * scale;
        end
        
        function waveformOut = applyRxGain(obj, waveformIn)
            %applyRxGain Apply receiver antenna gain
            
            scale = 10.^(obj.RxGain/20);
            waveformOut = waveformIn.* scale;
        end
        
        function waveformOut = applyThermalNoise(obj, waveformIn, pktInfo, selfInfo)
            %applyThermalNoise Apply thermal noise
            
            % Thermal noise(in Watts) = BoltzmannConstant * Temperature (in Kelvin) * bandwidth of the channel.
            Nt = physconst('Boltzmann') * selfInfo.Temperature * selfInfo.Bandwidth;
            thermalNoise = (10^(obj.NoiseFigure/10)) * Nt; % In watts
            totalnoise = thermalNoise;
            % Calculate SNR.
            SNR = pktInfo.TxPower - ((10*log10(totalnoise)) + 30);
            % Add noise
            waveformOut = awgn(waveformIn,SNR,pktInfo.TxPower-30, 'db');
        end
        
        function timestamp = getCurrentTime(obj)
            %getCurrentTime Return the current timestamp of node in microseconds
            
            % Calculate number of samples till the current symbol from the
            % beginning of the current frame
            numSubFrames = floor(obj.CurrSlot / obj.WaveformInfoUL.SlotsPerSubframe);
            numSlotSubFrame = mod(obj.CurrSlot, obj.WaveformInfoUL.SlotsPerSubframe);
            numSamples = (numSubFrames * sum(obj.WaveformInfoUL.SymbolLengths))...
                + sum(obj.WaveformInfoUL.SymbolLengths(1:numSlotSubFrame * obj.WaveformInfoUL.SymbolsPerSlot)) ...
                + sum(obj.WaveformInfoUL.SymbolLengths(1:obj.CurrSymbol));
            
            % Timestamp in microseconds
            timestamp = (obj.AFN * 0.01) + (numSamples *  1 / obj.WaveformInfoUL.SampleRate);
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
                % Get frame number of previous slot i.e the Tx slot. Reception ended at the
                % end of previous slot
                if obj.CurrSlot > 0
                    prevSlotAFN = obj.AFN; % Previous slot was in the current frame
                else
                    % Previous slot was in the previous frame
                    prevSlotAFN = obj.AFN - 1;
                end
                obj.PacketMetaData.SystemFrameNumber = mod(prevSlotAFN, 1024);
                obj.PacketMetaData.LinkDir = obj.PacketLogger.Uplink;
                obj.PacketMetaData.RNTI = info.PUSCHConfig.RNTI;
            else % Downlink
                obj.PacketMetaData.SystemFrameNumber = mod(obj.AFN, 1024);
                obj.PacketMetaData.LinkDir = obj.PacketLogger.Downlink;
                obj.PacketMetaData.RNTI = info.PDSCHConfig.RNTI;
            end
            write(obj.PacketLogger, macPDU, timestamp, 'PacketInfo', obj.PacketMetaData);
        end
    end
end