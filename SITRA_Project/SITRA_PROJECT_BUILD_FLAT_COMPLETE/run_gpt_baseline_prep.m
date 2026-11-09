clc;

% Locate SITRA project
root = pwd;

% Locate baseline directory
baselineDir = fullfile(root,'MATLAB','baselines');

if ~isfolder(baselineDir)
    error('MATLAB/baselines folder not found. Extract SITRA_baselines.zip first.');
end

addpath(root);
addpath(genpath(baselineDir));

% Verify files
assert(isfile(fullfile(root,'createNetwork.m')));
assert(isfile(fullfile(baselineDir,'test_bl_integration.m')));
assert(isfile(fullfile(baselineDir,'run_baseline_comparison.m')));
assert(isfile(fullfile(baselineDir,'bl_export_for_simulink.m')));

fprintf('\nAll baseline files located.\n');

% Run integration verification
fprintf('\n===== FROZEN MODEL INTEGRATION =====\n');

pass = test_bl_integration();

if ~pass
    error('Integration failed. Comparison stopped.');
end

% Run four-controller comparison
fprintf('\n===== FOUR-CONTROLLER COMPARISON =====\n');

RES = run_baseline_comparison(false);

% Save results
resultsDir = fullfile(root,'Results','baselines');

if ~isfolder(resultsDir)
    mkdir(resultsDir);
end

save(fullfile(resultsDir,'SITRA_integrated_results.mat'),'RES');

fprintf('\nBASELINE SIMULATION COMPLETE.\n');

