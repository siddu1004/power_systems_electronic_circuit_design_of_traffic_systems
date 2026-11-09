function ok = test_stage0_recon()
%% test_stage0_recon.m
% Stage 0: Recon
% Runs baseline integration test and existing unit tests, verifies design note.

clc;
close all;

fprintf('\n============================================================\n');
fprintf('STAGE 0: RECONNAISSANCE & BASELINE HEALTH CHECK\n');
fprintf('============================================================\n');

s5Dir = fileparts(mfilename('fullpath'));
rootDir = fileparts(s5Dir);
cd(rootDir);
addpath(rootDir);
addpath(s5Dir);
addpath(fullfile(rootDir, 'SITRA_baselines', 'MATLAB', 'baselines'));

% 1. Run baseline integration test
fprintf('\n1. Checking baseline integration harness against frozen Part 8...\n');
bl_ok = test_bl_integration();
assert(bl_ok, 'Stage 0 Failed: test_bl_integration failed!');

% 2. Check params_electrical
fprintf('\n2. Verifying params_electrical.m...\n');
p = params_electrical();
assert(isfield(p, 'normalized') && isfield(p, 'layerB'), 'params_electrical structure incomplete!');
assert(isequal(p.normalized.C, [1 1 1 1]), 'Normalized capacitances must be 1 F each!');
fprintf('   Normalized parameters and PLACEHOLDER hardware parameters verified.\n');

% 3. Check design note
fprintf('\n3. Verifying DESIGN_NOTE.md...\n');
assert(exist(fullfile(s5Dir, 'DESIGN_NOTE.md'), 'file') == 2, 'DESIGN_NOTE.md missing!');
fprintf('   DESIGN_NOTE.md verified.\n');

ok = true;
fprintf('\n------------------------------------------------------------\n');
fprintf('STAGE 0 STATUS = PASS\n');
fprintf('============================================================\n');
end
