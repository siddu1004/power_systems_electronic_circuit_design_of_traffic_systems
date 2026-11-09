%% PART 4 — FIXED-TIME TRAFFIC SIGNAL BASELINE
%
% Purpose:
% Establish a stable conventional traffic baseline
% before introducing optimization or power-electronics control.
%
% DO NOT START PART 5 UNTIL THIS SCRIPT PASSES.

clear;
clc;
close all;

%% ============================================================
% 1. CREATE NETWORK
% =============================================================

net = createNetwork();

%% ============================================================
% 2. SIMULATION PARAMETERS
% =============================================================

dt = 1.0;       % simulation time step [s]
T  = 600;       % total simulation time [s]

tVec = 0:dt:T;
N = numel(tVec);

%% ============================================================
% 3. TRAFFIC SIGNAL PARAMETERS
% =============================================================

sigParams = struct( ...
    'green',18, ...
    'yellow',3);

%% ============================================================
% 4. TRAFFIC DEMAND
% =============================================================
%
% Demand units:
% veh/s
%
% B1 = HopeCollege -> SITRA
% B2 = Kalapatti   -> SITRA
% B3 = Airport     -> SITRA
%
% These values are intentionally chosen below the
% signal-limited service capacity so that this first
% baseline should remain stable.

demand = [0.10 0.07 0.05];

%% ============================================================
% 5. INITIAL CONDITIONS
% =============================================================

% Queue on every branch
q = zeros(1,net.nBranches);

%% ============================================================
% 6. HISTORY ARRAYS
% =============================================================

qHist = zeros(N,net.nBranches);

arrivalHist = zeros(N,net.nBranches);

departureHist = zeros(N,net.nBranches);

residual = zeros(N,net.nBranches);

activeHist = zeros(1,N);

%% ============================================================
% 7. MAIN SIMULATION LOOP
% =============================================================

for k = 1:N

    % Current simulation time
    t = tVec(k);

    % ---------------------------------------------------------
    % Determine signal state
    % ---------------------------------------------------------

    active = signalModel(t,net,sigParams);

    activeHist(k) = active;

    % ---------------------------------------------------------
    % Initialize arrivals and departures
    % ---------------------------------------------------------

    arrival = zeros(1,net.nBranches);

    departure = zeros(1,net.nBranches);

    % ---------------------------------------------------------
    % External traffic demand
    % ---------------------------------------------------------

    arrival(1:3) = demand;

    % ---------------------------------------------------------
    % Feeding branches B1, B2, B3
    % ---------------------------------------------------------
    %
    % Only the green approach can discharge into B4.

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
    % Active approach feeds B4
    % ---------------------------------------------------------

    if active > 0

        arrival(4) = departure(active);

    else

        arrival(4) = 0;

    end

    % ---------------------------------------------------------
    % B4 exits toward Goldwins
    % ---------------------------------------------------------

    departure(4) = min( ...
        net.capacity(4), ...
        q(4)/dt);

    % ---------------------------------------------------------
    % Queue conservation equation
    % ---------------------------------------------------------

    qNext = max( ...
        0, ...
        q + dt*(arrival - departure));

    % ---------------------------------------------------------
    % Conservation residual
    % ---------------------------------------------------------

    residual(k,:) = ...
        arrival ...
        - departure ...
        - (qNext - q)/dt;

    % ---------------------------------------------------------
    % Store histories
    % ---------------------------------------------------------

    qHist(k,:) = q;

    arrivalHist(k,:) = arrival;

    departureHist(k,:) = departure;

    % ---------------------------------------------------------
    % Update queue
    % ---------------------------------------------------------

    q = qNext;

end

%% ============================================================
% 8. VALIDATION OUTPUT
% =============================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('PART 4 — FIXED-TIME BASELINE VALIDATION\n');
fprintf('====================================================\n');

fprintf('\n');

fprintf('Signal parameters:\n');

