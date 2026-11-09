%% test_SITRA_Hardware_Simulation.m
% Complete End-to-End Simulation of the SITRA Power-Electronic Traffic Hardware Model.
% Simulates SITRA_Traffic_Hardware.slx for 600 seconds with real-time MPC,
% switching logic, equivalent power electronic circuit, measurement,
% protection, and hardware interface.

clc;
close all;

fprintf('\n============================================================\n');
fprintf('SITRA SIMULINK POWER-ELECTRONIC HARDWARE SIMULATION\n');
fprintf('============================================================\n');

modelName = 'SITRA_Traffic_Hardware';
load_system(modelName);

fprintf('1) Simulating %s for T = 600 s (dt = 1.0 s)...\n', modelName);
tic;
simOut = sim(modelName, 'StopTime', '600');
simDuration = toc;
fprintf('   Simulation finished in %.2f seconds.\n', simDuration);

% Extract workspace variables
q_sim = squeeze(simOut.s2_q);
if size(q_sim, 1) == 4, q_sim = q_sim.'; end

t = (0:size(q_sim, 1)-1).';

vc_sim = squeeze(simOut.sim_meas_Vc);
if size(vc_sim, 1) == 4, vc_sim = vc_sim.'; end

d_sim = squeeze(simOut.s2_demand);
if size(d_sim, 1) == 3, d_sim = d_sim.'; end

err_val = squeeze(simOut.sim_val_error);

n = min(size(q_sim, 1), size(vc_sim, 1));
max_equiv_err = max(abs(vc_sim(1:n, :) - q_sim(1:n, :)), [], 'all');

fprintf('\n------------------------------------------------------------\n');
fprintf('SIMULINK MODEL VALIDATION RESULTS\n');
fprintf('------------------------------------------------------------\n');
fprintf('Total simulation steps completed : %d\n', numel(t));
fprintf('Max |V_c - q| Equivalence Error  : %.3e V\n', max_equiv_err);
fprintf('Capacitor voltages non-negative  : %s\n', passfail(all(vc_sim(:) >= 0)));
fprintf('Queue non-negativity             : %s\n', passfail(all(q_sim(:) >= 0)));
fprintf('Peak total queue in Simulink     : %.3f veh\n', max(sum(q_sim, 2)));
fprintf('Peak total capacitor voltage     : %.3f V\n', max(sum(vc_sim, 2)));

pass_all = (max_equiv_err < 1e-9);
fprintf('------------------------------------------------------------\n');
fprintf('SIMULINK HARDWARE STATUS         : %s\n', passfail(pass_all));
fprintf('============================================================\n');

function s = passfail(tf)
    if tf, s = 'PASS'; else, s = 'FAIL'; end
end
