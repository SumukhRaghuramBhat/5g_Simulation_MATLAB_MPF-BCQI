classdef hNRAMEntity < hNRRLCEntity
%hNRAMEntity Implement RLC AM functionality
%   RLCAMOBJ = hNRAMEntity creates an object for the radio link control
%   (RLC) acknowledged mode (AM) service as specified by the 3GPP TS
%   38.322.
%
% hNRAMEntity methods:
%
%   send                    - Queue the received service data units (SDUs)
%                             from higher layers in the Tx buffer
%   notifyTxOpportunity     - Send the RLC protocol data units (PDUs) that
%                             fit in the grant notified by medium access
%                             control (MAC) layer
%   getBufferStatus         - Return the current buffer status of the
%                             associated logical channel
%   receive                 - Process the received PDU from the MAC layer
%   updateTimer             - Decrement the active timers by 1 ms
%   getStatistics           - Return the statistics array
%
%   hNRAMEntity properties:
%
%   RNTI                    - UE's radio network temporary identifier
%   LogicalChannelID        - Logical channel identifier
%   SeqNumFieldLength       - Sequence number (SN) field length in bits
%   PollRetransmitTimer     - Timer for retransmitting poll bit
%   PollPDU                 - Number of RLC PDUs after which poll bit needs
%                             to be sent
%   PollByte                - Number of SDU bytes after which poll bit
%                             needs to be sent
%   MaxRetransmissions      - Limit of the number of retransmissions
%   MaxTxBufferSDUs         - Maximum capacity of the Tx buffer in terms of
%                             number of SDUs
%   ReassemblyTimer         - Timer to detect the reassembly failure of
%                             SDUs in the reception buffer
%   StatusProhibitTimer     - Timer to prohibit the transmission of status
%                             PDU after previous one
%   MaxReassemblySDU        - Number of SDUs that can be under reassembly
%                             procedure at any point of time

