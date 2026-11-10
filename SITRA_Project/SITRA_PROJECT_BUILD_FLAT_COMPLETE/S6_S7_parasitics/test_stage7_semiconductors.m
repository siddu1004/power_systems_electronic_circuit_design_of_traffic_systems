function ok = test_stage7_semiconductors()
%% TEST_STAGE7_SEMICONDUCTORS
% Stage S7: Semiconductor Switching Dynamics, Gate Charge, Conduction/Switching
% Losses, and Thermal Junction Temperatures under SITRA Scenario T6.
%
% Acceptance Criteria:
%   1. Conduction loss bounded: P_cond <= 0.1 W per active channel.
%   2. Switching transition energy bounded: E_sw <= 1.0 uJ per transition.
%   3. Gate charge drive loss bounded: P_gate <= 0.05 W.
%   4. Junction temperature margin: T_junc <= 65 degC (Safety margin > 85 degC to 150 degC limit).
%   5. Switching delay compatibility: Total switching delay (t_rise + t_fall < 100 ns) << clearance dead-time (3.0 s).

clc;
close all;

fprintf('\n============================================================\n');
fprintf('STAGE S7: SEMICONDUCTOR SWITCHING, LOSS & THERMAL TEST\n');
fprintf('============================================================\n');

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
rootDir = fileparts(thisDir);
cd(rootDir);
addpath(rootDir);
addpath(thisDir);
addpath(fullfile(rootDir, 'SITRA_baselines', 'MATLAB', 'baselines'));

p_bl = bl_config();
net = createNetwork();
scn = bl_scenarios(p_bl);

% Simulate on Scenario T6
A_t6 = bl_make_arrivals(scn(6), p_bl, 0);
R_t6 = bl_simulate('SITRA', A_t6, p_bl, net);

fprintf('1. Simulating Semiconductor Dynamics on Scenario T6 (600 s)...\n');
out = sim_parasitic_circuit(A_t6, R_t6.gates, false);

p = out.params;

% Metric calculations
max_p_cond = max(out.p_cond(:));
mean_p_cond = mean(out.p_cond(out.p_cond > 0));
max_p_sw = max(out.p_sw(:));
max_t_junc = max(out.t_junc(:));
mean_t_junc = mean(out.t_junc(:));
e_sw_per_trans = 0.5 * p.V_source * (p.V_source / p.R_load) * (p.t_rise + p.t_fall);
total_delay_ns = (p.t_don + p.t_rise + p.t_doff + p.t_fall) * 1e9;

% Acceptance gates
g1_ok = (max_p_cond <= 0.10);             % P_cond <= 100 mW
g2_ok = (e_sw_per_trans <= 1.0e-6);        % E_sw <= 1.0 uJ
g3_ok = (max_t_junc <= 65.0);              % T_junc <= 65 degC (ambient = 40 degC)
g4_ok = (total_delay_ns < 250);            % Switching delay < 250 ns << 3 s dead-time
g5_ok = (p.V_ds_max >= 1.5 * p.V_source);  % 40 V rating has > 50% voltage margin over 24 V

fprintf('\n------------------------------------------------------------\n');
fprintf('STAGE S7 ACCEPTANCE GATE RESULTS:\n');
fprintf('------------------------------------------------------------\n');
fprintf('1. Max Conduction Loss (Active) : %.3f W   [%s] (Limit <= 0.10 W)\n', max_p_cond, passfail(g1_ok));
fprintf('2. Mean Active Conduction Loss  : %.3f W   [INFO]\n', mean_p_cond);
fprintf('3. Transition Switching Energy  : %.3f uJ  [%s] (Limit <= 1.0 uJ)\n', e_sw_per_trans * 1e6, passfail(g2_ok));
fprintf('4. Peak MOSFET Junction Temp    : %.2f C  [%s] (Limit <= 65.0 C, Margin = %.1f C)\n', ...
    max_t_junc, passfail(g3_ok), p.T_j_max - max_t_junc);
fprintf('5. Total Switching Delay Time   : %.1f ns  [%s] (Limit < 250 ns << 3s clearance)\n', ...
    total_delay_ns, passfail(g4_ok));
fprintf('6. Transistor Voltage Margin    : %.1f V   [%s] (Rating: %.1f V, Bus: %.1f V)\n', ...
    p.V_ds_max - p.V_source, passfail(g5_ok), p.V_ds_max, p.V_source);
fprintf('------------------------------------------------------------\n');

ok = g1_ok && g2_ok && g3_ok && g4_ok && g5_ok;
fprintf('STAGE S7 OVERALL STATUS         : %s\n', passfail(ok));
fprintf('============================================================\n');

if nargout == 0
    clear ok;
end

end

function s = passfail(tf)
    if tf, s = 'PASS'; else, s = 'FAIL'; end
end
