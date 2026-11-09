%% ============================================================
% PART 5 — DEMAND SURGE SCENARIO
% =============================================================
%
% Purpose:
% Introduce a controlled traffic demand surge into the validated
% Part 4 fixed-time baseline.
%
% IMPORTANT:
% Part 4 fixedsignalbaseline.m is NOT modified.
%
% Controller:
% Controller 0 — Fixed-Time Signal
%
% Normal demand:
% B1 = 0.100 veh/s
% B2 = 0.070 veh/s
% B3 = 0.050 veh/s
%
% Stress demand:
% B1 = 0.300 veh/s
% B2 = 0.070 veh/s
% B3 = 0.050 veh/s
%
% Stress interval:
% 200 s <= t <= 400 s
%
% =============================================================

clear;
clc;
close all;

%% ============================================================
% 1. CREATE NETWORK
% =============================================================

net = createNetwork();

%% ============================================================
% 2. SIMULATION SETTINGS
% =============================================================

dt = 1.0;

T = 600;

tVec = 0:dt:T;

N = numel(tVec);

%% ============================================================
% 3. SIGNAL PARAMETERS
% =============================================================

sigParams = struct( ...
    'green',18, ...
    'yellow',3);

%% ============================================================
% 4. NORMAL DEMAND
% =============================================================

normalDemand = [ ...
    0.10 ...
    0.07 ...
    0.05];

%% ============================================================
% 5. SURGE DEMAND
% =============================================================

surgeDemand = [ ...
    0.30 ...
    0.07 ...
    0.05];

%% ============================================================
% 6. SURGE TIME WINDOW
% =============================================================

surgeStart = 200;

surgeEnd = 400;

%% ============================================================
% 7. INITIAL QUEUES
% =============================================================

q = zeros(1,net.nBranches);

%% ============================================================
% 8. STORAGE
% =============================================================

qHist = zeros(N,net.nBranches);

arrivalHist = zeros(N,net.nBranches);

departureHist = zeros(N,net.nBranches);

residual = zeros(N,net.nBranches);

activeHist = zeros(1,N);

demandHist = zeros(N,3);

%% ============================================================
% 9. MAIN SIMULATION LOOP
% =============================================================

for k = 1:N

    % Current time
    t = tVec(k);

    % ---------------------------------------------------------
    % Select demand
    % ---------------------------------------------------------

    if t >= surgeStart && t <= surgeEnd

        demand = surgeDemand;

    else

        demand = normalDemand;

    end

    % Store demand
    demandHist(k,:) = demand;

    % ---------------------------------------------------------
    % Signal state
    % ---------------------------------------------------------

    active = signalModel(t,net,sigParams);

    activeHist(k) = active;

    % ---------------------------------------------------------
    % Initialize flows
    % ---------------------------------------------------------

    arrival = zeros(1,net.nBranches);

    departure = zeros(1,net.nBranches);

    % ---------------------------------------------------------
    % External arrivals
    % ---------------------------------------------------------

    arrival(1) = demand(1);

    arrival(2) = demand(2);

    arrival(3) = demand(3);

    % ---------------------------------------------------------
    % Upstream branch departures
    % ---------------------------------------------------------
    %
    % Only the currently green approach can discharge.

    for b = net.feedingBranches

        if b == active

            departure(b) = min( ...
                net.capacity(b), ...
                q(b)/dt);

        else

            departure(b) = 0;

        end

    end

    % ---------------------------------------------------------
    % Flow entering B4
    % ---------------------------------------------------------

    if active > 0

        arrival(4) = departure(active);

    else

        arrival(4) = 0;

    end

    % ---------------------------------------------------------
    % B4 discharge toward Goldwins
    % ---------------------------------------------------------

    departure(4) = min( ...
        net.capacity(4), ...
        q(4)/dt);

    % ---------------------------------------------------------
    % QUEUE UPDATE
    % ---------------------------------------------------------

    qNext = q + dt*(arrival-departure);

    % Prevent negative queues
    qNext = max(qNext,0);

    % ---------------------------------------------------------
    % CONSERVATION RESIDUAL
    % ---------------------------------------------------------

    residual(k,:) = ...
        arrival ...
        - departure ...
        - (qNext-q)/dt;

    % ---------------------------------------------------------
    % SAVE RESULTS
    % ---------------------------------------------------------

    qHist(k,:) = q;

    arrivalHist(k,:) = arrival;

    departureHist(k,:) = departure;

    % ---------------------------------------------------------
    % UPDATE QUEUE
    % ---------------------------------------------------------

    q = qNext;

