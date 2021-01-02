classdef hNRSchedulerProportionalFair < hNRScheduler
    %hNRSchedulerProportionalFair Implements proportional fair scheduler

    %   Copyright 2020 The MathWorks, Inc.

    properties
        % MovingAvgDataRateWeight Moving average parameter to calculate the average data rate
        MovingAvgDataRateWeight (1, 1) {mustBeNumeric, mustBeNonempty,...
                     mustBeGreaterThanOrEqual(MovingAvgDataRateWeight, 0),...
                     mustBeLessThanOrEqual(MovingAvgDataRateWeight, 1)} = 0.5;

        % UEsServedDataRate Stores DL and UL served data rate for each UE 
        % N-by-2 matrix where 'N' is the number of UEs. For each UE, gNB
        % maintains a context which is used in taking scheduling decisions.
        % There is one row for each UE, indexed by their respective RNTI
        % values. Each row has two columns with following information:
        % Served data rate in DL and served data rate in UL direction.
        % Served data rate is the average data rate achieved by UE till now
        % and serves as an important parameter for doing proportional fair
        % scheduling
        UEsServedDataRate
    end

    methods
        function obj = hNRSchedulerProportionalFair(simParameters)
            %hNRSchedulerProportionalFair Construct an instance of this class

            % Invoke the super class constructor to initialize the properties
            obj = obj@hNRScheduler(simParameters);

            % Moving average parameter to calculate the average data rate
            if isfield(simParameters, 'MovingAvgDataRateWeight')
                obj.MovingAvgDataRateWeight = simParameters.MovingAvgDataRateWeight;
            end

            obj.UEsServedDataRate = ones(length(obj.UEs), 2);
        end

        function [selectedUE, mcsIndex] = runSchedulingStrategy(obj, schedulerInput)
            %runSchedulingStrategy Implements the proportional fair scheduling
            %
            %   [SELECTEDUE, MCSINDEX] = runSchedulingStrategy(OBJ, SCHEDULERINPUT) runs
            %   the proportional fair algorithm and returns the UE (among the eligible
            %   ones) which wins this particular resource block group, along with the
            %   suitable MCS index based on the channel conditions. This function gets
            %   called for selecting a UE for each RBG to be used for new transmission
            %   i.e. once for each of the remaining RBGs after assignment for
            %   retransmissions is completed. According to PF scheduling
            %   strategy, the UE which has maximum value for the PF weightage, i.e. the
            %   ratio: (RBG-Achievable-Data-Rate/Historical-data-rate), gets the RBG.
            %
            %   SCHEDULERINPUT structure contains the following fields which scheduler
            %   would use (not necessarily all the information) for selecting the UE to
            %   which RBG would be assigned.
            %
            %       eligibleUEs    - RNTI of the eligible UEs contending for the RBG
            %       RBGIndex       - RBG index in the slot which is getting scheduled
            %       slotNum        - Slot number in the frame whose RBG is getting scheduled
            %       RBGSize        - RBG Size in terms of number of RBs
            %       cqiRBG         - Uplink Channel quality on RBG for UEs. This is a
            %                        N-by-P  matrix with uplink CQI values for UEs on
            %                        different RBs of RBG. 'N' is the number of eligible
            %                        UEs and 'P' is the RBG size in RBs
            %       mcsRBG         - MCS for eligible UEs based on the CQI values of the RBs
            %                        of RBG. This is a N-by-2 matrix where 'N' is number of
            %                        eligible UEs. For each eligible UE it contains, MCS
            %                        index (first column) and efficiency (bits/symbol
            %                        considering both Modulation and Coding scheme)
            %       pastDataRate   - Served data rate. Vector of N elements containing
            %                        historical served data rate to eligible UEs. 'N' is
            %                        the number of eligible UEs
            %       bufferStatus   - Buffer-Status of UEs. Vector of N elements where 'N'
            %                        is the number of eligible UEs, containing pending
            %                        buffer status for UEs
            %       ttiDur         - TTI duration in ms
            %       UEs            - RNTI of all the UEs (even the non-eligible ones for
            %                        this RBG)
            %       lastSelectedUE - The RNTI of the UE which was assigned the last
            %                        scheduled RBG
            %
            %   SELECTEDUE The UE (among the eligible ones) which gets assigned
            %   this particular resource block group
            %
            %   MCSINDEX The suitable MCS index based on the channel conditions

            selectedUE = -1;
            maxPFWeightage = 0;
            mcsIndex = -1;
            bestAvgCQI = 0;
            linkDir = schedulerInput.LinkDir;
            for i = 1:length(schedulerInput.eligibleUEs)
                bufferStatus = schedulerInput.bufferStatus(i);
                pastDataRate = obj.UEsServedDataRate(schedulerInput.eligibleUEs(i), linkDir+1);
                if(bufferStatus > 0) % Check if UE has any data pending
                    bitsPerSym = schedulerInput.mcsRBG(i, 2); % Accounting for both Modulation & Coding scheme
                    achievableDataRate = ((schedulerInput.RBGSize * bitsPerSym * 14 * 12)*1000)/ ...
                        (schedulerInput.ttiDur); % bits/sec
                    % Calculate UE weightage as per PF strategy
                    pfWeightage = achievableDataRate/pastDataRate;
                    % Get CQI values for the RBs of the resource block
                    % group and calculate average CQI for the whole RBG.
                    cqiRBG = schedulerInput.cqiRBG(i, :);
                    cqiAvg = floor(mean(cqiRBG));
                    if(pfWeightage > maxPFWeightage && cqiAvg > bestAvgCQI)
                        % Update the UE with maximum weightage and also
                        % Update the best CQI value till now.
                        maxPFWeightage = pfWeightage;
                        bestAvgCQI = cqiAvg;        %modified by also including BestCQI
                        selectedUE = schedulerInput.eligibleUEs(i);
                        mcsIndex = schedulerInput.mcsRBG(i, 1);
                    end
                end
            end

        end
    end
    methods(Access = protected)

        function uplinkGrants = scheduleULResourcesSlot(obj, slotNum)
            %scheduleULResourcesSlot Schedule UL resources of a slot
            % Uplink grants are returned as output to convey the way the
            % the uplink scheduler has distributed the resources to
            % different UEs. 'slotNum' is the slot number in the 10 ms
            % frame which is getting scheduled. The output 'uplnkGrants' is
            % a cell array where each cell-element represents an uplink
            % grant and has following fields:
            %
            % RNTI        Uplink grant is for this UE
            %
            % Type        Whether assignment is for new transmission ('newTx'),
            %             retransmission ('reTx')
            %
            % HARQId   Selected uplink UE HARQ process ID
            %
            % RBGAllocationBitmap  Frequency-domain resource assignment. A
            %                      bitmap of resource-block-groups of the PUSCH
            %                      bandwidth. Value 1 indicates RBG is assigned
            %                      to the UE
            %
            % StartSymbol  Start symbol of time-domain resources. Assumed to be
            %              0 as time-domain assignment granularity is kept as
            %              full slot
            %
            % NumSymbols   Number of symbols allotted in time-domain
            %
            % SlotOffset   Slot-offset of PUSCH assignments for upcoming slot
            %              w.r.t the current slot
            %
            % MCS          Selected modulation and coding scheme for UE with
            %              respect to the resource assignment done
            %
            % NDI          New data indicator flag

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
                % Update served data rate for the UEs as per the resource
                % assignments. This affects scheduling decisions for future
                % TTI
                updateUEServedDataRate(obj, obj.ULType, uplinkGrants);
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

                    % Update served data rate for the UEs as per the resource
                    % assignments. This affects scheduling decisions for future
                    % TTI
                    updateUEServedDataRate(obj, obj.ULType, TTIULGrants);
                end
                uplinkGrants = uplinkGrants(1 : numULGrants);
            end
        end
        function downlinkGrants = scheduleDLResourcesSlot(obj, slotNum)
            %scheduleDLResourcesSlot Schedule DL resources of a slot
            % Downlink grants are returned as output to convey the way the
            % the downlink scheduler has distributed the resources to
            % different UEs. 'slotNum' is the slot number in the 10 ms
            % frame which is getting scheduled. The output 'downlinkGrants' is
            % a cell array where each cell-element represents a downlink
            % grant and has following fields:
            %
            % RNTI        Downlink grant is for this UE
            %
            % Type        Whether assignment is for new transmission ('newTx'),
            %             retransmission ('reTx')
            %
            % HARQId   Selected downlink UE HARQ process ID
            %
            % RBGAllocationBitmap  Frequency domain resource assignment. A
            %                      bitmap of resource block groups of the PUSCH
            %                      bandwidth. Value 1 indicates RBG is assigned
            %                      to the UE
            %
            % StartSymbol  Start symbol of time-domain resources. Assumed to be
            %              0 as time-domain assignment granularity is kept as
            %              full slot
            %
            % NumSymbols   Number of symbols allotted in time-domain
            %
            % SlotOffset   Slot-offset of PUSCH assignments for upcoming slot
            %              w.r.t the current slot
            %
            % MCS          Selected modulation and coding scheme for UE with
            %              respect to the resource assignment done
            %
            % NDI          New data indicator flag
            %
            % FeedbackSlotOffset Slot offset of PDSCH ACK/NACK from PDSCH transmission (i.e. k1)

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
                % Update served data rate for the UEs as per the resource
                % assignments. This affects scheduling decisions for future
                % TTI
                updateUEServedDataRate(obj, obj.DLType, downlinkGrants);
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
                    TTIDLGrants = assignDLResourceTTI(obj, slotNum, startSym, obj.TTIGranularity);
                    downlinkGrants(numDLGrants + 1 : numDLGrants + length(TTIDLGrants)) = TTIDLGrants(:);
                    numDLGrants = numDLGrants + length(TTIDLGrants);
                    startSym = startSym + obj.TTIGranularity;

                    % Update served data rate for the UEs as per the resource
                    % assignments. This affects scheduling decisions for future
                    % TTI
                    updateUEServedDataRate(obj, obj.DLType, TTIDLGrants);
                end
                downlinkGrants = downlinkGrants(1 : numDLGrants);
            end
        end

    end

    methods(Access = private)
        function updateUEServedDataRate(obj, linkType, resourceAssignments)
            %updateUEServedDataRate Update UEs' served data rate based on RB assignments
            
            if linkType % Uplink
                mcsTable = obj.MCSTableUL;
                totalRBs = obj.NumPUSCHRBs;
                rbgSize = obj.RBGSizeUL;
                numDMRS = obj.NumPUSCHDMRS;
            else % Downlink
                mcsTable = obj.MCSTableDL;
                totalRBs = obj.NumPDSCHRBs;
                rbgSize = obj.RBGSizeDL;
                numDMRS = obj.NumPDSCHDMRS;
            end
            
            % Store UEs which got grant
            scheduledUEs = zeros(length(obj.UEs), 1);
            % Update served data rate for UEs which got grant
            for i = 1:length(resourceAssignments)
                resourceAssignment = resourceAssignments{i};
                scheduledUEs(i) = resourceAssignment.RNTI;
                averageDataRate = obj.UEsServedDataRate(resourceAssignment.RNTI ,linkType+1);
                mcsInfo = mcsTable(resourceAssignment.MCS + 1, :);
                % Bits-per-symbol is after considering both modulation
                % scheme and coding rate
                bitsPerSym = mcsInfo(3);
                % Number of RBGs assigned to UE
                numRBGs = sum(resourceAssignment.RBGAllocationBitmap(:) == 1);
                if resourceAssignment.RBGAllocationBitmap(end) == 1 && ...
                        (mod(totalRBs, rbgSize) ~=0)
                    % If last RBG is allotted and it does not have same number of RBs as
                    % other RBGs.
                    numRBs = (numRBGs-1)*rbgSize + mod(totalRBs, rbgSize);
                else
                    numRBs = numRBGs * rbgSize;
                end
                achievedTxBits = obj.getResourceBandwidth(bitsPerSym, numRBs, ...
                    resourceAssignment.NumSymbols - numDMRS);
                ttiDuration = (obj.SlotDuration * resourceAssignment.NumSymbols)/14;
                achievedDataRate = (achievedTxBits*1000)/ttiDuration; % bits/sec
                updatedAverageDataRate = ((1-obj.MovingAvgDataRateWeight) * averageDataRate) + ...
                    (obj.MovingAvgDataRateWeight * achievedDataRate);
                obj.UEsServedDataRate(resourceAssignment.RNTI, linkType+1) = updatedAverageDataRate;
            end
            scheduledUEs = nonzeros(scheduledUEs);
            unScheduledUEs = setdiff(obj.UEs, scheduledUEs);
            
            % Update (decrease) served data rate for each unscheduled UE
            for i=1:length(unScheduledUEs)
                averageDataRate = obj.UEsServedDataRate(unScheduledUEs(i) ,linkType+1);
                updatedAverageDataRate = (1-obj.MovingAvgDataRateWeight) * averageDataRate;
                obj.UEsServedDataRate(unScheduledUEs(i), linkType+1) = updatedAverageDataRate;
            end
        end
    end
end