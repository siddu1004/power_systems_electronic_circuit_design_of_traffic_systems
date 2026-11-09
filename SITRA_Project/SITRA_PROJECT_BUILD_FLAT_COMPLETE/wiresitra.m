%% PART 3 — wire in B2, B3, and SITRA switch logic
%
%   Now all three approaches (B1, B2, B3) feed SITRA, but only ONE can
%   send into B4 at a time -- a simple round-robin switch, equal green
%   time per approach. This is the first version of the "contention"
%   layer; fixed-time proper (with yellow/clearance) comes in Part 4.
%
%   Demand is kept deliberately LOW here (0.10 veh/s each, well under
%   B4's 0.45 veh/s capacity even split three ways) so we can check
%   the switch wiring is correct without congestion confounding the
%   result. Forcing real congestion is Part 5, not this part.

clear; clc; close all;
net = createNetwork();

dt = 1.0;
T  = 300;
tVec = 0:dt:T;
N = numel(tVec);

gPhase   = 20;              % seconds of green per approach
cycleLen = 3*gPhase;        % 60s round-robin cycle, no yellow yet

demand = [0.10 0.10 0.10];  % [B1 B2 B3], veh/s each -- deliberately low

q = zeros(1, net.nBranches);     % [qB1 qB2 qB3 qB4]
qHist = zeros(N, net.nBranches);
residual = zeros(N, net.nBranches);
activeHist = zeros(1, N);

for k = 1:N
    t = tVec(k);

    % --- round-robin switch: which of B1/B2/B3 is active right now ---
    phase = floor(mod(t, cycleLen) / gPhase);   % 0, 1, or 2
    active = net.feedingBranches(phase + 1);    % maps to branch id 1, 2, or 3
    activeHist(k) = active;

    arrival = zeros(1, net.nBranches);
    departure = zeros(1, net.nBranches);

    % B1, B2, B3: arrival from external demand
    arrival(1:3) = demand;

    % Only the active branch can depart into B4 this step
    for b = net.feedingBranches
        if b == active
            departure(b) = min([net.capacity(b), q(b)/dt]);
        else
            departure(b) = 0;
        end
    end

    % B4: arrival = whatever the active branch just sent in
    arrival(4) = departure(active);
    departure(4) = min([net.capacity(4), q(4)/dt]);

    qNext = max(0, q + dt*(arrival - departure));
    residual(k, :) = arrival - departure - (qNext - q)/dt;
    qHist(k, :) = q;
    q = qNext;
end

fprintf('--- PART 3: SITRA switch wiring test ---\n');
fprintf('max |conservation residual|, per branch:\n');
for b = 1:net.nBranches
    fprintf('  %s: %.3e\n', net.branchNames{b}, max(abs(residual(:,b))));
end
fprintf('final queues [B1 B2 B3 B4] = [%.2f %.2f %.2f %.2f] veh\n', qHist(end,:));
fprintf('(all should be small/stable -- demand is well under capacity)\n');

figure('Name', 'Part 3 - SITRA switch validation');
subplot(3,1,1);
plot(tVec, qHist, 'LineWidth', 1.3);
legend(net.branchNames, 'Location', 'northoutside', 'Orientation', 'horizontal');
xlabel('time [s]'); ylabel('queue [veh]');
title('All 4 queues -- each should stay small and roughly periodic');
grid on;

subplot(3,1,2);
stairs(tVec, activeHist, 'k-', 'LineWidth', 1.3);
yticks([1 2 3]); yticklabels({'B1 (HopeCollege)','B2 (Kalapatti)','B3 (Airport)'});
xlabel('time [s]'); ylabel('active branch');
title('Which approach has right-of-way into SITRA -- should cycle every 20s');
grid on;

subplot(3,1,3);
plot(tVec, residual, 'LineWidth', 1);
legend(net.branchNames, 'Location', 'northoutside', 'Orientation', 'horizontal');
xlabel('time [s]'); ylabel('residual');
title('Conservation residual, all branches -- should hug 0');
grid on;