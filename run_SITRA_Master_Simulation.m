%% run_SITRA_Master_Simulation.m
% Master MATLAB behavioral simulation / validation package for the SITRA project.
%
% PURPOSE
%   1) Run the FROZEN Part 8 MPC reference without modifying it.
%   2) Capture the reference histories.
%   3) Convert the recorded active-phase history to discrete switching commands.
%   4) Reconstruct the queue dynamics with the exact Part 8 update ordering.
%   5) Validate green limits, mutual exclusion, queue trajectory,
%      conservation, and recovery equivalence.
%   6) Generate the requested engineering plots and schematic figures.
%   7) Save numerical results to Results/data.
%
% IMPORTANT
%   - part8_mpc_controller.m and mpcSignalModel.m are FROZEN references.
%   - This script does not redesign or replace the MPC.
%   - Electrical component values are intentionally not invented here.
%
% CLEAN-SESSION WORKFLOW
%   clear; clc; close all; run_SITRA_Master_Simulation
%

clear;
clc;
close all;

fprintf('\n============================================================\n');
fprintf('SITRA MASTER MATLAB SIMULATION\n');
fprintf('============================================================\n');

%% 1. Locate project folders
thisFile = mfilename('fullpath');
if isempty(thisFile)
    projectRoot = pwd;
else
    matlabFolder = fileparts(thisFile);
    projectRoot = matlabFolder;
end

resultsRoot = fullfile(projectRoot,'Results');
figRoot = fullfile(resultsRoot,'figures');
dataRoot = fullfile(resultsRoot,'data');
tableRoot = fullfile(resultsRoot,'comparison_tables');

if exist(figRoot,'dir') ~= 7, mkdir(figRoot); end
if exist(dataRoot,'dir') ~= 7, mkdir(dataRoot); end
if exist(tableRoot,'dir') ~= 7, mkdir(tableRoot); end

cd(matlabFolder);

%% 2. Required frozen files
requiredFiles = { ...
    'createNetwork.m', ...
    'part8_mpc_controller.m', ...
    'mpcSignalModel.m'};

for k = 1:numel(requiredFiles)
    if exist(requiredFiles{k},'file') ~= 2
        error(['Required file not found: ' requiredFiles{k} '. ' ...
            'Place the frozen Part 8 reference files in the MATLAB folder.']);
    end
end

%% 3. Reference files and run configuration are loaded after the frozen reference executes.

%% 4. Run frozen Part 8 reference
fprintf('\n[1/8] Running FROZEN Part 8 reference...\n');
run('part8_mpc_controller.m');

% The frozen Part 8 script begins with CLEAR. Rebuild the master-side
% configuration after it returns so the master simulation does not rely on
% variables that the frozen script may have removed.
thisFile = mfilename('fullpath');
matlabFolder = fileparts(thisFile);
projectRoot = matlabFolder;
resultsRoot = fullfile(projectRoot,'Results');
figRoot = fullfile(resultsRoot,'figures');
dataRoot = fullfile(resultsRoot,'data');
tableRoot = fullfile(resultsRoot,'comparison_tables');
if exist(figRoot,'dir') ~= 7, mkdir(figRoot); end
if exist(dataRoot,'dir') ~= 7, mkdir(dataRoot); end
if exist(tableRoot,'dir') ~= 7, mkdir(tableRoot); end
cd(matlabFolder);

% Re-establish project parameters after the frozen script's CLEAR.
net = createNetwork();
dt = 1.0;
T = 600;
cycle = 63;
yellow = 3;
gMin = 12;
gMax = 30;
gAvail = cycle - 3*yellow;
normalDemand = [0.10 0.07 0.05];
surgeDemand  = [0.30 0.07 0.05];
surgeStart = 200;
surgeEnd = 400;
congestionThreshold = 5.0;

requiredVars = {'qHist','residual','greenHist','tVec','activeHist'};
for k = 1:numel(requiredVars)
    if ~exist(requiredVars{k},'var')
        error('Frozen Part 8 did not produce required variable: %s',requiredVars{k});
    end
end

qHistPart8 = double(qHist);
residualPart8 = double(residual);
greenHistPart8 = double(greenHist);
tPart8 = double(tVec(:));
activeHistPart8 = double(activeHist(:));

N = numel(tPart8);

fprintf('  qHist      = %d x %d\n',size(qHistPart8,1),size(qHistPart8,2));
fprintf('  residual   = %d x %d\n',size(residualPart8,1),size(residualPart8,2));
fprintf('  greenHist  = %d x %d\n',size(greenHistPart8,1),size(greenHistPart8,2));
fprintf('  activeHist = %d x %d\n',size(activeHistPart8,1),size(activeHistPart8,2));

