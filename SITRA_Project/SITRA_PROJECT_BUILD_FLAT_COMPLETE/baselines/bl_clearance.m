function C = bl_clearance(t, Q, tEvent, tBaseWin, holdS, tol)
%BL_CLEARANCE  Time for the total approach queue to return to normal.
%   t        [N x 1] time vector [s]
%   Q        [N x 1] total approach queue B1+B2+B3 [veh]  (or sum of C_B1..C_B3 voltages [V])
%   tEvent   time the overload ends (surge end / step-down / t=0 for T8) [s]
%   tBaseWin [t1 t2] window that defines "normal" queue: Qbase = mean(Q in window)
%   holdS    Q must stay at or below the threshold for this long (default 60 s)
%   tol      threshold above Qbase (default 1 veh)
%
%   C.tClear     seconds after tEvent until Q <= Qbase+tol and stays there holdS (NaN if never)
%   C.cleared    logical
%   C.Qbase      normal queue level
%   C.Qpeak      max Q in the run
%   C.excessVehS trapz over t >= tEvent of max(Q - Qbase, 0)   [veh*s]

if nargin < 5 || isempty(holdS), holdS = 60; end
if nargin < 6 || isempty(tol), tol = 1.0; end

t = t(:);
Q = Q(:);

C = struct('tClear', NaN, 'cleared', false, 'Qbase', NaN, 'Qpeak', max(Q), 'excessVehS', NaN);

if isempty(t) || isempty(Q) || isnan(tEvent) || isempty(tBaseWin) || any(isnan(tBaseWin))
    return;
end

% 1. Compute baseline normal queue level
inWin = (t >= tBaseWin(1)) & (t <= tBaseWin(2));
if any(inWin)
    Qbase = mean(Q(inWin));
else
    Qbase = 0;
end
C.Qbase = Qbase;
threshold = Qbase + tol;

% 2. Compute excess vehicle-seconds after tEvent
idxAfter = find(t >= tEvent);
if ~isempty(idxAfter) && numel(idxAfter) >= 2
    Qafter = Q(idxAfter);
    tafter = t(idxAfter);
    excessQ = max(Qafter - Qbase, 0);
    C.excessVehS = trapz(tafter, excessQ);
else
    C.excessVehS = 0;
end

% 3. Find clearance time
dt = mean(diff(t));
if dt <= 0, dt = 1; end
samplesHold = round(holdS / dt);

cleared = false;
tClear = NaN;

for idx = 1:numel(idxAfter)
    k = idxAfter(idx);
    kEnd = k + samplesHold;
    if kEnd > numel(Q)
        % Run ends before the hold window fits
        break;
    end
    if all(Q(k:kEnd) <= threshold + 1e-9)
        cleared = true;
        tClear = t(k) - tEvent;
        break;
    end
end

C.tClear = tClear;
C.cleared = cleared;

end
