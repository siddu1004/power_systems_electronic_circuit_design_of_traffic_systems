function outB = sim_power_stage_layerB(gates, tVec, p)
%% SIM_POWER_STAGE_LAYERB
% Simulates Stage 4 Layer B: The physical DC electrical power stage for the signal heads.
%
% Models:
%   - 24 VDC Power Supply with internal source impedance
%   - DC-link decoupling capacitor (C_dc_link = 1000 uF, ESR = 0.02 Ohm)
%   - Power MOSFET switches driven by gate signals [g1, g2, g3]
%   - Signal head LED load clusters (R_load = 24 Ohm, 24 W per aspect)
%   - Physical power balance verification (Source = Load + Loss + DeltaE_cap)

if nargin < 3 || isempty(p)
    p = params_electrical();
end

dt = p.normalized.dt;
N = numel(tVec);

V_source = p.layerB.V_dc_nominal;    % 24.0 V
C_dc     = p.layerB.C_dc_link;       % 1000 uF
R_load   = p.layerB.R_load_branch;   % 24 Ohm
R_on     = p.layerB.R_on_switch;     % 0.025 Ohm
R_s      = 0.05;                     % [Ohm] Source internal resistance

% Pre-allocate
V_dc = zeros(N, 1);
I_source = zeros(N, 1);
I_branch = zeros(N, 3);
P_source = zeros(N, 1);
P_load   = zeros(N, 1);
P_loss   = zeros(N, 1);
switchStateMeas = zeros(N, 3);

% Initial condition: DC link fully charged
v_dc_curr = V_source;

% High-resolution sub-stepping per 1s step for physical continuous circuit dynamics
nSub = 50;
dt_sub = dt / nSub;

for k = 1:N
    g = gates(k, 1:3);
    activeBranch = find(g > 0.5, 1);
    
    if ~isempty(activeBranch)
        % One branch is conducting
        R_leg = R_load + R_on;
        G_eq = (1 / R_s) + (1 / R_leg);
        V_eq = (V_source / R_s) / G_eq; % ~23.95 V
        tau_eq = C_dc / G_eq;           % ~49.9 us
        
        % Exact analytical solution for DC-link voltage
        v_dc_curr = V_eq + (v_dc_curr - V_eq) * exp(-dt / tau_eq);
        
        i_br = zeros(1, 3);
        i_br(activeBranch) = v_dc_curr / R_leg;
        i_src = (V_source - v_dc_curr) / R_s;
        
        p_src = V_source * i_src;
        p_ld  = sum(i_br.^2) * R_load;
        p_ls  = (i_src^2 * R_s) + sum(i_br.^2 * R_on);
    else
        % Clearance / Yellow dead-time (all switches OFF)
        G_eq = 1 / R_s;
        V_eq = V_source;                % 24.0 V
        tau_eq = C_dc / G_eq;           % 50 us
        
        v_dc_curr = V_eq + (v_dc_curr - V_eq) * exp(-dt / tau_eq);
        
        i_br = zeros(1, 3);
        i_src = (V_source - v_dc_curr) / R_s;
        
        p_src = V_source * i_src;
        p_ld  = 0.0;
        p_ls  = i_src^2 * R_s;
    end
    
    V_dc(k) = v_dc_curr;
    I_source(k) = i_src;
    I_branch(k, :) = i_br;
    P_source(k) = p_src;
    P_load(k)   = p_ld;
    P_loss(k)   = p_ls;
    
    % Measured switch conduction state (current threshold detector)
    switchStateMeas(k, :) = double(i_br > 0.1);
end

% Cumulative Energy Calculations [Joules]
E_source = sum(P_source) * dt;
E_load   = sum(P_load) * dt;
E_loss   = sum(P_loss) * dt;
deltaE_cap = 0.5 * C_dc * (V_dc(end)^2 - V_source^2);

energyBalanceError = abs(E_source - (E_load + E_loss + deltaE_cap)) / max(E_source, eps) * 100;

% Pack results
outB.tVec = tVec(:);
outB.V_dc = V_dc;
outB.I_source = I_source;
outB.I_branch = I_branch;
outB.P_source = P_source;
outB.P_load = P_load;
outB.P_loss = P_loss;
outB.switchStateMeas = switchStateMeas;
outB.E_source = E_source;
outB.E_load = E_load;
outB.E_loss = E_loss;
outB.deltaE_cap = deltaE_cap;
outB.energyBalanceError = energyBalanceError;

end