%% 5. Validate Part 8 green allocation
fprintf('\n[2/8] Validating Part 8 supervisory allocation...\n');

lowerViolation = max(max(gMin - greenHistPart8,[],2));
upperViolation = max(max(greenHistPart8 - gMax,[],2));
greenSumError = max(abs(sum(greenHistPart8,2)-gAvail));

lowerPASS = lowerViolation <= 1e-9;
upperPASS = upperViolation <= 1e-9;
greenSumPASS = greenSumError <= 1e-9;
greenConstraintPASS = lowerPASS && upperPASS && greenSumPASS;

fprintf('  B1 range = %.2f -> %.2f s\n',min(greenHistPart8(:,1)),max(greenHistPart8(:,1)));
fprintf('  B2 range = %.2f -> %.2f s\n',min(greenHistPart8(:,2)),max(greenHistPart8(:,2)));
fprintf('  B3 range = %.2f -> %.2f s\n',min(greenHistPart8(:,3)),max(greenHistPart8(:,3)));
fprintf('  Lower violation = %.6e s\n',lowerViolation);
fprintf('  Upper violation = %.6e s\n',upperViolation);
fprintf('  Green-sum error = %.6e s\n',greenSumError);

%% 6. Build discrete switching commands from frozen activeHist
fprintf('\n[3/8] Building discrete switching representation...\n');

% activeHist values:
%   0 = clearance/all OFF
%   1 = B1 active
%   2 = B2 active
%   3 = B3 active
switchingState = activeHistPart8;
switchingCommands = zeros(N,3);

for k = 1:N
    a = switchingState(k);
    if a >= 1 && a <= 3
        switchingCommands(k,a) = 1;
    end
end

maxSimultaneous = max(sum(switchingCommands,2));
mutualExclusionPASS = maxSimultaneous <= 1;
validStatePASS = all(ismember(switchingState,0:3));

% Active-phase mismatch is defined relative to the binary command map.
activeFromSwitch = zeros(N,1);
for k = 1:N
    idx = find(switchingCommands(k,:) > 0.5,1,'first');
    if isempty(idx)
        activeFromSwitch(k) = 0;
    else
        activeFromSwitch(k) = idx;
    end
end

activeMismatch = max(abs(activeFromSwitch-switchingState));
activePhasePASS = activeMismatch == 0;

fprintf('  Max simultaneous active switches = %d\n',maxSimultaneous);
fprintf('  Valid switching states = %s\n',passfail(validStatePASS));
fprintf('  Active-phase mismatch = %.6e\n',activeMismatch);
fprintf('  Mutual exclusion = %s\n',passfail(mutualExclusionPASS));

%% 7. Cycle-level green conversion check
fprintf('\n[4/8] Checking green-duration conversion...\n');

cycleNumber = floor(tPart8/cycle)+1;
numCycles = max(cycleNumber);
conversionError = nan(numCycles,3);

for c = 1:numCycles
    idx = cycleNumber == c;
    if ~any(idx)
        continue;
    end

    firstIdx = find(idx,1,'first');
    lastIdx = find(idx,1,'last');

    % Only validate complete cycles. The final 600 s sample may be a partial cycle.
    cycleStart = (c-1)*cycle;
    cycleEnd = c*cycle;
    complete = (cycleEnd <= T + 1e-12);

    if ~complete || tPart8(lastIdx) < cycleEnd - dt
        continue;
    end

    gRef = greenHistPart8(firstIdx,:);
    onCounts = sum(switchingCommands(idx,:),1);
    conversionError(c,:) = abs(onCounts*dt-gRef);
end

completeIdx = all(isfinite(conversionError),2);
completeCyclesValidated = sum(completeIdx);

if completeCyclesValidated == 0
    maxConversionError = Inf;
    meanConversionError = Inf;
else
    conversionFinite = conversionError(completeIdx,:);
    maxConversionError = max(conversionFinite(:));
    meanConversionError = mean(conversionFinite(:));
end

conversionPASS = maxConversionError <= dt + 1e-9;

fprintf('  Complete cycles validated = %d\n',completeCyclesValidated);
fprintf('  Maximum discrete conversion error = %.6e s\n',maxConversionError);
fprintf('  Mean discrete conversion error = %.6e s\n',meanConversionError);

%% 8. Reconstruct switching queue trajectory using exact Part 8 ordering
fprintf('\n[5/8] Reconstructing switching queue trajectory...\n');

qSwitch = zeros(N,net.nBranches);
resSwitch = zeros(N,net.nBranches);
demandHistMaster = zeros(N,3);
arrivalHistSwitch = zeros(N,4);
departureHistSwitch = zeros(N,4);

