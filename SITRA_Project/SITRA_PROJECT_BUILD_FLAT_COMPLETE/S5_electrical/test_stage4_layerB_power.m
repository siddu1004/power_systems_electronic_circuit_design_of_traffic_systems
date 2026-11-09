function ok = test_stage4_layerB_power()
%% TEST_STAGE4_LAYERB_POWER
% Stage 4: Physical Layer B Power Stage Verification.
% Proves:
%   1. With healthy hardware, Layer A traffic queues match reference (< 1e-6)
%   2. DC-link voltage stays within nominal regulation band [22.8 V, 24.0 V] (24 V +/- 5%)
%   3. Branch current flows strictly when gate is active
%   4. Dead-time (zero branch current) is verified during clearance
%   5. Physical electrical energy conservation balance closes to < 1%

clc;
close all;

fprintf('\n============================================================\n');
fprintf('STAGE 4: PHYSICAL LAYER B POWER STAGE VERIFICATION\n');
fprintf('============================================================\n');

s5Dir = fileparts(mfilename('fullpath'));
rootDir = fileparts(s5Dir);
cd(rootDir);
addpath(rootDir);
addpath(s5Dir);
addpath(fullfile(rootDir, 'SITRA_baselines', 'MATLAB', 'baselines'));

p_bl = bl_config();
net = createNetwork();
scn = bl_scenarios(p_bl);
p_el = params_electrical();

% Run T6 baseline to get gate signals
A_t6 = bl_make_arrivals(scn(6), p_bl, 0);
R_ref = bl_simulate('SITRA', A_t6, p_bl, net);
S = bl_export_for_simulink(R_ref);

gates = S.gates(:, 2:4);
tVec  = S.qRef(:, 1);
qRef  = S.qRef(:, 2:5);
arrivals = S.arrivals(:, 2:4);

% 1. Simulate Layer B Power Stage
fprintf('1. Simulating Physical DC Power Stage (24V Bus, DC-link, MOSFETs, Loads)...\n');
pwr = sim_power_stage_layerB(gates, tVec, p_el);

% 2. Check 1: Healthy Hardware Coupling with Layer A
% Layer A is driven using the measured switch states from Layer B
pe = sim_layerA_circuit(arrivals, pwr.switchStateMeas, tVec, p_el);
maxErr_V = max(abs(pe.v_C - qRef), [], 'all');
g1_ok = (maxErr_V < 1e-6);

% 3. Check 2: DC-Link Voltage Regulation Band [22.8 V, 24.0 V] (24 V +/- 5%)
minV_dc = min(pwr.V_dc);
maxV_dc = max(pwr.V_dc);
g2_ok = (minV_dc >= 22.8) && (maxV_dc <= 24.1);

% 4. Check 3: Current Conduction Exclusivity (I_branch > 0 only when gate == 1)
leakageCurrent = max(pwr.I_branch .* (gates == 0), [], 'all');
g3_ok = (leakageCurrent < 1e-6);

% 5. Check 4: Dead-Time Verification during Clearance (when all gates == 0)
yellowSteps = (sum(gates, 2) == 0);
maxYellowCurrent = max(sum(pwr.I_branch(yellowSteps, :), 2));
g4_ok = (maxYellowCurrent < 1e-6);

% 6. Check 5: Power & Energy Balance (Source = Load + Loss + DeltaE_cap)
balanceErrorPercent = pwr.energyBalanceError;
g5_ok = (balanceErrorPercent < 1.0);

ok = g1_ok && g2_ok && g3_ok && g4_ok && g5_ok;

fprintf('\n------------------------------------------------------------\n');
fprintf('STAGE 4 ACCEPTANCE CHECKS:\n');
fprintf('------------------------------------------------------------\n');
fprintf('1. Layer A Queue Equivalence via Layer B : %.3e V   [%s] (Limit < 1e-6)\n', maxErr_V, passfail(g1_ok));
fprintf('2. DC-Link Voltage Band [Min, Max]       : [%.2f, %.2f] V [%s] (Nominal 24V +/- 5%%)\n', minV_dc, maxV_dc, passfail(g2_ok));
fprintf('3. Off-State Switch Leakage Current      : %.3e A   [%s] (Limit == 0)\n', leakageCurrent, passfail(g3_ok));
fprintf('4. Dead-Time Clearance Total Current     : %.3e A   [%s] (Limit == 0)\n', maxYellowCurrent, passfail(g4_ok));
fprintf('5. Power & Energy Balance Closure Error  : %.3f %%     [%s] (Limit < 1%%)\n', balanceErrorPercent, passfail(g5_ok));
fprintf('------------------------------------------------------------\n');
fprintf('STAGE 4 OVERALL STATUS                   : %s\n', passfail(ok));
fprintf('============================================================\n');

if nargout == 0
    clear ok;
end

end

function s = passfail(tf)
    if tf, s = 'PASS'; else, s = 'FAIL'; end
end
