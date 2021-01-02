% Post-simulation visualization of logs using MAT files containing
% parameters used for simulation run and the logs of simulation

% Copyright 2020 The MathWorks, Inc.

% Configuration
parametersFile = 'simParameters.mat'; % Simulation parameters file name
simulationLogFile = 'simulationLogs.mat'; % Simulation logs file name
cellId = 1; % Cell id
% Flag to indicate the type of visualization
% For DL only (visualizationFlag = 0), UL only (visualizationFlag = 1), and
% both UL and DL (visualizationFlag = 2)
visualizationFlag = 2; % Both DL and UL visualization
% Set this flag to true for replay of simulation logs. Set this flag to
% false, to analyze the details of a particular frame or a particular slot
% of a frame. In the 'Resource Grid Allocation' window, input the frame
% number to visualize the scheduling assignment for the entire frame. The
% frame number entered here controls the frame number for 'Channel Quality
% Visualization' figure too.
isLogReplay = false;

% Validate the inputs
if ~isfile(parametersFile) % Check presence of simulation parameters file
    error('nr5g:NRPostSimVisualization:couldNotReadFile', 'Unable to read file %s . No such file or directory.', parametersFile);
end

if ~isfile(simulationLogFile) % Check presence of simulation log file
    error('nr5g:NRPostSimVisualization:couldNotReadFile', 'Unable to read file %s . No such file or directory.', simulationLogFile);
end

% Validate cell id
validateattributes(cellId, {'numeric'}, {'nonempty', 'integer', 'scalar', '>=', 0, '<=', 1007}, 'cellId');

% Validate visualization flag
validateattributes(visualizationFlag, {'numeric'}, {'nonempty', 'integer', 'scalar', '>=', 0, '<=', 2}, 'visualizationFlag');


% Read simulation parameters
simParameters = load(parametersFile).simParameters;

% Flag to enable or disable channel quality information (CQI) visualization
simParameters.CQIVisualization = true;
% Flag to enable or disable visualization of resource block (RB)
% assignment. If enabled, then for slot based scheduling it shows RB
% allocation to the UEs for different slots of the frame. For symbol
% based scheduling, it shows RB allocation to the UEs over different
% symbols of the slot.
simParameters.RBVisualization = true;

if isfield(simParameters, 'NumCells')
    numCells = simParameters.NumCells;
    if isfield(simParameters, 'NCellIDList') && ~ismember(cellId, simParameters.NCellIDList)
        error('nr5g:NRPostSimVisualization:InvalidCellId', 'Invalid cell id (%d).', cellId);
    end
else
    numCells = 1;
    if isfield(simParameters, 'NCellID')
        if cellId ~= simParameters.NCellID
            error('nr5g:NRPostSimVisualization:InvalidCellId', 'Invalid cell id (%d).', cellId);
        end
    end
end

% Check the visualization flag for TDD
if isfield(simParameters, 'SchedulingType') && simParameters.SchedulingType && visualizationFlag ~= 2
    error('nr5g:NRPostSimVisualization:InvalidFlag', 'Flag value must be 2 for TDD');
end

simParameters.CellOfInterest = cellId;
simParameters.NCellID = cellId;

simLoggerObj = cell(3, 1); % Contains the list of logging and visualization objects created
count = 0;

% Read simulation log of cell of interest
simulationLogsInfo = load(simulationLogFile).simulationLogs;
for cellIdx = 1:numCells
    if isfield(simulationLogsInfo{cellIdx}, 'NCellID') && simulationLogsInfo{cellIdx}.NCellID == cellId
        break;
    end
end

logInfo = simulationLogsInfo{cellIdx};