for k = 1:N
    tNow = tPart8(k);

    if tNow >= surgeStart && tNow < surgeEnd
        demand = surgeDemand;
    else
        demand = normalDemand;
    end
    demandHistMaster(k,:) = demand;

    active = switchingState(k);

    arrival = zeros(1,net.nBranches);
    departure = zeros(1,net.nBranches);

    % External arrivals enter B1-B3.
    arrival(1:3) = demand;

    % Upstream departure uses queue present at START of timestep.
    for b = net.feedingBranches
        if b == active
            departure(b) = min(net.capacity(b),qSwitch(k,b)/dt);
        else
            departure(b) = 0;
        end
    end

    % Active approach feeds B4.
    if active > 0
        arrival(4) = departure(active);
    end

    % Downstream B4 service.
    departure(4) = min(net.capacity(4),qSwitch(k,4)/dt);

    % Exact validated queue update.
    qNext = max(0,qSwitch(k,:) + dt*(arrival-departure));

    resSwitch(k,:) = arrival - departure - (qNext-qSwitch(k,:))/dt;
    arrivalHistSwitch(k,:) = arrival;
    departureHistSwitch(k,:) = departure;

    if k < N
        qSwitch(k+1,:) = qNext;
    end
end

%% 9. Core equivalence / conservation checks
fprintf('\n[6/8] Running equivalence and conservation checks...\n');

queueError = abs(qHistPart8-qSwitch);
totalPart8 = sum(qHistPart8,2);
totalSwitch = sum(qSwitch,2);
totalError = abs(totalPart8-totalSwitch);
B1Error = abs(qHistPart8(:,1)-qSwitch(:,1));
resHistoryError = abs(residualPart8-resSwitch);

maxQueueError = max(queueError(:));
meanQueueError = mean(queueError(:));
maxTotalQueueError = max(totalError);
meanTotalQueueError = mean(totalError);
maxB1QueueError = max(B1Error);
maxResidualPart8 = max(abs(residualPart8(:)));
maxResidualSwitch = max(abs(resSwitch(:)));
maxResidualHistoryDifference = max(resHistoryError(:));

queueTrajectoryPASS = maxQueueError <= 1e-12;
conservationPASS = maxResidualSwitch < 1e-10 && maxResidualHistoryDifference <= 1e-12;
queueNonnegativePASS = all(qHistPart8(:) >= -1e-12) && all(qSwitch(:) >= -1e-12);

peakPart8 = max(totalPart8);
peakSwitch = max(totalSwitch);
peakError = abs(peakPart8-peakSwitch);
peakPASS = peakError <= 1e-12;

% Recovery metric: first time at/under threshold after surge end.
idx8 = find(tPart8 >= surgeEnd & totalPart8 <= congestionThreshold,1,'first');
idxS = find(tPart8 >= surgeEnd & totalSwitch <= congestionThreshold,1,'first');

if isempty(idx8), recoveryPart8 = Inf; else, recoveryPart8 = tPart8(idx8)-surgeEnd; end
if isempty(idxS), recoverySwitch = Inf; else, recoverySwitch = tPart8(idxS)-surgeEnd; end

if isinf(recoveryPart8) && isinf(recoverySwitch)
    recoveryError = 0;
else
    recoveryError = abs(recoveryPart8-recoverySwitch);
end
recoveryPASS = recoveryError <= dt + 1e-9;

fprintf('  Maximum absolute queue error = %.6e veh\n',maxQueueError);
fprintf('  Mean absolute queue error = %.6e veh\n',meanQueueError);
fprintf('  Maximum total queue error = %.6e veh\n',maxTotalQueueError);
fprintf('  Maximum B1 queue error = %.6e veh\n',maxB1QueueError);
fprintf('  Part 8 peak = %.3f veh\n',peakPart8);
fprintf('  Switching peak = %.3f veh\n',peakSwitch);
fprintf('  Part 8 max residual = %.6e\n',maxResidualPart8);
fprintf('  Switching max residual = %.6e\n',maxResidualSwitch);
fprintf('  Residual-history difference = %.6e\n',maxResidualHistoryDifference);
fprintf('  Part 8 recovery = %.3f s\n',recoveryPart8);
fprintf('  Switching recovery = %.3f s\n',recoverySwitch);

%% 10. Performance metrics
beforeMask = tPart8 < surgeStart;
duringMask = tPart8 >= surgeStart & tPart8 < surgeEnd;
afterMask = tPart8 >= surgeEnd;