end

%% ============================================================
% 10. TOTAL NETWORK QUEUE
% =============================================================

totalQueue = sum(qHist,2);

%% ============================================================
% 11. CONGESTION ANALYSIS
% =============================================================

% B1 queue before surge
beforeSurge = tVec < surgeStart;

% During surge
duringSurge = ...
    tVec >= surgeStart & ...
    tVec <= surgeEnd;

% After surge
afterSurge = tVec > surgeEnd;

meanQueueBefore = mean(totalQueue(beforeSurge));

meanQueueDuring = mean(totalQueue(duringSurge));

meanQueueAfter = mean(totalQueue(afterSurge));

maxQueue = max(totalQueue);

maxB1Queue = max(qHist(:,1));

%% ============================================================
% 12. CONGESTION ONSET
% =============================================================

% Define a simple measurable congestion threshold.
%
% Threshold = 5 vehicles total network queue.

congestionThreshold = 5.0;

congested = totalQueue >= congestionThreshold;

firstCongestionIndex = find(congested,1,'first');

if isempty(firstCongestionIndex)

    congestionOnset = NaN;

else

    congestionOnset = ...
        tVec(firstCongestionIndex);

end

%% ============================================================
% 13. CONGESTION DURATION
% =============================================================

congestionDuration = ...
    sum(congested)*dt;

%% ============================================================
% 14. MAXIMUM CONSERVATION ERROR
% =============================================================

maxResidual = max(abs(residual),[],'all');

%% ============================================================
% 15. COMMAND WINDOW REPORT
% =============================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('PART 5 — DEMAND SURGE SCENARIO\n');
fprintf('====================================================\n');

fprintf('\n');

fprintf('Simulation duration = %.1f s\n',T);

fprintf('Time step = %.1f s\n',dt);

fprintf('\n');

fprintf('Signal parameters:\n');

fprintf('Green  = %.1f s\n',sigParams.green);

fprintf('Yellow = %.1f s\n',sigParams.yellow);

fprintf('Cycle  = %.1f s\n', ...
    3*(sigParams.green + sigParams.yellow));

fprintf('\n');

fprintf('Normal demand:\n');

fprintf('B1 = %.3f veh/s\n',normalDemand(1));

fprintf('B2 = %.3f veh/s\n',normalDemand(2));

fprintf('B3 = %.3f veh/s\n',normalDemand(3));

fprintf('\n');

fprintf('Surge demand:\n');

fprintf('B1 = %.3f veh/s\n',surgeDemand(1));

fprintf('B2 = %.3f veh/s\n',surgeDemand(2));

fprintf('B3 = %.3f veh/s\n',surgeDemand(3));

fprintf('\n');

fprintf('Surge interval:\n');

fprintf('%.1f s -> %.1f s\n', ...
    surgeStart,surgeEnd);

fprintf('\n');

fprintf('B1 signal-limited average service:\n');

B1_signal_capacity = ...
    net.capacity(1) * ...
    sigParams.green / ...
    (3*(sigParams.green + sigParams.yellow));

fprintf('%.4f veh/s\n',B1_signal_capacity);

fprintf('\n');

fprintf('Maximum conservation residual:\n');

for b = 1:net.nBranches

    fprintf( ...
        '  %-35s %.3e\n', ...
        net.branchNames{b}, ...
        max(abs(residual(:,b))));

end

fprintf('\n');

fprintf('Overall maximum residual = %.3e\n', ...
    maxResidual);

fprintf('\n');

fprintf('Queue statistics:\n');

fprintf('Mean total queue BEFORE surge = %.3f veh\n', ...
    meanQueueBefore);

