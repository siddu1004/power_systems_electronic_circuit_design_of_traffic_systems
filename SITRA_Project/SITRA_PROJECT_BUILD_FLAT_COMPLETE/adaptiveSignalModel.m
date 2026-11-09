function [active, greenTimes] = adaptiveSignalModel(t, q, net, params)
%ADAPTIVESIGNALMODEL Queue-based adaptive traffic signal.
%
% Part 6:
% Allocates green time according to the current queue sizes.
%
% Inputs:
%   t          - current simulation time [s]
%   q          - current queue vector [veh]
%   net        - network structure
%   params     - controller parameters
%
% Outputs:
%   active     - currently active feeding branch
%   greenTimes - green time allocated to B1, B2, B3 [s]
%
% IMPORTANT:
% This controller is intentionally simple.
% It is NOT MPC.
%
% The total cycle remains fixed:
%
%   total green = cycle - 3*yellow
%
% A minimum green is guaranteed for every approach.
% Remaining green time is distributed according to queue size.

% ------------------------------------------------------------
% Parameters
% ------------------------------------------------------------

yellow = params.yellow;
cycleLen = params.cycleLength;

minGreen = params.minGreen;
maxGreen = params.maxGreen;

feedingBranches = net.feedingBranches;

n = numel(feedingBranches);

% Total green available in one cycle
totalGreen = cycleLen - n * yellow;

% ------------------------------------------------------------
% Determine whether we are at the beginning of a new cycle
% ------------------------------------------------------------

cycleIndex = floor(t / cycleLen);

% Store one green-time allocation for each cycle.
% Persistent variables allow the same allocation to be used
% throughout the current cycle.
persistent storedCycle storedGreenTimes storedOrder

if isempty(storedCycle) || storedCycle ~= cycleIndex

    storedCycle = cycleIndex;

    % --------------------------------------------------------
    % Queue values for the three approaches
    % --------------------------------------------------------

    queue = max(q(feedingBranches),0);

    % --------------------------------------------------------
    % Allocate minimum green first
    % --------------------------------------------------------

    greenTimes = ones(1,n) * minGreen;

    remainingGreen = totalGreen - sum(greenTimes);

    % --------------------------------------------------------
    % Queue-based allocation
    % --------------------------------------------------------

    if sum(queue) > 1e-9

        weights = queue / sum(queue);

        additionalGreen = remainingGreen * weights;

        greenTimes = greenTimes + additionalGreen;

    else

        % No queues -> equal allocation
        greenTimes = ones(1,n) * (totalGreen / n);

    end

    % --------------------------------------------------------
    % Enforce maximum green
    % --------------------------------------------------------

    greenTimes = min(greenTimes,maxGreen);

    % --------------------------------------------------------
    % Redistribute any remaining green time if necessary
    % --------------------------------------------------------

    difference = totalGreen - sum(greenTimes);

    if abs(difference) > 1e-9

        available = greenTimes < maxGreen - 1e-9;

        while abs(difference) > 1e-9 && any(available)

            share = difference / sum(available);

            oldValues = greenTimes;

            greenTimes(available) = ...
                min(maxGreen,greenTimes(available) + share);

            actualChange = sum(greenTimes - oldValues);

            difference = totalGreen - sum(greenTimes);

            if abs(actualChange) < 1e-9
                break;
            end

            available = greenTimes < maxGreen - 1e-9;

        end

    end

    storedGreenTimes = greenTimes;

    % --------------------------------------------------------
    % Determine phase order
    %
    % Highest queue receives the first available phase.
    % Remaining approaches follow in descending queue order.
    % --------------------------------------------------------

    [~,storedOrder] = sort(queue,'descend');

else

    greenTimes = storedGreenTimes;

end

% ------------------------------------------------------------
% Determine current phase using the stored cycle allocation
% ------------------------------------------------------------

tau = mod(t,cycleLen);

currentTime = 0;
active = 0;

for phase = 1:n

    branchIndex = storedOrder(phase);

    greenEnd = currentTime + greenTimes(branchIndex);
    yellowEnd = greenEnd + yellow;

    if tau >= currentTime && tau < greenEnd

        active = feedingBranches(branchIndex);
        return;

    elseif tau >= greenEnd && tau < yellowEnd

        active = 0;
        return;

    end

    currentTime = yellowEnd;

end

end