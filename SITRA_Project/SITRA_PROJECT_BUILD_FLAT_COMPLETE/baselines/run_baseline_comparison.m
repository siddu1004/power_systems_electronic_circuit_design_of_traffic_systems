function RES = run_baseline_comparison(showFigures)
%RUN_BASELINE_COMPARISON  SITRA vs Webster vs actuated vs max-pressure, T1-T8.
%
%   run_baseline_comparison          % figures on screen
%   run_baseline_comparison(false)   % off-screen (batch), PNGs still saved
%
%   For every scenario T1..T8 and every seed in bl_config, ONE arrival
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
%     fig3_throughput.png             throughput bars T1-T8
%     fig4_max_queue.png              max approach queue bars T1-T8
%     fig5_step_response.png          T5 step demand: demand + queue
%     fig6_part8_surge.png            T6/T7 total queue (Part 8 scenario)
%     fig7_clearance_time.png         Clearance time bars T5-T8 with error bars

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

% Clearance metric storage
meanClearTime   = nan(nS,nC);
stdClearTime    = nan(nS,nC);
clearedSeedsStr = cell(nS,nC);
meanExcessVehS  = nan(nS,nC);
meanPeakExcess  = nan(nS,nC);

fidSeed = fopen(fullfile(outDir,'baseline_runs_per_seed.csv'),'w');
fprintf(fidSeed, 'Scenario,Controller,Seed,AvgDelay_s,NetDelay_s,AvgQueue_veh,MaxQueue_veh,MaxQueueB4_veh,Throughput_veh,FinalQueue_veh,LOS,ClearTime_s,ExcessVehS,PeakExcess_veh,Cleared\n');

for i = 1:nS
    s = scn(i);
    % A3: Set p.q0 = s.q0 for scenario if specified (e.g. T8), otherwise zeros
    if isfield(s, 'q0') && ~isempty(s.q0)
        p.q0 = s.q0;
    else
        p.q0 = zeros(1,4);
    end
    if isfield(s, 'events')
        p.events = s.events;
    else
        p.events = [];
    end
    
    if s.stochastic, seeds = p.seeds; else, seeds = 0; end
    nSeeds = numel(seeds);
    vals = zeros(nSeeds, nC, numel(fields));
    clearVals = nan(nSeeds, nC);
    excessVals = nan(nSeeds, nC);
    peakExcessVals = nan(nSeeds, nC);
    clearedFlags = false(nSeeds, nC);

    for j = 1:nSeeds
        A = bl_make_arrivals(s, p, seeds(j));     % SAME arrivals for all controllers
        if isfield(s, 'events') && ~isempty(s.events)
            A = bl_inject('apply_demand', A, s.events);
        end
        
        % Twin run setup if scenario has an event definition
        hasTwin = ~isnan(s.tEvent) && isfield(s, 'twin') && ~isempty(fieldnames(s.twin));
        if hasTwin
            sTwin = s;
            if isfield(s.twin, 'demandFcn') && ~isempty(s.twin.demandFcn)
                sTwin.demandFcn = s.twin.demandFcn;
            end
            pTwin = p;
            if isfield(s.twin, 'q0') && ~isempty(s.twin.q0)
                pTwin.q0 = s.twin.q0;
            else
                pTwin.q0 = zeros(1,4);
            end
            if isfield(s.twin, 'events')
                pTwin.events = s.twin.events;
            else
                pTwin.events = [];
            end
            A_twin = bl_make_arrivals(sTwin, pTwin, seeds(j));
            if isfield(pTwin, 'events') && ~isempty(pTwin.events)
                A_twin = bl_inject('apply_demand', A_twin, pTwin.events);
            end
        end

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
            traces{i,c} = traces{i,c} + sum(R.qHist(:,1:3),2)/nSeeds;

            % Compute clearance metrics against twin run
            Q_total = sum(R.qHist(:,1:3), 2);
            if hasTwin
                R_twin = bl_simulate(ctrls{c}, A_twin, pTwin, net);
                Q_twin = sum(R_twin.qHist(:,1:3), 2);
                C_res = bl_clearance(R.tVec, Q_total, Q_twin, s.tEvent);
            else
                C_res = bl_clearance(R.tVec, Q_total, [], s.tEvent);
            end
            clearVals(j,c) = C_res.tClear;
            excessVals(j,c) = C_res.excessVehS;
            peakExcessVals(j,c) = C_res.peakExcess;
            clearedFlags(j,c) = C_res.cleared;

            fprintf(fidSeed, '%s,%s,%d,%.3f,%.3f,%.3f,%.3f,%.3f,%.2f,%.3f,%s,%.2f,%.2f,%.2f,%d\n', ...
                s.id, ctrls{c}, seeds(j), M.avgDelay, M.netDelay, M.avgQueue, ...
                M.maxQueue, M.maxQueueB4, M.throughput, M.finalQueue, M.LOS, ...
                C_res.tClear, C_res.excessVehS, C_res.peakExcess, double(C_res.cleared));
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
        
        % Aggregate clearance across seeds
        if ~isnan(s.tEvent)
            cMask = clearedFlags(:, c);
            nClr = sum(cMask);
            clearedSeedsStr{i,c} = sprintf('%d/%d', nClr, nSeeds);
            if nClr > 0
                meanClearTime(i,c) = mean(clearVals(cMask, c));
                if nClr > 1
                    stdClearTime(i,c) = std(clearVals(cMask, c));
                else
                    stdClearTime(i,c) = 0;
                end
            else
                meanClearTime(i,c) = NaN;
                stdClearTime(i,c) = NaN;
            end
            meanExcessVehS(i,c) = mean(excessVals(:, c));
            meanPeakExcess(i,c) = mean(peakExcessVals(:, c));
        else
            clearedSeedsStr{i,c} = 'N/A';
            meanClearTime(i,c) = NaN;
            stdClearTime(i,c) = NaN;
            meanExcessVehS(i,c) = NaN;
            meanPeakExcess(i,c) = NaN;
        end
    end
    fprintf('  %s %-30s done (%d seed%s)\n', s.id, s.name, nSeeds, plural(nSeeds));
