function plot_dual_domain(outDir)
%PLOT_DUAL_DOMAIN  Generate synchronized 4-panel figures for dual-domain dynamics.
%
%   Generates 8 figures (4 controllers x 2 scenarios: T6 surge, T9 incident):
%     (a) Gates g1-g3 (0/1) / MOSFET gate drive
%     (b) Queues q1-q4 [veh] / Capacitor voltages v_C1-v_C4 [V]
%     (c) Discharge currents i_b [A] / Departures [veh/s]
%     (d) What the controller "sees" (qSeen) vs true queue
%
%   Saved to <root>/Results/dual_domain/<ctrl>_<scn>.png

here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
root = fileparts(here);
addpath(root); addpath(here);
if nargin < 1 || isempty(outDir)
    outDir = fullfile(root, 'Results', 'dual_domain');
end
if ~exist(outDir, 'dir'), mkdir(outDir); end

topOutDir = fullfile(fileparts(root), 'Results', 'dual_domain');
if ~exist(topOutDir, 'dir'), mkdir(topOutDir); end

p = bl_config();
net = createNetwork();
allScn = bl_scenarios(p);

targetScns = {'T6', 'T9'};
controllers = {'SITRA', 'Webster', 'Actuated', 'MaxPressure'};

for sIdx = 1:numel(targetScns)
    sId = targetScns{sIdx};
    s = allScn(strcmp({allScn.id}, sId));
    if isempty(s)
        warning('Scenario %s not found', sId);
        continue;
    end
    
    pRun = p;
    if isfield(s, 'q0') && ~isempty(s.q0), pRun.q0 = s.q0; else, pRun.q0 = zeros(1,4); end
    if isfield(s, 'events'), pRun.events = s.events; else, pRun.events = []; end
    
    if s.stochastic, seed = 101; else, seed = 0; end
    A = bl_make_arrivals(s, pRun, seed);
    if isfield(s, 'events') && ~isempty(s.events)
        A = bl_inject('apply_demand', A, s.events);
    end
    
    for cIdx = 1:numel(controllers)
        ctrl = controllers{cIdx};
        R = bl_simulate(ctrl, A, pRun, net);
        
        h = figure('Name', sprintf('%s_%s', ctrl, s.id), 'Visible', 'off', ...
                   'Position', [100 100 1000 800]);
        
        % Panel (a): Gates / MOSFET Gate Drive
        subplot(4, 1, 1);
        stairs(R.tVec, R.gates(:, 1), 'b-', 'LineWidth', 1.4); hold on;
        stairs(R.tVec, R.gates(:, 2), 'Color', [0.85 0.40 0.10], 'LineWidth', 1.4);
        stairs(R.tVec, R.gates(:, 3), 'Color', [0.20 0.60 0.30], 'LineWidth', 1.4);
        ylabel({'Gates (0/1)', 'MOSFET Drive'});
        title(sprintf('Dual-Domain Operation: %s on %s (%s)', ctrl, s.id, s.name), ...
              'FontSize', 11, 'FontWeight', 'bold');
        legend({'g_1 (B1)', 'g_2 (B2)', 'g_3 (B3)'}, 'Location', 'eastoutside');
        ylim([-0.1 1.2]); xlim([0 R.tVec(end)]); grid on;
        
        % Panel (b): Queues / Capacitor Voltages
        subplot(4, 1, 2);
        plot(R.tVec, R.qHist(:, 1), 'b-', 'LineWidth', 1.4); hold on;
        plot(R.tVec, R.qHist(:, 2), 'Color', [0.85 0.40 0.10], 'LineWidth', 1.4);
        plot(R.tVec, R.qHist(:, 3), 'Color', [0.20 0.60 0.30], 'LineWidth', 1.4);
        plot(R.tVec, R.qHist(:, 4), 'm--', 'LineWidth', 1.4);
        ylabel({'Queue [veh]', 'Capacitor v_C [V]'});
        legend({'q_1 / v_{C1}', 'q_2 / v_{C2}', 'q_3 / v_{C3}', 'q_4 / v_{C4}'}, 'Location', 'eastoutside');
        xlim([0 R.tVec(end)]); grid on;
        
        % Panel (c): Discharge currents / Departures
        subplot(4, 1, 3);
        plot(R.tVec, R.depHist(:, 1), 'b-', 'LineWidth', 1.4); hold on;
        plot(R.tVec, R.depHist(:, 2), 'Color', [0.85 0.40 0.10], 'LineWidth', 1.4);
        plot(R.tVec, R.depHist(:, 3), 'Color', [0.20 0.60 0.30], 'LineWidth', 1.4);
        plot(R.tVec, R.depHist(:, 4), 'm--', 'LineWidth', 1.4);
        ylabel({'Departure [veh/s]', 'Current i_b [A]'});
        legend({'i_{dep,1}', 'i_{dep,2}', 'i_{dep,3}', 'i_{exit,4}'}, 'Location', 'eastoutside');
        xlim([0 R.tVec(end)]); grid on;
        
        % Panel (d): Observed vs True Approach Queue
        subplot(4, 1, 4);
        qTotTrue = sum(R.qHist(:, 1:3), 2);
        qTotSeen = sum(R.qSeen(:, 1:3), 2);
        plot(R.tVec, qTotTrue, 'b-', 'LineWidth', 1.8); hold on;
        plot(R.tVec, qTotSeen, 'r--', 'LineWidth', 1.2);
        ylabel({'Approach Queue', '[veh]'});
        xlabel('Time [s]');
        legend({'True Queue (Plant)', 'Observed Queue (Ctrl)'}, 'Location', 'eastoutside');
        xlim([0 R.tVec(end)]); grid on;
        
        fileName = sprintf('%s_%s.png', ctrl, s.id);
        set(h, 'PaperPositionMode', 'auto');
        print(h, fullfile(outDir, fileName), '-dpng', '-r130');
        print(h, fullfile(topOutDir, fileName), '-dpng', '-r130');
        close(h);
        fprintf('Saved dual-domain figure: %s\n', fileName);
    end
end
fprintf('All 8 dual-domain figures saved successfully.\n');
end
