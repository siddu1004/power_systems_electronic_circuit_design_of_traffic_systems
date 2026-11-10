%% PARAMS_PARASITICS.M
% Centralized parameters for Stage S6 (Capacitor Parasitics & Degradation)
% and Stage S7 (Semiconductor Switching & Gate-Driver Dynamics).
%
% Layer A: Normalized traffic equivalence (1 F, 1 V = 1 veh, 1 A = 1 veh/s).
% Layer B & Parasitics: Real physical engineering representations (marked PLACEHOLDER for S12).

function p = params_parasitics()

%% 1. Normalized Queue Storage Capacitors (Layer A)
p.C_nom = [1.0, 1.0, 1.0, 1.0];             % [F] Factual normalized capacitance (1 F = 1 veh/V)
p.C_init = [0.0, 0.0, 0.0, 0.0];            % [V] Initial queue voltages

%% 2. Capacitor Parasitics & Line Impedance (Stage S6 - PLACEHOLDER for S12)
% Modeled after low-ESR ultra-capacitor / active capacitor filter cells
p.R_esr_nom = [5e-3, 5e-3, 5e-3, 5e-3];     % [Ohm] Nominal Equivalent Series Resistance (5 mOhm)
p.L_esl     = [10e-9, 10e-9, 10e-9, 10e-9]; % [H] Equivalent Series Inductance (10 nH)
p.R_leak    = [10e6, 10e6, 10e6, 10e6];     % [Ohm] Dielectric leakage parallel resistance (10 MOhm)
p.R_line    = 10e-3;                         % [Ohm] PCB trace and distribution bus resistance (10 mOhm)
p.L_line    = 20e-9;                         % [H] PCB trace parasitic inductance (20 nH)

% Wear-out / Degradation scenario (End-of-Life condition)
p.esr_degradation_factor = 2.0;              % 200% ESR increase under accelerated thermal wear-out

%% 3. Semiconductor MOSFET Switch Parameters (Stage S7 - PLACEHOLDER for S12)
% Selected based on required power MOSFET electrical characteristics (S12 sizing rule)
p.V_ds_max = 40.0;                           % [V] Maximum drain-source voltage rating
p.I_d_max  = 30.0;                           % [A] Continuous drain current rating at 25 degC
p.R_dson   = 0.025;                          % [Ohm] On-state channel resistance (25 mOhm at Vgs = 10V)
p.V_th     = 2.5;                            % [V] Gate threshold voltage (2.5 V)
p.Q_g      = 45e-9;                          % [C] Total gate charge (45 nC)
p.C_oss    = 280e-12;                        % [F] Output capacitance (280 pF)

% Switching Dynamic Timings
p.t_rise   = 30e-9;                          % [s] Current rise time (30 ns)
p.t_fall   = 25e-9;                          % [s] Current fall time (25 ns)
p.t_don    = 45e-9;                          % [s] Turn-on delay time (45 ns)
p.t_doff   = 75e-9;                          % [s] Turn-off delay time (75 ns)

%% 4. Gate Driver Parameters (Stage S7 - PLACEHOLDER for S12)
% Required gate driver characteristics (S12 sizing rule)
p.V_gate_drive = 12.0;                       % [V] Gate drive nominal voltage
p.R_gate_ext   = 10.0;                       % [Ohm] External gate series damping resistor
p.I_source_max = 4.0;                        % [A] Peak pull-up sourcing capability
p.I_sink_max   = 4.0;                        % [A] Peak pull-down sinking capability
p.t_dead_min   = 100e-9;                     % [s] Hardware guaranteed dead-time interlock (100 ns)

%% 5. Thermal & Packaging Metrics (Stage S7 - PLACEHOLDER for S12)
% Surface-mount thermal model
p.R_theta_jc = 1.1;                          % [degC/W] Junction-to-case thermal resistance
p.R_theta_ca = 35.0;                         % [degC/W] Case-to-ambient on standard 1-oz copper PCB
p.R_theta_ja = p.R_theta_jc + p.R_theta_ca;  % [degC/W] Total junction-to-ambient (36.1 degC/W)
p.T_ambient  = 40.0;                         % [degC] Ambient operational temperature (SITRA outdoor cabinet)
p.T_j_max    = 150.0;                        % [degC] Maximum silicon junction rating

%% 6. Power Stage Electrical Operating Point (from S5 params)
p.V_source = 24.0;                           % [V] DC bus voltage
p.R_load   = 24.0;                           % [Ohm] 24 W Signal-head LED aspect load
p.dt_traffic = 1.0;                          % [s] Traffic discrete-time step

end