end
fclose(fidSeed);

% Sanity check: for T6, Webster excessVehS must be larger than SITRA's
idxT6 = find(strcmp({scn.id}, 'T6'), 1);
if ~isempty(idxT6)
    cWeb = find(strcmp(ctrls, 'Webster'), 1);
    cSit = find(strcmp(ctrls, 'SITRA'), 1);
    assert(meanExcessVehS(idxT6, cWeb) > meanExcessVehS(idxT6, cSit), ...
        'Sanity check failed: T6 Webster excessVehS (%.1f) must be > SITRA excessVehS (%.1f)', ...
        meanExcessVehS(idxT6, cWeb), meanExcessVehS(idxT6, cSit));
end

% Reset p.q0
p.q0 = zeros(1,4);

% ---- table -----------------------------------------------------------------
fid = fopen(fullfile(outDir,'baseline_comparison.csv'),'w');
fprintf(fid, 'Scenario,Name,Controller,AvgDelay_s,AvgDelay_std,LOS,NetDelay_s,AvgQueue_veh,MaxQueue_veh,MaxQueueB4_veh,Throughput_veh,Throughput_vph,FinalQueue_veh,MaxResidual,ClearTime_s,ClearTime_std,ClearedSeeds,ExcessVehS,PeakExcess_veh\n');
hdr = sprintf('%-4s %-12s %9s %4s %9s %9s %9s %9s %10s %9s %11s %11s %9s %10s', ...
    'Scn','Controller','Delay[s]','LOS','NetDel[s]','AvgQ','MaxQ','MaxQ_B4','Thru[veh]','FinalQ','ClearTime[s]','ClearSeeds','ExcessVehS','PeakExc[v]');
fprintf('\n%s\n%s\n', hdr, repmat('-',1,numel(hdr)));
for i = 1:nS
    for c = 1:nC
        clearStr = sprintf('%.1f', meanClearTime(i,c));
        if isnan(meanClearTime(i,c)), clearStr = 'NaN'; end
        excessStr = sprintf('%.1f', meanExcessVehS(i,c));
        if isnan(meanExcessVehS(i,c)), excessStr = 'NaN'; end
        peakExcStr = sprintf('%.2f', meanPeakExcess(i,c));
        if isnan(meanPeakExcess(i,c)), peakExcStr = 'NaN'; end
        fprintf('%-4s %-12s %9.2f %4s %9.2f %9.2f %9.2f %9.2f %10.1f %9.2f %11s %11s %9s %10s\n', ...
            scn(i).id, ctrls{c}, mean_.avgDelay(i,c), LOS{i,c}, mean_.netDelay(i,c), ...
            mean_.avgQueue(i,c), mean_.maxQueue(i,c), mean_.maxQueueB4(i,c), ...
            mean_.throughput(i,c), mean_.finalQueue(i,c), clearStr, clearedSeedsStr{i,c}, excessStr, peakExcStr);
        fprintf(fid, '%s,%s,%s,%.3f,%.3f,%s,%.3f,%.3f,%.3f,%.3f,%.2f,%.1f,%.3f,%.2e,%.2f,%.2f,%s,%.2f,%.2f\n', ...
            scn(i).id, scn(i).name, ctrls{c}, mean_.avgDelay(i,c), std_.avgDelay(i,c), ...
            LOS{i,c}, mean_.netDelay(i,c), mean_.avgQueue(i,c), mean_.maxQueue(i,c), ...
            mean_.maxQueueB4(i,c), mean_.throughput(i,c), mean_.throughputRate(i,c), ...
            mean_.finalQueue(i,c), mean_.maxResidual(i,c), ...
            meanClearTime(i,c), stdClearTime(i,c), clearedSeedsStr{i,c}, meanExcessVehS(i,c), meanPeakExcess(i,c));
    end
    if i < nS, fprintf('\n'); end