meanBefore = mean(totalPart8(beforeMask));
meanDuring = mean(totalPart8(duringMask));
meanAfter = mean(totalPart8(afterMask));
maxB1 = max(qHistPart8(:,1));
finalTotal = totalPart8(end);
finalB1 = qHistPart8(end,1);

congestedMask = totalPart8 > congestionThreshold;
congestionDuration = sum(congestedMask)*dt;
idxFirstCong = find(congestedMask,1,'first');
idxLastCong = find(congestedMask,1,'last');

if isempty(idxFirstCong)
    firstCongestionTime = NaN;
else
    firstCongestionTime = tPart8(idxFirstCong);
end
if isempty(idxLastCong)
    lastCongestionTime = NaN;
else
    lastCongestionTime = tPart8(idxLastCong);
end

%% 11. Optional frozen baseline values from BUILD_LOG for comparison
% These are LOGGED reference values, not regenerated controller runs.
% They are used only as a regression/context table.
loggedPart6 = struct( ...
    'meanBefore',4.428, ...
    'meanDuring',12.178, ...
    'meanAfter',6.370, ...
    'peakTotal',15.550, ...
    'peakB1',13.100, ...
    'finalTotal',5.330, ...
    'finalB1',0.900, ...
    'recovery',56.0);

loggedPart7Fixed = struct( ...
    'meanBefore',4.465, ...
    'meanDuring',18.574, ...
    'meanAfter',21.711, ...
    'peakTotal',30.570, ...
    'peakB1',28.200, ...
    'finalTotal',11.210, ...
    'finalB1',8.000, ...
    'recovery',NaN);

loggedPart8 = struct( ...
    'meanBefore',4.167, ...
    'meanDuring',10.724, ...
    'meanAfter',5.697, ...
    'peakTotal',12.890, ...
    'peakB1',10.800, ...
    'finalTotal',6.060, ...
    'finalB1',0.600, ...
    'recovery',47.0);

loggedReferenceTolerance = 5e-3;
loggedPart8RegressionPASS = ...
    abs(meanDuring-loggedPart8.meanDuring) <= loggedReferenceTolerance && ...
    abs(meanAfter-loggedPart8.meanAfter) <= loggedReferenceTolerance && ...
    abs(peakPart8-loggedPart8.peakTotal) <= loggedReferenceTolerance && ...
    abs(maxB1-loggedPart8.peakB1) <= loggedReferenceTolerance && ...
    abs(finalB1-loggedPart8.finalB1) <= loggedReferenceTolerance && ...
    abs(recoveryPart8-loggedPart8.recovery) <= loggedReferenceTolerance;

%% 12. Generate required figures
fprintf('\n[7/8] Generating engineering figures...\n');

% Common display helper.
addEventLines = @(ax) add_event_lines(ax,surgeStart,surgeEnd);

%% Figure 1 - Network queue trajectories
f1 = figure('Name','SITRA - Network Queue Dynamics','NumberTitle','off');
plot(tPart8,qHistPart8,'LineWidth',1.4);
grid on;
xlabel('Time [s]');
ylabel('Queue [veh]');
title('SITRA Network Queue Dynamics');
legend('B1','B2','B3','B4','Location','best');
addEventLines(gca);
save_figure(f1,figRoot,'01_network_queue_dynamics');

%% Figure 2 - Total queue
f2 = figure('Name','SITRA - Total Queue Response','NumberTitle','off');
plot(tPart8,totalPart8,'LineWidth',1.6);
hold on;
plot(tPart8,congestionThreshold*ones(size(tPart8)),'--','LineWidth',1.0);
grid on;
xlabel('Time [s]');
ylabel('Total Queue [veh]');
title('SITRA Total Queue Response');
legend('Total queue','Congestion threshold = 5 veh','Location','best');
addEventLines(gca);
save_figure(f2,figRoot,'02_total_queue_response');

%% Figure 3 - External demand
f3 = figure('Name','SITRA - External Demand Profile','NumberTitle','off');
plot(tPart8,demandHistMaster,'LineWidth',1.4);
grid on;
xlabel('Time [s]');
ylabel('Demand [veh/s]');
title('External Traffic Demand Profile');
legend('B1','B2','B3','Location','best');
addEventLines(gca);
save_figure(f3,figRoot,'03_external_demand_profile');

%% Figure 4 - Green allocation
f4 = figure('Name','SITRA - MPC Green Allocation','NumberTitle','off');
plot(tPart8,greenHistPart8,'LineWidth',1.4);
hold on;
plot(tPart8,gMin*ones(size(tPart8)),'--','LineWidth',1.0);
plot(tPart8,gMax*ones(size(tPart8)),'--','LineWidth',1.0);
grid on;
xlabel('Time [s]');
ylabel('Green Time [s]');
title('MPC Green-Time Allocation');
legend('B1','B2','B3','Minimum = 12 s','Maximum = 30 s','Location','best');
addEventLines(gca);
save_figure(f4,figRoot,'04_mpc_green_time_allocation');