% Time step logs
if isfield(logInfo, 'TimeStepLogs') || isfield(logInfo, 'DLTimeStepLogs') || isfield(logInfo, 'ULTimeStepLogs')
    count = count + 1;
    simLoggerObj{count} = hNRSchedulingLogger(simParameters, visualizationFlag, isLogReplay);
    if simLoggerObj{count}.DuplexMode % For TDD
        simLoggerObj{count}.SchedulingLog{1} = logInfo.TimeStepLogs(2:end,:); % MAC scheduling log
    else
        if visualizationFlag == 0 || visualizationFlag == 2 % Read downlink logs
            simLoggerObj{count}.SchedulingLog{1} = logInfo.DLTimeStepLogs(2:end,:); % MAC DL scheduling log
        end
        
        if visualizationFlag == 1 || visualizationFlag == 2 % Read uplink logs
            simLoggerObj{count}.SchedulingLog{2} = logInfo.ULTimeStepLogs(2:end,:); % MAC UL scheduling log
        end
    end
end

% Radio link control (RLC) logs
if isfield(logInfo, 'RLCLogs')
    count = count + 1;
    % Construct information for RLC logger
    lchInfo = repmat(struct('LCID',[],'EntityDir',[]), [simParameters.NumUEs 1]);
    for ueIdx = 1:simParameters.NumUEs
        % Find the RLC entity direction from the RLC entity type. The entity
        % direction values 0, 1, and 2 indicates downlink only, uplink only,
        % and both, respectively. The RLC UM entities uses the same values for
        % entity type. But, RLC AM uses value 3 to indicate entity type. So, it
        % needs to be altered to 2 to represent its direction
        if isfield(simParameters, 'LCHConfig')
            lchInfo(ueIdx).LCID = simParameters.LCHConfig.LCID(ueIdx, :);
            lchInfo(ueIdx).EntityDir = simParameters.RLCConfig.EntityDir(ueIdx, :);
        else
            lchInfo(ueIdx).LCID = simParameters.RLCChannelConfig.LogicalChannelID(simParameters.RLCChannelConfig.RNTI == ueIdx);
            lchInfo(ueIdx).EntityDir = simParameters.RLCChannelConfig.EntityType(simParameters.RLCChannelConfig.RNTI == ueIdx);
        end
        lchInfo(ueIdx).EntityDir(lchInfo(ueIdx).EntityDir == 3) = 2;
    end
    simLoggerObj{count} = hNRRLCLogger(simParameters, lchInfo, visualizationFlag);
    simLoggerObj{count}.RLCStatsLog = logInfo.RLCLogs(2:end,:); % RLC log
end

% Physical layer (Phy) logs
if isfield(logInfo, 'BLERLogs')
    count = count + 1;
    simLoggerObj{count} = hNRPhyLogger(simParameters, visualizationFlag);
    simLoggerObj{count}.BLERStatsLog = logInfo.BLERLogs(2:end,:); % BLERstatistics log
end

numSlotsFrame = (10 * simParameters.SCS)/ 15; % Number of slots in a 10 ms frame
simDuration = simParameters.NumFramesSim * numSlotsFrame; % In terms of number of slots
for slotNum = 1:simDuration % For each frame of simulation log
    if isfield(logInfo, 'TimeStepLogs') || isfield(logInfo, 'DLTimeStepLogs') || isfield(logInfo, 'ULTimeStepLogs')
        if isLogReplay
            if isfield(simParameters, 'SchedulingType') && simParameters.SchedulingType
                % Symbol based scheduling
                plotPostSimRBGrids(simLoggerObj{1}, slotNum); % Plot RB-assignment grid and RB-CQI grid
            else
                % Slot based scheduling
                if ~mod(slotNum, numSlotsFrame) % Last slot of the frame
                    plotPostSimRBGrids(simLoggerObj{1}, slotNum); % Plot RB-assignment grid and RB-CQI grid
                end
            end
        end
    end
    if mod(slotNum, simParameters.MetricsStepSize) == 0
        for idx = 1:count
            plotMetrics(simLoggerObj{idx}); % Plot the metrics
        end
    end
end