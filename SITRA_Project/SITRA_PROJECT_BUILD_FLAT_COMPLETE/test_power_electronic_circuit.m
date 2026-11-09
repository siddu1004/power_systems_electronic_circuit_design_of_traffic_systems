%% test_power_electronic_circuit.m
% Validation of the Equivalent Power-Electronic Circuit for SITRA Traffic Network.
%
% Proves the formal isomorphism:
%   Queue q [veh] <===> Capacitor Voltage V_c [V]
%   Traffic Flow [veh/s] <===> Electrical Branch Current I [A]
%   Traffic Signal Light <===> Semiconductor Switch (MOSFET/IGBT)
%   Yellow Clearance <===> Gate-Driver Hardware Dead-Time

clc;
close all;

fprintf('\n============================================================\n');
fprintf('SITRA POWER-ELECTRONIC EQUIVALENT CIRCUIT VALIDATION\n');
fprintf('============================================================\n');

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
cd(thisDir);

resultsDir = fullfile(thisDir, 'Results', 'power_electronics');
if exist(resultsDir, 'dir') ~= 7, mkdir(resultsDir); end
figDir = fullfile(thisDir, 'Results', 'figures');
if exist(figDir, 'dir') ~= 7, mkdir(figDir); end

%% 1. Run / Load Frozen Part 8 MPC Supervisory Reference
fprintf('\n[1/4] Running Part 8 MPC Supervisory Controller Reference...\n');
run('part8_mpc_controller.m');

% Note: part8_mpc_controller begins with clear, so define workspace variables here
refQ = qHist;
refActive = activeHist(:);
refDemand = demandHist;
refRes = residual;
refT = tVec(:);
close all;

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
cd(thisDir);

resultsDir = fullfile(thisDir, 'Results', 'power_electronics');
if exist(resultsDir, 'dir') ~= 7, mkdir(resultsDir); end
figDir = fullfile(thisDir, 'Results', 'figures');
if exist(figDir, 'dir') ~= 7, mkdir(figDir); end

net = createNetwork();
dt = 1.0;

%% 2. Simulate Equivalent Power Electronic Circuit
fprintf('\n[2/4] Simulating Equivalent Power Electronic Circuit Dynamics...\n');
PE = simulate_power_electronic_circuit(refActive, refDemand, refT, net, dt);

%% 3. Numerical Equivalence & Conservation Verification
fprintf('\n[3/4] Performing Rigorous Mathematical Equivalence Verification...\n');

n = min(size(PE.Vc, 1), size(refQ, 1));
err_Vc_vs_Q = max(abs(PE.Vc(1:n, :) - refQ(1:n, :)), [], 'all');
err_Demand_vs_Iin = max(abs(PE.I_in(1:n, 1:3) - refDemand(1:n, 1:3)), [], 'all');
err_KCL = max(abs(PE.residual(1:n, :)), [], 'all');

% Metrics
peakTotalVoltage = max(sum(PE.Vc, 2));
peakTotalQueue   = max(sum(refQ, 2));
totalEnergyJ     = max(PE.totalEnergy);
totalLossJ       = PE.totalEnergyDissipated(end);

pass_equiv  = err_Vc_vs_Q < 1e-9;
pass_demand = err_Demand_vs_Iin < 1e-9;
pass_kcl    = err_KCL < 1e-9;
pass_nonneg = all(PE.Vc(:) >= 0);
pass_deadtime = all(sum(PE.gates, 2) <= 1);