%% Figure 5 - Discrete switching state
f5 = figure('Name','SITRA - Discrete Switching State','NumberTitle','off');
stairs(tPart8,switchingState,'LineWidth',1.4);
grid on;
xlabel('Time [s]');
ylabel('State');
yticks(0:3);
yticklabels({'0 Clearance','1 B1','2 B2','3 B3'});
title('Discrete Traffic-Signal Switching State');
addEventLines(gca);
save_figure(f5,figRoot,'05_discrete_switching_state');

%% Figure 6 - Binary commands
f6 = figure('Name','SITRA - Switching Commands','NumberTitle','off');
stairs(tPart8,switchingCommands,'LineWidth',1.2);
grid on;
xlabel('Time [s]');
ylabel('Command');
yticks([0 1]);
title('Mutually Exclusive Switching Commands');
legend('S1 / B1','S2 / B2','S3 / B3','Location','best');
addEventLines(gca);
save_figure(f6,figRoot,'06_switching_commands');

%% Figure 7 - Total queue equivalence
f7 = figure('Name','SITRA - Part 8 vs Switching Total Queue','NumberTitle','off');
plot(tPart8,totalPart8,'LineWidth',1.5);
hold on;
plot(tPart8,totalSwitch,'--','LineWidth',1.5);
grid on;
xlabel('Time [s]');
ylabel('Total Queue [veh]');
title('Part 8 vs Switching Total Queue Equivalence');
legend('Part 8 reference','Switching representation','Location','best');
addEventLines(gca);
save_figure(f7,figRoot,'07_part8_vs_switching_total_queue');

%% Figure 8 - B1 equivalence
f8 = figure('Name','SITRA - B1 Queue Equivalence','NumberTitle','off');
plot(tPart8,qHistPart8(:,1),'LineWidth',1.5);
hold on;
plot(tPart8,qSwitch(:,1),'--','LineWidth',1.5);
grid on;
xlabel('Time [s]');
ylabel('B1 Queue [veh]');
title('B1 Queue Equivalence');
legend('Part 8 reference','Switching representation','Location','best');
addEventLines(gca);
save_figure(f8,figRoot,'08_b1_queue_equivalence');

%% Figure 9 - Error
f9 = figure('Name','SITRA - Queue Trajectory Error','NumberTitle','off');
plot(tPart8,totalError,'LineWidth',1.4);
hold on;
plot(tPart8,B1Error,'--','LineWidth',1.2);
grid on;
xlabel('Time [s]');
ylabel('Absolute Error [veh]');
title('Switching Representation Queue Error');
legend('Total queue error','B1 queue error','Location','best');
addEventLines(gca);
save_figure(f9,figRoot,'09_queue_trajectory_error');

%% Figure 10 - Conservation residual
f10 = figure('Name','SITRA - Conservation Residual','NumberTitle','off');
semilogy(tPart8,max(abs(residualPart8),[],2)+eps,'LineWidth',1.3);
hold on;
semilogy(tPart8,max(abs(resSwitch),[],2)+eps,'--','LineWidth',1.3);
grid on;
xlabel('Time [s]');
ylabel('Maximum |Residual|');
title('Traffic Network Conservation Residual');
legend('Part 8 reference','Switching representation','Location','best');
addEventLines(gca);
save_figure(f10,figRoot,'10_conservation_residual');

%% Figure 11 - Network visualization
f11 = figure('Name','SITRA - Network Schematic','NumberTitle','off');
axis off;
xlim([0 10]);
ylim([0 8]);
hold on;

plot([1 5],[6 4],'LineWidth',2);
plot([1 5],[4.2 4],'LineWidth',2);
plot([1 5],[2 4],'LineWidth',2);
plot([5 9],[4 4],'LineWidth',2);

text(0.6,6,'HopeCollege','FontWeight','bold');
text(0.6,4.2,'Kalapatti','FontWeight','bold');
text(0.6,2,'Airport','FontWeight','bold');
text(4.55,4,'SITRA','FontWeight','bold','FontSize',12);
text(8.6,4,'Goldwins','FontWeight','bold');

text(2.7,5.15,'B1  |  0.65 veh/s');
text(2.7,4.35,'B2  |  0.35 veh/s');
text(2.7,2.95,'B3  |  0.25 veh/s');
text(6.4,4.25,'B4  |  0.45 veh/s');

