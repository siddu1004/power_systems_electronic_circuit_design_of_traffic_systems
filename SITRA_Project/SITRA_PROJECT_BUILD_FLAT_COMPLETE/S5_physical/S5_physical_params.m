function S5 = S5_physical_params()
%S5_PHYSICAL_PARAMS  Parameters for SITRA_S5_Physical.slx.
%
%   Two kinds of values live here:
%     * Layer A (traffic equivalent circuit): normalized FACTS of the
%       analogy (1 veh = 1 C, 1 veh/s = 1 A, C = 1 F -> 1 V = 1 veh) and the
%       traffic capacities read from createNetwork.m (ASSUMED traffic values).
%     * Layer B (power path): every value is a PLACEHOLDER. Nothing here is a
%       selected hardware rating. Real ratings are sized in S12 using the
%       rule written next to each value.

net = createNetwork();

% ---------------- Layer A: traffic equivalent circuit (facts) -----------
S5.cap      = net.capacity;   % [A] = [veh/s]  B1 B2 B3 B4 (ASSUMED traffic capacities)
S5.dt       = 1;              % [s] traffic step, same as Part 8
S5.C_queue  = 1;              % [F] 1 F so that 1 V = 1 vehicle (normalized, not a part)
S5.vC0      = [0 0 0 0];      % [V] initial capacitor voltages C_B1..C_B4 (default 0 V)

% ---------------- Layer B: power path (ALL PLACEHOLDER) -----------------
P = struct();
P.Vac_rms   = 230;     % [V]   PLACEHOLDER mains RMS.            S12: local supply standard
P.f_ac      = 50;      % [Hz]  PLACEHOLDER mains frequency.      S12: local supply standard
P.Vsec_rms  = 36;      % [V]   PLACEHOLDER transformer secondary. S12: DC-link target + diode drops + regulation margin
P.R_sec     = 0.2;     % [Ohm] PLACEHOLDER winding/leakage R.    S12: transformer datasheet
P.L_sec     = 0.5e-3;  % [H]   PLACEHOLDER leakage inductance.   S12: transformer datasheet
P.C_dc      = 2200e-6; % [F]   PLACEHOLDER DC-link capacitance.  S12: ripple at full load, hold-up time
P.R_esr     = 0.05;    % [Ohm] PLACEHOLDER DC-link ESR.          S12: capacitor ripple-current rating
P.R_bleed   = 10e3;    % [Ohm] PLACEHOLDER bleed resistor.       S12: discharge-time safety requirement
P.V_bus_ref = 24;      % [V]   PLACEHOLDER signal-head bus.      S12: signal-head supply standard
P.f_sw      = 10e3;    % [Hz]  PLACEHOLDER buck switching freq.  S12: loss vs. magnetics size trade-off
P.L_buck    = 2e-3;    % [H]   PLACEHOLDER buck inductor.        S12: ripple-current target at max Vdc
P.C_out     = 3300e-6; % [F]   PLACEHOLDER bus capacitor.        S12: bus ripple + load-step droop
P.R_damp    = 1;       % [Ohm] PLACEHOLDER RC damper R (~sqrt(L/C)). S12: output-filter damping design
P.C_damp    = 4.7e-3;  % [F]   PLACEHOLDER RC damper C (~2-4x C_out). S12: output-filter damping design
P.R_busbleed= 240;     % [Ohm] PLACEHOLDER bus minimum load.     S12: converter minimum-load requirement
P.R_load    = 24;      % [Ohm] PLACEHOLDER signal-head load (1 A at 24 V). S12: measured lamp/LED-string current
P.R_gate    = 10;      % [Ohm] PLACEHOLDER gate resistor.        S12: switching speed vs EMI
P.V_gate    = 10;      % [V]   PLACEHOLDER gate-drive voltage.   S12: switch gate rating
P.I_trip    = 2;       % [A]   PLACEHOLDER channel over-current trip. S12: protection coordination with load
P.UV_frac   = 0.75;    % [-]   PLACEHOLDER bus under-voltage trip (fraction of ref). S12: signal-head min voltage
P.t_blank   = 0.246;   % [s]   PLACEHOLDER start-up blanking for UV trip. S12: measured start-up time
P.Kp        = 0.03;    % [1/V] PLACEHOLDER buck PI proportional gain. S12: loop design on real L, C
P.Ki        = 25;      % [1/(V s)] PLACEHOLDER buck PI integral gain.
P.D_max     = 0.95;    % [-]   PLACEHOLDER max duty.             S12: driver bootstrap / min off-time
P.Ts_local  = 2e-6;    % [s]   Simscape local-solver step for the power path (numerical, not hardware)
P.xfmr_n    = P.Vsec_rms / P.Vac_rms;   % secondary/primary ratio; the build script maps it to the block's convention
P.xfmr_n_block = P.Vac_rms / P.Vsec_rms;
S5.par = P;
end
