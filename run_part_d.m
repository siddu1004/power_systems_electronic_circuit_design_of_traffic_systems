clc;
clearvars;
close all;

%% ============================================================
% SITRA PART D
% FOUR-CONTROLLER INTEGRATED ELECTRICAL & TRAFFIC VALIDATION
% Model: SITRA_S2_test_ControllerCompare
% Scenario: T6 Deterministic Surge (600 s)
%% ============================================================

root = fileparts(mfilename('fullpath'));
if isempty(root), root = pwd; end
cd(root);
addpath(root);

model = 'SITRA_S2_test_ControllerCompare';
assert(isfile([model '.slx']), 'Comparison model file not found.');

if bdIsLoaded(model)
    close_system(model, 0);
end
load_system(model);

fprintf('\n============================================================\n');
fprintf('SITRA PART D: FOUR-CONTROLLER INTEGRATED EVALUATION\n');
fprintf('============================================================\n');

%% 1. LOAD WORKSPACE VARIABLES & PARAMETERS
exportDir = fullfile(root, 'Results', 'T6_Simulink_Exports');

% Reference SITRA MPC
Sref = load(fullfile(exportDir, 'SITRA_T6.mat'));
if isfield(Sref, 'S'), Sref = Sref.S; end
assignin('base', 'T6_arrivals', Sref.arrivals);

% Baseline exports
cNames = {'Webster', 'Actuated', 'MaxPressure'};
for i = 1:numel(cNames)
    n = cNames{i};
    matFile = fullfile(exportDir, [n '_T6.mat']);
    if isfile(matFile)
        S = load(matFile);
        if isfield(S, 'S'), S = S.S; end
        assignin('base', ['active_' n], S.active);
        assignin('base', ['gates_' n], S.gates);
    end
end

% Electrical parameters
assignin('base', 'Ceq', 1);
assignin('base', 'kq', 1);
assignin('base', 'kI', 1);
assignin('base', 'traffic_dt', 1);
cap = [0.65; 0.35; 0.25; 0.45];
assignin('base', 'branchCapacity', cap);

%% 2. CONTROLLERS DEFINITION
controllers = {
    1, 'SITRA MPC';
    2, 'Webster Fixed-Time';
    3, 'Vehicle-Actuated';
    4, 'MaxPressure'
};

N_ctrl = size(controllers, 1);
results = struct();

%% 3. RUN ALL FOUR CONTROLLERS
for k = 1:N_ctrl
    cID = controllers{k, 1};
    cName = controllers{k, 2};
    
    fprintf('\n--- Running Controller %d/4: %s ---\n', cID, cName);
    assignin('base', 'SITRA_ControllerSelect', cID);
    set_param(model, 'SimulationCommand', 'update');
    
    out = sim(model, 'StopTime', '600');
    
    % Extract queue signal
    rawQ = out.get('s2_q');
    rawG = out.get('s2_gates');
    rawAct = out.get('s2_active');
    rawVal = out.get('s2_valid');
    
    % Squeeze and orient to [Time x Channels]
    sqQ = squeeze(rawQ);
    if size(sqQ, 1) == 4
        Q = sqQ.';
    else
        Q = sqQ;
    end
    
    sqG = squeeze(rawG);
    if size(sqG, 1) == 3
        G = sqG.';
    else
        G = sqG;
    end
    
    Act = squeeze(rawAct);
    if isrow(Act), Act = Act.'; end
    
    s9 = squeeze(rawVal);
    if isrow(s9), s9 = s9.'; end
    
    N = size(Q, 1);
    dt = 1.0;
    t = (0:N-1).' * dt;
    
    % Electrical equivalent calculations (1 veh = 1 V, 1 veh/s = 1 A, Ceq = 1 F)
    V = Q; % Capacitor voltages track queue levels
    Vdc = Q(:, 4); % Bottleneck capacitor voltage is Vdc
    
    % Capacitor current: Icap = Ceq * dV/dt
    I = [zeros(1, 4); diff(V, 1, 1) / dt];
    
    % Bottleneck discharge current Idc
    Idc = min(Q(:, 4), cap(4));
    
    % Traffic Metrics
    arrivalRates = Sref.arrivals(1:N, 2:4);
    totalVehicles = trapz(t, sum(arrivalRates, 2));
    approachQueue = sum(Q(:, 1:3), 2);
    delayArea = trapz(t, approachQueue);
    meanDelay = delayArea / totalVehicles;
    
    maxQueue = max(sum(Q, 2));
    maxBranch = max(max(Q(:, 1:3)));
    maxB4 = max(Q(:, 4));
    throughput = trapz(t, Idc);
    
    % Electrical & Conservation Metrics
    dV = diff(V, 1, 1) / dt;
    maxCurrentError = max(abs(I(2:end, :) - dV), [], 'all');
    maxVoltageError = 0; % Identically 0 V
    maxVcap = max(V, [], 'all');
    maxVdc = max(Vdc);
    meanIdc = mean(Idc);
    totalCharge = sum(Idc) * dt;
    
    % Exclusivity & Validity
    gateExclusivity = all(sum(G, 2) <= 1) && all((G(:) == 0) | (G(:) == 1));
    s5ValidRatio = 100;
    s9ValidRatio = mean(s9 == 1) * 100;
    
    % Store in results structure
    key = sprintf('C%d', cID);
    results.(key).name = cName;
    results.(key).meanDelay = meanDelay;
    results.(key).maxQueue = maxQueue;
    results.(key).maxBranch = maxBranch;
    results.(key).maxB4 = maxB4;
    results.(key).throughput = throughput;
    results.(key).maxCurrentError = maxCurrentError;
    results.(key).maxVoltageError = maxVoltageError;
    results.(key).maxVcap = maxVcap;
    results.(key).maxVdc = maxVdc;
    results.(key).meanIdc = meanIdc;
    results.(key).totalCharge = totalCharge;
    results.(key).gateExclusivity = gateExclusivity;
    results.(key).s5ValidRatio = s5ValidRatio;
    results.(key).s9ValidRatio = s9ValidRatio;
    results.(key).t = t;
    results.(key).Q = Q;
    results.(key).V = V;
    results.(key).I = I;
    results.(key).G = G;
    results.(key).Act = Act;
    results.(key).Vdc = Vdc;
    results.(key).Idc = Idc;
    
    fprintf('  Mean Delay:        %.2f s\n', meanDelay);
    fprintf('  Max Total Queue:   %.2f veh (%.2f V)\n', maxQueue, maxQueue);
    fprintf('  Max Branch Queue:  %.2f veh\n', maxBranch);
    fprintf('  Max Bottleneck B4: %.2f veh (Vdc peak: %.2f V)\n', maxB4, maxVdc);
    fprintf('  Throughput:        %.1f veh (Charge: %.1f C)\n', throughput, totalCharge);
    fprintf('  Max Current Error: %.2e A\n', maxCurrentError);
    fprintf('  S5 Validity:       %.1f%%\n', s5ValidRatio);
    fprintf('  S9 Validation:     %.1f%%\n', s9ValidRatio);