fprintf('Mean total queue DURING surge = %.3f veh\n', ...
    meanQueueDuring);

fprintf('Mean total queue AFTER surge = %.3f veh\n', ...
    meanQueueAfter);

fprintf('\n');

fprintf('Maximum total queue = %.3f veh\n', ...
    maxQueue);

fprintf('Maximum B1 queue = %.3f veh\n', ...
    maxB1Queue);

fprintf('\n');

if isnan(congestionOnset)

    fprintf('Congestion onset = not reached\n');

else

    fprintf('Congestion onset = %.1f s\n', ...
        congestionOnset);

end

fprintf('Congestion duration = %.1f s\n', ...
    congestionDuration);

fprintf('\n');

fprintf('Final queues:\n');

fprintf( ...
    '[B1 B2 B3 B4] = [%.3f %.3f %.3f %.3f] veh\n', ...
    qHist(end,1), ...
    qHist(end,2), ...
    qHist(end,3), ...
    qHist(end,4));

%% ============================================================
% 16. FIGURE 1 — NETWORK QUEUES
% =============================================================

figure('Name','Part 5 - Network Queues');

plot( ...
    tVec, ...
    qHist, ...
    'LineWidth',1.3);

legend( ...
    net.branchNames, ...
    'Location','northoutside', ...
    'Orientation','horizontal');

xlabel('Time [s]');

ylabel('Queue [veh]');

title('Part 5 — Network Queues Under Demand Surge');

grid on;

%% ============================================================
% 17. FIGURE 2 — TOTAL QUEUE
% =============================================================

figure('Name','Part 5 - Total Queue');

plot( ...
    tVec, ...
    totalQueue, ...
    'LineWidth',1.6);

hold on;

yline( ...
    congestionThreshold, ...
    '--', ...
    'Congestion Threshold');

xline( ...
    surgeStart, ...
    '--', ...
    'Surge Start');

xline( ...
    surgeEnd, ...
    '--', ...
    'Surge End');

hold off;

xlabel('Time [s]');

ylabel('Total Network Queue [veh]');

title('Part 5 — Total Queue During Demand Surge');

legend( ...
    'Total Queue', ...
    'Congestion Threshold', ...
    'Surge Start', ...
    'Surge End', ...
    'Location','best');

grid on;

%% ============================================================
% 18. FIGURE 3 — DEMAND
% =============================================================

figure('Name','Part 5 - Demand Profile');

plot( ...
    tVec, ...
    demandHist, ...
    'LineWidth',1.3);

legend( ...
    {'B1 demand','B2 demand','B3 demand'}, ...
    'Location','northoutside', ...
    'Orientation','horizontal');

xlabel('Time [s]');

ylabel('Demand [veh/s]');

title('Part 5 — External Demand Profile');

grid on;

%% ============================================================
% 19. FIGURE 4 — SIGNAL STATE
% =============================================================

figure('Name','Part 5 - Signal State');

stairs( ...
    tVec, ...
    activeHist, ...
    'LineWidth',1.2);

yticks([0 1 2 3]);

yticklabels({ ...
    'Yellow / Clear', ...
    'B1 Green', ...
    'B2 Green', ...
    'B3 Green'});

xlabel('Time [s]');

ylabel('Signal State');

title('Part 5 — Fixed-Time Signal State');

grid on;

%% ============================================================
% 20. FINAL VALIDATION
% =============================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('PART 5 VALIDATION CHECK\n');
fprintf('====================================================\n');

if maxResidual < 1e-10

    fprintf('1. Conservation        = PASS\n');

else

    fprintf('1. Conservation        = FAIL\n');

end

if maxB1Queue > 5

    fprintf('2. Demand surge effect = PASS\n');

else

    fprintf('2. Demand surge effect = CHECK\n');

end

if meanQueueDuring > meanQueueBefore

    fprintf('3. Queue increase      = PASS\n');

else

    fprintf('3. Queue increase      = FAIL\n');

end

fprintf('\n');

fprintf('PART 5 experiment complete.\n');

fprintf('Do NOT design the new controller yet.\n');

fprintf('Inspect the four figures and Command Window results.\n');

fprintf('\n');