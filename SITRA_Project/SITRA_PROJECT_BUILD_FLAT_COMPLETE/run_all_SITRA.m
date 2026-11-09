%% run_all_SITRA.m
% One-command entry point for the current MATLAB behavioral simulation package.
clear;
clc;
close all;

root = fileparts(mfilename('fullpath'));
if exist(fullfile(root,'MATLAB'), 'dir')
    matlabFolder = fullfile(root,'MATLAB');
else
    matlabFolder = root;
end
addpath(matlabFolder);
if exist(fullfile(root, 'baselines'), 'dir')
    addpath(fullfile(root, 'baselines'));
end

fprintf('\nSITRA PROJECT - MASTER RUN\n');
fprintf('1) Checking project structure...\n');
run(fullfile(matlabFolder,'validate_SITRA_Project_Structure.m'));

fprintf('\n2) Running master simulation...\n');
run(fullfile(matlabFolder,'run_SITRA_Master_Simulation.m'));