text(4.15,6.9,'SITRA Network','FontWeight','bold','FontSize',14);
text(3.2,0.8,'Three feeding approaches -> one downstream bottleneck','FontAngle','italic');
text(3.1,0.35,'Capacities are simulation assumptions, not field measurements.','FontSize',8);

save_figure(f11,figRoot,'11_network_schematic');

%% Figure 12 - Switching visualization
f12 = figure('Name','SITRA - Switching Architecture','NumberTitle','off');
axis off;
xlim([0 12]);
ylim([0 10]);
hold on;

box = @(x,y,w,h,txt) draw_box(x,y,w,h,txt);
arrow = @(x1,y1,x2,y2) draw_arrow(x1,y1,x2,y2);

box(5,8.2,2,0.8,'MPC');
box(4.4,6.8,3.2,0.9,'Green Allocation');
box(3.8,5.3,4.4,0.9,'Switching State Generator');
box(0.8,3.5,2.2,0.8,'S1 -> B1');
box(4.5,3.5,2.2,0.8,'S2 -> B2');
box(8.2,3.5,2.2,0.8,'S3 -> B3');
box(4.6,1.8,2.8,0.8,'CLEARANCE');
box(4.8,0.4,2.4,0.8,'B4 -> Goldwins');

arrow(6,8.2,6,7.7);
arrow(6,6.8,6,6.2);
arrow(5,5.3,2,4.3);
arrow(6,5.3,5.6,4.3);
arrow(7,5.3,9.3,4.3);
arrow(2,3.5,5.7,2.6);
arrow(5.6,3.5,5.9,2.6);
arrow(9.3,3.5,6.6,2.6);
arrow(6,1.8,6,1.2);
arrow(6,0.4,6,0.0);

title('Controller-to-Switching Representation','FontSize',14,'FontWeight','bold');
save_figure(f12,figRoot,'12_switching_architecture');

%% Figure 13 - Optional conceptual electrical representation
f13 = figure('Name','SITRA - Conceptual Power Electronics Layer','NumberTitle','off');
axis off;
xlim([0 12]);
ylim([0 10]);
hold on;

box(5,8.4,2,0.8,'DC BUS');
box(1,5.5,2.6,0.8,'SWITCH S1 -> B1');
box(4.7,5.5,2.6,0.8,'SWITCH S2 -> B2');
box(8.4,5.5,2.6,0.8,'SWITCH S3 -> B3');
box(4.7,3.4,2.6,0.8,'Sensing');
box(4.7,1.9,2.6,0.8,'Protection');
box(4.1,0.4,3.8,0.8,'Controller / Gate Interface');

arrow(6,8.4,2.3,6.3);
arrow(6,8.4,6,6.3);
arrow(6,8.4,9.7,6.3);
arrow(2.3,5.5,6,4.2);
arrow(6,5.5,6,4.2);
arrow(9.7,5.5,6,4.2);
arrow(6,3.4,6,2.7);
arrow(6,1.9,6,1.2);

title('Conceptual Power-Electronics-Inspired Layer (No Component Values)','FontSize',13,'FontWeight','bold');
text(1.0,9.3,'Representation only - not yet an electrically validated power circuit.','FontAngle','italic');
save_figure(f13,figRoot,'13_conceptual_power_electronics_layer');


%% Figure 14 - Frozen baseline comparison
f14 = figure('Name','SITRA - Controller Comparison','NumberTitle','off');
labels = categorical({'Fixed-time','Adaptive','MPC'});
labels = reordercats(labels,{'Fixed-time','Adaptive','MPC'});
metricPeak = [loggedPart7Fixed.peakTotal loggedPart6.peakTotal peakPart8];
bar(labels,metricPeak);
grid on;
xlabel('Controller');
ylabel('Peak Total Queue [veh]');
title('Fixed-Time vs Adaptive vs MPC Peak Queue');
text(1:numel(metricPeak),metricPeak,string(round(metricPeak,3)), ...
    'HorizontalAlignment','center','VerticalAlignment','bottom');
save_figure(f14,figRoot,'14_fixed_adaptive_mpc_peak_comparison');

%% 13. Build validation table
fprintf('\n[8/8] Final validation and result export...\n');

% Validate the complete demand profile sample-by-sample. The simulation
% includes both endpoints (t = 0 and t = T), so comparing its sample mean
% against a continuous-duration average can introduce an off-by-one error.
expectedDemandHist = repmat(normalDemand, N, 1);
surgeMask = tPart8 >= surgeStart & tPart8 < surgeEnd;
expectedDemandHist(surgeMask,:) = repmat(surgeDemand, sum(surgeMask), 1);
demandSurgePASS = max(abs(demandHistMaster(:) - expectedDemandHist(:))) <= 1e-12;

