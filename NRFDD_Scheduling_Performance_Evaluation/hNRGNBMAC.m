classdef hNRGNBMAC < hNRMAC
    %hNRGNBMAC Implements gNB MAC functionality
    %   The class implements the gNB MAC and its interactions with RLC and Phy
    %   for Tx and Rx chains. Both, frequency division duplex (FDD) and time
    %   division duplex (TDD) modes are supported. It contains scheduler entity
    %   which takes care of uplink (UL) and downlink (DL) scheduling. Using the
    %   output of UL and DL schedulers, it implements transmission of UL and DL
    %   assignments. UL and DL assignments are sent out-of-band from MAC itself
    %   (without using frequency resources and with guaranteed reception), as
    %   physical downlink control channel (PDCCH) is not modeled. Physical
    %   uplink control channel (PUCCH) is not modeled too, so the control
    %   packets from UEs: buffer status report (BSR), PDSCH feedback, and DL
    %   channel quality report are also received out-of-band. Hybrid automatic
    %   repeat request (HARQ) control mechanism to enable retransmissions is
    %   implemented. MAC controls the HARQ processes residing in physical
    %   layer
    
    %   Copyright 2019-2020 The MathWorks, Inc.
    
    properties
        %UEs RNTIs of the UEs connected to the gNB
        UEs {mustBeInteger, mustBeInRange(UEs, 1, 65519)};
        
        %SCS Subcarrier spacing used. The default value is 15 kHz
        SCS (1, 1) {mustBeMember(SCS, [15, 30, 60, 120, 240])} = 15;
        
        %Scheduler Scheduler object
        Scheduler
        
        %DownlinkTxContext Tx context used for PDSCH transmissions
        % N-by-P cell array where is N is number of UEs and 'P' is number of
        % symbols in a 10 ms frame. An element at index (i, j) stores the
        % downlink grant for UE 'i' with PDSCH transmission scheduled to
        % start at symbol 'j' from the start of the frame. If no PDSCH
        % transmission scheduled, cell element is empty
        DownlinkTxContext
        
        %UplinkRxContext Rx context used for PUSCH reception
        % N-by-P cell array where 'N' is the number of UEs and 'P' is the
        % number of symbols in a 10 ms frame. It stores uplink resource
        % assignment details done to UEs. This is used by gNB in the
        % reception of uplink packets. An element at position (i, j) stores
        % the uplink grant corresponding to a PUSCH reception expected from
        % UE 'i' starting at symbol 'j' from the start of the frame. If
        % there no assignment, cell element is empty
        UplinkRxContext
        
        %RxContextFeedback Rx context at gNB used for feedback reception (ACK/NACK) of PDSCH transmissions
        % N-by-P-by-K cell array where 'N' is the number of UEs, 'P' is the
        % number of symbols in a 10 ms frame and K is the number of
        % downlink HARQ processes. This is used by gNB in the reception of
        % ACK/NACK from UEs. An element at index (i, j, k) in this array,
        % stores the downlink grant for the UE with RNTI 'i' where
        % 'j' is the symbol number from the start of the frame where
        % ACK/NACK is expected for UE's HARQ process number 'k'
        RxContextFeedback
        
        %NumHARQ Number of HARQ processes. The default value is 16
        NumHARQ (1, 1) {mustBeInteger, mustBeInRange(NumHARQ, 1, 16)} = 16;
        
        %CsirsConfig CSI-RS resource configuration for all the UEs
        % It is an object of type nrCSIRSConfig and contains the
        % CSI-RS resource configured for the UEs. All UEs are assumed to have
        % same CSI-RS resource configured
        CsirsConfig
        
        %CurrDLAssignments DL assignments done by scheduler on running at current symbol
        % This information is used for logging. If scheduler did not run or did not do any
        % DL assignment at the current symbol this is empty
        CurrDLAssignments = {};
        
        %CurrULAssignments UL assignments done by scheduler on running at current symbol
        % This information is used for logging. If scheduler did not run or did not do any
        % UL assignment at the current symbol this is empty
        CurrULAssignments = {};
        
        %CurrTxThroughputBytes Number of MAC bytes sent in current symbol for each UE
        % Vector of length 'N', where N is the number of UEs
        CurrTxThroughputBytes
        
        %CurrTxGoodputBytes Number of new transmission MAC bytes sent in current symbol for each UE
        % Vector of length 'N', where N is the number of UEs. Value is equal to
        % LastTxThroughputBytes if it was a new transmission, 0 otherwise
        CurrTxGoodputBytes
    end
    
    methods
        function obj = hNRGNBMAC(simParameters)
            %hNRGNBMAC Construct a gNB MAC object
            %
            % simParameters is a structure including the following fields:
            % NCellID                  - Physical cell ID. Values: 0 to 1007 (TS 38.211, sec 7.4.2.1)
            % NumUEs                   - Number of UEs in the cell
            % SCS                      - Subcarrier spacing used
            % NumLogicalChannels       - Number of logical channels configured
            % NumHARQ                  - Number of HARQ processes
            % NumRBs                   - Number of RBs in the bandwidth
            % CSIRSPeriod              - CSI-RS slot periodicity and offset
            % CSIRSRowNumber           - Row number of CSI-RS resource
            % CSIRSDensity             - CSI-RS resource frequency density ('one' (default), 'three', 'dot5even', 'dot5odd')
            
            obj.MACType = 0; % gNB MAC type
            if isfield(simParameters, 'NCellID')
                obj.NCellID = simParameters.NCellID;
            end
            if isfield(simParameters, 'SCS')
                obj.SCS = simParameters.SCS;
            end
            % Validate the number of UEs
            validateattributes(simParameters.NumUEs, {'numeric'}, {'nonempty', ...
                'integer', 'scalar', '>', 0, '<=', 65519}, 'simParameters.NumUEs', 'NumUEs');
            % UEs are assumed to have sequential radio network temporary
            % identifiers (RNTIs) from 1 to NumUEs
            obj.UEs = 1:simParameters.NumUEs;
            
            numUEs = length(obj.UEs);
            obj.SlotDuration = 1/(obj.SCS/15); % In ms
            obj.NumSlotsFrame = 10/obj.SlotDuration; % Number of slots in a 10 ms frame
            obj.ElapsedTimeSinceLastLCP = zeros(numUEs, 1);
            if isfield(simParameters, 'NumHARQ')
                obj.NumHARQ = simParameters.NumHARQ;
            end
            obj.CurrTxThroughputBytes = zeros(numUEs, 1);
            obj.CurrTxGoodputBytes = zeros(numUEs, 1);
            % Configuration of logical channels for UEs
            obj.LogicalChannelsConfig = cell(numUEs, obj.MaxLogicalChannels);
            obj.LCHBjList = zeros(numUEs, obj.MaxLogicalChannels);
            obj.LCHBufferStatus = zeros(numUEs, obj.MaxLogicalChannels);
            
            % Set non zero powered (NZP) CSI-RS configuration. All the UEs
            % are assumed to use same configuration
            csirs = nrCSIRSConfig;
            csirs.NID = obj.NCellID; % Set cell id as scrambling identity
            if isfield(simParameters, 'CSIRSPeriod')
                csirs.CSIRSPeriod = simParameters.CSIRSPeriod;
            end
            if isfield(simParameters, 'CSIRSDensity')
                csirs.Density = simParameters.CSIRSDensity;
            end
            if isfield(simParameters, 'NumRBs')
                csirs.NumRB = simParameters.NumRBs;
            end
            if isfield(simParameters, 'CSIRSRowNumber')
                csirs.RowNumber = simParameters.CSIRSRowNumber;
            else
                % Possible CSI-RS resource row numbers for single transmit antenna case are 1 and 2
                csirs.RowNumber = 2;
            end

            obj.CsirsConfig = csirs;
        end
        
        function run(obj)
            %run Run the gNB MAC layer operations
            
            % Run schedulers (UL and DL) and send the resource assignment information to the UEs.
            % Resource assignments returned by a scheduler (either UL or
            % DL) is empty, if either scheduler was not scheduled to run at
            % the current time or no resource got assigned
            resourceAssignmentsUL = runULScheduler(obj);
            resourceAssignmentsDL = runDLScheduler(obj);
            % Check if UL/DL assignments are done
            if ~isempty(resourceAssignmentsUL) || ~isempty(resourceAssignmentsDL)
                % Construct and send UL assignments and DL assignments to
                % UEs. UL and DL assignments are assumed to be sent
                % out-of-band without using any frequency-time resources,
                % from gNB's MAC to UE's MAC
                controlTx(obj, resourceAssignmentsUL, resourceAssignmentsDL);
            end
            
            % Send request to Phy for non-data transmissions scheduled in
            % this slot (currently only CSI-RS supported). Send it at the
            % first symbol of the slot for all the non-data transmissions
            % scheduled in the entire slot
            if obj.Scheduler.CurrSymbol == 0
                dlTTIRequest(obj);
            end
            
            % Send data Tx request to Phy for transmission(s) which is(are)
            % scheduled to start at current symbol. Construct and send the
            % DL MAC PDUs scheduled for current symbol to Phy
            dataTx(obj);
            
            % Send data Rx request to Phy for reception(s) which is(are) scheduled to start at current symbol
            dataRx(obj);
        end
        
        function addScheduler(obj, scheduler)
            %addScheduler Add scheduler object to MAC
            %   addScheduler(OBJ, SCHEDULER) adds the scheduler to MAC.
            %
            %   SCHEDULER Scheduler object.
            
            obj.Scheduler = scheduler;
            % Create Tx/Rx contexts
            obj.UplinkRxContext = cell(length(obj.UEs), obj.NumSlotsFrame * 14);
            obj.DownlinkTxContext = cell(length(obj.UEs), obj.NumSlotsFrame * 14);
            obj.RxContextFeedback = cell(length(obj.UEs), obj.NumSlotsFrame*14, obj.Scheduler.NumHARQ);
            
            % Set the MCS tables as matrices inside scheduler
            obj.Scheduler.MCSTableUL = getMCSTableUL(obj);
            obj.Scheduler.MCSTableDL = getMCSTableDL(obj);
        end
        
        function symbolType = currentSymbolType(obj)
            %currentSymbolType Get current running symbol type: DL/UL/Guard
            %   SYMBOLTYPE = currentSymbolType(OBJ) returns the symbol type of
            %   current symbol.
            %
            %   SYMBOLTYPE is the symbol type. Value 0, 1 and 2 represent
            %   DL, UL, guard symbol respectively.
            
            symbolType = currentSymbolType(obj.Scheduler);
        end
        
        function advanceTimer(obj, numSym)
            %advanceTimer Advance the timer ticks by specified number of symbols
            %   advanceTimer(OBJ, NUMSYM) advances the timer by specified
            %   number of symbols.
            %   NUMSYM is the number of symbols to be advanced. Value must
            %   be 14 for slot based scheduling and 1 for symbol based scheduling.
            
            obj.Scheduler.CurrSymbol = mod(obj.Scheduler.CurrSymbol + numSym, 14);
            if obj.Scheduler.CurrSymbol == 0 % Reached slot boundary
                obj.ElapsedTimeSinceLastLCP  = obj.ElapsedTimeSinceLastLCP + obj.SlotDuration;
                % Update current slot number in the 10 ms frame
                obj.Scheduler.CurrSlot = mod(obj.Scheduler.CurrSlot + 1, obj.NumSlotsFrame);
                if obj.Scheduler.CurrSlot == 0 % Reached frame boundary
                    obj.Scheduler.SFN = mod(obj.Scheduler.SFN + 1, 1024);
                end
                if obj.Scheduler.DuplexMode == 1 % TDD
                    % Update current slot number in DL-UL pattern
                    obj.Scheduler.CurrDLULSlotIndex = mod(obj.Scheduler.CurrDLULSlotIndex + 1, obj.Scheduler.NumDLULPatternSlots);
                end
            end
        end
        
        function resourceAssignments = runULScheduler(obj)
            %runULScheduler Run the UL scheduler
            %
            %   RESOURCEASSIGNMENTS = runULScheduler(OBJ) runs the UL scheduler
            %   and returns the resource assignments structure array.
            %
            %   RESOURCEASSIGNMENTS is a structure that contains the
            %   UL resource assignments information.
            
            resourceAssignments = runULScheduler(obj.Scheduler);
            % Set Rx context at gNB by storing the UL grants. It is set at
            % symbol number in the 10 ms frame, where UL reception is
            % expected to start. gNB uses this to anticipate the reception
            % start time of uplink packets
            for i = 1:length(resourceAssignments)
                grant = resourceAssignments{i};
                slotNum = mod(obj.Scheduler.CurrSlot + grant.SlotOffset, obj.NumSlotsFrame); % Slot number in the frame for the grant
                obj.UplinkRxContext{grant.RNTI, slotNum*14 + grant.StartSymbol + 1} = grant;
            end
            obj.CurrDLAssignments = resourceAssignments;
        end
        
        function resourceAssignments = runDLScheduler(obj)
            %runDLScheduler Run the DL scheduler
            %
            %   RESOURCEASSIGNMENTS = runDLScheduler(OBJ) runs the DL scheduler
            %   and returns the resource assignments structure array.
            %
            %   RESOURCEASSIGNMENTS is a structure that contains the
            %   DL resource assignments information.
            
            resourceAssignments = runDLScheduler(obj.Scheduler);
            % Update Tx context at gNB by storing the DL grants at the
            % symbol number (in the 10 ms frame) where DL transmission
            % is scheduled to start
            for i = 1:length(resourceAssignments)
                grant = resourceAssignments{i};
                slotNum = mod(obj.Scheduler.CurrSlot + grant.SlotOffset, obj.NumSlotsFrame); % Slot number in the frame for the grant
                obj.DownlinkTxContext{grant.RNTI, slotNum*14 + grant.StartSymbol + 1} = grant;
            end
            obj.CurrULAssignments = resourceAssignments;
        end
        
        function dataTx(obj)
            % dataTx Construct and send the DL MAC PDUs scheduled for current symbol to Phy
            %
            % dataTx(OBJ) Based on the downlink grants sent earlier, if
            % current symbol is the start symbol of downlink transmissions then
            % send the DL MAC PDUs to Phy
            
            obj.CurrTxThroughputBytes = zeros(length(obj.UEs), 1);
            obj.CurrTxGoodputBytes = zeros(length(obj.UEs), 1);
            
            symbolNumFrame = obj.Scheduler.CurrSlot*14 + obj.Scheduler.CurrSymbol; % Current symbol number in the 10 ms frame
            for rnti = 1:length(obj.UEs) % For all UEs
                downlinkGrant = obj.DownlinkTxContext{rnti, symbolNumFrame + 1};
                % If there is any downlink grant corresponding to which a transmission is scheduled at the current symbol
                if ~isempty(downlinkGrant)
                    % Construct and send MAC PDU in adherence to downlink grant
                    % properties
                    [sentPDULen, type] = sendMACPDU(obj, rnti, downlinkGrant);
                    obj.DownlinkTxContext{rnti, symbolNumFrame + 1} = []; % Tx done. Clear the context
                    
                    % Calculate the slot number where PDSCH ACK/NACK is
                    % expected
                    feedbackSlot = mod(obj.Scheduler.CurrSlot + downlinkGrant.FeedbackSlotOffset, obj.NumSlotsFrame);
                    
                    % For TDD, the selected symbol at which feedback would
                    % be transmitted by UE is the first UL symbol in
                    % feedback slot. For FDD, it is the first symbol in the
                    % feedback slot (as every symbol is UL)
                    if obj.Scheduler.DuplexMode == 1 % TDD
                        feedbackSlotDLULIdx = mod(obj.Scheduler.CurrDLULSlotIndex + downlinkGrant.FeedbackSlotOffset, obj.Scheduler.NumDLULPatternSlots);
                        feedbackSlotPattern = obj.Scheduler.DLULSlotFormat(feedbackSlotDLULIdx + 1, :);
                        feedbackSym = (find(feedbackSlotPattern == obj.ULType, 1, 'first')) - 1; % Check for location of first UL symbol in the feedback slot
                    else % FDD
                        feedbackSym = 0;  % First symbol
                    end
                    
                    % Update the context for this UE at the symbol number
                    % w.r.t start of the frame where feedback is expected
                    % to be received
                    obj.RxContextFeedback{rnti, ((feedbackSlot*14) + feedbackSym + 1), downlinkGrant.HARQId + 1} = downlinkGrant;
                    
                    obj.CurrTxThroughputBytes(rnti) = sentPDULen;
                    if(strcmp(type, 'newTx'))
                        obj.CurrTxGoodputBytes(rnti) = sentPDULen;
                    end
                end
            end
        end
        
        function controlTx(obj, resourceAssignmentsUL, resourceAssignmentsDL)
            %controlTx Construct and send the uplink and downlink assignments to the UEs
            %
            %   controlTx(obj, RESOURCEASSIGNMENTSUL, RESOURCEASSIGNMENTSDL)
            %   Based on the resource assignments done by uplink and
            %   downlink scheduler, send assignments to UEs. UL and DL
            %   assignments are sent out-of-band without the need of
            %   frequency resources.
            %
            %   RESOURCEASSIGNMENTSUL is a cell array of structures that
            %   contains the UL resource assignments information.
            %
            %   RESOURCEASSIGNMENTSDL is a cell array of structures that
            %   contains the DL resource assignments information.
            
            % Construct and send uplink grants
            if ~isempty(resourceAssignmentsUL)
                uplinkGrant = hNRUplinkGrantFormat;
                for i = 1:length(resourceAssignmentsUL) % For each UL assignment
                    grant = resourceAssignmentsUL{i};
                    uplinkGrant.RBGAllocationBitmap = grant.RBGAllocationBitmap;
                    uplinkGrant.StartSymbol = grant.StartSymbol;
                    uplinkGrant.NumSymbols = grant.NumSymbols;
                    uplinkGrant.SlotOffset = grant.SlotOffset;
                    uplinkGrant.MCS = grant.MCS;
                    uplinkGrant.NDI = grant.NDI;
                    uplinkGrant.RV = grant.RV;
                    uplinkGrant.HARQId = grant.HARQId;
                    
                    % Construct packet information
                    pktInfo.Packet = uplinkGrant;
                    pktInfo.PacketType = obj.ULGrant;
                    pktInfo.NCellID = obj.NCellID;
                    pktInfo.RNTI = grant.RNTI;
                    obj.TxOutofBandFcn(pktInfo); % Send the UL grant out-of-band to UE's MAC
                end
            end
            
            % Construct and send downlink grants
            if ~isempty(resourceAssignmentsDL)
                downlinkGrant = hNRDownlinkGrantFormat;
                for i = 1:length(resourceAssignmentsDL) % For each DL assignment
                    grant = resourceAssignmentsDL{i};
                    downlinkGrant.RBGAllocationBitmap = grant.RBGAllocationBitmap;
                    downlinkGrant.StartSymbol = grant.StartSymbol;
                    downlinkGrant.NumSymbols = grant.NumSymbols;
                    downlinkGrant.SlotOffset = grant.SlotOffset;
                    downlinkGrant.MCS = grant.MCS;
                    downlinkGrant.NDI = grant.NDI;
                    downlinkGrant.RV = grant.RV;
                    downlinkGrant.HARQId = grant.HARQId;
                    downlinkGrant.FeedbackSlotOffset = grant.FeedbackSlotOffset;
                    
                    % Construct packet information
                    pktInfo.Packet = downlinkGrant;
                    pktInfo.PacketType = obj.DLGrant;
                    pktInfo.NCellID = obj.NCellID;
                    pktInfo.RNTI = grant.RNTI;
                    obj.TxOutofBandFcn(pktInfo); % Send the DL grant out-of-band to UE's MAC
                end
            end
        end
        
        function controlRx(obj, pktInfo)
            %controlRx Receive callback for BSR, feedback(ACK/NACK) for PDSCH, and CQI report
            
            pktType = pktInfo.PacketType;
            switch(pktType)
                case obj.BSR % BSR received
                    bsr = pktInfo.Packet;
                    [lcid, sdu] = hNRMACPDUParser(bsr, 1); % Parse the BSR
                    [~, bufferSizeList] = hNRMACBSRParser(lcid, sdu{1});
                    bufferSize = sum(bufferSizeList); % Combined buffer size of all the LCGs
                    updateUEBufferStatus(obj.Scheduler, obj.ULType, pktInfo.RNTI, bufferSize);
                    
                case obj.PDSCHFeedback % PDSCH feedback received
                    feedbackList = pktInfo.Packet;
                    symNumFrame = obj.Scheduler.CurrSlot*14 + obj.Scheduler.CurrSymbol;
                    for harqId = 0:obj.Scheduler.NumHARQ-1 % Check for all HARQ processes
                        feedbackContext =  obj.RxContextFeedback{pktInfo.RNTI, symNumFrame+1, harqId+1};
                        if ~isempty(feedbackContext) % If any ACK/NACK expected from the UE for this HARQ process
                            feedback = feedbackList(feedbackContext.HARQId+1); % Read Rx success/failure result
                            % Notify Rx result update to scheduler for updating
                            % the HARQ context
                            handleDLRxResult(obj.Scheduler, pktInfo.RNTI, feedbackContext, feedback);
                            obj.RxContextFeedback{pktInfo.RNTI, symNumFrame+1, harqId+1} = []; % Clear the context
                        end
                    end
                    
                case obj.CQIReport % CQI report received
                    cqiReport = pktInfo.Packet;
                    obj.Scheduler.ChannelQualityDL(pktInfo.RNTI, :) = cqiReport;
                    % Assuming same DL and UL channel quality
                    obj.Scheduler.ChannelQualityUL(pktInfo.RNTI, :) = obj.Scheduler.ChannelQualityDL(pktInfo.RNTI, :);
            end
        end
        
        function dataRx(obj)
            %dataRx Send Rx start request to Phy for the receptions scheduled to start now
            %
            %   dataRx(OBJ) sends the Rx start request to Phy for the
            %   receptions scheduled to start now, as per the earlier sent
            %   uplink grants.
            
            gNBRxContext = obj.UplinkRxContext(:, (obj.Scheduler.CurrSlot * 14) + obj.Scheduler.CurrSymbol + 1); % Rx context of current symbol
            txUEs = find(~cellfun(@isempty, gNBRxContext)); % UEs which are assigned uplink grants starting at this symbol
            for i = 1:length(txUEs)
                % For the UE, get the uplink grant information
                uplinkGrant = gNBRxContext{txUEs(i)};
                rxRequestToPhy(obj, txUEs(i), uplinkGrant);
            end
            obj.UplinkRxContext(:, (obj.Scheduler.CurrSlot * 14) + obj.Scheduler.CurrSymbol + 1) = {[]}; % Clear uplink RX context
        end
        
        function rxIndication(obj, macPDU, crc, rxInfo)
            %rxIndication Packet reception from Phy
            %   rxIndication(OBJ, MACPDU, CRC, RXINFO) receives a MAC PDU from
            %   Phy.
            %   MACPDU is the PDU received from Phy.
            %   CRC is the success(value as 0)/failure(value as 1) indication
            %   from Phy.
            %   RXINFO is an object of type hNRRxIndicationInfo containing
            %   information about the reception.
            
            isRxSuccess = ~crc; % CRC value 0 indicates successful reception
            
            % Notify rx result update to scheduler for updating the HARQ context
            handleULRxResult(obj.Scheduler, rxInfo.RNTI, rxInfo, isRxSuccess);
            if isRxSuccess % Packet received is error free
                [lcidList, sduList] = hNRMACPDUParser(macPDU, obj.ULType);
                for sduIndex = 1:numel(lcidList)
                    if lcidList(sduIndex) >=1 && lcidList(sduIndex) <= 32
                        obj.RLCRxFcn(rxInfo.RNTI, lcidList(sduIndex), sduList{sduIndex});
                    end
                end
            end
        end
        
        function dlTTIRequest(obj)
            %dlTTIRequest Request from MAC to Phy to send non-data DL transmissions
            %   dlTTIRequest(OBJ) sends a request to Phy for non-data downlink
            %   transmission scheduled for the current slot. MAC sends it at the
            %   start of a DL slot for all the scheduled DL transmissions in
            %   the slot (except PDSCH, which is sent using dataTx
            %   function of this class).
            
            % Check if current slot is a slot with DL symbols. For FDD,
            % there is no need to check as every slot is a DL slot. For
            % TDD, check if current slot has any DL symbols
            if(obj.Scheduler.DuplexMode ~= 1 || (obj.Scheduler.DuplexMode == 1 && ...
                    ~isempty(find(obj.Scheduler.DLULSlotFormat(obj.Scheduler.CurrDLULSlotIndex + 1, :) == obj.DLType, 1))))
                dlTTIType = [];
                dlTTIPDUs = {};
                
                csirsConfig = obj.CsirsConfig;
                % Check if CSI-RS is scheduled to be sent in this slot
                if strcmp(csirsConfig.CSIRSPeriod, 'on') || ...
                        ~mod(obj.Scheduler.NumSlotsFrame*obj.Scheduler.SFN + ...
                        obj.Scheduler.CurrSlot - csirsConfig.CSIRSPeriod(2), csirsConfig.CSIRSPeriod(1))
                    dlTTIType(1) = hNRPhyInterface.CSIRSPDUType;
                    dlTTIPDUs{1} = csirsConfig;
                end
                obj.DlTTIRequestFcn(dlTTIType, dlTTIPDUs); % Send DL TTI request to Phy
            end
        end
        
        function [throughputServing, goodputServing] = getTTIBytes(obj)
            %getTTIBytes Return the amount of throughput and goodput MAC bytes sent in current symbol, for each UE
            %
            %   [THROUGHPUTPUTSERVING GOODPUTPUTSERVING] =
            %   getTTIBytes(OBJ) returns the amount of throughput and
            %   goodput bytes sent in the TTI which starts at current
            %   symbol. It also clears the context of returned information.
            %
            %   THROUGHPUTPUTSERVING is a vector of length 'N' where 'N' is
            %   the number of UEs. Value at index 'i' represents the amount
            %   of MAC bytes sent for UE 'i' as per the downlink
            %   assignment which starts at this symbol.
            %
            %   GOODPUTPUTSERVING is a vector of length 'N' where 'N' is
            %   the number of UEs. Value at index 'i' represents the amount
            %   of new-Tx MAC bytes sent for UE 'i' as per the downlink
            %   assignment which starts at this symbol.
            %
            %   Throughput and goodput bytes are same for a UE, if it is
            %   new transmission. For retransmission, goodput is zero.
            
            throughputServing = obj.CurrTxThroughputBytes;
            obj.CurrTxThroughputBytes(:) = 0;
            goodputServing = obj.CurrTxGoodputBytes;
            obj.CurrTxGoodputBytes(:) = 0;
        end
        
        function [DLAssignments, ULAssignments] = getCurrentSchedulingAssignments(obj)
            %getCurrentSchedulingAssignments Return the DL and UL assignments done by scheduler on running at current symbol
            %
            %   [DLASSIGNMENTS ULASSIGNMENTS] =
            %   getCurrentSchedulingAssignments(OBJ) returns the DL and UL
            %   assignments done by scheduler on running at current symbol.
            %   DLASSIGNMENTS would be empty if DL scheduler did not run or
            %   did not schedule any DL resources. Likewise, for
            %   ULASSIGNMENTS. It also clears the context of the returned
            %   information.
            %
            %   DLASSIGNMENTS is the cell array of downlink assignments.
            %
            %   ULASSIGNMENTS is the cell array of uplink assignments.
            
            DLAssignments = obj.CurrDLAssignments;
            obj.CurrDLAssignments = {};
            ULAssignments = obj.CurrULAssignments;
            obj.CurrULAssignments = {};
        end
        
        function cqiRBs = getChannelQualityStatus(obj, linkDir, rnti)
            %getChannelQualityStatus Get CQI values of different RBs of bandwidth
            %
            % CQIRBS = getChannelQualityStatus(OBJ, LINKDIR, RNTI) Gets the CQI
            % values of different RBs of bandwidth.
            %
            % LINKDIR - Represents the transmission direction
            % (uplink/downlink) with respect to UE
            %    LINKDIR = 0 represents downlink and
            %    LINKDIR = 1 represents uplink.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1, 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            % CQIRBS - It is an array of integers, specifies the CQI values
            % over the RBs of channel bandwidth
            
            cqiRBs = getChannelQualityStatus(obj.Scheduler, linkDir, rnti);
        end
        
        function updateChannelQualityStatus(obj, cqiRBs, linkDir, rnti)
            %updateChannelQualityStatus Update the channel quality information for a UE
            %
            % updateChannelQualityStatus(OBJ, CQIRBS, LINKDIR, RNTI)
            % updates the channel quality information based on
            % LINKDIR and RNTI at gNB.
            %
            % CQIRBS is an array of integers, specifies the CQI
            % values over the RBs of channel bandwidth.
            %
            % LINKDIR is a scalar integer, specified as 0 or 1. LINKDIR = 0
            % represents downlink and LINKDIR = 1 represents uplink.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1, 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            
            updateChannelQualityStatus(obj.Scheduler, cqiRBs, linkDir, rnti);
        end
        
        function buffStatus = getUEBufferStatus(obj)
            %getUEBufferStatus Get the pending downlink buffer amount (in bytes) for the UEs
            %
            %   BUFFSTATUS = getUEBufferStatus(OBJ) returns the pending
            %   amount of buffer in bytes at gNB for UEs.
            %
            %   BUFFSTATUS is an vector of size 'N', where N is the number
            %   of UEs. Value at index 'i' contains pending DL buffer
            %   amount in bytes, for UE with rnti 'i'.
            
            buffStatus = zeros(length(obj.UEs), 1);
            for i=1:length(obj.UEs)
                buffStatus(i) = sum(obj.LCHBufferStatus(i, :));
            end
        end
        
        function updateBufferStatus(obj, bufferStatusReport)
            %updateBufferStatus Update DL buffer status for UEs, as notified by RLC
            %
            %   updateBufferStatus(obj, BUFFERSTATUSREPORT) updates the
            %   DL buffer status for a logical channel of specified UE
            %
            %   BUFFERSTATUSREPORT is the report sent by RLC. It is a
            %   structure with 3 fields: (i) RNTI -> Specified UE and (ii)
            %   LogicalChannelID and (iii) BufferStatus -> Pending amount
            %   in bytes for the specified logical channel of UE.
            
            obj.LCHBufferStatus(bufferStatusReport.RNTI, bufferStatusReport.LogicalChannelID) = ...
                bufferStatusReport.BufferStatus;
            obj.Scheduler.UEsContextDL(bufferStatusReport.RNTI, 1) = ...
                sum(obj.LCHBufferStatus(bufferStatusReport.RNTI, :));
        end
    end
    
    methods (Access = private)
        function [pduLen, type] = sendMACPDU(obj, rnti, downlinkGrant)
            %sendMACPDU Sends MAC PDU to Phy as per the parameters of the downlink grant
            % Based on the NDI in the downlink grant, either new
            % transmission or retransmission would be indicated to Phy
            
            macPDU = [];
            % Populate PDSCH information to be sent to Phy, along with the MAC
            % PDU
            pdschInfo = hNRPDSCHInfo;
            RBGAllocationBitmap = downlinkGrant.RBGAllocationBitmap;
            DLGrantRBs = -1*ones(obj.Scheduler.NumPDSCHRBs, 1); % To store RB indices of DL grant
            for RBGIndex = 0:(length(RBGAllocationBitmap)-1) % Get RB indices of DL grant
                if RBGAllocationBitmap(RBGIndex+1) == 1
                    startRBInRBG = obj.Scheduler.RBGSizeDL * RBGIndex;
                    % If the last RBG of BWP is assigned, then it might
                    % not have the same number of RBs as other RBG.
                    if RBGIndex == length(RBGAllocationBitmap)-1
                        DLGrantRBs(startRBInRBG+1 : end) =  ...
                            startRBInRBG : obj.Scheduler.NumPDSCHRBs-1;
                    else
                        DLGrantRBs(startRBInRBG+1 : (startRBInRBG + obj.Scheduler.RBGSizeDL)) =  ...
                            startRBInRBG : (startRBInRBG + obj.Scheduler.RBGSizeDL -1) ;
                    end
                end
            end
            DLGrantRBs = DLGrantRBs(DLGrantRBs >= 0);
            pdschInfo.PDSCHConfig.PRBSet = DLGrantRBs;
            % Get the corresponding row from the mcs table
            mcsInfo = obj.Scheduler.MCSTableDL(downlinkGrant.MCS + 1, :);
            modSchemeBits = mcsInfo(1); % Bits per symbol for modulation scheme(stored in column 1)
            pdschInfo.TargetCodeRate = mcsInfo(2)/1024; % Coderate (stored in column 2)
            % Modulation scheme and corresponding bits/symbol
            fullmodlist = ["pi/2-BPSK", "BPSK", "QPSK", "16QAM", "64QAM", "256QAM"]';
            qm = [1 1 2 4 6 8];
            modScheme = fullmodlist((modSchemeBits == qm)); % Get modulation scheme string
            pdschInfo.PDSCHConfig.Modulation = modScheme(1);
            pdschInfo.PDSCHConfig.SymbolAllocation = [downlinkGrant.StartSymbol downlinkGrant.NumSymbols];
            pdschInfo.PDSCHConfig.RNTI = rnti;
            pdschInfo.PDSCHConfig.NID = obj.NCellID;
            pdschInfo.NSlot = obj.Scheduler.CurrSlot;
            pdschInfo.HARQId = downlinkGrant.HARQId;
            pdschInfo.RV = downlinkGrant.RV;
            if obj.Scheduler.SchedulingType % Symbol based scheduling
                pdschInfo.PDSCHConfig.MappingType = 'B';
            end
            carrierConfig = nrCarrierConfig;
            carrierConfig.NSizeGrid = obj.Scheduler.NumPDSCHRBs;
            carrierConfig.SubcarrierSpacing = obj.SCS;
            carrierConfig.NSlot = pdschInfo.NSlot;
            [~, pdschIndicesInfo] = nrPDSCHIndices(carrierConfig, pdschInfo.PDSCHConfig); % Calculate PDSCH indices
            tbs = nrTBS(pdschInfo.PDSCHConfig.Modulation, pdschInfo.PDSCHConfig.NumLayers, length(DLGrantRBs), ...
                pdschIndicesInfo.NREPerPRB, pdschInfo.TargetCodeRate); % Calculate the transport block size
            pduLen = floor(tbs/8); % In bytes
            pdschInfo.TBS = pduLen;
            
            downlinkGrantHarqIndex = downlinkGrant.HARQId;
            lastNDI = obj.Scheduler.HarqStatusAndNDIDL(rnti, downlinkGrantHarqIndex+1, 2);% Last NDI for this HARQ process
            if downlinkGrant.NDI ~= lastNDI
                % NDI is toggled, so send a new MAC packet
                type = 'newTx';
                % Generate MAC PDU
                macPDU = constructMACPDU(obj, floor(tbs/8), rnti);
                % Store the grant NDI for this HARQ process
                obj.Scheduler.HarqStatusAndNDIDL(rnti, downlinkGrantHarqIndex+1, 2) = downlinkGrant.NDI;
                obj.Scheduler.TBSizeDL(rnti, downlinkGrantHarqIndex+1) = pduLen;
            else
                pduLen = obj.Scheduler.TBSizeDL(rnti, downlinkGrantHarqIndex+1);
                type = 'reTx';
            end
            obj.TxDataRequestFcn(pdschInfo, macPDU);
        end
        
        function rxRequestToPhy(obj, rnti, uplinkGrant)
            % rxRequestToPhy Send Rx request to Phy
            
            puschInfo = hNRPUSCHInfo; % Information to be passed to Phy for PUSCH reception
            RBGAllocationBitmap = uplinkGrant.RBGAllocationBitmap;
            numPUSCHRBs = obj.Scheduler.NumPUSCHRBs;
            ULGrantRBs = -1*ones(numPUSCHRBs, 1); % To store RB indices of UL grant
            rbgSizeUL = obj.Scheduler.RBGSizeUL;
            for RBGIndex = 0:(length(RBGAllocationBitmap)-1) % For all RBGs
                if RBGAllocationBitmap(RBGIndex+1) % If RBG is set in bitmap
                    startRBInRBG = rbgSizeUL*RBGIndex;
                    % If the last RBG of BWP is assigned, then it might
                    % not have the same number of RBs as other RBG
                    if RBGIndex == (length(RBGAllocationBitmap)-1)
                        ULGrantRBs(startRBInRBG + 1 : end) =  ...
                            startRBInRBG : numPUSCHRBs-1 ;
                    else
                        ULGrantRBs((startRBInRBG + 1) : (startRBInRBG + rbgSizeUL)) =  ...
                            startRBInRBG : (startRBInRBG + rbgSizeUL -1);
                    end
                end
            end
            ULGrantRBs = ULGrantRBs(ULGrantRBs >= 0);
            puschInfo.PUSCHConfig.PRBSet = ULGrantRBs;
            % Get the corresponding row from the mcs table
            mcsInfo = obj.Scheduler.MCSTableUL(uplinkGrant.MCS + 1, :);
            modSchemeBits = mcsInfo(1); % Bits per symbol for modulation scheme (stored in column 1)
            puschInfo.TargetCodeRate = mcsInfo(2)/1024; % Coderate (stored in column 2)
            % Modulation scheme and corresponding bits/symbol
            fullmodlist = ["pi/2-BPSK", "BPSK", "QPSK", "16QAM", "64QAM", "256QAM"]';
            qm = [1 1 2 4 6 8];
            modScheme = fullmodlist(modSchemeBits == qm); % Get modulation scheme string
            puschInfo.PUSCHConfig.Modulation = modScheme(1);
            puschInfo.PUSCHConfig.RNTI = rnti;
            puschInfo.PUSCHConfig.NID = obj.NCellID;
            puschInfo.NSlot = obj.Scheduler.CurrSlot;
            puschInfo.HARQId = uplinkGrant.HARQId;
            puschInfo.RV = uplinkGrant.RV;
            puschInfo.PUSCHConfig.SymbolAllocation = [uplinkGrant.StartSymbol uplinkGrant.NumSymbols];
            
            carrierConfig = nrCarrierConfig;
            carrierConfig.NSizeGrid = obj.Scheduler.NumPUSCHRBs;
            carrierConfig.SubcarrierSpacing = obj.SCS;
            carrierConfig.NSlot = puschInfo.NSlot;
            
            if strcmp(uplinkGrant.Type, 'newTx') % New transmission
                if obj.Scheduler.SchedulingType % Symbol based scheduling
                    puschInfo.PUSCHConfig.MappingType = 'B';
                end
                % Calculate TBS
                [~, puschIndicesInfo] = nrPUSCHIndices(carrierConfig, puschInfo.PUSCHConfig);
                tbs = nrTBS(puschInfo.PUSCHConfig.Modulation, puschInfo.PUSCHConfig.NumLayers, length(ULGrantRBs), ...
                    puschIndicesInfo.NREPerPRB, puschInfo.TargetCodeRate);
                puschInfo.TBS = floor(tbs/8); % TBS in bytes
                obj.Scheduler.TBSizeUL(rnti, uplinkGrant.HARQId+1) = puschInfo.TBS;
            else % Retransmission
                % Use TBS of the original transmission
                puschInfo.TBS = obj.Scheduler.TBSizeUL(rnti, uplinkGrant.HARQId+1);
            end
            
            % Call Phy to start receiving PUSCH
            obj.RxDataRequestFcn(puschInfo);
        end
    end
end