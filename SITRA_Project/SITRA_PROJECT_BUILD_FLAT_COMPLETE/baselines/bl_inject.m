function varargout = bl_inject(action, varargin)
%BL_INJECT  Congestion injector: events, network, demand, sensor and signal faults.
%
%   Supported event types:
%     'surge'            sudden rise in demand (mag = fraction, e.g. 1.0 = double)
%     'platoon'          pulse arrivals (mag = veh per pulse, extra.period = seconds)
%     'incident'         capacity loss at stop line (mag = fraction lost)
%     'blockage'         spill-back / B4 exit limited (mag = fraction lost, extra.q4max = max B4 queue)
%     'sensor_stuck'     detector frozen at value at tStart
%     'sensor_noise'     noisy detector (mag = sigma in veh)
%     'signal_stuck_off' signal head / driver fault (gate forced to 0)
%
%   Usage:
%     ev = bl_inject('create', type, branch, tStart, tEnd, mag, extra)
%     A  = bl_inject('apply_demand', A, events)
%     net = bl_inject('apply_network', net, events)
%     [qSeen, sState] = bl_inject('apply_sensor', q, t, events, sState)
%     gates = bl_inject('apply_gates', gates, t, events)
%     active = bl_inject('apply_active', active, t, events)

switch lower(action)
    case 'create'
        varargout{1} = create_event(varargin{:});
    case 'apply_demand'
        varargout{1} = apply_demand(varargin{:});
    case 'apply_network'
        varargout{1} = apply_network(varargin{:});
    case 'apply_sensor'
        [qSeen, sState] = apply_sensor(varargin{:});
        varargout{1} = qSeen;
        if nargout > 1
            varargout{2} = sState;
        end
    case 'apply_gates'
        varargout{1} = apply_gates(varargin{:});
    case 'apply_active'
        varargout{1} = apply_active(varargin{:});
    otherwise
        error('bl_inject: unknown action "%s"', action);
end

end

function ev = create_event(type, branch, tStart, tEnd, mag, extra)
if nargin < 5 || isempty(mag), mag = 0; end
if nargin < 6 || isempty(extra), extra = struct(); end

ev = struct('type', lower(type), 'branch', branch, ...
            'tStart', tStart, 'tEnd', tEnd, 'mag', mag, 'extra', extra);
end

function A = apply_demand(A, events)
if isempty(events), return; end
dt = mean(diff(A.tVec));
if dt <= 0, dt = 1; end