checkNames = { ...
    'Simulation duration', ...
    'Time step', ...
    'Demand surge', ...
    'Green lower bound', ...
    'Green upper bound', ...
    'Green sum = 54 s', ...
    'Mutual exclusion', ...
    'Valid switching state', ...
    'Valid active-phase conversion', ...
    'Conservation', ...
    'Queue non-negativity', ...
    'Reference queue equivalence', ...
    'Peak queue equivalence', ...
    'Recovery equivalence'};

checkPass = [ ...
    abs(T-600) <= 1e-12, ...
    abs(dt-1) <= 1e-12, ...
    demandSurgePASS, ...
    lowerPASS, ...
    upperPASS, ...
    greenSumPASS, ...
    mutualExclusionPASS, ...
    validStatePASS, ...
    activePhasePASS, ...
    conservationPASS, ...
    queueNonnegativePASS, ...
    queueTrajectoryPASS, ...
    peakPASS, ...
    recoveryPASS];

overallPASS = all(checkPass);

fprintf('\nCHECK                                      RESULT\n');
fprintf('---------------------------------------------------------------\n');
for k = 1:numel(checkNames)
    fprintf('%-40s %s\n',checkNames{k},passfail(checkPass(k)));
end
fprintf('---------------------------------------------------------------\n');
if overallPASS
    fprintf('OVERALL SIMULATION STATUS = PASS\n');
else
    fprintf('OVERALL SIMULATION STATUS = FAIL\n');
end

%% 14. Print performance report
fprintf('\n============================================================\n');
fprintf('SITRA MATLAB SIMULATION RESULTS\n');
fprintf('============================================================\n');
fprintf('Simulation: T = %.0f s, dt = %.1f s\n',T,dt);
fprintf('Demand: Normal = [%.2f %.2f %.2f] veh/s\n',normalDemand);
fprintf('        Surge  = [%.2f %.2f %.2f] veh/s\n',surgeDemand);
fprintf('        Surge interval = %.0f -> %.0f s\n',surgeStart,surgeEnd);
fprintf('Signal: Cycle = %.0f s, Yellow = %.0f s, Green = %.0f -> %.0f s\n',cycle,yellow,gMin,gMax);
fprintf('        Available green = %.0f s\n',gAvail);
fprintf('\nQueues (Part 8 reference):\n');
fprintf('  Mean before surge = %.3f veh\n',meanBefore);
fprintf('  Mean during surge = %.3f veh\n',meanDuring);
fprintf('  Mean after surge  = %.3f veh\n',meanAfter);
fprintf('  Peak total queue  = %.3f veh\n',peakPart8);
fprintf('  Peak B1 queue     = %.3f veh\n',maxB1);
fprintf('  Final total queue = %.3f veh\n',finalTotal);
fprintf('  Final B1 queue    = %.3f veh\n',finalB1);
fprintf('\nCongestion:\n');
fprintf('  Threshold = %.1f veh\n',congestionThreshold);
fprintf('  Duration above threshold = %.1f s\n',congestionDuration);
fprintf('  First congestion time = %.1f s\n',firstCongestionTime);
fprintf('  Last congestion time  = %.1f s\n',lastCongestionTime);
fprintf('  Recovery = %.1f s after surge end\n',recoveryPart8);
fprintf('\nSwitching:\n');
fprintf('  Max simultaneous active switches = %d\n',maxSimultaneous);
fprintf('  Complete cycles validated = %d\n',completeCyclesValidated);
fprintf('  Maximum conversion error = %.6e s\n',maxConversionError);
fprintf('\nEquivalence:\n');
fprintf('  Maximum queue error = %.6e veh\n',maxQueueError);
fprintf('  Mean queue error = %.6e veh\n',meanQueueError);
fprintf('  Maximum total queue error = %.6e veh\n',maxTotalQueueError);
fprintf('  Maximum B1 queue error = %.6e veh\n',maxB1QueueError);
fprintf('  Peak error = %.6e veh\n',peakError);
fprintf('  Recovery error = %.6e s\n',recoveryError);
fprintf('\nConservation:\n');
fprintf('  Part 8 max residual = %.6e\n',maxResidualPart8);
fprintf('  Switching max residual = %.6e\n',maxResidualSwitch);
fprintf('  Residual-history difference = %.6e\n',maxResidualHistoryDifference);
fprintf('\nLogged Part 8 regression check = %s\n',passfail(loggedPart8RegressionPASS));
fprintf('============================================================\n');
fprintf('FINAL STATUS = %s\n',passfail(overallPASS));
fprintf('============================================================\n');