end
fclose(fid);
fprintf('\nDelay = sum(q_B1..B3*dt)/vehicles (LOS basis). NetDel adds the B4 queue.\n');
fprintf('Stochastic scenarios: mean of %d seeds. Capacities are ASSUMED placeholders.\n', numel(p.seeds));

% ---- clearance ranking table (A4) ------------------------------------------
fprintf('\n============================================================\n');
fprintf('CONGESTION CLEARANCE TIME RANKINGS (Fastest to Slowest)\n');
fprintf('============================================================\n');
for i = 1:nS
    if isnan(scn(i).tEvent), continue; end
    fprintf('\nScenario %s (%s, event at t=%.0f s):\n', scn(i).id, scn(i).name, scn(i).tEvent);
    cTimes = meanClearTime(i,:);
    cExcess = meanExcessVehS(i,:);
    
    % Sort: valid times first ascending, NaNs last
    sortKeys = cTimes;
    sortKeys(isnan(sortKeys)) = 1e9;
    [~, sortIdx] = sortrows([sortKeys(:), cExcess(:)]);
    
    for rank = 1:nC
        c = sortIdx(rank);
        if isnan(cTimes(c))
            timeDisp = 'NOT CLEARED';
        else
            timeDisp = sprintf('%.1f s (+/- %.1f s)', cTimes(c), stdClearTime(i,c));
        end
        fprintf('  Rank %d: %-14s | Clearance: %-20s | Cleared Seeds: %-5s | Excess: %.1f veh*s\n', ...
            rank, ctrls{c}, timeDisp, clearedSeedsStr{i,c}, cExcess(c));
    end
end
fprintf('============================================================\n\n');

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

% Fig 7: Clearance time comparison (A4)
clrIds = {'T5', 'T6', 'T7', 'T8'};
scClr = [];
for k = 1:numel(clrIds)
    idx = find(strcmp(ids, clrIds{k}));
    if ~isempty(idx), scClr(end+1) = idx; end %#ok<AGROW>
end

nScClr = numel(scClr);
Y_bar = zeros(nScClr, nC);
E_bar = zeros(nScClr, nC);
for k = 1:nScClr
    sIdx = scClr(k);
    for c = 1:nC
        Y_bar(k,c) = meanClearTime(sIdx,c);
        if isnan(stdClearTime(sIdx,c))
            E_bar(k,c) = 0;
        else
            E_bar(k,c) = stdClearTime(sIdx,c);
        end
    end
end

h = figure('Name','Clearance time comparison','Visible',vis,'Position',[110 110 950 520]);
Y_plot = Y_bar;
Y_plot(isnan(Y_plot)) = 0;
bh = bar(Y_plot, 'grouped');
for c = 1:nC, set(bh(c), 'FaceColor', col(c,:)); end
hold on;

