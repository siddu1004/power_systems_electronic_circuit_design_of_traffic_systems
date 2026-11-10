%% show_all_results.m
% =========================================================================
% ONE-CLICK RUNNER TO SIMULATE AND DISPLAY ALL SITRA RESULTS
% =========================================================================
clc;
clear;
close all;

% Set working folder
root = fileparts(mfilename('fullpath'));
if isempty(root), root = pwd; end
cd(root);
addpath(root);

fprintf('============================================================\n');
fprintf('RUNNING SITRA FOUR-CONTROLLER SIMULATION & DISPLAYING RESULTS\n');
fprintf('============================================================\n');

% 1. Run Part D (Simulates all 4 controllers & creates comparison figures)
run('run_part_d.m');

% 2. Ensure all generated figures are visible and brought to front
figs = findall(0, 'Type', 'figure');
for i = 1:numel(figs)
    set(figs(i), 'Visible', 'on');
    figure(figs(i));
end

fprintf('\n============================================================\n');
fprintf('ALL RESULTS AND FIGURES ARE NOW DISPLAYED ON SCREEN!\n');
fprintf('============================================================\n');
