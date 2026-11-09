%% PART 2 — single-branch conservation test (B1: HopeCollege -> SITRA)
%
%   Purpose: prove the core conservation update is correct in isolation
%   before wiring anything else. No signal, no contention -- B1 just
%   receives constant demand and departs at its own capacity.
%
%   Law:  q(k+1) = q(k) + dt * (arrival(k) - departure(k)),  q >= 0
%   Departure is capped by: (a) branch capacity, (b) available queue.

clear; clc; close all;
net = createNetwork();

dt = 1.0;          % seconds
T  = 300;           % total sim time [s]
tVec = 0:dt:T;
N = numel(tVec);

capB1 = net.capacity(1);   % 0.65 veh/s

% Try TWO demand levels in the same run so we can see both regimes:
%   Phase 1 (t < 150s): demand BELOW capacity -> queue should settle near 0
%   Phase 2 (t >= 150s): demand ABOVE capacity -> queue should grow linearly
demandFn = @(t) 0.50 + 0.30*(t >= 150);   % 0.50 veh/s, then 0.80 veh/s

q = 0;                       % initial queue [veh]
qHist = zeros(1, N);
residual = zeros(1, N);

for k = 1:N
    t = tVec(k);
    d = demandFn(t);

    departure = min(capB1, q/dt);          % (a) capacity, (b) available queue
    qNext = max(0, q + dt*(d - departure));

    residual(k) = d - departure - (qNext - q)/dt;   % should be ~0 every step
    qHist(k) = q;
    q = qNext;
end

fprintf('--- PART 2: single-branch B1 test ---\n');
fprintf('B1 capacity = %.2f veh/s\n', capB1);
fprintf('max |conservation residual| = %.3e (should be ~0)\n', max(abs(residual)));
fprintf('queue at t=149s (below capacity)  = %.2f veh (expect ~0)\n', qHist(150));
fprintf('queue at t=300s (above capacity)  = %.2f veh (expect > 0, growing)\n', qHist(end));

figure('Name', 'Part 2 - B1 single-branch validation');
subplot(2,1,1);
plot(tVec, qHist, 'b-', 'LineWidth', 1.5);
xlabel('time [s]'); ylabel('queue B1 [veh]');
title('B1 queue -- should stay ~0 before t=150s, then climb linearly');
grid on;

subplot(2,1,2);
plot(tVec, residual, 'r-');
xlabel('time [s]'); ylabel('residual');
title('Conservation residual (numerical noise only, should hug 0)');
grid on;