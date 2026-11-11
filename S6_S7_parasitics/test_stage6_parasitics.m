function ok = test_stage6_parasitics()
%% TEST_STAGE6_PARASITICS
% Stage S6: Capacitor Parasitics (ESR, ESL, Dielectric Leakage) & Degradation.
%
% Acceptance Criteria:
%   1. Terminal ESR voltage drop bounded: max |V_term - V_int| <= 5.0 mV under nominal ESR.
%   2. Real-time ESR sensor compensation error: max |V_comp - qRef| < 1e-6 V.
%   3. Detector threshold immunity: No false vehicle detector switching at 0.5 V threshold.
%   4. Wear-out degradation stability: Queue tracking remains stable under 200% ESR increase.

clc;
close all;

fprintf('\n============================================================\n');
fprintf('STAGE S6: CAPACITOR PARASITICS & WEAR-OUT DEGRADATION TEST\n');
fprintf('============================================================\n');

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
rootDir = fileparts(thisDir);
cd(rootDir);
addpath(rootDir);
addpath(thisDir);
addpath(fullfile(rootDir, 'baselines'));

p_bl = bl_config();
net = createNetwork();
scn = bl_scenarios(p_bl);

% Run on T6 deterministic surge
A_t6 = bl_make_arrivals(scn(6), p_bl, 0);
R_t6 = bl_simulate('SITRA', A_t6, p_bl, net);
qRef = R_t6.qHist;

% Case 1: Nominal Capacitor Parasitics (R_esr = 5 mOhm)
fprintf('1. Simulating Nominal Capacitor Parasitics (ESR = 5 mOhm)...\n');
out_nom = sim_parasitic_circuit(A_t6, R_t6.gates, false);

max_drop_nom = max(abs(out_nom.v_esr_drop), [], 'all');
max_comp_err_nom = max(abs(out_nom.v_term_comp - qRef), [], 'all');

% Stop-line queue detector stability check (0.5 veh / 0.5 V threshold)
threshold = 0.5;
tol = 1e-12;
ref_det = qRef >= (threshold - tol);

% Raw terminal detector (uncompensated - vulnerable to ESR ripple)
raw_det = out_nom.v_term_raw >= (threshold - tol);
det_mismatch_raw = sum(raw_det(:) ~= ref_det(:));

% Compensated sensor detector (ESR ripple rejected)
comp_det_nom = out_nom.v_term_comp >= (threshold - tol);
det_mismatch_comp_nom = sum(comp_det_nom(:) ~= ref_det(:));

% Case 2: Wear-out / End-of-Life Degradation (ESR doubled to 10 mOhm)
fprintf('2. Simulating End-of-Life Degradation (ESR doubled to 10 mOhm)...\n');
out_deg = sim_parasitic_circuit(A_t6, R_t6.gates, true);

max_drop_deg = max(abs(out_deg.v_esr_drop), [], 'all');
max_comp_err_deg = max(abs(out_deg.v_term_comp - qRef), [], 'all');
comp_det_deg = out_deg.v_term_comp >= (threshold - tol);
det_mismatch_comp_deg = sum(comp_det_deg(:) ~= ref_det(:));

% Acceptance Gates
g1_ok = (max_drop_nom <= 5.0e-3);          % Less than 5 mV ESR drop
g2_ok = (max_comp_err_nom < 1.0e-6);       % Compensation restores < 1 uV accuracy
g3_ok = (det_mismatch_comp_nom == 0);      % Zero detector error with compensation
g4_ok = (max_comp_err_deg < 1.0e-6);       % Degraded ESR still perfectly compensated
g5_ok = (det_mismatch_comp_deg == 0);      % Zero detector error under 200% ESR wear-out

fprintf('\n------------------------------------------------------------\n');
fprintf('STAGE S6 ACCEPTANCE GATE RESULTS:\n');
fprintf('------------------------------------------------------------\n');
fprintf('1. Nominal ESR Max Voltage Drop       : %.3f mV   [%s] (Limit <= 5.0 mV)\n', ...
    max_drop_nom * 1e3, passfail(g1_ok));
fprintf('2. Sensor ESR Compensation Error      : %.3e V   [%s] (Limit < 1e-6 V)\n', ...
    max_comp_err_nom, passfail(g2_ok));
fprintf('3. Compensated Detector Mismatch (Nom): %d steps    [%s] (Limit == 0)\n', ...
    det_mismatch_comp_nom, passfail(g3_ok));
fprintf('4. Uncompensated ESR False Triggers   : %d steps   [INFO] (Demonstrates ESR vulnerability)\n', ...
    det_mismatch_raw);
fprintf('5. Degraded ESR Max Voltage Drop (2x) : %.3f mV   [INFO]\n', ...
    max_drop_deg * 1e3);
fprintf('6. Degraded ESR Compensation Error    : %.3e V   [%s] (Limit < 1e-6 V)\n', ...
    max_comp_err_deg, passfail(g4_ok));
fprintf('7. Compensated Detector Mismatch (Deg): %d steps    [%s] (Limit == 0)\n', ...
    det_mismatch_comp_deg, passfail(g5_ok));
fprintf('------------------------------------------------------------\n');

ok = g1_ok && g2_ok && g3_ok && g4_ok && g5_ok;
fprintf('STAGE S6 OVERALL STATUS               : %s\n', passfail(ok));
fprintf('============================================================\n');

if nargout == 0
    clear ok;
end

end

function s = passfail(tf)
    if tf, s = 'PASS'; else, s = 'FAIL'; end
end
