rng('default'); % Reset the random number generator
simParameters = []; % Clear the simulation parameters

simParameters.NumFramesSim = 100; % Simulation time in terms of number of 10 ms frames
% Number of UEs in the simulation. UEs are assumed to have sequential radio
% network temporary identifiers (RNTIs) from 1 to NumUEs. If you change the
% number of UEs, ensure that the length of simParameters.UEDistance is equal to NumUEs
simParameters.NumUEs = 4;
simParameters.UEDistance = [100 250 700 750]; % Distance of UEs from gNB (in meters)

% Set the channel bandwidth to 30 MHz and subcarrier spacing (SCS) to 15
% kHz as defined in 3GPP TS 38.104 Section 5.3.2. The complete UL and
% DL bandwidth is assumed to be allotted for PUSCH and PDSCH. The
% UL and DL carriers are assumed to have symmetric channel
% bandwidth
simParameters.DLBandwidth = 30e6; % Hz
simParameters.ULBandwidth = 30e6; % Hz
simParameters.NumRBs = 160;
simParameters.SCS = 15; % kHz
simParameters.DLCarrierFreq = 2.635e9; % Hz
simParameters.ULCarrierFreq = 2.515e9; % Hz

% Configure parameters to update UL channel quality at gNB and DL
% channel quality at gNB and UE. Channel conditions are periodically
% improved or deteriorated by CQIDelta every channelUpdatePeriodicity
% seconds for all RBs of a UE. Whether channel conditions for a particular
% UE improve or deteriorate is randomly determined
% RBCQI = RBCQI +/- CQIDelta
simParameters.ChannelUpdatePeriodicity = 0.2; % In sec
simParameters.CQIDelta = 2;
% Mapping between distance from gNB (first column in meters) and maximum
% achievable UL CQI value (second column). For example, if a UE is 700
% meters away from the gNB, it can achieve a maximum CQI value of 10 as the
% distance falls within the [501, 800] meters range, as per the mapping.
% Set the distance in increasing order and the maximum achievable CQI value in
% decreasing order
simParameters.CQIvsDistance = [
    200  15;
    500  12;
    800  10;
    1000  8;
    1200  7];

simParameters.BSRPeriodicity = 5; % In ms
simParameters.EnableHARQ = true; % Flag to enable or disable HARQ. If disabled, there are no retransmissions
simParameters.NumHARQ = 16; % Number of HARQ processes

% Set the scheduler run periodicity in terms of number of slots. Value must
% be less than the number of slots in a 10 ms frame
simParameters.SchedulerPeriodicity = 4;
simParameters.SchedulerStrategy = 'PF'; % Supported scheduling strategies: 'PF', 'RR' and 'BestCQI'
% Moving average parameter within the range [0, 1] to calculate average
% data rate for a UE in UL and DL directions. This value is used in
% the PF scheduling strategy. Parameter value closer to 1 implies more
% weight on the instantaneous data rate. Parameter value closer to 0
% implies more weight on the past data rate
% AverageDataRate = ((1 - MovingAvgDataRateWeight) * PastDataRate) + (MovingAvgDataRateWeight * InstantaneousDataRate)
simParameters.MovingAvgDataRateWeight = 0.5;
% gNB ensures that PUSCH assignment is received at UEs PUSCHPrepTime ahead
% of the transmission time
simParameters.PUSCHPrepTime = 200; % In microseconds
% Maximum RBs allotted to a UE in a slot for the UL and DL
% transmission (limit is applicable for new PUSCH and PDSCH assignments and
% not for the retransmissions)
simParameters.RBAllocationLimitUL = 100; % For PUSCH
simParameters.RBAllocationLimitDL = 100; % For PDSCH

load('NRFDDRLCChannelConfig.mat')
simParameters.RLCChannelConfig = RLCChannelConfig;

load('NRFDDAppConfig.mat');
simParameters.AppConfig = AppConfig;

% The parameters CQIVisualization and RBVisualization control the display
% of these visualizations: (i) CQI visualization of RBs (ii) RB assignment
% visualization. By default, these plots are disabled. You can enable them
% by setting to 'true'
simParameters.CQIVisualization = false;
simParameters.RBVisualization = false;
% The output metrics plots are updated periodically NumMetricsSteps times within the
% simulation duration
simParameters.NumMetricsSteps = 20;
% MAT-files to write the logs into. They are used for post simulation analysis and visualization
simParameters.ParametersLogFile = 'simParameters'; % For logging the simulation parameters
simParameters.SimulationLogFile = 'simulationLogs'; % For logging the simulation logs

% Validate the simulation configuration
hNRSchedulingFDDValidateConfig(simParameters);

