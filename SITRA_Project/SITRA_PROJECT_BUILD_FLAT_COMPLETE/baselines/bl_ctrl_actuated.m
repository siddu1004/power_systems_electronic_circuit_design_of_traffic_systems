function [active, st] = bl_ctrl_actuated(t, q, info, st, p, net) %#ok<INUSL>
%BL_CTRL_ACTUATED  Fully actuated controller with gap-out / max-out.
%
%   Phases B1 -> B2 -> B3, yellow 3 s between phases.
%   Green rules (defaults in bl_config):
%     - every green lasts at least minGreen (10 s)
%     - an actuation resets the gap timer; the green ends when the gap
%       since the last actuation reaches the passage time (3 s) = gap-out
%     - the green never exceeds maxGreen (40 s) = max-out
%   Detector model: the approach is actuated in a step if a whole vehicle
%   crossed its detector in the previous step (info.vehPrev > 0), or if
%   the standing queue still covers the stop-line detector (q >= queueOn).
%   Phase skipping: after yellow the controller goes to the next approach
%   in order that has a call (queue >= queueOn or a vehicle arrived while
%   it was red).  If nobody calls, it serves the next approach anyway
%   (minimum recall), so the cycle never stalls.

a = p.act;
if isempty(st)
    st.name  = 'Actuated';
    st.phase = 1;
    st.mode  = 'green';
    st.timer = 0;       % time in current interval [s]
    st.gap   = 0;       % time since last actuation on the green approach [s]
    st.call  = false(1,3);
end

% Register calls on red approaches
for b = 1:3
    if info.vehPrev(b) > 0 || q(b) >= a.queueOn
        st.call(b) = true;
    end
end

% Yellow finished -> pick next phase with a call
if strcmp(st.mode,'yellow') && st.timer >= p.yellow
    nxt = 0;
    for k = 1:3
        b = mod(st.phase - 1 + k, 3) + 1;
        if st.call(b)
            nxt = b; break;
        end
    end
    if nxt == 0
        nxt = mod(st.phase, 3) + 1;
    end
    st.phase = nxt;
    st.mode  = 'green';
    st.timer = 0;
    st.gap   = 0;
end

% Green: gap-out / max-out test
if strcmp(st.mode,'green')
    b = st.phase;
    st.call(b) = false;
    actuated = info.vehPrev(b) > 0 || q(b) >= a.queueOn;
    if actuated
        st.gap = 0;
    elseif st.timer > 0
        st.gap = st.gap + p.dt;
    end
    maxOut = st.timer >= a.maxGreen;
    gapOut = st.timer >= a.minGreen && st.gap >= a.passage;
    if maxOut || gapOut
        st.mode  = 'yellow';
        st.timer = 0;
    end
end

if strcmp(st.mode,'green')
    active = net.feedingBranches(st.phase);
else
    active = 0;
end
st.timer = st.timer + p.dt;
end