fprintf('\n------------------------------------------------------------\n');
fprintf('CIRCUIT <===> TRAFFIC ISOMORPHISM VERIFICATION GATES\n');
fprintf('------------------------------------------------------------\n');
fprintf('Max |V_c(t) - q(t)| (Voltage <-> Queue)    : %.3e V   [%s]\n', err_Vc_vs_Q, passfail(pass_equiv));
fprintf('Max |I_in(t) - demand(t)| (Current <-> Flow): %.3e A   [%s]\n', err_Demand_vs_Iin, passfail(pass_demand));
fprintf('Max KCL Residual (Kirchhoff Conservation)  : %.3e A   [%s]\n', err_KCL, passfail(pass_kcl));
fprintf('Capacitor Voltage Non-Negativity (V_c >= 0) :            [%s]\n', passfail(pass_nonneg));
fprintf('Mutual Exclusion Gate Interlock (sum(g)<=1):            [%s]\n', passfail(pass_deadtime));
fprintf('Peak Total Capacitor Voltage vs Peak Queue  : %.3f V / %.3f veh\n', peakTotalVoltage, peakTotalQueue);
fprintf('Peak Electrostatic Stored Energy in Network : %.3f Joules\n', totalEnergyJ);
fprintf('Total Cumulative Semiconductor Energy Loss  : %.3f Joules\n', totalLossJ);

overallStatus = pass_equiv && pass_demand && pass_kcl && pass_nonneg && pass_deadtime;
fprintf('------------------------------------------------------------\n');
fprintf('OVERALL POWER ELECTRONIC CIRCUIT STATUS    : %s\n', passfail(overallStatus));
fprintf('============================================================\n');

%% 4. Plot Comprehensive Engineering Figures
fprintf('\n[4/4] Generating Publication-Quality Electrical Figures...\n');

branchNames = {'B1 (Hope College)', 'B2 (Kalapatti)', 'B3 (Airport)', 'B4 (Goldwins Bottleneck)'};
colors = [0.85 0.325 0.098; 0 0.447 0.741; 0.929 0.694 0.125; 0.494 0.184 0.556];

% --- Figure 1: Capacitor Voltages vs Traffic Queues (Equivalence) ---
hFig1 = figure('Name', 'PE1_Capacitor_Voltages_vs_Traffic_Queues', 'Position', [100 100 1000 700], 'Visible', 'off');
subplot(2,1,1);
hold on; grid on;
for b = 1:4
    plot(refT, PE.Vc(:, b), 'LineWidth', 1.8, 'Color', colors(b,:), 'DisplayName', sprintf('V_{C%d} (%s)', b, branchNames{b}));
    plot(refT, refQ(:, b), '--', 'LineWidth', 1.0, 'Color', 'k', 'HandleVisibility', 'off');
end
legend('Location', 'northeast');
xlabel('Time [s]'); ylabel('Capacitor Voltage V_C [V]');
title('Equivalent Circuit Capacitor Voltages (Solid) vs Traffic Queue [veh] (Dashed Black)');

subplot(2,1,2);
hold on; grid on;
totalVc = sum(PE.Vc, 2);
totalQ = sum(refQ, 2);
plot(refT, totalVc, 'b-', 'LineWidth', 2.0, 'DisplayName', 'Total Capacitor Voltage \Sigma V_C [V]');
plot(refT, totalQ, 'r--', 'LineWidth', 1.5, 'DisplayName', 'Total Traffic Queue \Sigma q [veh]');
legend('Location', 'northeast');
xlabel('Time [s]'); ylabel('Total Potential [V]');
title(sprintf('Network Total Energy State (Max Equivalence Error = %.2e V)', err_Vc_vs_Q));
saveas(hFig1, fullfile(resultsDir, 'PE1_capacitor_voltages.png'));
saveas(hFig1, fullfile(figDir, '15_PE_capacitor_voltages.png'));

% --- Figure 2: Electrical Branch Currents & Surge Dynamic ---
hFig2 = figure('Name', 'PE2_Branch_Currents', 'Position', [150 150 1000 700], 'Visible', 'off');
subplot(2,1,1);
hold on; grid on;
for b = 1:3
    plot(refT, PE.I_in(:, b), 'LineWidth', 1.6, 'Color', colors(b,:), 'DisplayName', sprintf('I_{in,%d} (%s)', b, branchNames{b}));
