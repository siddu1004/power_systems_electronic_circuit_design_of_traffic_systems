%% compare_controllers_on_power_circuit.m
% Cross-Controller Electrical Performance Benchmark on the SITRA Power Circuit.
% Compares:
%   1. SITRA MPC Controller
%   2. Webster Fixed-Time Controller
%   3. Vehicle-Actuated Controller
%   4. Max-Pressure Controller
%
% Evaluates:
%   - Peak and RMS Capacitor Voltages (Queue potentials)
%   - Stored Electrostatic Energy E = 0.5 * sum(C * V^2)
%   - Semiconductor Conduction Losses P = I^2 * R_on
%   - Gate Commutations / Switch Stress
%   - DC Junction Bus Current Profiles

clc;
close all;

fprintf('\n============================================================\n');
fprintf('CROSS-CONTROLLER ELECTRICAL BENCHMARK ON POWER CIRCUIT\n');
fprintf('============================================================\n');

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
cd(thisDir);
addpath(thisDir);
addpath(fullfile(thisDir, 'SITRA_baselines', 'MATLAB', 'baselines'));

resultsDir = fullfile(thisDir, 'Results', 'power_electronics');
if exist(resultsDir, 'dir') ~= 7, mkdir(resultsDir); end

%% 1. Configure Scenario (T6 Part 8 Surge Scenario)
p = bl_config();
net = createNetwork();
scn = bl_scenarios(p);

% Use Scenario 6 (T6: Deterministic Part 8 Demand Surge, 200s - 400s)
targetScenario = scn(6);
fprintf('Benchmarking on Scenario: %s (%s, Duration = %d s)\n', ...
    targetScenario.id, targetScenario.name, targetScenario.T);

% Generate identical arrival sequence for all controllers
A = bl_make_arrivals(targetScenario, p, 0);

ctrlList = {'SITRA', 'Webster', 'Actuated', 'MaxPressure'};
nCtrl = numel(ctrlList);

PE_results = cell(nCtrl, 1);
traffic_results = cell(nCtrl, 1);

%% 2. Simulate Each Controller through Traffic Plant and Power Circuit
for c = 1:nCtrl
    cName = ctrlList{c};
    fprintf('  Simulating Controller [%d/%d]: %-12s ... ', c, nCtrl, cName);
    
    % Run traffic harness
    R = bl_simulate(cName, A, p, net);
    traffic_results{c} = R;
    
    % Run through equivalent power electronic circuit
    pe = simulate_power_electronic_circuit(R.activeHist, R.arrHist(:, 1:3), R.tVec, net, p.dt);
    PE_results{c} = pe;
    
    fprintf('Done.\n');
end

%% 3. Extract Comparative Electrical Metrics
metrics = struct();
fprintf('\n--------------------------------------------------------------------------------------------------\n');
fprintf('%-14s | %-12s | %-12s | %-12s | %-12s | %-12s\n', ...
    'Controller', 'Peak V_tot[V]', 'Avg Energy[J]', 'Peak Energy[J]', 'Losses[J]', 'Switch Cycles');
fprintf('--------------------------------------------------------------------------------------------------\n');

fid = fopen(fullfile(resultsDir, 'controller_electrical_comparison.csv'), 'w');
fprintf(fid, 'Controller,PeakVoltage_V,AvgEnergy_J,PeakEnergy_J,ConductionLoss_J,SwitchTransitions\n');

for c = 1:nCtrl
    cName = ctrlList{c};
    pe = PE_results{c};
    
    vTot = sum(pe.Vc, 2);
    peakV = max(vTot);
    avgE = mean(pe.totalEnergy);
    peakE = max(pe.totalEnergy);
    lossE = pe.totalEnergyDissipated(end);
    
    % Calculate number of switch state changes
    act = traffic_results{c}.activeHist;
    switchTransitions = sum(diff(act) ~= 0);
    
    fprintf('%-14s | %10.2f V | %10.2f J | %10.2f J | %10.3f J | %10d\n', ...
        cName, peakV, avgE, peakE, lossE, switchTransitions);
    
    fprintf(fid, '%s,%.3f,%.3f,%.3f,%.4f,%d\n', ...
        cName, peakV, avgE, peakE, lossE, switchTransitions);
end
fclose(fid);
fprintf('--------------------------------------------------------------------------------------------------\n');

