function p = params_electrical()
%% PARAMS_ELECTRICAL
% Single repository for all electrical parameters in Layer A and Layer B.
%
% RULE ENFORCEMENT:
%   - Normalized Layer A values (1 F, 1 V = 1 veh, 1 A = 1 veh/s) are FACTUAL.
%   - Layer B hardware ratings are strictly marked PLACEHOLDER and will be
%     sized rigorously in Stage S12.

%% 1. Layer A: Normalized Traffic Equivalent Circuit (FACTUAL)
p.normalized.C = [1.0, 1.0, 1.0, 1.0];   % [F] 1 Farad per branch (B1..B4): 1 V = 1 vehicle, 1 C = 1 vehicle
p.normalized.dt = 1.0;                   % [s] Discrete traffic update time step
p.normalized.yellow = 3.0;               % [s] Clearance interval (all switches OFF)
p.normalized.q0 = [0.0, 0.0, 0.0, 0.0];  % [V] Initial capacitor voltages (zero initial queue)

% Capacities loaded dynamically from createNetwork() - NEVER hardcoded
net = createNetwork();
p.normalized.cap = net.capacity;         % [A] Saturation flow limits [0.65 0.35 0.25 0.45] A

%% 2. Layer B: Power Stage & Hardware Representation (ALL PLACEHOLDER)
% DC Supply / Bus
p.layerB.V_dc_nominal = 24.0;
% [V] PLACEHOLDER: Nominal DC bus voltage for intersection signal head drive.
% S12 Sizing Rule: Selected according to industrial roadside traffic signal standards (24 VDC or 48 VDC).

p.layerB.C_dc_link = 1000e-6;
% [F] PLACEHOLDER: DC-link energy storage / decoupling capacitor.
% S12 Sizing Rule: Sized from peak current step Delta_I = 2 A and max allowable voltage dip:
% C >= (I_load * Delta_t) / Delta_V_max for Delta_V_max < 0.02 * V_dc.

p.layerB.R_dc_esr = 0.02;
% [Ohm] PLACEHOLDER: DC-link capacitor equivalent series resistance.
% S12 Sizing Rule: Sized from capacitor ripple current rating and thermal heating limits.

% Semiconductor Switches (MOSFET/IGBT Legs for Phase S1, S2, S3)
p.layerB.R_on_switch = 0.025;
% [Ohm] PLACEHOLDER: Switch on-state resistance (e.g. automotive N-channel power MOSFET).
% S12 Sizing Rule: Sized from conduction loss P_cond = I_rms^2 * R_on to operate without heatsink (< 1 W).

p.layerB.V_gate_drive = 10.0;
% [V] PLACEHOLDER: Gate-source driver output voltage level.
% S12 Sizing Rule: Sized from selected MOSFET standard V_gs threshold for complete saturation.

p.layerB.t_hardware_deadtime = 3.0;
% [s] FACTUAL: Maps directly to 3.0 s traffic yellow clearance. S4 gate contract ensures all OFF.

% Branch Loads (Traffic Signal Heads)
p.layerB.R_load_branch = 24.0;
% [Ohm] PLACEHOLDER: Nominal branch load resistance (1.0 A at 24 V -> 24 W LED aspect).
% S12 Sizing Rule: Sized from standard LED traffic signal optical head wattage (typically 15 W - 30 W).

% Protection Ratings
p.layerB.I_overcurrent_trip = 2.0;
% [A] PLACEHOLDER: Overcurrent detection trip threshold.
% S12 Sizing Rule: Sized to 150% of maximum steady-state branch current with 50 ms trip delay.

p.layerB.V_undervoltage_trip = 18.0;
% [V] PLACEHOLDER: DC bus undervoltage fault threshold (sag/dropout).
% S12 Sizing Rule: Sized to 75% of nominal 24 V rail to initiate immediate fail-safe all-red clearance.

p.layerB.V_overvoltage_trip = 30.0;
% [V] PLACEHOLDER: DC bus overvoltage trip threshold.
% S12 Sizing Rule: Sized to 125% of nominal rail to protect gate driver ICs and MOSFET breakdown voltage.

end
