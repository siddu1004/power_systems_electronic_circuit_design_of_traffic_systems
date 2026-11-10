%% run_all_SITRA.m
% One-command entry point for the current MATLAB behavioral simulation package.
clear;
clc;
close all;

root = fileparts(mfilename('fullpath'));
if isempty(root), root = pwd; end
cd(root);
addpath(root);
if exist(fullfile(root,'MATLAB'), 'dir')
    addpath(fullfile(root,'MATLAB'));
end
if exist(fullfile(root, 'baselines'), 'dir')
    addpath(fullfile(root, 'baselines'));
end
if exist(fullfile(root, 'Results'), 'dir')
    addpath(fullfile(root, 'Results'));
end

fprintf('\n============================================================\n');
fprintf('SITRA PROJECT - MASTER EXECUTION & RESULTS GENERATION\n');
fprintf('============================================================\n');

fprintf('1) Checking project structure...\n');
if exist(fullfile(root, 'validate_SITRA_Project_Structure.m'), 'file')
    run(fullfile(root, 'validate_SITRA_Project_Structure.m'));
elseif exist(fullfile(root, 'MATLAB', 'validate_SITRA_Project_Structure.m'), 'file')
    run(fullfile(root, 'MATLAB', 'validate_SITRA_Project_Structure.m'));
end

% Re-acquire root in case script ran 'clear'
root = fileparts(mfilename('fullpath'));
if isempty(root), root = pwd; end
cd(root);

fprintf('\n2) Running master simulation and generating figures...\n');
if exist(fullfile(root, 'run_SITRA_Master_Simulation.m'), 'file')
    run(fullfile(root, 'run_SITRA_Master_Simulation.m'));
elseif exist(fullfile(root, 'MATLAB', 'run_SITRA_Master_Simulation.m'), 'file')
    run(fullfile(root, 'MATLAB', 'run_SITRA_Master_Simulation.m'));
end

fprintf('\n[SUCCESS] Master simulation finished. All figures generated in Results/figures/\n');