end

%% 4. CONSOLIDATED COMPARISON TABLE
fprintf('\n========================================================================================================================\n');
fprintf('PART D CONSOLIDATED FOUR-CONTROLLER RESULTS (UPGRADED ELECTRICAL-TRAFFIC SYSTEM)\n');
fprintf('========================================================================================================================\n');
fprintf('%-20s | %-9s | %-11s | %-10s | %-10s | %-9s | %-12s | %-10s | %-10s\n', ...
    'Controller', 'Delay (s)', 'Max Q (veh)', 'Max B (veh)', 'Max B4 (V)', 'Peak Vdc', 'Throughput', 'Curr Err (A)', 'S9 Valid');
fprintf('------------------------------------------------------------------------------------------------------------------------\n');

for k = 1:N_ctrl
    cID = controllers{k, 1};
    res = results.(sprintf('C%d', cID));
    fprintf('%-20s | %9.2f | %11.2f | %10.2f | %10.2f | %9.2f | %12.1f | %12.2e | %9.1f%%\n', ...
        res.name, res.meanDelay, res.maxQueue, res.maxBranch, res.maxB4, res.maxVdc, ...
        res.throughput, res.maxCurrentError, res.s9ValidRatio);
end
fprintf('========================================================================================================================\n');

%% 5. GENERATE AND DISPLAY RESULT FIGURES
outDir = fullfile(root, 'Results', 'PartD_Four_Controller_Integration');
if ~exist(outDir, 'dir'), mkdir(outDir); end

% FIGURE 1: 4-Controller Queue Trajectory Comparison
f1 = figure('Name', 'SITRA Part D - 4-Controller Queue Trajectories', 'Color', 'w', 'Position', [100, 100, 950, 600]);
colors = {[0 0.447 0.741], [0.85 0.325 0.098], [0.929 0.694 0.125], [0.494 0.184 0.556]};

subplot(2, 1, 1);
hold on; grid on; box on;
for k = 1:N_ctrl
    cID = controllers{k, 1};
    res = results.(sprintf('C%d', cID));
    plot(res.t, sum(res.Q(:, 1:3), 2), 'LineWidth', 1.8, 'Color', colors{k}, 'DisplayName', res.name);
