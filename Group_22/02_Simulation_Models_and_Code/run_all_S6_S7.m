function pass = run_all_S6_S7()
%% RUN_ALL_S6_S7
% Master runner and acceptance validator for Stages S6 & S7:
%   - Stage S6: Storage Capacitor Parasitics (ESR, ESL, Dielectric Leakage) & 200% Degradation
%   - Stage S7: Power Semiconductor (MOSFET) Switching Dynamics, Loss Breakdown & Thermal Rise

clc;
clearvars -except rootDir mode tMasterStart s5Dir s6s7Dir flatDir;
close all;

fprintf('\n============================================================\n');
fprintf('SITRA STAGES S6 & S7 COMPREHENSIVE VALIDATION SUITE\n');
fprintf('============================================================\n');

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
flatRoot = fileparts(thisDir);
addpath(flatRoot);
addpath(thisDir);
addpath(fullfile(flatRoot, 'baselines'));

outDir = fullfile(flatRoot, 'Results', 'S6_S7');
if ~exist(outDir, 'dir'), mkdir(outDir); end

% Run S6
ok_s6 = test_stage6_parasitics();

% Run S7
ok_s7 = test_stage7_semiconductors();

% Generate Figures
fprintf('\nGenerating S6/S7 physical dynamic figures...\n');
p_bl = bl_config();
net = createNetwork();
scn = bl_scenarios(p_bl);
A_t6 = bl_make_arrivals(scn(6), p_bl, 0);
R_t6 = bl_simulate('SITRA', A_t6, p_bl, net);
out_nom = sim_parasitic_circuit(A_t6, R_t6.gates, false);
out_deg = sim_parasitic_circuit(A_t6, R_t6.gates, true);

t = out_nom.tVec;

% Figure 1: Capacitor ESR drop and sensor compensation
f1 = figure('Visible', 'off');
subplot(2, 1, 1);
plot(t, out_nom.v_term_raw(:, 1), 'r', 'LineWidth', 1.0); hold on;
plot(t, out_nom.v_term_comp(:, 1), 'b--', 'LineWidth', 1.2);
plot(t, R_t6.qHist(:, 1), 'k:', 'LineWidth', 1.0);
ylabel('Branch 1 Queue [V]'); grid on;
legend('Raw Terminal (ESR + Leakage)', 'Compensated Sensor', 'Reference qRef');
title('Stage S6: Capacitor Terminal Voltage & Active ESR Compensation');

subplot(2, 1, 2);
plot(t, out_nom.v_esr_drop(:, 1)*1e3, 'r', 'LineWidth', 1.0); hold on;
plot(t, out_deg.v_esr_drop(:, 1)*1e3, 'm--', 'LineWidth', 1.0);
ylabel('\Delta V_{ESR} [mV]'); xlabel('Time [s]'); grid on;
legend('Nominal ESR (5 m\Omega)', 'Degraded EoL ESR (10 m\Omega)');
title('ESR Voltage Drop Under Dynamic Phase Charging & Discharging');
saveas(f1, fullfile(outDir, 'S6_capacitor_parasitics_compensation.png'));

% Figure 2: Semiconductor power losses and thermal rise
f2 = figure('Visible', 'off');
subplot(2, 1, 1);
plot(t, out_nom.p_cond(:, 1), 'b', 'LineWidth', 1.0); hold on;
plot(t, out_nom.p_sw(:, 1), 'r', 'LineWidth', 1.0);
ylabel('Power [W]'); grid on;
legend('Conduction Loss P_{cond}', 'Switching Loss P_{sw}');
title('Stage S7: MOSFET Dynamic Power Dissipation (Branch 1)');

subplot(2, 1, 2);
plot(t, out_nom.t_junc(:, 1), 'r', 'LineWidth', 1.2); hold on;
yline(out_nom.params.T_j_max, 'k--', 'Max Silicon Limit (150 ^\circC)');
yline(out_nom.params.T_ambient, 'g:', 'Ambient (40 ^\circC)');
ylabel('T_{junction} [^\circC]'); xlabel('Time [s]'); grid on;
legend('Junction Temp T_j', 'Silicon Limit', 'Cabinet Ambient');
title('MOSFET Junction Thermal Equilibrium (TO-263 / D2PAK Model)');
saveas(f2, fullfile(outDir, 'S7_semiconductor_thermal_losses.png'));
close all;

fprintf('Saved figures to %s\n', outDir);

% Overall Summary
fprintf('\n============================================================\n');
fprintf('S6/S7 SUITE SUMMARY:\n');
fprintf('  Stage S6 (Capacitor Parasitics & EoL Degradation) : %s\n', passfail(ok_s6));
fprintf('  Stage S7 (Semiconductor Switching & Thermal Rise) : %s\n', passfail(ok_s7));
pass = ok_s6 && ok_s7;
fprintf('OVERALL S6/S7 STATUS                               : %s\n', passfail(pass));
fprintf('============================================================\n');

save(fullfile(outDir, 'S6_S7_results.mat'), 'ok_s6', 'ok_s7', 'pass');

end

function s = passfail(tf)
    if tf, s = 'PASS'; else, s = 'FAIL'; end
end
