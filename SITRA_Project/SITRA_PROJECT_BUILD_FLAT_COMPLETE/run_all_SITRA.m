%% run_all_SITRA.m
% Unified entry point for the SITRA Project.
% Runs the complete integrated simulation suite.

clear;
clc;
close all;

root = fileparts(mfilename('fullpath'));
if isempty(root), root = pwd; end
cd(root);

run(fullfile(root, 'run_SITRA_Integrated_Suite.m'));