% Copyright 2020 The MathWorks, Inc.

    properties (Access = public)
        % RNTI Radio network temporary identifier of a UE
        %   Specify the RNTI as an integer scalar within the [1, 65519]
        %   range. For more details, refer 3GPP TS 38.321 Table 7.1-1. The
        %   default is 1.
        RNTI (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(RNTI, 1), mustBeLessThanOrEqual(RNTI, 65519)} = 1;
        % LogicalChannelID Logical channel identifier
        %   Specify the logical channel identifier as an integer scalar
        %   within the [1, 32] range. For more details, refer 3GPP TS
        %   38.322 Table 6.2.1-1. The default is 1.
        LogicalChannelID (1, 1) {mustBeInteger, mustBeGreaterThanOrEqual(LogicalChannelID, 1), mustBeLessThanOrEqual(LogicalChannelID, 32)} = 1;
        % SeqNumFieldLength Sequence number field size in bits for
        % the transmitter and receiver sides
        %   Specify the sequence number field length as 1-by-2 matrix where
        %   each element is one of '12' | '18'. The default is [12 12]. It
        %   can also accepts scalar as an input and it will create a 1-by-2
        %   matrix with the specified input. For more details, refer 3GPP
        %   TS 38.322 Section 6.2.3.3.
        SeqNumFieldLength (1, 2) {mustBeMember(SeqNumFieldLength, [12 18])} = 12;
        % PollRetransmitTimer Timer used by the transmitting side of an AM
        % RLC entity in order to retransmit a poll
        %   Specify the poll retransmit timer value as one of 5, 10, 15,
        %   20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 75, 80, 85, 90, 95,
        %   100, 105, 110, 115, 120, 125, 130, 135, 140, 145, 150, 155,
        %   160, 165, 170, 175, 180, 190, 195, 200, 205, 210, 215, 220,
        %   225, 230, 235, 240, 245, 250, 300, 350, 400, 450, 500, 800,
        %   1000, 2000, or 4000 ms. For more details, refer 3GPP TS 38.331
        %   information element RLC-Config. The default is 10.
        PollRetransmitTimer (1, 1) {mustBeMember(PollRetransmitTimer, ...
            [5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, ...
            60, 65, 75, 80, 85, 90, 95, 100, 105, 110, ...
            115, 120, 125, 130, 135, 140, 145, 150, ...
            155, 160, 165, 170, 175, 180, 190, 195, ...
            200, 205, 210, 215, 220, 225, 230, 235, ...
            240, 245, 250, 300, 350, 400, 450, 500, 800, ...
            1000, 2000, 4000])} = 10;
        % PollPDU Parameter used by the transmitting side of an AM RLC
        % entity to trigger a poll based on number of PDUs
        %   Specify the number of poll PDUs as one of 4, 8, 16, 32, 64,
        %   128, 256, 512, 1024, 2048, 4096, 6144, 8192, 12288, 16384,
        %   20480, 24576, 28672, 32768, 40960, 49152, 57344, 65536, or 0
        %   (infinite). The value 0 is considered as infinite. For more
        %   details, refer 3GPP TS 38.331 information element RLC-Config.
        %   The default is 4.
        PollPDU (1, 1) {mustBeMember(PollPDU, ...
            [4, 8, 16, 32, 64, 128, 256, 512, 1024, 2048, 4096, 6144, ...
            8192, 12288, 16384, 20480, 24576, 28672, 32768, 40960, 49152, ...
            57344, 65536, 0])} = 4;
        % PollByte Parameter used by the transmitting side of an AM RLC
        % entity to trigger a poll based on number of SDU bytes
        %   Specify the number of poll bytes as one of 1, 2, 5, 8, 10, 15,
        %   25, 50, 75, 100, 125, 250, 375, 500, 750, 1000, 1250, 1500,
        %   2000, 3000, 4000, 4500, 5000, 5500, 6000, 6500, 7000, 7500,
        %   8192, 9216, 10240, 11264, 12228, 13312, 14336, 15360, 16384,
        %   17408, 18432, 20480, 25600, 30720, 40960, or 0 (infinite) kilo
        %   bytes. The value 0 is considered as infinite. For more details,
        %   refer 3GPP TS 38.331 information element RLC-Config. The
        %   default is 1.
        PollByte (1, 1) {mustBeMember(PollByte, [1, 2, 5, 8, 10, 15, ...
            25, 50, 75, 100, 125, 250, 375, 500, 750, 1000, 1250, 1500, ...
            2000, 3000, 4000, 4500, 5000, 5500, 6000, 6500, 7000, ...
            7500, 8192, 9216, 10240, 11264, 12228, 13312, 14336, ...
            15360, 16384, 17408, 18432, 20480, 25600, 30720, 40960, 0])} = 1;
        % MaxRetransmissions Maximum number of retransmissions
        % corresponding to an RLC SDU, including its segments
        %   Specify the maximum retransmission threshold as one of 1, 2, 3,
        %   4, 6, 8, 16, or 12. For more details, refer 3GPP TS 38.331
        %   information element RLC-Config. The default is 4.
        MaxRetransmissions (1, 1) {mustBeMember(MaxRetransmissions, [1, 2, 3, 4, 6, 8, 16, 32])} = 4;
        % MaxTxBufferSDUs Maximum capacity of the Tx buffer in terms of
        % number of SDUs
        %   Specify the maximum Tx buffer capacity of an RLC entity as a
        %   positive integer scalar. The default is 64.
        MaxTxBufferSDUs (1, 1) {mustBeInteger, mustBeGreaterThan(MaxTxBufferSDUs, 0)} = 64;
        % ReassemblyTimer Timer used by the receiving side of an RLC entity
        % in order to detect the reassembly failure
        %   Specify the reassembly timer value as one of 0, 5, 10, 15, 20,
        %   25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95,
        %   100, 110, 120, 130, 140, 150, 160, 170, 180, 190, or 200 ms.
        %   For more details, refer 3GPP TS 38.331 information element
        %   RLC-Config. The default is 10.
        ReassemblyTimer (1, 1) {mustBeMember(ReassemblyTimer, ...
            [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, ...
            60, 65, 75, 80, 85, 90, 95, 100, 105, 110, ...
            115, 120, 125, 130, 135, 140, 145, 150, ...
            155, 160, 165, 170, 175, 180, 190, 195, 200])} = 10;
        % StatusProhibitTimer Timer used by the receiving side of an RLC
        % entity in order to prohibit frequent transmission of control PDU
        %   Specify the status prohibit timer values as one of 0, 5, 10,
        %   15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 75, 80, 85, 90, 95,
        %   100, 105, 110, 115, 120, 125, 130, 135, 140, 145, 150, 155,
        %   160, 165, 170, 175, 180, 190, 195, 200, 205, 210, 215, 220,
        %   225, 230, 235, 240, 245, 250, 300, 350, 400, 450, 500, 800,
        %   1000, 1200, 1600, 2000, or 2400 ms. For more details, refer
        %   3GPP TS 38.331 information element RLC-Config. The default
        %   value is 10.
        StatusProhibitTimer (1, 1) {mustBeMember(StatusProhibitTimer, [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55,...
            60, 65, 75, 80, 85, 90, 95, 100, 105, 110, ...
            115, 120, 125, 130, 135, 140, 145, 150, ...
            155, 160, 165, 170, 175, 180, 190, 195, ...
            200, 205, 210, 215, 220, 225, 230, 235, ...
            240, 245, 250, 300, 350, 400, 450, 500, 800, 1000, ...
            1200, 1600, 2000, 2400])} = 10;
        % MaxReassemblySDU Maximum capacity of the reassembly buffer in
        % terms of number of SDUs
        %   Specify the maximum capacity of the reassembly buffer as an
        %   integer scalar. The reassembly buffer capacity depends on the
        %   number of HARQ processes present. If the number of SDUs under
        %   reassembly reaches the limit, the oldest SDU in the buffer will
        %   be discarded. The default is 16.
        MaxReassemblySDU (1, 1) {mustBeInteger, mustBeGreaterThan(MaxReassemblySDU, 0)} = 16;
    end

    properties(Access = private)
        %% Tx properties
        % TxBuffer Buffer to store the RLC SDUs received from higher
        % layers. This is a N-by-1 cell array where 'N' is the maximum
        % number of SDUs which can be buffered
        TxBuffer
        % TxHeaderBuffer Buffer to store the associated RLC headers for the
        % received SDUs from higher layers. This is a N-by-1 cell array
        % where 'N' is the maximum number of SDUs which can be buffered
        TxHeaderBuffer
        % TxBufferFront Index that points to the earliest SDU in the Tx
        % buffer
        TxBufferFront = 0;
        % NumTxBufferSDUs Number of SDUs in the Tx buffer
        NumTxBufferSDUs = 0;
        % WaitingForACKBuffer Buffer to store the transmitted/retransmitted
        % SDUs which are waiting for the acknowledgment. This is a N-by-1
        % cell array where 'N' is the maximum number of SDUs which can be
        % buffered
        WaitingForACKBuffer
        % WaitingForACKBufferContext Buffer to store the context of SDUs
        % which are waiting for the acknowledgment. This is a N-by-2 matrix
        % where 'N' is the maximum number of SDUs which can be buffered.
        % Each row has the following information: sequence number and
        % retransmission count
        WaitingForACKBufferContext
        % NumSDUsWaitingForACK Number of SDUs that are waiting for the
        % acknowledgment
        NumSDUsWaitingForACK = 0;
        % ReTxBuffer Buffer to store the SDUs which has received the
        % negative acknowledgment. This is a N-by-1 cell array where 'N'
        % is the maximum number of SDUs which can be buffered
        ReTxBuffer
        % ReTxBufferContext Buffer to store the context of the SDUs in the
        % retransmission buffer. This is a N-by-(2 + 2*P) matrix where 'N'
        % is the maximum Tx buffer SDUs and 'P' is the maximum number of
        % segment gaps possible at any point of time. Values at indexes (i,
        % 1), (i, 2), (i, 3:end) indicate sequence number, retransmission
        % count, and lost segments information, respectively
        ReTxBufferContext
        % ReTxBufferFront Index that points to the earliest SDU in the
        % retransmission buffer
        ReTxBufferFront = 0;
        % NumReTxBufferSDUs Number of SDUs in the retransmission buffer
        NumReTxBufferSDUs = 0;
        % TxNext SN to be assigned for the newly received SDU from higher
        % layers
        TxNext = 0;
        % TxNextAck Earliest SN that is yet to receive a positive
        % acknowledgment
        TxNextAck = 0;
        % SegmentOffset Position of the segmented SDU in bytes within the
        % original SDU in Tx buffer
        SegmentOffset = 0;
        % RequiredGrantLength Size of the required grant to transmit the
        % SDUs in the Tx and retransmission buffer
        RequiredGrantLength = 0;
        % TxSeqNumFieldLength Sequence number field length in bits for the
        % Tx side
        TxSeqNumFieldLength
        % TotalTxSeqNum Total sequence numbers configured for the use of Tx
        % side
        TotalTxSeqNum
        % TxSubmitted Sequence number of the last SDU that has been
        % submitted to lower layer
        TxSubmitted = -1;
        % AMTxWindowSize SN window size used by the transmitting side of an
        % RLC AM entity for the retransmission procedure. The window size
        % is 2048 and 131072 for 12 bit and 18 bit SN, respectively
        AMTxWindowSize = 2048;
        % PDUsWithoutPoll Number of PDUs after which a status report can be
        % requested
        PDUsWithoutPoll = 0;
        % BytesWithoutPollbit Number of SDU bytes after which a status
        % report can be requested
        BytesWithoutPoll = 0;
        % PollSN The highest SN among the AMD PDUs submitted to MAC
        PollSN = 0;
        % PollRetransmitTimeLeft Time left for the retransmission of status
        % report request
        PollRetransmitTimeLeft = 0;
        % RetransmitPollFlag Flag that indicates the retransmission of poll
        % is triggered
        RetransmitPollFlag = false;

        %% Rx properties
        % RxBuffer Buffer to store the segmented SDUs for reassembly. This
        % is a N-by-1 cell array where 'N' is the maximum reassembly buffer
        % length
        RxBuffer
        % ReassemblySNMap Map that shows where the segmented SDUs are
        % stored in the reassembly buffer. This is a N-by-1 column vector
        % where 'N' is the maximum reassembly buffer length. Each element
        % contains the SN of the SDUs which are under reassembly procedure.
        % Each element in the vector can take value in the range between -1
        % and 2^SeqNumFieldLength-1. if an element is set to -1, it
        % indicates that is not occupied by any SDUs SN
        ReassemblySNMap
        % RcvdSNList List of contiguously received full SDU SNs that help
        % in the status PDU construction. This is a N-by-2 matrix where 'N'
        % is the maximum reassembly buffer length. Each row has a starting
        % SN and ending SN that indicates a contiguous reception of SNs in
        % the receiving window. Value [-1, -1] in a row indicates
        % unoccupancy
        RcvdSNList
        % RxNext SN of the last in-sequence completely received RLC SDU. It
        % serves as the lower end of the receiving window
        RxNext = 0;
        % RxNextHighest SN following the SN of the RLC SDU with the highest
        % SN among received RLC SDUs
        RxNextHighest = 0;
        % RxNextStatusTrigger SN following the SN of the RLC SDU which
        % triggered reassembly timer
        RxNextStatusTrigger = 0;
        % RxHighestStatus The highest possible SN which can be indicated by
        % ACK SN when a status PDU needs to be constructed
        RxHighestStatus = 0;
        % RxSeqNumFieldLength Sequence number field length of the Rx side
        RxSeqNumFieldLength
        % TotalRxSeqNum Total sequence numbers configured for the use of Rx
        % side
        TotalRxSeqNum
        % AMRxWindowSize SN window size used by the receiving side of an
        % RLC AM entity for the reassembly procedure. The window size is
        % 2048 and 131072 for 12 bit and 18 bit SN, respectively
        AMRxWindowSize = 2048;
        % IsStatusPDUTriggered Flag that indicates whether a status report
        % is triggered. The values true and false indicate triggered and
        % not triggered, respectively
        IsStatusPDUTriggered = false;
        % IsStatusPDUDelayed Flag that indicates whether the status report
        % is delayed. The values true and false indicate delayed and not
        % delayed, respectively
        IsStatusPDUDelayed = false;
        % IsStatusPDUTriggeredOverSPT Flag that indicates whether the
        % status report is requested when the status prohibit timer is
        % running. A value of 'true' indicates that the request is made
        % when the status prohibit timer is running
        IsStatusPDUTriggeredOverSPT = false;
        % ReassemblyTimeLeft Time left for the reassembly procedure
        ReassemblyTimeLeft = 0;
        % PollRetransmitTimeLeft Time left to avoid the transmission of
        % status PDU
        StatusProhibitTimeLeft = 0;
        % GrantRequiredForStatusReport Grant size required for the status
        % report triggered
        GrantRequiredForStatusReport = 0;
        % DataPDUInfo Data container that holds the decoded data PDU
        % information
        DataPDUInfo
    end

    properties (Access = private, Constant)
        % AMWindowSizeFor18bitSN SN window size for 18-bit SN field length
        AMWindowSizeFor18bitSN = 131072;
    end

    methods(Access = public)
        function obj = hNRAMEntity(config)
            %hNRAMEntity Create an RLC AM entity
            %   OBJ = hNRAMEntity(CONFIG) creates an RLC AM entity.
            %
            %   CONFIG is a structure that contains the following fields:
            %
            %   RNTI is a radio network temporary identifier, specified in
            %   the [1, 65519] range. For more details, refer 3GPP TS
            %   38.321 Table 7.1-1.
            %
            %   LogicalChannelID is a logical channel identifier, specified
            %   in the [1, 32] range. For more details, refer 3GPP TS
            %   38.321 Table 6.2.1-1.
            %
            %   SeqNumFieldLength is the length of sequence number in bits
            %   for the transmitter and receiver entities, specified as a
            %   1-by-2 matrix. Each element of the SEQNUMFIELDLENGTH is
            %   specified as '12' | '18'. For more details, refer 3GPP TS
            %   38.322 Section 6.2.3.3.
            %
            %   PollRetransmitTimer is an integer scalar, specified as one
            %   of 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 75,
            %   80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130, 135,
            %   140, 145, 150, 155, 160, 165, 170, 175, 180, 190, 195, 200,
            %   205, 210, 215, 220, 225, 230, 235, 240, 245, 250, 300, 350,
            %   400, 450, 500, 800, 1000, 2000, or 4000 ms. For more
            %   details, refer 3GPP TS 38.331 information element
            %   RLC-Config.
            %
            %   PollPDU is an integer scalar, specified as one of 4, 8, 16,
            %   32, 64, 128, 256, 512, 1024, 2048, 4096, 6144, 8192, 12288,
            %   16384, 20480, 24576, 28672, 32768, 40960, 49152, 57344,
            %   65536, or 0 (infinite). The value 0 is considered as
            %   infinite. For more details, refer 3GPP TS 38.331
            %   information element RLC-Config.
            %
            %   PollByte is an integer scalar, specified as one of 1, 2, 5,
            %   8, 10, 15, 25, 50, 75, 100, 125, 250, 375, 500, 750, 1000,
            %   1250, 1500, 2000, 3000, 4000, 4500, 5000, 5500, 6000, 6500,
            %   7000, 7500, 8192, 9216, 10240, 11264, 12228, 13312, 14336,
            %   15360, 16384, 17408, 18432, 20480, 25600, 30720, 40960, or
            %   0 (infinite) kilo bytes. The value 0 is considered as
            %   infinite. For more details, refer 3GPP TS 38.331
            %   information element RLC-Config.
            %
            %   MaxRetransmissions is an integer scalar, specified as one
            %   of 1, 2, 3, 4, 6, 8, 16, or 12. For more details, refer
            %   3GPP TS 38.331 information element RLC-Config.
            %
            %   MaxTxBufferSDUs is the maximum Tx buffer SDUs of the
            %   logical channel, specified as a positive integer scalar.
            %
            %   ReassemblyTimer is an integer scalar, specified as one of
            %   0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70,
            %   75, 80, 85, 90, 95, 100, 110, 120, 130, 140, 150, 160, 170,
            %   180, 190, or 200 ms. For more details, refer 3GPP TS 38.331
            %   information element RLC-Config.
            %
            %   StatusProhibitTimer is an integer scalar, specified as one
            %   of 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65,
            %   75, 80, 85, 90, 95, 100, 105, 110, 115, 120, 125, 130, 135,
            %   140, 145, 150, 155, 160, 165, 170, 175, 180, 190, 195, 200,
            %   205, 210, 215, 220, 225, 230, 235, 240, 245, 250, 300, 350,
            %   400, 450, 500, 800, 1000, 1200, 1600, 2000, or 2400 ms. For
            %   more details, refer 3GPP TS 38.331 information element
            %   RLC-Config
            %
            %   MaxReassemblySDU is an integer scalar, used as the maximum
            %   number of SDUs that can be under reassembly process at any
            %   point of time.

            if nargin > 0
                if isfield(config, 'RNTI')
                    obj.RNTI = config.RNTI;
                end
                if isfield(config, 'LogicalChannelID')
                    obj.LogicalChannelID = config.LogicalChannelID;
                end
                if isfield(config, 'SeqNumFieldLength')
                    obj.SeqNumFieldLength = config.SeqNumFieldLength;
                end
                if isfield(config, 'MaxTxBufferSDUs')
                    obj.MaxTxBufferSDUs = config.MaxTxBufferSDUs;
                end
                if isfield(config, 'PollPDU')
                    obj.PollPDU = config.PollPDU;
                end
                if isfield(config, 'PollByte')
                    obj.PollByte = config.PollByte;
                end
                if isfield(config, 'PollRetransmitTimer')
                    obj.PollRetransmitTimer = config.PollRetransmitTimer;
                end
                if isfield(config, 'MaxRetransmissions')
                    obj.MaxRetransmissions = config.MaxRetransmissions;
                end
                if isfield(config, 'ReassemblyTimer')
                    obj.ReassemblyTimer = config.ReassemblyTimer;
                end
                if isfield(config, 'StatusProhibitTimer')
                    obj.StatusProhibitTimer = config.StatusProhibitTimer;
                end
                if isfield(config, 'MaxReassemblySDU')
                    obj.MaxReassemblySDU = config.MaxReassemblySDU;
                end
            end

            %% Initialize Tx side configuration
            obj.TxSeqNumFieldLength = obj.SeqNumFieldLength(1);
            if obj.TxSeqNumFieldLength == 18
                obj.AMTxWindowSize = obj.AMWindowSizeFor18bitSN;
            end
            obj.TotalTxSeqNum = 2*obj.AMTxWindowSize;
            obj.TxBuffer = cell(obj.MaxTxBufferSDUs, 1);
            obj.TxHeaderBuffer = cell(obj.MaxTxBufferSDUs, 1);
            obj.WaitingForACKBuffer = cell(obj.MaxTxBufferSDUs, 1);
            obj.WaitingForACKBufferContext = -1 * ones(obj.MaxTxBufferSDUs, 2);
            obj.ReTxBuffer = cell(obj.MaxTxBufferSDUs, 1);
            obj.ReTxBufferContext = -1 * ones(obj.MaxTxBufferSDUs, 2 + obj.MaxReassemblySDU*2);

            %% Initialize Rx side configuration
            obj.DataPDUInfo = hNRRLCDataPDUInfo();
            obj.RxSeqNumFieldLength = obj.SeqNumFieldLength(2);
            if obj.RxSeqNumFieldLength == 18
                obj.AMRxWindowSize = obj.AMWindowSizeFor18bitSN;
            end
            obj.TotalRxSeqNum = 2*obj.AMRxWindowSize;
            % Define Rx buffer objects to help in reassembly procedure
            obj.RxBuffer = repmat({hNRRLCDataReassembly(obj.MaxReassemblySDU)}, obj.MaxReassemblySDU, 1);
            for pktIdx = 1:obj.MaxReassemblySDU
                obj.RxBuffer{pktIdx} = hNRRLCDataReassembly(obj.MaxReassemblySDU);
            end
            obj.RcvdSNList = -1 * ones(obj.MaxReassemblySDU, 2);
            obj.ReassemblySNMap = -1 * ones(obj.MaxReassemblySDU, 1);
        end

        function send(obj, rlcSDU)
            %send Queue the received SDUs from higher layers in the Tx
            % buffer
            %   send(OBJ, RLCSDU) queues the received RLCSDU in the Tx
            %   buffer. This also generates and stores the corresponding
            %   RLC AM header in the Tx header buffer.
            %
            %   RLCSDU is a column vector of octets in decimal format,
            %   which represents the RLC SDU.

            rlcSDULength = numel(rlcSDU);
            % The maximum RLC SDU is 9000 bytes as per 3GPP TS 38.323
            % Section 4.3.1. If the received SDU size is more than the
            % maximum RLC SDU size, throw an error
            if rlcSDULength > obj.MaxSDUSize
                error('nr5g:hNRRLCEntity:InvalidSDUSize', 'RLC SDU size must be <= 9000 bytes');
            end
            % On Tx buffer overflow, discard the received. Update the
            % statistics accordingly
            if obj.NumTxBufferSDUs == obj.MaxTxBufferSDUs
                obj.StatTxPacketsDropped = obj.StatTxPacketsDropped + 1;
                obj.StatTxBytesDropped = obj.StatTxBytesDropped + rlcSDULength;
                return;
            end
            % Store the SDU in the RLC Tx buffer and its associated RLC
            % header in the RLC Tx header buffer
            sduEnqueueIdx = mod(obj.TxBufferFront + obj.NumTxBufferSDUs, obj.MaxTxBufferSDUs) + 1;
            obj.TxBuffer{sduEnqueueIdx} = rlcSDU;
            obj.TxHeaderBuffer{sduEnqueueIdx} = obj.generateDataHeader(0, obj.TxSeqNumFieldLength, obj.TxNext, 0);
            obj.NumTxBufferSDUs = obj.NumTxBufferSDUs + 1;

            % Update the SN to be assigned for the next RLC SDU
            obj.TxNext = mod(obj.TxNext + 1, obj.TotalTxSeqNum);

            % Increment the required grant size by the sum of expected MAC
            % header length and complete RLC PDU length
            rlcPDULength = rlcSDULength + length(obj.TxHeaderBuffer{sduEnqueueIdx});
            obj.RequiredGrantLength = obj.RequiredGrantLength + ...
                obj.getMACHeaderLength(rlcPDULength) + rlcPDULength;
            % Send the updated RLC buffer status report to MAC layer
            obj.TxBufferStatusFcn(obj.getBufferStatus());
        end

        function rlcPDUSet = notifyTxOpportunity(obj, bytesGranted, remainingTBS)
            %notifyTxOpportunity Send the RLC PDUs that fit in the grant
            % notified by MAC layer
            %   RLCPDUSET = notifyTxOpportunity(OBJ, BYTESGRANTED,
            %   REMAININGTBS) sends the RLC PDUs that fit in the grant
            %   notified by MAC layer.
            %
            %   RLCPDUSET is a cell array of RLC AM PDUs. This includes
            %   both control and data PDUs.
            %
            %   BYTESGRANTED is a positive integer scalar, which represents
            %   the number of granted transmission bytes.
            %
            %   REMAININGTBS is an integer scalar, which represents the
            %   remaining number of bytes in the transport block size
            %   (TBS). Remaining grant is greater than or equal to 0. This
            %   helps to avoid the segmentation of RLC SDUs in round-1 of
            %   MAC logical channel prioritization (LCP) procedure.

            rlcPDUSet = {};
            remainingGrant = bytesGranted;

            if obj.IsStatusPDUTriggered && (obj.StatusProhibitTimeLeft == 0)
                % Construct the status PDU and update the statistics
                % accordingly
                rlcPDUSet{end+1} = obj.constructStatusPDU(remainingGrant + remainingTBS);
                obj.StatTxControlPDU = obj.StatTxControlPDU + 1;
                obj.StatTxControlBytes = obj.StatTxControlBytes + numel(rlcPDUSet{end, 1});
                % Upon construction of status PDU, start status prohibit
                % timer before sending it to the MAC and reset the status
                % PDU delay flag
                obj.IsStatusPDUDelayed = false;
                obj.StatusProhibitTimeLeft = obj.StatusProhibitTimer;
                % Update the amount of grant left in the given grant and
                % buffer status of the RLC entity
                remainingGrant = remainingGrant - numel(rlcPDUSet{end, 1});
                obj.RequiredGrantLength = obj.RequiredGrantLength - obj.GrantRequiredForStatusReport;
                obj.GrantRequiredForStatusReport = 0;
            end
            [reTxPDUSet, pollInReTx, reTxPollSN, remainingGrant] = obj.retransmitSDUs(remainingGrant, remainingTBS);
            [txPDUSet, pollInTx, txPollSN, ~] = obj.transmitSDUs(remainingGrant, remainingTBS);
            rlcPDUSet = {rlcPDUSet(:); reTxPDUSet(:); txPDUSet(:)};
            rlcPDUSet = vertcat(rlcPDUSet{:});

            % To avoid buffer status calculation errors due to
            % overestimation of the required grant, reset the required
            % grant length when Tx and retransmission buffers are empty
            % along with no grant requirement for status PDU
            if (obj.NumTxBufferSDUs == 0) && (obj.NumReTxBufferSDUs == 0) && ...
                    (obj.GrantRequiredForStatusReport == 0)
                obj.RequiredGrantLength = 0;
            end
            % Send the updated RLC buffer status report to MAC layer
            obj.TxBufferStatusFcn(obj.getBufferStatus());

            % Set POLL_SN to highest SN among the sent AMD PDUs as per
            % Section 5.3.3.2 of 3GPP TS 38.322
            isPollIncluded = false;
            if pollInReTx
                isPollIncluded = true;
                obj.PollSN = reTxPollSN;
            end
            if pollInTx
                isPollIncluded = true;
                obj.PollSN = txPollSN;
            end
            % Restart the poll retransmit timer as per Section
            % 5.3.3.3 of 3GPP TS 38.322
            if isPollIncluded
                obj.PollRetransmitTimeLeft = obj.PollRetransmitTimer;
            end
        end

        function bufferStatusReport = getBufferStatus(obj)
            %getBufferStatus Return the current buffer status of the
            % associated logical channel
            %   BUFFERSTATUSREPORT = getBufferStatus(OBJ) returns the
            %   current buffer status of the associated logical channel.
            %
            %   BUFFERSTATUSREPORT is a handle object, which contains the
            %   following fields:
            %       RNTI                - Radio network temporary 
            %                             identifier
            %       LogicalChannelID    - Logical channel identifier
            %       BUFFERSTATUS        - Required grant for transmitting 
            %                             the stored RLC SDUs

            % Create a hNRRLCBufferStatus object that holds buffer status
            % of the associated logical channel
            bufferStatusReport = hNRRLCBufferStatus(obj.RNTI, ...
                obj.LogicalChannelID, obj.RequiredGrantLength);
        end

        function [sdu, sduLen] = receive(obj, packet)
            %receive Process the received PDU from the MAC layer
            %   [SDU, SDULEN] = receive(OBJ, PACKET) processes the received
            %   PACKET from the MAC layer.
            %
            %   SDU is an output column vector of octets in decimal
            %   format.
            %
            %   SDULEN is an integer scalar, represents the length of SDU
            %
            %   PACKET is a column vector of octets in decimal format.

            sdu = [];
            sduLen = 0;
            % Process data and control PDUs separately by distinguish them
            % with data/control bit in the header
            if bitand(packet(1), 128)
                [sdu, sduLen] = obj.processDataPDU(packet);
            else
                obj.processStatusPDU(packet);
            end
        end

        function updateTimer(obj)
            %updateTimer Decrement the configured timers by 1 ms

            % Check if the poll retransmit timer is running
            if obj.PollRetransmitTimeLeft > 0
                % Decrement the time left for poll retransmit timer trigger
                % by 1
                obj.PollRetransmitTimeLeft = obj.PollRetransmitTimeLeft - 1;
                % Check whether the poll retransmit timer is triggered
                if obj.PollRetransmitTimeLeft == 0
                    % Increment the count of reassembly timer expiration
                    % event
                    obj.StatTimerPollRetransmitTimedOut = obj.StatTimerPollRetransmitTimedOut + 1;
                    obj.pollRetransmitTimerExpiry();
                    obj.RetransmitPollFlag = true;
                end
            end

            % Check if the reassembly timer is running
            if obj.ReassemblyTimeLeft > 0
                % Decrement the time left for reassembly timer trigger
                % by 1
                obj.ReassemblyTimeLeft = obj.ReassemblyTimeLeft - 1;
                % Check whether the reassembly timer is triggered
                if obj.ReassemblyTimeLeft == 0
                    % Increment the count of reassembly timer expiration
                    % event
                    obj.StatTimerReassemblyTimedOut = obj.StatTimerReassemblyTimedOut + 1;
                    obj.reassemblyTimerExpiry();
                end
            end

            % Check if the status prohibit timer is running
            if obj.StatusProhibitTimeLeft > 0
                % Decrement the time left for status prohibit timer trigger
                % by 1
                obj.StatusProhibitTimeLeft = obj.StatusProhibitTimeLeft - 1;
                % Check whether the status prohibit timer is triggered
                if obj.StatusProhibitTimeLeft == 0
                    % Increment the count of status prohibit timer
                    % expiration event
                    obj.StatTimerStatusProhibitTimedOut = obj.StatTimerStatusProhibitTimedOut + 1;
                    obj.statusProhibitTimerExpiry();
                end
            end
        end
    end

    methods(Access = private)
        function rlcAMHeader = generateDataHeader(~, segmentationInfo, seqNumFieldLength, segmentSeqNum, segmentOffset)
            %generateDataHeader Generate header for RLC AMD PDU

            amdPDUHeader = zeros(5, 1);
            % Set D/C flag, segmentation information and sequence number
            % fields in the header. D/C flag is always 1 since it is a data
            % PDU
            if seqNumFieldLength == 12
                headerLen = 2; % In bytes
                amdPDUHeader(1:headerLen) = [128 + bitshift(segmentationInfo, 4) + bitshift(segmentSeqNum, -8); ...
                    bitand(segmentSeqNum, 255)];
            else
                headerLen = 3; % In bytes
                amdPDUHeader(1:headerLen) = [128 + bitshift(segmentationInfo, 4) + bitshift(segmentSeqNum, -16);
                    bitand(bitshift(segmentSeqNum, -8), 255);
                    bitand(segmentSeqNum, 255)];
            end
            % Append segment offset field depending on the value of
            % segmentation information
            if segmentationInfo >= 2
                amdPDUHeader(headerLen+1:headerLen+2) = [bitshift(segmentOffset, -8); bitand(segmentOffset, 255)];
                headerLen = headerLen + 2;
            end
            rlcAMHeader = amdPDUHeader(1:headerLen);
        end

        function decodeDataPDU(obj, rlcPDU, seqNumFieldLength)
            %decodeDataPDU Decode the RLC AMD PDU

            % Extract the poll bit and segmentation information from the
            % PDU header
            obj.DataPDUInfo.PollBit = bitand(bitshift(rlcPDU(1), -6), 1);
            obj.DataPDUInfo.SegmentationInfo = bitand(bitshift(rlcPDU(1), -4), 3);
            obj.DataPDUInfo.PDULength = numel(rlcPDU);
            % Extract SN
            if seqNumFieldLength == 12
                % Index to indicate the starting position of the data field
                % in the received PDU. In case of 12 bit sequence number
                % field length, it is 3
                idx = 3;
                first2bytes = bitor(bitshift(rlcPDU(1), 8), rlcPDU(2));
                obj.DataPDUInfo.SequenceNumber = bitand(first2bytes, 4095); % 4095 is a 12 bit mask
            else
                % Index to indicate the starting position of the data field
                % in the received PDU. In case of 18 bit sequence number
                % field length, it is 4
                idx  = 4;
                first3Bytes = bitor(bitshift(rlcPDU(1), 16), bitor(bitshift(rlcPDU(2),8), rlcPDU(3)));
                obj.DataPDUInfo.SequenceNumber = bitand(first3Bytes, 262143); % 262143 is a 18 bit mask
            end
            % Extract segment offset and payload from the PDU
            if obj.DataPDUInfo.SegmentationInfo == 2 || obj.DataPDUInfo.SegmentationInfo == 3
                obj.DataPDUInfo.SegmentOffset = bitor(bitshift(rlcPDU(idx), 8), rlcPDU(idx + 1));
                obj.DataPDUInfo.Data = rlcPDU(idx + 2:end);
            else
                obj.DataPDUInfo.SegmentOffset = 0;
                % Extract the data fields
                obj.DataPDUInfo.Data = rlcPDU(idx:end);
            end
        end

        function [rlcPDU, remainingGrant] = retransmitSegment(obj, sn, lostSegmentInfo, remainingGrant, remainingTBS)
            %retransmitSegment Retransmit the specified SDU segment

            % Determine its segmentation information
            segmentInfo = obj.determineSegmentInfo(lostSegmentInfo(1), lostSegmentInfo(2));
            sdu = obj.ReTxBuffer{obj.ReTxBufferFront + 1};
            segmentEnd = lostSegmentInfo(2);
            % Update segment offset end with the actual offset since
            % last segment's end offset is always 65535 irrespective of
            % the SDU size
            if lostSegmentInfo(2) == 65535
                lostSegmentInfo(2) = numel(sdu)-1;
            end
            % Construct the AMD PDU for the SDU segment
            pduHeader = obj.generateDataHeader(segmentInfo, obj.TxSeqNumFieldLength, sn, lostSegmentInfo(1));
            [rlcPDU, sduLen, remainingGrant, isSegmented] = obj.constructAMDPDU(sn, lostSegmentInfo(1), lostSegmentInfo(2), pduHeader, sdu, remainingGrant, remainingTBS);

            if isSegmented
                % Update the start offset of segment because of the
                % resegmentation
                soStartIndex = obj.ReTxBufferContext(obj.ReTxBufferFront + 1, 3:end) == lostSegmentInfo(1);
                obj.ReTxBufferContext(obj.ReTxBufferFront + 1, logical([0 0 soStartIndex])) = lostSegmentInfo(1) + sduLen;
                % Update the required grant length, including 8 byte MAC
                % and RLC headers overhead, because of the reduced segment
                % size
                remainingSDULen = lostSegmentInfo(2) - (lostSegmentInfo(1) + sduLen) + 1;
                obj.RequiredGrantLength = obj.RequiredGrantLength + remainingSDULen + 8;
            else
                % Remove the segment information from the retransmission
                % context
                soIndexes = obj.ReTxBufferContext(obj.ReTxBufferFront + 1, 3:end) == lostSegmentInfo(1) | ...
                    obj.ReTxBufferContext(obj.ReTxBufferFront + 1, 3:end) == segmentEnd;
                obj.ReTxBufferContext(obj.ReTxBufferFront + 1, logical([0 0 soIndexes])) = -1;
            end
            obj.StatReTxDataPDU = obj.StatReTxDataPDU + 1;
            obj.StatReTxDataBytes = obj.StatReTxDataBytes + numel(rlcPDU);
        end

        function [rlcPDU, sduLen, remainingGrant, isSegmented] = constructAMDPDU(obj, sn, soStart, soEnd, pduHeader, sdu, remainingGrant, remainingTBS)
            %constructAMDPDU Construct an AMD PDU that fits in the given
            % grant

            isSegmented = false;
            pduHeaderLength = numel(pduHeader);
            pduLength = pduHeaderLength + numel(sdu(soStart + 1: soEnd + 1));
            macHeaderLength = obj.getMACHeaderLength(pduLength);
            % Remove the considered grant size from the required grant
            % length
            obj.RequiredGrantLength = obj.RequiredGrantLength - (pduLength + macHeaderLength);

            % Check whether the complete/segmented AMD PDU needs to be
            % segmented/resegmented to fit within the notified grant size.
            % The below conditional also takes care of MAC LCP requirement
            % as such avoiding segmentation/resegmentation by using
            % remaining TBS
            if (pduLength + macHeaderLength) > (remainingTBS + remainingGrant)
                % Update the RLC header for segmented/resegmented SDU
                if soStart
                    % Create the RLC header for middle SDU segment since
                    % the SDU has been segmented earlier
                    updatedHeader = obj.generateDataHeader(3, obj.TxSeqNumFieldLength, sn, soStart);
                else
                    % Create the RLC header for first SDU segment since the
                    % SDU has not been segmented earlier
                    updatedHeader = obj.generateDataHeader(1, obj.TxSeqNumFieldLength, sn, soStart);
                end
                % Calculate the segmented SDU length that fit in the
                % current grant excluding the estimated MAC and RLC headers
                % overhead
                headersOverhead = numel(updatedHeader) + obj.getMACHeaderLength(remainingGrant-3);
                sduLen = remainingGrant - headersOverhead;
                % Create the segmented/resegmented AMD PDU
                rlcPDU = [updatedHeader; ...
                    sdu(soStart + 1 : soStart + sduLen)];
                isSegmented = true;
                remainingGrant = remainingGrant - (headersOverhead + sduLen);
            else
                % Create a complete/segmented RLC AMD PDU
                rlcPDU = [pduHeader; sdu(soStart + 1: soEnd + 1)];
                sduLen = soEnd - soStart + 1;
                remainingGrant = remainingGrant - (numel(rlcPDU) + macHeaderLength);
            end
        end

        function pollFlag = getPollStatus(obj, varargin)
            %getPollStatus Return the poll flag and reset the poll counters
            % upon the flag set
            %   POLLFLAG = getPollStatus(OBJ) checks all the poll trigger
            %   conditions except poll counters update and returns the poll
            %   flag. If the poll flag is set, it resets the poll counters.
            %
            %   POLLFLAG = getPollStatus(OBJ, SEGMENTLENGTH) checks all the
            %   poll trigger conditions. It increments the poll byte
            %   counter by SEGMENTLENGTH and poll PDU counter by 1 before
            %   the check of poll trigger. If the poll flag is set, it
            %   resets the poll counters.

            pollFlag = 0;
            if nargin == 2
                % Increment PDU without poll count by 1 and bytes without
                % poll count by every new byte data carried in the AMD PDU
                obj.PDUsWithoutPoll = obj.PDUsWithoutPoll + 1;
                obj.BytesWithoutPoll = obj.BytesWithoutPoll + varargin{1};
                % If any of the poll PDU counter or the poll byte counter
                % is enabled, check the PDUs sent without poll or the SDU
                % bytes sent without poll exceeds the specified threshold
                if ((obj.PollPDU ~= 0) && (obj.PDUsWithoutPoll >= obj.PollPDU)) || ...
                        ((obj.PollByte ~= 0) && (obj.BytesWithoutPoll >= (obj.PollByte * 1024)))
                    pollFlag = 1;
                end
            end
            % Send the poll request if either the Tx and retransmission
            % buffers are empty after the submission of current AMD PDU or
            % the occurence of Tx window stall due to the limited buffer
            % size
            if (obj.NumTxBufferSDUs == 0) && (obj.NumReTxBufferSDUs == 0) || ...
                    (obj.NumSDUsWaitingForACK == obj.MaxTxBufferSDUs)
                pollFlag = 1;
            elseif obj.getTxSNModulus(obj.TxSubmitted) == obj.getTxSNModulus(obj.TxNextAck + obj.AMTxWindowSize - 1) % Tx window stalling condition
                pollFlag = 1;
            end
            % Send the poll request if the poll retransmit timer has
            % expired
            if obj.RetransmitPollFlag
                pollFlag = 1;
                obj.RetransmitPollFlag = false;
            end
            % Upon poll flag set, reset PDUs and bytes without poll
            % counters
            if pollFlag
                obj.PDUsWithoutPoll = 0;
                obj.BytesWithoutPoll = 0;
            end
        end

        function pollRetransmitTimerExpiry(obj)
            %pollRetransmitTimerExpiry Perform the actions required after
            % the expiry of poll retransmit timer

            % Retransmit an SDU, which is awaiting for acknowledgement,
            % when one of the following conditions is met:
            %   - Empty Tx and retransmission buffers
            %   - Tx window stall due to the limited buffer size
            %   - Tx window stall due to no acknowledgement for the SNs of 
            %     size Tx window. This condition occurs when Tx buffer
            %     size is configured to be more than the Tx window size
            if ((obj.NumTxBufferSDUs == 0) && (obj.NumReTxBufferSDUs == 0)) || ... 
                    (obj.NumSDUsWaitingForACK == obj.MaxTxBufferSDUs) || ... 
                    (obj.getTxSNModulus(obj.TxSubmitted) == obj.getTxSNModulus(obj.TxNextAck + obj.AMTxWindowSize - 1))
                % Consider an SDU for retransmission that was submitted to
                % the MAC layer, since new SDU cannot be transmitted
                highestSNIdx = obj.WaitingForACKBufferContext(:, 1) == obj.TxSubmitted;
                % Enqueue the selected SDU into the retransmission buffer
                % and update the retransmission such that the complete SDU
                % was lost
                sduEnqueueIdx = mod(obj.ReTxBufferFront + obj.NumReTxBufferSDUs, obj.MaxTxBufferSDUs) + 1;
                obj.ReTxBuffer{sduEnqueueIdx} = obj.WaitingForACKBuffer{highestSNIdx};
                obj.ReTxBufferContext(sduEnqueueIdx) = obj.TxSubmitted; % SN of the SDU
                obj.ReTxBufferContext(sduEnqueueIdx, 2) = obj.WaitingForACKBufferContext(highestSNIdx, 2) + 1; % Increment of the retransmission count
                % Throw out an RLC link failure (RLF) error due to the
                % reach of maximum retransmission limit
                if obj.ReTxBufferContext(sduEnqueueIdx, 2) == obj.MaxRetransmissions
                    error('nr5g:hNRAMEntity:RLCLinkFailure', 'Maximum retransmission threshold is reached for LCID %d', obj.LogicalChannelID);
                end
                obj.ReTxBufferContext(sduEnqueueIdx, 3:4) = [0 65535]; % Lost segments information
                obj.WaitingForACKBufferContext(highestSNIdx, 1:2) = -1;
                obj.NumSDUsWaitingForACK = obj.NumSDUsWaitingForACK - 1;
                % Update the buffer status of the RLC entity to inform the
                % MAC about the grant requirement
                obj.RequiredGrantLength = obj.RequiredGrantLength + numel(obj.ReTxBuffer{sduEnqueueIdx}) + 8;
                obj.NumReTxBufferSDUs = obj.NumReTxBufferSDUs + 1;
            end
        end

        function si = determineSegmentInfo(~, soStart, soEnd)
            %determineSegmentInfo Return the segmentation information
            % depending on the soStart and soEnd values

            maxSegOffset = 65535;
            if(soStart > 0) && (soEnd < maxSegOffset)
                si = 3; % Segmentation field for the middle segment
            elseif (soStart == 0) && (soEnd == maxSegOffset)
                si = 0; % Segmentation field for the whole SDU
            elseif (soStart == 0) && (soEnd < maxSegOffset)
                si = 1; % Segmentation field for the first segment
            else
                si = 2; % Segmentation field for the last segment
            end
        end

        function inside = isInsideTransmittingWindow(obj, seqNum)
            %isInsideTransmittingWindow Check whether the given sequence
            % number is inside the transmitting window

            % For more details about Tx window, refer 3GPP TS 38.322
            % Section 7.1
            if (obj.getTxSNModulus(obj.TxNextAck) <= obj.getTxSNModulus(seqNum)) && ...
                    (obj.getTxSNModulus(seqNum) < obj.getTxSNModulus(obj.TxNextAck + obj.AMTxWindowSize))
                inside = true;
            else
                inside = false;
            end
        end

        function valueAfterModulus = getTxSNModulus(obj, seqNum)
            %getTxSNModulus Return the Tx modulus for the given sequence
            % number

            % For more details about Tx modulus, refer 3GPP TS 38.322
            % Section 7.1
            valueAfterModulus = mod(seqNum - obj.TxNextAck, obj.TotalTxSeqNum);
        end

        function macHeaderLength = getMACHeaderLength(~, pduLength)
            %getMACHeaderLength Return the MAC header length in bytes
            % for the given RLC PDU length

            macHeaderLength = 2;
            if pduLength > 255
                macHeaderLength = 3;
            end
        end

        function [sdu, sduLen] = processDataPDU(obj, dataPDU)
            %processDataPDU Process the received data PDU

            sdu = [];
            sduLen = 0;
            % Decode the data packet received from the MAC layer. Update
            % the statistics accordingly
            obj.decodeDataPDU(dataPDU, obj.RxSeqNumFieldLength);
            dataPDUInfo = obj.DataPDUInfo;
            obj.StatRxDataPDU = obj.StatRxDataPDU + 1;
            obj.StatRxDataBytes = obj.StatRxDataBytes + dataPDUInfo.PDULength;

            % Discard the received SDU if it falls outside of the Rx window
            % or it is a duplicate SDU which was completely received
            % earlier
            if ~obj.isInsideReceivingWindow(dataPDUInfo.SequenceNumber) || ...
                    obj.isCompleteSDURcvd(dataPDUInfo.SequenceNumber)
                numBytesDiscarded = numel(dataPDUInfo.Data);
                isReassembled = false;
            else
                if dataPDUInfo.SegmentationInfo == 0 % Reception of complete SDU
                    [numBytesDiscarded, isReassembled, sdu, sduLen] = obj.processCompleteSDU(dataPDUInfo);
                else % On the reception of a segmented SDU
                    [numBytesDiscarded, isReassembled, sdu, sduLen] = obj.processSegmentedSDU(dataPDUInfo);
                end
            end

            if numel(dataPDUInfo.Data) ~= numBytesDiscarded
                if ~dataPDUInfo.PollBit
                    % Update the RLC AM state variables based on the
                    % received PDU sequence number
                    obj.updateRxState(dataPDUInfo.SequenceNumber, isReassembled);
                    return;
                end
                % Trigger status PDU
                if (obj.getRxSNModulus(dataPDUInfo.SequenceNumber) < obj.getRxSNModulus(obj.RxHighestStatus)) || ...
                        (obj.getRxSNModulus(dataPDUInfo.SequenceNumber) >= obj.getRxSNModulus(obj.RxNext + obj.AMRxWindowSize))
                    obj.IsStatusPDUTriggered = true;
                    obj.IsStatusPDUDelayed = false;
                else
                    obj.IsStatusPDUDelayed = true;
                end
                obj.updateRxState(dataPDUInfo.SequenceNumber, isReassembled);
            else
                % Trigger the status PDU on discarding the received
                % byte segments as per Section 5.2.3.2.3 of 3GPP TS
                % 38.322
                obj.IsStatusPDUTriggered = true;
            end

            % Check if the received PDU contains the duplicate
            % bytes
            if numBytesDiscarded
                % Update the duplicate segment reception statistics
                obj.StatRxDataPDUDuplicate = obj.StatRxDataPDUDuplicate + 1;
                obj.StatRxDataBytesDuplicate = obj.StatRxDataBytesDuplicate + dataPDUInfo.PDULength;
            end

            % Check if the status prohibit when status PDU is triggered
            if obj.IsStatusPDUTriggered && (obj.StatusProhibitTimeLeft ~= 0)
                obj.IsStatusPDUTriggered = false;
                obj.IsStatusPDUTriggeredOverSPT = true;
            else
                % Update the buffer status report
                obj.addStatusReportInReqGrant();
            end
        end

        function processStatusPDU(obj, statusPDU)
            %processStatusPDU Process the received status PDU and update
            % the retransmission context

            % Decode the control packet received from MAC and update the
            % statistics accordingly
            [nackSNInfo, soInfo, ackSN] = obj.decodeStatusPDU(statusPDU, obj.RxSeqNumFieldLength);
            obj.StatRxControlPDU = obj.StatRxControlPDU + 1;
            obj.StatRxControlBytes = obj.StatRxControlBytes + numel(statusPDU);
            % Check whether the received ACK SN is valid and falls inside
            % the Tx window
            if (ackSN >= 0) && (obj.getTxSNModulus(ackSN) < obj.AMTxWindowSize)
                % Update the retransmission context based on the received
                % STATUS PDU
                obj.updateRetransmissionContext(nackSNInfo, soInfo, ackSN);
            end
        end

        function updateRxState(obj, currPktSeqNum, isReassembled)
            %updateRxState Update the RLC AM receiver context

            % Update the upper end of the receiving window
            if obj.getRxSNModulus(currPktSeqNum) >= obj.getRxSNModulus(obj.RxNextHighest)
                obj.RxNextHighest = mod(currPktSeqNum + 1, obj.TotalRxSeqNum);
            end
            % Check whether all bytes of the RLC SDU with SN = x are
            % received
            if isReassembled
                if (currPktSeqNum == obj.RxHighestStatus) || (currPktSeqNum == obj.RxNext)
                    minSN = mod(currPktSeqNum + 1, obj.TotalRxSeqNum);
                    % Update RxNextHighest and RxHighestStatus sequence
                    % numbers by finding a new sequence number which is not
                    % yet reassembled and delivered to higher layer
                    receptionIndex = (obj.RcvdSNList(:, 1) <= minSN) & ...
                        (obj.RcvdSNList(:, 2) >= minSN);
                    if any(receptionIndex, 'all')
                        minSN = obj.RcvdSNList(logical(sum(receptionIndex, 2)), 2) + 1;
                    end
                    if currPktSeqNum == obj.RxHighestStatus
                        obj.RxHighestStatus = minSN;
                    end
                    if currPktSeqNum == obj.RxNext
                        obj.RxNext = minSN;
                        % Update the reception status array
                        obj.RcvdSNList(obj.getRxSNModulus(obj.RcvdSNList) > obj.AMRxWindowSize) = -1;
                    end
                end
            end
            obj.updateReassemblyTimerContext();
        end

        function updateRetransmissionContext(obj, nackSNInfo, soInfo, ackSN)
            %updateRetransmissionContext Update the retransmission context

            txNextAckModulus = obj.getTxSNModulus(obj.TxNextAck);
            txSubmittedModulus = obj.getTxSNModulus(obj.TxSubmitted);
            snInfoIndices = nackSNInfo >= 0;
            nackSNInfoList = nackSNInfo(snInfoIndices);
            soInfoList = soInfo(snInfoIndices, :);
            headersOverhead = 8; % Maximum size of the MAC and RLC overhead
            nackSNIdx = 0;

            % Iterate through each SN that was transmitted earlier and
            % update the retransmission context based on the status report
            for snRef = txNextAckModulus:obj.getTxSNModulus(ackSN)-1
                sn = mod(obj.TxNextAck + snRef, obj.TotalTxSeqNum);
                snModulus = obj.getTxSNModulus(sn);
                if all(sn ~= nackSNInfoList)
                    % Remove the SDU context from waiting-for-ack buffer or
                    % retransmission buffer since it was successfully
                    % transmitted
                    isSNWaitingForAck = obj.getTxSNModulus(obj.WaitingForACKBufferContext(:, 1)) == obj.getTxSNModulus(sn);
                    obj.WaitingForACKBufferContext(isSNWaitingForAck, :) = -1;
                    if any(isSNWaitingForAck)
                        obj.NumSDUsWaitingForACK = obj.NumSDUsWaitingForACK - 1;
                    end
                    isInReTxBuffer = obj.getTxSNModulus(obj.ReTxBufferContext(:, 1)) == obj.getTxSNModulus(sn);
                    obj.ReTxBufferContext(isInReTxBuffer, :) = -1;
                    if any(isInReTxBuffer)
                        obj.NumReTxBufferSDUs = obj.NumReTxBufferSDUs - 1;
                    end
                    continue;
                end
                nackSNIdx = nackSNIdx + 1;
                % Do not retransmit the SN if it falls outside of the
                % retransmission window
                if ~obj.isInsideTransmittingWindow(sn) || ...
                        (snModulus > txSubmittedModulus)
                    continue;
                end
                % If the SN has any previous pending retransmission
                % context, remove it and consider the latest retransmission
                % context
                reTxNackSNIdxList = obj.ReTxBufferContext(:, 1) == sn;
                if any(reTxNackSNIdxList)
                    % Remove the grant required, including MAC and RLC
                    % headers, for the obsolete segments
                    currLostSegments = obj.ReTxBufferContext(reTxNackSNIdxList, 3:end);
                    oldReqGrantLength = sum(headersOverhead + ...
                        (currLostSegments(2:2:end) - currLostSegments(1:2:end)));
                    obj.RequiredGrantLength = obj.RequiredGrantLength - oldReqGrantLength;
                    % Add the grant required, including MAC and RLC
                    % headers, for the latest segments
                    newReqGrantLength = sum(headersOverhead + ...
                    (soInfoList(nackSNIdx, 2:2:end) - soInfoList(nackSNIdx, 1:2:end)));
                    obj.RequiredGrantLength = obj.RequiredGrantLength + newReqGrantLength;
                    % Update the segments information in the retransmission
                    % context
                    obj.ReTxBufferContext(reTxNackSNIdxList, 3:end) = soInfoList(nackSNIdx, :);
                end

                % If the SN has no pending retransmission context and it is
                % waiting for acknowledgment, add its information to the
                % retransmission context
                nackSNIdxList = obj.WaitingForACKBufferContext(:, 1) == sn;
                if any(nackSNIdxList)
                    currentReTxCount = obj.WaitingForACKBufferContext(nackSNIdxList, 2) + 1;
                    % Throw out an RLC link failure (RLF) error due to the
                    % reach of maximum retransmission limit
                    if currentReTxCount == obj.MaxRetransmissions
                        error('nr5g:hNRAMEntity:RLCLinkFailure', 'Maximum retransmission threshold is reached for LCID %d', obj.LogicalChannelID);
                    end
                    % Enqueue the SDU into retransmission buffer which has
                    % received the NACK and update its retransmission
                    % context
                    sduEnqueueIdx = mod(obj.ReTxBufferFront + obj.NumReTxBufferSDUs, obj.MaxTxBufferSDUs) + 1;
                    obj.ReTxBuffer{sduEnqueueIdx} = obj.WaitingForACKBuffer{nackSNIdxList};
                    obj.ReTxBufferContext(sduEnqueueIdx, :) = [sn ...
                        currentReTxCount soInfoList(nackSNIdx, :)];
                    obj.WaitingForACKBufferContext(nackSNIdxList, 1:2) = -1;
                    obj.NumReTxBufferSDUs = obj.NumReTxBufferSDUs + 1;
                    obj.NumSDUsWaitingForACK = obj.NumSDUsWaitingForACK - 1;
                    nullSegments = numel(soInfoList(soInfoList < 0))/2; % Not the actual segments
                    % Update the buffer status of the RLC entity
                    newGrantLength = headersOverhead + ...
                        soInfoList(nackSNIdx, 2:2:end) - soInfoList(nackSNIdx, 1:2:end);
                    obj.RequiredGrantLength = obj.RequiredGrantLength + sum(newGrantLength) - ...
                        (nullSegments * headersOverhead);
                end
            end

            % Check if POLL_SN received any positive or negative
            % acknowledgment
            if any(nackSNInfoList == obj.PollSN) || (obj.getTxSNModulus(obj.PollSN) < obj.getTxSNModulus(ackSN))
                % Stop and reset the t-pollRetransmit timer as per Section
                % 5.3.3.3 of 3GPP TS 38.322
                if obj.PollRetransmitTimeLeft ~= 0
                    obj.PollRetransmitTimeLeft = 0;
                end
            end

            % When receiving a positive acknowledgment for an RLC SDU with
            % SN = x, the transmitting side of an AM RLC entity shall:
            %  - send an indication to the upper layers of successful
            %  delivery of the RLC SDU; - set TX_Next_Ack equal to the SN
            %  of the RLC SDU with the smallest SN, whose SN falls within
            %  the range TX_Next_Ack <= SN <= TX_Next and for which a
            %  positive acknowledgment has not been received yet.
            minNACKSNReceived = ackSN;
            if ~isempty(nackSNInfoList)
                minNACKSNReceived = nackSNInfoList(1);
            end
            obj.TxNextAck = mod(obj.TxNextAck + ...
                (obj.getTxSNModulus(minNACKSNReceived) - txNextAckModulus), obj.TotalTxSeqNum);
        end

        function inside = isInsideReceivingWindow(obj, seqNum)
            %isInsideReceivingWindow Check whether the given sequence
            % number is inside the receiving window

            if (obj.getRxSNModulus(obj.RxNext) <= obj.getRxSNModulus(seqNum)) && (obj.getRxSNModulus(seqNum) < obj.getRxSNModulus(obj.RxNext + obj.AMRxWindowSize))
                inside = true;
            else
                inside = false;
            end
        end

        function valueAfterModulus = getRxSNModulus(obj, value)
            %getRxSNModulus Get the modulus value for the given
            % sequence number

            valueAfterModulus = mod(value - obj.RxNext, obj.TotalRxSeqNum);
        end

        function controlPDU = constructStatusPDU(obj, remainingGrant)
            %constructStatusPDU Construct the status PDU

            bytesFilled = 0;
            isPrevSNLost = false;
            range = 0;
            statusPDU = zeros(obj.GrantRequiredForStatusReport, 1);
            statusPDULen = 3; % minimum status PDU length
            grantLeft = min(remainingGrant, obj.GrantRequiredForStatusReport) - statusPDULen; % Set aside 3 bytes for status PDU header and ACK SN
            lastSNOffset = statusPDULen;
            sn = obj.RxNext;
            rxHighestStatus = obj.getRxSNModulus(obj.RxHighestStatus);

            % Include each missing SN information in the status PDU by
            % iterating through each SN between the lower end of the
            % receiving window and the highest status
            for snIdx = 0:rxHighestStatus-1
                sn = snIdx + obj.RxNext;
                if obj.isCompleteSDURcvd(sn) % On a complete reception of SDU
                    % Do not include the SN which is received completely
                    isPrevSNLost = false;
                    sn = mod(sn + 1, obj.TotalRxSeqNum);
                    continue;
                end
                snBufIdx = obj.getSDUReassemblyBufIdx(sn);
                if snBufIdx > -1 % On a partial reception of SDU
                    % Get the lost segments information and its
                    % corresponding status PDU information
                    segmentsLost = obj.RxBuffer{snBufIdx}.getLostSegmentsInfo();
                    [subStatusPDU, subStatusPDULen, e1UpdateOffset] = obj.addSegmentsInfoInStatusPDU(sn, segmentsLost');
                    isPrevSNLost = any(segmentsLost == 65535);
                else % On a complete lost of SDU
                    segmentsLost = [];
                    if isPrevSNLost
                        % Update the range field if SNs are lost
                        % consecutively. The loss of the last segment
                        % of the previous SN and complete loss of the
                        % current SN is also considered as consecutive
                        % loss
                        sn = mod(sn + 1, obj.TotalRxSeqNum);
                        range = range + 1;
                        continue;
                    end
                    isPrevSNLost = true;
                    [subStatusPDU, subStatusPDULen, e1UpdateOffset] = obj.addSegmentsInfoInStatusPDU(sn, segmentsLost');
                end

                % Update the E3 field in the status PDU and add
                % range to the status PDU
                if range && (~isempty(segmentsLost) || (snIdx == rxHighestStatus-1))
                    if obj.RxSeqNumFieldLength == 12
                        statusPDU(lastSNOffset) = bitor(statusPDU(lastSNOffset), 2);
                    else
                        statusPDU(lastSNOffset) = bitor(statusPDU(lastSNOffset), 8);
                    end
                    statusPDU(statusPDULen + 1) = range;
                    grantLeft = grantLeft - 1;
                    bytesFilled = bytesFilled + 1;
                    statusPDULen = statusPDULen + 1;
                    range = 0;
                end
                % Don't add NACK SN information to the status PDU if the
                % grant is not sufficient. This is to avoid any
                % misinterpretation about NACK SN to ACK SN by the peer RLC
                % entity
                if (subStatusPDULen > grantLeft)
                    break;
                end
                % Update the E1 field in the status PDU to denote that
                % there is a lost SN information after this
                if ~isempty(segmentsLost)
                    if (obj.RxSeqNumFieldLength == 12) && (lastSNOffset ~= 3)
                        statusPDU(lastSNOffset) = bitor(statusPDU(lastSNOffset), 8);
                    elseif (obj.RxSeqNumFieldLength == 18) && (lastSNOffset ~= 3)
                        statusPDU(lastSNOffset) = bitor(statusPDU(lastSNOffset), 32);
                    end
                    statusPDU(statusPDULen + 1: statusPDULen + subStatusPDULen)= subStatusPDU(1:subStatusPDULen);
                    grantLeft = grantLeft - subStatusPDULen;
                    lastSNOffset = lastSNOffset + bytesFilled + e1UpdateOffset;
                    bytesFilled = subStatusPDULen - e1UpdateOffset;
                    statusPDULen = statusPDULen + subStatusPDULen;
                end
                sn = mod(sn + 1, obj.TotalRxSeqNum);
            end

            % Add ACK SN information into the status PDU along with D/C and
            % CPT fields
            statusPDU(1:3) = obj.getACKSNBytes(statusPDULen-3, sn);
            controlPDU = statusPDU(1:statusPDULen);
        end

        function [nackInfo, soInfo, ackSN] = decodeStatusPDU(obj, rlcPDU, seqNumFieldLength)
            %decodeStatusPDU decode the received status PDU

            % Estimate the number of SNs that can be present in the
            % received status PDU. The max number of NACK SNs per status
            % PDU equals ceil((status PDU length - ACK SN size)/minimum
            % nack SN size)
            pduLen = numel(rlcPDU);
            if obj.TxSeqNumFieldLength == 12
                numSNs = ceil((pduLen - 3)/2);
            else
                numSNs = ceil((pduLen - 3)/3);
            end
            % Define an array to store lost segment start and end fields
            soInfo = -1 * ones(numSNs, obj.MaxReassemblySDU * 2);
            % Stores the sequence numbers of the PDUs with lost segments
            nackInfo = -1 * ones(numSNs, 1);
            ackSN = -1;
            numSNs = 0;
            numSOsPerSN = 0;

            % Get the Control PDU Type
            cpt = bitand(bitshift(rlcPDU(1), -4), 7);
            if cpt ~= 0
                % On the reception of corrupted status PDU, don't do any
                % further processing
                return;
            end
            % Extract ACK SN and extension bit-1 values
            if seqNumFieldLength == 12
                ackSN = bitor(bitshift(bitand(rlcPDU(1), 15), 8), rlcPDU(2));
                e1 = bitshift(rlcPDU(3), -7);
            else
                ackSN = bitor(bitor(bitshift(bitand(rlcPDU(1), 15), 14), bitshift(rlcPDU(2), 6)), bitshift(rlcPDU(3), -2));
                e1 = bitand(bitshift(rlcPDU(3), -1), 1);
            end

            octetIndex = 4;
            lastSN = -1;
            % Check whether extension bit-1 is set or the entire PDU has
            % been parsed
            while e1 && (octetIndex <= pduLen)
                % Extract NACK_SN, extension bit-1, extension bit-2, and
                % extension bit-3
                if seqNumFieldLength == 12
                    nacksn = bitor(bitshift(rlcPDU(octetIndex), 4), bitshift(rlcPDU(octetIndex + 1), -4));
                    e2 = bitshift(bitand(rlcPDU(octetIndex + 1), 4), -2);
                    e3 = bitshift(bitand(rlcPDU(octetIndex + 1), 2), -1);
                    e1 = bitshift(bitand(rlcPDU(octetIndex + 1), 8), -3);
                    octetIndex = octetIndex + 2;
                else
                    nacksn = bitor(bitor(bitshift(rlcPDU(octetIndex), 10), bitshift(rlcPDU(octetIndex + 1), 2)), bitshift(rlcPDU(octetIndex + 2), -6));
                    e2 = bitshift(bitand(rlcPDU(octetIndex + 2), 16), -4);
                    e3 = bitshift(bitand(rlcPDU(octetIndex + 2), 8), -3);
                    e1 = bitshift(bitand(rlcPDU(octetIndex + 2), 32), -5);
                    octetIndex = octetIndex + 3;
                end
                % If the new SN is not same as the last one, add lost
                % segment information of the new SN in a separate row
                if nacksn ~= lastSN
                    numSNs = numSNs + 1;
                    nackInfo(numSNs) = nacksn;
                    numSOsPerSN = 0;
                    lastSN = nacksn;
                end
                % Extract the segment start and end for the NACK SN
                if e2
                    soStart = bitor(bitshift(rlcPDU(octetIndex), 8), rlcPDU(octetIndex + 1));
                    soEnd = bitor(bitshift(rlcPDU(octetIndex + 2), 8), rlcPDU(octetIndex + 3));
                    soInfo(numSNs, numSOsPerSN + 1:numSOsPerSN + 2) = [soStart soEnd];
                    numSOsPerSN = numSOsPerSN + 2;
                    octetIndex = octetIndex + 4;
                else
                    soInfo(numSNs, numSOsPerSN + 1:numSOsPerSN + 2) = [0 65535];
                end
                % Extract NACK SN range field
                if e3
                    nackRange = rlcPDU(octetIndex);
                    for sn = 1:nackRange
                        % Set the number of segment offsets to 0 for every
                        % new NACK SN
                        numSOsPerSN = 0;
                        nackInfo(numSNs + 1) = nacksn + sn;
                        numSNs = numSNs + 1;
                        soInfo(numSNs, numSOsPerSN + 1:numSOsPerSN + 2)= [0 65535];
                        numSOsPerSN = numSOsPerSN + 2;
                    end
                    octetIndex = octetIndex + 1;
                end
            end
        end

        function reassemblyTimerExpiry(obj)
            %reassemblyTimerExpiry Perform the actions required after
            % the expiry of reassembly timer

            % Update the Rx highest status SN to the SN >= the reassembly
            % timer triggered SN for which all bytes not have been received
            minSN = obj.RxNextStatusTrigger;
            receptionIndex = (obj.RcvdSNList(:, 1) <= obj.RxNextStatusTrigger) & ...
                        (obj.RcvdSNList(:, 2) >= obj.RxNextStatusTrigger);
            if any(receptionIndex, 'all')
                minSN = obj.RcvdSNList(logical(sum(receptionIndex, 2)), 2) + 1;
            end
            obj.RxHighestStatus = minSN;

            rhsBufIdx = obj.getSDUReassemblyBufIdx(obj.RxHighestStatus);
            rhsModulus = obj.getRxSNModulus(mod(obj.RxHighestStatus + 1, obj.TotalRxSeqNum));
            isRNHEqualsRHS = obj.getRxSNModulus(obj.RxNextHighest) == rhsModulus;
            % Start the reassembly timer again if the conditions mentioned
            % in 3GPP TS 38.322 Section 5.2.3.2.4 are met
            if (obj.getRxSNModulus(obj.RxNextHighest) > rhsModulus) || ...
                    (isRNHEqualsRHS && (rhsBufIdx ~= -1) && ...
                    obj.RxBuffer{rhsBufIdx}.anyLostSegment())
                % Start the reassembly timer
                obj.ReassemblyTimeLeft = obj.ReassemblyTimer;
                obj.RxNextStatusTrigger = obj.getRxSNModulus(obj.RxNextHighest);
            end
            % Trigger the status report
            obj.IsStatusPDUTriggered = true;
            obj.addStatusReportInReqGrant();
        end

        function statusProhibitTimerExpiry(obj)
            %statusProhibitTimerExpiry Perform the actions required after
            % the expiry of status prohibit timer

            % Trigger the status report requested while status prohibit
            % timer is running
            if obj.IsStatusPDUTriggeredOverSPT
                obj.IsStatusPDUTriggered = true;
                obj.addStatusReportInReqGrant();
            end
            obj.StatusProhibitTimeLeft = 0;
        end

        function addStatusReportInReqGrant(obj)
            %addStatusReportInReqGrant Update the buffer status by the
            % grant required for sending status report

            grantForNACKSNSegment = 8; % Maximum grant required for sending one NACK SN in the status PDU
            grantSize = 3 + obj.getRxSNModulus(obj.RxHighestStatus) * grantForNACKSNSegment; % 3 for status PDU header and ACK field size
            obj.RequiredGrantLength = obj.RequiredGrantLength + grantSize;
            obj.GrantRequiredForStatusReport = grantSize;
            % Send the updated RLC buffer status report to MAC layer
            obj.TxBufferStatusFcn(obj.getBufferStatus());
        end

        function snBufIdx = assignReassemblyBufIdx(obj, sn)
            %assignReassemblyBufIdx Find a place to store the specified
            % SN's SDU in the reassembly buffer

            % Find out an empty RLC reassembly buffer for segmented SDU
            snBufIdx = obj.getSDUReassemblyBufIdx(sn);
            if snBufIdx ~= -1
                % Return if SDU has been allotted a buffer for reassembly
                return;
            end
            % Find an empty buffer to store the SDU
            for bufIdx = 1:obj.MaxReassemblySDU
                if obj.ReassemblySNMap(bufIdx) == -1
                    snBufIdx = bufIdx;
                    obj.ReassemblySNMap(snBufIdx) = sn;
                    break;
                end
            end
        end

        function snBufIdx = getSDUReassemblyBufIdx(obj, sn)
            %getSDUReassemblyIdx Return the reassembly buffer index in
            % which SDU is stored

            snBufIdx = -1;
            for bufIdx = 1:obj.MaxReassemblySDU
                if obj.ReassemblySNMap(bufIdx) == sn
                    snBufIdx = bufIdx;
                    break;
                end
            end
        end

        function ackSN = getACKSNBytes(obj, hasNACKSNs, sn)
            %getACKSNBytes Return status PDU header and ACK SN information

            % Generate ACK SN information for the status PDU along with D/C
            % and CPT fields
            if obj.RxSeqNumFieldLength == 12
                if hasNACKSNs
                    ackSN = [bitshift(sn, -8); bitand(sn, 255); 128];
                else
                    ackSN = [bitshift(sn, -8); bitand(sn, 255); 0];
                end
            else
                if hasNACKSNs
                    ackSN = [bitshift(sn, -14); ...
                        bitand(bitshift(sn, -6), 255); ...
                        bitor(bitshift(bitand(sn, 63), 2), 2)];
                else
                    ackSN = [bitshift(sn, -14); ...
                        bitand(bitshift(sn, -6), 255); ...
                        bitshift(bitand(sn, 63), 2)];
                end
            end
        end

        function [numBytesDiscarded, isReassembled, sdu, sduLen] = processCompleteSDU(obj, pduInfo)
            % processCompleteSDU Process the received complete SDU

            sdu = [];
            sduLen = 0;
            numBytesDiscarded = 0;
            isReassembled = false;
            receivedSDULen = numel(pduInfo.Data);
            % Check if it is already received
            if any(obj.getRxSNModulus(obj.RcvdSNList) == ...
                    obj.getRxSNModulus(pduInfo.SequenceNumber), 'all')
                % Consider all the received SDU bytes are duplicate
                numBytesDiscarded = receivedSDULen;
            else
                % Update the reception status on receiving a new complete
                % SDU. There is no need to update this on the reception of
                % complete SDU for lower edge SN since it moves forward
                % after the complete reception
                if obj.RxNext ~= pduInfo.SequenceNumber
                    obj.updateRxGaps(pduInfo.SequenceNumber);
                end
                sdu(1:receivedSDULen) = pduInfo.Data;
                sduLen = receivedSDULen;
                isReassembled = true;
            end
        end

        function [numBytesDiscarded, isReassembled, sdu, sduLen] = processSegmentedSDU(obj, pduInfo)
            %processSegmentedSDU Process the received segmented SDU

            sdu = [];
            sduLen = 0;
            numBytesDiscarded = 0;
            isReassembled = 0;
            % Find out the index in the reassembly buffer
            snBufIdx = obj.assignReassemblyBufIdx(pduInfo.SequenceNumber);
            if snBufIdx == -1
                obj.StatRxDataPDUDropped = obj.StatRxDataPDUDropped + 1;
                obj.StatRxDataBytesDropped = obj.StatRxDataBytesDropped + pduInfo.PDULength;
                return;
            end
            % Check whether the received segment is last segment
            isLastSegment = false;
            if pduInfo.SegmentationInfo == 2
                isLastSegment = true;
            end
            % Perform the duplicate detection and add the new segment
            % bytes to the reassembly buffer
            [numBytesDiscarded, isReassembled] = obj.RxBuffer{snBufIdx}.reassembleSegment(pduInfo.Data, pduInfo.PDULength, pduInfo.SegmentOffset, isLastSegment);
            % On the reception of all byte segments, reassemble the
            % segments and deliver it to higher layer without any further
            % delay
            if isReassembled == 1
                % Update the reception status on receiving a new complete
                % SDU. There is no need to update this on the reception of
                % complete SDU for lower edge SN since it moves forward
                % after the complete reception
                if obj.RxNext ~= pduInfo.SequenceNumber
                    obj.updateRxGaps(pduInfo.SequenceNumber);
                end
                [sdu, sduLen] = obj.RxBuffer{snBufIdx}.getReassembledSDU();
                obj.ReassemblySNMap(obj.ReassemblySNMap == pduInfo.SequenceNumber) = -1;
            end
        end

        function updateReassemblyTimerContext(obj)
            %updateReassemblyTimerContext Update the reassembly timer state
            % and Rx state variables

            rnBufIdx = obj.getSDUReassemblyBufIdx(obj.RxNext);
            rnModulus = obj.getRxSNModulus(mod(obj.RxNext + 1, obj.TotalRxSeqNum));
            if obj.ReassemblyTimeLeft ~= 0 % Reassembly timer is in running
                if obj.RxNextStatusTrigger == obj.RxNext
                    % Stop the reassembly timer if there is no gaps in
                    % reception till the SN which caused the start of
                    % reassembly timer
                    obj.ReassemblyTimeLeft = 0;
                elseif (obj.getRxSNModulus(obj.RxNextStatusTrigger) == rnModulus) && ((rnBufIdx ~= -1) && ~obj.RxBuffer{rnBufIdx}.anyLostSegment())
                    % Stop the reassembly timer if there is no gaps in
                    % reception till the earliest SN that requires
                    % reassembly. This applies only when
                    % RxNextStatusTrigger is equal to RxNext + 1
                    obj.ReassemblyTimeLeft = 0;
                elseif (~obj.isInsideReceivingWindow(obj.RxNextStatusTrigger) && (obj.RxNextStatusTrigger ~= (obj.RxNext + obj.AMRxWindowSize)))
                    % Stop the reassembly if RxNextStatusTrigger falls
                    % outside of the Rx window
                    obj.ReassemblyTimeLeft = 0;
                end
            end

            if obj.ReassemblyTimeLeft == 0 % Reassembly timer is not running
                rnhModulus = obj.getRxSNModulus(obj.RxNextHighest);
                % Start the reassembly timer if any of the following
                % conditions is met:
                %   - At least one missing SN between lower and upper ends
                %   of the receiving window
                %   - At least one missing segment between lower and upper
                %   ends of the receiving window when upper end = lower
                %   end + 1
                if (rnhModulus > rnModulus) || ...
                        ((rnhModulus == rnModulus) && (rnBufIdx ~= -1) && obj.RxBuffer{rnBufIdx}.anyLostSegment())
                    obj.ReassemblyTimeLeft = obj.ReassemblyTimer;
                    obj.RxNextStatusTrigger = obj.RxNextHighest;
                end
            end
        end

        function [rlcPDUSet, isPollIncluded, sn, remainingGrant] = transmitSDUs(obj, bytesGranted, remainingTBSSize)
            %transmitSDU Generate PDUs for SDUs upon being notified of
            % transmission opportunity

            rlcPDUSet = {};
            isPollIncluded = false;
            remainingGrant = bytesGranted;
            sn = -1;

            % Iterate through each SDU in the Tx buffer
            for sduIdx = 1:obj.NumTxBufferSDUs
                % Check the Tx window stalling arises due to the Tx buffer
                % size limitation
                if obj.NumSDUsWaitingForACK >= obj.MaxTxBufferSDUs
                    break;
                end
                % Check whether the minimum grant length condition
                % is satisfied as per Section 5.4.3.1.3 of 3GPP TS
                % 38.321
                if remainingGrant < obj.MinRequiredGrant
                    break;
                end
                sn = mod(obj.TxSubmitted + 1, obj.TotalTxSeqNum);
                % Do not transmit any SDU which has a SN that falls outside
                % of the transmitting window
                if ~((obj.getTxSNModulus(obj.TxNextAck) <= obj.getTxSNModulus(sn)) && ...
                        (obj.getTxSNModulus(sn) < obj.getTxSNModulus(obj.TxNextAck + obj.AMTxWindowSize)))
                    continue;
                end

                sdu = obj.TxBuffer{obj.TxBufferFront + 1};
                soStart = obj.SegmentOffset;
                soEnd = numel(obj.TxBuffer{obj.TxBufferFront + 1}) - 1;
                pduHeader = obj.TxHeaderBuffer{obj.TxBufferFront + 1};
                % Generate an AMD PDU that fits in the given grant
                [rlcPDU, sduLen, remainingGrant, isSegmented] = obj.constructAMDPDU(sn, soStart, soEnd, pduHeader, sdu, remainingGrant, remainingTBSSize);

                if isSegmented
                    % Update the segment start offset for the segmented SDU
                    obj.SegmentOffset = obj.SegmentOffset + sduLen;
                    % Update the header for the remaining SDU. This
                    % helps in reducing the preprocessing latency
                    % for the upcoming transmission opportunities
                    obj.TxHeaderBuffer{obj.TxBufferFront + 1} = obj.generateDataHeader(2, ...
                        obj.TxSeqNumFieldLength, sn, obj.SegmentOffset);
                    % Update the required grant size for this RLC entity
                    % Get the remaining RLC PDU length
                    newPDULength = numel(obj.TxHeaderBuffer{obj.TxBufferFront + 1}) + ...
                        (numel(obj.TxBuffer{obj.TxBufferFront + 1}) - obj.SegmentOffset);
                    newMACHeaderLength = obj.getMACHeaderLength(newPDULength);
                    obj.RequiredGrantLength = obj.RequiredGrantLength + newPDULength + newMACHeaderLength;
                else
                    obj.SegmentOffset = 0;
                    obj.TxSubmitted = sn;
                    obj.TxBufferFront = mod(obj.TxBufferFront + 1, obj.MaxTxBufferSDUs);
                    obj.NumTxBufferSDUs = obj.NumTxBufferSDUs - 1;
                    % After the complete transmission, keep the SDU in a
                    % buffer where it can wait for the acknowledgment
                    obj.NumSDUsWaitingForACK = obj.NumSDUsWaitingForACK + 1;
                    emptyTxedBufIdx = find(obj.WaitingForACKBufferContext(:, 1) == -1, 1);
                    obj.WaitingForACKBuffer{emptyTxedBufIdx} = sdu;
                    obj.WaitingForACKBufferContext(emptyTxedBufIdx, :) = [sn, -1];
                end
                obj.StatTxDataPDU = obj.StatTxDataPDU + 1;
                obj.StatTxDataBytes = obj.StatTxDataBytes + numel(rlcPDU);
                % Update the poll bit in the PDU header if any of the
                % status report triggering condition is met
                pollBit = obj.getPollStatus(sduLen);
                if pollBit
                    rlcPDU(1) = bitor(rlcPDU(1), bitshift(pollBit, 6));
                    isPollIncluded = true;
                end
                rlcPDUSet{end+1} = rlcPDU;
            end
        end

        function [rlcPDUSet, isPollIncluded, sn, remainingGrant] = retransmitSDUs(obj, bytesGranted, remainingTBSSize)
            %retransmitSDU Generate PDUs for retransmitting SDUs upon
            % notification of transmission opportunity

            rlcPDUSet = {};
            isPollIncluded = false;
            remainingGrant = bytesGranted;
            sn = -1;

            % Iterate through the SDUs in the retransmission buffer
            for sduIdx = 1:obj.NumReTxBufferSDUs
                sn = obj.ReTxBufferContext(obj.ReTxBufferFront + 1);
                segmentsInfo = obj.ReTxBufferContext(obj.ReTxBufferFront + 1, 3:end);
                lostSegments = segmentsInfo(segmentsInfo >= 0);
                % Iterate through the segments in retransmission for the
                % SDU
                for j = 1:2:numel(lostSegments)
                    % Check whether the minimum grant length condition is
                    % satisfied as per Section 5.4.3.1.3 of 3GPP TS 38.321
                    if remainingGrant < obj.MinRequiredGrant
                        break;
                    end
                    [rlcPDU, remainingGrant] = obj.retransmitSegment(sn, lostSegments(j:j+1), remainingGrant, remainingTBSSize);
                    segmentsLeft = obj.ReTxBufferContext(obj.ReTxBufferFront + 1, 3:end);
                    if ~numel(segmentsLeft(segmentsLeft >= 0))
                        % After completing the retransmission of all the SDU
                        % segments, keep the SDU in a buffer where it can wait
                        % for the acknowledgment
                        obj.NumSDUsWaitingForACK = obj.NumSDUsWaitingForACK + 1;
                        emptyTxedBufIdx = find(obj.WaitingForACKBufferContext(:, 1) == -1, 1);
                        obj.WaitingForACKBuffer{emptyTxedBufIdx} = obj.ReTxBuffer{obj.ReTxBufferFront + 1};
                        obj.WaitingForACKBufferContext(emptyTxedBufIdx, :) = [sn, obj.ReTxBufferContext(obj.ReTxBufferFront + 1, 2)];
                        % Clear the retransmission context of the SDU
                        obj.ReTxBufferContext(obj.ReTxBufferFront + 1, 1:2) = -1;
                        obj.ReTxBufferFront = mod(obj.ReTxBufferFront + 1, obj.MaxTxBufferSDUs);
                        obj.NumReTxBufferSDUs = obj.NumReTxBufferSDUs - 1;
                    end
                    % Update the poll bit in the PDU header if any of the
                    % status report triggering condition is met
                    pollBit = obj.getPollStatus();
                    if pollBit
                        rlcPDU(1) = bitor(rlcPDU(1), bitshift(pollBit, 6));
                        isPollIncluded = true;
                    end
                    rlcPDUSet{end+1} = rlcPDU;
                end
            end
        end

        function [statusPDU, statusPDULen, lastSNOffset] = addSegmentsInfoInStatusPDU(obj, sn, segmentsLost)
            %addSegmentsInfoInStatusPDU Add segmented SDUs information in
            % the status PDU

            lastSNOffset = 0;
            % Define the status PDU with the specified size. Maximum number
            % of bytes to represent a segment loss in the status PDU is 7
            statusPDU = zeros(obj.MaxReassemblySDU * 7, 1);
            statusPDULen = 0;

            segmentIdx = 1;
            numSegmentsLost = numel(segmentsLost);
            isRxSeqNum12 = obj.RxSeqNumFieldLength == 12;
            bytesFilled = 0;
            % Iterate through the segments lost for the SDU
            while true
                if lastSNOffset ~= 0
                    % Update the E1 field in the status PDU
                    if isRxSeqNum12
                        statusPDU(lastSNOffset) = bitor(statusPDU(lastSNOffset), 8);
                    else
                        statusPDU(lastSNOffset) = bitor(statusPDU(lastSNOffset), 32);
                    end
                end

                % Update the NACK SN in the status PDU
                if isRxSeqNum12
                    statusPDU(statusPDULen + 1) = bitshift(sn, -4);
                    statusPDU(statusPDULen + 2) = bitshift(bitand(sn, 15), 4);
                    lastSNOffset = lastSNOffset + bytesFilled + 2;
                    statusPDULen = statusPDULen + 2;
                else
                    statusPDU(statusPDULen + 1) = bitshift(sn, -10);
                    statusPDU(statusPDULen + 2) = bitand(bitshift(sn, -2), 255);
                    statusPDU(statusPDULen + 3) = bitshift(bitand(sn, 3), 6);
                    lastSNOffset = lastSNOffset + bytesFilled + 3;
                    statusPDULen = statusPDULen + 3;
                end
                % Check if the whole SDU is missing
                if numSegmentsLost == 0
                    break;
                end
                bytesFilled = 0;
                % Add the segment offset information to the status PDU
                segmentStart = segmentsLost(segmentIdx);
                segmentEnd = segmentsLost(segmentIdx + 1);
                % Update the E2 field
                if isRxSeqNum12
                    statusPDU(lastSNOffset) = bitor(statusPDU(lastSNOffset), 4);
                else
                    statusPDU(lastSNOffset) = bitor(statusPDU(lastSNOffset), 16);
                end
                % Add the SO start in the status PDU
                statusPDU(statusPDULen + 1) = bitshift(segmentStart, -8);
                statusPDU(statusPDULen + 2) = bitand(segmentStart, 255);
                % Add the SO end in the status PDU
                statusPDU(statusPDULen + 3) = bitshift(segmentEnd, -8);
                statusPDU(statusPDULen + 4) = bitand(segmentEnd, 255);
                statusPDULen = statusPDULen + 4;
                bytesFilled = bytesFilled + 4;
                % Update the segment index to next segment start
                segmentIdx = segmentIdx + 2;
                if (segmentIdx > numSegmentsLost)
                    break;
                end
            end
        end

        function updateRxGaps(obj, sn)
            %updateRxGaps Update the completely received SDUs context

            % Identify whether this complete SDU reception is an extension
            % for the existing contiguous SDU receptions. This can be
            % checked by finding its previous and following SDUs reception
            % status
            prevSNRxStatus = (obj.RcvdSNList == mod(sn - 1, obj.TotalRxSeqNum));
            nextSNRxStatus = (obj.RcvdSNList == mod(sn + 1, obj.TotalRxSeqNum));
            isPrevSNContigious = any(prevSNRxStatus, 'all');
            isNextSNContigious = any(nextSNRxStatus, 'all');
            if ~isPrevSNContigious && ~isNextSNContigious
                % Create a new contiguous reception since it is not
                % extending any other existing contiguous reception
                indices = find(obj.RcvdSNList == [-1, -1], 1);
                obj.RcvdSNList(indices, 1) = sn;
                obj.RcvdSNList(indices, 2) = sn;
            elseif isPrevSNContigious && ~isNextSNContigious
                obj.RcvdSNList(prevSNRxStatus(:, 2), 2) = sn;
            elseif ~isPrevSNContigious && isNextSNContigious
                obj.RcvdSNList(nextSNRxStatus(:, 1), 1) = sn;
            else
                % Merge the two contiguous receptions since the new SDU
                % makes them one contiguous reception
                obj.RcvdSNList(prevSNRxStatus(:, 2), 2) = obj.RcvdSNList(nextSNRxStatus(:, 1), 2);
                obj.RcvdSNList(nextSNRxStatus(:, 1), 1:2) = -1;
            end
        end

        function rxStatus = isCompleteSDURcvd(obj, sn)
            %isCompleteSDURcvd Check whether the complete SDU is received

            rxStatus = false;
            % Get the contiguous reception starts and ends
            contiguousRxStarts = obj.getRxSNModulus(obj.RcvdSNList(obj.RcvdSNList(:, 1) >= 0, 1));
            contiguousRxEnds = obj.getRxSNModulus(obj.RcvdSNList(obj.RcvdSNList(:, 2) >= 0, 2));
            sn = obj.getRxSNModulus(sn);
            % When the contiguous receptions are present, check whether the
            % given SDU SN falls within any of the contiguous reception
            if ~isempty(contiguousRxStarts)
                if any((contiguousRxStarts <= sn) & (contiguousRxEnds >= sn))
                    rxStatus = true;
                end
            end
        end
    end
end
