%% ============================================================
% PART 9 - STEP 9.3
% TRAJECTORY-LEVEL VALIDATION OF PART 8 vs SWITCHING REPRESENTATION
% =============================================================
%
% IMPORTANT:
% 1. Part 8 is FROZEN and is NOT edited by this file.
% 2. This script deliberately RUNS the frozen Part 8 file so that
%    qHist, residual, greenHist, tVec, and activeHist are captured.
% 3. The switching representation then reconstructs the same network
%    dynamics using the Part 8 supervisory green allocation.
%
% Run this file from the folder containing:
%   part8_mpc_controller.m
%   mpcSignalModel.m
%   createNetwork.m
%
% =============================================================

clc;

fprintf('\n============================================================\n');
fprintf('PART 9 - STEP 9.3: TRAJECTORY-LEVEL VALIDATION\n');
fprintf('============================================================\n');

%% 1. Locate and run the FROZEN Part 8 reference
part8File = 'part8_mpc_controller.m';

if exist(part8File,'file') ~= 2
    error(['Cannot find ',part8File,'. Put Step 9.3 in the same folder ', ...
           'as the frozen Part 8 controller.']);
end

fprintf('\nRunning FROZEN Part 8 reference...\n');
fprintf('No changes are made to the Part 8 source file.\n\n');

run(part8File);

%% 2. Capture the Part 8 reference variables
requiredVars = {'qHist','residual','greenHist','tVec','activeHist'};
for k = 1:numel(requiredVars)
    if ~exist(requiredVars{k},'var')
        error('Part 8 did not leave required variable "%s" in the workspace.', ...
            requiredVars{k});
    end
end

qHistPart8       = double(qHist);
residualPart8    = double(residual);
greenHistPart8   = double(greenHist);
tPart8           = double(tVec(:));
activeHistPart8  = double(activeHist(:));

N = numel(tPart8);

fprintf('\nPart 8 reference captured successfully:\n');
fprintf('  qHist      = %d x %d\n',size(qHistPart8,1),size(qHistPart8,2));
fprintf('  residual   = %d x %d\n',size(residualPart8,1),size(residualPart8,2));
fprintf('  greenHist  = %d x %d\n',size(greenHistPart8,1),size(greenHistPart8,2));
fprintf('  activeHist = %d x %d\n',size(activeHistPart8,1),size(activeHistPart8,2));

%% 3. Reference parameters
dt      = 1.0;
T       = 600;
cycle   = 63;
yellow  = 3;
gMin    = 12;
gMax    = 30;
gAvail  = cycle - 3*yellow;

normalDemand = [0.10 0.07 0.05];
surgeDemand  = [0.30 0.07 0.05];
surgeStart   = 200;
surgeEnd     = 400;

net = createNetwork();
cap = net.capacity;

fprintf('\nReference parameters:\n');
fprintf('  Duration = %.0f s\n',T);
fprintf('  dt = %.0f s\n',dt);
fprintf('  Cycle = %.0f s\n',cycle);
fprintf('  Yellow / clearance = %.0f s\n',yellow);
fprintf('  Min green = %.0f s\n',gMin);
fprintf('  Max green = %.0f s\n',gMax);
fprintf('  Available green = %.0f s\n',gAvail);

%% 4. Part 8 green-allocation validation
lowerViolation = max(max(gMin - greenHistPart8,[],2));
upperViolation = max(max(greenHistPart8 - gMax,[],2));
greenSumError  = max(abs(sum(greenHistPart8,2) - gAvail));

greenConstraintPASS = lowerViolation <= 1e-9 && ...
                      upperViolation <= 1e-9 && ...
                      greenSumError <= 1e-9;

fprintf('\nPart 8 green constraints:\n');
fprintf('  B1 range = %.2f -> %.2f s\n', ...
    min(greenHistPart8(:,1)),max(greenHistPart8(:,1)));
fprintf('  B2 range = %.2f -> %.2f s\n', ...
    min(greenHistPart8(:,2)),max(greenHistPart8(:,2)));
