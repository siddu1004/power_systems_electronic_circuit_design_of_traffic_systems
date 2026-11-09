%% PART 6 — QUEUE-BASED ADAPTIVE CONTROLLER
%
% Purpose:
% Test the first adaptive traffic controller against the
% Part 5 demand-surge scenario.
%
% IMPORTANT:
% Part 4 fixedsignalbaseline.m is NOT modified.
% Part 5 is NOT modified.
%
% This controller is intentionally simple and interpretable.
%
% Controller principle:
%
%     larger queue -> larger green allocation
%
% This is NOT MPC.
%
% ------------------------------------------------------------

clear;
clc;
close all;

%% -----------------------------------------------------------
% NETWORK
% ------------------------------------------------------------

net = createNetwork();

%% -----------------------------------------------------------
% SIMULATION PARAMETERS
% ------------------------------------------------------------

dt = 1.0;
T  = 600;

tVec = 0:dt:T;
N = numel(tVec);

%% -----------------------------------------------------------
% ADAPTIVE SIGNAL PARAMETERS
% ------------------------------------------------------------

sigParams = struct();

sigParams.yellow = 3;

% Fixed total cycle
sigParams.cycleLength = 63;

% Minimum green for every approach
sigParams.minGreen = 12;

% Maximum green allowed for one approach
sigParams.maxGreen = 30;

%% -----------------------------------------------------------
% DEMAND PROFILE
% ------------------------------------------------------------

normalDemand = [0.10 0.07 0.05];

surgeDemand = [0.30 0.07 0.05];

surgeStart = 200;
surgeEnd   = 400;

%% -----------------------------------------------------------
% INITIAL CONDITIONS
% ------------------------------------------------------------

q = zeros(1,net.nBranches);

%% -----------------------------------------------------------
% HISTORY ARRAYS
% ------------------------------------------------------------

qHist = zeros(N,net.nBranches);

arrivalHist = zeros(N,net.nBranches);

departureHist = zeros(N,net.nBranches);

residual = zeros(N,net.nBranches);

activeHist = zeros(1,N);

demandHist = zeros(N,3);

greenHist = zeros(N,3);

%% -----------------------------------------------------------
% SIMULATION
% ------------------------------------------------------------

for k = 1:N

    t = tVec(k);

    % --------------------------------------------------------
    % Select demand
    % --------------------------------------------------------

    if t >= surgeStart && t < surgeEnd

        demand = surgeDemand;

    else

        demand = normalDemand;

    end

    demandHist(k,:) = demand;

    % --------------------------------------------------------
    % Adaptive signal
    % --------------------------------------------------------

    [active,greenTimes] = adaptiveSignalModel( ...
        t,q,net,sigParams);

    activeHist(k) = active;

    greenHist(k,:) = greenTimes;

    % --------------------------------------------------------
    % Initialize flows
    % --------------------------------------------------------

    arrival = zeros(1,net.nBranches);

    departure = zeros(1,net.nBranches);

    % --------------------------------------------------------
    % External vehicle arrivals
    % --------------------------------------------------------

    arrival(1:3) = demand;

    % --------------------------------------------------------
    % Signal-controlled departures
    % --------------------------------------------------------

    for b = net.feedingBranches

        if b == active

            departure(b) = min( ...
                net.capacity(b), ...
                q(b)/dt);

        else

            departure(b) = 0;

        end

    end

    % --------------------------------------------------------
    % Flow from active approach into B4
    % --------------------------------------------------------

    if active > 0

        arrival(4) = departure(active);

    else

        arrival(4) = 0;

    end

    % --------------------------------------------------------
    % B4 exits toward Goldwins
    % --------------------------------------------------------

    departure(4) = min( ...
        net.capacity(4), ...
        q(4)/dt);

    % --------------------------------------------------------
    % Conservation update
    % --------------------------------------------------------

    qNext = q + dt*(arrival-departure);

    % Queues cannot become negative
    qNext = max(qNext,0);

    % --------------------------------------------------------
    % Conservation residual
    % --------------------------------------------------------

    residual(k,:) = ...
        arrival ...
        - departure ...
        - (qNext-q)/dt;

    % --------------------------------------------------------
    % Store history
    % --------------------------------------------------------

    qHist(k,:) = q;

    arrivalHist(k,:) = arrival;

    departureHist(k,:) = departure;

    % --------------------------------------------------------
    % Advance state
    % --------------------------------------------------------

    q = qNext;

end

%% ============================================================
% VALIDATION / RESULTS
% =============================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('PART 6 — QUEUE-BASED ADAPTIVE CONTROLLER\n');
fprintf('====================================================\n');

fprintf('\nSimulation duration = %.1f s\n',T);
fprintf('Time step = %.1f s\n',dt);

fprintf('\nAdaptive signal parameters:\n');
fprintf('Cycle = %.1f s\n',sigParams.cycleLength);
fprintf('Yellow = %.1f s\n',sigParams.yellow);
fprintf('Minimum green = %.1f s\n',sigParams.minGreen);
fprintf('Maximum green = %.1f s\n',sigParams.maxGreen);

fprintf('\nNormal demand:\n');
fprintf('B1 = %.3f veh/s\n',normalDemand(1));
fprintf('B2 = %.3f veh/s\n',normalDemand(2));
fprintf('B3 = %.3f veh/s\n',normalDemand(3));

fprintf('\nSurge demand:\n');
fprintf('B1 = %.3f veh/s\n',surgeDemand(1));
fprintf('B2 = %.3f veh/s\n',surgeDemand(2));
fprintf('B3 = %.3f veh/s\n',surgeDemand(3));

