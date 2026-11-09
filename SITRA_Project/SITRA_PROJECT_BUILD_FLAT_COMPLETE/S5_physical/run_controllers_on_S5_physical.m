%% run_controllers_on_S5_physical.m
% Runs all 4 controllers (SITRA MPC, Webster, Actuated, MaxPressure)
% through the real Simscape physical circuit (SITRA_S5_Physical.slx) on
% scenarios T5, T6, T7, and T8.
%
% Measures clearance time directly from the capacitor voltages vC_B1..vC_B3
% and compares against the baseline model queue trajectories.
%
% Outputs:
%   - Results/S5_physical/controller_clearance_physical.csv
%   - Results/S5_physical/fig_clearance_physical.png (2x2 grid)

function results = run_controllers_on_S5_physical()

here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
root = fileparts(here);
addpath(here);
addpath(root);
addpath(genpath(fullfile(root, 'baselines')));

outDir = fullfile(root, 'Results', 'S5_physical');
if ~exist(outDir, 'dir'), mkdir(outDir); end

topOutDir = fullfile(fileparts(root), 'Results', 'S5_physical');
if ~exist(topOutDir, 'dir'), mkdir(topOutDir); end

mdl = 'SITRA_S5_Physical';
if ~bdIsLoaded(mdl)
    load_system(mdl);
end

% Ensure S5 parameters are initialized in base workspace
S5_base = S5_physical_params();
assignin('base', 'S5', S5_base);

p = bl_config();
net = createNetwork();
allScn = bl_scenarios(p);

% Target evaluation runs:
% T5: deterministic (seed 0)
% T6: deterministic (seed 0)
% T7: stochastic (seed 101)
% T8: stochastic (seed 101)
evalRuns = {
    struct('scnIdx', 5, 'seed', 0,   'name', 'T5 (step 600s)')
    struct('scnIdx', 6, 'seed', 0,   'name', 'T6 (surge 200-400s)')
    struct('scnIdx', 7, 'seed', 101, 'name', 'T7 (surge Poisson)')
    struct('scnIdx', 8, 'seed', 101, 'name', 'T8 (congested start)')
};

controllers = {'SITRA', 'Webster', 'Actuated', 'MaxPressure'};
ctrlColors  = struct('SITRA', [0 0.4470 0.7410], ...
                     'Webster', [0.8500 0.3250 0.0980], ...
                     'Actuated', [0.9290 0.6940 0.1250], ...
                     'MaxPressure', [0.4940 0.1840 0.5560]);

numRuns = numel(evalRuns) * numel(controllers);
recScenario      = cell(numRuns, 1);
recController    = cell(numRuns, 1);
rectClearModel   = zeros(numRuns, 1);
rectClearCirc    = zeros(numRuns, 1);
recCleared       = false(numRuns, 1);
recMaxErrV       = zeros(numRuns, 1);
recExcessVehS    = zeros(numRuns, 1);
recQpeak         = zeros(numRuns, 1);
recQbase         = zeros(numRuns, 1);

% Prepare data cache for plotting
plotData = struct();

fprintf('========================================================================\n');
fprintf(' SITRA S5: Controller Clearance Time Comparison on Physical Simscape Circuit\n');
fprintf('========================================================================\n');

set_param([mdl '/Power_Path'], 'Commented', 'on');
rowIdx = 0;