% Add error bars and label "Not Cleared"
groupWidth = min(0.8, nC/(nC + 1.5));
for c = 1:nC
    x = (1:nScClr) - groupWidth/2 + (2*c - 1) * groupWidth / (2*nC);
    % Error bars for valid numbers
    validMask = ~isnan(Y_bar(:,c)) & (Y_bar(:,c) > 0);
    if any(validMask)
        errorbar(x(validMask), Y_bar(validMask,c), E_bar(validMask,c), ...
            'k', 'linestyle', 'none', 'LineWidth', 1.2, 'CapSize', 8);
    end
    % Not cleared labels
    nanMask = isnan(Y_bar(:,c));
    for k = find(nanMask(:)')
        text(x(k), 10, 'Not Cleared', 'Rotation', 90, ...
            'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
            'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.8 0.1 0.1]);
        plot(x(k), 0, 'rx', 'MarkerSize', 10, 'LineWidth', 2);
    end
end
hold off; grid on;

set(gca, 'XTick', 1:nScClr, 'XTickLabel', clrIds);
xlabel('Scenario'); ylabel('Clearance Time [s] (mean \pm std)');
title('Congestion Clearance Time Comparison Across Controllers (T5 - T8)');
legend(ctrls, 'Location', 'northwest');
ymax = max(Y_bar(~isnan(Y_bar)));
if isempty(ymax) || ymax <= 0, ymax = 200; end
ylim([0, ymax * 1.25 + 20]);
saveFig(h, fullfile(outDir,'fig7_clearance_time.png'));

% ---- fig8: T9-T14 injection clearance comparison ----------------------------
clrIds8 = {'T9','T10','T11','T12','T13','T14'};
scClr8 = [];
for k = 1:numel(clrIds8)
    idx = find(strcmp(ids, clrIds8{k}));
    if ~isempty(idx), scClr8(end+1) = idx; end %#ok<AGROW>
end

if ~isempty(scClr8)
    nScClr8 = numel(scClr8);
    Y_bar8 = zeros(nScClr8, nC);
    E_bar8 = zeros(nScClr8, nC);
    for k = 1:nScClr8
        sIdx = scClr8(k);
        for c = 1:nC
            Y_bar8(k,c) = meanClearTime(sIdx,c);
            if isnan(stdClearTime(sIdx,c))
                E_bar8(k,c) = 0;
            else
                E_bar8(k,c) = stdClearTime(sIdx,c);
            end
        end
    end

    h8 = figure('Name','Injection Clearance Time Comparison','Visible',vis,'Position',[120 120 950 520]);
    Y_plot8 = Y_bar8;
    Y_plot8(isnan(Y_plot8)) = 0;
    bh8 = bar(Y_plot8, 'grouped');
    for c = 1:nC, set(bh8(c), 'FaceColor', col(c,:)); end
    hold on;

    groupWidth = min(0.8, nC/(nC + 1.5));
    for c = 1:nC
        x = (1:nScClr8) - groupWidth/2 + (2*c - 1) * groupWidth / (2*nC);
        validMask = ~isnan(Y_bar8(:,c)) & (Y_bar8(:,c) > 0);
        if any(validMask)
            errorbar(x(validMask), Y_bar8(validMask,c), E_bar8(validMask,c), ...
                'k', 'linestyle', 'none', 'LineWidth', 1.2, 'CapSize', 8);
        end
        nanMask = isnan(Y_bar8(:,c));
        for k = find(nanMask(:)')
            text(x(k), 10, 'Not Cleared', 'Rotation', 90, ...
                'HorizontalAlignment', 'left', 'VerticalAlignment', 'middle', ...
                'FontSize', 8, 'FontWeight', 'bold', 'Color', [0.8 0.1 0.1]);
            plot(x(k), 0, 'rx', 'MarkerSize', 10, 'LineWidth', 2);
        end
    end
    hold off; grid on;

    set(gca, 'XTick', 1:nScClr8, 'XTickLabel', clrIds8);
    xlabel('Scenario'); ylabel('Clearance Time [s] (mean \pm std)');
    title('Congestion Clearance Time Comparison Across Controllers (T9 - T14 Faults & Events)');
    legend(ctrls, 'Location', 'northwest');
    ymax8 = max(Y_bar8(~isnan(Y_bar8)));
    if isempty(ymax8) || ymax8 <= 0, ymax8 = 200; end
    ylim([0, ymax8 * 1.25 + 20]);
    saveFig(h8, fullfile(outDir,'fig8_injection_clearance.png'));
end

% ---- save --------------------------------------------------------------------
RES.scenarios = scn; RES.controllers = ctrls;
RES.mean = mean_; RES.std = std_; RES.LOS = LOS;
RES.traces = traces; RES.tAxis = tAxis; RES.rate = rateAxis;
RES.simulinkSignals = perSeed;  % first-seed runs, ready for From Workspace
RES.clearance = struct('meanClearTime', meanClearTime, 'stdClearTime', stdClearTime, ...
                       'clearedSeeds', {clearedSeedsStr}, 'excessVehS', meanExcessVehS, ...
                       'peakExcess', meanPeakExcess);
RES.config = rmfield(p, 'controllers');
% Clean non-portable function handles before saving
scnSave = scn;
for k = 1:numel(scnSave)
    scnSave(k).demandFcn = [];
    if isfield(scnSave(k), 'twin') && isfield(scnSave(k).twin, 'demandFcn')
        scnSave(k).twin.demandFcn = [];
    end
    if isfield(scnSave(k), 'events'), scnSave(k).events = []; end
    if isfield(scnSave(k), 'twin') && isfield(scnSave(k).twin, 'events')
        scnSave(k).twin.events = [];
    end
end
RES.scenarios = scnSave;
save(fullfile(outDir,'baseline_results.mat'), 'RES');
fprintf('\nSaved table, per-seed CSV, MAT and 8 figures to:\n  %s\n\n', outDir);
end

function saveFig(h, file)
set(h, 'PaperPositionMode', 'auto');
print(h, file, '-dpng', '-r130');
end

function s = plural(n)
if n == 1, s = ''; else, s = 's'; end
end
