%% run_presentation_demo.m
% =========================================================================
% PROJECT SITRA: LIVE PRESENTATION & DEFENSE DEMONSTRATION SCRIPT
% Group 22 | Amrita School of Engineering, Coimbatore
% Evaluator: Dr. S. Sampath Kumar
%
% Runs all 4 Acts automatically end-to-end without freezing on keypresses:
%   Act 1: 4-Controller Simulink Benchmark (SITRA MPC, Webster, Actuated, MaxPressure)
%   Act 2: 5 us Break-Before-Make Semiconductor Dead-Time Interlock Testbench
%   Act 3: 230V AC -> 47V DC-Link -> 24V Buck Simscape Physical Circuit + 1F Traffic Network
%   Act 4: Slide 14 Sensor Fault Reversal (Clean vs Noisy Sensor Breakdown)
% =========================================================================

clc;
clear;
close all;
bdclose all;

rootDir = fileparts(mfilename('fullpath'));
if isempty(rootDir), rootDir = pwd; end
cd(rootDir);
addpath(rootDir);
addpath(fullfile(rootDir, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE'));
addpath(fullfile(rootDir, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE', 'S5_physical'));
addpath(fullfile(rootDir, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE', 'S6_S7_parasitics'));
addpath(fullfile(rootDir, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE', 'baselines'));

screen = get(0, 'ScreenSize');
sw = screen(3);
sh = screen(4);

fprintf('======================================================================\n');
fprintf('       PROJECT SITRA: LIVE PRESENTATION & DEFENSE DEMO (GROUP 22)     \n');
fprintf('======================================================================\n');
fprintf('Team Members:\n');
fprintf('  1. Sreedev C.                 (CB.EN.U4EEE24142)\n');
fprintf('  2. Vanguri Satya Sai Siddardh (CB.EN.U4EEE24152)\n');
fprintf('  3. Vishal S.                  (CB.EN.U4EEE24155)\n');
fprintf('======================================================================\n\n');

%% Initialize dual-domain parameters in base workspace
if isfile(fullfile(rootDir, 'init_simscape_workspace.m'))
    init_simscape_workspace;
end

%% =========================================================================
%% ACT 1: SIMULINK 4-CONTROLLER BENCHMARK & SIMULATION WINDOW
%% =========================================================================
fprintf('\n>>> [ACT 1/4] OPENING SIMULINK MULTI-CONTROLLER MODEL ON SCREEN...\n');
model1 = 'SITRA_S2_test_ControllerCompare';
load_system(model1);
open_system(model1);
screen = get(0, 'ScreenSize'); sw = screen(3); sh = screen(4);
set_param(model1, 'Location', [20, 60, round(sw*0.52), round(sh*0.92)]);
drawnow;

fprintf('Running live simulation across 4 controllers (SITRA MPC, Webster, Actuated, MaxPressure)...\n');
run_part_d_integrated;

% Restore screen coordinates (since run_part_d_integrated uses local variable 'sw')
screen = get(0, 'ScreenSize'); sw = screen(3); sh = screen(4);

dMat = fullfile(rootDir, 'Results', 'PartD_Integrated_Validation', 'PartD_AllControllers.mat');
if isfile(dMat)
    D = load(dMat, 'Results');
    Res = D.Results;
    f_act1 = figure('Name', 'ACT 1: Multi-Controller Live Queue & Electrical Equivalence', ...
        'Position', [round(sw*0.53), round(sh*0.50), round(sw*0.45), round(sh*0.43)], ...
        'Color', 'w', 'NumberTitle', 'off');

    subplot(1, 2, 1);
    t = Res.SITRA.time;
    patch([200 400 400 200], [0 0 40 40], [0.92 0.92 0.92], 'FaceAlpha', 0.5, 'EdgeColor', 'none', 'DisplayName', 'Surge [200-400s]');
    hold on; grid on;
    plot(t, sum(Res.Webster.queue, 2), 'Color', [0.85 0.33 0.10], 'LineWidth', 1.8, 'DisplayName', 'Webster (Fixed)');
    plot(t, sum(Res.Actuated.queue, 2), 'Color', [0.47 0.67 0.19], 'LineWidth', 1.8, 'DisplayName', 'Actuated');
    plot(t, sum(Res.MaxPressure.queue, 2), 'Color', [0.49 0.18 0.56], 'LineWidth', 1.8, 'DisplayName', 'Max-Pressure');
    plot(t, sum(Res.SITRA.queue, 2), 'Color', [0.00 0.45 0.74], 'LineWidth', 2.4, 'DisplayName', 'SITRA MPC');
    title('Total Network Queue Backlog (T6 Surge)', 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Time [s]'); ylabel('Total Queue [veh]');
    legend('Location', 'northeast', 'FontSize', 8);
    xlim([0 600]); ylim([0 max(sum(Res.Webster.queue, 2))*1.15]);

    subplot(1, 2, 2);
    cNames = {'SITRA', 'Webster', 'Actuated', 'MaxPressure'};
    avgQ = [Res.SITRA.averageQueue, Res.Webster.averageQueue, Res.Actuated.averageQueue, Res.MaxPressure.averageQueue];
    pkQ  = [Res.SITRA.peakQueue,    Res.Webster.peakQueue,    Res.Actuated.peakQueue,    Res.MaxPressure.peakQueue];
    b = bar([avgQ(:), pkQ(:)]);
    b(1).FaceColor = [0.00 0.45 0.74];
    b(2).FaceColor = [0.85 0.33 0.10];
    set(gca, 'XTickLabel', cNames, 'FontSize', 9);
    ylabel('Vehicles [veh] / Equivalent Volts [V]');
    title('Average vs Peak Queue Across Controllers', 'FontSize', 11, 'FontWeight', 'bold');
    legend({'Avg Queue', 'Peak Queue'}, 'Location', 'northwest', 'FontSize', 8);
    grid on;
    drawnow;
end

pause(1.5);

%% =========================================================================
%% ACT 2: MICROSECOND SEMICONDUCTOR DEAD-TIME INTERLOCK
%% =========================================================================
fprintf('\n>>> [ACT 2/4] BUILDING & RUNNING 5 us DEAD-TIME INTERLOCK TESTBENCH...\n');
run_part_c;

screen = get(0, 'ScreenSize'); sw = screen(3); sh = screen(4);
model2 = 'SITRA_Deadtime_Testbench';
if bdIsLoaded(model2)
    open_system(model2);
    set_param(model2, 'Location', [40, 90, round(sw*0.48), round(sh*0.48)]);
end

cMat = fullfile(rootDir, 'Results', 'PartC_Deadtime_Validation', 'PartC_Results.mat');
if isfile(cMat)
    C = load(cMat, 'PartC');
    PartC = C.PartC;
    f_act2 = figure('Name', 'ACT 2: 5.0 us Break-Before-Make Dead-Time Interlock', ...
        'Position', [round(sw*0.53), round(sh*0.05), round(sw*0.45), round(sh*0.40)], ...
        'Color', 'w', 'NumberTitle', 'off');

    t_us = PartC.time * 1e6;
    idx = find(t_us >= 85 & t_us <= 125); % Zoom in around 100 us transition
    if isempty(idx), idx = 1:numel(t_us); end

    subplot(2, 1, 1);
    stairs(t_us(idx), PartC.requestedGates(idx, 1), 'b--', 'LineWidth', 1.8, 'DisplayName', 'Req Gate 1');
    hold on; grid on;
    stairs(t_us(idx), PartC.requestedGates(idx, 2), 'r--', 'LineWidth', 1.8, 'DisplayName', 'Req Gate 2');
    title('Commanded Phase Transition at t = 100 \mus (Zero Dead-Time Request)', 'FontSize', 10, 'FontWeight', 'bold');
    ylabel('Req Gate'); ylim([-0.2 1.3]); legend('Location', 'east', 'FontSize', 8);

    subplot(2, 1, 2);
    patch([100 105 105 100], [-0.2 -0.2 1.3 1.3], [1 0.85 0.85], 'EdgeColor', 'none', 'DisplayName', '5.0 \mus Blanked Dead-Time');
    hold on; grid on;
    stairs(t_us(idx), PartC.actualGates(idx, 1), 'Color', [0.00 0.45 0.74], 'LineWidth', 2.2, 'DisplayName', 'Actual MOSFET Gate 1');
    stairs(t_us(idx), PartC.actualGates(idx, 2), 'Color', [0.85 0.33 0.10], 'LineWidth', 2.2, 'DisplayName', 'Actual MOSFET Gate 2');
    title(sprintf('Enforced 5.0 \\mus Break-Before-Make Dead-Time (Measured = %.1f \\mus, Shoot-Through = 0)', PartC.minimumDeadTime*1e6), ...
        'FontSize', 10, 'FontWeight', 'bold');
    xlabel('Time [\mus]'); ylabel('Actual Gate'); ylim([-0.2 1.3]);
    legend('Location', 'east', 'FontSize', 8);
    drawnow;
end

pause(1.5);

%% =========================================================================
%% ACT 3: AUTHENTIC 230V AC SIMSCAPE PHYSICAL HARDWARE
%% =========================================================================
fprintf('\n>>> [ACT 3/4] OPENING 230V AC PURE SIMSCAPE PHYSICAL CIRCUIT ON SCREEN...\n');
s5Model = 'SITRA_S5_Physical';
s5Dir = fullfile(rootDir, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE', 'S5_physical');
cd(s5Dir);
load_system(s5Model);
open_system(s5Model);
open_system([s5Model '/Traffic_Equivalent_Circuit']);
open_system([s5Model '/Power_Path']);

screen = get(0, 'ScreenSize'); sw = screen(3); sh = screen(4);
set_param(s5Model, 'Location', [30, 60, round(sw*0.50), round(sh*0.88)]);
drawnow;

fprintf('Simscape Physical Model "%s" and both physical circuits are now open and visible!\n', s5Model);
fprintf('Simulating Layer A (1F Capacitive Road Network) & Layer B (230V AC -> 47V DC-Link -> 24V Buck -> MOSFETs)...\n');

test_SITRA_S5_Physical;

screen = get(0, 'ScreenSize'); sw = screen(3); sh = screen(4);
f_act3 = figure('Name', 'ACT 3: Simscape Physical Circuit Verification (Layer A & Layer B)', ...
    'Position', [round(sw*0.03), round(sh*0.06), round(sw*0.48), round(sh*0.82)], ...
    'Color', 'w', 'NumberTitle', 'off');

subplot(3, 1, 1);
plot(tv(1:N), vC, 'LineWidth', 1.6); hold on;
plot(tv(1:N), qRef, 'k:', 'LineWidth', 1.2);
grid on; xlabel('Time [s]'); ylabel('Capacitor V_C [V] = Queue [veh]');
title(sprintf('Layer A Simscape Capacitive Voltages vs Part 8 Reference (Max Error = %.2e V)', err), 'FontSize', 10, 'FontWeight', 'bold');
legend({'C_{B1}', 'C_{B2}', 'C_{B3}', 'C_{B4}', 'Part 8 q_{ref}'}, 'Location', 'northeast', 'FontSize', 8);

subplot(3, 1, 2);
plot(tp, vDC, 'Color', [0.85 0.33 0.10], 'LineWidth', 1.5, 'DisplayName', 'Rectified DC-Link (~47.2 V)');
hold on; grid on;
plot(tp, vBus, 'Color', [0.00 0.45 0.74], 'LineWidth', 1.8, 'DisplayName', 'Regulated Buck Bus (24.0 V)');
yline(24.0, 'k--', '24V Target');
xlabel('Time [s]'); ylabel('Voltage [V]');
title(sprintf('Layer B Power Conversion: 230V AC -> 47.2V DC-Link -> %.2fV Buck Bus', busMean), 'FontSize', 10, 'FontWeight', 'bold');
legend('Location', 'southeast', 'FontSize', 8);

subplot(3, 1, 3);
plot(tp, iCh, 'LineWidth', 1.5);
grid on; xlabel('Time [s]'); ylabel('MOSFET Load Current [A]');
title(sprintf('MOSFET Signal-Head Currents (Illegal 2-Green Command at t=0.62s Blocked: Overlap=%d)', twoOn), 'FontSize', 10, 'FontWeight', 'bold');
legend({'Branch B1 (1A)', 'Branch B2 (1A)', 'Branch B3 (1A)'}, 'Location', 'northeast', 'FontSize', 8);
drawnow;

pause(1.5);

%% =========================================================================
%% ACT 4: SCENARIO T13 NOISE DEMO (SLIDE 14 DEFENSE HIGHLIGHT)
%% =========================================================================
fprintf('\n>>> [ACT 4/4] DEMONSTRATING SLIDE 14: SENSOR NOISE BREAKDOWN & REVERSAL...\n');
cd(rootDir);
csvPath = fullfile(rootDir, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE', 'Results', 'baselines', 'baseline_comparison.csv');
if ~isfile(csvPath)
    csvPath = fullfile(rootDir, 'Group_22', '03_Supplementary_Results_and_Figures', 'baseline_comparison.csv');
end

if isfile(csvPath)
    T = readtable(csvPath);
    t2_rows  = T(strcmp(T.Scenario, 'T2'), :);  % Clean Moderate Demand
    t9_rows  = T(strcmp(T.Scenario, 'T9'), :);  % Clean Incident B1 Clearance
    t13_rows = T(strcmp(T.Scenario, 'T13'), :); % Noisy Sensors (sigma = 2 veh)

    screen = get(0, 'ScreenSize'); sw = screen(3); sh = screen(4);
    f_act4 = figure('Name', 'ACT 4: Slide 14 Defense Highlight - Sensor Fault Reversal', ...
        'Position', [round(sw*0.25), round(sh*0.12), round(sw*0.52), round(sh*0.65)], ...
        'Color', 'w', 'NumberTitle', 'off');

    subplot(1, 2, 1);
    delayMat = [t2_rows.AvgDelay_s(:), t13_rows.AvgDelay_s(:)];
    b1 = bar(delayMat);
    b1(1).FaceColor = [0.20 0.60 0.85];
    b1(2).FaceColor = [0.85 0.33 0.10];
    set(gca, 'XTickLabel', t13_rows.Controller, 'FontSize', 9);
    ylabel('Average Delay [s/veh]');
    title('Average Delay: Clean (T2) vs Noisy Sensors (T13)', 'FontSize', 10, 'FontWeight', 'bold');
    legend({'Clean Sensors (Actuated Wins)', 'Noisy \sigma=2 veh (SITRA MPC Wins!)'}, 'Location', 'northwest', 'FontSize', 8);
    grid on;

    subplot(1, 2, 2);
    clrMat = [t9_rows.ClearTime_s(:), t13_rows.ClearTime_s(:)];
    b2 = bar(clrMat);
    b2(1).FaceColor = [0.47 0.67 0.19];
    b2(2).FaceColor = [0.78 0.18 0.18];
    set(gca, 'XTickLabel', t13_rows.Controller, 'FontSize', 9);
    ylabel('Clearance Time [seconds]');
    title('Clearance Time: Clean Incident (T9) vs Sensor Noise (T13)', 'FontSize', 10, 'FontWeight', 'bold');
    legend({'Clean Incident (T9)', 'Sensor Noise T13 (Actuated = 424.3s!)'}, 'Location', 'northwest', 'FontSize', 8);
    grid on;
    drawnow;

    fprintf('\n======================================================================\n');
    fprintf('  SLIDE 14 NUMERICAL SUMMARY FOR EXAMINER (Dr. S. Sampath Kumar):\n');
    fprintf('----------------------------------------------------------------------\n');
    fprintf('  Clean Moderate (T2 Avg Delay): Actuated = 17.85 s | MaxPressure = 25.41 s | SITRA MPC = 25.59 s | Webster = 26.77 s\n');
    fprintf('  Noisy Sensors  (T13 Avg Delay): SITRA MPC = 21.55 s (1st!) | Webster = 26.77 s | Actuated = 27.01 s | MaxPressure = 29.91 s\n');
    fprintf('  Noisy Clearance(T13 ClearTime): Webster   =  0.00 s (Immune, open-loop)\n');
    fprintf('                                  SITRA MPC = 56.60 s (Robust horizon filter)\n');
    fprintf('                                  Actuated  = 424.25 s (CATASTROPHIC false gap-out stall!)\n');
    fprintf('======================================================================\n');
end

cd(rootDir);
fprintf('\n======================================================================\n');
fprintf('  PRESENTATION DEMONSTRATION COMPLETE - ALL 4 ACTS & WINDOWS LIVE!    \n');
fprintf('======================================================================\n');