for r = 1:numel(evalRuns)
    target = evalRuns{r};
    s = allScn(target.scnIdx);
    pRun = p;
    if isfield(s, 'q0') && ~isempty(s.q0)
        pRun.q0 = s.q0;
    else
        pRun.q0 = zeros(1, 4);
    end
    
    A = bl_make_arrivals(s, pRun, target.seed);
    plotData.(sprintf('run_%d', r)).name = s.name;
    plotData.(sprintf('run_%d', r)).tEvent = s.tEvent;
    plotData.(sprintf('run_%d', r)).tBaseWin = s.tBaseWin;
    
    for c = 1:numel(controllers)
        ctrlName = controllers{c};
        rowIdx = rowIdx + 1;
        
        fprintf('\n--- [%d/%d] %s on %s (seed %d) ---\n', ...
            rowIdx, numRuns, ctrlName, s.name, target.seed);
        
        % 1. Baseline model simulation
        R = bl_simulate(ctrlName, A, pRun, net);
        S = bl_export_for_simulink(R);
        
        % 2. Setup inputs for SITRA_S5_Physical
        S5 = evalin('base', 'S5');
        t0 = S.arrivals(1, 1);
        S5.arrivals = [S.arrivals(:, 1) - t0, S.arrivals(:, 2:end)];
        S5.gates    = [S.gates(:, 1) - t0,    S.gates(:, 2:end)];
        S5.hwGates  = S5.gates;
        S5.vC0      = pRun.q0;  % Initial capacitor charges
        N = size(S.qRef, 1);
        S5.stopTime = N - 1;
        S5.maxStep  = 0.05;
        assignin('base', 'S5', S5);
        
        % 3. Run physical circuit
        tic;
        out = sim(mdl, 'ReturnWorkspaceOutputs', 'on');
        simTime = toc;
        
        % 4. Extract capacitor voltages
        vC = out.S5_vC.signals.values(1:N, :);
        tv = out.S5_vC.time(1:N);
        qRef = S.qRef(:, 2:5);
        
        maxErr = max(max(abs(vC - qRef)));
        fprintf('Sim time: %.2f s | Max |vC - qRef| = %.3e V\n', simTime, maxErr);
        assert(maxErr < 1e-3, 'Circuit voltage deviates from queue reference (> 1 mV)');
        
        % 5. Approach queue (branches B1..B3)
        Qcirc  = sum(vC(:, 1:3), 2);
        Qmodel = sum(qRef(:, 1:3), 2);
        
        % 6. Compute clearance
        Cc = bl_clearance(tv, Qcirc, s.tEvent, s.tBaseWin);
        Cm = bl_clearance(tv, Qmodel, s.tEvent, s.tBaseWin);
        
        % Consistency assertion
        if isnan(Cm.tClear)
            assert(isnan(Cc.tClear), 'Clearance state mismatch (model NaN, circuit not NaN)');
        else
            assert(abs(Cc.tClear - Cm.tClear) <= 1.0, ...
                'Clearance time discrepancy between circuit and model exceeds 1 s');
        end
        
        recScenario{rowIdx}    = s.name;
        recController{rowIdx}  = ctrlName;
        rectClearModel(rowIdx) = Cm.tClear;
        rectClearCirc(rowIdx)  = Cc.tClear;
        recCleared(rowIdx)     = Cc.cleared;
        recMaxErrV(rowIdx)     = maxErr;
        recExcessVehS(rowIdx)  = Cc.excessVehS;
        recQpeak(rowIdx)       = Cc.Qpeak;
        recQbase(rowIdx)       = Cc.Qbase;
        
        if isnan(Cc.tClear)
            fprintf('Clearance: NOT CLEARED | Excess queue: %.1f veh*s | Qpeak = %.1f veh\n', ...
                Cc.excessVehS, Cc.Qpeak);
        else
            fprintf('Clearance time: %.1f s | Excess queue: %.1f veh*s | Qbase = %.1f, Qpeak = %.1f\n', ...
                Cc.tClear, Cc.excessVehS, Cc.Qbase, Cc.Qpeak);
        end
        
        % Save for plotting
        plotData.(sprintf('run_%d', r)).(ctrlName).t = tv;
        plotData.(sprintf('run_%d', r)).(ctrlName).Q = Qcirc;
        plotData.(sprintf('run_%d', r)).(ctrlName).tClear = Cc.tClear;
        plotData.(sprintf('run_%d', r)).(ctrlName).cleared = Cc.cleared;
    end
end

set_param([mdl '/Power_Path'], 'Commented', 'off');

% Format results table
T = table(recScenario, recController, rectClearModel, rectClearCirc, ...
    recCleared, recMaxErrV, recExcessVehS, recQpeak, recQbase, ...
    'VariableNames', {'Scenario', 'Controller', 'tClear_Model_s', 'tClear_Circuit_s', ...
                      'Cleared', 'MaxErr_V', 'ExcessVehS', 'Qpeak_veh', 'Qbase_veh'});

csvFile = fullfile(outDir, 'controller_clearance_physical.csv');
writetable(T, csvFile);
topCsvFile = fullfile(topOutDir, 'controller_clearance_physical.csv');
writetable(T, topCsvFile);
fprintf('\nSaved results CSV to: %s\n', csvFile);

% Plot 2x2 grid
fig = figure('Name', 'Circuit Congestion Clearance Comparison', ...
             'Position', [100 100 1200 800], 'Visible', 'off');

for r = 1:numel(evalRuns)
    subplot(2, 2, r);
    hold on; grid on; box on;
    d = plotData.(sprintf('run_%d', r));
    
    for c = 1:numel(controllers)
        ctrlName = controllers{c};
        cdat = d.(ctrlName);
        plot(cdat.t, cdat.Q, 'LineWidth', 1.4, 'Color', ctrlColors.(ctrlName), ...
             'DisplayName', sprintf('%s (t_{clear}=%.0fs)', ctrlName, cdat.tClear));
    end
    
    if ~isnan(d.tEvent)
        xline(d.tEvent, 'k--', 'LineWidth', 1.2, 'DisplayName', sprintf('Event (t=%.0fs)', d.tEvent));
    end
    
    title(d.name, 'FontSize', 11, 'FontWeight', 'bold');
    xlabel('Time [s]');
    ylabel('Approach Queue Q_{B1..B3} [veh = V]');
    legend('Location', 'northeast', 'FontSize', 8);
    xlim([0 max(cdat.t)]);
end

figFile = fullfile(outDir, 'fig_clearance_physical.png');
saveas(fig, figFile);
topFigFile = fullfile(topOutDir, 'fig_clearance_physical.png');
saveas(fig, topFigFile);
close(fig);
fprintf('Saved comparison figure to: %s\n', figFile);

% Print summary ranking
fprintf('\n========================================================================\n');
fprintf(' CIRCUIT CLEARANCE TIME COMPARISON SUMMARY\n');
fprintf('========================================================================\n');
disp(T);

results = T;
end
