function RES = run_baseline_comparison(showFigures)
%RUN_BASELINE_COMPARISON  SITRA vs Webster vs actuated vs max-pressure, T1-T7.
%
%   run_baseline_comparison          % figures on screen
%   run_baseline_comparison(false)   % off-screen (batch), PNGs still saved
%
%   For every scenario T1..T7 and every seed in bl_config, ONE arrival
%   sequence is generated and fed to every controller (identical arrivals,
%   capacities, initial queues, duration, seed).  Metrics are averaged
%   over seeds.  Deterministic T6 uses a single run.
%
%   Outputs in <root>/Results/baselines/:
%     baseline_comparison.csv         mean metrics per scenario x controller
%     baseline_runs_per_seed.csv      every individual run
%     baseline_results.mat            everything, incl. mean queue traces
%     fig1_queue_vs_time.png          T1-T4 total approach queue
%     fig2_delay_vs_demand.png        avg delay vs total demand + LOS bands
%     fig3_throughput.png             throughput bars T1-T7
%     fig4_max_queue.png              max approach queue bars T1-T7
%     fig5_step_response.png          T5 step demand: demand + queue
%     fig6_part8_surge.png            T6/T7 total queue (Part 8 scenario)

if nargin < 1, showFigures = true; end

[~, outDir] = bl_paths();
p = bl_config();
p.showFigures = showFigures;
net = createNetwork();
scn = bl_scenarios(p);
ctrls = p.controllers;
nS = numel(scn); nC = numel(ctrls);

fprintf('\nSITRA BASELINE COMPARISON  (%d scenarios x %d controllers)\n', nS, nC);

% ---- integration gate first -------------------------------------------------
if ~test_bl_integration()
    error('Integration check failed: the harness does not reproduce frozen Part 8. Stop.');
end

fields = {'avgDelay','netDelay','avgQueue','maxQueue','maxQueueB4', ...
          'throughput','throughputRate','finalQueue','maxResidual'};
mean_ = struct(); std_ = struct();
for f = 1:numel(fields)
    mean_.(fields{f}) = zeros(nS,nC);
    std_.(fields{f})  = zeros(nS,nC);
end
LOS = cell(nS,nC);
traces = cell(nS,nC);     % mean total-approach queue over seeds
tAxis = cell(nS,1);
rateAxis = cell(nS,1);
perSeed = {};

fidSeed = fopen(fullfile(outDir,'baseline_runs_per_seed.csv'),'w');
fprintf(fidSeed, 'Scenario,Controller,Seed,AvgDelay_s,NetDelay_s,AvgQueue_veh,MaxQueue_veh,MaxQueueB4_veh,Throughput_veh,FinalQueue_veh,LOS\n');

for i = 1:nS
    s = scn(i);
    if s.stochastic, seeds = p.seeds; else, seeds = 0; end
    vals = zeros(numel(seeds), nC, numel(fields));
    for j = 1:numel(seeds)
        A = bl_make_arrivals(s, p, seeds(j));     % SAME arrivals for all controllers
        if j == 1
            tAxis{i} = A.tVec(:);
            rateAxis{i} = A.rate;
            for c = 1:nC, traces{i,c} = zeros(numel(A.tVec),1); end
        end
        for c = 1:nC
            R = bl_simulate(ctrls{c}, A, p, net);
            M = bl_metrics(R);
            for f = 1:numel(fields)
                vals(j,c,f) = M.(fields{f});
            end
            traces{i,c} = traces{i,c} + sum(R.qHist(:,1:3),2)/numel(seeds);
            fprintf(fidSeed, '%s,%s,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f,%.3f,%s\n', ...
                s.id, ctrls{c}, seeds(j), M.avgDelay, M.netDelay, M.avgQueue, ...
                M.maxQueue, M.maxQueueB4, M.throughput, M.finalQueue, M.LOS);
            if s.stochastic == false || j == 1
                perSeed{end+1} = bl_export_for_simulink(R); %#ok<AGROW>
                perSeed{end}.scenario = s.id;
            end
        end
    end
    for f = 1:numel(fields)
        mean_.(fields{f})(i,:) = mean(vals(:,:,f), 1);
        std_.(fields{f})(i,:)  = std(vals(:,:,f), 0, 1);
    end
    for c = 1:nC
        LOS{i,c} = bl_hcm_los(mean_.avgDelay(i,c));
    end
    fprintf('  %s %-30s done (%d seed%s)\n', s.id, s.name, numel(seeds), plural(numel(seeds)));