simParameters.DuplexMode = 0; % FDD
% Size of sub-band for CQI reporting in terms of number of RBs (Only used
% when 5G Toolbox™ PHY layer processing is enabled)
simParameters.SubbandSize = 16;
simParameters.NumCells = 1; % Number of cells
simParameters.NCellID = 1; % Physical cell ID
simParameters.GNBPosition = [0 0 0]; % Position of gNB in (x,y,z) coordinates
% Slot duration for the selected SCS and number of slots in a 10 ms frame
slotDuration = 1/(simParameters.SCS/15); % In ms
numSlotsFrame = 10/slotDuration; % Number of slots in a 10 ms frame
numSlotsSim = simParameters.NumFramesSim * numSlotsFrame; % Number of slots in the simulation

% Calculate maximum achievable CQI value for the UEs based on their distance from
% the gNB
maxUECQIs = zeros(simParameters.NumUEs, 1); % To store the maximum achievable CQI value for UEs
for ueIdx = 1:simParameters.NumUEs
    % Based on the distance of the UE from gNB, find matching row in
    % CQIvsDistance mapping
    matchingRowIdx = find(simParameters.CQIvsDistance(:, 1) > simParameters.UEDistance(ueIdx));
    if isempty(matchingRowIdx)
        maxUECQIs(ueIdx) = simParameters.CQIvsDistance(end, 2);
    else
        maxUECQIs(ueIdx) = simParameters.CQIvsDistance(matchingRowIdx(1), 2);
    end
end

% Interval at which metrics visualization updates in terms of number of
% slots. As one slot is the finest time-granularity of the simulation, make
% sure that MetricsStepSize is an integer
simParameters.MetricsStepSize = ceil(numSlotsSim / simParameters.NumMetricsSteps);
if mod(numSlotsSim, simParameters.NumMetricsSteps) ~= 0
    % Update the NumMetricsSteps parameter if NumSlotsSim is not
    % completely divisible by it
    simParameters.NumMetricsSteps = floor(numSlotsSim / simParameters.MetricsStepSize);
end

% Define initial UL and DL channel quality as an N-by-P matrix,
% where 'N' is the number of UEs and 'P' is the number of RBs in the carrier
% bandwidth. The initial value of CQI for each RB, for each UE, is given
% randomly and is limited by the maximum achievable CQI value corresponding
% to the distance of the UE from gNB
simParameters.InitialChannelQualityUL = zeros(simParameters.NumUEs, simParameters.NumRBs); % To store current UL CQI values on the RBs for different UEs
simParameters.InitialChannelQualityDL = zeros(simParameters.NumUEs, simParameters.NumRBs); % To store current DL CQI values on the RBs for different UEs
for ueIdx = 1:simParameters.NumUEs
    % Assign random CQI values for the RBs, limited by the maximum achievable CQI value
    simParameters.InitialChannelQualityUL(ueIdx, :) = randi([1 maxUECQIs(ueIdx)], 1, simParameters.NumRBs);
    % Initially, DL and UL CQI values are assumed to be equal
    simParameters.InitialChannelQualityDL(ueIdx, :) = simParameters.InitialChannelQualityUL(ueIdx, :);
end

simParameters.Position = simParameters.GNBPosition;
gNB = hNRGNB(simParameters); % Create gNB node

% Create and add scheduler
switch(simParameters.SchedulerStrategy)
    case 'RR' % Round robin scheduler
        scheduler = hNRSchedulerRoundRobin(simParameters);
    case 'PF' % Proportional fair scheduler
        scheduler = hNRSchedulerProportionalFair(simParameters);
    case 'BestCQI' % Best CQI scheduler
        scheduler = hNRSchedulerBestCQI(simParameters);
end
addScheduler(gNB, scheduler); % Add scheduler to gNB

gNB.PhyEntity = hNRGNBPassThroughPhy(simParameters); % Add passthrough PHY
configurePhy(gNB, simParameters);
setPhyInterface(gNB); % Set the interface to PHY layer

% Create the set of UE nodes
UEs = cell(simParameters.NumUEs, 1); 
for ueIdx=1:simParameters.NumUEs
    simParameters.Position = [simParameters.UEDistance(ueIdx) 0 0]; % Position of UE
    UEs{ueIdx} = hNRUE(simParameters, ueIdx);
    UEs{ueIdx}.PhyEntity = hNRUEPassThroughPhy(simParameters, ueIdx); % Add passthrough PHY
    configurePhy(UEs{ueIdx}, simParameters);
    setPhyInterface(UEs{ueIdx}); % Set the interface to PHY layer
    
    % Initialize the UL CQI values at gNB
    updateChannelQuality(gNB, simParameters.InitialChannelQualityUL(ueIdx, :), 1, ueIdx); % 1 for UL
    % Initialize the DL CQI values at gNB and UE. The DL CQI values
    % help gNB in scheduling, and UE in packet error probability estimation
    updateChannelQuality(gNB, simParameters.InitialChannelQualityDL(ueIdx, :), 0, ueIdx); % 0 for DL
    updateChannelQuality(UEs{ueIdx}, simParameters.InitialChannelQualityDL(ueIdx, :));
