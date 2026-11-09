function R = bl_simulate(ctrlName, A, p, net)
%BL_SIMULATE  Run one controller on one arrival sequence (integration harness).
%
%   R = bl_simulate('SITRA'|'Webster'|'Actuated'|'MaxPressure', A, p, net)
%
%   A comes from bl_make_arrivals and is SHARED by every controller, so all
%   controllers see identical arrivals, capacities, initial queues (p.q0),
%   duration and seed.  The loop order is the frozen Part 8 order:
%       demand -> controller -> plant update -> store q (pre-update) -> q = qNext
%
%   Output fields (N = number of steps):
%     tVec 1xN, qHist Nx4, activeHist 1xN, gates Nx3, arrHist Nx4,
%     depHist Nx4, residual Nx4, rate Nx3, ctrl (final controller state)

switch lower(ctrlName)
    case 'sitra',       f = @bl_ctrl_sitra;
    case 'webster',     f = @bl_ctrl_webster;
    case 'actuated',    f = @bl_ctrl_actuated;
    case 'maxpressure', f = @bl_ctrl_maxpressure;
    otherwise, error('bl_simulate: unknown controller "%s"', ctrlName);
end

dt = p.dt;
tVec = A.tVec;
N = numel(tVec);

% Whole vehicles crossing the upstream detector each step
cum = cumsum(A.count, 1);
cumPrev = [zeros(1,3); cum(1:end-1,:)];
veh = floor(cum + 1e-9) - floor(cumPrev + 1e-9);

% Design flow for fixed-time plans
if strcmpi(p.web.designFlow, 'peak')
    design = max(A.rate, [], 1);
else
    design = mean(A.rate, 1);
end

q = p.q0;
qHist = zeros(N,4); arrHist = zeros(N,4); depHist = zeros(N,4);
residual = zeros(N,4); activeHist = zeros(1,N); gates = zeros(N,3);
st = [];

for k = 1:N
    t = tVec(k);
    info.rate    = A.rate(k,:);
    info.design  = design;
    if k > 1
        info.vehPrev = veh(k-1,:);
    else
        info.vehPrev = zeros(1,3);
    end

    [active, st] = f(t, q, info, st, p, net);
    gates(k,:) = bl_gates(active);          % S4 contract check every step
    activeHist(k) = active;

    [qNext, arr, dep, res] = bl_plant_step(q, A.count(k,:)/dt, active, net, dt);

    qHist(k,:) = q;
    arrHist(k,:) = arr;
    depHist(k,:) = dep;
    residual(k,:) = res;
    q = qNext;
end

R.controller = ctrlName;
R.tVec = tVec;
R.qHist = qHist;
R.qFinal = q;
R.activeHist = activeHist;
R.gates = gates;
R.arrHist = arrHist;
R.depHist = depHist;
R.residual = residual;
R.rate = A.rate;
R.count = A.count;
R.seed = A.seed;
R.dt = dt;
R.ctrl = st;
end