fprintf('  B3 range = %.2f -> %.2f s\n', ...
    min(greenHistPart8(:,3)),max(greenHistPart8(:,3)));
fprintf('  Lower violation = %.3e s\n',lowerViolation);
fprintf('  Upper violation = %.3e s\n',upperViolation);
fprintf('  Green-sum error = %.3e s\n',greenSumError);
fprintf('  Green constraints = %s\n',passfail(greenConstraintPASS));

%% 5. Build switching commands from the Part 8 allocation
%
% The phase sequence is:
%   B1 green -> clearance -> B2 green -> clearance
%   -> B3 green -> clearance
%
% This is the discrete switching representation of the supervisory
% allocation. It does not introduce a new controller.

S = zeros(N,3);
state = zeros(N,1);
cycleIndex = floor(tPart8/cycle) + 1;
greenUsed = zeros(N,3);

for k = 1:N
    tau = mod(tPart8(k),cycle);

    g = greenHistPart8(k,:);

    if tau < g(1)
        state(k) = 1;
        S(k,1) = 1;
    elseif tau < g(1) + yellow
        state(k) = 2;
    elseif tau < g(1) + yellow + g(2)
        state(k) = 3;
        S(k,2) = 1;
    elseif tau < g(1) + yellow + g(2) + yellow
        state(k) = 4;
    elseif tau < g(1) + yellow + g(2) + yellow + g(3)
        state(k) = 5;
        S(k,3) = 1;
    else
        state(k) = 6;
    end

    greenUsed(k,:) = g;
end

maxSimultaneous = max(sum(S,2));
mutualExclusionPASS = maxSimultaneous <= 1;

fprintf('\nSwitching representation:\n');
fprintf('  Maximum simultaneous active switches = %d\n',maxSimultaneous);
fprintf('  Mutual exclusion = %s\n',passfail(mutualExclusionPASS));

%% 6. Cycle-level green conversion
nCycles = ceil((tPart8(end)+1e-9)/cycle);
conversionError = zeros(nCycles,3);

for c = 1:nCycles
    idx = cycleIndex == c;
    if ~any(idx)
        continue;
    end

    gRef = greenHistPart8(find(idx,1,'first'),:);
    gSwitch = sum(S(idx,:),1)*dt;

    conversionError(c,:) = abs(gSwitch-gRef);
end

maxConversionError  = max(conversionError(:));
meanConversionError = mean(conversionError(:));

% Because the simulation uses a 1 s grid, a 1 s boundary discretization
% tolerance is acceptable.
conversionPASS = maxConversionError <= dt + 1e-9;

fprintf('\nSwitching conversion:\n');
fprintf('  Maximum discrete conversion error = %.6e s\n',maxConversionError);
fprintf('  Mean discrete conversion error = %.6e s\n',meanConversionError);
fprintf('  Conversion = %s\n',passfail(conversionPASS));

%% 7. Reconstruct queue dynamics using the EXACT Part 8 update order
%
% This section intentionally mirrors Part 8:
%
%   arrival(1:3) = demand
%   departure(feeding branch) = min(capacity, q/dt) if active
%   arrival(4) = departure(active)
%   departure(4) = min(capacity(4),q(4)/dt)
%   qNext = max(0,q + dt*(arrival-departure))
%
% In particular, newly arriving vehicles do NOT depart from B1/B2/B3
% during the same time step. This matches the frozen Part 8 implementation.

qSwitch = zeros(N,net.nBranches);
resSwitch = zeros(N,net.nBranches);

for k = 1:N
    tNow = tPart8(k);

    if tNow >= surgeStart && tNow < surgeEnd
        demand = surgeDemand;
    else
        demand = normalDemand;
    end

    active = find(S(k,:),1,'first');

    arrival = zeros(1,net.nBranches);
    departure = zeros(1,net.nBranches);

    % External demand
    arrival(1:3) = demand;

    % Feeding branches
    for b = net.feedingBranches
        if b == active
            departure(b) = min(cap(b),qSwitch(k,b)/dt);
        else
            departure(b) = 0;
        end
    end

    % Active branch -> B4
    if active > 0
        arrival(4) = departure(active);
    end

    % B4 -> Goldwins
    departure(4) = min(cap(4),qSwitch(k,4)/dt);

    % Conservation update
    qNext = max(0,qSwitch(k,:) + dt*(arrival-departure));

    resSwitch(k,:) = arrival - departure - ...
        (qNext-qSwitch(k,:))/dt;

    if k < N
        qSwitch(k+1,:) = qNext;
    end
