%% ============================================================
% PART 8 — PREDICTIVE / MPC TRAFFIC SIGNAL CONTROLLER
% =============================================================

clear;
clc;
close all;

%% ============================================================
% 1. NETWORK
% =============================================================

net = createNetwork();

%% ============================================================
% 2. SIMULATION
% =============================================================

dt = 1.0;
T = 600;

tVec = 0:dt:T;
N = numel(tVec);

%% ============================================================
% 3. DEMAND
% =============================================================

normalDemand = [0.10 0.07 0.05];

surgeDemand = [0.30 0.07 0.05];

surgeStart = 200;
surgeEnd   = 400;

%% ============================================================
% 4. MPC PARAMETERS
% =============================================================

mpcParams.yellow = 3;

mpcParams.cycleLength = 63;

mpcParams.minGreen = 12;

mpcParams.maxGreen = 30;

% Prediction horizon
mpcParams.predictionCycles = 3;

% Objective weights
mpcParams.wTotal = 1.0;

mpcParams.wB1 = 0.5;

mpcParams.wDelta = 0.02;

%% ============================================================
% 5. INITIAL QUEUE
% ============================================================

q = zeros(1,net.nBranches);

%% ============================================================
% 6. STORAGE
% ============================================================

qHist = zeros(N,net.nBranches);

residual = zeros(N,net.nBranches);

activeHist = zeros(1,N);

greenHist = zeros(N,3);

demandHist = zeros(N,3);

%% ============================================================
% 7. MAIN LOOP
% ============================================================

for k = 1:N

    t = tVec(k);

    %% --------------------------------------------------------
    % Demand
    % ---------------------------------------------------------

    if t >= surgeStart && t < surgeEnd

        demand = surgeDemand;

    else

        demand = normalDemand;

    end

    demandHist(k,:) = demand;

    %% --------------------------------------------------------
    % MPC controller
    % ---------------------------------------------------------

    [active,greenTimes] = mpcSignalModel( ...
        t, ...
        q, ...
        net, ...
        mpcParams, ...
        demand);

    activeHist(k) = active;

    greenHist(k,:) = greenTimes;

    %% --------------------------------------------------------
    % Actual network simulation
    % ---------------------------------------------------------

    arrival = zeros(1,net.nBranches);

    departure = zeros(1,net.nBranches);

    %% External demand

    arrival(1:3) = demand;

    %% Feeding branches

    for b = net.feedingBranches

        if b == active

            departure(b) = min( ...
                net.capacity(b), ...
                q(b)/dt);

        else

            departure(b) = 0;

        end

    end

    %% Active branch -> B4

    if active > 0

        arrival(4) = departure(active);

    end

    %% B4 -> Goldwins

    departure(4) = min( ...
        net.capacity(4), ...
        q(4)/dt);

    %% --------------------------------------------------------
    % Queue conservation
    % ---------------------------------------------------------

    qNext = max( ...
        0, ...
        q + dt*(arrival-departure));

    %% --------------------------------------------------------
    % Conservation residual
    % ---------------------------------------------------------

    residual(k,:) = ...
        arrival ...
        - departure ...
        - (qNext-q)/dt;

    %% --------------------------------------------------------
    % Store
    % ---------------------------------------------------------

    qHist(k,:) = q;

    %% --------------------------------------------------------
    % Update
    % ---------------------------------------------------------

    q = qNext;

end

%% ============================================================
% 8. TOTAL QUEUE
% =============================================================

totalQueue = sum(qHist,2);

%% ============================================================
% 9. TIME WINDOWS
% =============================================================

beforeMask = tVec < surgeStart;

duringMask = ...
    tVec >= surgeStart & ...
    tVec < surgeEnd;

afterMask = tVec >= surgeEnd;

%% ============================================================
% 10. STATISTICS
% =============================================================

meanBefore = mean(totalQueue(beforeMask));

meanDuring = mean(totalQueue(duringMask));

meanAfter = mean(totalQueue(afterMask));

maxTotal = max(totalQueue);

maxB1 = max(qHist(:,1));

finalTotal = totalQueue(end);

finalB1 = qHist(end,1);

overallResidual = max(abs(residual(:)));

%% ============================================================
% 11. GREEN STATISTICS
% =============================================================

minGreenObserved = min(greenHist);

maxGreenObserved = max(greenHist);

%% ============================================================
% 12. RECOVERY
% =============================================================

threshold = 5.0;

postTimes = tVec(afterMask);

postQueue = totalQueue(afterMask);

idx = find(postQueue <= threshold,1,'first');

if isempty(idx)

    recoveryTime = NaN;

else

    recoveryTime = postTimes(idx) - surgeEnd;

end

%% ============================================================
% 13. OUTPUT
% =============================================================

fprintf('\n');
fprintf('====================================================\n');
fprintf('PART 8 — PREDICTIVE / MPC CONTROLLER\n');
fprintf('====================================================\n');

fprintf('\nSimulation:\n');

