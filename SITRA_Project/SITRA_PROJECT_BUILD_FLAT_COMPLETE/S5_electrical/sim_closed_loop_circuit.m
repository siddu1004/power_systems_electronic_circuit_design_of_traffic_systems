function R_cl = sim_closed_loop_circuit(ctrlName, A, p, net)
%% SIM_CLOSED_LOOP_CIRCUIT
% Simulates Stage 3 Closed-Loop: The digital controller reads physical
% capacitor voltages from voltage sensors, decides active phase, maps to
% semiconductor gates via S4 contract, and commutates the physical circuit switches.
%
% Inputs:
%   ctrlName : 'SITRA' or 'Actuated' (or other baselines)
%   A        : Arrival struct from bl_make_arrivals()
%   p        : Parameter struct from bl_config()
%   net      : Network struct from createNetwork()

switch lower(ctrlName)
    case 'sitra',       f = @bl_ctrl_sitra;
    case 'webster',     f = @bl_ctrl_webster;
    case 'actuated',    f = @bl_ctrl_actuated;
    case 'maxpressure', f = @bl_ctrl_maxpressure;
    otherwise, error('sim_closed_loop_circuit: unknown controller "%s"', ctrlName);
end

dt = p.dt;
tVec = A.tVec;
N = numel(tVec);

% Detector preprocessing for actuated control
cum = cumsum(A.count, 1);
cumPrev = [zeros(1,3); cum(1:end-1,:)];
veh = floor(cum + 1e-9) - floor(cumPrev + 1e-9);

if strcmpi(p.web.designFlow, 'peak')
    design = max(A.rate, [], 1);
else
    design = mean(A.rate, 1);
end

% Circuit components
C = [1.0 1.0 1.0 1.0];
cap = net.capacity;

% State initialization
v_C = zeros(N, 4);
activeHist = zeros(1, N);
gates = zeros(N, 3);
I_in = zeros(N, 4);
I_dep = zeros(N, 4);
I_bus = zeros(N, 1);
residual = zeros(N, 4);

v_current = p.q0;
st = [];

for k = 1:N
    t = tVec(k);
    
    % 1. Controller reads physical capacitor voltages (V_C1..V_C4)
    q_sensor = v_current;
    v_C(k, :) = v_current;
    
    % Controller info packet
    info.rate = A.rate(k, :);
    info.design = design;
    if k > 1
        info.vehPrev = veh(k-1, :);
    else
        info.vehPrev = zeros(1, 3);
    end
    
    % 2. Controller executes control law on capacitor voltage feedback
    [active, st] = f(t, q_sensor, info, st, p, net);
    activeHist(k) = active;
    
    % 3. S4 Gate Contract: At most one gate active, all off during clearance
    g = bl_gates(active);
    gates(k, :) = g;
    
    % 4. Layer A Physical Circuit Dynamics (Sample-and-hold current discharge)
    i_in_step = zeros(1, 4);
    i_in_step(1:3) = A.count(k, :) / dt;
    
    i_dep_step = zeros(1, 4);
    for b = 1:3
        if g(b) > 0.5
            i_dep_step(b) = min(cap(b), v_current(b) / dt);
        end
    end
    
    i_bus = sum(i_dep_step(1:3));
    I_bus(k) = i_bus;
    i_in_step(4) = i_bus;
    
    % Downstream Goldwins exit
    i_dep_step(4) = min(cap(4), v_current(4) / dt);
    
    % 5. Physical integration across C_b
    v_next = max(zeros(1, 4), v_current + (dt ./ C) .* (i_in_step - i_dep_step));
    res = i_in_step - i_dep_step - (C ./ dt) .* (v_next - v_current);
    
    I_in(k, :) = i_in_step;
    I_dep(k, :) = i_dep_step;
    residual(k, :) = res;
    
    v_current = v_next;
end

R_cl.controller = ctrlName;
R_cl.tVec = tVec;
R_cl.v_C = v_C;
R_cl.activeHist = activeHist;
R_cl.gates = gates;
R_cl.I_in = I_in;
R_cl.I_dep = I_dep;
R_cl.I_bus = I_bus;
R_cl.residual = residual;
R_cl.v_final = v_current;

end
