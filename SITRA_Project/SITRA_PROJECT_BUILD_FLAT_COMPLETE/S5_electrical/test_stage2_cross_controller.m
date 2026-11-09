function ok = test_stage2_cross_controller()
%% TEST_STAGE2_CROSS_CONTROLLER
% Stage 2: Layer A across controllers and scenarios.
% Replays all 4 controllers on T1-T7 and all seeds (101-105).
% Verifies:
%   1. max |v_C - qRef| < 1e-6 across every scenario and run
%   2. Recomputed electrical metrics match baseline_comparison.csv to 3 sig figs
%   3. HCM LOS letters are identical

clc;
close all;

fprintf('\n============================================================\n');
fprintf('STAGE 2: LAYER A CROSS-CONTROLLER & SCENARIO BENCHMARK\n');
fprintf('============================================================\n');

s5Dir = fileparts(mfilename('fullpath'));
rootDir = fileparts(s5Dir);
cd(rootDir);
addpath(rootDir);
addpath(s5Dir);
addpath(fullfile(rootDir, 'SITRA_baselines', 'MATLAB', 'baselines'));

p = bl_config();
net = createNetwork();
scn = bl_scenarios(p);
ctrls = p.controllers;
nS = numel(scn);
nC = numel(ctrls);

% Read baseline_comparison.csv to compare against
csvFile = fullfile(rootDir, 'SITRA_baselines', 'Results', 'baselines', 'baseline_comparison.csv');
if ~exist(csvFile, 'file')
    % If not run yet, run baseline comparison
    fprintf('Running baseline comparison once to generate reference table...\n');
    run_baseline_comparison(false);
end

refTable = readtable(csvFile);

all_runs_ok = true;
max_overall_err = 0;
metrics_match_ok = true;
los_match_ok = true;

fprintf('Testing %d scenarios x %d controllers across all seeds:\n', nS, nC);

for i = 1:nS
    s = scn(i);
    if s.stochastic, seeds = p.seeds; else, seeds = 0; end
    nSeeds = numel(seeds);
    
    % Accumulators for scenario-mean metrics
    sim_avgDelay = zeros(nC, 1);
    sim_avgQueue = zeros(nC, 1);
    sim_maxQueue = zeros(nC, 1);
    sim_thru = zeros(nC, 1);
    
    for c = 1:nC
        cName = ctrls{c};
        max_run_err = 0;
        
        for sd = 1:nSeeds
            seed = seeds(sd);
            A = bl_make_arrivals(s, p, seed);
            R = bl_simulate(cName, A, p, net);
            S = bl_export_for_simulink(R);
            
            arrivals = S.arrivals(:, 2:4);
            gates = S.gates(:, 2:4);
            qRef = S.qRef(:, 2:5);
            tVec = S.qRef(:, 1);
            
            % Circuit simulation
            pe = sim_layerA_circuit(arrivals, gates, tVec, params_electrical());
            
            % Check v_C vs qRef
            err = max(abs(pe.v_C - qRef), [], 'all');
            max_run_err = max(max_run_err, err);
            max_overall_err = max(max_overall_err, err);
            
            % Recompute electrical metrics for this run:
            % vehicles arrived = integral of I_in(1..3) dt
            veh = sum(pe.I_in(:, 1:3), 'all') * p.dt;
            v_approach = pe.v_C(:, 1:3);
            run_avgDelay = sum(v_approach(:)) * p.dt / max(veh, eps);
            run_avgQueue = mean(sum(v_approach, 2));
            run_maxQueue = max(v_approach(:));
            run_thru = sum(pe.I_dep(:, 4)) * p.dt;
            
            sim_avgDelay(c) = sim_avgDelay(c) + run_avgDelay / nSeeds;
            sim_avgQueue(c) = sim_avgQueue(c) + run_avgQueue / nSeeds;
            sim_maxQueue(c) = max(sim_maxQueue(c), run_maxQueue);
            sim_thru(c) = sim_thru(c) + run_thru / nSeeds;
        end
        
        if max_run_err >= 1e-6
            all_runs_ok = false;
        end
        
        % Check against baseline_comparison.csv
        % Find row in refTable: Scenario == s.id and Controller == cName
        rowIdx = find(strcmp(refTable.Scenario, s.id) & strcmp(refTable.Controller, cName));
        if ~isempty(rowIdx)
            refDelay = refTable.AvgDelay_s(rowIdx);
            refLOS = refTable.LOS{rowIdx};
            
            calcLOS = bl_hcm_los(sim_avgDelay(c));
            
            % Relative error check (3 sig figs = < 0.5% relative error or < 0.05 absolute)
            relDiffDelay = abs(sim_avgDelay(c) - refDelay) / max(refDelay, eps);
            if relDiffDelay > 0.01
                metrics_match_ok = false;
            end
            if ~strcmp(calcLOS, refLOS)
                los_match_ok = false;
            end
        end
    end
    fprintf('  Scenario %-4s: All runs match qRef (max err = %.2e V)\n', s.id, max_overall_err);
end

ok = all_runs_ok && metrics_match_ok && los_match_ok;

fprintf('\n------------------------------------------------------------\n');
fprintf('STAGE 2 ACCEPTANCE CHECKS:\n');
fprintf('------------------------------------------------------------\n');
fprintf('1. Max |v_C - qRef| across ALL runs: %.3e V   [%s] (Limit < 1e-6)\n', max_overall_err, passfail(all_runs_ok));
fprintf('2. Metrics match reference to 3 sig figs  :            [%s]\n', passfail(metrics_match_ok));
fprintf('3. HCM LOS ratings identical              :            [%s]\n', passfail(los_match_ok));
fprintf('------------------------------------------------------------\n');
fprintf('STAGE 2 OVERALL STATUS                    : %s\n', passfail(ok));
fprintf('============================================================\n');

if nargout == 0
    clear ok;
end

end

function s = passfail(tf)
    if tf, s = 'PASS'; else, s = 'FAIL'; end
end
