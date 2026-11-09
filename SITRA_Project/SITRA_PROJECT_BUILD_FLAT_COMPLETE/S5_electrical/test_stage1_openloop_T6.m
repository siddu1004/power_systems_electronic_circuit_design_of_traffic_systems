function ok = test_stage1_openloop_T6()
%% TEST_STAGE1_OPENLOOP_T6
% Stage 1: Layer A open-loop T6 replay test against frozen Part 8 reference.

clc;
close all;

fprintf('\n============================================================\n');
fprintf('STAGE 1: LAYER A OPEN-LOOP T6 REPLAY TEST\n');
fprintf('============================================================\n');

s5Dir = fileparts(mfilename('fullpath'));
rootDir = fileparts(s5Dir);
cd(rootDir);
addpath(rootDir);
addpath(s5Dir);
addpath(fullfile(rootDir, 'SITRA_baselines', 'MATLAB', 'baselines'));

p = bl_config();
net = createNetwork();
scn = bl_scenarios(p);

% Scenario T6: Deterministic Part 8 Demand Surge
targetScenario = scn(6);
fprintf('Target scenario: %s (%s, Duration: %d s)\n', targetScenario.id, targetScenario.name, targetScenario.T);

% 1. Generate arrivals and run SITRA baseline
A = bl_make_arrivals(targetScenario, p, 0);
R = bl_simulate('SITRA', A, p, net);
S = bl_export_for_simulink(R);

% 2. Extract inputs for Layer A circuit
arrivals = S.arrivals(:, 2:4);  % [a1 a2 a3] (A)
gates = S.gates(:, 2:4);        % [g1 g2 g3]
qRef = S.qRef(:, 2:5);          % [q1 q2 q3 q4] (veh)
tVec = S.qRef(:, 1);

% 3. Run Layer A circuit simulation
pe = sim_layerA_circuit(arrivals, gates, tVec, params_electrical());

% 4. Acceptance Gates
% Gate 1: max|v_C - qRef| < 1e-6
maxErr_V = max(abs(pe.v_C - qRef), [], 'all');

% Gate 2: Charge balance |arrived - exited - sum(V_end)| < 1e-6 C
chargeErr = pe.chargeError;

% Gate 3: min v_C >= -1e-9
minV = min(pe.v_C, [], 'all');

% Gate 4: Zero gate overlap violations
gateViolations = pe.gateOverlapCount;

g1_ok = maxErr_V < 1e-6;
g2_ok = chargeErr < 1e-6;
g3_ok = minV >= -1e-9;
g4_ok = (gateViolations == 0);

ok = g1_ok && g2_ok && g3_ok && g4_ok;

fprintf('\n------------------------------------------------------------\n');
fprintf('STAGE 1 ACCEPTANCE CHECKS:\n');
fprintf('------------------------------------------------------------\n');
fprintf('1. max |v_C(t) - qRef(t)|         : %.3e V   [%s] (Limit < 1e-6)\n', maxErr_V, passfail(g1_ok));
fprintf('2. Charge Conservation Error       : %.3e C   [%s] (Limit < 1e-6)\n', chargeErr, passfail(g2_ok));
fprintf('3. Minimum Capacitor Voltage       : %.3e V   [%s] (Limit >= -1e-9)\n', minV, passfail(g3_ok));
fprintf('4. Gate Overlap Violations Count   : %d         [%s] (Limit == 0)\n', gateViolations, passfail(g4_ok));
fprintf('------------------------------------------------------------\n');
fprintf('STAGE 1 OVERALL STATUS             : %s\n', passfail(ok));
fprintf('============================================================\n');

if nargout == 0
    clear ok;
end

end

function s = passfail(tf)
    if tf, s = 'PASS'; else, s = 'FAIL'; end
end