fprintf('Duration = %.1f s\n',T);

fprintf('Time step = %.1f s\n',dt);

fprintf('Cycle = %.1f s\n',mpcParams.cycleLength);

fprintf('Prediction horizon = %d cycles\n', ...
    mpcParams.predictionCycles);

fprintf('\nDemand:\n');

fprintf('Normal = [%.3f %.3f %.3f] veh/s\n', ...
    normalDemand);

fprintf('Surge = [%.3f %.3f %.3f] veh/s\n', ...
    surgeDemand);

fprintf('Surge interval = %.1f -> %.1f s\n', ...
    surgeStart,surgeEnd);

fprintf('\n----------------------------------------------------\n');
fprintf('MPC QUEUE RESULTS\n');
fprintf('----------------------------------------------------\n');

fprintf('Mean total queue BEFORE surge = %.3f veh\n', ...
    meanBefore);

fprintf('Mean total queue DURING surge = %.3f veh\n', ...
    meanDuring);

fprintf('Mean total queue AFTER surge  = %.3f veh\n', ...
    meanAfter);

fprintf('Maximum total queue           = %.3f veh\n', ...
    maxTotal);

fprintf('Maximum B1 queue              = %.3f veh\n', ...
    maxB1);

fprintf('Final total queue             = %.3f veh\n', ...
    finalTotal);

fprintf('Final B1 queue                = %.3f veh\n', ...
    finalB1);

fprintf('\n----------------------------------------------------\n');
fprintf('GREEN-TIME VALIDATION\n');
fprintf('----------------------------------------------------\n');

fprintf('B1 green range = %.2f -> %.2f s\n', ...
    minGreenObserved(1), ...
    maxGreenObserved(1));

fprintf('B2 green range = %.2f -> %.2f s\n', ...
    minGreenObserved(2), ...
    maxGreenObserved(2));

fprintf('B3 green range = %.2f -> %.2f s\n', ...
    minGreenObserved(3), ...
    maxGreenObserved(3));

fprintf('\n----------------------------------------------------\n');
fprintf('RECOVERY\n');
fprintf('----------------------------------------------------\n');

fprintf('Congestion threshold = %.2f veh\n',threshold);

if isnan(recoveryTime)

    fprintf('Recovery = NOT REACHED\n');

else

    fprintf('Recovery = %.1f s after surge end\n', ...
        recoveryTime);

end

fprintf('\n----------------------------------------------------\n');
fprintf('CONSERVATION\n');
fprintf('----------------------------------------------------\n');

fprintf('Maximum residual = %.3e\n', ...
    overallResidual);

fprintf('\n====================================================\n');
fprintf('PART 8 SIMULATION COMPLETE\n');
fprintf('====================================================\n');

%% ============================================================
% 14. FIGURE 1 — TOTAL QUEUE
% =============================================================

figure('Name','Part 8 - MPC Total Queue');

plot(tVec,totalQueue,'LineWidth',1.6);

hold on;

yline(threshold,'--','Congestion Threshold');

xline(surgeStart,'--','Surge Start');

xline(surgeEnd,'--','Surge End');

hold off;

xlabel('Time [s]');
ylabel('Total Network Queue [veh]');

title('Part 8 — Predictive MPC Total Queue');

legend( ...
    'MPC Total Queue', ...
    'Congestion Threshold', ...
    'Surge Start', ...
    'Surge End', ...
    'Location','best');

grid on;

%% ============================================================
% 15. FIGURE 2 — B1 QUEUE
% =============================================================

figure('Name','Part 8 - MPC B1 Queue');

plot(tVec,qHist(:,1),'LineWidth',1.6);

hold on;

xline(surgeStart,'--','Surge Start');

xline(surgeEnd,'--','Surge End');

hold off;

xlabel('Time [s]');
ylabel('B1 Queue [veh]');

title('Part 8 — Predictive MPC B1 Queue');

legend( ...
    'MPC B1 Queue', ...
    'Surge Start', ...
    'Surge End', ...
    'Location','best');

grid on;

%% ============================================================
% 16. FIGURE 3 — MPC GREEN ALLOCATION
% =============================================================

figure('Name','Part 8 - MPC Green Allocation');

plot(tVec,greenHist,'LineWidth',1.4);

xlabel('Time [s]');
ylabel('Allocated Green Time [s]');

title('Part 8 — MPC Green-Time Allocation');

legend( ...
    'B1 green', ...
    'B2 green', ...
    'B3 green', ...
    'Location','best');

grid on;

%% ============================================================
% 17. FIGURE 4 — DEMAND
% =============================================================

figure('Name','Part 8 - MPC Demand');

plot(tVec,demandHist,'LineWidth',1.3);

xlabel('Time [s]');
ylabel('Demand [veh/s]');

title('Part 8 — External Demand Profile');

legend( ...
    'B1 demand', ...
    'B2 demand', ...
    'B3 demand', ...
    'Location','best');

grid on;