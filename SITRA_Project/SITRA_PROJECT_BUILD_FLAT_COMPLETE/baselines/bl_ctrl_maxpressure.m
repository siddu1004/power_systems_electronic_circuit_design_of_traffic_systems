function [active, st] = bl_ctrl_maxpressure(t, q, info, st, p, net) %#ok<INUSL>
%BL_CTRL_MAXPRESSURE  Max-pressure (back-pressure) controller, optional baseline.
%
%   Every 'slot' seconds of green the controller picks the approach with
%   the largest pressure
%       w_i = s_i * (q_i - q_B4)
%   All three approaches discharge into the same branch B4, so q_B4 is
%   common and the choice reduces to argmax s_i*q_i.  If the winner is the
%   current approach, the green continues for another slot (no max green,
%   as in the standard algorithm).  Otherwise a 3 s yellow is inserted.
%   If all approaches are below queueOn, the current green continues.

if isempty(st)
    st.name  = 'MaxPressure';
    st.phase = 1;
    st.mode  = 'green';
    st.timer = 0;
    st.next  = 1;
end

s = net.capacity(1:3);

if strcmp(st.mode,'yellow') && st.timer >= p.yellow
    st.phase = st.next;
    st.mode  = 'green';
    st.timer = 0;
end

if strcmp(st.mode,'green') && st.timer >= p.mp.slot
    qa = q(1:3);
    if any(qa >= p.mp.queueOn)
        w = s .* (qa - q(4));
        [~, best] = max(w);
        if best ~= st.phase
            st.next  = best;
            st.mode  = 'yellow';
        end
    end
    st.timer = 0;       % new slot (or start of yellow)
end

if strcmp(st.mode,'green')
    active = net.feedingBranches(st.phase);
else
    active = 0;
end
st.timer = st.timer + p.dt;
end
