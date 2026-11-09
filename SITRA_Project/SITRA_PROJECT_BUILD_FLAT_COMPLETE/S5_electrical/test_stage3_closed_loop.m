function ok = test_stage3_closed_loop()
%% TEST_STAGE3_CLOSED_LOOP
% Stage 3: Closed-Loop Verification.
% Proves the closed-loop system where the controller reads capacitor voltages directly
% from physical sensors produces identical activeHist and queue trajectories to the reference.

clc;
close all;

fprintf('\n============================================================\n');
fprintf('STAGE 3: CLOSED-LOOP SENSOR-TO-SWITCH VERIFICATION\n');
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

% Case 1: SITRA MPC on T6 (Deterministic Surge)
fprintf('\n--- Case 1: Closed-Loop SITRA MPC on Scenario T6 ---\n');
A_t6 = bl_make_arrivals(scn(6), p, 0);
R_ref_sitra = bl_simulate('SITRA', A_t6, p, net);
R_cl_sitra  = sim_closed_loop_circuit('SITRA', A_t6, p, net);

actDiff_sitra = max(abs(R_cl_sitra.activeHist - R_ref_sitra.activeHist));
qDiff_sitra   = max(abs(R_cl_sitra.v_C - R_ref_sitra.qHist), [], 'all');

ok1_act = (actDiff_sitra == 0);
ok1_q   = (qDiff_sitra < 1e-6);

fprintf('  Active phase mismatch : %d          [%s]\n', actDiff_sitra, passfail(ok1_act));
fprintf('  Max |v_C - qRef|      : %.3e V   [%s]\n', qDiff_sitra, passfail(ok1_q));

% Case 2: Actuated Controller on T6
fprintf('\n--- Case 2: Closed-Loop Actuated Controller on Scenario T6 ---\n');
R_ref_act_t6 = bl_simulate('Actuated', A_t6, p, net);
R_cl_act_t6  = sim_closed_loop_circuit('Actuated', A_t6, p, net);

actDiff_act_t6 = max(abs(R_cl_act_t6.activeHist - R_ref_act_t6.activeHist));
qDiff_act_t6   = max(abs(R_cl_act_t6.v_C - R_ref_act_t6.qHist), [], 'all');

ok2_act = (actDiff_act_t6 == 0);
ok2_q   = (qDiff_act_t6 < 1e-6);

fprintf('  Active phase mismatch : %d          [%s]\n', actDiff_act_t6, passfail(ok2_act));
fprintf('  Max |v_C - qRef|      : %.3e V   [%s]\n', qDiff_act_t6, passfail(ok2_q));

% Case 3: Actuated Controller on Stochastic Scenario (T2 Moderate, Seed 101)
fprintf('\n--- Case 3: Closed-Loop Actuated Controller on Scenario T2 (Poisson Seed 101) ---\n');
A_t2 = bl_make_arrivals(scn(2), p, 101);
R_ref_act_t2 = bl_simulate('Actuated', A_t2, p, net);
R_cl_act_t2  = sim_closed_loop_circuit('Actuated', A_t2, p, net);

actDiff_act_t2 = max(abs(R_cl_act_t2.activeHist - R_ref_act_t2.activeHist));
qDiff_act_t2   = max(abs(R_cl_act_t2.v_C - R_ref_act_t2.qHist), [], 'all');

ok3_act = (actDiff_act_t2 == 0);
ok3_q   = (qDiff_act_t2 < 1e-6);

fprintf('  Active phase mismatch : %d          [%s]\n', actDiff_act_t2, passfail(ok3_act));
fprintf('  Max |v_C - qRef|      : %.3e V   [%s]\n', qDiff_act_t2, passfail(ok3_q));

ok = ok1_act && ok1_q && ok2_act && ok2_q && ok3_act && ok3_q;

fprintf('\n------------------------------------------------------------\n');
fprintf('STAGE 3 OVERALL STATUS: %s\n', passfail(ok));
fprintf('============================================================\n');

if nargout == 0
    clear ok;
end

end

function s = passfail(tf)
    if tf, s = 'PASS'; else, s = 'FAIL'; end
end
