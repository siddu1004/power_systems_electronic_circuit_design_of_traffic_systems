function C = bl_clearance(t, Q, Qtwin, tEvent, opts)
%BL_CLEARANCE  Time for congested run queue to match twin no-congestion run queue.
%   t       [N x 1] time vector [s]
%   Q       [N x 1] total approach queue B1+B2+B3 for event run [veh]
%   Qtwin   [N x 1] total approach queue B1+B2+B3 for twin run [veh]
%   tEvent  time the overload ends (surge end / step-down / t=0 for T8) [s]
%   opts    struct with options:
%             .W    moving-mean window in seconds (default 120 s)
%             .tol  tolerance in vehicles (default 1.0 veh)
%             .hold hold duration in seconds (default 60 s)
%
%   C.tClear     seconds after tEvent until |Qs - Qts| <= tol and stays for hold (0 if already <= tol at tEvent, NaN if never)
%   C.cleared    logical (~isnan(tClear))
%   C.excessVehS trapz over t >= tEvent of max(Q - Qtwin, 0) [veh*s] (raw, not smoothed)
%   C.peakExcess max(Qs - Qts) over t >= tEvent [veh]
%   C.Qpeak      max Q in the run [veh]
%   C.Qbase      mean Qtwin over t >= tEvent [veh]

if nargin < 5, opts = struct(); end
if ~isfield(opts, 'W')    || isempty(opts.W),    opts.W = 120; end
if ~isfield(opts, 'tol')  || isempty(opts.tol),  opts.tol = 1.0; end
if ~isfield(opts, 'hold') || isempty(opts.hold), opts.hold = 60; end

t = t(:);
Q = Q(:);

C = struct('tClear', NaN, 'cleared', false, 'excessVehS', NaN, ...
           'peakExcess', NaN, 'Qpeak', max([Q; 0]), 'Qbase', NaN);

if isempty(t) || isempty(Q) || isnan(tEvent) || nargin < 3 || isempty(Qtwin)
    return;
end

Qtwin = Qtwin(:);
dt = mean(diff(t));
if dt <= 0, dt = 1; end

% Raw excess vehicle-seconds after tEvent
idxAfter = find(t >= tEvent);
if ~isempty(idxAfter) && numel(idxAfter) >= 2
    Q_after = Q(idxAfter);
    Qtwin_after = Qtwin(idxAfter);
    t_after = t(idxAfter);
    excessRaw = max(Q_after - Qtwin_after, 0);
    C.excessVehS = trapz(t_after, excessRaw);
    C.Qbase = mean(Qtwin_after);
else
    C.excessVehS = 0;
    C.Qbase = mean(Qtwin);
end

% Moving-mean smoothing to remove cyclic signal ripple
wPts = max(1, round(opts.W / dt));
Qs   = movmean(Q,     wPts);
Qts  = movmean(Qtwin, wPts);
d    = Qs - Qts;   % extra queue caused by the event

if ~isempty(idxAfter)
    C.peakExcess = max(d(idxAfter));
else
    C.peakExcess = 0;
end

% Check if already within tolerance at tEvent
samplesHold = round(opts.hold / dt);
firstIdx = idxAfter(1);

% Check clearance: first t >= tEvent where |d| <= tol and stays for hold duration
tClear = NaN;
cleared = false;

for idx = 1:numel(idxAfter)
    k = idxAfter(idx);
    kEnd = k + samplesHold;
    if kEnd > numel(d)
        % Run ends before hold window fits
        break;
    end
    if all(abs(d(k:kEnd)) <= opts.tol + 1e-9)
        cleared = true;
        if k == firstIdx
            tClear = 0;  % Absorbed during overload
        else
            tClear = t(k) - tEvent;
        end
        break;
    end
end

C.tClear = tClear;
C.cleared = cleared;

end
