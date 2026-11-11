function [active, greenTimes] = mpcSignalModel(t, q, net, params, demand)
% MPC-style supervisory signal model used by Part 8.
% Returns mutually exclusive active branch and the feasible green allocation.
% This file implements the documented finite-horizon design; keep Part 8 queue
% dynamics unchanged.

n = numel(net.feedingBranches);
yellow = params.yellow;
cycleLength = params.cycleLength;
minGreen = params.minGreen;
maxGreen = params.maxGreen;
totalGreen = cycleLength - n*yellow;

% Candidate allocations at 1-s resolution. Protect B2/B3 minimums.
base = minGreen*ones(1,n);
remaining = totalGreen - sum(base);

% Use current queues and demand as a simple predictive priority score.
q3 = max(q(1:n),0);
d = max(demand(:).',0);
score = q3 + 10*d;
score(2:3) = score(2:3) + 0.25;

% Allocate remaining seconds greedily to the highest score while respecting max.
greenTimes = base;
for s = 1:round(remaining)
    room = maxGreen - greenTimes;
    [m,idx] = max(score .* (room > 1e-12));
    if m <= 0
        break;
    end
    greenTimes(idx) = greenTimes(idx) + 1;
    % Diminishing return prevents starving the other approaches.
    score(idx) = score(idx) * 0.985 + 1e-12;
end

% Correct any rounding mismatch without violating bounds.
diffGreen = totalGreen - sum(greenTimes);
while abs(diffGreen) > 1e-12
    if diffGreen > 0
        room = maxGreen-greenTimes;
        [mx,idx] = max(room);
        if mx <= 0, break; end
        add = min(diffGreen,mx);
        greenTimes(idx)=greenTimes(idx)+add;
        diffGreen=totalGreen-sum(greenTimes);
    else
        room = greenTimes-minGreen;
        [mx,idx] = max(room);
        if mx <= 0, break; end
        sub = min(-diffGreen,mx);
        greenTimes(idx)=greenTimes(idx)-sub;
        diffGreen=totalGreen-sum(greenTimes);
    end
end

% Phase timing uses the chosen allocation for the current cycle.
tau = mod(t,cycleLength);
current = 0;
active = 0;
order = 1:n;
for p = 1:n
    b = order(p);
    gEnd = current + greenTimes(b);
    yEnd = gEnd + yellow;
    if tau >= current && tau < gEnd
        active = net.feedingBranches(b);
        return;
    elseif tau >= gEnd && tau < yEnd
        active = 0;
        return;
    end
    current = yEnd;
end
end
