%% run_SITRA_Integrated_Suite.m
% SITRA INTEGRATED MASTER SIMULATION SUITE
%
% Integrates:
%   1. Project Structure & Dependency Validator
%   2. Frozen Part 8 MPC Reference Simulation & 14 Engineering Figures
%   3. Complete Baseline Controllers Suite (Webster, Actuated, Max-Pressure, MPC)
%      across 7 traffic scenarios (T1 - T7)
%   4. Equivalent Power-Electronic Circuit Simulation & Waveforms (PE1 - PE6)
%   5. Complete 9-Subsystem Simulink Hardware Simulation (SITRA_Traffic_Hardware.slx)
%
% Single unified entry point.

clear;
clc;
close all;

suiteStart = tic;
fprintf('\n======================================================================\n');
fprintf('       SITRA TRAFFIC & POWER-ELECTRONIC INTEGRATED SIMULATION SUITE    \n');
fprintf('======================================================================\n');

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
cd(thisDir);
addpath(thisDir);
addpath(fullfile(thisDir, 'baselines'));

resultsRoot = fullfile(thisDir, 'Results');
if exist(resultsRoot, 'dir') ~= 7, mkdir(resultsRoot); end

%% PHASE 1: Structure Validation
fprintf('\n>>> PHASE 1: Project Structure Validation...\n');
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
run(fullfile(thisDir, 'validate_SITRA_Project_Structure.m'));

%% PHASE 2: Frozen Part 8 Reference Simulation
fprintf('\n>>> PHASE 2: Master Traffic Behavioral Simulation & Part 8 Reference...\n');
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
run(fullfile(thisDir, 'run_SITRA_Master_Simulation.m'));

%% PHASE 3: Baseline Controller Comparison Suite
fprintf('\n>>> PHASE 3: Running Baseline Controller Suite (Webster, Actuated, Max-Pressure, MPC)...\n');
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
cd(fullfile(thisDir, 'baselines'));
blResults = run_baseline_comparison(false);
cd(thisDir);

%% PHASE 4: Equivalent Power Electronic Circuit Simulation
fprintf('\n>>> PHASE 4: Simulating Equivalent Power Electronic Circuit...\n');
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
run(fullfile(thisDir, 'test_power_electronic_circuit.m'));

%% PHASE 5: Simulink Hardware Simulation
fprintf('\n>>> PHASE 5: Running Complete Simulink Hardware Model...\n');
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
run(fullfile(thisDir, 'test_SITRA_Hardware_Simulation.m'));

tic;
suiteTime = toc;

fprintf('\n======================================================================\n');
fprintf('                 INTEGRATION SUITE COMPLETED SUCCESSFULLY             \n');
fprintf('======================================================================\n');
thisDir = fileparts(mfilename('fullpath')); if isempty(thisDir), thisDir = pwd; end
resultsRoot = fullfile(thisDir, 'Results');
fprintf('Outputs generated:\n');
fprintf('  - Master behavioral results: %s/data\n', resultsRoot);
fprintf('  - Master figures (01 - 14) : %s/figures\n', resultsRoot);
fprintf('  - Baseline metrics & plots : %s/baselines\n', resultsRoot);
fprintf('  - Power Electronic figures : %s/power_electronics\n', resultsRoot);
fprintf('  - Simulink hardware model  : %s/SITRA_Traffic_Hardware.slx\n', thisDir);
fprintf('======================================================================\n');