end

%% 8. Direct comparison with the frozen Part 8 trajectory
queueError = qSwitch-qHistPart8;

maxQueueAbsError    = max(abs(queueError(:)));
meanQueueAbsError   = mean(abs(queueError(:)));
maxTotalQueueError  = max(abs(sum(qSwitch,2)-sum(qHistPart8,2)));
meanTotalQueueError = mean(abs(sum(qSwitch,2)-sum(qHistPart8,2)));
maxB1Error          = max(abs(qSwitch(:,1)-qHistPart8(:,1)));

totalPart8 = sum(qHistPart8,2);
totalSwitch = sum(qSwitch,2);

peakPart8 = max(totalPart8);
peakSwitch = max(totalSwitch);
peakError = abs(peakSwitch-peakPart8);

trajectoryPASS = maxQueueAbsError <= 1e-9 && ...
                 maxTotalQueueError <= 1e-9 && ...
                 maxB1Error <= 1e-9;

fprintf('\nQueue trajectory comparison:\n');
fprintf('  Max absolute queue error = %.6e veh\n',maxQueueAbsError);
fprintf('  Mean absolute queue error = %.6e veh\n',meanQueueAbsError);
fprintf('  Max total queue error = %.6e veh\n',maxTotalQueueError);
fprintf('  Mean total queue error = %.6e veh\n',meanTotalQueueError);
fprintf('  Max B1 queue error = %.6e veh\n',maxB1Error);
fprintf('  Part 8 peak total queue = %.3f veh\n',peakPart8);
fprintf('  Switching peak total queue = %.3f veh\n',peakSwitch);
fprintf('  Peak error = %.6e veh\n',peakError);
fprintf('  Queue trajectory equivalence = %s\n',passfail(trajectoryPASS));

%% 9. Conservation comparison
maxResidualPart8 = max(abs(residualPart8(:)));
maxResidualSwitch = max(abs(resSwitch(:)));
residualDifference = max(abs(resSwitch(:)-residualPart8(:)));

conservationPASS = maxResidualPart8 <= 1e-10 && ...
                   maxResidualSwitch <= 1e-10 && ...
                   residualDifference <= 1e-10;

fprintf('\nConservation comparison:\n');
fprintf('  Part 8 maximum residual = %.6e\n',maxResidualPart8);
fprintf('  Switching maximum residual = %.6e\n',maxResidualSwitch);
fprintf('  Residual-history difference = %.6e\n',residualDifference);
fprintf('  Conservation equivalence = %s\n',passfail(conservationPASS));

%% 10. Recovery-time comparison
threshold = 5.0;

maskAfter = tPart8 >= surgeEnd;

idx8 = find(maskAfter & totalPart8 <= threshold,1,'first');
idxS = find(maskAfter & totalSwitch <= threshold,1,'first');

if isempty(idx8)
    recoveryPart8 = NaN;
else
    recoveryPart8 = tPart8(idx8)-surgeEnd;
end

if isempty(idxS)
    recoverySwitch = NaN;
else
    recoverySwitch = tPart8(idxS)-surgeEnd;
end

if isnan(recoveryPart8) && isnan(recoverySwitch)
    recoveryError = 0;
elseif ~isnan(recoveryPart8) && ~isnan(recoverySwitch)
    recoveryError = abs(recoveryPart8-recoverySwitch);
else
    recoveryError = Inf;
end

recoveryPASS = recoveryError <= dt + 1e-9;

