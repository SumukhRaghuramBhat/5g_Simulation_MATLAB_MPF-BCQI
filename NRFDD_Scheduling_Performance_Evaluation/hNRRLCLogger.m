classdef hNRRLCLogger < handle
%hNRRLCLogger RLC logging and visualization
%   The class implements per slot logging mechanism as well as
%   visualization of the RLC logs. Visualization shows the RLC throughput
%   of the logical channels of the UEs.

%   Copyright 2019-2020 The MathWorks, Inc.

    properties
        %NCellID Cell id to which the logging and visualization object belongs
        NCellID (1, 1) {mustBeInteger, mustBeInRange(NCellID, 0, 1007)} = 1;

        % NumUEs Count of UEs
        NumUEs

        % Metrics Timestamped RLC throughput metrics for each UE
        % Store UE metrics in a cell array of tables. Each table
        % holds simulation metrics of one UE. Each row of the table has
        % information of a metrics step and has these columns: timestamp,
        % throughput
        Metrics

        % ThroughputPlotHandles N-by-2 matrix of throughput plot handles
        % Here N represent maximum number of logical channels of a UE, and
        % column 1, 2 represent the metric plots handles in downlink and
        % uplink respectively
        ThroughputPlotHandles

        % NumSlotsFrame Number of slots in 10ms time frame
        NumSlotsFrame

        % RLCStatsLog Slot-by-slot log of the RLC statistics
        RLCStatsLog

        % SelectedUE UE selected for visualizing the RLC throughput
        % The default value is 1
        SelectedUE = 1
    end

    properties(Access = private)
        % CurrSlot Current slot in the frame
        CurrSlot = -1

        % CurrFrame Current frame
        CurrFrame = -1

        % LcidList List of LCIDs of each UE
        LcidList

        % PlotDesc Description of the plot
        PlotDesc

        % UELegend Legend for the UE
        UELegend

        % NumMetricsSteps Number of times metrics plots are updated
        NumMetricsSteps

        % PlotIds Plot Ids
        PlotIds

        % FinalUERLCStats Cumulative statistics of RLC layer at UE for the
        % entire simulation
        FinalUERLCStats

        % FinalgNBRLCStats Cumulative statistics of RLC layer at gNB for
        % the entire simulation
        FinalgNBRLCStats

        % RLCVisualizationFigHandle Handle to display UE RLC layer's
        % logical channel throughput
        RLCVisualizationFigHandle

        % PlotHandle RLC throughput handle for downlink and uplink
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
        % NumLogicalChannels Maximum number of logical channels
        NumLogicalChannels = 32;

        % Constants related to downlink and uplink information. These
        % constants are used for indexing logs and identifying plots
        % DownlinkIdx Index for all downlink information
        DownlinkIdx = 1;
        % UplinkIdx Index for all uplink information
        UplinkIdx = 2;

        % RLCStatsTitles Title for the columns of RLC statistics
        RLCStatsTitles = {'RNTI', 'LCID', 'TxDataPDU', 'TxDataBytes', ...
                'ReTxDataPDU', 'ReTxDataBytes' 'TxControlPDU', ...
                'TxControlBytes', 'TxPacketsDropped', 'TxBytesDropped', ...
                'TimerPollRetransmitTimedOut', 'RxDataPDU', ...
                'RxDataPDUBytes', 'RxDataPDUDropped', 'RxDataBytesDropped', ...
                'RxDataPDUDuplicate', 'RxDataBytesDuplicate', ...
                'RxControlPDU', 'RxControlBytes', ...
                'TimerReassemblyTimedOut', 'TimerStatusProhibitTimedOut'};
    end

    methods (Access = public)
        function obj = hNRRLCLogger(simParameters, lchInfo, varargin)
            %hNRRLCLogger Construct RLC log and visualization object
            %
            % OBJ = hNRRLCLogger(SIMPARAMETERS, LCHINFO) Create an RLC logging and
            % throughput visualization object. It creates figures for
            % visualizing throughput in both downlink and uplink.
            %
            % OBJ = hNRRLCLogger(SIMPARAMETERS, LCHINFO, FLAG) Create an RLC logging and
            % throughput visualization object.
            %
            % SIMPARAMETERS - It is a structure and contain simulation
            % configuration information.
            %
            % NumUEs            - Number of UEs
            % NCellID           - Cell identifier
            % SCS               - Subcarrier spacing
            % NumMetricsSteps   - Number of times metrics plots to be
            %                     updated
            % MetricsStepSize   - Interval at which metrics visualization
            %                     updates in terms of number of slots
            %
            % LCHINFO - It is an array of structures and contains following
            % fields.
            %    LCID - Specifies the logical channel id of an UE
            %    EntityDir - Specifies the logical channel type
            %    corresponding to the logical channel specified in LCID
            %    If EntityDir = 0, Represents the logical channel in
            %    downlink direction
            %    If EntityDir = 1, Represents the logical channel in uplink
            %    direction
            %    If EntityDir = 2, Represents the logical channel in both
            %    downlink & uplink direction
            %
            % If FLAG = 0, Visualize downlink throughput.
            % If FLAG = 1, Visualize uplink throughput.

            if isfield(simParameters , 'NCellID')
                obj.NCellID = simParameters.NCellID;
            end
            obj.NumUEs = simParameters.NumUEs;
            obj.NumSlotsFrame = (10 * simParameters.SCS) / 15; % Number of slots in a 10 ms frame
            obj.NumMetricsSteps = simParameters.NumMetricsSteps;
            % Interval at which metrics visualization updates in terms of number of
            % slots. Make sure that MetricsStepSize is an integer
            obj.MetricsStepSize = simParameters.MetricsStepSize;
            obj.MetricsStepDuration = obj.MetricsStepSize * (15 / simParameters.SCS);
            % One is added to numMetricSteps as X-axis of performance plots starts from zero
            timestamp = zeros(obj.NumMetricsSteps + 1, 1);
            throughput = zeros(obj.NumMetricsSteps + 1, obj.NumLogicalChannels);
            % Initialize cell array of UE metrics. One cell element per UE. Each cell
            % element is a table of timestamped metrics.
            obj.LcidList = cell(obj.NumUEs, 2);
            obj.ThroughputPlotHandles = zeros(obj.NumLogicalChannels, 2); % Plot handles

            numRows = 0; % Number of rows to create in logs
            for ueIdx = 1:obj.NumUEs
                % Logical channels in downlink
                dlIdx = sort([find(lchInfo(ueIdx).EntityDir == 0); find(lchInfo(ueIdx).EntityDir == 2)]);
                dlLogicalChannels = lchInfo(ueIdx).LCID(dlIdx);
                obj.LcidList{ueIdx, obj.DownlinkIdx} = dlLogicalChannels;
                obj.PlotDesc{obj.DownlinkIdx} = 'Downlink RLC Throughput (Mbps)';
                % Logical channels in uplink
                ulIdx = sort([find(lchInfo(ueIdx).EntityDir == 1); find(lchInfo(ueIdx).EntityDir == 2)]);
                ulLogicalChannels = lchInfo(ueIdx).LCID(ulIdx);
                obj.LcidList{ueIdx, obj.UplinkIdx} = ulLogicalChannels;
                obj.PlotDesc{obj.UplinkIdx} = 'Uplink RLC Throughput (Mbps)';
                % Update the numRows based on logical channel
                % configurations
                numRows = numRows + numel(union(dlLogicalChannels, ulLogicalChannels));
            end

            % RLC Stats
            % Each row represents the statistics of each slot and last row
            % of the log represents the cumulative statistics of the entire
            % simulation
            obj.RLCStatsLog = cell((simParameters.NumFramesSim * obj.NumSlotsFrame) + 1, 4);
            obj.RLCStatsLog{1, 1} = 0; % Frame number
            obj.RLCStatsLog{1, 2} = 0; % Slot number
            obj.RLCStatsLog{1, 3} = cell(1, 1); % UE RLC stats
            obj.RLCStatsLog{1, 4} = cell(1, 1); % gNB RLC stats

            % Initialize the cumulative statistics of UE and gNB
            obj.FinalUERLCStats = zeros(numRows, numel(obj.RLCStatsTitles));
            obj.FinalgNBRLCStats = zeros(numRows, numel(obj.RLCStatsTitles));
            idx = 1; % To index the number of rows created in logs
            for ueIdx = 1:obj.NumUEs
                % Determine the active logical channel ids
                activeLCHIds = sort(union(obj.LcidList{ueIdx, 1}, obj.LcidList{ueIdx, 2}));
                activeLCHCount = numel(activeLCHIds);
                for lcidx =1:activeLCHCount
                    % Update the statistics with RNTI and LCID
                    obj.FinalUERLCStats(idx, 1) = ueIdx;
                    obj.FinalUERLCStats(idx, 2) = activeLCHIds(lcidx);
                    obj.FinalgNBRLCStats(idx, 1) = ueIdx;
                    obj.FinalgNBRLCStats(idx, 2) = activeLCHIds(lcidx);
                    idx = idx + 1;
                end
            end
            
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

                % Initialize metrics
                obj.Metrics = cell(obj.NumUEs, 2);
                for idx = 1:numel(obj.PlotIds)
                    plotId = obj.PlotIds(idx);
                    for ueIdx = 1 : obj.NumUEs
                        obj.Metrics{ueIdx, plotId} = table(timestamp, throughput);
                    end
                end
                
                % Using the screen width and height, calculate figure width and
                % height
                resolution = get(0,'ScreenSize');
                screenWidth = resolution(3);
                screenHeight = resolution(4);
                figureWidth = screenWidth * 0.90;
                figureHeight = screenHeight * 0.85;

                % Create the figure for CQI Visualization
                obj.RLCVisualizationFigHandle = figure('Name', 'RLC Throughput Visualization', 'Position', [screenWidth*0.05 screenHeight*0.05 figureWidth figureHeight]);
                % Coordinates for UI control elements displayed in the figure
                xCoordinate = 0.015;
                yCoordinate = 0.75;

                % Create the items for the drop-down component with the UEs as
                % selectable items
                itemList = cell(obj.NumUEs, 1);
                for ueIdx = 1 : obj.NumUEs
                    itemList{ueIdx} = [' UE - ', num2str(ueIdx)];
                end

                % Create legend for the logical channels
                obj.UELegend = cell(obj.NumLogicalChannels, 1);
                for lcIdx = 1:obj.NumLogicalChannels
                    obj.UELegend{lcIdx,1} = strcat("Logical Channel ", num2str(lcIdx));
                end

                % Create drop-down component for UE display range selection
                uicontrol(obj.RLCVisualizationFigHandle, 'Style', 'text', 'Units', 'normalized', 'Position', [xCoordinate yCoordinate 0.06 0.025], 'String', 'Select UE', 'FontSize', 10, 'HorizontalAlignment', 'left', 'FontUnits', 'normalized');
                uicontrol(obj.RLCVisualizationFigHandle, 'Style', 'popupmenu', 'Units', 'normalized', 'Position', [xCoordinate+0.060 yCoordinate 0.06 0.025], 'String', itemList, 'Callback', @(dd, event) cbSelectedUE(obj, dd));

                if numel(obj.PlotIds) == 2
                    plotHandleDL = subplot(2, 1, 2, 'Tag', obj.PlotDesc{obj.DownlinkIdx});
                    plotHandleDL.Position = [0.2294 0.0990 0.5700 0.3500]; % Downlink plot
                    obj.PlotHandle{obj.DownlinkIdx} = plotHandleDL;
                    createPlots(obj, obj.DownlinkIdx);
                    plotHandleUL = subplot(2, 1, 1, 'Tag', obj.PlotDesc{obj.UplinkIdx}); % Uplink plot
                    plotHandleUL.Position = [0.2294 0.5590 0.5700 0.35000];
                    obj.PlotHandle{obj.UplinkIdx} = plotHandleUL;
                    createPlots(obj, obj.UplinkIdx);
                    sgtitle(strcat("RLC Throughput Visualization for Cell ID - ", num2str(obj.NCellID)), 'FontWeight', 'Bold', 'FontName', 'Arial', 'FontSize', 15, 'FontUnits', 'normalized');
                else
                    plotHandle = gca;
                    set(plotHandle, 'Units', 'Pixels', 'Position', [figureWidth * 0.23 figureHeight * 0.1 figureWidth * 0.67 figureHeight * 0.8], 'Units', 'normalized');
                    hold on;
                    title(strcat("RLC Throughput Visualization for Cell ID - ", num2str(obj.NCellID)), 'FontSize', 15,'FontUnits', 'normalized', 'Position', [0.5 1.04 0], 'Units', 'normalized');
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
            %plotMetrics Plot the RLC throughput metrics
            %
            % plotMetrics(OBJ) Calculate and stores the throughput of
            % each logical channel of each UE and updates the plot

            % Check whether 'RLC Throughput Visualization' figure exists
            if isempty(findobj(obj.RLCVisualizationFigHandle, 'Name', 'RLC Throughput Visualization'))
                return;
            end

            obj.MetricsStepIndex = obj.MetricsStepIndex + 1;
            % Calculate metrics from logs of the slot in last step
            stepLogStartIdx = (obj.MetricsStepIndex-1) * obj.MetricsStepSize + 1;
            stepLogEndIdx = (obj.MetricsStepIndex) * obj.MetricsStepSize;
            logIdx = [4 3]; % Indices of gNB and UE RLC statistics
            numRows = [size(obj.FinalgNBRLCStats, 1); size(obj.FinalUERLCStats, 1)];
            for idx = 1:numel(obj.PlotIds)
                plotId = obj.PlotIds(idx);
                % Among the statistics first two columns will represent
                % RNTI and LCID. The remaining statistics will be updated
                % periodically.
                rlcStats = zeros(numRows(plotId), numel(obj.RLCStatsTitles));

                % Get the statistics of the row, including RNTI and
                % LCID columns
                slotLog = obj.RLCStatsLog(stepLogStartIdx, :);
                rlcStats = rlcStats + cell2mat(slotLog{logIdx(plotId)}(2:end, :));
                for i = stepLogStartIdx+1:stepLogEndIdx
                    slotLog = obj.RLCStatsLog(i, :);
                    % Get the statistics of the row, excluding RNTI and
                    % LCID columns
                    rlcStats(:, 3:end) = rlcStats(:, 3:end) + cell2mat(slotLog{logIdx(plotId)}(2:end,3:end));
                end

                % Throughput calculation and plotting: Throughput is the rate
                % (Mbps) at which data at RLC is sent to the MAC
                for ueIdx = 1:obj.NumUEs
                    numActiveLogicalChannels = numel(obj.LcidList{ueIdx, plotId});
                    for lcIdx = 1 : numActiveLogicalChannels
                        lcid = obj.LcidList{ueIdx, plotId}(lcIdx);
                        rowIdx = (rlcStats(:, 1) == ueIdx & rlcStats(:, 2) == lcid);
                        obj.Metrics{ueIdx, plotId}.timestamp(obj.MetricsStepIndex) = ...
                            (obj.MetricsStepIndex * obj.MetricsStepDuration ) / 1000;
                        % Calculating throughput based on number of RLC PDU
                        % bytes transmitted
                        throughputServed = rlcStats(rowIdx, 4) * 8 / (obj.MetricsStepDuration * 1000);
                        obj.Metrics{ueIdx, plotId}.throughput(obj.MetricsStepIndex+1, lcid) = throughputServed;
                    end
                end
                updateMetrics(obj, plotId);
            end
        end

        function updateMetrics(obj, plotId)
            %updateMetrics Update the UE metrics

            %  Updates the plot according to the UE selected in the
            %  drop-down
            numActiveLogicalChannels = numel(obj.LcidList{obj.SelectedUE, plotId});
            for lcIdx = 1 : numActiveLogicalChannels
                lcid = obj.LcidList{obj.SelectedUE, plotId}(lcIdx);
                set(obj.ThroughputPlotHandles(lcid, plotId), 'Xdata', (0 : obj.MetricsStepIndex), 'Ydata',...
                    obj.Metrics{obj.SelectedUE, plotId}.throughput(1 : obj.MetricsStepIndex+1, lcid));
            end
        end

        function logRLCStats(obj, ueRLCStats, gNBRLCStats)
             %logRLCStats Log the RLC statistics
             %
             % logRLCStats(OBJ, UERLCSTATS, GNBRLCSTATS) Logs the RLC
             % statistics
             %
             % UERLCSTATS - Represents a N-by-1 cell, where N is the number
             % of UEs. Each element of the cell is  a P-by-Q matrix, where
             % P is the number of logical channels, and Q is the number of
             % statistics collected. Each row represents statistics of a
             % logical channel.
             %
             % GNBRLCSTATS - Represents a N-by-1 cell, where N is the number
             % of UEs. Each element of the cell is  a P-by-Q matrix, where
             % P is the number of logical channels, and Q is the number of
             % statistics collected. Each row represents statistics of a
             % logical channel of a UE at gNB.

             % Move to the next slot
             obj.CurrSlot = mod(obj.CurrSlot + 1, obj.NumSlotsFrame);
             if(obj.CurrSlot == 0)
                 obj.CurrFrame = obj.CurrFrame + 1; % Next frame
             end
             logIndex = obj.CurrFrame * obj.NumSlotsFrame + obj.CurrSlot + 1;
             obj.RLCStatsLog{logIndex, 1} = obj.CurrFrame;
             obj.RLCStatsLog{logIndex, 2} = obj.CurrSlot;
             currUEStats = vertcat(ueRLCStats{:});
             currgNBStats = vertcat(gNBRLCStats{:});
             % Current cumulative statistics
             obj.FinalUERLCStats(:,3:end) = currUEStats(:,3:end) + obj.FinalUERLCStats(:,3:end);
             obj.FinalgNBRLCStats(:,3:end) = currgNBStats(:,3:end) + obj.FinalgNBRLCStats(:,3:end);
             % Add column titles for the current slot statistics
            obj.RLCStatsLog{logIndex, 3} = vertcat(obj.RLCStatsTitles, num2cell(currUEStats));
            obj.RLCStatsLog{logIndex, 4} = vertcat(obj.RLCStatsTitles, num2cell(currgNBStats));
        end

        function rlcLogs = getRLCLogs(obj)
            %GETRLCLOGS Return the per slot logs
            %
            % RLCLOGS = getRLCLogs(OBJ) Returns the RLC logs
            %
            % RLCLOGS - It is (N+2)-by-P cell, where N represents the
            % number of slots in the simulation and P represents the number
            % of columns. The first row of the logs contains titles for the
            % logs. The last row of the logs contains the cumulative
            % statistics for the entire simulation. Each row (excluding
            % first and last rows) in the logs represents a slot and
            % contains the following information.
            %   Frame - Frame number.
            %   Slot - Slot number in the frame.
            %   UE RLC statistics - N-by-P cell, where N is the product of
            %                       number of UEs and number of logical
            %                       channels, and P is the number of
            %                       statistics collected. Each row
            %                       represents statistics of a logical
            %                       channel in a UE.
            %   gNB RLC statistics - N-by-P cell, where N is the product of
            %                      number of UEs and number of logical
            %                      channels, and P is the number of
            %                      statistics collected. Each row
            %                      represents statistics of a logical
            %                      channel of a UE at gNB.

            headings = {'Frame number', 'Slot number', 'UE RLC statistics', 'gNB RLC statistics'};
            % Most recent log index for the current simulation
            lastLogIndex = obj.CurrFrame * obj.NumSlotsFrame + obj.CurrSlot + 1;
            % Create a row at the end of the to store the cumulative statistics of the UE
            % and gNB at the end of the simulation
            lastLogIndex = lastLogIndex + 1;
            obj.RLCStatsLog{lastLogIndex, 3} = vertcat(obj.RLCStatsTitles, num2cell(obj.FinalUERLCStats));
            obj.RLCStatsLog{lastLogIndex, 4} = vertcat(obj.RLCStatsTitles, num2cell(obj.FinalgNBRLCStats));
            rlcLogs = [headings; obj.RLCStatsLog(1:lastLogIndex, :)];
        end
    end

    methods(Access = private)
        function cbSelectedUE(obj, dd)
            %cbSelectedUE Handle the event when user selects UE in RLC visualization

            % Clear previous messages on the plot
            delete(findall(obj.RLCVisualizationFigHandle, 'type', 'annotation'))
            prevSelecteUE = obj.SelectedUE;
            obj.SelectedUE = dd.Value;
            for idx = 1:numel(obj.PlotIds)
                plotId = obj.PlotIds(idx);
                if numel(obj.LcidList{prevSelecteUE, plotId}) ~= 0
                    % Clear previous plot handles
                    delete(obj.ThroughputPlotHandles(:, plotId));
                    % Reset the color order index
                    hAx = get(obj.RLCVisualizationFigHandle, 'CurrentAxes');
                    hAx.ColorOrderIndex = 1;
                end
                obj.ThroughputPlotHandles(:, plotId) = zeros(obj.NumLogicalChannels, 1);
                % Plot the RLC throughput of the selected UE
                createPlots(obj, plotId)
                updateMetrics(obj, plotId);
            end
        end

        function createPlots(obj, plotId)
            %createPlots Create plots for downlink/uplink

            obj.ThroughputPlotHandles(obj.LcidList{obj.SelectedUE,plotId}, plotId) = plot(obj.PlotHandle{plotId}, zeros(obj.NumMetricsSteps+1, numel(obj.LcidList{obj.SelectedUE, plotId})), 'Tag', obj.PlotDesc{plotId});
            legend(obj.PlotHandle{plotId}, obj.UELegend{obj.LcidList{obj.SelectedUE, plotId}});
            ylabel(obj.PlotHandle{plotId}, obj.PlotDesc{plotId});

            if numel(obj.LcidList{obj.SelectedUE, plotId}) == 0
                % Display a message
                annotation('textbox',obj.PlotHandle{plotId}.Position,'String','No active logical channels','FitBoxToText','on');
            end
            xlabel(obj.PlotHandle{plotId},['Simulation Time (1 unit = ', num2str(obj.MetricsStepDuration), ' ms)']);
            xlim(obj.PlotHandle{plotId},[0 obj.NumMetricsSteps]);
            grid(obj.PlotHandle{plotId}, 'on');
        end
    end
end