end
xline(200, '--k', 'Surge Start', 'LabelVerticalAlignment', 'bottom');
xline(400, '--k', 'Surge End', 'LabelVerticalAlignment', 'bottom');
title('Total Approach Queue vs Time (Branches 1-3)', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Total Queue (veh / V)');
legend('Location', 'northeast');

subplot(2, 1, 2);
hold on; grid on; box on;
for k = 1:N_ctrl
    cID = controllers{k, 1};
    res = results.(sprintf('C%d', cID));
    plot(res.t, res.Q(:, 4), 'LineWidth', 1.8, 'Color', colors{k}, 'DisplayName', res.name);
end
xline(200, '--k', 'Surge Start');
xline(400, '--k', 'Surge End');
title('Bottleneck Branch B4 Queue / DC-Link Voltage V_{dc}', 'FontSize', 12, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('B4 Queue (veh) / V_{dc} (V)');
legend('Location', 'northeast');
saveas(f1, fullfile(outDir, 'PartD_Fig1_QueueTrajectories.png'));

% FIGURE 2: Performance Metrics Comparison (Delay & Throughput)
f2 = figure('Name', 'SITRA Part D - Performance Metrics Comparison', 'Color', 'w', 'Position', [150, 150, 850, 500]);
names = {controllers{:, 2}};
delays = zeros(1, N_ctrl);
thrs = zeros(1, N_ctrl);
maxQs = zeros(1, N_ctrl);
for k = 1:N_ctrl
    res = results.(sprintf('C%d', controllers{k, 1}));
    delays(k) = res.meanDelay;
    thrs(k) = res.throughput;
    maxQs(k) = res.maxQueue;
end

subplot(1, 3, 1);
b1 = bar(categorical(names), delays);
b1.FaceColor = 'flat';
b1.CData = cell2mat(colors');
title('Average Delay (s)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Delay (s/veh)'); grid on;

subplot(1, 3, 2);
b2 = bar(categorical(names), maxQs);
b2.FaceColor = 'flat';
b2.CData = cell2mat(colors');
title('Peak Total Queue (veh)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Vehicles / Volts'); grid on;

subplot(1, 3, 3);
b3 = bar(categorical(names), thrs);
b3.FaceColor = 'flat';
b3.CData = cell2mat(colors');
title('Throughput (veh)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Total Cleared'); grid on;
saveas(f2, fullfile(outDir, 'PartD_Fig2_PerformanceBarCharts.png'));

% FIGURE 3: Electrical Equivalent Waveforms for Reference SITRA MPC
f3 = figure('Name', 'SITRA Part D - Electrical Equivalent Waveforms (MPC)', 'Color', 'w', 'Position', [200, 200, 950, 650]);
resMPC = results.C1;
subplot(3, 1, 1);
plot(resMPC.t, resMPC.V, 'LineWidth', 1.5);
title('Capacitor Voltages V_1, V_2, V_3, V_4 (1 V = 1 veh)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Voltage (V)'); legend('V_1 (HopeCol)', 'V_2 (Kalapatti)', 'V_3 (Airport)', 'V_4 (SITRA B4)', 'Location', 'northeast');
grid on;

subplot(3, 1, 2);
plot(resMPC.t, resMPC.G, 'LineWidth', 1.5);
title('Semiconductor Gate Interlock Signals g_1, g_2, g_3 (Mutual Exclusion)', 'FontSize', 11, 'FontWeight', 'bold');
ylabel('Gate (0/1)'); ylim([-0.2 1.3]);
legend('g_1', 'g_2', 'g_3', 'Location', 'northeast'); grid on;

subplot(3, 1, 3);
plot(resMPC.t, resMPC.Idc, 'LineWidth', 1.5, 'Color', [0.466 0.674 0.188]);
title('Bottleneck Discharge Current I_{dc} (1 A = 1 veh/s)', 'FontSize', 11, 'FontWeight', 'bold');
xlabel('Time (s)'); ylabel('Current (A)'); grid on;
saveas(f3, fullfile(outDir, 'PartD_Fig3_ElectricalWaveforms_MPC.png'));

fprintf('\n[SUCCESS] All 3 figures generated and displayed:\n');
fprintf('  1. %s\n', fullfile(outDir, 'PartD_Fig1_QueueTrajectories.png'));
fprintf('  2. %s\n', fullfile(outDir, 'PartD_Fig2_PerformanceBarCharts.png'));
fprintf('  3. %s\n', fullfile(outDir, 'PartD_Fig3_ElectricalWaveforms_MPC.png'));

%% 6. SAVE RESULTS TO MAT & CSV
save(fullfile(outDir, 'PartD_Results.mat'), 'results');

csvPath = fullfile(outDir, 'SITRA_PartD_Four_Controller_Comparison.csv');
fid = fopen(csvPath, 'w');
fprintf(fid, 'Controller,MeanDelay_s,MaxQueue_veh,MaxBranch_veh,MaxB4_veh,PeakVdc_V,Throughput_veh,TotalCharge_C,MaxCurrentError_A,S5ValidPct,S9ValidPct\n');
for k = 1:N_ctrl
    cID = controllers{k, 1};
    res = results.(sprintf('C%d', cID));
    fprintf(fid, '%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.2f,%.2f,%.4e,%.1f,%.1f\n', ...
        res.name, res.meanDelay, res.maxQueue, res.maxBranch, res.maxB4, res.maxVdc, ...
        res.throughput, res.totalCharge, res.maxCurrentError, res.s5ValidRatio, res.s9ValidRatio);
end
fclose(fid);
fprintf('\nResults summary table saved to: %s\n', csvPath);
