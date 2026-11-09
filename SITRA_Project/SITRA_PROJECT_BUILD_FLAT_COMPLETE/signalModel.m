function active = signalModel(t, net, params)
%SIGNALMODEL Fixed-time 3-phase traffic signal.
%
% Inputs:
%   t      = simulation time [s]
%   net    = network structure
%   params = signal parameters
%
% Output:
%   active = active branch number
%            0 = yellow / clearance
%
% Signal sequence:
%
% B1 GREEN
%    ↓
% YELLOW
%    ↓
% B2 GREEN
%    ↓
% YELLOW
%    ↓
% B3 GREEN
%    ↓
% YELLOW
%    ↓
% REPEAT

% Green duration
g = params.green;

% Yellow / clearance duration
y = params.yellow;

% Duration of one phase
slot = g + y;

% Three phases in one complete cycle
cycleLen = 3 * slot;

% Position inside current cycle
tau = mod(t, cycleLen);

% Determine which phase we are in
phaseIdx = floor(tau / slot);

% Time inside current phase
tauInPhase = tau - phaseIdx * slot;

% Green period
if tauInPhase < g

    active = net.feedingBranches(phaseIdx + 1);

% Yellow / clearance period
else

    active = 0;

end

end