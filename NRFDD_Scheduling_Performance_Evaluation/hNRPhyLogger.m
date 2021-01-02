classdef hNRPhyLogger < handle
    %hNRPhyLogger Phy logging and visualization
    %   The class implements per slot logging mechanism as well as
    %   visualization of the physical layer metrics like block error rate
    %   (BLER). Visualization shows the block error rate with respect to
    %   the simulation time.

    %   Copyright 2020 The MathWorks, Inc.

    properties
        %NCellID Cell id to which the logging and visualization object belongs
        NCellID (1, 1) {mustBeInteger, mustBeInRange(NCellID, 0, 1007)} = 1;

        % NumUEs Count of UEs in each cell
        NumUEs
        
        % BLERMetrics Timestamped BLER metrics for each UE
        % Store metrics in a cell array of tables. Each table holds
        % simulation metrics of uplink and downlink. Each row of the table
        % has information of a metrics step and has these columns:
        % timestamp, BLER of all UEs in an array
        BLERMetrics

        % NumSlotsFrame Number of slots in 10ms time frame
        NumSlotsFrame

        % BLERStatsLog Slot-by-slot log of the BLER statistics
        BLERStatsLog
    end

    properties(Access = private)
        % BLERPlotHandles 1-by-2 matrix of BLER plot handles. Columns 1, 2
        % represent the metric plots handles in downlink and uplink
        % respectively
        BLERPlotHandles
        
        % BLERVisualizationFigHandle Handle to display the downlink and
        % uplink block error rates for each UE
        BLERVisualizationFigHandle

        % CurrSlot Current slot in the frame
        CurrSlot = -1

        % CurrFrame Current frame
        CurrFrame = -1

        % PlotDescription Description of the plot
        PlotDescription

        % UELegends Legend for the UEs
        UELegends

        % NumMetricsSteps Number of times metrics plots are updated
        NumMetricsSteps

        % PlotIds Plot Ids
        PlotIds

        % PlotHandle Handle for downlink and uplink BLER plots
        PlotHandle = cell(2, 1);

        % MetricsStepIndex Current metrics step index
        % Metrics are collected every slot but are plotted only at metrics
        % steps
        MetricsStepIndex = 0

        % MetricsStepSize Number of slots in one metrics step
        MetricsStepSize

        % MetricsStepDuration Duration of 1 metrics step
        MetricsStepDuration
    end

    properties (Access = private, Constant, Hidden)
        % Constants related to downlink and uplink information. These
        % constants are used for indexing logs and identifying plots
        % DownlinkIdx Index for all downlink information
        DownlinkIdx = 1;
        
        % UplinkIdx Index for all uplink information
        UplinkIdx = 2;
    end

    methods (Access = public)
        function obj = hNRPhyLogger(simParameters, varargin)
            %hNRPhyLogger Construct Phy log and visualization object
            %
            % OBJ = hNRPhyLogger(SIMPARAMETERS) Create a Phy logging and
            % block error rate (BLER) visualization object. It creates
            % figures for visualizing BLER in both downlink and uplink.
            %
            % OBJ = hNRPhyLogger(SIMPARAMETERS, FLAG) Create a Phy logging 
            % and BLER visualization object. It creates figures for 
            % visualizing BLER either in the downlink or in the uplink directions.
            %
            % SIMPARAMETERS - It is a structure with the following fields
            %
            %   NumUEs            - Number of UEs
            %   NCellID           - Cell identifier
            %   SCS               - Subcarrier spacing
            %   NumMetricsSteps   - Number of times metrics plots to be
            %                       updated
            %   MetricsStepSize   - Interval at which metrics visualization
            %                       updates in terms of number of slots
            % If FLAG = 0, Visualize downlink BLER
            % If FLAG = 1, Visualize uplink BLER

            if isfield(simParameters, 'NCellID')
                obj.NCellID = simParameters.NCellID;
            end
            obj.NumUEs = simParameters.NumUEs;
            obj.NumSlotsFrame = (10 * simParameters.SCS) / 15; % Number of slots in a 10 ms frame
            obj.NumMetricsSteps = simParameters.NumMetricsSteps;
            % Interval at which metrics visualization updates in terms of number of
            % slots. Ensure that MetricsStepSize is an integer
            obj.MetricsStepSize = simParameters.MetricsStepSize;
            obj.MetricsStepDuration = obj.MetricsStepSize * (15 / simParameters.SCS);
            % One is added to numMetricSteps as X-axis of performance plots starts from zero
            timestamp = zeros(obj.NumMetricsSteps + 1, 1);
            blkErr = zeros(obj.NumMetricsSteps + 1, obj.NumUEs);

            obj.BLERPlotHandles = zeros(obj.NumUEs, 2); % Plot handles

            % BLER stats
            % Each row represents the statistics of each slot
            obj.BLERStatsLog = cell((simParameters.NumFramesSim * obj.NumSlotsFrame) + 2, 6);
            obj.BLERStatsLog{1, 1} = 0; % Frame number
            obj.BLERStatsLog{1, 2} = 0; % Slot number
            % Number of erroneous packets received per UE in the downlink direction
            obj.BLERStatsLog{1, 3} = zeros(obj.NumUEs, 1);
            % Number of packets received per UE in the downlink direction
            obj.BLERStatsLog{1, 4} = zeros(obj.NumUEs, 1);
            % Number of erroneous packets received per UE in the uplink direction
            obj.BLERStatsLog{1, 5} = zeros(obj.NumUEs, 1);
            % Number of packets received per UE in the uplink direction
            obj.BLERStatsLog{1, 6} = zeros(obj.NumUEs, 1);

            % Create the visualization for cell of interest
            if ~isfield(simParameters, 'CellOfInterest') || obj.NCellID == simParameters.CellOfInterest
                % Determine the plots
                if isempty(varargin) || varargin{1} == 2
                    % Downlink and uplink metrics plots
                    obj.PlotIds = [obj.DownlinkIdx obj.UplinkIdx];
                elseif varargin{1} == 0
                    obj.PlotIds = obj.DownlinkIdx; % Downlink metrics plot
                else
                    obj.PlotIds = obj.UplinkIdx; % Uplink metrics plot
                end
                obj.PlotDescription{obj.DownlinkIdx} = 'Downlink BLER';
                obj.PlotDescription{obj.UplinkIdx} = 'Uplink BLER';

                % Initialize metrics
                obj.BLERMetrics = cell(1, 2);
                for idx = 1:numel(obj.PlotIds)
                    plotId = obj.PlotIds(idx);
                    obj.BLERMetrics{1, plotId} = table(timestamp, blkErr);
                end

                % Create legend for the UEs
                obj.UELegends = cell(obj.NumUEs, 1);
                for ueIdx = 1:obj.NumUEs
                    obj.UELegends{ueIdx,1} = strcat("UE ", num2str(ueIdx));
                end

                % Using the screen width and height, calculate figure width and
                % height
                resolution = get(0,'ScreenSize');
                screenWidth = resolution(3);
                screenHeight = resolution(4);
                figureWidth = screenWidth * 0.90;
                figureHeight = screenHeight * 0.85;

                % Create the figure for BLER Visualization
                obj.BLERVisualizationFigHandle = figure('Name', 'Block Error Rate (BLER) Visualization',...
                    'Position', [screenWidth*0.05 screenHeight*0.05 figureWidth figureHeight], 'Visible', 'on');

                if numel(obj.PlotIds) == 2
                    plotHandleDL = subplot(2, 1, 2, 'Tag', obj.PlotDescription{obj.DownlinkIdx});
                    plotHandleDL.Position = [0.2294 0.0990 0.5700 0.3500]; % Downlink plot
                    obj.PlotHandle{obj.DownlinkIdx} = plotHandleDL;
                    createPlots(obj, obj.DownlinkIdx);
                    plotHandleUL = subplot(2, 1, 1, 'Tag', obj.PlotDescription{obj.UplinkIdx}); % Uplink plot
                    plotHandleUL.Position = [0.2294 0.5590 0.5700 0.35000];
                    obj.PlotHandle{obj.UplinkIdx} = plotHandleUL;
                    createPlots(obj, obj.UplinkIdx);
                    sgtitle(strcat("Block Error Rate (BLER) Visualization for Cell ID - ", num2str(obj.NCellID)), 'FontWeight', 'Bold', 'FontName', 'Arial', 'FontSize', 15, 'FontUnits', 'normalized');
                else
                    plotHandle = gca;
                    set(plotHandle, 'Units', 'Pixels', 'Position', [figureWidth * 0.23 figureHeight * 0.1 figureWidth * 0.67 figureHeight * 0.8], 'Units', 'normalized');
                    hold on;
                    title(strcat("Block Error Rate (BLER) Visualization for Cell ID - ", num2str(obj.NCellID)), 'FontSize', 15,'FontUnits', 'normalized', 'Position', [0.5 1.04 0], 'Units', 'normalized');
                    if obj.PlotIds == obj.DownlinkIdx % Downlink plot
                        obj.PlotHandle{obj.DownlinkIdx} = plotHandle;
                    else % Uplink plot
                        obj.PlotHandle{obj.UplinkIdx} = plotHandle;
                    end
                    createPlots(obj, obj.PlotIds);
                end
            end
        end

        function plotMetrics(obj)
            %plotMetrics Plot the Block Error Rate (BLER) metrics
            %
            % plotMetrics(OBJ) Calculate and stores the BLER of
            % each UE and updates the plot

            % Check whether 'BLER Visualization' figure exists
            if isempty(findobj(obj.BLERVisualizationFigHandle, 'Name', 'Block Error Rate (BLER) Visualization'))
                return;
            end

            obj.MetricsStepIndex = obj.MetricsStepIndex + 1;
            % Calculate metrics from logs of the slot in last step
            stepLogStartIdx = (obj.MetricsStepIndex-1) * obj.MetricsStepSize + 1;
            stepLogEndIdx = (obj.MetricsStepIndex) * obj.MetricsStepSize;
            for idx = 1:numel(obj.PlotIds)
                plotId = obj.PlotIds(idx);
                blerLogs = zeros(obj.NumUEs, 2);
                for stepIdx = stepLogStartIdx:stepLogEndIdx
                    blerLogs(:, 1) = blerLogs(:, 1) + obj.BLERStatsLog{stepIdx, 2*plotId + 1};
                    blerLogs(:, 2) = blerLogs(:, 2) + obj.BLERStatsLog{stepIdx, 2*plotId + 2};
                end
                % Average statistics over metric steps
                slotLog = blerLogs(:, 1)./blerLogs(:, 2);
                % Assign BLER to zero if no packets have been received
                slotLog(blerLogs(:, 2) == 0) = 0;
                obj.BLERMetrics{1, plotId}.timestamp(obj.MetricsStepIndex + 1) = ...
                    (obj.MetricsStepIndex * obj.MetricsStepDuration ) / 1000;
                for ueIdx = 1:obj.NumUEs
                    obj.BLERMetrics{1, plotId}.blkErr(obj.MetricsStepIndex+1, ueIdx) = slotLog(ueIdx, 1);
                end
                updateMetrics(obj, plotId);
            end
        end

        function updateMetrics(obj, plotId)
            %updateMetrics Update the UE metrics

            for ueIdx = 1:obj.NumUEs
                set(obj.BLERPlotHandles(ueIdx, plotId), 'Xdata', (0 : obj.MetricsStepIndex), 'Ydata',...
                    obj.BLERMetrics{1, plotId}.blkErr(1 : obj.MetricsStepIndex+1, ueIdx));
            end
        end
        
        function logBLERStats(obj, ueBLERStats, gNBBLERStats)
            %logBLERStats Log the block error rate (BLER) statistics
            %
            % logBLERtats(OBJ, UEBLERSTATS, GNBBLERSTATS) Logs the BLER
            % statistics
            %
            % UEBLERSTATS - Represents a N-by-2 array, where N is the number
            % of UEs. First and second columns of the array contains the
            % number of erroneous packets received and the total number of
            % received packets for each UE
            %
            % GNBBLERSTATS - Represents a N-by-2 array, where N is the number
            % of UEs. First and second columns of the array contains the
            % number of erroneous packets received and the total number of
            % received packets from each UE
            
            if isempty(ueBLERStats) % Downlink BLER stats
                ueBLERStats = zeros(obj.NumUEs, 2);
            end
            if isempty(gNBBLERStats) % Uplink BLER stats
                gNBBLERStats = zeros(obj.NumUEs, 2);
            end
            % Move to the next slot
            obj.CurrSlot = mod(obj.CurrSlot + 1, obj.NumSlotsFrame);
            if(obj.CurrSlot == 0)
                obj.CurrFrame = obj.CurrFrame + 1; % Next frame
            end
            logIndex = obj.CurrFrame * obj.NumSlotsFrame + obj.CurrSlot + 1;
            obj.BLERStatsLog{logIndex, 1} = obj.CurrFrame;
            obj.BLERStatsLog{logIndex, 2} = obj.CurrSlot;
            
            % Number of erroneous packets in downlink
            obj.BLERStatsLog{logIndex, 3} = ueBLERStats(:, 1);
            % Number of packets in downlink
            obj.BLERStatsLog{logIndex, 4} = ueBLERStats(:, 2);
            % Number of erroneous packets in uplink
            obj.BLERStatsLog{logIndex, 5} = gNBBLERStats(:, 1);
            % Number of packets in uplink
            obj.BLERStatsLog{logIndex, 6} = gNBBLERStats(:, 2);
        end

        function blerLogs = getBLERLogs(obj)
            %GETBLERLOGS Return the per slot logs
            %
            % BLERLOGS = getBLERLogs(OBJ) Returns the Block Error Rate logs
            %
            % BLERLOGS - It is (N+2)-by-P cell, where N represents the
            % number of slots in the simulation and P represents the number
            % of columns. The first row of the logs contains titles for the
            % logs.The last row of the logs contains the cumulative
            % statistics for the entire simulation. Each row (excluding the first and last rows)
            % in the logs represents a slot and contains the following information.
            %  Frame                           - Frame number.
            %  Slot                            - Slot number in the frame.
            %  Number of Erroneous Packets(DL) - N-by-1 array, where N is the
            %                                    number of UEs. Each
            %                                    element contains the
            %                                    number of erroneous
            %                                    packets in the downlink
            %  Number of Packets(DL)           - N-by-1 array, where N is the
            %                                    number of UEs. Each
            %                                    element contains the
            %                                    number of packets in the downlink
            %  Number of Erroneous Packets(UL) - N-by-1 array, where N is the
            %                                    number of UEs. Each
            %                                    element contains the
            %                                    number of erroneous
            %                                    packets in the uplink
            %  Number of Packets(UL)           - N-by-1 array, where N is the
            %                                    number of UEs. Each
            %                                    element contains the
            %                                    number of packets in the uplink

            headings = {'Frame number', 'Slot number', 'Number of Erroneous Packets(DL)',...
                'Number of Packets(DL)', 'Number of Erroneous Packets(UL)', 'Number of Packets(UL)'};
            % Most recent log index for the current simulation
            lastLogIndex = obj.CurrFrame * obj.NumSlotsFrame + obj.CurrSlot + 1;
            totalULPackets = zeros(obj.NumUEs, 1);
            totalErrULPackets = zeros(obj.NumUEs, 1);
            totalDLPackets = zeros(obj.NumUEs, 1);
            totalErrDLPackets = zeros(obj.NumUEs, 1);

            % Calculate statistics for the entire simulation
            for idx = 1:lastLogIndex
                totalErrDLPackets = totalErrDLPackets + obj.BLERStatsLog{idx, 3};
                totalDLPackets = totalDLPackets + obj.BLERStatsLog{idx, 4};
                totalErrULPackets = totalErrULPackets + obj.BLERStatsLog{idx, 5};
                totalULPackets = totalULPackets + obj.BLERStatsLog{idx, 6};
            end

            % Update lastLogIndex value
            lastLogIndex = lastLogIndex + 1;
            % Update last row of BLERStatsLog
            if ismember(obj.DownlinkIdx, obj.PlotIds) % Downlink
                obj.BLERStatsLog{lastLogIndex, 3} = totalErrDLPackets./totalDLPackets;
            end
            if ismember(obj.UplinkIdx, obj.PlotIds) % Uplink
                obj.BLERStatsLog{lastLogIndex, 5} = totalErrULPackets./totalULPackets;
            end
            blerLogs = [headings; obj.BLERStatsLog(1:lastLogIndex , :)];
        end
    end

    methods(Access = private)
        function createPlots(obj, plotId)
            %createPlots Create plots for downlink/uplink

            obj.BLERPlotHandles(:, plotId) = plot(obj.PlotHandle{plotId}, zeros(obj.NumMetricsSteps+1, obj.NumUEs),...
                'Tag', obj.PlotDescription{plotId});
            legend(obj.PlotHandle{plotId}, obj.UELegends);
            ylabel(obj.PlotHandle{plotId}, obj.PlotDescription{plotId});
            xlabel(obj.PlotHandle{plotId},['Simulation Time (1 unit = ', num2str(obj.MetricsStepDuration), ' ms)']);
            xlim(obj.PlotHandle{plotId},[0 obj.NumMetricsSteps]);
            grid(obj.PlotHandle{plotId}, 'on');
        end
    end
end