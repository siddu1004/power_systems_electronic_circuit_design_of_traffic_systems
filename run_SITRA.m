%% run_SITRA.m (Workspace Root Launcher)
clear; clc; close all;
projDir = fullfile(fileparts(mfilename('fullpath')), 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE');
cd(projDir);
run('run_all_SITRA.m');