end

% Setup logical channels
for lchInfoIdx = 1:size(simParameters.RLCChannelConfig, 1)
    rlcChannelConfigStruct = table2struct(simParameters.RLCChannelConfig(lchInfoIdx, :));
    ueIdx = simParameters.RLCChannelConfig.RNTI(lchInfoIdx);
    % Setup the logical channel at gNB and UE
    gNB.configureLogicalChannel(ueIdx, rlcChannelConfigStruct);
    UEs{ueIdx}.configureLogicalChannel(ueIdx, rlcChannelConfigStruct);
end

% Add data traffic pattern generators to gNB and UE nodes
for appIdx = 1:size(simParameters.AppConfig, 1)
    device = simParameters.AppConfig.HostDevice(appIdx);
    rnti = simParameters.AppConfig.RNTI(appIdx);
    lcid = simParameters.AppConfig.LCID(appIdx);
    packetSize = simParameters.AppConfig.PacketSize(appIdx);
    packetInterval = simParameters.AppConfig.PacketInterval(appIdx);
    % Calculate the data rate (in kbps) of On-Off traffic pattern using
    % packet size (in bytes) and packet interval (in ms)
    dataRate = ceil(1000/packetInterval) * packetSize * 8e-3;
    % Limit the size of the generated application packet to the maximum RLC
    % SDU size. The maximum supported RLC SDU size is 9000 bytes
    if packetSize > 9000
        packetSize = 9000;
    end
    % Create an object for On-Off network traffic pattern and add it to the
    % specified UE. This object generates the uplink data traffic on the UE
    if device == 1 || device == 2
        ulApp = networkTrafficOnOff('PacketSize', packetSize, 'GeneratePacket', true, ...
            'OnTime', simParameters.NumFramesSim/100, 'OffTime', 0, 'DataRate', dataRate);
        UEs{rnti}.addApplication(rnti, lcid, ulApp);
    end
    % Create an object for On-Off network traffic pattern for the specified
    % UE and add it to the gNB. This object generates the downlink data
    % traffic on the gNB for the UE
    if device == 0 || device == 2
        dlApp = networkTrafficOnOff('PacketSize', packetSize, 'GeneratePacket', true, ...
            'OnTime', simParameters.NumFramesSim/100, 'OffTime', 0, 'DataRate', dataRate);
        gNB.addApplication(rnti, lcid, dlApp);
    end
end

% Setup the UL and DL packet distribution mechanism
simParameters.MaxReceivers = simParameters.NumUEs;
% Create DL packet distribution object
dlPacketDistributionObj = hNRPacketDistribution(simParameters, 0); % 0 for DL
% Create UL packet distribution object
ulPacketDistributionObj = hNRPacketDistribution(simParameters, 1); % 1 for UL
hNRSetUpPacketDistribution(simParameters, gNB, UEs, dlPacketDistributionObj, ulPacketDistributionObj);

% To store these UE metrics for each slot: throughput bytes
% transmitted, goodput bytes transmitted, and pending buffer amount bytes.
% The number of goodput bytes is calculated by excluding the
% retransmissions from the total transmissions
UESlotMetricsUL = zeros(simParameters.NumUEs, 3);
UESlotMetricsDL = zeros(simParameters.NumUEs, 3);

% To store the RLC statistics for each slot
ueRLCStats = cell(simParameters.NumUEs, 1);
gNBRLCStats = cell(simParameters.NumUEs, 1);

 % To store current UL and DL CQI values on the RBs for different UEs
uplinkChannelQuality = zeros(simParameters.NumUEs, simParameters.NumRBs);
downlinkChannelQuality = zeros(simParameters.NumUEs, simParameters.NumRBs);

 % To store last received UL and DL HARQ process NDI flag value at UE
HARQProcessStatusUL = zeros(simParameters.NumUEs, simParameters.NumHARQ);
HARQProcessStatusDL = zeros(simParameters.NumUEs, simParameters.NumHARQ);

% Create an object for MAC (UL & DL) scheduling information visualization and logging
simSchedulingLogger = hNRSchedulingLogger(simParameters);

% To store the logical channel information associated per UE
lchInfo = repmat(struct('LCID',[],'EntityDir',[]), [simParameters.NumUEs 1]);
for ueIdx = 1:simParameters.NumUEs
    lchInfo(ueIdx).LCID = simParameters.RLCChannelConfig.LogicalChannelID(simParameters.AppConfig.RNTI == ueIdx);
    lchInfo(ueIdx).EntityDir = simParameters.RLCChannelConfig.EntityType(simParameters.AppConfig.RNTI == ueIdx);
