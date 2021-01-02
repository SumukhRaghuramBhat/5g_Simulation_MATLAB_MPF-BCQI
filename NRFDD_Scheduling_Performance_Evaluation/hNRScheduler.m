classdef (Abstract) hNRScheduler < handle
    %hNRScheduler Implements physical uplink shared channel (PUSCH) and physical downlink shared channel (PDSCH) resource scheduling
    %   The class implements uplink (UL) and downlink (DL) scheduling for
    %   both FDD and TDD modes. It supports both slot based and symbol
    %   based scheduling. In symbol based scheduling, scheduler ensures
    %   smallest TTI granularity (configurable) for UL and DL assignments
    %   in terms of number of symbols. Scheduling is only done at slot
    %   boundary when start symbol is DL so that output can be immediately
    %   conveyed to UEs in DL direction, assuming zero run time for
    %   scheduler algorithm. Hence, in FDD mode the schedulers (DL and UL)
    %   run periodically (configurable) as every slot is DL while for TDD
    %   DL time is checked. In FDD mode, schedulers run to assign the
    %   resources from the next unscheduled slot onwards and a count of
    %   slots equal to scheduler periodicity in terms of number of slots
    %   are scheduled. In TDD mode, the UL scheduler schedules the
    %   resources as close to the transmission time as possible,
    %   considering the PUSCH preparation capability of UEs. The DL
    %   scheduler in TDD mode runs to assign DL resources of the next slot
    %   with unscheduled DL resources. Scheduling decisions are based on
    %   selected scheduling strategy chosen, scheduler configuration and
    %   the context (buffer status, served data rate, channel conditions
    %   and pending retransmissions) maintained for each UE. The class also
    %   implements the MAC portion of the HARQ functionality for
    %   retransmissions.
    
    %   Copyright 2020 The MathWorks, Inc.
    
    properties
        %UEs RNTIs of the UEs connected to the gNB
        UEs {mustBeInteger, mustBeInRange(UEs, 1, 65519)};
        
        %SCS Subcarrier spacing used. The default value is 15 kHz
        SCS (1, 1) {mustBeMember(SCS, [15, 30, 60, 120, 240])} = 15;
        
        %Slot duration in ms
        SlotDuration
        
        %NumSlotsFrame Number of slots in a 10 ms frame. Depends on the SCS used
        NumSlotsFrame
        
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
        
        %NextULSchedulingSlot Slot to be scheduled next by UL scheduler
        % Slot number in the 10 ms frame whose resources will be scheduled
        % when UL scheduler runs next (for TDD mode)
        NextULSchedulingSlot
        
        %NumPUSCHRBs Number of resource blocks (RB) in the uplink bandwidth 
        % The default value is 52 RBs
        NumPUSCHRBs (1, 1){mustBeNonempty, mustBeInteger, mustBeInRange(NumPUSCHRBs, 1, 275)} = 52;
        
        %NumPDSCHRBs Number of RBs in the downlink bandwidth
        % The default value is 52 RBs
        NumPDSCHRBs (1, 1){mustBeNonempty, mustBeInteger, mustBeInRange(NumPDSCHRBs, 1, 275)} = 52;
        
        %RBGSizeUL Size of an uplink resource block group (RBG) in terms of number of RBs
        RBGSizeUL
        
        %RBGSizeDL Size of a downlink RBG in terms of number of RBs
        RBGSizeDL
        
        %NumRBGsUL Number of RBGs in uplink bandwidth
        NumRBGsUL
        
        %NumRBGsDL Number of RBGs in downlink bandwidth
        NumRBGsDL
        
        %RBAllocationLimitUL Maximum limit on number of RBs that can be allotted for a PUSCH 
        % The limit is applicable for new PUSCH transmissions and not for
        % retransmissions
        RBAllocationLimitUL {mustBeInteger, mustBeInRange(RBAllocationLimitUL, 1, 275)};
        
        %RBAllocationLimitDL Maximum limit on number of RBs that can be allotted for a PDSCH
        % The limit is applicable for new PDSCH transmissions and not for
        % retransmissions
        RBAllocationLimitDL {mustBeInteger, mustBeInRange(RBAllocationLimitDL, 1, 275)};
        
        %SchedulerPeriodicity Periodicity at which the schedulers (DL and UL) run in terms of number of slots (for FDD mode)
        % Default value is 1 slot
        SchedulerPeriodicity {mustBeInteger, mustBeInRange(SchedulerPeriodicity, 1, 160)} = 1;
        
        %SlotsSinceSchedulerRunDL Number of slots elapsed since DL scheduler ran last (for FDD mode) 
        % It is incremented every slot and when it reaches the
        % 'SchedulerPeriodicity', it is reset to zero and DL scheduler runs
        SlotsSinceSchedulerRunDL
        
        % SlotsSinceSchedulerRunUL Number of slots elapsed since UL scheduler ran last (for FDD mode)
        % It is incremented every slot and when it reaches the
        % 'SchedulerPeriodicity', it is reset to zero and UL scheduler runs
        SlotsSinceSchedulerRunUL
        
        %PUSCHPrepSymDur PUSCH preparation time in terms of number of symbols
        % Scheduler ensures that PUSCH grant arrives at UEs at least these
        % many symbols before the transmission time
        PUSCHPrepSymDur
        
        %UEsContextUL Stores pending buffer amount and served data rate for UL direction, for each UE
        % N-by-1 matrix where 'N' is the number of UEs. For each UE, gNB
        % maintains a context which is used in taking scheduling decisions.
        % There is one row for each UE, indexed by their respective RNTI
        % values. Each row has following information: Pending UL buffer
        % amount on UE. Pending buffer amount for a UE is populated based
        % on buffer status report (BSR) received from UE.
        UEsContextUL
        
        %UEsContextDL Stores pending buffer amount and served data rate for DL direction, for each UE
        % N-by-1 matrix where 'N' is the number of UEs. For each UE, gNB
        % maintains a context which is used in taking scheduling decisions.
        % There is one row for each UE, indexed by their respective RNTI
        % values. Each row has following information: Pending DL buffer
        % amount for UE.
        UEsContextDL
        
        %LastSelectedUEUL The RNTI of UE which was assigned the last scheduled PUSCH RBG
        LastSelectedUEUL = 0;
        
        %LastSelectedUEDL The RNTI of UE which was assigned the last scheduled downlink RBG
        LastSelectedUEDL = 0;
        
        %ChannelQualityUL Current uplink CQI values at gNB for each UE
        % N-by-P matrix where 'N' is the number of UEs and 'P' is the
        % number of RBs in the bandwidth. A matrix element at position (i,
        % j) corresponds to uplink CQI value for UE with RNTI 'i' at RB 'j'
        ChannelQualityUL
        
        %ChannelQualityDL Current downlink CQI values at gNB for each UE
        % N-by-P matrix where 'N' is the number of UEs and 'P' is the
        % number of RBs in the DL bandwidth. A matrix element at position (i,
        % j) corresponds to DL CQI value for UE with RNTI 'i' at RB 'j'
        ChannelQualityDL
        
        %CQITableUL CQI table used for uplink
        % It contains the mapping of CQI indices with Modulation and Coding
        % schemes
        CQITableUL
        
        %MCSTableUL MCS table used for uplink
        % It contains the mapping of MCS indices with Modulation and Coding
        % schemes
        MCSTableUL
        
        %CQITableDL CQI table used for downlink
        % It contains the mapping of CQI indices with Modulation and Coding
        % schemes
        CQITableDL
        
        %MCSTableDL MCS table used for downlink
        % It contains the mapping of MCS indices with Modulation and Coding
        % schemes
        MCSTableDL
        
        %TTIGranularity Minimum time-domain assignment in terms of number of symbols (for symbol based scheduling). 
        % The default value is 4 symbols
        TTIGranularity {mustBeMember(TTIGranularity, [2, 4, 7])} = 4;
        
        %NumPUSCHDMRS Number of PUSCH demodulation reference signal symbols
        NumPUSCHDMRS = 1;
        
        % NumPDSCHDMRS Number of PDSCH demodulation reference signal symbols
        NumPDSCHDMRS = 1;
        
        %NumHARQ Number of HARQ processes
        % The default value 16 HARQ processes
        NumHARQ (1, 1) {mustBeInteger, mustBeInRange(NumHARQ, 1, 16)} = 16;
        
        %HarqProcessesUL Uplink HARQ processes context
        % N-by-P structure array where 'N' is the number of UEs and 'P' is
        % the number of HARQ processes. Each row in this matrix stores the
        % context of all the uplink HARQ processes of a particular UE.
        HarqProcessesUL
        
        %HarqProcessesDL Downlink HARQ proceses context
        % N-by-P structure array where 'N' is the number of UEs and 'P' is
        % the number of HARQ processes. Each row in this matrix stores the
        % context of all the downlink HARQ processes of a particular UE.
        HarqProcessesDL
        
        %HarqStatusAndNDIUL Status (free or busy) of each uplink HARQ process of the UEs, and last sent NDI value for the HARQ process
        % N-by-P-by-2 array where 'N' is the number of UEs and 'P' is the
        % number of HARQ processes. For each UL HARQ process of a UE, it
        % stores these 2 information fields: HARQ process status (value 0
        % represents free, value 1 represents busy) and the last sent NDI
        % to the UE
        HarqStatusAndNDIUL
        
        %HarqStatusAndNDIDL Status (free or busy) of each downlink HARQ process of the UEs, and last sent NDI value for the HARQ process
        % N-by-P-by-2 array where 'N' is the number of UEs and 'P' is the
        % number of HARQ processes. For each DL HARQ process of a UE, it
        % stores these 2 information fields: HARQ process status (value 0
        % represents free, value 1 represents busy) and the last sent NDI
        % to the UE
        HarqStatusAndNDIDL
        
        %RetransmissionContextUL Information about uplink retransmission requirements of the UEs
        % N-by-P cell array where 'N' is the number of UEs and 'P' is the
        % number of HARQ processes. It stores the information of HARQ
        % processes for which the reception failed at gNB. This information
        % is used for assigning uplink grants for retransmissions. Each row
        % corresponds to a UE and a non-empty value in one of its columns
        % indicates that the reception has failed for this particular HARQ
        % process governed by the column index. The value in the cell
        % element would be uplink grant information used by the UE for the
        % previous failed transmission
        RetransmissionContextUL
        
        %RetransmissionContextDL Information about downlink retransmission requirements of the UEs
        % N-by-P cell array where 'N' is the number of UEs and 'P' is the
        % number of HARQ processes. It stores the information of HARQ
        % processes for which the reception failed at UE. This information
        % is used for assigning downlink grants for retransmissions. Each
        % row corresponds to a UE and a non-empty value in one of its
        % columns indicates that the reception has failed for this
        % particular HARQ process governed by the column index. The value
        % in the cell element would be downlink grant information used by
        % the gNB for the previous failed transmission
        RetransmissionContextDL
        
        %TBSizeDL Stores the size of transport block sent for DL HARQ processes
        % N-by-P matrix where 'N' is the number of UEs and P is number of
        % HARQ process. Value at index (i,j) stores size of transport block
        % sent for UE with RNTI 'i' for HARQ process index 'j'.
        % Value is 0 if DL HARQ process is free
        TBSizeDL
        
        %TBSizeUL Stores the size of transport block to be received for UL HARQ processes
        % N-by-P matrix where 'N' is the number of UEs and P is number of
        % HARQ process. Value at index (i,j) stores size of transport block
        % to be received from UE with RNTI 'i' for HARQ process index 'j'.
        % Value is 0, if no UL packet expected for HARQ process of the UE
        TBSizeUL
    end
    
    properties (Constant)
        % NominalRBGSizePerBW Nominal RBG size for the specified bandwidth in accordance with 3GPP TS 38.214, Section 5.1.2.2.1
        NominalRBGSizePerBW = [
            36   2   4
            72   4   8
            144  8   16
            275  16  16 ];
        
        %DLType Value to specify downlink direction or downlink symbol type
        DLType = 0;
        
        %ULType Value to specify uplink direction or uplink symbol type
        ULType = 1;
        
        %GuardType Value to specify guard symbol type
        GuardType = 2;
    end
    
    methods
        function obj = hNRScheduler(param)
            %hNRScheduler Construct gNB MAC scheduler object
            %
            % param is a structure including the following fields:
            % NumUEs                       - Number of UEs in the cell
            % DuplexMode                   - Duplexing mode: FDD (value 0) or TDD (value 1)
            % SchedulingType               - Slot based scheduling (value 0) or symbol based scheduling (value 1)
            % TTIGranularity               - Smallest TTI size in terms of number of symbols (for symbol based scheduling)
            % NumRBs                       - Number of resource blocks in PUSCH and PDSCH bandwidth
            % SCS                          - Subcarrier spacing
            % SchedulerPeriodicity         - Scheduler run periodicity in slots (for FDD mode)
            % RBAllocationLimitUL          - Maximum limit on the number of RBs allotted to a UE for a PUSCH
            % RBAllocationLimitDL          - Maximum limit on the number of RBs allotted to a UE for a PDSCH
            % NumHARQ                      - Number of HARQ processes
            % EnableHARQ                   - Flag to enable/disable retransmissions
            % DLULPeriodicity              - Duration of the DL-UL pattern in ms (for TDD mode)
            % NumDLSlots                   - Number of full DL slots at the start of DL-UL pattern (for TDD mode)
            % NumDLSyms                    - Number of DL symbols after full DL slots of DL-UL pattern (for TDD mode)
            % NumULSyms                    - Number of UL symbols before full UL slots of DL-UL pattern (for TDD mode)
            % NumULSlots                   - Number of full UL slots at the end of DL-UL pattern (for TDD mode)
            % PUSCHPrepTime                - PUSCH preparation time required by UEs (in microseconds)
            % RBGSizeConfig                - RBG size configuration as 1 (configuration-1 RBG table) or 2 (configuration-2 RBG table)
            %                                as defined in 3GPP TS 38.214 Section 5.1.2.2.1. It defines the
            %                                number of RBs in an RBG. Default value is 1
            
            % Initialize the class properties
            % Validate the number of UEs
            validateattributes(param.NumUEs, {'numeric'}, {'nonempty', ...
                'integer', 'scalar', '>', 0, '<=', 65519}, 'param.NumUEs', 'NumUEs');
            % UEs are assumed to have sequential radio network temporary
            % identifiers (RNTIs) from 1 to NumUEs
            obj.UEs = 1:param.NumUEs;
            if isfield(param, 'SCS')
                obj.SCS = param.SCS;
            end
            obj.SlotDuration = 1/(obj.SCS/15); % In ms
            obj.NumSlotsFrame = 10/obj.SlotDuration; % Number of slots in a 10 ms frame
            
            if isfield(param, 'PUSCHPrepTime')
                validateattributes(param.PUSCHPrepTime, {'numeric'}, ...
                    {'nonempty', 'integer', 'scalar', 'finite', '>=', 0}, ...
                    'param.PUSCHPrepTime', 'PUSCHPrepTime');
                obj.PUSCHPrepSymDur = ceil(param.PUSCHPrepTime/((obj.SlotDuration*1000)/14));
            else
                % Default value is 200 microseconds
                obj.PUSCHPrepSymDur = ceil(200/((obj.SlotDuration*1000)/14));
            end

            if isfield(param, 'SchedulingType')
                obj.SchedulingType = param.SchedulingType;
            end
            if obj.SchedulingType % Symbol based scheduling
                % Set TTI granularity
                if isfield(param, 'TTIGranularity')
                    obj.TTIGranularity = param.TTIGranularity;
                end
            end
            
            populateDuplexModeProperties(obj, param);
            
            if isfield(param, 'RBAllocationLimitUL')
                validateattributes(param.RBAllocationLimitUL, {'numeric'}, ...
                    {'nonempty', 'integer', 'scalar', '>=', 1, '<=',obj.NumPUSCHRBs},...
                    'param.RBAllocationLimitUL', 'RBAllocationLimitUL');
                obj.RBAllocationLimitUL = param.RBAllocationLimitUL;
            else
                % Set RB limit to half of the total number of RBs
                obj.RBAllocationLimitUL = floor(obj.NumPUSCHRBs * 0.5);
            end
            
            if isfield(param, 'RBAllocationLimitDL')
                validateattributes(param.RBAllocationLimitDL, {'numeric'}, ...
                    {'nonempty', 'integer', 'scalar', '>=', 1, '<=',obj.NumPDSCHRBs},...
                    'param.RBAllocationLimitDL', 'RBAllocationLimitDL');
                obj.RBAllocationLimitDL = param.RBAllocationLimitDL;
            else
                % Set RB limit to half of the total number of RBs
                obj.RBAllocationLimitDL = floor(obj.NumPDSCHRBs * 0.5);
            end
            
            numUEs = length(obj.UEs);
            for i = 1:numUEs
                % Initialize UE buffer status to 0
                obj.UEsContextUL(i, 1) = 0;
                obj.UEsContextDL(i, 1) = 0;
            end
            
            % Store the CQI tables as matrices
            obj.CQITableUL = getCQITableUL(obj);
            obj.CQITableDL = getCQITableDL(obj);
            
            % Context initialization for HARQ processes
            if isfield(param, 'NumHARQ')
                obj.NumHARQ = param.NumHARQ;
            end
            harqProcess.RVSequence = [0 3 2 1]; % Set RV sequence
            
            % Validate the flag to enable/disable HARQ
            if isfield(param, 'EnableHARQ')
                % To support true/false
                validateattributes(param.EnableHARQ, {'logical', 'numeric'}, {'nonempty', 'integer', 'scalar'}, 'param.EnableHARQ', 'EnableHARQ');
                if isnumeric(param.EnableHARQ)
                    % To support 0/1
                    validateattributes(param.EnableHARQ, {'numeric'}, {'>=', 0, '<=', 1}, 'param.EnableHARQ', 'EnableHARQ');
                end
                if ~param.EnableHARQ
                    % No retransmissions
                    harqProcess.RVSequence = 0; % Set RV sequence
                end
            end
            ncw = 1; % Only single codeword
            harqProcess.ncw = ncw; % Set number of codewords
            harqProcess.blkerr = zeros(1, ncw); % Initialize block errors
            harqProcess.RVIdx = ones(1, ncw);  % Add RVIdx to process
            harqProcess.RV = harqProcess.RVSequence(ones(1,ncw));
            % Create HARQ processes context array for each UE
            obj.HarqProcessesUL = repmat(harqProcess, numUEs, obj.NumHARQ);
            obj.HarqProcessesDL = repmat(harqProcess, numUEs, obj.NumHARQ);
            for i=1:numUEs
                obj.HarqProcessesUL(i,:) = hNewHARQProcesses(obj.NumHARQ, harqProcess.RVSequence, ncw);
                obj.HarqProcessesDL(i,:) = hNewHARQProcesses(obj.NumHARQ, harqProcess.RVSequence, ncw);
            end
            % For each HARQ process of the UEs, store following 2 information fields: status (0 = free, 1 = busy) and last sent NDI-flag
            obj.HarqStatusAndNDIUL = zeros(numUEs, obj.NumHARQ, 2);
            obj.HarqStatusAndNDIDL = zeros(numUEs, obj.NumHARQ, 2);
            
            % Create retransmission context
            obj.RetransmissionContextUL = cell(numUEs, obj.NumHARQ);
            obj.RetransmissionContextDL = cell(numUEs, obj.NumHARQ);
            
            % Initialize DL and UL channel quality as CQI index 7
            obj.ChannelQualityDL = 7*ones(numUEs, obj.NumPDSCHRBs);
            obj.ChannelQualityUL = 7*ones(numUEs, obj.NumPUSCHRBs);
            
            obj.TBSizeDL = zeros(numUEs, obj.NumHARQ);
            obj.TBSizeUL = zeros(numUEs, obj.NumHARQ);
        end
        
        function resourceAssignments = runDLScheduler(obj)
            %runDLScheduler Run the DL scheduler
            %
            %   RESOURCEASSIGNMENTS = runDLScheduler(OBJ) runs the DL scheduler
            %   and returns the resource assignments structure array.
            %
            %   RESOURCEASSIGNMENTS is a structure that contains the
            %   DL resource assignments information.
            
            resourceAssignments = {};
            if obj.CurrSymbol == 0 % Run scheduler at slot boundary
                if obj.DuplexMode == 1 % TDD
                    resourceAssignments = runDLSchedulerTDD(obj);
                else % FDD
                    resourceAssignments = runDLSchedulerFDD(obj);
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
            
            resourceAssignments = {};
            if obj.CurrSymbol == 0 % Run scheduler at slot boundary
                if obj.DuplexMode == 1 % TDD
                    resourceAssignments = runULSchedulerTDD(obj);
                else % FDD
                    resourceAssignments = runULSchedulerFDD(obj);
                end
            end
        end
        
        function symbolType = currentSymbolType(obj)
            %currentSymbolType Get current running symbol type: DL/UL/Guard
            %   SYMBOLTYPE = currentSymbolType(OBJ) returns the symbol type of
            %   current symbol.
            %
            %   SYMBOLTYPE is the symbol type. Value 0, 1 and 2 represent
            %   DL, UL, guard symbol respectively.
            
            symbolType = obj.DLULSlotFormat(obj.CurrDLULSlotIndex + 1, obj.CurrSymbol + 1);
        end
        
        function updateUEBufferStatus(obj, linkDir, rnti, bufferSize)
            %updateUEBufferStatus Update pending buffer status for UE
            %
            %   updateUEBufferStatus(OBJ, LINKDIR, RNTI, BUFFERSIZE)
            %   updates the pending buffer status information of a UE.
            %
            %   LINKDIR - Represents the link direction (uplink/downlink)
            %   with respect to UE. LINKDIR = 0 represents downlink, and
            %   LINKDIR = 1 represents uplink.
            %
            %   RNTI is a radio network temporary identifier, specified
            %   within [1, 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            %   BUFFERSIZE - Current buffer size (in bytes)
            
            if linkDir % Uplink
                obj.UEsContextUL(rnti, 1) = bufferSize;
            else % Downlink
                obj.UEsContextDL(rnti, 1) = bufferSize;
            end
        end
        
        function cqiRBs = getChannelQualityStatus(obj, linkDir, rnti)
            %getChannelQualityStatus Get CQI values of different RBs of bandwidth
            %
            %   CQIRBS = getChannelQualityStatus(OBJ, LINKDIR, RNTI) Gets the CQI
            %   values of different RBs of bandwidth.
            %
            %   LINKDIR - Represents the transmission direction
            %   (uplink/downlink) with respect to UE. LINKDIR = 0
            %   represents downlink, and LINKDIR = 1 represents uplink.
            %
            %   RNTI is a radio network temporary identifier, specified
            %   within [1, 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            %   CQIRBS is an array of integers specifying the CQI values
            %   over the RBs of channel bandwidth
            
            if linkDir % Uplink
                cqiRBs = obj.ChannelQualityUL(rnti, :);
            else % Downlink
                cqiRBs = obj.ChannelQualityDL(rnti, :);
            end
        end
        
        function updateChannelQualityStatus(obj, cqiRBs, linkDir, rnti)
            %updateChannelQualityStatus Update the channel quality information
            %
            %   updateChannelQualityStatus(OBJ, CQIRBS, LINKDIR, RNTI)
            %   updates the channel quality information based on
            %   LINKDIR and RNTI at gNB.
            %
            %   CQIRBS is an array of integers specifying the CQI values over
            %   the RBs of channel bandwidth.
            %
            %   LINKDIR is a scalar integer, specified as 0 or 1. LINKDIR = 0
            %   represents downlink and LINKDIR = 1 represents uplink.
            %
            %   RNTI is a radio network temporary identifier, specified
            %   within [1, 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            
            if linkDir % Uplink
                obj.ChannelQualityUL(rnti, :) = cqiRBs;
            else % Downlink
                obj.ChannelQualityDL(rnti, :) = cqiRBs;
            end
        end
        
        function resourceAssignments = runULSchedulerFDD(obj)
            %runULSchedulerFDD Run the gNB scheduler to assign uplink resources for FDD mode
            % If UL scheduler is scheduled to run in this slot, assign
            % resources of upcoming unscheduled slots. The number of slots
            % scheduled in one run is equal to the periodicity of UL
            % scheduler in terms of number of slots. The PUSCH preparation
            % time required by the UEs is also considered by the scheduler
            %
            % RESOURCEASSIGNMENTS = runULSchedulerFDD(OBJ) runs the
            % scheduler and returns the resource assignments structure.
            %
            % RESOURCEASSIGNMENTS is a cell array of structures that contains the
            % resource assignments information.
            
            resourceAssignments = {};
            obj.SlotsSinceSchedulerRunUL = obj.SlotsSinceSchedulerRunUL + 1;
            if obj.SlotsSinceSchedulerRunUL == obj.SchedulerPeriodicity
                % Scheduler periodicity reached, run the scheduler to
                % assign UL resources. Offset of first slot to be scheduled
                % in this scheduler run must be such that UEs get required
                % PUSCH preparation time.
                firstScheduledSlotOffset = max(1, ceil(obj.PUSCHPrepSymDur/14));
                lastScheduledSlotOffset = firstScheduledSlotOffset + obj.SchedulerPeriodicity - 1;
                numULGrants = 0;
                % Slot-by-slot scheduling of the resources
                for slotOffset = firstScheduledSlotOffset:lastScheduledSlotOffset
                    slotNum = mod(obj.CurrSlot + slotOffset, obj.NumSlotsFrame);
                    slotULGrants = scheduleULResourcesSlot(obj, slotNum);
                    resourceAssignments(numULGrants + 1 : numULGrants + length(slotULGrants)) = slotULGrants(:);
                    numULGrants = numULGrants + length(slotULGrants);
                end
                obj.SlotsSinceSchedulerRunUL = 0;
            end
        end
        
        function resourceAssignments = runDLSchedulerFDD(obj)
            %runDLSchedulerFDD Runs the gNB scheduler to assign downlink resources for FDD mode
            % If DL scheduler is scheduled to run in this slot, assign
            % resources of upcoming slots, starting from the next slot and
            % till (and including) the slot when scheduler would run next,
            % as per configured scheduler periodicity.
            %
            % RESOURCEASSIGNMENTS = runDLSchedulerFDD(OBJ) runs the
            % scheduler and returns the resource assignments structure.
            %
            % RESOURCEASSIGNMENTS is a cell array of structures that contains the
            % resource assignments information.
            
            resourceAssignments = {};
            obj.SlotsSinceSchedulerRunDL = obj.SlotsSinceSchedulerRunDL + 1;
            if obj.SlotsSinceSchedulerRunDL == obj.SchedulerPeriodicity
                % Scheduler periodicity reached, run the scheduler to
                % assign DL resources. Slot-by-slot scheduling of the
                % resources till the next run of scheduler
                numDLGrants = 0;
                for slotOffset = 1:obj.SchedulerPeriodicity
                    slotNum = mod(obj.CurrSlot + slotOffset, obj.NumSlotsFrame);
                    slotDLGrants = scheduleDLResourcesSlot(obj, slotNum);
                    resourceAssignments(numDLGrants + 1 : numDLGrants + length(slotDLGrants)) = slotDLGrants(:);
                    numDLGrants = numDLGrants + length(slotDLGrants);
                end
                obj.SlotsSinceSchedulerRunDL = 0;
            end
        end
        
        function resourceAssignments = runULSchedulerTDD(obj)
            %runULSchedulerTDD Runs the gNB scheduler to assign uplink resources in TDD mode
            % If current slot has DL symbol at the start (Scheduling is
            % only done in DL time), then (i) Scheduler selects the
            % upcoming slots (which contains UL resources) to be scheduled.
            % The criterion used for selecting these slots to be scheduled
            % is: All the slot with UL resources which cannot be scheduled
            % in the next DL slot based on the PUSCH preparation time
            % capability of the UEs. It ensures that the UL resources are
            % scheduled as close as possible to the actual transmission
            % time, respecting the PUSCH preparation time capability of
            % the UEs(ii) The scheduler assigns UL resources of the
            % selected slots among the UEs and returns all the UL
            % assignments done
            %
            % RESOURCEASSIGNMENTS = runULSchedulerTDD(OBJ) runs the
            % scheduler and returns the resource assignments structure.
            %
            % RESOURCEASSIGNMENTS is a cell array of structures that contains the
            % resource assignments information.
            
            resourceAssignments = {};
            % Scheduling is only done in the slot starting with DL symbol
            if find(obj.DLULSlotFormat(obj.CurrDLULSlotIndex+1, 1) == obj.DLType, 1)
                slotsToBeSched = selectULSlotsToBeSched(obj); % Select the set of slots to be scheduled in this UL scheduler run
                numULGrants = 0;
                for i=1:length(slotsToBeSched)
                    % Schedule each selected slot
                    slotULGrants = scheduleULResourcesSlot(obj, slotsToBeSched(i));
                    resourceAssignments(numULGrants + 1 : numULGrants + length(slotULGrants)) = slotULGrants(:);
                    numULGrants = numULGrants + length(slotULGrants);
                end
                % Update the next to-be-scheduled UL slot. Next UL
                % scheduler run starts assigning resources this slot
                % onwards
                if ~isempty(slotsToBeSched)
                    % If any UL slots are scheduled, set the next
                    % to-be-scheduled UL slot as the next UL slot after
                    % last scheduled UL slot
                    lastSchedULSlot = slotsToBeSched(end);
                    obj.NextULSchedulingSlot = getToBeSchedULSlotNextRun(obj, lastSchedULSlot);
                end
            end
        end
        
        function resourceAssignments = runDLSchedulerTDD(obj)
            %runDLSchedulerTDD Runs the gNB scheduler to assign downlink resources
            % If current slot has DL symbol at start(Scheduling is only
            % done in DL time), then the scheduler assigns DL resources of
            % first upcoming slot containing DL resources
            %
            % RESOURCEASSIGNMENTS = runDLSchedulerTDD(OBJ) runs the
            % scheduler and returns the resource assignments structure.
            %
            % RESOURCEASSIGNMENTS is a cell array of structures that contains the
            % resource assignments information.
            
            resourceAssignments = {};
            % Scheduling is only done in the slot starting with DL symbol
            if find(obj.DLULSlotFormat(obj.CurrDLULSlotIndex+1, 1) == obj.DLType, 1)
                slotToBeSched = selectDLSlotToBeSched(obj); % Select the slot to be scheduled in this DL scheduler run
                if ~isempty(slotToBeSched)
                    % Schedule the DL symbols of the selected slot
                    slotDLGrants = scheduleDLResourcesSlot(obj, slotToBeSched);
                    resourceAssignments(1 : length(slotDLGrants)) = slotDLGrants(:);
                end
            end
        end
        
        function handleDLRxResult(obj, rnti, dlGrant, rxResult)
            %handleDLRxResult Update the HARQ process context based on the Rx success/failure for DL packets
            % handleDLRxResult(OBJ, RNTI, DLGRANT, RXRESULT) updates the HARQ
            % process context, based on the ACK/NACK received by gNB for
            % the DL packet.
            %
            % RNTI - UE that sent the ACK/NACK for its DL reception.
            %
            % DLGRANT - DL assignment corresponding to the DL packet.
            %
            % RXRESULT - 0 means NACK or no feedback received. 1 means ACK.
            
            if rxResult % Rx success
                % Update the DL HARQ process context
                obj.HarqStatusAndNDIDL(rnti, dlGrant.HARQId+1, 1) = 0; % Mark the HARQ process as free
                harqProcess = obj.HarqProcessesDL(rnti, dlGrant.HARQId+1);
                harqProcess.blkerr(1) = 0;
                obj.HarqProcessesDL(rnti, dlGrant.HARQId+1) = harqProcess;
                
                % Clear the retransmission context for the HARQ
                % process of the UE. It would already be empty if
                % this feedback was not for a retransmission.
                obj.RetransmissionContextDL{rnti, dlGrant.HARQId+1}= [];
            else % Rx failure or no feedback received
                harqProcess = obj.HarqProcessesDL(rnti, dlGrant.HARQId+1);
                harqProcess.blkerr(1) = 1;
                if harqProcess.RVIdx(1) == length(harqProcess.RVSequence)
                    % Packet reception failed for all redundancy
                    % versions. Mark the HARQ process as free. Also
                    % clear the retransmission context to not allow any
                    % further retransmissions for this packet
                    harqProcess.blkerr(1) = 0;
                    obj.HarqStatusAndNDIDL(rnti, dlGrant.HARQId+1, 1) = 0; % Mark HARQ as free
                    obj.HarqProcessesDL(rnti, dlGrant.HARQId+1) = harqProcess;
                    obj.RetransmissionContextDL{rnti, dlGrant.HARQId+1}= [];
                else
                    % Update the retransmission context for the UE
                    % and HARQ process to indicate retransmission
                    % requirement
                    obj.HarqProcessesDL(rnti, dlGrant.HARQId+1) = harqProcess;
                    obj.RetransmissionContextDL{rnti, dlGrant.HARQId+1}= dlGrant;
                end
            end
        end
        
        function handleULRxResult(obj, rnti, ulInfo, rxResult)
            %handleULRxResult Update the HARQ process context based on the Rx success/failure for UL packets
            % handleULRxResult(OBJ, RNTI, ULGRANT, RXRESULT) updates the HARQ
            % process context, based on the reception success/failure of
            % UL packets.
            %
            % RNTI - UE corresponding to the UL packet.
            %
            % ULGRANT - Information about the UL packet.
            %
            % RXRESULT - 0 means Rx failure or no reception. 1 means Rx success.
            
            if rxResult % Rx success
                % Update the HARQ process context
                obj.HarqStatusAndNDIUL(rnti, ulInfo.HARQId + 1, 1) = 0; % Mark HARQ process as free
                harqProcess = obj.HarqProcessesUL(rnti, ulInfo.HARQId + 1);
                harqProcess.blkerr(1) = 0;
                obj.HarqProcessesUL(rnti, ulInfo.HARQId+1) = harqProcess;
                
                % Clear the retransmission context for the HARQ process
                % of the UE. It would already be empty if this
                % reception was not a retransmission.
                obj.RetransmissionContextUL{rnti, ulInfo.HARQId+1}= [];
            else % Rx failure or no packet received
                % No packet received (or corrupted) from UE although it
                % was scheduled to send. Store the transmission uplink
                % grant in retransmission context, which will be used
                % while assigning grant for retransmission
                harqProcess = obj.HarqProcessesUL(rnti, ulInfo.HARQId+1);
                harqProcess.blkerr(1) = 1;
                if harqProcess.RVIdx(1) == length(harqProcess.RVSequence)
                    % Packet reception failed for all redundancy
                    % versions. Mark the HARQ process as free. Also
                    % clear the retransmission context to not allow any
                    % further retransmissions for this packet
                    harqProcess.blkerr(1) = 0;
                    obj.HarqStatusAndNDIUL(rnti, ulInfo.HARQId+1, 1) = 0; % Mark HARQ as free
                    obj.HarqProcessesUL(rnti, ulInfo.HARQId+1) = harqProcess;
                    obj.RetransmissionContextUL{rnti, ulInfo.HARQId+1}= [];
                else
                    obj.HarqProcessesUL(rnti, ulInfo.HARQId+1) = harqProcess;
                    obj.RetransmissionContextUL{rnti, ulInfo.HARQId+1}= ulInfo;
                end
            end
        end
        
        function [selectedUE, mcsIndex] = runSchedulingStrategy(~, schedulerInput)
            %runSchedulingStrategy Implements the round-robin scheduling
            %
            %   [SELECTEDUE, MCSINDEX] = runSchedulingStrategy(~,SCHEDULERINPUT) runs
            %   the round robin algorithm and returns the selected UE for this RBG
            %   (among the eligible ones), along with the suitable MCS index based on
            %   the channel conditions. This function gets called for selecting a UE for
            %   each RBG to be used for new transmission, i.e. once for each of the
            %   remaining RBGs after assignment for retransmissions is completed.
            %
            %   SCHEDULERINPUT structure contains the following fields which scheduler
            %   would use (not necessarily all the information) for selecting the UE to
            %   which RBG would be assigned.
            %
            %       eligibleUEs    -  RNTI of the eligible UEs contending for the RBG
            %       RBGIndex       -  RBG index in the slot which is getting scheduled
            %       slotNum        -  Slot number in the frame whose RBG is getting scheduled
            %       RBGSize        -  RBG Size in terms of number of RBs
            %       cqiRBG         -  Uplink Channel quality on RBG for UEs. This is a
            %                         N-by-P  matrix with uplink CQI values for UEs on
            %                         different RBs of RBG. 'N' is the number of eligible
            %                         UEs and 'P' is the RBG size in RBs
            %       mcsRBG         -  MCS for eligible UEs based on the CQI values of the RBs
            %                         of RBG. This is a N-by-2 matrix where 'N' is number of
            %                         eligible UEs. For each eligible UE it contains, MCS
            %                         index (first column) and efficiency (bits/symbol
            %                         considering both Modulation and Coding scheme)
            %       pastDataRate   -  Served data rate. Vector of N elements containing
            %                         historical served data rate to eligible UEs. 'N' is
            %                         the number of eligible UEs
            %       bufferStatus   -  Buffer-Status of UEs. Vector of N elements where 'N'
            %                         is the number of eligible UEs, containing pending
            %                         buffer status for UEs
            %       ttiDur         -  TTI duration in ms
            %       UEs            -  RNTI of all the UEs (even the non-eligible ones for
            %                         this RBG)
            %       lastSelectedUE - The RNTI of the UE which was assigned the last
            %                        scheduled RBG
            %
            %   SELECTEDUE The UE (among the eligible ones) which gets assigned
            %                   this particular resource block group
            %
            %   MCSINDEX   The suitable MCS index based on the channel conditions
            
            % Select next UE for scheduling. After the last selected UE, go in
            % sequence and find the first UE which is eligible and with non-zero
            % buffer status
            selectedUE = -1;
            mcsIndex = -1;
            scheduledUE = schedulerInput.lastSelectedUE;
            for i = 1:length(schedulerInput.UEs)
                scheduledUE = mod(scheduledUE, length(schedulerInput.UEs))+1; % Next UE selected in round-robin fashion
                % Selected UE through round-robin strategy must be in eligibility-list
                % and must have something to send, otherwise move to the next UE
                index = find(schedulerInput.eligibleUEs == scheduledUE, 1);
                if(~isempty(index))
                    bufferStatus = schedulerInput.bufferStatus(index);
                    if(bufferStatus > 0) % Check if UE has any data pending
                        % Select the UE and calculate the expected MCS index
                        % for uplink grant, based on the CQI values for the RBs
                        % of this RBG
                        selectedUE = schedulerInput.eligibleUEs(index);
                        mcsIndex = schedulerInput.mcsRBG(index, 1);
                        break;
                    end
                end
            end
        end
    end
    
    methods (Access = protected)
        function uplinkGrants = scheduleULResourcesSlot(obj, slotNum)
            %scheduleULResourcesSlot Schedule UL resources of a slot
            %   UPLINKGRANTS = scheduleULResourcesSlot(OBJ, SLOTNUM)
            %   assigns UL resources of the slot, SLOTNUM. Based on the UL
            %   assignment done, it also updates the UL HARQ process
            %   context.
            %   
            %   SLOTNUM is the slot number in the 10 ms frame whose UL
            %   resources are getting scheduled. For FDD, all the symbols
            %   can be used for UL. For TDD, the UL resources can stretch
            %   the full slot or might just be limited to few symbols in
            %   the slot.
            %
            %   UPLINKGRANTS is a cell array where each cell-element
            %   represents an uplink grant and has following fields:
            %
            %       RNTI                Uplink grant is for this UE
            %
            %       Type                Whether assignment is for new transmission ('newTx'),
            %                           retransmission ('reTx')
            %
            %       HARQId              Selected uplink HARQ process ID
            %
            %       RBGAllocationBitmap Frequency-domain resource assignment. A
            %                           bitmap of resource-block-groups of
            %                           the PUSCH bandwidth. Value 1
            %                           indicates RBG is assigned to the UE
            %
            %       StartSymbol         Start symbol of time-domain resources
            %
            %       NumSymbols          Number of symbols allotted in time-domain
            %
            %       SlotOffset          Slot-offset of PUSCH assignment
            %                           w.r.t the current slot
            %
            %       MCS                 Selected modulation and coding scheme for UE with
            %                           respect to the resource assignment done
            %
            %       NDI                 New data indicator flag
            
            % Calculate offset of the slot to be scheduled, from the current
            % slot
            if slotNum >= obj.CurrSlot
                slotOffset = slotNum - obj.CurrSlot;
            else
                slotOffset = (obj.NumSlotsFrame + slotNum) - obj.CurrSlot;
            end
            
            % Get start UL symbol and number of UL symbols in the slot
            if obj.DuplexMode == 1 % TDD
                DLULPatternIndex = mod(obj.CurrDLULSlotIndex + slotOffset, obj.NumDLULPatternSlots);
                slotFormat = obj.DLULSlotFormat(DLULPatternIndex + 1, :);
                firstULSym = find(slotFormat == obj.ULType, 1, 'first') - 1; % Index of first UL symbol in the slot
                lastULSym = find(slotFormat == obj.ULType, 1, 'last') - 1; % Index of last UL symbol in the slot
                numULSym = lastULSym - firstULSym + 1;
            else % FDD
                % All symbols are UL symbols
                firstULSym = 0;
                numULSym = 14;
            end
            
            if obj.SchedulingType == 0 % Slot based scheduling
                % Assignments to span all the symbols in the slot
                uplinkGrants = assignULResourceTTI(obj, slotNum, firstULSym, numULSym);
                
            else % Symbol based scheduling
                if numULSym < obj.TTIGranularity
                    uplinkGrants = [];
                    return; % Not enough symbols for minimum TTI granularity
                end
                numTTIs = floor(numULSym / obj.TTIGranularity); % UL TTIs in the slot
                
                % UL grant array with maximum size to store grants
                uplinkGrants = cell((ceil(14/obj.TTIGranularity) * length(obj.UEs)), 1);
                numULGrants = 0;
                
                % Schedule all UL TTIs in the slot one-by-one
                startSym = firstULSym;
                for i = 1 : numTTIs
                    TTIULGrants = assignULResourceTTI(obj, slotNum, startSym, obj.TTIGranularity);
                    uplinkGrants(numULGrants + 1 : numULGrants + length(TTIULGrants)) = TTIULGrants(:);
                    numULGrants = numULGrants + length(TTIULGrants);
                    startSym = startSym + obj.TTIGranularity;
                end
                uplinkGrants = uplinkGrants(1 : numULGrants);
            end
        end
        
        function downlinkGrants = scheduleDLResourcesSlot(obj, slotNum)
           %scheduleDLResourcesSlot Schedule DL resources of a slot
            %   DOWNLINKGRANTS = scheduleDLResourcesSlot(OBJ, SLOTNUM)
            %   assigns DL resources of the slot, SLOTNUM. Based on the DL
            %   assignment done, it also updates the DL HARQ process
            %   context.
            %   
            %   SLOTNUM is the slot number in the 10 ms frame whose DL
            %   resources are getting scheduled. For FDD, all the symbols
            %   can be used for DL. For TDD, the DL resources can stretch
            %   the full slot or might just be limited to few symbols in
            %   the slot.
            %
            %   DOWNLINKGRANTS is a cell array where each cell-element
            %   represents a downlink grant and has following fields:
            %
            %       RNTI                Downlink grant is for this UE
            %
            %       Type                Whether assignment is for new transmission ('newTx'),
            %                           retransmission ('reTx')
            %
            %       HARQId              Selected downlink HARQ process ID
            %
            %       RBGAllocationBitmap Frequency-domain resource assignment. A
            %                           bitmap of resource-block-groups of
            %                           the PDSCH bandwidth. Value 1
            %                           indicates RBG is assigned to the UE
            %
            %       StartSymbol         Start symbol of time-domain resources
            %
            %       NumSymbols          Number of symbols allotted in time-domain
            %
            %       SlotOffset          Slot offset of PDSCH assignment
            %                           w.r.t the current slot
            %
            %       MCS                 Selected modulation and coding scheme for UE with
            %                           respect to the resource assignment done
            %
            %       NDI                 New data indicator flag
            %
            %       FeedbackSlotOffset  Slot offset of PDSCH ACK/NACK from
            %                           PDSCH transmission slot (i.e. k1)
            
            % Calculate offset of the slot to be scheduled, from the current
            % slot
            if slotNum >= obj.CurrSlot
                slotOffset = slotNum - obj.CurrSlot;
            else
                slotOffset = (obj.NumSlotsFrame + slotNum) - obj.CurrSlot;
            end
            
            % Get start DL symbol and number of DL symbols in the slot
            if obj.DuplexMode == 1 % TDD mode
                DLULPatternIndex = mod(obj.CurrDLULSlotIndex + slotOffset, obj.NumDLULPatternSlots);
                slotFormat = obj.DLULSlotFormat(DLULPatternIndex + 1, :);
                firstDLSym = find(slotFormat == obj.DLType, 1, 'first') - 1; % Location of first DL symbol in the slot
                lastDLSym = find(slotFormat == obj.DLType, 1, 'last') - 1; % Location of last DL symbol in the slot
                numDLSym = lastDLSym - firstDLSym + 1;
            else
                % For FDD, all symbols are DL symbols
                firstDLSym = 0;
                numDLSym = 14;
            end
            
            if obj.SchedulingType == 0  % Slot based scheduling
                % Assignments to span all the symbols in the slot
                downlinkGrants = assignDLResourceTTI(obj, slotNum, firstDLSym, numDLSym);
            else %Symbol based scheduling
                if numDLSym < obj.TTIGranularity
                    downlinkGrants = [];
                    return; % Not enough symbols for minimum TTI granularity
                end
                numTTIs = floor(numDLSym / obj.TTIGranularity); % DL TTIs in the slot
                
                % DL grant array with maximum size to store grants. Maximum
                % grants possible in a slot is the product of number of
                % TTIs in slot and number of UEs
                downlinkGrants = cell((ceil(14/obj.TTIGranularity) * length(obj.UEs)), 1);
                numDLGrants = 0;
                
               % Schedule all DL TTIs in the slot one-by-one
                startSym = firstDLSym;
                for i = 1 : numTTIs
                    TTIDLGrants = assignDLResourceTTI(obj, slotNum, startSym,  obj.TTIGranularity);
                    downlinkGrants(numDLGrants + 1 : numDLGrants + length(TTIDLGrants)) = TTIDLGrants(:);
                    numDLGrants = numDLGrants + length(TTIDLGrants);
                    startSym = startSym + obj.TTIGranularity;
                end
                downlinkGrants = downlinkGrants(1 : numDLGrants);
            end
        end
        
        function selectedSlots = selectULSlotsToBeSched(obj)
            %selectULSlotsToBeSched Get the set of slots to be scheduled by UL scheduler (for TDD mode)
            % The criterion used here selects all the upcoming slots
            % (including the current one) containing unscheduled UL symbols
            % which must be scheduled now. These slots can be scheduled now
            % but cannot be scheduled in the next slot with DL symbols,
            % based on PUSCH preparation time capability of UEs (It is
            % assumed that all the UEs have same PUSCH preparation
            % capability).
            
            selectedSlots = zeros(obj.NumSlotsFrame, 1);
            
            % Calculate how far the next DL slot is
            nextDLSlotOffset = 1;
            while nextDLSlotOffset < obj.NumSlotsFrame % Consider only the slots within 10 ms
                slotIndex = mod(obj.CurrDLULSlotIndex + nextDLSlotOffset, obj.NumDLULPatternSlots);
                if find(obj.DLULSlotFormat(slotIndex + 1, :) == obj.DLType, 1)
                    break; % Found a slot with DL symbols
                end
                nextDLSlotOffset = nextDLSlotOffset + 1;
            end
            nextDLSymOffset = (nextDLSlotOffset * 14); % Convert to number of symbols
            
            % Calculate how many slots ahead is the next to-be-scheduled
            % slot
            if obj.CurrSlot <= obj.NextULSchedulingSlot
                % It is in the current frame
                nextULSchedSlotOffset = obj.NextULSchedulingSlot - obj.CurrSlot;
            else
                % It is in the next frame
                nextULSchedSlotOffset = (obj.NumSlotsFrame + obj.NextULSchedulingSlot) - obj.CurrSlot;
            end
            
            % Start evaluating candidate future slots one-by-one, to check
            % if they must be scheduled now, starting from the slot which
            % is 'nextULSchedSlotOffset' slots ahead
            numSlotsSelected = 0;
            while nextULSchedSlotOffset < obj.NumSlotsFrame
                % Get slot index of candidate slot in DL-UL pattern and its
                % format
                slotIdxDLULPattern = mod(obj.CurrDLULSlotIndex + nextULSchedSlotOffset, obj.NumDLULPatternSlots);
                slotFormat = obj.DLULSlotFormat(slotIdxDLULPattern + 1, :);
                
                firstULSym = find(slotFormat == obj.ULType, 1, 'first'); % Check for location of first UL symbol in the candidate slot
                if firstULSym % If slot has any UL symbol
                    nextULSymOffset = (nextULSchedSlotOffset * 14) + firstULSym - 1;
                    if (nextULSymOffset - nextDLSymOffset) < obj.PUSCHPrepSymDur
                        % The UL resources of this candidate slot cannot be
                        % scheduled in the first upcoming slot with DL
                        % symbols. Check if it can be scheduled now. If so,
                        % add it to the list of selected slots
                        if nextULSymOffset >= obj.PUSCHPrepSymDur
                            numSlotsSelected = numSlotsSelected + 1;
                            selectedSlots(numSlotsSelected) = mod(obj.CurrSlot + nextULSchedSlotOffset, obj.NumSlotsFrame);
                        end
                    else
                        % Slots which are 'nextULSchedSlotOffset' or more
                        % slots ahead can be scheduled in next slot with DL
                        % symbols as scheduling there will also be able to
                        % give enough PUSCH preparation time for UEs.
                        break;
                    end
                end
                nextULSchedSlotOffset = nextULSchedSlotOffset + 1; % Move to the next slot
            end
            selectedSlots = selectedSlots(1 : numSlotsSelected); % Keep only the selected slots in the array
        end
        
        function selectedSlot = selectDLSlotToBeSched(obj)
            %selectDLSlotToBeSched Select the slot to be scheduled by DL scheduler (for TDD mode)
            % Return the slot number of next slot with DL resources
            % (symbols). In every run the DL scheduler schedules the next
            % slot with DL symbols.
            selectedSlot = [];
            % Calculate how far the next DL slot is
            nextDLSlotOffset = 1;
            while nextDLSlotOffset < obj.NumSlotsFrame % Consider only the slots within 10 ms
                slotIndex = mod(obj.CurrDLULSlotIndex + nextDLSlotOffset, obj.NumDLULPatternSlots);
                if find(obj.DLULSlotFormat(slotIndex + 1, :) == obj.DLType, 1)
                    % Found a slot with DL symbols, calculate the slot
                    % number
                    selectedSlot = mod(obj.CurrSlot + nextDLSlotOffset, obj.NumSlotsFrame);
                    break;
                end
                nextDLSlotOffset = nextDLSlotOffset + 1;
            end
        end
        
        function selectedSlot = getToBeSchedULSlotNextRun(obj, lastSchedULSlot)
            %getToBeSchedULSlotNextRun Get the first slot to be scheduled by UL scheduler in the next run (for TDD mode)
            % Based on the last scheduled UL slot, get the slot number of
            % the next UL slot (which would be scheduled in the next
            % UL scheduler run)
            
            % Calculate offset of the last scheduled slot
            if lastSchedULSlot >= obj.CurrSlot
                lastSchedULSlotOffset = lastSchedULSlot - obj.CurrSlot;
            else
                lastSchedULSlotOffset = (obj.NumSlotsFrame + lastSchedULSlot) - obj.CurrSlot;
            end
            
            candidateSlotOffset = lastSchedULSlotOffset + 1;
            % Slot index in DL-UL pattern
            candidateSlotDLULIndex = mod(obj.CurrDLULSlotIndex + candidateSlotOffset, obj.NumDLULPatternSlots);
            while isempty(find(obj.DLULSlotFormat(candidateSlotDLULIndex+1,:) == obj.ULType, 1))
                % Slot does not have UL symbols. Check the next slot
                candidateSlotOffset = candidateSlotOffset + 1;
                candidateSlotDLULIndex = mod(obj.CurrDLULSlotIndex + candidateSlotOffset, obj.NumDLULPatternSlots);
            end
            selectedSlot = mod(obj.CurrSlot + candidateSlotOffset, obj.NumSlotsFrame);
        end
       
        function ULGrantsTTI = assignULResourceTTI(obj, slotNum, startSym, numSym)
            %assignULResourceTTI Perform the uplink scheduling of a set of contiguous UL symbols representing a TTI, of the specified slot
            % A UE getting retransmission opportunity in the TTI is not
            % eligible for getting resources for new transmission. An
            % uplink assignment can be non-contiguous, scattered over RBGs
            % of the PUSCH bandwidth
            
            RBGAllocationBitmap = zeros(1, obj.NumRBGsUL);
            % Assignment of resources for retransmissions
            [reTxUEs, RBGAllocationBitmap, reTxULGrants] = scheduleRetransmissionsUL(obj, slotNum, startSym, numSym, RBGAllocationBitmap);
            ULGrantsTTI = reTxULGrants;
            % Assignment of resources for new transmissions, if there
            % are RBGs remaining after retransmissions. UEs which got
            % assigned resources for retransmissions as well as those with
            % no free HARQ process, are not eligible for assignment
            eligibleUEs = getNewTxEligibleUEs(obj, obj.ULType, reTxUEs);
            if any(~RBGAllocationBitmap) && ~isempty(eligibleUEs) % If any RBG is free in the TTI and there are any eligible UEs
                [~, ~, newTxULGrants] = scheduleNewTxUL(obj, slotNum, eligibleUEs, startSym, numSym, RBGAllocationBitmap);
                ULGrantsTTI = [ULGrantsTTI;newTxULGrants];
            end
        end
        
        function DLGrantsTTI = assignDLResourceTTI(obj, slotNum, startSym, numSym)
            %assignDLResourceTTI Perform the downlink scheduling of a set of contiguous DL symbols representing a TTI, of the specified slot
            % A UE getting retransmission opportunity in the TTI is not
            % eligible for getting resources for new transmission. A
            % downlink assignment can be non-contiguous, scattered over RBGs
            % of the PDSCH bandwidth
            
            rbgAllocationBitmap = zeros(1, obj.NumRBGsDL);
            % Assignment of resources for retransmissions
            [reTxUEs, rbgAllocationBitmap, reTxDLGrants] = scheduleRetransmissionsDL(obj, slotNum, startSym, numSym, rbgAllocationBitmap);
            DLGrantsTTI = reTxDLGrants;
            % Assignment of resources for new transmissions, if there
            % are RBGs remaining after retransmissions. UEs which got
            % assigned resources for retransmissions as well those with
            % no free HARQ process, are not considered
            eligibleUEs = getNewTxEligibleUEs(obj, obj.DLType, reTxUEs);
            % If any RBG is free in the slot and there are eligible UEs
            if any(~rbgAllocationBitmap) && ~isempty(eligibleUEs)
                [~, ~, newTxDLGrants] = scheduleNewTxDL(obj, slotNum, eligibleUEs, startSym, numSym, rbgAllocationBitmap);
                DLGrantsTTI = [DLGrantsTTI;newTxDLGrants];
            end
        end
        
        function [reTxUEs, updatedRBGStatus, ULGrants] = scheduleRetransmissionsUL(obj, scheduledSlot, startSym, numSym, rbgOccupancyBitmap)
            %scheduleRetransmissionsUL Assign resources of a set of contiguous UL symbols representing a TTI, of the specified slot for uplink retransmissions
            % Return the uplink assignments to the UEs which are allotted
            % retransmission opportunity and the updated
            % RBG-occupancy-status to convey what all RBGs are used. All
            % UEs are checked if they require retransmission for any of
            % their HARQ processes. If there are multiple such HARQ
            % processes for a UE then one HARQ process is selected randomly
            % among those. All UEs get maximum 1 retransmission opportunity
            % in a TTI
            
            % Holds updated RBG occupancy status as the RBGs keep getting
            % allotted for retransmissions
            updatedRBGStatus = rbgOccupancyBitmap;
            
            reTxGrantCount = 0;
            % Store UEs which get retransmission opportunity
            reTxUEs = zeros(length(obj.UEs), 1);
            % Store retransmission UL grants of this TTI
            ULGrants = cell(length(obj.UEs), 1);
            
            % Create a random permutation of UE RNTIs, to define the order
            % in which UEs would be considered for retransmission
            % assignments for this scheduler run
            reTxAssignmentOrder = randperm(length(obj.UEs));
            
            % Calculate offset of scheduled slot from the current slot
            if scheduledSlot >= obj.CurrSlot
                slotOffset = scheduledSlot - obj.CurrSlot;
            else
                slotOffset = (obj.NumSlotsFrame + scheduledSlot) - obj.CurrSlot;
            end
            
            % Consider retransmission requirement of the UEs as per
            % reTxAssignmentOrder
            for i = 1:length(reTxAssignmentOrder)
                reTxContextUE = obj.RetransmissionContextUL(obj.UEs(reTxAssignmentOrder(i)), :);
                failedRxHarqs = find(~cellfun(@isempty,reTxContextUE));
                if ~isempty(failedRxHarqs) % At least one UL HARQ process for UE requires retransmission
                    % Select one HARQ process randomly
                    selectedHarqId = failedRxHarqs(randi(length(failedRxHarqs))) - 1;
                    % Read last UL grant for the transmission to calculate
                    % its TBS. Retransmission grant TBS also needs to be
                    % big enough to accommodate the packet.
                    lastULGrantContext = obj.RetransmissionContextUL{obj.UEs(reTxAssignmentOrder(i)), selectedHarqId+1};
                    lastTbsBits = lastULGrantContext.TBS*8; % TBS in bits
                    % Assign resources and MCS for retransmission
                    [isAssigned, allottedRBGBitmap, MCS] = getRetransmissionResources(obj, obj.ULType, reTxAssignmentOrder(i), ...
                        lastTbsBits, updatedRBGStatus, scheduledSlot, startSym, numSym);
                    if isAssigned
                        % Fill the retransmission uplink grant properties
                        grant = struct();
                        grant.RNTI = reTxAssignmentOrder(i);
                        grant.Type = 'reTx';
                        grant.HARQId = selectedHarqId;
                        grant.RBGAllocationBitmap = allottedRBGBitmap;
                        grant.StartSymbol = startSym;
                        grant.NumSymbols = numSym;
                        grant.SlotOffset = slotOffset;
                        grant.MCS = MCS;
                        grant.NDI = obj.HarqStatusAndNDIUL(reTxAssignmentOrder(i), selectedHarqId+1, 2); % Fill same NDI (for retransmission)
                        
                        % Update the HARQ process context to reflect the
                        % retransmission grant
                        harqProcess = hUpdateHARQProcess(obj.HarqProcessesUL(reTxAssignmentOrder(i), selectedHarqId+1), 1);
                        obj.HarqProcessesUL(reTxAssignmentOrder(i), selectedHarqId+1) = harqProcess;
                        grant.RV = harqProcess.RVSequence(harqProcess.RVIdx(1));
                        
                        reTxGrantCount = reTxGrantCount+1;
                        reTxUEs(reTxGrantCount) = reTxAssignmentOrder(i);
                        ULGrants{reTxGrantCount} = grant;
                        % Mark the allotted RBGs as occupied.
                        updatedRBGStatus = updatedRBGStatus | allottedRBGBitmap;
                        
                        % Clear the retransmission context for this HARQ
                        % process of the selected UE to make it ineligible
                        % for retransmission assignments (Retransmission
                        % context would again get set, if Rx fails again in
                        % future for this retransmission assignment)
                        obj.RetransmissionContextUL{obj.UEs(reTxAssignmentOrder(i)), selectedHarqId+1} = [];
                    end
                end
            end
            reTxUEs = reTxUEs(1 : reTxGrantCount);
            ULGrants = ULGrants(~cellfun('isempty', ULGrants)); % Remove all empty elements
        end
        
        function [reTxUEs, updatedRBGStatus, DLGrants] = scheduleRetransmissionsDL(obj, scheduledSlot, startSym, numSym, rbgOccupancyBitmap)
            %scheduleRetransmissionsDL Assign resources of a set of contiguous DL symbols representing a TTI, of the specified slot for downlink retransmissions
            % Return the downlink assignments to the UEs which are
            % allotted retransmission opportunity and the updated
            % RBG-occupancy-status to convey what all RBGs are used. All
            % UEs are checked if they require retransmission for any of
            % their HARQ processes. If there are multiple such HARQ
            % processes for a UE then one HARQ process is selected randomly
            % among those. All UEs get maximum 1 retransmission opportunity
            % in a TTI
            
            % Holds updated RBG occupancy status as the RBGs keep getting
            % allotted for retransmissions
            updatedRBGStatus = rbgOccupancyBitmap;
            
            reTxGrantCount = 0;
            % Store UEs which get retransmission opportunity
            reTxUEs = zeros(length(obj.UEs), 1);
            % Store retransmission DL grants of this TTI
            DLGrants = cell(length(obj.UEs), 1);
            
            % Create a random permutation of UE RNTIs, to define the order
            % in which retransmission assignments would be done for this
            % TTI
            reTxAssignmentOrder = randperm(length(obj.UEs));
            
            % Calculate offset of currently scheduled slot from the current slot
            if scheduledSlot >= obj.CurrSlot
                slotOffset = scheduledSlot - obj.CurrSlot; % Scheduled slot is in current frame
            else
                slotOffset = (obj.NumSlotsFrame + scheduledSlot) - obj.CurrSlot; % Scheduled slot is in next frame
            end
            
            % Consider retransmission requirement of the UEs as per
            % reTxAssignmentOrder
            for i = 1:length(reTxAssignmentOrder) % For each UE
                reTxContextUE = obj.RetransmissionContextDL(obj.UEs(reTxAssignmentOrder(i)), :);
                failedRxHarqs = find(~cellfun(@isempty,reTxContextUE));
                if ~isempty(failedRxHarqs) % At least one DL HARQ process for UE requires retransmission
                    % Select one HARQ process randomly
                    selectedHarqId = failedRxHarqs(randi(length(failedRxHarqs))) - 1;
                    % Read last DL grant TBS. Retransmission grant TBS also needs to be
                    % big enough to accommodate the packet
                    lastTbs = obj.TBSizeDL(obj.UEs(reTxAssignmentOrder(i)), selectedHarqId+1);
                    lastTbsBits = lastTbs*8;
                    % Assign resources and MCS for retransmission
                    [isAssigned, allottedRBGBitmap, MCS] = getRetransmissionResources(obj, obj.DLType, reTxAssignmentOrder(i),  ...
                        lastTbsBits, updatedRBGStatus, scheduledSlot, startSym, numSym);
                    if isAssigned
                        % Fill the retransmission downlink grant properties
                        grant = struct();
                        grant.RNTI = reTxAssignmentOrder(i);
                        grant.Type = 'reTx';
                        grant.HARQId = selectedHarqId;
                        grant.RBGAllocationBitmap = allottedRBGBitmap;
                        grant.StartSymbol = startSym;
                        grant.NumSymbols = numSym;
                        grant.SlotOffset = slotOffset;
                        grant.MCS = MCS;
                        grant.NDI = obj.HarqStatusAndNDIDL(reTxAssignmentOrder(i), selectedHarqId+1, 2); % Fill same NDI (for retransmission)
                        grant.FeedbackSlotOffset = getPDSCHFeedbackSlotOffset(obj, slotOffset);
                        
                        % Update the HARQ process context to reflect the
                        % retransmission grant
                        harqProcess = hUpdateHARQProcess(obj.HarqProcessesDL(reTxAssignmentOrder(i), selectedHarqId+1), 1);
                        obj.HarqProcessesDL(reTxAssignmentOrder(i), selectedHarqId+1) = harqProcess;
                        grant.RV = harqProcess.RVSequence(harqProcess.RVIdx(1));
                        
                        reTxGrantCount = reTxGrantCount+1;
                        reTxUEs(reTxGrantCount) = reTxAssignmentOrder(i);
                        DLGrants{reTxGrantCount} = grant;
                        % Mark the allotted RBGs as occupied.
                        updatedRBGStatus = updatedRBGStatus | allottedRBGBitmap;
                        % Clear the retransmission context for this HARQ
                        % process of the selected UE to make it ineligible
                        % for retransmission assignments (Retransmission
                        % context would again get set, if Rx fails again in
                        % future for this retransmission assignment)
                        obj.RetransmissionContextDL{obj.UEs(reTxAssignmentOrder(i)), selectedHarqId+1} = [];
                    end
                end
            end
            reTxUEs = reTxUEs(1 : reTxGrantCount);
            DLGrants = DLGrants(~cellfun('isempty', DLGrants)); % Remove all empty elements
        end
        
        function [newTxUEs, updatedRBGStatus, ULGrants] = scheduleNewTxUL(obj, scheduledSlot, eligibleUEs, startSym, numSym, rbgOccupancyBitmap)
            %scheduleNewTxUL Assign resources of a set of contiguous UL symbols representing a TTI, of the specified slot for new uplink transmissions
            % Return the uplink assignments, the UEs which are allotted
            % new transmission opportunity and the RBG-occupancy-status to
            % convey what all RBGs are used. Eligible set of UEs are passed
            % as input along with the bitmap of occupancy status of RBGs
            % for the slot getting scheduled. Only RBGs marked as 0 are
            % available for assignment to UEs
            
            % Stores UEs which get new transmission opportunity
            newTxUEs = zeros(length(eligibleUEs), 1);
            
            % Stores UL grants of this TTI
            ULGrants = cell(length(eligibleUEs), 1);
            
            % To store the MCS of all the RBGs allocated to UEs. As PUSCH
            % assignment to a UE must have a single MCS even if multiple
            % RBGs are allotted, average of all the values is taken.
            rbgMCS = -1*ones(length(eligibleUEs), obj.NumRBGsUL);
            
            % To store allotted RB count to UE in the slot
            allottedRBCount = zeros(length(eligibleUEs), 1);
            
            % Holds updated RBG occupancy status as the RBGs keep getting
            % allotted for new transmissions
            updatedRBGStatus = rbgOccupancyBitmap;
            
            % Calculate offset of scheduled slot from the current slot
            if scheduledSlot >= obj.CurrSlot
                slotOffset = scheduledSlot - obj.CurrSlot;
            else
                slotOffset = (obj.NumSlotsFrame + scheduledSlot) - obj.CurrSlot;
            end
            
            % For each available RBG, based on the scheduling strategy
            % select the most appropriate UE. Also ensure that the number of
            % RBs allotted to a UE in the slot does not exceed the limit as
            % defined by the class property 'RBAllocationLimit'
            RBGEligibleUEs = eligibleUEs; % To keep track of UEs currently eligible for RBG allocations in this slot
            newTxGrantCount = 0;
            for i = 1:length(rbgOccupancyBitmap)
                % Resource block group is free
                if ~rbgOccupancyBitmap(i)
                    RBGIndex = i-1;
                    schedulerInput = createSchedulerInput(obj, obj.ULType, scheduledSlot, RBGEligibleUEs, RBGIndex, startSym, numSym);
                    % Run the scheduling strategy to select a UE for the RBG and appropriate MCS
                    [selectedUE, mcs] = obj.runSchedulingStrategy(schedulerInput);
                    if selectedUE ~= -1 % If RBG is assigned to any UE
                        updatedRBGStatus(i) = 1; % Mark as assigned
                        obj.LastSelectedUEUL = selectedUE;
                        selectedUEIdx = find(eligibleUEs == selectedUE, 1, 'first'); % Find UE index in eligible UEs set
                        rbgMCS(selectedUEIdx, i) = mcs;
                        if isempty(find(newTxUEs == selectedUE,1))
                            % Selected UE is allotted first RBG in this TTI
                            grant.RNTI = selectedUE;
                            grant.Type = 'newTx';
                            grant.RBGAllocationBitmap = zeros(1, length(rbgOccupancyBitmap));
                            grant.RBGAllocationBitmap(RBGIndex+1) = 1;
                            grant.StartSymbol = startSym;
                            grant.NumSymbols = numSym;
                            grant.SlotOffset = slotOffset;
                            
                            newTxGrantCount = newTxGrantCount + 1;
                            newTxUEs(newTxGrantCount) = selectedUE;
                            ULGrants{selectedUEIdx} = grant;
                        else
                            % Add RBG to the UE's grant
                            grant = ULGrants{selectedUEIdx};
                            grant.RBGAllocationBitmap(RBGIndex+1) = 1;
                            ULGrants{selectedUEIdx} = grant;
                        end
                        
                        if RBGIndex < obj.NumRBGsUL-1
                            allottedRBCount(selectedUEIdx) = allottedRBCount(selectedUEIdx) + obj.RBGSizeUL;
                            % Check if the UE which got this RBG remains
                            % eligible for further RBGs in this TTI, as per
                            % set 'RBAllocationLimitUL'.
                            nextRBGSize = obj.RBGSizeUL;
                            if RBGIndex == obj.NumRBGsUL-2 % If next RBG index is the last one in the BWP
                                nextRBGSize = obj.NumPUSCHRBs - ((RBGIndex+1) * obj.RBGSizeUL);
                            end
                            if allottedRBCount(selectedUEIdx) > (obj.RBAllocationLimitUL - nextRBGSize)
                                % Not eligible for next RBG as max RB
                                % allocation limit would get breached
                                RBGEligibleUEs = setdiff(RBGEligibleUEs, selectedUE, 'stable');
                            end
                        end
                        
                        % Decrement the buffer status value of UE to
                        % reflect the assignment done for avoiding
                        % allocating unnecessary resources further
                        startRBIndex = obj.RBGSizeUL * RBGIndex;
                        % Last RBG may have lesser RBs as number of RBs might not
                        % be completely divisible by RBG size
                        lastRBIndex = min(startRBIndex+obj.RBGSizeUL-1, obj.NumPUSCHRBs-1);
                        mcsInfo = obj.MCSTableUL(mcs + 1, :);
                        bitsPerSym = mcsInfo(3); % Accounting for both Modulation & Coding scheme
                        achievedTxBits = obj.getResourceBandwidth(bitsPerSym, (lastRBIndex - startRBIndex + 1), numSym - obj.NumPUSCHDMRS);
                        bufferStatus = obj.UEsContextUL(selectedUE, 1);
                        updatedBufferStatus = max(0,(bufferStatus - (floor(achievedTxBits/8))));
                        updateUEBufferStatus(obj, obj.ULType, selectedUE, updatedBufferStatus);
                    end
                end
            end
            
            % Calculate a single MCS value for the PUSCH assignment to UEs
            % from the MCS values of all the RBGs allotted. Also select a
            % free HARQ process to be used for uplink over the selected
            % RBGs. It was already ensured that UEs in eligibleUEs set have
            % at least one free HARQ process before deeming them eligible
            % for getting resources for new transmission
            for i = 1:length(eligibleUEs)
                % If any resources were assigned to this UE
                if ~isempty(ULGrants{i})
                    grant = ULGrants{i};
                    grant.MCS = obj.MCSForRBGBitmap(rbgMCS(i, :)); % Get a single MCS for all allotted RBGs
                    % Select one HARQ process, update its context to reflect
                    % grant
                    selectedHarqId = findFreeUEHarqProcess(obj, obj.ULType, eligibleUEs(i));
                    harqProcess = hUpdateHARQProcess(obj.HarqProcessesUL(eligibleUEs(i), selectedHarqId+1), 1);
                    obj.HarqProcessesUL(eligibleUEs(i), selectedHarqId+1) = harqProcess;
                    grant.RV = harqProcess.RVSequence(harqProcess.RVIdx(1));
                    obj.HarqStatusAndNDIUL(eligibleUEs(i), selectedHarqId+1, 1) = 1; % Mark HARQ process as busy
                    grant.HARQId = selectedHarqId; % Fill HARQ id in grant
                    grant.NDI = ~obj.HarqStatusAndNDIUL(grant.RNTI, selectedHarqId + 1, 2); % Toggle the NDI for new transmission
                    obj.HarqStatusAndNDIUL(grant.RNTI, selectedHarqId+1, 2) = grant.NDI; % Update the NDI context for the HARQ process
                    ULGrants{i} = grant;
                end
            end
            newTxUEs = newTxUEs(1 : newTxGrantCount);
            ULGrants = ULGrants(~cellfun('isempty',ULGrants)); % Remove all empty elements
        end
        
        function [newTxUEs, updatedRBGStatus, DLGrants] = scheduleNewTxDL(obj, scheduledSlot, eligibleUEs, startSym, numSym, rbgOccupancyBitmap)
            %scheduleNewTxDL Assign resources of a set of contiguous UL symbols representing a TTI, of the specified slot for new downlink transmissions
            % Return the downlink assignments for the UEs which are allotted
            % new transmission opportunity and the RBG-occupancy-status to
            % convey what all RBGs are used. Eligible set of UEs are passed
            % as input along with the bitmap of occupancy status of RBGs
            % of the slot getting scheduled. Only RBGs marked as 0 are
            % available for assignment to UEs
            
            % Stores UEs which get new transmission opportunity
            newTxUEs = zeros(length(eligibleUEs), 1);
            
            % Stores DL grants of the TTI
            DLGrants = cell(length(eligibleUEs), 1);
            
            % To store the MCS of all the RBGs allocated to UEs. As PDSCH
            % assignment to a UE must have a single MCS even if multiple
            % RBGs are allotted, average of all the values is taken
            rbgMCS = -1*ones(length(eligibleUEs), obj.NumRBGsDL);
            
            % To store allotted RB count to UE in the slot
            allottedRBCount = zeros(length(eligibleUEs), 1);
            
            % Holds updated RBG occupancy status as the RBGs keep getting
            % allotted for new transmissions
            updatedRBGStatus = rbgOccupancyBitmap;
            
            % Calculate offset of scheduled slot from the current slot
            if scheduledSlot >= obj.CurrSlot
                slotOffset = scheduledSlot - obj.CurrSlot;
            else
                slotOffset = (obj.NumSlotsFrame + scheduledSlot) - obj.CurrSlot;
            end
            
            % For each available RBG, based on the scheduling strategy
            % select the most appropriate UE. Also ensure that the number of
            % RBs allotted for a UE in the slot does not exceed the limit as
            % defined by the class property 'RBAllocationLimitDL'
            RBGEligibleUEs = eligibleUEs; % To keep track of UEs currently eligible for RBG allocations in this slot
            newTxGrantCount = 0;
            for i = 1:length(rbgOccupancyBitmap)
                % Resource block group is free
                if ~rbgOccupancyBitmap(i)
                    RBGIndex = i-1;
                    schedulerInput = createSchedulerInput(obj, obj.DLType, scheduledSlot, RBGEligibleUEs, RBGIndex, startSym, numSym);
                    % Run the scheduling strategy to select a UE for the RBG and appropriate MCS
                    [selectedUE, mcs] = obj.runSchedulingStrategy(schedulerInput);
                    if selectedUE ~= -1 % If RBG is assigned to any UE
                        updatedRBGStatus(i) = 1; % Mark as assigned
                        obj.LastSelectedUEDL = selectedUE;
                        selectedUEIdx = find(eligibleUEs == selectedUE, 1, 'first'); % Find UE index in eligible UEs set
                        rbgMCS(selectedUEIdx, i) = mcs;
                        if isempty(find(newTxUEs == selectedUE,1))
                            % Selected UE is allotted first RBG in this TTI
                            grant.RNTI = selectedUE;
                            grant.Type = 'newTx';
                            grant.RBGAllocationBitmap = zeros(1, length(rbgOccupancyBitmap));
                            grant.RBGAllocationBitmap(RBGIndex+1) = 1;
                            grant.StartSymbol = startSym;
                            grant.NumSymbols = numSym;
                            grant.SlotOffset = slotOffset;
                            grant.FeedbackSlotOffset = getPDSCHFeedbackSlotOffset(obj, slotOffset);
                            
                            newTxGrantCount = newTxGrantCount + 1;
                            newTxUEs(newTxGrantCount) = selectedUE;
                            DLGrants{selectedUEIdx} = grant;
                        else
                            % Add RBG to the UE's grant
                            grant = DLGrants{selectedUEIdx};
                            grant.RBGAllocationBitmap(RBGIndex+1) = 1;
                            DLGrants{selectedUEIdx} = grant;
                        end
                        if RBGIndex < obj.NumRBGsDL-1
                            allottedRBCount(selectedUEIdx) = allottedRBCount(selectedUEIdx) + obj.RBGSizeDL;
                            % Check if the UE which got this RBG remains
                            % eligible for further RBGs in this TTI, as per
                            % set 'RBAllocationLimitDL'.
                            nextRBGSize = obj.RBGSizeDL;
                            if RBGIndex == obj.NumRBGsDL-2 % If next RBG index is the last one in BWP
                                nextRBGSize = obj.NumPDSCHRBs - ((RBGIndex+1) * obj.RBGSizeDL);
                            end
                            if allottedRBCount(selectedUEIdx) > (obj.RBAllocationLimitDL - nextRBGSize)
                                % Not eligible for next RBG as max RB
                                % allocation limit would get breached
                                RBGEligibleUEs = setdiff(RBGEligibleUEs, selectedUE, 'stable');
                            end
                        end
                        
                        % Decrement the buffer status value of UE to
                        % reflect the assignment done for avoiding
                        % allocating unnecessary resources further
                        startRBIndex = obj.RBGSizeDL * RBGIndex;
                        % Last RBG can have lesser RBs as number of RBs might not
                        % be completely divisible by RBG size.
                        lastRBIndex = min(startRBIndex+obj.RBGSizeDL-1, obj.NumPDSCHRBs-1);
                        mcsInfo = obj.MCSTableDL(mcs + 1, :);
                        bitsPerSym = mcsInfo(3); % Accounting for both Modulation & Coding scheme
                        achievedTxBits = obj.getResourceBandwidth(bitsPerSym, (lastRBIndex - startRBIndex + 1), (numSym - obj.NumPDSCHDMRS));
                        bufferStatus = obj.UEsContextDL(selectedUE, 1);
                        updatedBufferStatus = max(0,(bufferStatus - (floor(achievedTxBits/8))));
                        updateUEBufferStatus(obj, obj.DLType, selectedUE, updatedBufferStatus);
                    end
                end
            end
            
            % Calculate a single MCS value for the PDSCH assignment to UEs
            % from the MCS values of all the RBGs allotted. Also select a
            % free HARQ process to be used for downlink over the selected
            % RBGs. It was already ensured that UEs in eligibleUEs set have
            % at least one free HARQ process before deeming them eligible
            % for getting resources for new transmission
            for i = 1:length(eligibleUEs)
                % If any resources were assigned to this UE
                if ~isempty(DLGrants{i})
                    grant = DLGrants{i};
                    grant.MCS = obj.MCSForRBGBitmap(rbgMCS(i, :)); % Get a single MCS for all allotted RBGs
                    % Select one HARQ process, update its context to reflect
                    % grant
                    selectedHarqId = findFreeUEHarqProcess(obj, obj.DLType, eligibleUEs(i));
                    harqProcess = hUpdateHARQProcess(obj.HarqProcessesDL(eligibleUEs(i), selectedHarqId+1), 1);
                    obj.HarqProcessesDL(eligibleUEs(i), selectedHarqId+1) = harqProcess;
                    grant.RV = harqProcess.RVSequence(harqProcess.RVIdx(1));
                    obj.HarqStatusAndNDIDL(eligibleUEs(i), selectedHarqId+1, 1) = 1; % Mark HARQ process as busy
                    grant.HARQId = selectedHarqId; % Fill HARQ Id
                    grant.NDI = ~obj.HarqStatusAndNDIDL(grant.RNTI, selectedHarqId + 1, 2); % Toggle the NDI for new transmission
                    DLGrants{i} = grant;
                end
            end
            newTxUEs = newTxUEs(1 : newTxGrantCount);
            DLGrants = DLGrants(~cellfun('isempty',DLGrants)); % Remove all empty elements
        end
        
        function k1 = getPDSCHFeedbackSlotOffset(obj, PDSCHSlotOffset)
            %getPDSCHFeedbackSlotOffset Calculate k1 i.e. slot offset of feedback (ACK/NACK) transmission from the PDSCH transmission slot
            % For FDD, k1 is set as 1 as every slot is a UL slot. For
            % TDD, k1 is set to slot offset of first upcoming slot with UL
            % symbols. Input 'PDSCHSlotOffset' is the slot offset of PDSCH
            % transmission slot from the current slot
            
            if obj.DuplexMode == 0 % FDD
                k1 = 2; % For FDD, feedback slot as next slot of the PDSCH transmission slot
            else % TDD
                % Calculate offset of first slot containing UL symbols, from PDSCH transmission slot
                k1 = 2;
                while(k1 < obj.NumSlotsFrame)
                    slotIndex = mod(obj.CurrDLULSlotIndex + PDSCHSlotOffset + k1, obj.NumDLULPatternSlots);
                    if find(obj.DLULSlotFormat(slotIndex + 1, :) == obj.ULType, 1)
                        break; % Found a slot with UL symbols
                    end
                    k1 = k1 + 1;
                end
            end
        end
        
        function schedulerInput = createSchedulerInput(obj, linkDir, slotNum, eligibleUEs, rbgIndex, startSym, numSym)
            %createSchedulerInput Create the input structure for scheduling strategy
            %
            % linkDir       - Link direction for scheduler (0 means DL and 1
            %                   means UL)
            % slotNum       - Slot whose TTI is currently getting scheduled
            %
            % eligibleUEs   - RNTI of the eligible UEs contending for the RBG
            %
            % rbgIndex      - Index of the RBG (which is getting scheduled) in the bandwidth
            %
            % startSym      - Start symbol of the TTI getting scheduled
            %
            % numSym        - Number of symbols in the TTI getting scheduled
            %
            % Scheduler input structure contains the following fields which
            % scheduler would use (not necessarily all the information) for
            % selecting the UE, which RBG would be assigned to:
            %
            %   eligibleUEs: RNTI of the eligible UEs contending for the RBG
            %
            %   RBGIndex: RBG index in the slot which is getting scheduled
            %
            %   slotNum: Slot whose TTI is currently getting scheduled
            %
            %   startSym: Start symbol of TTI
            %
            %   numSym: Number of symbols in TTI
            %
            %   RBGSize: RBG Size in terms of number of RBs
            %
            %   cqiRBG: Channel quality on RBG for UEs. N-by-P matrix with CQI
            %   values for UEs on different RBs of RBG. 'N' is number of
            %   eligible UEs and 'P' is RBG size in RBs
            %
            %   mcsRBG: MCS for eligible UEs based on the CQI values on the RBs of RBG.
            %   N-by-2 matrix where 'N' is number of eligible UEs. For each eligible
            %   UE, it has MCS index (first column) and efficiency (bits/symbol considering
            %   both Modulation and coding scheme)
            %
            %   bufferStatus: Buffer status of UEs. Vector of N elements where 'N'
            %   is number of eligible UEs, containing pending buffer status for UEs
            %
            %   ttiDur: TTI duration in ms
            %
            %   UEs: RNTI of all the UEs (even the non-eligible ones for this RBG)
            %
            %   lastSelectedUE: The RNTI of UE which was assigned the last scheduled RBG
            
            if linkDir % Uplink
                numRBs = obj.NumPUSCHRBs;
                rbgSize = obj.RBGSizeUL;
                ueContext = obj.UEsContextUL;
                channelQuality = obj.ChannelQualityUL;
                mcsTable = obj.MCSTableUL;
                schedulerInput.lastSelectedUE = obj.LastSelectedUEUL;
            else % Downlink
                numRBs = obj.NumPDSCHRBs;
                rbgSize = obj.RBGSizeDL;
                ueContext = obj.UEsContextDL;
                channelQuality = obj.ChannelQualityDL;
                mcsTable = obj.MCSTableDL;
                schedulerInput.lastSelectedUE = obj.LastSelectedUEDL;
            end
            schedulerInput.LinkDir = linkDir;
            startRBIndex = rbgSize * rbgIndex;
            % Last RBG can have lesser RBs as number of RBs might not
            % be completely divisible by RBG size
            lastRBIndex = min(startRBIndex + rbgSize - 1, numRBs - 1);
            schedulerInput.eligibleUEs = eligibleUEs;
            schedulerInput.slotNum = slotNum;
            schedulerInput.startSym = startSym;
            schedulerInput.numSym = numSym;
            schedulerInput.RBGIndex = rbgIndex;
            schedulerInput.RBGSize = lastRBIndex - startRBIndex + 1; % Number of RBs in this RBG
            for i = 1:length(eligibleUEs)
                schedulerInput.bufferStatus(i) = ueContext(eligibleUEs(i), 1);
                cqiRBG = channelQuality(eligibleUEs(i), startRBIndex+1 : lastRBIndex+1);
                schedulerInput.cqiRBG(i, :) = cqiRBG;
                CQISetRBG = floor(mean(cqiRBG));
                mcsRBG = getMCSIndex(obj, CQISetRBG);
                mcsInfo = mcsTable(mcsRBG + 1, :);
                bitsPerSym = mcsInfo(3); % Accounting for both modulation & coding scheme
                schedulerInput.mcsRBG(i, 1) = mcsRBG; % MCS index
                schedulerInput.mcsRBG(i, 2) = bitsPerSym; % MCS efficiency
            end
            schedulerInput.ttiDur = (numSym * obj.SlotDuration)/14; % In ms
            schedulerInput.UEs = obj.UEs;
        end
        
        function harqId = findFreeUEHarqProcess(obj, linkDir, rnti)
            %findFreeUEHarqProcess Returns index of a free uplink or downlink HARQ process of UE, based on the link direction (UL/DL)
            
            harqId = -1;
            numHarq = obj.NumHARQ;
            if linkDir % Uplink
                harqProcessInfo = squeeze(obj.HarqStatusAndNDIUL(rnti, :, :));
            else % Downlink
                harqProcessInfo = squeeze(obj.HarqStatusAndNDIDL(rnti, :, :));
            end
            for i = 1:numHarq
                harqStatus = harqProcessInfo(i, 1);
                if ~harqStatus % Free process
                    harqId = i-1;
                    return;
                end
            end
        end
        
        function eligibleUEs = getNewTxEligibleUEs(obj, linkDir, reTxUEs)
            %getNewTxEligibleUEs Return the UEs eligible for getting resources for new transmission
            % Out of all the UEs, the UEs which did not get retransmission
            % opportunity in the current TTI and have at least one free
            % HARQ process are considered eligible for getting resources
            % for new UL (linkDir = 1) or DL (linkDir = 0)
            % opportunity
            
            noReTxUEs = setdiff(obj.UEs, reTxUEs, 'stable'); % UEs which did not get any re-Tx opportunity
            eligibleUEs = noReTxUEs;
            % Eliminate further the UEs which do not have free HARQ process
            for i = 1:length(noReTxUEs)
                freeHarqId = findFreeUEHarqProcess(obj, linkDir, noReTxUEs(i));
                if freeHarqId == -1
                    % No HARQ process free on this UE, so not eligible.
                    eligibleUEs = setdiff(eligibleUEs, noReTxUEs(i), 'stable');
                end
            end
        end
        
        function [isAssigned, allottedBitmap, MCS] = getRetransmissionResources(obj, linkDir, rnti, ...
                tbs, rbgOccupancyBitmap, ~, ~, numSym)
            %getRetransmissionResources Based on the tbs, get the retransmission resources
            % A set of RBGs are chosen for retransmission grant along with
            % the corresponding MCS. The approach used is to find the set
            % of RBGs (which are free) with best channel quality w.r.t UE,
            % to increase the successful reception probability
            
            if linkDir % Uplink
                cqiRBs = obj.ChannelQualityUL(rnti, :);
                cqiRBGs = zeros(obj.NumRBGsUL, 1);
                numRBGs = obj.NumRBGsUL;
                allottedBitmap = zeros(1, numRBGs);
                RBGSize = obj.RBGSizeUL;
                numRBs = obj.NumPUSCHRBs;
                mcsTable = obj.MCSTableUL;
            else % Downlink
                cqiRBs = obj.ChannelQualityDL(rnti, :);
                cqiRBGs = zeros(obj.NumRBGsDL, 1);
                allottedBitmap = zeros(1, obj.NumRBGsDL);
                numRBGs = obj.NumRBGsDL;
                RBGSize = obj.RBGSizeDL;
                numRBs = obj.NumPDSCHRBs;
                mcsTable = obj.MCSTableDL;
            end
            
            isAssigned = 0;
            MCS = 0;
            % Calculate average CQI for each RBG
            for i = 1:numRBGs
                if ~rbgOccupancyBitmap(i)
                    startRBIndex = (i-1)*RBGSize + 1;
                    lastRBIndex = min(i*RBGSize, numRBs);
                    cqiRBGs(i) = floor(mean((cqiRBs(startRBIndex : lastRBIndex))));
                end
            end
            
            % Get the indices of RBGs in decreasing order of their CQI
            % values. Then start assigning the RBGs in this order, if the
            % RBG is free to use. Continue assigning the RBGs till the tbs
            % requirement is satisfied.
            [~, sortedIndices] = sort(cqiRBGs, 'descend');
            requiredBits = tbs;
            mcsRBGs = -1*ones(numRBGs, 1);
            for i = 1:numRBGs
                if ~rbgOccupancyBitmap(sortedIndices(i)) % Free RBG
                    % Calculate transport block bits capability of RBG
                    cqiRBG = cqiRBGs(sortedIndices(i));
                    mcsIndex = getMCSIndex(obj, cqiRBG);
                    mcsInfo = mcsTable(mcsIndex + 1, :);
                    numRBsRBG = RBGSize;
                    if sortedIndices(i) == numRBGs && mod(numRBs, RBGSize) ~= 0
                        % Last RBG might have lesser number of RBs
                        numRBsRBG = mod(numRBs, RBGSize);
                    end
                    modSchemeBits = mcsInfo(1); % Bits per symbol for modulation scheme
                    codeRate = mcsInfo(2)/1024;
                    % Modulation scheme and corresponding bits/symbol
                    fullmodlist = ["pi/2-BPSK", "BPSK", "QPSK", "16QAM", "64QAM", "256QAM"]';
                    qm = [1 1 2 4 6 8];
                    modScheme = fullmodlist((modSchemeBits == qm)); % Get modulation scheme string
                    nLayers = 1;
                    if linkDir % Uplink
                        nred = 12 * (numSym - obj.NumPUSCHDMRS); % Accommodating for DM-RS
                        servedBits = nrTBS(modScheme(1), nLayers, numRBsRBG, ...
                            nred, codeRate);
                    else % Downlink
                        nred = 12 * (numSym - obj.NumPDSCHDMRS); % Accommodating for DM-RS
                        servedBits = nrTBS(modScheme(1), nLayers, numRBsRBG, ...
                            nred, codeRate);
                    end
                    
                    requiredBits = max(0, requiredBits - servedBits);
                    allottedBitmap(sortedIndices(i)) = 1; % Selected RBG
                    mcsRBGs(sortedIndices(i)) = mcsIndex; % MCS for RBG
                    if ~requiredBits
                        % Retransmission TBS requirement have met
                        isAssigned = 1;
                        MCS = floor(mean(mcsRBGs(mcsRBGs>=0))); % Average MCS
                        break;
                    end
                end
            end
            
            % Although TBS requirement is fulfilled by RBG set with
            % corresponding MCS values calculated above but as the
            % retransmission grant needs to have a single MCS, so average
            % MCS of selected RBGs might bring down the tbs capability of
            % grant below the required tbs. If that happens, select the
            % biggest of the MCS values to satisfy the TBS requirement
            if isAssigned
                grantRBs = convertRBGBitmapToRBs(obj, allottedBitmap, linkDir);
                mcsInfo = mcsTable(MCS + 1, :);
                modSchemeBits = mcsInfo(1); % Bits per symbol for modulation scheme
                codeRate = mcsInfo(2)/1024;
                % Modulation scheme and corresponding bits/symbol
                fullmodlist = ["pi/2-BPSK", "BPSK", "QPSK", "16QAM", "64QAM", "256QAM"]';
                qm = [1 1 2 4 6 8];
                
                modScheme = fullmodlist(modSchemeBits == qm); % Get modulation scheme string
                % Calculate tbs capability of grant
                nLayers = 1;
                if linkDir % Uplink
                    nred = 12 * (numSym - obj.NumPUSCHDMRS); % Accommodating for DM-RS
                    actualServedBits = nrTBS(modScheme(1), nLayers, length(grantRBs), ...
                        nred, codeRate);
                else % Downlink
                    nred = 12 * (numSym - obj.NumPDSCHDMRS); % Accommodating for DM-RS
                    actualServedBits = nrTBS(modScheme(1), nLayers, length(grantRBs), ...
                        nred, codeRate);
                end
                if actualServedBits < tbs
                    % Average MCS is not sufficing, so taking the maximum MCS
                    % value
                    MCS = max(mcsRBGs);
                end
            end
        end
        
        function CQITable = getCQITableDL(~)
            %getCQITableDL Returns the CQI table as per TS 38.214 - Table
            %5.2.2.1-3
            
            CQITable = [0  0   0
                2 	78      0.1523
                2 	193 	0.3770
                2 	449 	0.8770
                4 	378 	1.4766
                4 	490 	1.9141
                4 	616 	2.4063
                6 	466 	2.7305
                6 	567 	3.3223
                6 	666 	3.9023
                6 	772 	4.5234
                6 	873 	5.1152
                8 	711 	5.5547
                8 	797 	6.2266
                8 	885 	6.9141
                8 	948 	7.4063];
        end
        
        function CQITable = getCQITableUL(~)
            %getCQITableUL Return the CQI table as per TS 38.214 - Table
            %5.2.2.1-3. As uplink channel quality is assumed in terms of CQIs,
            %using the same table as DL CQI table in 3GPP standard.
            
            CQITable = [0  0   0
                2 	78      0.1523
                2 	193 	0.3770
                2 	449 	0.8770
                4 	378 	1.4766
                4 	490 	1.9141
                4 	616 	2.4063
                6 	466 	2.7305
                6 	567 	3.3223
                6 	666 	3.9023
                6 	772 	4.5234
                6 	873 	5.1152
                8 	711 	5.5547
                8 	797 	6.2266
                8 	885 	6.9141
                8 	948 	7.4063];
        end
        
        function numBits = getResourceBandwidth(~, mcsEfficiency, numRBs, numSymbols)
            %getResourceBandwidth Returns approximate TBS bits supported by given frequency-time resources
            % It is calculated based on the MCS efficiency (number of MAC
            % bits per Symbol accounting for both modulation scheme and
            % coding rate), dimensions of frequency-time resources and
            % number of DM-RS
            
            numBits = floor(mcsEfficiency * numRBs * 12 * numSymbols);
        end
        
        function mcs = MCSForRBGBitmap(~, mcsValues)
            %MCSForRBGBitmap Calculates and returns single MCS value for the PUSCH assignment to a UE from the MCS values of all the RBGs allotted
            
            % Taking average of all the MCS values to reach the final MCS
            % value. This is just one way of doing it, it can be deduced
            % in any other way too
            mcs = floor(mean(mcsValues(mcsValues>=0)));
        end
        
        function mcsRowIndex = getMCSIndex(obj, cqiIndex)
            %getMCSIndex Returns the MCS row index based on cqiIndex
            
            % Valid rows in MCS table (as Index 28, 29, 30, 31 are reserved)
            % Indexing starts from 1
            validRows = (0:27) + 1;
            cqiRow = obj.CQITableUL(cqiIndex + 1, :);
            modulation = cqiRow(1);
            coderate = cqiRow(2);
            % List of matching indices in MCS table for modulation scheme
            % as per 'cqiIndex'
            modulationList = find((modulation == obj.MCSTableUL(validRows, 1)));
            
            % Indices in 'modulationList' which have code rate less than
            % equal to the code rate as per the 'cqiIndex'
            coderateList = find(obj.MCSTableUL(modulationList, 2) <= coderate);
            if isempty(coderateList)
                % If no match found, take the first value in 'modulationList'
                coderateList = modulationList(1);
            end
            % Take the value from 'modulationList' with highest code rate
            mcsRowIndex = modulationList(coderateList(end)) - 1;
        end
        
        function RBSet = convertRBGBitmapToRBs(obj, rbgBitmap, linkType)
            %convertRBGBitmapToRBs Convert RBGBitmap to corresponding RB indices
            
            if linkType % Uplink
                rbgSize = obj.RBGSizeUL;
                numRBs = obj.NumPUSCHRBs;
            else % Downlink
                rbgSize = obj.RBGSizeDL;
                numRBs = obj.NumPDSCHRBs;
            end
            RBSet = -1*ones(numRBs, 1); % To store RB indices of last UL grant
            for rbgIndex = 0:length(rbgBitmap)-1
                if rbgBitmap(rbgIndex+1)
                    % If the last RBG of BWP is assigned, then it
                    % might not have the same number of RBs as other RBG.
                    if rbgIndex == (length(rbgBitmap)-1)
                        RBSet((rbgSize*rbgIndex + 1) : end) = ...
                            rbgSize*rbgIndex : numRBs-1 ;
                    else
                        RBSet((rbgSize*rbgIndex + 1) : (rbgSize*rbgIndex + rbgSize)) = ...
                            (rbgSize*rbgIndex) : (rbgSize*rbgIndex + rbgSize -1);
                    end
                end
            end
            RBSet = RBSet(RBSet >= 0);
        end
        
        function populateDuplexModeProperties(obj, param)
            % Populate duplex mode dependent properties
            
            % Set the RBG size configuration (for defining number of RBs in
            % one RBG) to 1 (configuration-1 RBG table) or 2
            % (configuration-2 RBG table) as defined in 3GPP TS 38.214
            % Section 5.1.2.2.1. If it is not configured, take default
            % value as 1.
            if isfield(param, 'RBGSizeConfig')
                RBGSizeConfig = param.RBGSizeConfig;
            else
                RBGSizeConfig = 1;
            end
            
            if isfield(param, 'DuplexMode')
                obj.DuplexMode = param.DuplexMode;
            end
            if isfield(param, 'NumRBs')
                obj.NumPUSCHRBs = param.NumRBs;
                obj.NumPDSCHRBs = param.NumRBs;
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
            % As number of RBs may not be completely divisible by RBG
            % size, last RBG may not have the same number of RBs
            obj.NumRBGsUL = ceil(obj.NumPUSCHRBs/obj.RBGSizeUL);
            obj.NumRBGsDL = ceil(obj.NumPDSCHRBs/obj.RBGSizeDL);
            
            if obj.DuplexMode == 1 % TDD
                % Validate the TDD configuration and populate the properties
                populateTDDConfiguration(obj, param);
                
                % Set format of slots in the DL-UL pattern. Value 0, 1 and 2 means
                % symbol type as DL, UL and guard, respectively
                obj.DLULSlotFormat = obj.GuardType * ones(obj.NumDLULPatternSlots, 14);
                obj.DLULSlotFormat(1:obj.NumDLSlots, :) = obj.DLType; % Mark all the symbols of full DL slots as DL
                obj.DLULSlotFormat(obj.NumDLSlots + 1, 1 : obj.NumDLSyms) = obj.DLType; % Mark DL symbols following the full DL slots
                % For symbol based scheduling, the slot containing guard
                % period for DL-UL switch can have UL symbols after guard
                % period. While for slot based scheduling, this slot will
                % have guard period till the end of the slot, after
                % the DL symbols
                if obj.SchedulingType == 1 % For symbol based scheduling
                    obj.DLULSlotFormat(obj.NumDLSlots + floor(obj.GuardDuration/14) + 1, (obj.NumDLSyms + mod(obj.GuardDuration, 14) + 1) : end)  ...
                        = obj.ULType; % Mark UL symbols at the end of slot before full UL slots
                end
                obj.DLULSlotFormat((end - obj.NumULSlots + 1):end, :) = obj.ULType; % Mark all the symbols of full UL slots as UL type
                
                % Get the first slot with UL symbols
                slotNum = 0;
                while slotNum < obj.NumSlotsFrame && slotNum < obj.NumDLULPatternSlots
                    if find(obj.DLULSlotFormat(slotNum + 1, :) == obj.ULType, 1)
                        break; % Found a slot with UL symbols
                    end
                    slotNum = slotNum + 1;
                end
                
                obj.NextULSchedulingSlot = slotNum; % Set the first slot to be scheduled by UL scheduler
            else % FDD
                if isfield(param, 'SchedulerPeriodicity')
                    % Number of slots in a frame
                    numSlotsFrame = 10 *(obj.SCS / 15);
                    validateattributes(param.SchedulerPeriodicity, {'numeric'}, {'nonempty', ...
                        'integer', 'scalar', '>', 0, '<=', numSlotsFrame}, 'param.SchedulerPeriodicity', ...
                        'SchedulerPeriodicity');
                    obj.SchedulerPeriodicity = param.SchedulerPeriodicity;
                end
                % Initialization to make sure that schedulers run in the
                % very first slot of simulation run
                obj.SlotsSinceSchedulerRunDL = obj.SchedulerPeriodicity - 1;
                obj.SlotsSinceSchedulerRunUL = obj.SchedulerPeriodicity - 1;
            end
        end
        
        function populateTDDConfiguration(obj, param)
            %populateTDDConfiguration Validate TDD configuration and
            %populate the properties
            
            % Validate the DL-UL pattern duration
            validDLULPeriodicity{1} =  { 1 2 5 10 }; % Applicable for scs = 15 kHz
            validDLULPeriodicity{2} =  { 0.5 1 2 2.5 5 10 }; % Applicable for scs = 30 kHz
            validDLULPeriodicity{3} =  { 0.5 1 1.25 2 2.5 5 10 }; % Applicable for scs = 60 kHz
            validDLULPeriodicity{4} =  { 0.5 0.625 1 1.25 2 2.5 5 10}; % Applicable for scs = 120 kHz
            validSCS = [15 30 60 120];
            if ~ismember(obj.SCS, validSCS)
                error('nr5g:hNRScheduler:InvalidSCS','The subcarrier spacing ( %d ) must be one of the set (%s).',obj.SCS, sprintf(repmat('%d ', 1, length(validSCS)), validSCS));
            end
            numerology = find(validSCS==obj.SCS, 1, 'first');
            validSet = cell2mat(validDLULPeriodicity{numerology});
            
            if isfield(param, 'DLULPeriodicity')
                validateattributes(param.DLULPeriodicity, {'numeric'}, {'nonempty'}, 'param.DLULPeriodicity', 'DLULPeriodicity');
                if ~ismember(param.DLULPeriodicity, cell2mat(validDLULPeriodicity{numerology}))
                    error('nr5g:hNRScheduler:InvalidNumDLULSlots','DLULPeriodicity (%.3f) must be one of the set (%s).', ...
                        param.DLULPeriodicity, sprintf(repmat('%.3f ', 1, length(validSet)), validSet));
                end
                numSlotsDLDULPattern = param.DLULPeriodicity/obj.SlotDuration;
                
                % Validate the number of full DL slots at the beginning of DL-UL pattern
                validateattributes(param.NumDLSlots, {'numeric'}, {'nonempty'}, 'param.NumDLSlots', 'NumDLSlots');
                if~(param.NumDLSlots <= (numSlotsDLDULPattern-1))
                    error('nr5g:hNRScheduler:InvalidNumDLSlots','Number of full DL slots (%d) must be less than numSlotsDLDULPattern(%d).', ...
                        param.NumDLSlots, numSlotsDLDULPattern);
                end
                
                % Validate the number of full UL slots at the end of DL-UL pattern
                validateattributes(param.NumULSlots, {'numeric'}, {'nonempty'}, 'param.NumULSlots', 'NumULSlots');
                if~(param.NumULSlots <= (numSlotsDLDULPattern-1))
                    error('nr5g:hNRScheduler:InvalidNumULSlots','Number of full UL slots (%d) must be less than numSlotsDLDULPattern(%d).', ...
                        param.NumULSlots, numSlotsDLDULPattern);
                end
                
                if~(param.NumDLSlots + param.NumULSlots  <= (numSlotsDLDULPattern-1))
                    error('nr5g:hNRScheduler:InvalidNumDLULSlots','Sum of full DL and UL slots(%d) must be less than numSlotsDLDULPattern(%d).', ...
                        param.NumDLSlots + param.NumULSlots, numSlotsDLDULPattern);
                end
                
                % Validate that there must be some UL resources in the DL-UL pattern
                if obj.SchedulingType == 0 && param.NumULSlots == 0
                    error('nr5g:hNRScheduler:InvalidNumULSlots','Number of full UL slots (%d) must be greater than {0} for slot based scheduling', param.NumULSlots);
                end
                if obj.SchedulingType == 1 && param.NumULSlots == 0 && param.NumULSyms == 0
                    error('nr5g:hNRScheduler:InvalidULResources','DL-UL pattern must contain UL resources. Set NumULSlots(%d) or NumULSyms(%d) to a positive integer).', ...
                        param.NumULSlots, param.NumULSyms);
                end
                % Validate that there must be some DL resources in the DL-UL pattern
                if(param.NumDLSlots == 0 && param.NumDLSyms == 0)
                    error('nr5g:hNRScheduler:InvalidDLResources','DL-UL pattern must contain DL resources. Set NumDLSlots(%d) or NumDLSyms(%d) to a positive integer).', ...
                        param.NumDLSlots, param.NumDLSyms);
                end
                
                obj.NumDLULPatternSlots = param.DLULPeriodicity/obj.SlotDuration;
                obj.NumDLSlots = param.NumDLSlots;
                obj.NumULSlots = param.NumULSlots;
                obj.NumDLSyms = param.NumDLSyms;
                obj.NumULSyms = param.NumULSyms;
                
                % All the remaining symbols in DL-UL pattern are assumed to
                % be guard symbols
                obj.GuardDuration = (obj.NumDLULPatternSlots * 14) - ...
                    (((obj.NumDLSlots + obj.NumULSlots)*14) + ...
                    obj.NumDLSyms + obj.NumULSyms);
            end
        end
    end
end