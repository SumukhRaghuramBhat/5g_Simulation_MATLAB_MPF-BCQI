classdef hNRUEMAC < hNRMAC
%hNRUEMAC Implements UE MAC functionality
%   The class implements the UE MAC and its interactions with RLC and Phy
%   for Tx and Rx chains. It involves adhering to packet transmission and
%   reception schedule and other related parameters which are received from
%   gNB in the form of uplink (UL) and downlink (DL) assignments. Reception
%   of uplink and downlink assignments on physical downlink control channel
%   (PDCCH) is not modeled and they are received as out-of-band packets
%   i.e. without using frequency resources and with guaranteed reception.
%   Additionally, physical uplink control channel (PUCCH) is not modeled.
%   The UE MAC sends the periodic buffer status report (BSR), PDSCH
%   feedback, and DL channel quality report out-of-band. Hybrid automatic
%   repeat request (HARQ) control mechanism to enable retransmissions is
%   implemented. MAC controls the HARQ processes residing in physical
%   layer.

%   Copyright 2019-2020 The MathWorks, Inc.

%#codegen

    properties
        % RNTI Radio network temporary identifier of a UE
        %   Specify the RNTI as an integer scalar within [1 65519]. Refer
        %   table 7.1-1 in 3GPP TS 38.321. The default value is 1.
        RNTI (1, 1) {mustBeInteger, mustBeInRange(RNTI, 1, 65519)} = 1;

        %SCS Subcarrier spacing used. The default value is 15 kHz
        SCS (1, 1) {mustBeMember(SCS, [15, 30, 60, 120, 240])} = 15;

        %CurrSlot Current running slot number in the 10 ms frame
        CurrSlot = 0;

        %CurrSymbol Current running symbol of the current slot
        CurrSymbol = 0;

        %SFN System frame number (0 ... 1023)
        SFN = 0;

        %SchedulingType Type of scheduling (slot based or symbol based)
        % Value 0 means slot based and value 1 means symbol based. The
        % default value is 0
        SchedulingType (1, 1) {mustBeInteger, mustBeInRange(SchedulingType, 0, 1)} = 0;

        %DuplexMode Duplexing mode. Frequency division duplexing (FDD) or time division duplexing (TDD)
        % Value 0 means FDD and 1 means TDD. The default value is 0
        DuplexMode (1, 1) {mustBeInteger, mustBeInRange(DuplexMode, 0, 1)} = 0;

        % MCSTableUL MCS table used for uplink
        % It contains the mapping of MCS indices with Modulation and Coding
        % schemes
        MCSTableUL

        % MCSTableDL MCS table used for downlink
        % It contains the mapping of MCS indices with Modulation and Coding
        % schemes
        MCSTableDL

        %NumDLULPatternSlots Number of slots in DL-UL pattern (for TDD mode)
        % The default value is 5 slots
        NumDLULPatternSlots (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(NumDLULPatternSlots, 0), mustBeFinite} = 5;

        %NumDLSlots Number of full DL slots at the start of DL-UL pattern (for TDD mode)
        % The default value is 2 slots
        NumDLSlots (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(NumDLSlots, 0), mustBeFinite} = 2;

        %NumDLSyms Number of DL symbols after full DL slots in the DL-UL pattern (for TDD mode)
        % The default value is 8 symbols
        NumDLSyms (1, 1) {mustBeInteger, mustBeInRange(NumDLSyms, 0, 13)} = 8;

        %NumULSyms Number of UL symbols before full UL slots in the DL-UL pattern (for TDD mode)
        % The default value is 4 symbols
        NumULSyms (1, 1) {mustBeInteger, mustBeInRange(NumULSyms, 0, 13)} = 4;

        %NumULSlots Number of full UL slots at the end of DL-UL pattern (for TDD mode)
        % The default value is 2 slots
        NumULSlots (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(NumULSlots, 0), mustBeFinite} = 2;

        %GuardDuration Guard period in the DL-UL pattern in terms of number of symbols (for TDD mode)
        % The default value is 2 symbols
        GuardDuration (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(GuardDuration, 1), mustBeFinite} = 2;

        %DLULSlotFormat Format of the slots in DL-UL pattern (for TDD mode)
        % N-by-14 matrix where 'N' is number of slots in DL-UL pattern.
        % Each row contains the symbol type of the 14 symbols in the slot.
        % Value 0, 1 and 2 represent DL symbol, UL symbol, guard symbol,
        % respectively
        DLULSlotFormat

        %CurrDLULSlotIndex Slot index of the current running slot in the DL-UL pattern (for TDD mode)
        CurrDLULSlotIndex = 0;

        %NumPUSCHRBs Number of resource blocks (RBs) in the uplink bandwidth part
        % The default value is 52 RBs
        NumPUSCHRBs (1, 1) {mustBeInteger, mustBeInRange(NumPUSCHRBs, 1, 275)} = 52;
        
        %NumPDSCHRBs Number of resource blocks in the downlink bandwidth part
        % The default value is 52 RBs
        NumPDSCHRBs (1, 1) {mustBeInteger, mustBeInRange(NumPDSCHRBs, 1, 275)} = 52;

        %NumPUSCHDMRS Number of PUSCH demodulation reference signal symbols
        NumPUSCHDMRS = 1;

        %NumPDSCHDMRS Number of PDSCH demodulation reference signal symbols
        NumPDSCHDMRS = 1;

        %UplinkTxContext Uplink grant properties to be used for PUSCH transmissions
        % Cell array of size 'N' where 'N' is the number of symbols in a 10
        % ms frame. At index 'i', it contains the uplink grant for a
        % transmission which is scheduled to start at symbol number 'i'
        % w.r.t start of the frame. Value at an index is empty, if no
        % uplink transmission is scheduled for the symbol. An uplink grant
        % has the following fields:
        %
        % SlotOffset                Offset of the allocated slot from the current slot
        %
        % RBGAllocationBitmap       Resource block group(RBG) allocation
        %                           represented as a bit vector
        %
        % StartSymbol               Start symbol of transmission
        %
        % NumSymbols                Number of symbols
        %
        % MCS                       Modulation and coding scheme
        %
        % NDI                       New data indicator flag
        %
        % RV                        Redundancy version sequence number
        %
        % HARQId                    HARQ process ID
        UplinkTxContext

        %DownlinkRxContext Downlink grant properties to be used for PDSCH reception
        % Cell array of size 'N' where N is the number of symbols
        % in a 10 ms frame. An element at index 'i' stores the downlink
        % grant for PDSCH scheduled to be received at symbol 'i' from the
        % start of the frame. If no PDSCH reception is scheduled, cell
        % element is empty. An uplink grant has the following fields:
        %
        % SlotOffset  Slot-offset of the PDSCH assignments for upcoming slot
        %             w.r.t the current slot
        %
        % RBGAllocationBitmap  Frequency-domain resource assignment. A
        %                      bitmap of resource-block-groups of the PDSCH
        %                      bandwidth. Value 1 indicates RBG is assigned
        %                      to the UE
        %
        % StartSymbol  Start symbol of time-domain resources. Assumed to be
        %              0 as time-domain assignment granularity is kept as
        %              full slot
        %
        % NumSymbols   Number of symbols in time-domain
        %
        % MCS          Selected modulation and coding scheme for UE with
        %              respect to the resource assignment done
        %
        % RV           Redundancy version
        %
        % NDI          New data indicator flag
        %
        % HARQId       HARQ process ID
        %
        % FeedbackSlotOffset Slot offset of PDSCH ACK/NACK from PDSCH
        % transmission (i.e. k1)
        DownlinkRxContext

        % PDSCHRxFeedback Feedback to be sent for PDSCH reception
        % N-by-2 array where 'N' is the number of HARQ process. For each
        % HARQ process, first column contains the symbol number w.r.t start
        % of 10ms frame where PDSCH feedback is scheduled to be
        % transmitted. Second column contains the feedback to be sent.
        % Symbol number is -1 if no feedback is scheduled for HARQ process.
        % Feedback value 0 means NACK while value 1 means ACK
        PDSCHRxFeedback

        %NumHARQ Number of uplink HARQ processes. The default value is 16 HARQ processes
        NumHARQ (1, 1) {mustBeInteger, mustBeInRange(NumHARQ, 1, 16)} = 16;

        %HARQNDIUL Stores the last received NDI for uplink HARQ processes
        % Vector of length 'N' where 'N' is number of HARQ process. Value
        % at index 'i' stores last received NDI for the HARQ process index
        % 'i'. NDI in the UL grant is compared with this NDI to decide
        % whether grant is for new transmission or retransmission
        HARQNDIUL

        %HARQNDIDL Stores the last received NDI for downlink HARQ processes
        % Vector of length 'N' where 'N' is number of HARQ process. Value
        % at index 'i' stores last received NDI for the HARQ process index
        % 'i'. NDI in the DL grant is compared with this NDI to decide
        % whether grant is for new transmission or retransmission
        HARQNDIDL

        %TBSizeUL Stores the size of transport block sent for UL HARQ processes 
        % Vector of length 'N' where 'N' is number of HARQ process. Value
        % at index 'i' stores transport block size for HARQ process index
        % 'i'. Value is 0, if HARQ process is free
        TBSizeUL

        %TBSizeDL Stores the size of transport block to be received for DL HARQ processes 
        % Vector of length 'N' where 'N' is number of HARQ process. Value
        % at index 'i' stores transport block size for HARQ process index
        % 'i'. Value is 0 if no DL packet expected for HARQ process
        TBSizeDL

        %BSRPeriodicity Buffer status report periodicity in terms of number of slots
        BSRPeriodicity

        %CQIReportPeriodicity CQI reporting periodicity in terms of number of slots
        CQIReportPeriodicity

        %RBGSizeUL Resource block group size of uplink BWP in terms of number of RBs
        RBGSizeUL

        %RBGSizeDL Resource block group size of downlink BWP in terms of number of RBs
        RBGSizeDL

        %NumRBGsUL Number of RBGs in uplink BWP
        NumRBGsUL

        %NumRBGsDL Number of RBGs in downlink BWP
        NumRBGsDL

        %CsirsConfig CSI-RS resource configuration for the UE
        % It is an object of type nrCSIRSConfig and contains the
        % CSI-RS resource configured for UE
        CsirsConfig

        %ChannelQualityDL Current downlink CQI values over PDSCH bandwidth
        % Vector of length 'N' where 'N' is the number of RBs in the
        % DL bandwidth
        ChannelQualityDL

        %CurrTxThroughputBytes Number of MAC bytes sent in current symbol
        CurrTxThroughputBytes = 0;

        %CurrTxGoodputBytes Number of new MAC bytes sent in current symbol
        % Value is equal to LastTxThroughputBytes if it was a new transmission, 0 otherwise.
        CurrTxGoodputBytes = 0;
    end

    properties (Access = private)
        %LCGBufferStatus Logical channel group buffer status
        LCGBufferStatus = zeros(8, 1);

        %SlotsSinceBSR Number of slots elapsed since last BSR was sent
        % It is incremented every slot and as soon as it reaches the
        % 'BSRPeriodicity', it is set to zero and a BSR is sent
        SlotsSinceBSR = 0;

        %SlotsSinceCQIReport Number of slots elapsed since CQI report was sent
        % It is incremented every slot and as soon as it reaches the
        % 'CQIPeriodicity', it is set to zero and a CQI report is sent
        SlotsSinceCQIReport = 0;
    end

    methods
        function obj = hNRUEMAC(simParameters, rnti)
            %hNRUEMAC Construct a UE MAC object
            %
            % simParameters is a structure including the following fields:
            %
            % NCellID                  - Physical cell ID. Values: 0 to 1007 (TS 38.211, sec 7.4.2.1)
            % SCS                      - Subcarrier spacing
            % DuplexMode               - Duplexing mode. FDD (value 0) or TDD (value 1)
            % BSRPeriodicity(optional) - Periodicity for the BSR packet
            %                            generation. Default value is 5 subframes
            % NumRBs                   - Number of RBs in PUSCH and PDSCH bandwidth
            % NumHARQ                  - Number of HARQ processes on UEs
            % DLULPeriodicity          - Duration of the DL-UL pattern in ms (for TDD mode)
            % NumDLSlots               - Number of full DL slots at the start of DL-UL pattern (for TDD mode)
            % NumDLSyms                - Number of DL symbols after full DL slots of DL-UL pattern (for TDD mode)
            % NumULSyms                - Number of UL symbols before full UL slots of DL-UL pattern (for TDD mode)
            % NumULSlots               - Number of full UL slots at the end of DL-UL pattern (for TDD mode)
            % SchedulingType           - Slot based scheduling (value 0) or symbol based scheduling (value 1)
            % NumLogicalChannels       - Number of logical channels configured
            % RBGSizeConfig(optional)  - RBG size configuration as 1 (configuration-1 RBG table) or 2 (configuration-2 RBG table)
            %                            as defined in 3GPP TS 38.214 Section 5.1.2.2.1. It defines the
            %                            number of RBs in an RBG. Default value is 1
            %
            % The second input, RNTI, is the radio network temporary
            % identifier, specified within [1, 65519]. Refer table 7.1-1 in
            % 3GPP TS 38.321.

            obj.RNTI = rnti;

            if isfield(simParameters, 'NCellID')
                obj.NCellID = simParameters.NCellID;
            end
            if isfield(simParameters, 'SCS')
                obj.SCS = simParameters.SCS;
            end

            % Convert BSR periodicity in terms of number of slots. Dividing
            % 15 kHz by the scs used, gives the slot duration in ms
            if isfield(simParameters, 'BSRPeriodicity')
                % Valid BSR periodicity in terms of number of subframes
                validBSRPeriodicity =  [1, 5, 10, 16, 20, 32, 40, 64, 80, 128, 160, 320, 640, 1280, 2560, inf];
                % Validate the BSR periodicity
                validateattributes(simParameters.BSRPeriodicity, {'numeric'}, {'nonempty'}, 'simParameters.BSRPeriodicity', 'BSRPeriodicity');
                if ~ismember(simParameters.BSRPeriodicity, validBSRPeriodicity)
                    error('nr5g:hNRUEMAC:InvalidBSRPeriodicity','BSRPeriodicity ( %d ) must be one of the set (1,5,10,16,20,32,40,64,80,128,160,320,640,1280,2560,inf).',simParameters.BSRPeriodicity);
                end
                obj.BSRPeriodicity = simParameters.BSRPeriodicity/(15/obj.SCS);
            else
                % By default, for every 5 subframes BSR sent to the gNB
                obj.BSRPeriodicity = 5 /(15/obj.SCS);
            end

            if isfield(simParameters, 'SchedulingType')
                obj.SchedulingType = simParameters.SchedulingType;
            end
            if isfield(simParameters, 'NumHARQ')
                obj.NumHARQ = simParameters.NumHARQ;
            end

            obj.MACType = 1; % UE MAC
            obj.SlotDuration = 1/(obj.SCS/15); % In ms
            obj.NumSlotsFrame = 10/obj.SlotDuration; % Number of slots in a 10 ms frame
            cqiPeriodicity = 2; % 2 ms i.e Send it every alternate subframe
            obj.CQIReportPeriodicity = cqiPeriodicity*(obj.SCS/15); % Periodicity in terms of number of slots

            % Set the RBG size configuration (for defining number of RBs in
            % one RBG) to 1 (configuration-1 RBG table) or 2
            % (configuration-2 RBG table) as defined in 3GPP TS 38.214
            % Section 5.1.2.2.1. If it is not configured, take default
            % value as 1.
            if isfield(simParameters, 'RBGSizeConfig')
                RBGSizeConfig = simParameters.RBGSizeConfig;
            else
                RBGSizeConfig = 1;
            end
            if isfield(simParameters, 'DuplexMode')
                obj.DuplexMode = simParameters.DuplexMode;
            end
            if isfield(simParameters, 'NumRBs')
                obj.NumPUSCHRBs = simParameters.NumRBs;
                obj.NumPDSCHRBs = simParameters.NumRBs;
            end

            % Calculate UL and DL RBG size in terms of number of RBs
            uplinkRBGSizeIndex = min(find(obj.NumPUSCHRBs <= obj.NominalRBGSizePerBW(:, 1), 1));
            downlinkRBGSizeIndex = min(find(obj.NumPDSCHRBs <= obj.NominalRBGSizePerBW(:, 1), 1));
            if RBGSizeConfig == 1
                obj.RBGSizeUL = obj.NominalRBGSizePerBW(uplinkRBGSizeIndex, 2);
                obj.RBGSizeDL = obj.NominalRBGSizePerBW(downlinkRBGSizeIndex, 2);
            else % RBGSizeConfig is 2
                obj.RBGSizeUL = obj.NominalRBGSizePerBW(uplinkRBGSizeIndex, 3);
                obj.RBGSizeDL = obj.NominalRBGSizePerBW(downlinkRBGSizeIndex, 3);
            end
            
            if obj.DuplexMode == 1 % For TDD duplex
                % Validate the TDD configuration and populate the properties
                populateTDDConfiguration(obj, simParameters);

                % Set format of slots in the DL-UL pattern. Value 0 means
                % DL symbol, value 1 means UL symbol while symbols with
                % value 2 are guard symbols
                obj.DLULSlotFormat = obj.GuardType * ones(obj.NumDLULPatternSlots, 14);
                obj.DLULSlotFormat(1:obj.NumDLSlots, :) = obj.DLType; % Mark all the symbols of full DL slots as DL
                obj.DLULSlotFormat(obj.NumDLSlots + 1, 1 : obj.NumDLSyms) = obj.DLType; % Mark DL symbols following the full DL slots
                % For symbol based scheduling, the slot containing
                % guard period for DL-UL switch can have UL symbols
                % after guard period. While for slot based scheduling,
                % this slot will have guard period till the end of the
                % slot, after the DL symbols
                if obj.SchedulingType % For symbol based scheduling
                    obj.DLULSlotFormat(obj.NumDLSlots + floor(obj.GuardDuration/14) + 1, (obj.NumDLSyms + mod(obj.GuardDuration, 14) + 1) : end)  ...
                        = obj.ULType; % Mark UL symbols at the end of slot before full UL slots
                end
                obj.DLULSlotFormat((end - obj.NumULSlots + 1):end, :) = obj.ULType; % Mark all the symbols of full UL slots as UL type
            end

            obj.PDSCHRxFeedback = -1*ones(obj.NumHARQ, 2);
            obj.HARQNDIUL = zeros(obj.NumHARQ, 1); % Initialize NDI of each UL HARQ process to 0
            obj.HARQNDIDL = zeros(obj.NumHARQ, 1); % Initialize NDI of each DL HARQ process to 0
            obj.TBSizeDL = zeros(obj.NumHARQ, 1);

            % Stores uplink assignments (if any), corresponding to uplink
            % transmissions starting at different symbols of the frame
            obj.UplinkTxContext = cell(obj.NumSlotsFrame * 14, 1);

            % Stores downlink assignments (if any), corresponding to
            % downlink receptions starting at different symbols of the
            % frame
            obj.DownlinkRxContext = cell(obj.NumSlotsFrame * 14, 1);

            % Set non zero powered (NZP) CSI-RS configuration for the UE
            csirs = nrCSIRSConfig;
            csirs.NID = obj.NCellID; % Set cell id as scrambling identity
            csirs.NumRB = obj.NumPDSCHRBs;
            if isfield(simParameters, 'CSIRSPeriod')
                csirs.CSIRSPeriod = simParameters.CSIRSPeriod;
            end
            if isfield(simParameters, 'CSIRSDensity')
                csirs.Density = simParameters.CSIRSDensity;
            end
            if isfield(simParameters, 'CSIRSRowNumber')
                csirs.RowNumber = simParameters.CSIRSRowNumber;
            else
                % Possible CSI-RS resource row numbers for single transmit antenna case are 1 and 2
                csirs.RowNumber = 2;
            end
            obj.CsirsConfig = csirs;

            obj.MCSTableUL = getMCSTableUL(obj);
            obj.MCSTableDL = getMCSTableDL(obj);
            obj.LCHBufferStatus = zeros(1, obj.MaxLogicalChannels);
            obj.LCHBjList = zeros(1, obj.MaxLogicalChannels);
            obj.LogicalChannelsConfig = cell(1, obj.MaxLogicalChannels);
            obj.ElapsedTimeSinceLastLCP = 0;
            obj.TBSizeUL = zeros(obj.NumHARQ, 1);
        end

        function run(obj)
            %run Run the UE MAC layer operations
            
            % Send Tx request to Phy for transmission which is scheduled to start at current
            % symbol. Construct and send the UL MAC PDUs scheduled for
            % current symbol to Phy
            dataTx(obj);
            
            % Send Rx request to Phy for reception which is scheduled to start at current symbol
            dataRx(obj);
            
            % Send BSR, PDSCH feedback (ACK/NACK) and CQI report
            controlTx(obj);
            
            % Send request to Phy for non-data receptions scheduled in this
            % slot (currently only CSI-RS supported). Send it at the first
            % symbol of the slot for all the non-data receptions scheduled
            % in the entire slot
            if obj.CurrSymbol == 0 
                dlTTIRequest(obj);
            end
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
            if obj.CurrSymbol == 0 % Reached slot boundary
                % Current slot number in 10 ms frame
                obj.CurrSlot = mod(obj.CurrSlot + 1, obj.NumSlotsFrame);
                if obj.CurrSlot == 0 % Reached frame boundary
                    obj.SFN = mod(obj.SFN + 1, 1024);
                end
                if obj.DuplexMode == 1 % TDD
                    % Current slot number in DL-UL pattern
                    obj.CurrDLULSlotIndex = mod(obj.CurrDLULSlotIndex + 1, obj.NumDLULPatternSlots);
                end
                obj.ElapsedTimeSinceLastLCP  = obj.ElapsedTimeSinceLastLCP  + obj.SlotDuration;
                obj.SlotsSinceBSR = obj.SlotsSinceBSR + 1;
                obj.SlotsSinceCQIReport = obj.SlotsSinceCQIReport + 1;
            end
        end

        function dataTx(obj)
            %dataTx Construct and send the UL MAC PDUs scheduled for current symbol to Phy
            %
            %   dataTx(OBJ) Based on the uplink grants received in earlier,
            %   if current symbol is the start symbol of a Tx then send the UL MAC PDU to
            %   Phy.

            symbolNumFrame = obj.CurrSlot*14 + obj.CurrSymbol;
            uplinkGrant = obj.UplinkTxContext{symbolNumFrame + 1};
            % If there is any uplink grant corresponding to which a transmission is scheduled at the current symbol
            if ~isempty(uplinkGrant)
                % Construct and send MAC PDU to Phy
                [sentPDULen, type] = sendMACPDU(obj, uplinkGrant);
                obj.UplinkTxContext{symbolNumFrame + 1} = []; % Tx done. Clear the context
                obj.CurrTxThroughputBytes = sentPDULen;
                if strcmp(type, 'newTx')
                    obj.CurrTxGoodputBytes = sentPDULen;
                end
            end
        end

        function dataRx(obj)
            %dataRx Send Rx start request to Phy for the reception scheduled to start now
            %
            %   dataRx(OBJ) sends the Rx start request to Phy for the
            %   reception scheduled to start now, as per the earlier
            %   received downlink assignments.

            downlinkGrant = obj.DownlinkRxContext{(obj.CurrSlot * 14) + obj.CurrSymbol + 1}; % Rx context of current symbol
            if ~isempty(downlinkGrant) % If PDSCH reception is expected
                % Calculate feedback transmission symbol number w.r.t start
                % of 10ms frame
                feedbackSlot = mod(obj.CurrSlot + downlinkGrant.FeedbackSlotOffset, obj.NumSlotsFrame);
                %For TDD, the symbol at which feedback would be transmitted
                %is kept as first UL symbol in feedback slot. For FDD, it
                %simply the first symbol in the feedback slot
                if obj.DuplexMode % TDD
                    feedbackSlotDLULIdx = mod(obj.CurrDLULSlotIndex + downlinkGrant.FeedbackSlotOffset, obj.NumDLULPatternSlots);
                    feedbackSlotPattern = obj.DLULSlotFormat(feedbackSlotDLULIdx + 1, :);
                    feedbackSym = (find(feedbackSlotPattern == obj.ULType, 1, 'first')) - 1; % Check for location of first UL symbol in the feedback slot
                else % FDD
                    feedbackSym = 0;  % First symbol
                end
                obj.PDSCHRxFeedback(downlinkGrant.HARQId+1, 1) = feedbackSlot*14 + feedbackSym; % Set symbol number for PDSCH feedback transmission
                rxRequestToPhy(obj, downlinkGrant); % Indicate Rx start to Phy
                obj.DownlinkRxContext{(obj.CurrSlot * 14) + obj.CurrSymbol + 1} = []; % Clear the Rx context
            end
        end

        function rxIndication(obj, macPDU, crc, rxInfo)
            %rxIndication Packet reception from Phy
            %   rxIndication(OBJ, MACPDU, CRC, RXINFO) receives a MAC PDU from
            %   Phy.
            %   MACPDU is the PDU received from Phy.
            %   CRC is the success(value as 0)/failure(value as 1)
            %   indication from Phy.
            %   RXINFO is an object of type hNRRxIndicationInfo containing
            %   information about the reception.

            isRxSuccess = ~crc; % CRC value 0 indicates successful reception
            if isRxSuccess % Packet received is error-free
                % Parse Downlink MAC PDU
                [lcidList, sduList] = hNRMACPDUParser(macPDU, obj.DLType);
                for sduIndex = 1:numel(lcidList)
                    if lcidList(sduIndex) >=1 && lcidList(sduIndex) <= 32
                        obj.RLCRxFcn(obj.RNTI, lcidList(sduIndex), sduList{sduIndex});
                    end
                end
                obj.PDSCHRxFeedback(rxInfo.HARQId+1, 2) = 1;  % Positive ACK
            else % Packet corrupted
                obj.PDSCHRxFeedback(rxInfo.HARQId+1, 2) = 0; % NACK
            end
        end

        function dlTTIRequest(obj)
            % dlTTIRequest Request from MAC to Phy to receive non-data DL receptions
            %
            %   dlTTIRequest(OBJ) sends a request to Phy for non-data
            %   downlink receptions in the current slot. MAC sends it at
            %   the start of a DL slot for all the scheduled DL receptions
            %   in the slot (except PDSCH, which is received using dataRx
            %   function of this class).

            % Check if current slot is a slot with DL symbols. For FDD,
            % there is no need to check as every slot is a DL slot. For
            % TDD, check if current slot has any DL symbols
            if(obj.DuplexMode ~=1 || (obj.DuplexMode == 1 && ...
                    ~isempty(find(obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, :) == obj.DLType, 1))))
                dlTTIType = [];
                dlTTIPDUs = {};
                
                csirsConfig = obj.CsirsConfig;
                % Check if CSI-RS is scheduled to be sent in this slot
                if strcmp(csirsConfig.CSIRSPeriod, 'on') || ~mod(obj.NumSlotsFrame*obj.SFN + ...
                        obj.CurrSlot - csirsConfig.CSIRSPeriod(2), csirsConfig.CSIRSPeriod(1))
                    dlTTIType(1) = hNRPhyInterface.CSIRSPDUType;
                    dlTTIPDUs{1} = csirsConfig;
                end
                obj.DlTTIRequestFcn(dlTTIType, dlTTIPDUs); % Send DL TTI request to Phy
            end
        end

        function csirsIndication(obj, cqiRBs)
            %csirsIndication Reception of DL channel quality measurement from Phy
            %   csirsIndication(OBJ, CQIRBS) receives the DL channel
            %   quality from Phy, measured on the configured CSI-RS for the
            %   UE.
            %   CQIRBS - It is a vector of size 'N', where 'N' is number of
            %   RBs in bandwidth. Value at index 'i' represents CQI value at
            %   RB-index 'i'.

            obj.ChannelQualityDL = cqiRBs;
        end

        function controlTx(obj)
            %controlTx Send BSR packet, PDSCH feedback and CQI report
            %   controlTx(OBJ) sends the buffer status report (BSR),
            %   feedback for PDSCH receptions, and DL channel quality
            %   information. These are sent out-of-band to gNB's MAC
            %   without the need of frequency resources

            % Send BSR if its transmission periodicity reached
            if obj.SlotsSinceBSR >= obj.BSRPeriodicity
                if obj.DuplexMode == 1 % TDD
                    % UL symbol is checked
                    if obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, obj.CurrSymbol+1) == obj.ULType % UL symbol
                        obj.SlotsSinceBSR = 0;
                        bsrTx(obj);
                    end
                else % For FDD, no need to check for UL symbol
                    obj.SlotsSinceBSR = 0;
                    bsrTx(obj);
                end
            end

            % Send PDSCH feedback (ACK/NACK), if scheduled
            symNumFrame = obj.CurrSlot*14 + obj.CurrSymbol;
            feedback = -1*ones(obj.NumHARQ, 1);
            for harqIdx=1:obj.NumHARQ
                if obj.PDSCHRxFeedback(harqIdx, 1) == symNumFrame % If any feedback is scheduled in current symbol
                    feedback(harqIdx) = obj.PDSCHRxFeedback(harqIdx, 2); % Set the feedback (ACK/NACK)
                    obj.PDSCHRxFeedback(harqIdx, :) = -1; % Clear the context
                end
            end
            % Construct packet information
            pktInfo.Packet = feedback;
            pktInfo.PacketType = obj.PDSCHFeedback;
            pktInfo.NCellID = obj.NCellID;
            pktInfo.RNTI = obj.RNTI;
            obj.TxOutofBandFcn(pktInfo); % Send the PDSCH feedback out-of-band to gNB's MAC

            % Send CQI report if the transmission periodicity has reached
            if obj.SlotsSinceCQIReport >= obj.CQIReportPeriodicity
                % Construct packet information
                pktInfo.PacketType = obj.CQIReport;
                pktInfo.NCellID = obj.NCellID;
                pktInfo.RNTI = obj.RNTI;
               
                if obj.DuplexMode == 1 % TDD
                    % UL symbol is checked
                    if obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, obj.CurrSymbol+1) == obj.ULType % UL symbol
                        obj.SlotsSinceCQIReport = 0;
                        pktInfo.Packet = obj.ChannelQualityDL;
                        obj.TxOutofBandFcn(pktInfo); % Send the CQI report out-of-band to gNB's MAC
                    end
                else % For FDD, no need to check for UL symbol
                    obj.SlotsSinceCQIReport = 0;
                    pktInfo.Packet = obj.ChannelQualityDL;
                    obj.TxOutofBandFcn(pktInfo); % Send the CQI report out-of-band to gNB's MAC
                end
            end
        end
        
        function controlRx(obj, pktInfo)
            %controlRx Receive callback for uplink and downlink grants for this UE

            pktType = pktInfo.PacketType;
            switch(pktType)
                case obj.ULGrant % Uplink grant received
                    uplinkGrant = pktInfo.Packet;
                    % Store the uplink grant at the corresponding Tx start
                    % symbol. The uplink grant is later used for PUSCH
                    % transmission at the transmission time defined by
                    % uplink grant
                    numSymFrame = obj.NumSlotsFrame * 14; % Number of symbols in 10 ms frame
                    txStartSymbol = mod((obj.CurrSlot + uplinkGrant.SlotOffset)*14 + uplinkGrant.StartSymbol, numSymFrame);
                    % Store the grant at the PUSCH start symbol w.r.t the 10 ms frame
                    obj.UplinkTxContext{txStartSymbol + 1} = uplinkGrant;
                    
                case obj.DLGrant % Downlink grant received
                    downlinkGrant = pktInfo.Packet;
                    % Store the downlink grant at the corresponding Rx start
                    % symbol. The downlink grant is later used for PDSCH
                    % reception at the reception time defined by
                    % downlink grant
                    numSymFrame = obj.NumSlotsFrame * 14; % Number of symbols in 10 ms frame
                    rxStartSymbol = mod((obj.CurrSlot + downlinkGrant.SlotOffset)*14 + downlinkGrant.StartSymbol, numSymFrame);
                    obj.DownlinkRxContext{rxStartSymbol + 1} = downlinkGrant; % Store the grant at the PDSCH start symbol w.r.t the 10 ms frame
            end
        end
      
        function buffStatus = getUEBufferStatus(obj)
            %getUEBufferStatus Get the pending buffer amount (bytes) on the UE
            %
            %   BUFFSTATUS = getUEBufferStatus(OBJ) Returns the pending
            %   buffer amount (bytes) on the UE
            %
            %   BUFFSTATUS - Represents the buffer size in bytes.

            buffStatus = sum(obj.LCGBufferStatus);
        end

        function cqiRBs = getChannelQualityStatus(obj)
            %getChannelQualityStatus Get DL CQI values for the RBs of bandwidth
            %
            %   CQIRBS = getChannelQualityStatus(OBJ) gets DL CQI values for
            %   the RBs of bandwidth.
            %
            %   CQIRBS - It is a vector of size 'N', where 'N' is number of
            %   RBs in bandwidth. Value at index 'i' represents CQI value at
            %   RB-index 'i'.
            cqiRBs = obj.ChannelQualityDL(:);
        end

        function updateChannelQualityStatus(obj, cqiRBs)
            %updateChannelQualityStatus Update DL CQI values for the RBs of bandwidth
            %
            %   updateChannelQualityStatus(OBJ, CQIRBS) updates DL CQI
            %   values for different RBs of bandwidth
            %
            %   CQIRBS - It is a vector of size 'N', where 'N' is number of
            %   RBs in bandwidth. Value at index 'i' represents CQI value
            %   at RB-index 'i'.

            obj.ChannelQualityDL = cqiRBs;
        end

        function lastNDIs = getLastNDIFlagHarq(obj, linkDir)
            %getLastNDIFlagHarq Return the last received NDI flag for the UL/DL HARQ processes

            % LASTNDISTATUS = getLastNDIFlagHarq(OBJ, LINKDIR) Returns last
            % received NDI flag value at UE, for all the HARQ processes of
            % the specified link direction, LINKDIR (Value 0 for DL and
            % Value 1 for UL).
            %
            % LASTNDISTATUS - It is a vector of integers of size equals to
            % the number of HARQ processes. It contains the last received
            % NDI flag value for the HARQ processes.

            lastNDIs = zeros(obj.NumHARQ,1);
            for i=1:obj.NumHARQ
                if linkDir % UL
                    lastNDIs(i) = obj.HARQNDIUL(i); % Read NDI of UL HARQ process
                else % DL
                    lastNDIs(i) = obj.HARQNDIDL(i); % Read NDI of DL HARQ process
                end
            end
        end

        function updateBufferStatus(obj, lcBufferStatus)
            %updateBufferStatus Update the buffer status of the logical channel
            %
            %   updateBufferStatus(OBJ, LCBUFFERSTATUS) Updates the buffer
            %   status of a logical channel based on information present in
            %   LCBUFFERSTATUS object
            %
            %   LCBUFFERSTATUS - Represents an object which contains the
            %   current buffer status of a logical channel. It contains the
            %   following properties:
            %       RNTI                    - UE's radio network temporary identifier
            %       LogicalChannelID        - Logical channel identifier
            %       BufferStatus            - Number of bytes in the logical
            %                                 channel's Tx buffer

            lcgID = -1;
            for i = 1:length(obj.LogicalChannelsConfig)
                if ~isempty(obj.LogicalChannelsConfig{i}) && (obj.LogicalChannelsConfig{i}.LCID == lcBufferStatus.LogicalChannelID)
                    lcgID = obj.LogicalChannelsConfig{i}.LCGID;
                    break;
                end
            end
            if lcgID == -1
                error('nr5g:hNRUEMAC:InvalidLCIDMapping', ['The logical channel with id ', lcBufferStatus.LogicalChannelID, ' is not mapped to any LCG id']);
            end
            % Subtract from the old buffer status report of the corresponding
            % logical channel
            lcgIdIndex = lcgID + 1; % Indexing starts from 1

            % Update the buffer status of LCG to which this logical channel
            % belongs to. Subtract the current logical channel buffer
            % amount and adding the new amount
            obj.LCGBufferStatus(lcgIdIndex) = obj.LCGBufferStatus(lcgIdIndex) -  ...
                obj.LCHBufferStatus(lcBufferStatus.LogicalChannelID) + lcBufferStatus.BufferStatus;

            % Update the new buffer status
            obj.LCHBufferStatus(lcBufferStatus.LogicalChannelID) = lcBufferStatus.BufferStatus;
        end

        function [throughputServing, goodputServing] = getTTIBytes(obj)
            %getTTIBytes Return the amount of throughput and goodput MAC bytes sent in current symbol
            %
            % [THROUGHPUTPUTSERVING GOODPUTPUTSERVING] =
            % getTTIBytes(OBJ) returns the amount of throughput and
            % goodput bytes sent in the TTI which starts at current
            % symbol. It also clears the context of returned information.
            %
            % THROUGHPUTPUTSERVING represents the amount of MAC bytes sent
            % as per the uplink assignment which starts at this symbol
            %
            % GOODPUTPUTSERVING represents the amount of new-Tx MAC bytes
            % sent as per the uplink assignment which starts at this
            % symbol
            %
            % Throughput and goodput bytes are same, if it is new
            % transmission. For retransmission, goodput is zero

             throughputServing = obj.CurrTxThroughputBytes;
             obj.CurrTxThroughputBytes = 0;
             goodputServing = obj.CurrTxGoodputBytes;
             obj.CurrTxGoodputBytes = 0;
        end
    end

    methods (Access = private)
        function [pduLen, type] = sendMACPDU(obj, uplinkGrant)
            %sendMACPDU Send MAC PDU as per the parameters of the uplink grant
            % Uplink grant and its parameters were sent beforehand by gNB
            % in uplink grant. Based on the NDI received in the uplink
            % grant, either the packet in the HARQ buffer would be retransmitted
            % or a new MAC packet would be sent

            macPDU = [];
            % Populate PUSCH information to be sent to Phy, along with the MAC
            % PDU
            puschInfo = hNRPUSCHInfo;
            RBGAllocationBitmap = uplinkGrant.RBGAllocationBitmap;
            ULGrantRBs = -1*ones(obj.NumPUSCHRBs, 1); % To store RB indices of UL grant
            for RBGIndex = 0:(length(RBGAllocationBitmap)-1) % Get RB indices of UL grant
                if RBGAllocationBitmap(RBGIndex+1)
                    % If the last RBG of BWP is assigned, then it might
                    % not have the same number of RBs as other RBG
                    startRBInRBG = obj.RBGSizeUL*RBGIndex;
                    if RBGIndex == (length(RBGAllocationBitmap)-1)
                        ULGrantRBs(startRBInRBG + 1 : end) =  ...
                            startRBInRBG : obj.NumPUSCHRBs-1 ;
                    else
                        ULGrantRBs((startRBInRBG + 1) : (startRBInRBG + obj.RBGSizeUL)) =  ...
                            startRBInRBG : (startRBInRBG + obj.RBGSizeUL -1);
                    end
                end
            end
            ULGrantRBs = ULGrantRBs(ULGrantRBs >= 0);
            puschInfo.PUSCHConfig.PRBSet = ULGrantRBs;
            % Get the corresponding row from the mcs table
            mcsInfo = obj.MCSTableUL(uplinkGrant.MCS + 1, :);
            modSchemeBits = mcsInfo(1); % Bits per symbol for modulation scheme (stored in column 1)
            puschInfo.TargetCodeRate = mcsInfo(2)/1024; % Coderate (stored in column 2)
            % Modulation scheme and corresponding bits/symbol
            fullmodlist = ["pi/2-BPSK", "BPSK", "QPSK", "16QAM", "64QAM", "256QAM"]';
            qm = [1 1 2 4 6 8];
            modScheme = fullmodlist(modSchemeBits == qm); % Get modulation scheme string
            puschInfo.PUSCHConfig.Modulation = modScheme(1);
            puschInfo.PUSCHConfig.RNTI = obj.RNTI;
            puschInfo.PUSCHConfig.SymbolAllocation = [uplinkGrant.StartSymbol uplinkGrant.NumSymbols];
            puschInfo.PUSCHConfig.NID = obj.NCellID;
            puschInfo.NSlot = obj.CurrSlot;
            puschInfo.HARQId = uplinkGrant.HARQId;
            puschInfo.RV = uplinkGrant.RV;
            if obj.SchedulingType % Symbol based scheduling
                puschInfo.PUSCHConfig.MappingType = 'B';
            end
            carrierConfig = nrCarrierConfig;
            carrierConfig.NSizeGrid = obj.NumPUSCHRBs;
            carrierConfig.SubcarrierSpacing = obj.SCS;
            carrierConfig.NSlot = puschInfo.NSlot;
            [~, puschIndicesInfo] = nrPUSCHIndices(carrierConfig, puschInfo.PUSCHConfig); % Calculate PUSCH indices
            tbs = nrTBS(puschInfo.PUSCHConfig.Modulation, puschInfo.PUSCHConfig.NumLayers, length(ULGrantRBs), ...
                puschIndicesInfo.NREPerPRB, puschInfo.TargetCodeRate); % TBS calcuation
            pduLen = floor(tbs/8); % In bytes
            puschInfo.TBS = pduLen;

            uplinkGrantHARQId =  uplinkGrant.HARQId;
            lastNDI = obj.HARQNDIUL(uplinkGrantHARQId+1); % Last receive NDI for this HARQ process
            if uplinkGrant.NDI ~= lastNDI
                % NDI has been toggled, so send a new MAC packet. This acts
                % as an ACK for the last sent packet of this HARQ process,
                % in addition to acting as an uplink grant
                type = 'newTx';

                % Generate MAC PDU
                macPDU = constructMACPDU(obj, floor(tbs/8));

                % Store the uplink grant NDI for this HARQ process which
                % will be used in taking decision of 'newTx' or 'reTx' when
                % an uplink grant for the same HARQ process comes
                obj.HARQNDIUL(uplinkGrantHARQId+1) = uplinkGrant.NDI; % Update NDI
                obj.TBSizeUL(uplinkGrantHARQId+1) = pduLen;
            else
                type = 'reTx';
                pduLen = obj.TBSizeUL(uplinkGrantHARQId+1);
            end
            obj.TxDataRequestFcn(puschInfo, macPDU);
        end

        function rxRequestToPhy(obj, downlinkGrant)
            % Send Rx request to Phy

            pdschInfo = hNRPDSCHInfo; % Information to be passed to Phy for PDSCH reception
            RBGAllocationBitmap = downlinkGrant.RBGAllocationBitmap;
            DLGrantRBs = -1*ones(obj.NumPDSCHRBs, 1); % To store RB indices of DL grant
            for RBGIndex = 0:(length(RBGAllocationBitmap)-1) % Get RB indices of DL grant
                if RBGAllocationBitmap(RBGIndex+1) == 1
                    startRBInRBG = obj.RBGSizeDL * RBGIndex;
                    % If the last RBG of BWP is assigned, then it might
                    % not have the same number of RBs as other RBG
                    if RBGIndex == (length(RBGAllocationBitmap)-1)
                        DLGrantRBs((startRBInRBG+1) : end) =  ...
                            startRBInRBG : obj.NumPDSCHRBs-1 ;
                    else
                        DLGrantRBs((startRBInRBG+1) : (startRBInRBG + obj.RBGSizeDL)) =  ...
                            startRBInRBG : (startRBInRBG + obj.RBGSizeDL -1) ;
                    end
                end
            end
            DLGrantRBs = DLGrantRBs(DLGrantRBs >= 0);
            pdschInfo.PDSCHConfig.PRBSet = DLGrantRBs;
            % Get the corresponding row from the mcs table
            mcsInfo = obj.MCSTableDL(downlinkGrant.MCS + 1, :);
            modSchemeBits = mcsInfo(1); % Bits per symbol for modulation scheme(stored in column 1)
            pdschInfo.TargetCodeRate = mcsInfo(2)/1024; % Coderate (stored in column 2)
            % Modulation scheme and corresponding bits/symbol
            fullmodlist = ["pi/2-BPSK", "BPSK", "QPSK", "16QAM", "64QAM", "256QAM"]';
            qm = [1 1 2 4 6 8];
            modScheme = fullmodlist((modSchemeBits == qm)); % Get modulation scheme string
            pdschInfo.PDSCHConfig.Modulation = modScheme(1);
            pdschInfo.PDSCHConfig.RNTI = obj.RNTI;
            pdschInfo.PDSCHConfig.NID = obj.NCellID;
            pdschInfo.PDSCHConfig.SymbolAllocation = [downlinkGrant.StartSymbol downlinkGrant.NumSymbols];
            pdschInfo.NSlot = obj.CurrSlot;
            
            carrierConfig = nrCarrierConfig;
            carrierConfig.NSizeGrid = obj.NumPDSCHRBs;
            carrierConfig.SubcarrierSpacing = obj.SCS;
            carrierConfig.NSlot = pdschInfo.NSlot;
            if obj.HARQNDIDL(downlinkGrant.HARQId+1) ~= downlinkGrant.NDI % NDI toggled: new transmission
                if obj.SchedulingType % Symbol based scheduling
                    pdschInfo.PDSCHConfig.MappingType = 'B';
                end
                % Calculate TBS
                [~, pdschIndicesInfo] = nrPDSCHIndices(carrierConfig, pdschInfo.PDSCHConfig); % Calculate PDSCH indices
                tbs = nrTBS(pdschInfo.PDSCHConfig.Modulation, pdschInfo.PDSCHConfig.NumLayers, length(DLGrantRBs), ...
                    pdschIndicesInfo.NREPerPRB, pdschInfo.TargetCodeRate); % Calculate the transport block size
                pdschInfo.TBS = floor(tbs/8);
                obj.TBSizeDL(downlinkGrant.HARQId+1) = pdschInfo.TBS;
            else % Retransmission
                % Use TBS of the original transmission
                pdschInfo.TBS = obj.TBSizeDL(downlinkGrant.HARQId+1);
            end

            obj.HARQNDIDL(downlinkGrant.HARQId+1) = downlinkGrant.NDI; % Update the stored NDI for HARQ process
            pdschInfo.HARQId = downlinkGrant.HARQId;
            pdschInfo.RV = downlinkGrant.RV;

            % Call Phy to start receiving PDSCH
            obj.RxDataRequestFcn(pdschInfo);
        end

        function bsrTx(obj)
            %bsrTx Construct and send a BSR

            % Construct BSR
            subPDU = constructBSR(obj);
            if ~isempty(subPDU)
                % Construct packet information
                pktInfo.Packet = subPDU;
                pktInfo.PacketType = obj.BSR;
                pktInfo.NCellID = obj.NCellID;
                pktInfo.RNTI = obj.RNTI;
                obj.TxOutofBandFcn(pktInfo); % Send the BSR out-of-band to gNB's MAC
            end
        end

        function subPDU = constructBSR(obj, varargin)
            %constructBSR Return the subPDU which contains BSR in its payload
            %
            %   SUBPDU = constructBSR(OBJ) Constructs the subPDU which
            %   contains BSR in its payload. It will be invoked for Periodic
            %   and Regular BSR type
            %
            %   SUBPDU = constructBSR(OBJ, PADDINGBYTES) Constructs the subPDU
            %   which contains BSR in its payload. It will be invoked for
            %   Padding BSR type
            %
            %   PADDINGBYTES Determines the size and type of BSR to
            %   construct

            %   Get the index of the LCGs with data (index starts from 1)
            lcgIndexWithData = find(obj.LCGBufferStatus);
            numLCGWithData = numel(lcgIndexWithData);

            if nargin == 1
                % For Periodic and Regular BSR type
                if numLCGWithData > 1
                    % Long BSR
                    lcid = 62;
                else
                    % Short BSR
                    lcid = 61;
                end
            else
                % For Padding BSR type numBytesLongBSR = (number of LCGs
                % which have data available * 1) + 1 byte LCG bitmap + 2
                % byte MAC subheader
                numBytesLongBSR = numLCGWithData + 3;
                paddingBytes = varargin{1};
                if paddingBytes >= 2 && paddingBytes <  numBytesLongBSR
                    if numLCGWithData > 1
                        if paddingBytes == 2
                            lcid = 59; % Short truncated BSR
                        else
                            lcid = 60; % Long truncated BSR
                        end
                    else
                        lcid = 61; % Short BSR
                    end
                elseif paddingBytes >= numBytesLongBSR
                    lcid = 62; % Long BSR
                else
                    % If paddingBytes <= 1
                    subPDU = [];
                    return;
                end
            end

            % Determine to which LCGs buffer status has to report
            if lcid == 61 && numLCGWithData == 0
                % If there is no data available at UE
                lcgIdList = 0;
                bufferSizeList = 0;
            else
                lcgIdList = zeros(numLCGWithData,1);
                bufferSizeList = zeros(numLCGWithData,1);
                for i = 1:numel(lcgIndexWithData)
                    % LCG id value start from 0 to 7. So, index-1 results in the
                    % LCG id
                    lcgIdList(i) = lcgIndexWithData(i)-1;
                    bufferSizeList(i) = obj.LCGBufferStatus(lcgIndexWithData(i));
                end
            end

            % Generate the buffer status report control element
            if lcid == 60
                % Subtract 2 bytes from available padding bytes for
                % subheader
                bsr = hNRMACBSR(lcid, lcgIdList, bufferSizeList, paddingBytes - 2);
            else
                bsr = hNRMACBSR(lcid, lcgIdList, bufferSizeList);
            end

            % Generate the subPDU
            subPDU = hNRMACSubPDU(lcid, bsr, obj.ULType);
        end
        
        function populateTDDConfiguration(obj, simParameters)
            %populateTDDConfiguration Validate TDD configuration and
            %populate the properties

            % Validate the DL-UL pattern duration
            validDLULPeriodicity{1} =  { 1 2 5 10 }; % Applicable for scs = 15 kHz
            validDLULPeriodicity{2} =  { 0.5 1 2 2.5 5 10 }; % Applicable for scs = 30 kHz
            validDLULPeriodicity{3} =  { 0.5 1 1.25 2 2.5 5 10 }; % Applicable for scs = 60 kHz
            validDLULPeriodicity{4} =  { 0.5 0.625 1 1.25 2 2.5 5 10}; % Applicable for scs = 120 kHz
            validSCS = [15 30 60 120];
            if ~ismember(obj.SCS, validSCS)
                error('nr5g:hNRUEMAC:InvalidSCS','The subcarrier spacing ( %d ) must be one of the set (%s).',obj.SCS, sprintf(repmat('%d ', 1, length(validSCS)), validSCS));
            end
            numerology = find(validSCS==obj.SCS, 1, 'first');
            validSet = cell2mat(validDLULPeriodicity{numerology});

            if isfield(simParameters, 'DLULPeriodicity')
                validateattributes(simParameters.DLULPeriodicity, {'numeric'}, {'nonempty'}, 'simParameters.DLULPeriodicity', 'DLULPeriodicity');
                if ~ismember(simParameters.DLULPeriodicity, cell2mat(validDLULPeriodicity{numerology}))
                    error('nr5g:hNRUEMAC:InvalidNumDLULSlots','DLULPeriodicity (%.3f) must be one of the set (%s).', ...
                        simParameters.DLULPeriodicity, sprintf(repmat('%.3f ', 1, length(validSet)), validSet));
                end
                numSlotsDLDULPattern = simParameters.DLULPeriodicity/obj.SlotDuration;
                
                % Validate the number of full DL slots at the beginning of DL-UL pattern
                validateattributes(simParameters.NumDLSlots, {'numeric'}, {'nonempty'}, 'simParameters.NumDLSlots', 'NumDLSlots');
                if~(simParameters.NumDLSlots <= (numSlotsDLDULPattern-1))
                    error('nr5g:hNRUEMAC:InvalidNumDLSlots','Number of full DL slots (%d) must be less than numSlotsDLDULPattern(%d).', ...
                        simParameters.NumDLSlots, numSlotsDLDULPattern);
                end

                % Validate the number of full UL slots at the end of DL-UL pattern
                validateattributes(simParameters.NumULSlots, {'numeric'}, {'nonempty'}, 'simParameters.NumULSlots', 'NumULSlots');
                if~(simParameters.NumULSlots <= (numSlotsDLDULPattern-1))
                    error('nr5g:hNRUEMAC:InvalidNumULSlots','Number of full UL slots (%d) must be less than numSlotsDLDULPattern(%d).', ...
                        simParameters.NumULSlots, numSlotsDLDULPattern);
                end
                
                if~(simParameters.NumDLSlots + simParameters.NumULSlots  <= (numSlotsDLDULPattern-1))
                    error('nr5g:hNRUEMAC:InvalidNumDLULSlots','Sum of full DL and UL slots(%d) must be less than numSlotsDLDULPattern(%d).', ...
                        simParameters.NumDLSlots + simParameters.NumULSlots, numSlotsDLDULPattern);
                end
                
                % Validate that there must be some UL resources in the DL-UL pattern
                if obj.SchedulingType == 0 && simParameters.NumULSlots == 0
                    error('nr5g:hNRUEMAC:InvalidNumULSlots','Number of full UL slots (%d) must be greater than {0} for slot based scheduling', simParameters.NumULSlots);
                end
                if obj.SchedulingType == 1 && simParameters.NumULSlots == 0 && simParameters.NumULSyms == 0
                    error('nr5g:hNRUEMAC:InvalidULResources','DL-UL pattern must contain UL resources. Set NumULSlots(%d) or NumULSyms(%d) to a positive integer).', ...
                        simParameters.NumULSlots, simParameters.NumULSyms);
                end
                % Validate that there must be some DL resources in the DL-UL pattern
                if(simParameters.NumDLSlots == 0 && simParameters.NumDLSyms == 0)
                    error('nr5g:hNRUEMAC:InvalidDLResources','DL-UL pattern must contain DL resources. Set NumDLSlots(%d) or NumDLSyms(%d) to a positive integer).', ...
                        simParameters.NumDLSlots, simParameters.NumDLSyms);
                end
                
                obj.NumDLULPatternSlots = simParameters.DLULPeriodicity/obj.SlotDuration;
                obj.NumDLSlots = simParameters.NumDLSlots;
                obj.NumULSlots = simParameters.NumULSlots;
                obj.NumDLSyms = simParameters.NumDLSyms;
                obj.NumULSyms = simParameters.NumULSyms;
                
                % All the remaining symbols in DL-UL pattern are assumed to
                % be guard symbols
                obj.GuardDuration = (obj.NumDLULPatternSlots * 14) - ...
                    (((obj.NumDLSlots + obj.NumULSlots)*14) + ...
                    obj.NumDLSyms + obj.NumULSyms);
            end
        end
    end
end