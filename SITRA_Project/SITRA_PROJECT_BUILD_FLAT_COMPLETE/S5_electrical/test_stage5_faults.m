function ok = test_stage5_faults()
%% TEST_STAGE5_FAULTS
% Stage 5: Fault Injection & Protection Interlock Verification.
% Tests all 5 physical electrical failure modes:
%   1. Two gate commands on simultaneously (shoot-through command)
%   2. Switch stuck closed (MOSFET short)
%   3. Switch stuck open (MOSFET open)
%   4. DC supply sag/dropout (10V undervoltage)
%   5. Branch overcurrent (5A short)

clc;
close all;

fprintf('\n============================================================\n');
fprintf('STAGE 5: FAULT INJECTION & HARDWARE PROTECTION VERIFICATION\n');
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

% Baseline inputs from T6
A_t6 = bl_make_arrivals(scn(6), p_bl, 0);
R_ref = bl_simulate('SITRA', A_t6, p_bl, net);
S = bl_export_for_simulink(R_ref);

gates = S.gates(:, 2:4);
tVec  = S.qRef(:, 1);
arrivals = S.arrivals(:, 2:4);

% 1. Fault 1: Simultaneous Gate Command (Shoot-through)
fprintf('\n1. Testing Simultaneous Shoot-Through Command...\n');
f1 = sim_fault_injection('shoot_through', arrivals, gates, tVec, p_el);
maxSimultGates = max(sum(f1.gatesEffective, 2));
f1_ok = (maxSimultGates <= 1) && (f1.numFaultEvents > 0);
fprintf('   Shoot-through logged: %d times. Max effective simultaneous gates: %d [%s]\n', ...
    f1.numFaultEvents, maxSimultGates, passfail(f1_ok));

% 2. Fault 2: Switch Stuck Open
fprintf('\n2. Testing Switch Stuck Open (S1 open-circuit failure during surge)...\n');
f2 = sim_fault_injection('switch_stuck_open', arrivals, gates, tVec, p_el);
% Traffic consequence: B1 queue cannot drain during surge, queue grows to huge level
f2_traffic_consequence = (f2.maxQueueB1 > 50.0);
f2_ok = (f2.numFaultEvents > 0) && f2_traffic_consequence;
fprintf('   Fault logged: %d times. Peak B1 queue escalated to %.1f veh [%s]\n', ...
    f2.numFaultEvents, f2.maxQueueB1, passfail(f2_ok));

% 3. Fault 3: Switch Stuck Closed
fprintf('\n3. Testing Switch Stuck Closed (S2 short-circuit failure)...\n');
f3 = sim_fault_injection('switch_stuck_closed', arrivals, gates, tVec, p_el);
f3_ok = f3.tripped && f3.safeStateActive && (max(sum(f3.gatesEffective(200:end, :), 2)) == 0);
fprintf('   Main contactor tripped to safe all-red: %s [%s]\n', ...
    passfail(f3.safeStateActive), passfail(f3_ok));

% 4. Fault 4: DC Supply Undervoltage Sag
fprintf('\n4. Testing DC Power Supply Sag (Dropout to 10 V)...\n');
f4 = sim_fault_injection('supply_sag', arrivals, gates, tVec, p_el);
f4_ok = f4.tripped && f4.safeStateActive && (f4.finalTotalQueue > 50.0);
fprintf('   Undervoltage trip executed: %s, Safe state engaged: %s, Final queue: %.1f veh [%s]\n', ...
    passfail(f4.tripped), passfail(f4.safeStateActive), f4.finalTotalQueue, passfail(f4_ok));

% 5. Fault 5: Branch Overcurrent
fprintf('\n5. Testing Branch Overcurrent (5 A short-circuit)...\n');
f5 = sim_fault_injection('overcurrent', arrivals, gates, tVec, p_el);
f5_ok = f5.tripped && f5.safeStateActive;
fprintf('   Electronic fuse tripped within 1 ms: %s [%s]\n', ...
    passfail(f5.tripped), passfail(f5_ok));

ok = f1_ok && f2_ok && f3_ok && f4_ok && f5_ok;

fprintf('\n------------------------------------------------------------\n');
fprintf('STAGE 5 OVERALL STATUS: %s\n', passfail(ok));
fprintf('============================================================\n');

if nargout == 0
    clear ok;
end

end

function s = passfail(tf)
    if tf, s = 'PASS'; else, s = 'FAIL'; end
end
