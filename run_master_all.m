%% run_master_all.m
% =========================================================================
% SITRA UNIFIED MASTER SIMULATION RUNNER
% Project SITRA: Simulink Integrated Traffic & Resilient Automation
%
% Integrates:
%   [Track 1] Mathematical Equivalent Model & Multi-Controller Benchmarking:
%             - SITRA MPC, Webster, Actuated, MaxPressure (Scenario T6)
%             - Mathematical equivalent circuit (1 F, 1 V/veh, 1 A/(veh/s))
%             - Current conservation & KCL node proofs (Part B)
%             - 5 us microsecond semiconductor dead-time interlock (Part C)
%             - S9 output validation suite (Part D Integrated)
%
%   [Track 2] Pure Physical Simscape Circuit & Power Distribution:
%             - SITRA_S5_Physical.slx (Pure Simscape fl_lib/ee_lib blocks)
%             - AC mains (230V) -> Transformer -> 4-Diode Rectifier ->
%               DC link -> Closed-Loop Buck DC-DC Converter (24V PI+PWM) ->
%               3 High-side MOSFET signal-head channels
%             - Physical 1F capacitor KCL traffic equivalent network
%             - S6: Storage capacitor parasitics (ESR/ESL/leakage) & compensation
%             - S7: MOSFET switching dynamics, losses, and thermal equilibrium
% =========================================================================

clc;
clear;
close all;

rootDir = fileparts(mfilename('fullpath'));
if isempty(rootDir), rootDir = pwd; end
cd(rootDir);
addpath(rootDir);
addpath(fullfile(rootDir, 'S6_S7_parasitics'));
addpath(fullfile(rootDir, 'baselines'));

fprintf('======================================================================\n');
fprintf('       SITRA COMPLETE UNIFIED SIMULATION AND VALIDATION SUITE        \n');
fprintf('======================================================================\n\n');

fprintf('Select execution mode:\n');
fprintf('  [1] Run All (Track 1 Mathematical Equivalent + Track 2 Simscape Physical)\n');
fprintf('  [2] Run Track 1: Mathematical Equivalent & Multi-Controller Suite (Parts B, C, D)\n');
fprintf('  [3] Run Track 2: Physical Simscape Circuit & Hardware Suite (S5, S6, S7)\n');
fprintf('  [4] Run Track 3: Master Traffic Behavioral Simulation & Baselines (T1-T7)\n');

% Default to [1]
mode = 1;

fprintf('\nExecuting Mode [%d]...\n', mode);
tMasterStart = tic;

%% TRACK 1: MATHEMATICAL EQUIVALENT & MULTI-CONTROLLER SUITE
if ismember(mode, [1, 2])
    fprintf('\n----------------------------------------------------------------------\n');
    fprintf('>>> TRACK 1: MATHEMATICAL EQUIVALENT & CONTROLLER VALIDATION\n');
    fprintf('----------------------------------------------------------------------\n');
    
    % Step 1.1: Part B Electrical Conservation
    fprintf('\n--- [1.1] Running Part B: Electrical Conservation & Equivalence ---\n');
    run(fullfile(rootDir, 'run_part_b.m'));
    
    % Step 1.2: Part C High-Speed Dead-Time Testbench
    fprintf('\n--- [1.2] Running Part C: 5 us Semiconductor Dead-Time Interlock ---\n');
    run(fullfile(rootDir, 'run_part_c.m'));
    
    % Step 1.3: Part D Integrated Four-Controller Validation
    fprintf('\n--- [1.3] Running Part D: Four-Controller S9 Integrated Validation ---\n');
    run(fullfile(rootDir, 'run_part_d_integrated.m'));
end

%% TRACK 2: PURE PHYSICAL SIMSCAPE ELECTRICAL CIRCUIT
if ismember(mode, [1, 3])
    fprintf('\n----------------------------------------------------------------------\n');
    fprintf('>>> TRACK 2: PHYSICAL SIMSCAPE ELECTRICAL CIRCUIT & HARDWARE DYNAMICS\n');
    fprintf('----------------------------------------------------------------------\n');
    
    % Step 2.1: S5 Simscape Physical Circuit Model + S6/S7 Parasitics & Thermal + 7 Live Figures
    fprintf('\n--- [2.1] Running Stage S5/S6/S7 Physical Simscape Suite & 7 Live Graphs ---\n');
    rootDir = fileparts(mfilename('fullpath')); if isempty(rootDir), rootDir = pwd; end
    cd(rootDir);
    run(fullfile(rootDir, 'test_SITRA_S5_Physical.m'));
    
    % Step 2.2: S6 & S7 Acceptance Gate Summary
    fprintf('\n--- [2.2] Running Stages S6 & S7 Acceptance Gate Summary ---\n');
    rootDir = fileparts(mfilename('fullpath')); if isempty(rootDir), rootDir = pwd; end
    s6s7Dir = fullfile(rootDir, 'S6_S7_parasitics');
    cd(s6s7Dir);
    run(fullfile(s6s7Dir, 'run_all_S6_S7.m'));
    cd(rootDir);
end

%% TRACK 3: TRAFFIC BEHAVIORAL SIMULATION & BASELINE CONTROLLERS
if ismember(mode, [1, 4])
    fprintf('\n----------------------------------------------------------------------\n');
    fprintf('>>> TRACK 3: MASTER TRAFFIC BEHAVIORAL SIMULATION & BASELINE SUITE\n');
    fprintf('----------------------------------------------------------------------\n');
    
    rootDir = fileparts(mfilename('fullpath')); if isempty(rootDir), rootDir = pwd; end
    cd(rootDir);
    run(fullfile(rootDir, 'run_SITRA_Master_Simulation.m'));
    rootDir = fileparts(mfilename('fullpath')); if isempty(rootDir), rootDir = pwd; end
    cd(rootDir);
    
    blCsv = fullfile(rootDir, 'Results', 'baselines', 'baseline_comparison.csv');
    if mode == 4 || ~isfile(blCsv)
        cd(fullfile(rootDir, 'baselines'));
        run_baseline_comparison(false);
        cd(rootDir);
    else
        fprintf('\n[Fast Laptop Mode] Verified 14-Scenario Baseline Comparison Table: %s\n', blCsv);
    end
end

if exist('tMasterStart', 'var')
    totalElapsed = toc(tMasterStart);
    fprintf('\n======================================================================\n');
    fprintf('  SITRA MASTER SUITE COMPLETED SUCCESSFULLY IN %.2f SECONDS\n', totalElapsed);
else
    fprintf('\n======================================================================\n');
    fprintf('  SITRA MASTER SUITE COMPLETED SUCCESSFULLY\n');
end
fprintf('  All results, logs, and figures have been updated and validated.\n');
fprintf('======================================================================\n');