end

% Create an object for RLC visualization and logging
simRLCLogger = hNRRLCLogger(simParameters, lchInfo);

symbolNum = 0;
% Run processing loop
for slotNum = 1:numSlotsSim
    
    % Run MAC and PHY layers of gNB
    run(gNB.MACEntity);
    run(gNB.PhyEntity);
    
    % Run MAC and PHY layers of UEs
    for ueIdx = 1:simParameters.NumUEs
        % Read the last received NDI flags for HARQ processes for
        % logging (Reading it before it gets overwritten by run function of MAC)
        HARQProcessStatusUL(ueIdx, :) = getLastNDIFlagHarq(UEs{ueIdx}.MACEntity, 1); % 1 for UL
        HARQProcessStatusDL(ueIdx, :) = getLastNDIFlagHarq(UEs{ueIdx}.MACEntity, 0); % 0 for DL
        run(UEs{ueIdx}.MACEntity); 
        run(UEs{ueIdx}.PhyEntity);
    end
    
    % RLC logging
    for ueIdx = 1:simParameters.NumUEs % For all UEs
        % Get RLC statistics
        ueRLCStats{ueIdx} = getRLCStatistics(UEs{ueIdx}, ueIdx);
        gNBRLCStats{ueIdx} = getRLCStatistics(gNB, ueIdx);
    end
    logRLCStats(simRLCLogger, ueRLCStats, gNBRLCStats); % Update RLC statistics logs
    
    % MAC logging
    % Read UL and DL assignments done by gNB MAC scheduler
    % at current time. Resource assignments returned by a scheduler (either
    % UL or DL) is empty, if either scheduler was not scheduled to run at
    % the current time or no resources got scheduled
    [resourceAssignmentsUL, resourceAssignmentsDL] = getCurrentSchedulingAssignments(gNB.MACEntity);
    % Read throughput and goodput bytes sent for each UE
    [UESlotMetricsDL(:, 1), UESlotMetricsDL(:, 2)] = getTTIBytes(gNB);
    UESlotMetricsDL(:, 3) = getBufferStatus(gNB); % Read pending buffer (in bytes) on gNB
    for ueIdx = 1:simParameters.NumUEs
        % Read the UL channel quality at gNB for each of the UEs for logging
        uplinkChannelQuality(ueIdx,:) = getChannelQuality(gNB, 1, ueIdx); % 1 for UL
        % Read the DL channel quality at gNB for each of the UEs for logging
        downlinkChannelQuality(ueIdx,:) = getChannelQuality(gNB, 0, ueIdx); % 0 for DL
        % Read throughput and goodput bytes transmitted for this UE in the current TTI for logging
        [UESlotMetricsUL(ueIdx, 1), UESlotMetricsUL(ueIdx, 2)] = getTTIBytes(UEs{ueIdx});
        UESlotMetricsUL(ueIdx, 3) = getBufferStatus(UEs{ueIdx}); % Read pending buffer (in bytes) on UE
    end
    % Update scheduling logs based on the current slot run of UEs and gNB.
    % Logs are updated in each slot, RB grid visualizations are updated
    % every frame, and metrics plots are updated every metricsStepSize
    % slots
    logScheduling(simSchedulingLogger, symbolNum + 1, resourceAssignmentsUL, UESlotMetricsUL, uplinkChannelQuality, HARQProcessStatusUL, 1); % 1 for UL
    logScheduling(simSchedulingLogger, symbolNum + 1, resourceAssignmentsDL, UESlotMetricsDL, downlinkChannelQuality, HARQProcessStatusDL, 0); % 0 for DL

    % Visualization
    % RB assignment visualization (if enabled)
    if simParameters.RBVisualization
        if mod(slotNum, numSlotsFrame) == 0
            plotRBGrids(simSchedulingLogger);
        end
    end
    % CQI grid visualization (if enabled)
    if simParameters.CQIVisualization
        if mod(slotNum, numSlotsFrame) == 0
            plotCQIRBGrids(simSchedulingLogger);
        end
    end
    % Plot scheduler metrics and RLC metrics visualization at slot
    % boundary, if the update periodicity is reached
    if mod(slotNum, simParameters.MetricsStepSize) == 0
        plotMetrics(simSchedulingLogger);
        plotMetrics(simRLCLogger);
    end

    % Advance timer ticks for gNB and UEs by the number of symbols per slot
    advanceTimer(gNB, 14);
    for ueIdx = 1:simParameters.NumUEs
        advanceTimer(UEs{ueIdx}, 14);
    end

    % Symbol number in the simulation
    symbolNum = symbolNum + 14; 
end