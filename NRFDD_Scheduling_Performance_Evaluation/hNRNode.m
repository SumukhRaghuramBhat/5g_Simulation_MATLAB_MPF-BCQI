classdef (Abstract) hNRNode < handle
    %hNRNode Node class containing properties and components common for
    %both gNB node and UE node

    % Copyright 2019-2020 The MathWorks, Inc.

    properties (Access = public)
        % Applications A column vector of data traffic models installed on this node
        Applications

        % RLCEntities A set of RLC entities
        % Each entity corresponds to a configured MAC logical channel. For
        % gNB, it is a 2D array with each row corresponding to a UE
        RLCEntities

        % MACEntity A MAC entity associated with this node
        MACEntity

        % PhyEntity A physical layer entity associated with this node
        PhyEntity

        % Position Position of the node
        Position
    end

    properties (Access = protected)
        % MsTimer Keeps track of count of symbol finished in current period of 1 ms
        % When symbols equivalent to duration of 1 ms are
        % finished, RLC is triggered and applications are run
        MsTimer = 0;
    end

    properties (Access = protected, Constant)
        % MaxApplications Maximum number of applications
        % Maximum number of applications that can be configured between a UE and its gNB
        MaxApplications = 16;
        % MaxLogicalChannels Maximum number of logical channels
        % Maximum number of logical channels that can be configured between a UE
        % and its associated gNB. It can be up to 32 as in the 3GPP
        % standard
        MaxLogicalChannels = 4;
        % NumRLCStats Number of RLC layer statistics collected
        NumRLCStats = 21;
    end

    methods (Access = public)
        function obj = hNRNode()
            %hNRNode Initialize the object properties with default values

            % For gNB, the default initialization considers only one UE
            % associated with it
            obj.RLCEntities = cell(1, obj.MaxLogicalChannels);
            obj.Applications = cell(obj.MaxApplications, 1);
        end

        function addApplication(obj, rnti, lcid, app)
            %appApplication Add application traffic model to the node
            %
            % appApplication(OBJ, RNTI, LCID, APPCONFIG) adds the
            % application traffic model for LCID in the node. If the node is UE,
			% the traffic is in UL direction. If it is gNB, it is in DL
			% direction for the UE identified by RNTI.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            % LCID is a logical channel id, specified in the range
            % between 1 and 32, inclusive.
            %
            % APP is a handle object that generates the application
            % traffic.

            % Determine the application index of a UE in the application
            % set
            if obj.MACEntity.MACType
                % For UE, there will be only one application set
                appSetIndex = 1;
            else
                % For gNB, then RNTI becomes application set index
                appSetIndex = rnti;
            end
            appsListStart = obj.MaxApplications * (appSetIndex - 1) + 1;
            appsListEnd = obj.MaxApplications * appSetIndex;
            % Check whether the new application can be installed between
            % the UE and its associated gNB
            appIdx = appsListStart + find(cellfun(@isempty, obj.Applications(appsListStart:appsListEnd)), 1) - 1;
            if isempty(appIdx)
                error('nr5g:hNRNode:TooManyApplications', ...
                    ['Number of applications between UE', num2str(rnti), ...
                    ' and its associated gNB must not exceed the configured limit ', num2str(obj.MaxApplications)]);
            end
            obj.Applications{appIdx}.RNTI = rnti;
            obj.Applications{appIdx}.LogicalChannelID = lcid;
            obj.Applications{appIdx}.App = app;
            obj.Applications{appIdx}.TimeLeft = 0;
        end

        function runApplication(obj)
            %runApplication Generate traffic from the installed
            % applications

            % Iterate through all the installed applications
            for appIdx = 1:numel(obj.Applications)
                if isempty(obj.Applications{appIdx})
                    continue;
                end
                % Decrement the time left for generating a new packet by 1
                % ms
                obj.Applications{appIdx}.TimeLeft = obj.Applications{appIdx}.TimeLeft - 1;

                % Check if the application has generated one more packet in
                % the current millisecond
                while obj.Applications{appIdx}.TimeLeft <= 0
                    % Generate packet from the application traffic pattern
                    [dt, packetSize, packet] = generate(obj.Applications{appIdx}.App);
                    % Send the application packet to RLC layer
                    obj.enqueueRLCSDU(obj.Applications{appIdx}.RNTI, obj.Applications{appIdx}.LogicalChannelID, packet(1:packetSize));
                    % Update the time left for the generation of next
                    % packet
                    obj.Applications{appIdx}.TimeLeft = obj.Applications{appIdx}.TimeLeft + dt;
                end
            end
        end

        function configureLogicalChannel(obj, rnti, rlcChannelConfig)
            %configureLogicalChannel Configure a logical channel
            %   configureLogicalChannel(OBJ, RNTI, RLCCHANNELCONFIG)
            %   configures a logical channel by creating an associated RLC
            %   entity and updating this logical channel information in the
            %   MAC.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            %   RLCCHANNELCONFIG is a RLC channel configuration structure.
            %   For RLC transmitter entity RLCCHANNELCONFIG contains these
            %   fields:
            %       EntityType         - Indicates the RLC entity type. It
            %                            can take values in the range [0,
            %                            3]. The values 0, 1, 2, and 3
            %                            indicate RLC UM unidirectional DL
            %                            entity, RLC UM unidirectional UL
            %                            entity, RLC UM bidirectional
            %                            entity, and RLC AM entity,
            %                            respectively
            %       LogicalChannelID    - Logical channel id
            %       SeqNumFieldLength   - Sequence number field length (in
            %                             bits) for transmitter and
            %                             receiver. So, it is a 1-by-2
            %                             matrix
            %       MaxTxBufferSDUs     - Maximum Tx buffer size in term of
            %                             RLC SDUs
            %       PollPDU             - Number of PDUs that must be sent
            %                             before requesting status report
            %                             in the RLC AM entity
            %       PollByte            - Number of RLC SDU bytes that must
            %                             be sent before requesting status
            %                             report in the RLC AM entity
            %       PollRetransmitTimer - Poll retransmit timer value (in
            %                             ms) that is used in the RLC AM
            %                             entity
            %       ReassemblyTimer     - Reassembly timer value (in ms)
            %
            %       StatusProhibitTimer - Status prohibit timer value (in
            %                             ms) that
            %       LCGID               - Logical channel group id
            %       Priority            - Priority of the logical channel
            %       PBR                 - Prioritized bit rate (in kilo
            %                             bytes per second)
            %       BSD                 - Bucket size duration (in ms)

            % Determine the logical channel index of a UE in the logical
            % channel set
            if obj.MACEntity.MACType
                % If it is UE, there will be only one logical channel set
                logicalChannelSetIndex = 1;
            else
                % If it is gNB, then RNTI becomes logical channel set index
                logicalChannelSetIndex = rnti;
            end

            % Alter the entity type value in the given configuration
            % structure from 0 to 1 and 1 to 0 for UE device. This
            % alteration helps in UE side RLC entities to choose receiver
            % configuration on 0 and transmitter configuration on 1 from
            % the structure in case of unidirectional RLC UM entities
            if obj.MACEntity.MACType && isfield(rlcChannelConfig, 'EntityType') && ...
                    any(rlcChannelConfig.EntityType == [0 1])
                rlcChannelConfig.EntityType = ~rlcChannelConfig.EntityType;
            end
            rlcChannelConfig.RNTI = rnti;

            % Check whether the new logical channel can be established
            % between the UE and its associated gNB
            lchIdx = find(cellfun(@isempty, obj.RLCEntities(logicalChannelSetIndex, :)), 1);
            if isempty(lchIdx)
                error('nr5g:hNRNode:TooManyLogicalChannels', ...
                    ['Number of logical channels between UE', num2str(rnti), ...
                    ' and its associated gNB must not exceed the configured limit ', num2str(obj.MaxLogicalChannels)]);
            end

            % Set the RLC reassembly buffer size to the number of gaps
            % possible in the reception. The maximum possible gaps at RLC
            % entity is equal to the number of HARQ process at the MAC
            % layer
            rlcChannelConfig.MaxReassemblySDU = obj.MACEntity.NumHARQ;
            if isfield(rlcChannelConfig, 'EntityType') && rlcChannelConfig.EntityType == 3
                % Create an RLC AM entity
                obj.RLCEntities{logicalChannelSetIndex, lchIdx} = hNRAMEntity(rlcChannelConfig);
            else
                % Create an RLC UM entity
                obj.RLCEntities{logicalChannelSetIndex, lchIdx} = hNRUMEntity(rlcChannelConfig);
            end
            % Register MAC interface function with the RLC entity
            obj.RLCEntities{logicalChannelSetIndex, lchIdx}.registerMACInterfaceFcn(@obj.updateLCHBufferStatus);
            % Add the logical channel information to the MAC layer
            lcConfig.RNTI = rnti;
            lcConfig.LCID = rlcChannelConfig.LogicalChannelID;
            lcConfig.Priority = rlcChannelConfig.Priority;
            lcConfig.LCGID = rlcChannelConfig.LCGID;
            lcConfig.BSD = rlcChannelConfig.BSD;
            lcConfig.PBR = rlcChannelConfig.PBR;
            obj.MACEntity.addLogicalChannelInfo(lcConfig, rnti);
        end

        function enqueueRLCSDU(obj, rnti, lcid, rlcSDU)
            %enqueueRLCSDU Enqueue the RLC SDU from higher layers
            %
            % enqueueRLCSDU(OBJ, RNTI, LCID, RLCSDU) forwards the
            % received RLC SDU to the respective RLC entity and sends the
            % updated buffer status information to the MAC.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            % LCID is a logical channel id, specified in the range
            % between 1 and 32.
            %
            % RLCSDU is a column vector of octets in decimal format.

            % Get the corresponding RLC entity
            rlcEntity = getRLCEntity(obj, rnti, lcid);
            % Send the received RLC SDU to the corresponding RLC entity
            rlcEntity.send(rlcSDU);
        end

        function rlcPDUs = sendRLCPDUs(obj, rnti, lcid, grantSize, remainingGrant)
            %sendRLCPDUs Callback from MAC to RLC for getting RLC PDUs of a
            % logical channel for transmission
            %
            % RLCPDUS = sendRLCPDUs(OBJ, RNTI, LCID, GRANTSIZE,
            % REMAININGGRANT) returns the RLC PDUs.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            % LCID is a logical channel id, specified in the range
            % between 1 and 32, inclusive.
            %
            % GRANTSIZE is a scalar integer that specifies the resource
            % grant size in bytes.
            %
            % REMAININGGRANT is a scalar integer that specifies the
            % remaining resource grant (in bytes) available for the
            % current Tx.
            %
            % RLCPDUS is a cell array of RLC PDUs. Each element in the
            % cell represents an RLC PDU which contains column vector of
            % octets in decimal format.

            % Get the corresponding RLC entity
            rlcEntity = getRLCEntity(obj, rnti, lcid);
            % Notify the grant to the RLC entity
            rlcPDUs = rlcEntity.notifyTxOpportunity(grantSize, remainingGrant);
        end

        function receiveRLCPDUs(obj, rnti, lcid, rlcPDU)
            %receiveRLCPDUs Callback to RLC to receive an RLC PDU for a
            % logical channel
            %
            % receiveRLCPDUs(OBJ, RNTI, LCID, RLCPDU)
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321. It
            % identifies the transmitter UE.
            %
            % LCID is a logical channel id, specified in the range
            % between 1 and 32, inclusive.
            %
            % RLCPDU RLC PDU extracted from received MAC PDU, to be sent
            % to RLC.

            % Get the corresponding RLC entity
            rlcEntity = getRLCEntity(obj, rnti, lcid);
            % Forward the received RLC PDU to the RLC entity
            receive(rlcEntity, rlcPDU);
        end

        function updateLCHBufferStatus(obj, lchBufferStatus)
            %updateLCHBufferStatus Update the buffer status of the logical channel
            %   updateLCHBufferStatus(OBJ, LCHBUFFERSTATUS) updates the
            %   buffer status of the logical channel. This method is
            %   registered as a callback for reporting the buffersatus of
            %   RLC entity to MAC
            %
            %   LCHBUFFERSTATUS is a handle object, which contains the
            %   following fields:
            %       RNTI                - Radio network temporary 
            %                             identifier
            %       LogicalChannelID    - Logical channel identifier
            %       BUFFERSTATUS        - Required grant for transmitting 
            %                             the stored RLC SDUs

            % Send the updated buffer status information to the MAC
            updateBufferStatus(obj.MACEntity, lchBufferStatus);
        end

        function cqiRBs = getChannelQuality(obj, linkDir, rnti)
            %getChannelQuality Return the channel quality information of a UE based on link direction
            %
            % CQIRBS = getChannelQuality(OBJ, LINKDIR, RNTI) returns the
            % channel quality information for the specified LINKDIR for
            % the UE.
            %
            % CQIRBS it is an array of integers that specifies the CQI
            % values over the RBs of channel bandwidth.
            %
            % LINKDIR is a scalar integer, specified as 0 or 1. LINKDIR = 0
            % represents downlink and LINKDIR = 1 represents uplink.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            
            if obj.MACEntity.MACType
                % If called by UE, return its DL channel quality
                cqiRBs = getChannelQualityStatus(obj.MACEntity);
            else
                % If called by gNB, return the linkDir (DL/UL) channel
                % quality for the UE
                cqiRBs = getChannelQualityStatus(obj.MACEntity, linkDir, rnti);
            end
        end

        function updateChannelQuality(obj, cqiRBs, varargin)
            %updateChannelQuality Update the channel quality information at the gNB and UEs
            %
            % updateChannelQuality(OBJ, CQIRBS, LINKDIR, RNTI) helps in
            % updating the channel quality information based on LINKDIR
            % and RNTI at gNB.
            %
            % updateChannelQuality(OBJ, CQIRBS) updates the downlink
            % channel quality information at UE.
            %
            % CQIRBS is an array of integers that specifies the CQI
            % values over the RBs of channel bandwidth.
            %
            % LINKDIR is a scalar integer, specified as 0 or 1. LINKDIR = 0
            % represents downlink and LINKDIR = 1 represents uplink.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            
            if numel(varargin) == 2
                updateChannelQualityStatus(obj.MACEntity, cqiRBs, varargin{1}, varargin{2});
            else
                updateChannelQualityStatus(obj.MACEntity, cqiRBs);
            end
        end

        function symbolType = currentSymbolType(obj)
            %currentSymbolType Get the current running symbol type:
            % DL/UL/Guard

            symbolType = currentSymbolType(obj.MACEntity);
        end

        function rlcStats = getRLCStatistics(obj, rnti)
            %getRLCStatistics Return the instantaneous RLC statistics
            %
            % RLCSTATS = getRLCStatistics(OBJ, RNTI) returns statistics
            % of its RLC entities.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            % RLCSTATS - RLC statistics represented as a N-by-P matrix,
            % where 'N' represent the number of logical channels and 'P'
            % represent the number of RLC layer statistics collected. The
            % 'P' columns are as follows 'RNTI', 'LCID', 'TxDataPDU',
            % 'TxDataBytes', 'ReTxDataPDU', 'ReTxDataBytes' 'TxControlPDU',
            % 'TxControlBytes', 'TxPacketsDropped', 'TxBytesDropped',
            % 'TimerPollRetransmitTimedOut', 'RxDataPDU', 'RxDataBytes',
            % 'RxDataPDUDropped', 'RxDataBytesDropped',
            % 'RxDataPDUDuplicate', 'RxDataBytesDuplicate', 'RxControlPDU',
            % 'RxControlBytes', 'TimerReassemblyTimedOut',
            % 'TimerStatusProhibitTimedOut'

            % Row index in the RLC Entity list
            if obj.MACEntity.MACType % UE
                logicalChannelSetIdx = 1;
            else % gNB
                % If it is gNB, then RNTI becomes row index
                logicalChannelSetIdx = rnti;
            end

            rlcStatsList = zeros(obj.MaxLogicalChannels, obj.NumRLCStats);
            activeLCHIds = zeros(obj.MaxLogicalChannels, 1);
            for lchIdx = 1:obj.MaxLogicalChannels
                % Check the existence of RLC entity before querying the
                % statistics
                rlcEntity = obj.RLCEntities{logicalChannelSetIdx, lchIdx};
                if isempty(rlcEntity)
                    continue;
                end
                % Get the cumulative RLC statistics of all logical
                % channels of a UE
                stats = rlcEntity.getStatistics();
                lcid = rlcEntity.LogicalChannelID;
                activeLCHIds(lchIdx) = lchIdx;
                rlcStatsList(lchIdx, :) = [rnti lcid stats'];
            end
            rlcStats = rlcStatsList(nonzeros(activeLCHIds), :); % Send the information of active logical channels
        end

        function [throughputServing, goodputServing] = getTTIBytes(obj)
            %getTTIBytes Return amount of throughput and goodput bytes sent in current symbol
            %
            % [THROUGHPUTSERVING GOODPUTSERVING] = getTTIBytes(OBJ)
            % returns the amount of throughput and goodput bytes sent in
            % the TTI which starts at current symbol.
            %
            % THROUGHPUTSERVING - MAC transmission (throughput) in bytes.
            %
            % GOODPUTSERVING - Only new MAC transmission (goodput) in bytes

            [throughputServing, goodputServing] = getTTIBytes(obj.MACEntity);
        end

        function advanceTimer(obj, tickGranularity)
            %advanceTimer Advance the timer by tick granularity
            %
            % advanceTimer(OBJ, TICKGRANULARITY) Advance the timer by
            % tick granularity. Additionally, send periodic 1 ms trigger
            % to RLC.
            %
            % TICKGRANULARITY - Specified in terms of number of symbols.
            % It is 1 for symbol-based scheduling, so execution happens
            % symbol-by-symbol. It is 14 for slot based scheduling, so
            % execution jumps from slot boundary to next slot boundary.

            advanceTimer(obj.MACEntity, tickGranularity); % Advance MAC clock
            obj.MsTimer = obj.MsTimer + tickGranularity;
            scs = obj.MACEntity.SCS;
            if obj.MsTimer == (14 * scs/15)
                % Trigger RLC timer for every 1 ms
                updateRlcTimer(obj);
                % Run applications
                runApplication(obj);
                % Reset after every 1 ms
                obj.MsTimer = 0;
            end

            advanceTimer(obj.PhyEntity, tickGranularity); % Advance Phy clock
        end

        function bufferStatus = getBufferStatus(obj)
            %getBufferStatus Return the current buffer status of UEs
            %
            % BUFFERSTATUS = getBufferStatus(OBJ) Returns the UL buffer
            % status of UE, when called by UE. Returns DL buffer
            % status array containing buffer amount for each UE, when
            % called by gNB.
            %
            % BUFFERSTATUS - Represents the buffer size in bytes.

            bufferStatus = getUEBufferStatus(obj.MACEntity);
        end

        function pos = getPosition(obj)
            %getPosition Get the current node position
            %
            % POS = getPosition(OBJ) returns the current node position, POS

            pos = obj.Position;
        end
    end

    methods(Access = private)
        function updateRlcTimer(obj)
            %updateRlcTimer Advance timer in all RLC entities by 1 ms

            for ueRLCEntityIdx = 1:size(obj.RLCEntities, 1)
                for rlcEntityIdx = 1:obj.MaxLogicalChannels
                    rlcEntity = obj.RLCEntities{ueRLCEntityIdx, rlcEntityIdx};
                    % Check if the RLC entity exists
                    if isempty(rlcEntity)
                        continue;
                    end
                    rlcEntity.updateTimer();
                end
            end
        end

        function rlcEntity = getRLCEntity(obj, rnti, lcid)
            %getRLCEntity Return the RLC entity
            %   RLCENTITY = getRLCEntityIndex(OBJ, RNTI, LCID) returns the
            %   RLCENTITY reference based on RNTI and LCID.
            %
            % RNTI is a radio network temporary identifier, specified
            % within [1 65519]. Refer table 7.1-1 in 3GPP TS 38.321.
            %
            %   LCID is a logical channel id, specified in the range
            %   between 1 and 32, inclusive.

            % Row index in the RLC Entity list
            if obj.MACEntity.MACType % UE
                rowIdx = 1;
            else % gNB
                % If it is gNB then RNTI becomes row index
                rowIdx = rnti;
            end
            rlcEntity = [];
            for colIdx = 1:obj.MaxLogicalChannels
                tmpRLCEntity = obj.RLCEntities{rowIdx, colIdx};
                % Check the existence of RLC entity before accessing its
                % data
                if isempty(tmpRLCEntity)
                    continue;
                end
                if obj.RLCEntities{rowIdx, colIdx}.LogicalChannelID == lcid
                    rlcEntity = obj.RLCEntities{rowIdx, colIdx};
                    break;
                end
            end
        end
    end
end