for k = 1:numel(events)
    e = events(k);
    inWindow = (A.tVec >= e.tStart - 1e-9) & (A.tVec < e.tEnd - 1e-9);
    b = e.branch;
    
    switch e.type
        case 'surge'
            if b >= 1 && b <= 3
                A.rate(inWindow, b)  = A.rate(inWindow, b) * (1 + e.mag);
                A.count(inWindow, b) = A.count(inWindow, b) * (1 + e.mag);
            end
            
        case 'platoon'
            if b >= 1 && b <= 3
                period = 60;
                if isfield(e.extra, 'period') && ~isempty(e.extra.period)
                    period = e.extra.period;
                end
                pulseVeh = e.mag;
                for i = find(inWindow(:)')
                    t = A.tVec(i);
                    dtFromStart = t - e.tStart;
                    if mod(dtFromStart, period) < dt - 1e-9
                        A.count(i, b) = A.count(i, b) + pulseVeh;
                        A.rate(i, b)  = A.rate(i, b) + pulseVeh / dt;
                    end
                end
            end
    end
end
end

function net = apply_network(net, events)
baseCap = net.capacity;
if isempty(events)
    if ~isfield(net, 'capFcn') || isempty(net.capFcn)
        net.capFcn = @(t) repmat(baseCap, numel(t), 1);
    end
    return;
end

capEvents = events(strcmp({events.type}, 'incident') | strcmp({events.type}, 'blockage'));

if isempty(capEvents)
    if ~isfield(net, 'capFcn') || isempty(net.capFcn)
        net.capFcn = @(t) repmat(baseCap, numel(t), 1);
    end
else
    net.capFcn = @(t) eval_capacity(t, baseCap, capEvents);
end

% Check for blockage q4max spill-back limit
blkEvents = events(strcmp({events.type}, 'blockage'));
if ~isempty(blkEvents)
    for k = 1:numel(blkEvents)
        if isfield(blkEvents(k).extra, 'q4max') && ~isempty(blkEvents(k).extra.q4max)
            net.q4max = blkEvents(k).extra.q4max;
            net.blkWindow = [blkEvents(k).tStart, blkEvents(k).tEnd];
        end
    end
end
end

function c = eval_capacity(t, baseCap, capEvents)
if numel(t) == 1
    c = baseCap;
    for k = 1:numel(capEvents)
        e = capEvents(k);
        if t >= e.tStart - 1e-9 && t < e.tEnd - 1e-9
            c(e.branch) = baseCap(e.branch) * (1 - e.mag);
        end
    end
else
    N = numel(t);
    c = repmat(baseCap, N, 1);
    for k = 1:numel(capEvents)
        e = capEvents(k);
        inWin = (t >= e.tStart - 1e-9) & (t < e.tEnd - 1e-9);
        c(inWin, e.branch) = baseCap(e.branch) * (1 - e.mag);
    end
end
end

function [qSeen, sState] = apply_sensor(q, t, events, sState)
if nargin < 4 || isempty(sState)
    sState = struct('frozenVal', nan(1,4), 'isFrozen', false(1,4));
end
qSeen = q;
if isempty(events), return; end

for k = 1:numel(events)
    e = events(k);
    inWindow = (t >= e.tStart - 1e-9) && (t < e.tEnd - 1e-9);
    bList = e.branch;
    
    switch e.type
        case 'sensor_stuck'
            for b = bList
                if inWindow
                    if ~sState.isFrozen(b)
                        sState.frozenVal(b) = q(b);
                        sState.isFrozen(b) = true;
                    end
                    qSeen(b) = sState.frozenVal(b);
                else
                    sState.isFrozen(b) = false;
                end
            end
            
        case 'sensor_noise'
            if inWindow
                sig = e.mag;
                for b = bList
                    % Deterministic Box-Muller pseudo-random normal distribution
                    u1 = mod(sin(t * 12.9898 + b * 78.233) * 43758.5453, 1);
                    u1 = max(1e-12, min(1 - 1e-12, abs(u1)));
                    u2 = mod(cos(t * 4.1414 + b * 26.651) * 24634.6345, 1);
                    u2 = max(1e-12, min(1 - 1e-12, abs(u2)));
                    z = sqrt(-2 * log(u1)) * cos(2 * pi * u2);
                    noise = sig * z;
                    qSeen(b) = max(0, q(b) + noise);
                end
            end
    end
end
end

function gates = apply_gates(gates, varargin)
if nargin == 2
    events = varargin{1};
    t = (0:size(gates, 1)-1)';
elseif nargin >= 3
    t = varargin{1};
    events = varargin{2};
else
    return;
end

if isempty(events), return; end
for k = 1:numel(events)
    e = events(k);
    if strcmp(e.type, 'signal_stuck_off')
        b = e.branch;
        if b >= 1 && b <= size(gates, 2)
            if isscalar(t)
                if t >= e.tStart - 1e-9 && t < e.tEnd - 1e-9
                    gates(b) = 0;
                end
            else
                mask = (t >= e.tStart - 1e-9) & (t < e.tEnd - 1e-9);
                gates(mask, b) = 0;
            end
        end
    end
end
end

function active = apply_active(active, t, events)
if isempty(events), return; end
for k = 1:numel(events)
    e = events(k);
    if strcmp(e.type, 'signal_stuck_off')
        if t >= e.tStart - 1e-9 && t < e.tEnd - 1e-9
            if active == e.branch
                active = 0;
            end
        end
    end
end
end