end
fclose(fidSeed);

% ---- table -----------------------------------------------------------------
fid = fopen(fullfile(outDir,'baseline_comparison.csv'),'w');
fprintf(fid, 'Scenario,Name,Controller,AvgDelay_s,AvgDelay_std,LOS,NetDelay_s,AvgQueue_veh,MaxQueue_veh,MaxQueueB4_veh,Throughput_veh,Throughput_vph,FinalQueue_veh,MaxResidual\n');
hdr = sprintf('%-4s %-12s %9s %4s %9s %9s %9s %9s %10s %9s', ...
    'Scn','Controller','Delay[s]','LOS','NetDel[s]','AvgQ','MaxQ','MaxQ_B4','Thru[veh]','FinalQ');
fprintf('\n%s\n%s\n', hdr, repmat('-',1,numel(hdr)));
for i = 1:nS
    for c = 1:nC
        fprintf('%-4s %-12s %9.2f %4s %9.2f %9.2f %9.2f %9.2f %10.1f %9.2f\n', ...
            scn(i).id, ctrls{c}, mean_.avgDelay(i,c), LOS{i,c}, mean_.netDelay(i,c), ...
            mean_.avgQueue(i,c), mean_.maxQueue(i,c), mean_.maxQueueB4(i,c), ...
            mean_.throughput(i,c), mean_.finalQueue(i,c));
        fprintf(fid, '%s,%s,%s,%.3f,%.3f,%s,%.3f,%.3f,%.3f,%.3f,%.2f,%.1f,%.3f,%.2e\n', ...
            scn(i).id, scn(i).name, ctrls{c}, mean_.avgDelay(i,c), std_.avgDelay(i,c), ...
            LOS{i,c}, mean_.netDelay(i,c), mean_.avgQueue(i,c), mean_.maxQueue(i,c), ...
            mean_.maxQueueB4(i,c), mean_.throughput(i,c), mean_.throughputRate(i,c), ...
            mean_.finalQueue(i,c), mean_.maxResidual(i,c));
    end
    if i < nS, fprintf('\n'); end
end
fclose(fid);
fprintf('\nDelay = sum(q_B1..B3*dt)/vehicles (LOS basis). NetDel adds the B4 queue.\n');
fprintf('Stochastic scenarios: mean of %d seeds. Capacities are ASSUMED placeholders.\n', numel(p.seeds));

% ---- figures ---------------------------------------------------------------
col = [0.10 0.30 0.70; 0.85 0.40 0.10; 0.20 0.60 0.30; 0.55 0.25 0.65];
vis = 'on'; if ~showFigures, vis = 'off'; end
ids = {scn.id};

% Fig 1: queue vs time, T1-T4
h = figure('Name','Queue vs time','Visible',vis,'Position',[50 50 1100 700]);
for k = 1:4
    subplot(2,2,k); hold on;
    for c = 1:nC, plot(tAxis{k}, traces{k,c}, 'Color', col(c,:), 'LineWidth', 1.2); end
    hold off; grid on;
    title(sprintf('%s %s (total demand %.2f veh/s)', scn(k).id, scn(k).name, scn(k).totalDemand));
    xlabel('Time [s]'); ylabel('Queue B1+B2+B3 [veh]');
    if k == 1, legend(ctrls, 'Location','northwest'); end
end
saveFig(h, fullfile(outDir,'fig1_queue_vs_time.png'));

% Fig 2: delay vs demand
h = figure('Name','Delay vs demand','Visible',vis,'Position',[60 60 800 520]);
x = [scn(1:4).totalDemand];
hold on;
for c = 1:nC
    eh = errorbar(x, mean_.avgDelay(1:4,c), std_.avgDelay(1:4,c));
    set(eh, 'Color', col(c,:), 'LineWidth', 1.4, 'Marker', 'o', ...
        'MarkerFaceColor', col(c,:), 'LineStyle', '-');
end
xl = [min(x)-0.02, max(x)+0.02];
bands = [10 20 35 55 80]; names = 'ABCDE';
for b = 1:numel(bands)
    plot(xl, bands(b)*[1 1], ':', 'Color', [0.5 0.5 0.5]);
    text(xl(1)+0.003, bands(b), sprintf('LOS %s / %s', names(b), char(names(b)+1)), ...
        'VerticalAlignment','bottom', 'FontSize', 8, 'Color', [0.4 0.4 0.4]);