fprintf('Green  = %.1f s\n', ...
    sigParams.green);

fprintf('Yellow = %.1f s\n', ...
    sigParams.yellow);

fprintf('Cycle  = %.1f s\n', ...
    3*(sigParams.green + sigParams.yellow));

fprintf('\n');

fprintf('Demand [B1 B2 B3] = ');

fprintf('[%.3f %.3f %.3f] veh/s\n', ...
    demand);

fprintf('\n');

%% ============================================================
% 9. CONSERVATION CHECK
% =============================================================

fprintf('Maximum conservation residual:\n');

for b = 1:net.nBranches

    fprintf('  %-35s %.3e\n', ...
        net.branchNames{b}, ...
        max(abs(residual(:,b))));

end

%% ============================================================
% 10. QUEUE VALIDATION
% =============================================================

fprintf('\n');

fprintf('Final queues [B1 B2 B3 B4] = ');

fprintf('[%.3f %.3f %.3f %.3f] veh\n', ...
    qHist(end,1), ...
    qHist(end,2), ...
    qHist(end,3), ...
    qHist(end,4));

%% ============================================================
% 11. LAST 200 SECOND ANALYSIS
% =============================================================

last200 = tVec >= 400;

totalQueue = sum(qHist,2);

meanLast200 = mean( ...
    totalQueue(last200));

maxLast200 = max( ...
    totalQueue(last200));

fprintf('\n');

fprintf('Mean total queue, last 200 s = %.3f veh\n', ...
    meanLast200);

fprintf('Maximum total queue, last 200 s = %.3f veh\n', ...
    maxLast200);

%% ============================================================
% 12. SIGNAL STATE CHECK
% =============================================================

fprintf('\n');

fprintf('Signal sequence:\n');

fprintf('B1 green -> yellow -> B2 green -> yellow -> ');
fprintf('B3 green -> yellow -> repeat\n');

%% ============================================================
% 13. PLOT 1 — QUEUES
% =============================================================

figure('Name','Part 4 - Network Queues');

plot( ...
    tVec, ...
    qHist, ...
    'LineWidth',1.3);

legend( ...
    net.branchNames, ...
    'Location','northoutside', ...
    'Orientation','horizontal');

xlabel('time [s]');

ylabel('queue [veh]');

title('Network queues — stable fixed-time baseline');

grid on;

%% ============================================================
% 14. PLOT 2 — SIGNAL STATE
% =============================================================

figure('Name','Part 4 - Signal State');

stairs( ...
    tVec, ...
    activeHist, ...
    'LineWidth',1.2);

yticks([0 1 2 3]);

yticklabels({ ...
    'yellow/clear', ...
    'B1', ...
    'B2', ...
    'B3'});

xlabel('time [s]');

ylabel('active branch');

title('Fixed-time signal state');

grid on;

%% ============================================================
% 15. PLOT 3 — TOTAL QUEUE
% =============================================================

figure('Name','Part 4 - Total Network Queue');

plot( ...
    tVec, ...
    totalQueue, ...
    'LineWidth',1.6);

xlabel('time [s]');

ylabel('total network queue [veh]');

title('Total network queue — Part 4 baseline');

grid on;

%% ============================================================
% 16. FINAL MESSAGE
% =============================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('PART 4 SIMULATION FINISHED\n');
fprintf('====================================================\n');

fprintf('\n');

fprintf('IMPORTANT:\n');

fprintf('Inspect the three figures before declaring PASS.\n');

fprintf('\n');

fprintf('Expected:\n');

fprintf('1. Conservation residuals approximately zero.\n');
fprintf('2. Signal sequence must be correct.\n');
fprintf('3. Queues should remain bounded.\n');
fprintf('4. Total queue should not continuously grow.\n');

fprintf('\n');

fprintf('If all four conditions are satisfied:\n');
fprintf('PART 4 = PASS\n');

fprintf('Do NOT start Part 5 until this is confirmed.\n');

fprintf('\n');