fprintf('\nRecovery comparison:\n');
fprintf('  Part 8 recovery = %.3f s after surge end\n',recoveryPart8);
fprintf('  Switching recovery = %.3f s after surge end\n',recoverySwitch);
fprintf('  Recovery-time error = %.6f s\n',recoveryError);
fprintf('  Recovery equivalence = %s\n',passfail(recoveryPASS));

%% 11. Overall Step 9.3 decision
overallPASS = greenConstraintPASS && ...
              mutualExclusionPASS && ...
              conversionPASS && ...
              trajectoryPASS && ...
              conservationPASS && ...
              recoveryPASS;

fprintf('\n============================================================\n');
fprintf('PART 9 - STEP 9.3 RESULTS\n');
fprintf('============================================================\n');
fprintf('  Green constraints        = %s\n',passfail(greenConstraintPASS));
fprintf('  Mutual exclusion         = %s\n',passfail(mutualExclusionPASS));
fprintf('  Switching conversion     = %s\n',passfail(conversionPASS));
fprintf('  Queue trajectory         = %s\n',passfail(trajectoryPASS));
fprintf('  Conservation equivalence = %s\n',passfail(conservationPASS));
fprintf('  Recovery equivalence     = %s\n',passfail(recoveryPASS));
fprintf('------------------------------------------------------------\n');
fprintf('STEP 9.3 OVERALL = %s\n',passfail(overallPASS));
fprintf('============================================================\n');

%% 12. Required figures
figure('Name','Part 9 Step 9.3 - Total Queue Equivalence');
plot(tPart8,totalPart8,'LineWidth',1.5);
hold on;
plot(tPart8,totalSwitch,'--','LineWidth',1.5);
xline(surgeStart,':');
xline(surgeEnd,':');
grid on;
xlabel('Time [s]');
ylabel('Total Queue [veh]');
title('Part 9 Step 9.3 — Part 8 vs Switching Total Queue');
legend('Part 8 reference','Switching representation', ...
       'Surge start','Surge end','Location','best');

figure('Name','Part 9 Step 9.3 - B1 Queue Equivalence');
plot(tPart8,qHistPart8(:,1),'LineWidth',1.5);
hold on;
plot(tPart8,qSwitch(:,1),'--','LineWidth',1.5);
xline(surgeStart,':');
xline(surgeEnd,':');
grid on;
xlabel('Time [s]');
ylabel('B1 Queue [veh]');
title('Part 9 Step 9.3 — B1 Queue Equivalence');
legend('Part 8 reference','Switching representation', ...
       'Surge start','Surge end','Location','best');

figure('Name','Part 9 Step 9.3 - Queue Error');
plot(tPart8,max(abs(queueError),[],2),'LineWidth',1.5);
grid on;
xlabel('Time [s]');
ylabel('Maximum Absolute Queue Error [veh]');
title('Part 9 Step 9.3 — Queue Trajectory Error');

figure('Name','Part 9 Step 9.3 - Conservation Residual');
plot(tPart8,max(abs(residualPart8),[],2),'LineWidth',1.5);
hold on;
plot(tPart8,max(abs(resSwitch),[],2),'--','LineWidth',1.5);
grid on;
xlabel('Time [s]');
ylabel('Maximum Absolute Conservation Residual');
title('Part 9 Step 9.3 — Conservation Residual Equivalence');
legend('Part 8 reference','Switching representation','Location','best');

%% 13. Standardized outputs for later work
qHistPart9Switching = qSwitch;
residualPart9Switching = resSwitch;
timePart9 = tPart8;
switchingStatePart9 = state;
switchingCommandsPart9 = S;
conversionErrorPart9 = conversionError;

fprintf('\nStandardized Step 9 variables created:\n');
fprintf('  qHistPart8\n');
fprintf('  qHistPart9Switching\n');
fprintf('  residualPart8\n');
fprintf('  residualPart9Switching\n');
fprintf('  timePart9\n');
fprintf('  switchingStatePart9\n');
fprintf('  switchingCommandsPart9\n');
fprintf('  conversionErrorPart9\n');

%% Local helper
function out = passfail(tf)
    if tf
        out = 'PASS';
    else
        out = 'FAIL';
    end
end
