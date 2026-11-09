function [qNext, arrival, departure, res] = bl_plant_step(q, arrRate, active, net, dt, t)
%BL_PLANT_STEP  One step of the SITRA 4-branch queue plant.
%
%   Same equations and the same update order as the frozen Part 8 loop
%   (part8_mpc_controller.m, section 7) and the S2 queueStep block:
%
%     dep(b) = min(cap(b), q(b)/dt)  if b == active (B1..B3), else 0
%     arr(4) = dep(active)
%     dep(4) = min(cap(4), q(4)/dt)
%     qNext  = max(0, q + dt*(arr - dep))
%
%   arrRate is the external arrival RATE on B1..B3 for this step
%   (vehicles in the step divided by dt).  Electrical reading (S5):
%   q = capacitor voltage (1 F), arrival/departure = branch currents.

if nargin < 6 || isempty(t), t = 0; end

if isfield(net, 'capFcn') && ~isempty(net.capFcn)
    cap = net.capFcn(t);
else
    cap = net.capacity;
end

% Blockage / spill-back: if B4 queue reaches q4max, B1..B3 cannot discharge
blocked = isfield(net, 'q4max') && ~isempty(net.q4max) && (q(4) >= net.q4max - 1e-4);

arrival = zeros(1,net.nBranches);
departure = zeros(1,net.nBranches);
arrival(1:3) = arrRate;

for b = net.feedingBranches
    if b == active && ~blocked
        departure(b) = min(cap(b), q(b)/dt);
    else
        departure(b) = 0;
    end
end

if active > 0 && ~blocked
    arrival(4) = departure(active);
else
    arrival(4) = 0;
end

departure(4) = min(cap(4), q(4)/dt);

qNext = max(0, q + dt*(arrival - departure));
res = arrival - departure - (qNext - q)/dt;
end