end
hold off; grid on; xlim(xl);
set(gca, 'YScale', 'log');
xlabel('Total entering demand [veh/s]   (B4 capacity = 0.45)');
ylabel('Average delay [s/veh] (log scale)');
title('Average delay vs demand, T1-T4 (mean \pm 1 sd over seeds)');
legend(ctrls, 'Location','northwest');
saveFig(h, fullfile(outDir,'fig2_delay_vs_demand.png'));

% Fig 3: throughput bars
h = figure('Name','Throughput','Visible',vis,'Position',[70 70 900 480]);
bh = bar(mean_.throughputRate, 'grouped');
for c = 1:nC, set(bh(c), 'FaceColor', col(c,:)); end
set(gca, 'XTick', 1:nS, 'XTickLabel', ids); grid on;
ylabel('Throughput to Goldwins [veh/h]');
title('Throughput by scenario');
legend(ctrls, 'Location','northwest');
saveFig(h, fullfile(outDir,'fig3_throughput.png'));

% Fig 4: max queue bars
h = figure('Name','Max queue','Visible',vis,'Position',[80 80 900 480]);
bh = bar(mean_.maxQueue, 'grouped');
for c = 1:nC, set(bh(c), 'FaceColor', col(c,:)); end
set(gca, 'XTick', 1:nS, 'XTickLabel', ids); grid on;
ylabel('Max single-approach queue [veh]');
title('Maximum queue by scenario (B1-B3)');
legend(ctrls, 'Location','northwest');
saveFig(h, fullfile(outDir,'fig4_max_queue.png'));

% Fig 5: step response T5
i5 = find(strcmp(ids,'T5'));
h = figure('Name','Step response','Visible',vis,'Position',[90 90 900 650]);
subplot(3,1,1);
plot(tAxis{i5}, sum(rateAxis{i5},2), 'k', 'LineWidth', 1.4); grid on;
ylabel('Demand [veh/s]'); title('T5 step demand: low 0-300 s, high 300-600 s, moderate 600-900 s');
ylim([0 0.45]);
subplot(3,1,[2 3]); hold on;
for c = 1:nC, plot(tAxis{i5}, traces{i5,c}, 'Color', col(c,:), 'LineWidth', 1.3); end
yl = ylim;
plot([300 300], yl, 'k--'); plot([600 600], yl, 'k--');
hold off; grid on;
xlabel('Time [s]'); ylabel('Queue B1+B2+B3 [veh]');
legend(ctrls, 'Location','northwest');
saveFig(h, fullfile(outDir,'fig5_step_response.png'));

% Fig 6: Part 8 surge scenario
i6 = find(strcmp(ids,'T6')); i7 = find(strcmp(ids,'T7'));
h = figure('Name','Part 8 surge','Visible',vis,'Position',[100 100 1000 450]);
for k = 1:2
    ii = [i6 i7]; ii = ii(k);
    subplot(1,2,k); hold on;
    for c = 1:nC, plot(tAxis{ii}, traces{ii,c}, 'Color', col(c,:), 'LineWidth', 1.3); end
    yl = ylim; plot([200 200], yl, 'k--'); plot([400 400], yl, 'k--');
    hold off; grid on;
    title(sprintf('%s %s', scn(ii).id, scn(ii).name));
    xlabel('Time [s]'); ylabel('Queue B1+B2+B3 [veh]');
    if k == 1, legend(ctrls, 'Location','northwest'); end
end
saveFig(h, fullfile(outDir,'fig6_part8_surge.png'));

% ---- save --------------------------------------------------------------------
RES.scenarios = scn; RES.controllers = ctrls;
RES.mean = mean_; RES.std = std_; RES.LOS = LOS;
RES.traces = traces; RES.tAxis = tAxis; RES.rate = rateAxis;
RES.simulinkSignals = perSeed;  % first-seed runs, ready for From Workspace
RES.config = rmfield(p, 'controllers');
scnSave = rmfield(scn, 'demandFcn'); %#ok<NASGU>  (function handles do not save portably)
RES.scenarios = rmfield(scn, 'demandFcn');
save(fullfile(outDir,'baseline_results.mat'), 'RES');
fprintf('\nSaved table, per-seed CSV, MAT and 6 figures to:\n  %s\n\n', outDir);
end

function saveFig(h, file)
set(h, 'PaperPositionMode', 'auto');
print(h, file, '-dpng', '-r130');
end

function s = plural(n)
if n == 1, s = ''; else, s = 's'; end
end
