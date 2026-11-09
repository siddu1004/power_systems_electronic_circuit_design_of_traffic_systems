function out = sim_parasitic_circuit(A, gates, degraded_esr)
%% SIM_PARASITIC_CIRCUIT
% Simulates Stage S6 (Capacitor ESR/ESL & Degradation) and Stage S7 (MOSFET
% Switching Dynamics, Conduction/Switching Losses, and Thermal Rise).
%
% Inputs:
%   A            : Arrival structure from bl_make_arrivals()
%   gates        : N x 3 gate matrix from S4 gate contract (bl_gates)
%   degraded_esr : Boolean flag. If true, doubles ESR to model end-of-life wear-out.
%
% Output:
%   out : Structure containing internal vs terminal voltages, ESR voltage drops,
%         conduction/switching losses, thermal profiles, and estimation errors.

if nargin < 3, degraded_esr = false; end

p = params_parasitics();

if degraded_esr
    R_esr = p.R_esr_nom * p.esr_degradation_factor;
else
    R_esr = p.R_esr_nom;
end

N = size(gates, 1);
dt = p.dt_traffic;
cap = [0.65, 0.35, 0.25, 0.45]; % From createNetwork()

% Pre-allocation
v_int       = zeros(N, 4); % Pure internal capacitor electrostatic charge voltage (1 V = 1 veh)
v_term_raw  = zeros(N, 4); % Terminal physical voltage including ESR and leakage
v_term_comp = zeros(N, 4); % Sensor-compensated queue estimate
i_arr_hist  = zeros(N, 4);
i_dep_hist  = zeros(N, 4);
v_esr_drop  = zeros(N, 4);
p_cond      = zeros(N, 3); % MOSFET conduction power [W]
p_sw        = zeros(N, 3); % MOSFET switching loss [W]
t_junc      = zeros(N, 3); % MOSFET junction temperature [degC]

v_curr = p.C_init;
prev_gates = zeros(1, 3);

for k = 1:N
    g = gates(k, :);
    
    % 1. Arrival currents [A] = [veh/s]
    i_arr = zeros(1, 4);
    i_arr(1:3) = A.count(k, :) / dt;
    
    % 2. Sample-and-Hold Departures
    i_dep = zeros(1, 4);
    for b = 1:3
        if g(b) > 0.5
            i_dep(b) = min(cap(b), v_curr(b) / dt);
        end
    end
    i_bus = sum(i_dep(1:3));
    i_arr(4) = i_bus;
    i_dep(4) = min(cap(4), v_curr(4) / dt);
    
    % 3. Dielectric Leakage Current (parallel R_leak)
    i_leak = v_curr ./ p.R_leak;
    
    % 4. Net Capacitor Current
    i_net = i_arr - i_dep - i_leak;
    
    % 5. Internal Electrostatic Integration (Charge state)
    v_next = max(zeros(1, 4), v_curr + (dt ./ p.C_nom) .* (i_arr - i_dep));
    v_int(k, :) = v_curr;
    
    % 6. Physical Terminal Voltage with Parasitic ESR & Leakage
    v_drop = (i_arr - i_dep) .* R_esr;
    v_term_raw(k, :)  = v_curr + v_drop - i_leak * dt;
    v_esr_drop(k, :)  = v_drop;
    
    % 7. Sensor Real-Time ESR Current Compensation
    v_term_comp(k, :) = v_term_raw(k, :) - v_drop + i_leak * dt;
    
    % 8. Stage S7: MOSFET Switching, Conduction & Thermal Model
    % Load current through signal head when gate is active
    i_branch = zeros(1, 3);
    for b = 1:3
        if g(b) > 0.5
            i_branch(b) = p.V_source / (p.R_load + p.R_dson);
        end
    end
    
    % Conduction loss
    p_cond_step = (i_branch .^ 2) * p.R_dson;
    p_cond(k, :) = p_cond_step;
    
    % Switching energy on commutations (transitions)
    transition = (g > 0.5) ~= (prev_gates > 0.5);
    e_sw_step = zeros(1, 3);
    for b = 1:3
        if transition(b)
            % Turn-on or turn-off transition energy
            e_sw_step(b) = 0.5 * p.V_source * (p.V_source / p.R_load) * (p.t_rise + p.t_fall);
        end
    end
    p_sw(k, :) = e_sw_step / dt;
    
    % Gate charge dissipation
    p_gate_step = transition * (p.Q_g * p.V_gate_drive / dt);
    
    % Junction Temperature Rise
    p_tot_step = p_cond_step + p_sw(k, :) + p_gate_step;
    t_junc(k, :) = p.T_ambient + p_tot_step * p.R_theta_ja;
    
    % Updates
    v_curr = v_next;
    prev_gates = g;
    i_arr_hist(k, :) = i_arr;
    i_dep_hist(k, :) = i_dep;
end

% Package Results
out.tVec        = A.tVec;
out.v_int       = v_int;
out.v_term_raw  = v_term_raw;
out.v_term_comp = v_term_comp;
out.v_esr_drop  = v_esr_drop;
out.i_arr       = i_arr_hist;
out.i_dep       = i_dep_hist;
out.p_cond      = p_cond;
out.p_sw        = p_sw;
out.t_junc      = t_junc;
out.params      = p;
out.R_esr       = R_esr;

end