%% 4. Plot Multi-Controller Electrical Waveforms
hFig = figure('Name', 'Cross_Controller_Electrical_Comparison', 'Position', [100 80 1100 850], 'Visible', 'off');

ctrlColors = [
    0.000, 0.447, 0.741;  % SITRA MPC - Blue
    0.850, 0.325, 0.098;  % Webster - Red/Orange
    0.466, 0.674, 0.188;  % Actuated - Green
    0.494, 0.184, 0.556   % MaxPressure - Purple
];

tVec = traffic_results{1}.tVec;

% Subplot 1: Total Network Capacitor Voltage (Queue Potential)
subplot(3, 2, [1 2]);
hold on; grid on;
for c = 1:nCtrl
    vTot = sum(PE_results{c}.Vc, 2);
    plot(tVec, vTot, 'LineWidth', 1.8, 'Color', ctrlColors(c,:), 'DisplayName', ctrlList{c});
end
xline(200, 'k--', 'Surge Start', 'LabelVerticalAlignment', 'bottom');
xline(400, 'k--', 'Surge End', 'LabelVerticalAlignment', 'bottom');
xlabel('Time [s]'); ylabel('Total Capacitor Voltage \Sigma V_C [V]');
title('Total Network Capacitive Voltage Potential Across Controllers (T6 Demand Surge)');
legend('Location', 'northeast');

% Subplot 2: Stored Electrostatic Energy
subplot(3, 2, 3);
hold on; grid on;
for c = 1:nCtrl
    plot(tVec, PE_results{c}.totalEnergy, 'LineWidth', 1.6, 'Color', ctrlColors(c,:), 'DisplayName', ctrlList{c});
end
xlabel('Time [s]'); ylabel('Stored Energy [J]');
title('Network Electrostatic Potential Energy E = 0.5 \Sigma C V^2');
legend('Location', 'northeast');

% Subplot 3: Cumulative Conduction Power Loss
subplot(3, 2, 4);
hold on; grid on;
for c = 1:nCtrl
    plot(tVec, PE_results{c}.totalEnergyDissipated, 'LineWidth', 1.6, 'Color', ctrlColors(c,:), 'DisplayName', ctrlList{c});
end
xlabel('Time [s]'); ylabel('Cumulative Loss [J]');
title('Semiconductor Conduction Energy Losses (I^2 R_{on})');
legend('Location', 'northwest');

% Subplot 4: Junction DC Bus Current
subplot(3, 2, 5);
hold on; grid on;
for c = 1:nCtrl
    plot(tVec, PE_results{c}.I_bus, 'LineWidth', 1.2, 'Color', ctrlColors(c,:), 'DisplayName', ctrlList{c});
end
yline(0.45, 'r--', 'Capacity (0.45 A)', 'LineWidth', 1.3);
xlim([180 320]);
xlabel('Time [s]'); ylabel('DC Bus Current I_{bus} [A]');
title('Junction DC Bus Current (Zoomed 180s - 320s)');
legend('Location', 'northeast');

% Subplot 5: Commutations & Peak Stored Energy Bar Chart
subplot(3, 2, 6);
barData = zeros(nCtrl, 2);
for c = 1:nCtrl
    barData(c, 1) = max(PE_results{c}.totalEnergy);
    barData(c, 2) = PE_results{c}.totalEnergyDissipated(end) * 50; % scale for display
end
b = bar(categorical(ctrlList), barData);
b(1).FaceColor = [0.2 0.4 0.8];
b(2).FaceColor = [0.8 0.3 0.2];
ylabel('Energy [J]');
title('Peak Stored Energy (Blue) vs Dissipated Loss x50 (Red)');
legend({'Peak Stored Energy [J]', 'Dissipated Loss x50 [J]'}, 'Location', 'northeast');
grid on;

figPath = fullfile(resultsDir, 'PE7_controller_electrical_comparison.png');
saveas(hFig, figPath);
figPathMaster = fullfile(thisDir, 'Results', 'figures', '21_PE_controller_comparison.png');
saveas(hFig, figPathMaster);

fprintf('\nComparison plot saved to:\n  %s\n', figPath);
fprintf('Comparative CSV saved to:\n  %s\n', fullfile(resultsDir, 'controller_electrical_comparison.csv'));