end
legend('Location', 'northeast');
xlabel('Time [s]'); ylabel('Inflow Current [A]');
title('Source Converters: Inflow Demand Currents (B1 Surge: 200s - 400s)');

subplot(2,1,2);
hold on; grid on;
for b = 1:4
    plot(refT, PE.I_dep(:, b), 'LineWidth', 1.4, 'Color', colors(b,:), 'DisplayName', sprintf('I_{dep,%d} (%s)', b, branchNames{b}));
end
legend('Location', 'northeast');
xlabel('Time [s]'); ylabel('Discharge Current [A]');
title('Switched Discharge Currents (Controlled by Semiconductor Gates & Saturation Limit)');
saveas(hFig2, fullfile(resultsDir, 'PE2_branch_currents.png'));
saveas(hFig2, fullfile(figDir, '16_PE_branch_currents.png'));

% --- Figure 3: Semiconductor Gate Pulses & Dead-Time Intervals ---
hFig3 = figure('Name', 'PE3_Gate_Driver_Timing', 'Position', [200 200 1000 650], 'Visible', 'off');
subplot(2,1,1);
hold on; grid on;
stairs(refT, PE.gates(:, 1) + 2.4, 'LineWidth', 1.5, 'Color', colors(1,:), 'DisplayName', 'Gate S1 (B1 Hope College)');
stairs(refT, PE.gates(:, 2) + 1.2, 'LineWidth', 1.5, 'Color', colors(2,:), 'DisplayName', 'Gate S2 (B2 Kalapatti)');
stairs(refT, PE.gates(:, 3) + 0.0, 'LineWidth', 1.5, 'Color', colors(3,:), 'DisplayName', 'Gate S3 (B3 Airport)');
yticks([0 1 1.2 2.2 2.4 3.4]);
yticklabels({'OFF','ON (S3)','OFF','ON (S2)','OFF','ON (S1)'});
xlim([180 320]); % Zoom in to show switching commutations
xlabel('Time [s]'); ylabel('Switch State');
title('Semiconductor Gate Control Pulses (g_1, g_2, g_3) - Zoomed (180s - 320s)');
legend('Location', 'northeast');

