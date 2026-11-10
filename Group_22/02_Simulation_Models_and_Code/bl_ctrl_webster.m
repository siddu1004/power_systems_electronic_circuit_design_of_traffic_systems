function [active, st] = bl_ctrl_webster(t, q, info, st, p, net) %#ok<INUSL>
%BL_CTRL_WEBSTER  Webster fixed-time plan (pre-timed, no detection).
%
%   Plan computed once from the design flows (info.design):
%     y_i = flow_i / s_i      s_i = approach capacity (saturation flow)
%     Y   = sum(y_i)          L = n*(yellow + startLost)
%     C0  = (1.5 L + 5) / (1 - Y)          clamped to [Cmin, Cmax]
%     g_i = (C0 - L) * y_i / Y             rounded to 1 s, >= minGreen
%   If Y >= 0.95 the formula blows up, so C = Cmax is used.
%   Phase order B1 -> B2 -> B3, yellow after each.  Same plan all run.
%
%   Note: Webster only sees the approach capacities.  The downstream B4
%   bottleneck (0.45 veh/s) is not in the formula, which is the textbook
%   method's known blind spot for this network.

if isempty(st)
    st = websterPlan(info.design, p, net);
end

tau = mod(t, st.C);
active = 0;
cur = 0;
for i = 1:3
    gEnd = cur + st.green(i);
    if tau >= cur && tau < gEnd
        active = net.feedingBranches(i);
        return;
    end
    cur = gEnd + p.yellow;   % yellow -> active stays 0
end
end

function st = websterPlan(flow, p, net)
s = net.capacity(1:3);
y = flow(:).' ./ s;
Y = sum(y);
n = 3;
L = n*(p.yellow + p.web.startLost);

if Y < 0.95
    C0 = (1.5*L + 5) / (1 - Y);
else
    C0 = p.web.Cmax;
end
C0 = min(max(C0, p.web.Cmin), p.web.Cmax);

if Y > 0
    g = (C0 - n*p.yellow) * y / Y;
else
    g = (C0 - n*p.yellow) * ones(1,n)/n;
end
g = max(round(g), p.web.minGreen);

st.name  = 'Webster';
st.green = g;
st.C     = sum(g) + n*p.yellow;    % actual cycle after rounding/floors
st.Y     = Y;
st.C0    = C0;
end