fprintf('\nSurge interval:\n');
fprintf('%.1f s -> %.1f s\n',surgeStart,surgeEnd);

%% ------------------------------------------------------------
% Conservation
% ------------------------------------------------------------

fprintf('\nMaximum conservation residual:\n');

for b = 1:net.nBranches

    fprintf('  %-35s %.3e\n', ...
        net.branchNames{b}, ...
        max(abs(residual(:,b))));

end

overallResidual = max(abs(residual(:)));

fprintf('\nOverall maximum residual = %.3e\n', ...
    overallResidual);

%% ------------------------------------------------------------
% Queue statistics
% ------------------------------------------------------------

totalQueue = sum(qHist,2);

beforeMask = tVec < surgeStart;

duringMask = ...
    tVec >= surgeStart & ...
    tVec < surgeEnd;

afterMask = tVec >= surgeEnd;

fprintf('\nQueue statistics:\n');

fprintf('Mean total queue BEFORE surge = %.3f veh\n', ...
    mean(totalQueue(beforeMask)));

fprintf('Mean total queue DURING surge = %.3f veh\n', ...
    mean(totalQueue(duringMask)));

fprintf('Mean total queue AFTER surge = %.3f veh\n', ...
    mean(totalQueue(afterMask)));

fprintf('\nMaximum total queue = %.3f veh\n', ...
    max(totalQueue));

fprintf('Maximum B1 queue = %.3f veh\n', ...
    max(qHist(:,1)));

fprintf('\nFinal queues:\n');

fprintf('[B1 B2 B3 B4] = [%.3f %.3f %.3f %.3f] veh\n', ...
    qHist(end,1), ...
    qHist(end,2), ...
    qHist(end,3), ...
    qHist(end,4));

%% ------------------------------------------------------------
% Green-time statistics
% ------------------------------------------------------------

fprintf('\nGreen-time statistics:\n');

fprintf('B1 minimum green observed = %.2f s\n', ...
    min(greenHist(:,1)));

fprintf('B1 maximum green observed = %.2f s\n', ...
    max(greenHist(:,1)));

fprintf('B2 minimum green observed = %.2f s\n', ...
    min(greenHist(:,2)));

fprintf('B2 maximum green observed = %.2f s\n', ...
    max(greenHist(:,2)));

fprintf('B3 minimum green observed = %.2f s\n', ...
    min(greenHist(:,3)));

fprintf('B3 maximum green observed = %.2f s\n', ...
    max(greenHist(:,3)));

%% ============================================================
% VALIDATION CHECK
% =============================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('PART 6 VALIDATION CHECK\n');
fprintf('====================================================\n');

%% Conservation test

if overallResidual < 1e-10

    fprintf('1. Conservation        = PASS\n');

else

    fprintf('1. Conservation        = FAIL\n');

end

%% Adaptive behavior test

if max(greenHist(:,1)) > 18.0

    fprintf('2. Adaptive green      = PASS\n');

else

    fprintf('2. Adaptive green      = FAIL\n');

end

%% Queue response test

beforeMean = mean(totalQueue(beforeMask));
duringMean = mean(totalQueue(duringMask));

if duringMean > beforeMean

    fprintf('3. Queue response      = PASS\n');

else

    fprintf('3. Queue response      = FAIL\n');

end

fprintf('\nPart 6 simulation complete.\n');

fprintf('\nIMPORTANT:\n');
fprintf('Do NOT design MPC yet.\n');
fprintf('Inspect all four figures before declaring Part 6 PASS.\n');

%% ============================================================
% FIGURE 1 — NETWORK QUEUES
% =============================================================

figure('Name','Part 6 - Network Queues');

plot(tVec,qHist,'LineWidth',1.3);

legend(net.branchNames, ...
    'Location','northoutside', ...
    'Orientation','horizontal');

xlabel('Time [s]');
ylabel('Queue [veh]');

title('Part 6 — Network Queues Under Adaptive Control');

grid on;

%% ============================================================
% FIGURE 2 — TOTAL QUEUE
% =============================================================

figure('Name','Part 6 - Total Queue');

plot(tVec,totalQueue,'LineWidth',1.6);

hold on;

yline(5,'--','Congestion Threshold');

xline(surgeStart,'--','Surge Start');

xline(surgeEnd,'--','Surge End');

hold off;

xlabel('Time [s]');
ylabel('Total Network Queue [veh]');

title('Part 6 — Total Queue Under Adaptive Control');

legend('Total Queue', ...
    'Congestion Threshold', ...
    'Surge Start', ...
    'Surge End', ...
    'Location','best');

grid on;

%% ============================================================
% FIGURE 3 — DEMAND PROFILE
% =============================================================

figure('Name','Part 6 - Demand Profile');

plot(tVec,demandHist,'LineWidth',1.3);

legend('B1 demand','B2 demand','B3 demand', ...
    'Location','northoutside', ...
    'Orientation','horizontal');

xlabel('Time [s]');
ylabel('Demand [veh/s]');

title('Part 6 — External Demand Profile');

grid on;

%% ============================================================
% FIGURE 4 — ADAPTIVE GREEN ALLOCATION
% =============================================================

figure('Name','Part 6 - Adaptive Green Allocation');

plot(tVec,greenHist,'LineWidth',1.3);

legend('B1 green','B2 green','B3 green', ...
    'Location','northoutside', ...
    'Orientation','horizontal');

xlabel('Time [s]');
ylabel('Allocated Green Time [s]');

title('Part 6 — Adaptive Green-Time Allocation');

grid on;