%% test_SITRA_Simscape_Hardware.m
% Validates execution of the dedicated SITRA_Simscape_Hardware.slx model.
% Compares logged Simscape capacitor voltages against Part 8 frozen reference.

clc;
close all;

fprintf('\n============================================================\n');
fprintf('VALIDATING DEDICATED SIMSCAPE ELECTRICAL HARDWARE MODEL\n');
fprintf('============================================================\n');

%% 1. Load Reference Run
fprintf('1. Loading Part 8 reference...\n');
run('part8_mpc_controller.m');
refQ = qHist;
close all;

% Re-establish workspace variables after part8_mpc_controller clear
thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
cd(thisDir);
init_simscape_workspace;

modelName = 'SITRA_Simscape_Hardware';
load_system(modelName);

% 2. Simulate Simscape Model
fprintf('2. Simulating %s.slx for T = 600 s...\n', modelName);
simOut = sim(modelName, 'StopTime', '600');

% 3. Extract Signals
vc_sim = squeeze(simOut.simscape_Vc);
if size(vc_sim, 1) == 4, vc_sim = vc_sim.'; end

v_dc = squeeze(simOut.simscape_Vdc);
i_bus = squeeze(simOut.simscape_Ibus);

% 4. Equivalence and Physical Checks
if size(refQ, 2) == 5
    refQ = refQ(:, 2:5);
end
n = min(size(vc_sim, 1), size(refQ, 1));
maxErr = max(abs(vc_sim(1:n, :) - refQ(1:n, :)), [], 'all');

g1_ok = (maxErr < 1e-6);
g2_ok = (min(v_dc) >= 22.8) && (max(v_dc) <= 24.1);
g3_ok = all(vc_sim(:) >= 0);

fprintf('\n------------------------------------------------------------\n');
fprintf('SIMSCAPE ELECTRICAL MODEL ACCEPTANCE CHECKS:\n');
fprintf('------------------------------------------------------------\n');
fprintf('1. Max |V_C - qRef| Equivalence Error : %.3e V   [%s] (Limit < 1e-6)\n', maxErr, passfail(g1_ok));
fprintf('2. Layer B DC-Link Voltage Regulation : [%.2f, %.2f] V [%s] (Nominal 24V +/- 5%%)\n', min(v_dc), max(v_dc), passfail(g2_ok));
fprintf('3. Capacitor Voltage Non-Negativity   :            [%s]\n', passfail(g3_ok));
fprintf('------------------------------------------------------------\n');
fprintf('SIMSCAPE HARDWARE MODEL STATUS        : %s\n', passfail(g1_ok && g2_ok && g3_ok));
fprintf('============================================================\n');

function s = passfail(tf)
    if tf, s = 'PASS'; else, s = 'FAIL'; end
end