%% 15. Save MAT results
results = struct();
results.projectRoot = projectRoot;
results.parameters = struct('dt',dt,'T',T,'cycle',cycle,'yellow',yellow, ...
    'gMin',gMin,'gMax',gMax,'gAvail',gAvail,'normalDemand',normalDemand, ...
    'surgeDemand',surgeDemand,'surgeStart',surgeStart,'surgeEnd',surgeEnd, ...
    'congestionThreshold',congestionThreshold);
results.network = net;
results.time = tPart8;
results.qHistPart8 = qHistPart8;
results.qHistSwitching = qSwitch;
results.residualPart8 = residualPart8;
results.residualSwitching = resSwitch;
results.greenHistPart8 = greenHistPart8;
results.activeHistPart8 = activeHistPart8;
results.switchingState = switchingState;
results.switchingCommands = switchingCommands;
results.demandHistory = demandHistMaster;
results.arrivalHistorySwitching = arrivalHistSwitch;
results.departureHistorySwitching = departureHistSwitch;
results.metrics = struct('meanBefore',meanBefore,'meanDuring',meanDuring, ...
    'meanAfter',meanAfter,'peakTotal',peakPart8,'peakB1',maxB1, ...
    'finalTotal',finalTotal,'finalB1',finalB1,'congestionDuration',congestionDuration, ...
    'firstCongestionTime',firstCongestionTime,'lastCongestionTime',lastCongestionTime, ...
    'recovery',recoveryPart8);
results.validation = struct('greenConstraintPASS',greenConstraintPASS, ...
    'mutualExclusionPASS',mutualExclusionPASS,'validStatePASS',validStatePASS, ...
    'activePhasePASS',activePhasePASS,'conversionPASS',conversionPASS, ...
    'queueTrajectoryPASS',queueTrajectoryPASS,'peakPASS',peakPASS, ...
    'conservationPASS',conservationPASS,'queueNonnegativePASS',queueNonnegativePASS, ...
    'recoveryPASS',recoveryPASS,'overallPASS',overallPASS);

save(fullfile(dataRoot,'SITRA_master_results.mat'),'results','-v7');

%% 16. Save CSV summaries where supported
summaryTable = table( ...
    {'Part8';'Switching'}, ...
    [meanBefore;mean(totalSwitch(beforeMask))], ...
    [meanDuring;mean(totalSwitch(duringMask))], ...
    [meanAfter;mean(totalSwitch(afterMask))], ...
    [peakPart8;peakSwitch], ...
    [maxB1;max(qSwitch(:,1))], ...
    [finalTotal;totalSwitch(end)], ...
    [finalB1;qSwitch(end,1)], ...
    [recoveryPart8;recoverySwitch], ...
    'VariableNames',{'Model','MeanBefore','MeanDuring','MeanAfter','PeakTotal','PeakB1','FinalTotal','FinalB1','Recovery'});

writetable(summaryTable,fullfile(tableRoot,'SITRA_reference_vs_switching.csv'));

%% 17. Store workspace variables for interactive inspection
qHistPart9Switching = qSwitch;
residualPart9Switching = resSwitch;
timePart9 = tPart8;
switchingStatePart9 = switchingState;
switchingCommandsPart9 = switchingCommands;
conversionErrorPart9 = conversionError;

fprintf('\nSaved results:\n');
fprintf('  Results/data/SITRA_master_results.mat\n');
fprintf('  Results/comparison_tables/SITRA_reference_vs_switching.csv\n');
fprintf('  Results/figures/01...14_*.png\n');

if ~overallPASS
    error('SITRA master simulation completed but at least one required validation check FAILED.');
end

%% Local functions
function txt = passfail(tf)
if tf
    txt = 'PASS';
else
    txt = 'FAIL';
end
end

function add_event_lines(ax,t1,t2)
hold(ax,'on');
yl = ylim(ax);
line(ax,[t1 t1],yl,'LineStyle',':');
line(ax,[t2 t2],yl,'LineStyle',':');
end

function save_figure(figHandle,folderRoot,baseName)
set(figHandle,'Color','w');
try
    exportgraphics(figHandle,fullfile(folderRoot,[baseName '.png']),'Resolution',180);
catch
    saveas(figHandle,fullfile(folderRoot,[baseName '.png']));
end
end

function draw_box(x,y,w,h,txt)
rectangle('Position',[x y w h],'Curvature',0.08,'LineWidth',1.3);
text(x+w/2,y+h/2,txt,'HorizontalAlignment','center','VerticalAlignment','middle', ...
    'FontWeight','bold');
end

function draw_arrow(x1,y1,x2,y2)
annotation('textarrow',[x1/12 x2/12],[y1/10 y2/10],'String','');
end