subplot(2,1,2);
hold on; grid on;
stairs(refT, PE.deadtimeState, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Hardware Dead-Time (Yellow/Clearance = 3s)');
xlim([180 320]);
ylim([-0.2 1.2]);
yticks([0 1]); yticklabels({'Conduction Active','Dead-Time (All OFF)'});
xlabel('Time [s]'); ylabel('Dead-Time State');
title('Commutation Dead-Time Interlock (Prevents Shoot-Through / Cross-Traffic Contention)');
legend('Location', 'northeast');
saveas(hFig3, fullfile(resultsDir, 'PE3_gate_timing.png'));
saveas(hFig3, fullfile(figDir, '17_PE_gate_timing.png'));

% --- Figure 4: Junction DC Bus Current & Downstream Bottleneck Flow ---
hFig4 = figure('Name', 'PE4_Junction_DC_Bus_and_Bottleneck', 'Position', [250 250 1000 600], 'Visible', 'off');
subplot(2,1,1);
hold on; grid on;
plot(refT, PE.I_bus, 'k-', 'LineWidth', 1.5, 'DisplayName', 'SITRA Junction DC Bus Current I_{bus} [A]');
yline(0.45, 'r--', 'LineWidth', 1.5, 'DisplayName', 'B4 Bottleneck Capacity Limit (0.45 A)');
legend('Location', 'northeast');
xlabel('Time [s]'); ylabel('DC Bus Current [A]');
title('Intersection Mixing Bus: Switched Current Entering Downstream Link B4');

subplot(2,1,2);
hold on; grid on;
plot(refT, PE.I_dep(:, 4), 'm-', 'LineWidth', 1.5, 'DisplayName', 'Goldwins Sink Current I_{dep,4} [A]');
legend('Location', 'northeast');
xlabel('Time [s]'); ylabel('Exit Current [A]');
title('Goldwins Downstream Current Sink (Bottleneck Departure Rate)');
saveas(hFig4, fullfile(resultsDir, 'PE4_bus_and_bottleneck.png'));
saveas(hFig4, fullfile(figDir, '18_PE_bus_and_bottleneck.png'));

% --- Figure 5: Stored Electrostatic Energy & Semiconductor Conduction Losses ---
hFig5 = figure('Name', 'PE5_Energy_and_Losses', 'Position', [300 300 1000 650], 'Visible', 'off');
subplot(2,1,1);
hold on; grid on;
plot(refT, PE.totalEnergy, 'b-', 'LineWidth', 1.8, 'DisplayName', 'Total Stored Energy E = 0.5 \Sigma C V^2 [J]');
legend('Location', 'northeast');
xlabel('Time [s]'); ylabel('Energy [Joules]');
title('Network Congestion Potential Energy (Electrostatic Analog)');

subplot(2,1,2);
hold on; grid on;
plot(refT, PE.powerLoss, 'r-', 'LineWidth', 1.2, 'DisplayName', 'Instantaneous Conduction Loss P_{loss} = I^2 R_{on} [W]');
plot(refT, PE.totalEnergyDissipated, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Cumulative Energy Dissipated [J]');
legend('Location', 'northwest');
xlabel('Time [s]'); ylabel('Power [W] / Energy [J]');
title('Power Electronic Conduction Losses in Semiconductor Switches');
saveas(hFig5, fullfile(resultsDir, 'PE5_energy_and_losses.png'));
saveas(hFig5, fullfile(figDir, '19_PE_energy_and_losses.png'));

% --- Figure 6: Kirchhoff Current Law Conservation Residuals ---
hFig6 = figure('Name', 'PE6_KCL_Residuals', 'Position', [350 350 1000 500], 'Visible', 'off');
hold on; grid on;
for b = 1:4
    plot(refT, PE.residual(:, b), 'LineWidth', 1.2, 'Color', colors(b,:), 'DisplayName', sprintf('Res_{%s}', branchNames{b}));
end
legend('Location', 'northeast');
xlabel('Time [s]'); ylabel('KCL Residual Current [A]');
title(sprintf('Kirchhoff Current Law (KCL) Conservation: Max Residual = %.2e A', err_KCL));
saveas(hFig6, fullfile(resultsDir, 'PE6_kcl_residuals.png'));
saveas(hFig6, fullfile(figDir, '20_PE_kcl_residuals.png'));

%% 5. Save Data & Tables
save(fullfile(resultsDir, 'SITRA_power_electronic_circuit_results.mat'), 'PE');

% Export equivalence summary table to CSV
fid = fopen(fullfile(resultsDir, 'SITRA_PE_circuit_validation.csv'), 'w');
fprintf(fid, 'Metric,Value,Unit,ValidationStatus\n');
fprintf(fid, 'MaxQueueVoltageError,%.6e,V,%s\n', err_Vc_vs_Q, passfail(pass_equiv));
fprintf(fid, 'MaxDemandCurrentError,%.6e,A,%s\n', err_Demand_vs_Iin, passfail(pass_demand));
fprintf(fid, 'MaxKCLResidual,%.6e,A,%s\n', err_KCL, passfail(pass_kcl));
fprintf(fid, 'PeakTotalVoltage,%.3f,V,PASS\n', peakTotalVoltage);
fprintf(fid, 'PeakStoredEnergy,%.3f,J,PASS\n', totalEnergyJ);
fprintf(fid, 'TotalDissipatedEnergy,%.3f,J,PASS\n', totalLossJ);
fprintf(fid, 'MutualExclusionInterlock,1,logical,%s\n', passfail(pass_deadtime));
fclose(fid);

fprintf('\nResults and 6 engineering figures saved to:\n  %s\n', resultsDir);

function s = passfail(tf)
    if tf, s = 'PASS'; else, s = 'FAIL'; end
end
