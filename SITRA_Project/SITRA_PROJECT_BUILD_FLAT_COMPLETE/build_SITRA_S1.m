%% build_SITRA_S1.m
% S1 - Detailed Simulink Architecture / Model Skeleton
%
% Project:
%   SITRA Traffic Management -> Switching -> Power Electronics
%
% Purpose:
%   Create a clean, runnable Simulink architecture before implementing
%   the traffic plant, MPC, switching logic, electrical stage, sensing,
%   protection, and hardware interface.
%
% IMPORTANT:
%   - Frozen Part 8 MPC is the reference controller.
%   - This file creates architecture only.
%   - No new optimization/controller is introduced here.
%   - No arbitrary electrical component values are introduced here.
%
% Workflow:
%   Implement -> Run -> Inspect -> Validate -> Update BUILD_LOG -> PASS/FAIL
%
% Expected result:
%   A model named:
%       SITRA_Traffic_Hardware
%
% Created subsystems:
%   01_Traffic_Demand
%   02_Traffic_Queue_Plant
%   03_MPC_Controller
%   04_Switching_Logic
%   05_Power_Electronics
%   06_Measurement
%   07_Protection_Interlock
%   08_Hardware_Interface
%   09_Output_Validation
%
% No detailed subsystem dynamics are implemented in S1.

clear;
clc;
close all;

%% 1. USER / PROJECT PARAMETERS
modelName = 'SITRA_Traffic_Hardware';

dt = 1.0;          % simulation step [s]
T  = 600;          % simulation duration [s]

cycleLength = 63;  % signal cycle [s]
yellowTime  = 3;   % clearance/yellow [s]
minGreen    = 12;  % minimum green [s]
maxGreen    = 30;  % maximum green [s]

normalDemand = [0.10 0.07 0.05];   % veh/s
surgeDemand  = [0.30 0.07 0.05];   % veh/s

surgeStart = 200;   % [s]
surgeEnd   = 400;   % [s]

%% 2. CLOSE EXISTING MODEL IF OPEN
if bdIsLoaded(modelName)
    close_system(modelName, 0);
end

%% 3. CREATE NEW MODEL
new_system(modelName);
open_system(modelName);

%% 4. MODEL CONFIGURATION
set_param(modelName, ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', num2str(dt), ...
    'StartTime', '0', ...
    'StopTime', num2str(T), ...
    'SaveOutput', 'off', ...
    'SaveTime', 'off');

%% 5. MODEL-WIDE VARIABLES
mdlWS = get_param(modelName, 'ModelWorkspace');

assignin(mdlWS, 'dt', dt);
assignin(mdlWS, 'T', T);

assignin(mdlWS, 'cycleLength', cycleLength);
assignin(mdlWS, 'yellowTime', yellowTime);
assignin(mdlWS, 'minGreen', minGreen);
assignin(mdlWS, 'maxGreen', maxGreen);

assignin(mdlWS, 'normalDemand', normalDemand);
assignin(mdlWS, 'surgeDemand', surgeDemand);

assignin(mdlWS, 'surgeStart', surgeStart);
assignin(mdlWS, 'surgeEnd', surgeEnd);

%% 6. TOP-LEVEL SUBSYSTEM DEFINITIONS
% Format:
% {name, numberOfInputs, numberOfOutputs, x, y, width, height}

blocks = {
    '01_Traffic_Demand',       0, 1,  40, 180, 140, 80;
    '02_Traffic_Queue_Plant',  2, 2, 240, 250, 170, 100;
    '03_MPC_Controller',       2, 1, 490, 180, 150, 100;
    '04_Switching_Logic',      1, 2, 700, 180, 150, 100;
    '05_Power_Electronics',    2, 1, 910, 250, 170, 100;
    '06_Measurement',          1, 1, 1140, 250, 150, 100;
    '07_Protection_Interlock', 1, 1, 1340, 250, 170, 100;
    '08_Hardware_Interface',   1, 1, 1570, 250, 170, 100;
    '09_Output_Validation',    3, 1, 1140, 450, 180, 110;
};

%% 7. CREATE SUBSYSTEMS
for k = 1:size(blocks, 1)

    blkName = blocks{k,1};
    nIn     = blocks{k,2};
    nOut    = blocks{k,3};

    x = blocks{k,4};
    y = blocks{k,5};
    w = blocks{k,6};
    h = blocks{k,7};

    blkPath = [modelName '/' blkName];

    add_block( ...
        'built-in/Subsystem', ...
        blkPath, ...
        'Position', [x y x+w y+h]);

    open_system(blkPath);

    %% Create input ports
    for p = 1:nIn
        inName = ['In' num2str(p)];

        add_block( ...
            'simulink/Ports & Subsystems/In1', ...
            [blkPath '/' inName], ...
            'Position', [30 50 + 70*(p-1) 60 65 + 70*(p-1)]);

        set_param( ...
            [blkPath '/' inName], ...
            'Port', num2str(p));
    end

    %% Create output ports
    for p = 1:nOut
        outName = ['Out' num2str(p)];

        add_block( ...
            'simulink/Ports & Subsystems/Out1', ...
            [blkPath '/' outName], ...
            'Position', [220 50 + 70*(p-1) 250 65 + 70*(p-1)]);

        set_param( ...
            [blkPath '/' outName], ...
            'Port', num2str(p));
    end

    close_system(blkPath, 0);
end

%% 8. TOP-LEVEL SIGNAL FLOW
%
% Traffic Demand -> Queue Plant
% Traffic Demand -> MPC
% Queue Plant -> MPC
% MPC -> Switching Logic
% Switching Logic -> Queue Plant
% Switching Logic -> Power Electronics
% Power Electronics -> Measurement
% Measurement -> Protection / Interlock
% Protection / Interlock -> Hardware Interface
% Queue Plant -> Output Validation
% MPC -> Output Validation
% Measurement -> Output Validation

add_line(modelName, ...
    '01_Traffic_Demand/1', ...
    '02_Traffic_Queue_Plant/1', ...
    'autorouting', 'on');

add_line(modelName, ...
    '01_Traffic_Demand/1', ...
    '03_MPC_Controller/1', ...
    'autorouting', 'on');

add_line(modelName, ...
    '02_Traffic_Queue_Plant/1', ...
    '03_MPC_Controller/2', ...
    'autorouting', 'on');

add_line(modelName, ...
    '03_MPC_Controller/1', ...
    '04_Switching_Logic/1', ...
    'autorouting', 'on');

add_line(modelName, ...
    '04_Switching_Logic/1', ...
    '02_Traffic_Queue_Plant/2', ...
    'autorouting', 'on');

add_line(modelName, ...
    '04_Switching_Logic/2', ...
    '05_Power_Electronics/1', ...
    'autorouting', 'on');

add_line(modelName, ...
    '05_Power_Electronics/1', ...
    '06_Measurement/1', ...
    'autorouting', 'on');

add_line(modelName, ...
    '06_Measurement/1', ...
    '07_Protection_Interlock/1', ...
    'autorouting', 'on');

add_line(modelName, ...
    '07_Protection_Interlock/1', ...
    '08_Hardware_Interface/1', ...
    'autorouting', 'on');

add_line(modelName, ...
    '02_Traffic_Queue_Plant/2', ...
    '09_Output_Validation/1', ...
    'autorouting', 'on');

add_line(modelName, ...
    '03_MPC_Controller/1', ...
    '09_Output_Validation/2', ...
    'autorouting', 'on');

add_line(modelName, ...
    '06_Measurement/1', ...
    '09_Output_Validation/3', ...
    'autorouting', 'on');

%% 9. ADD DOCUMENTATION ANNOTATIONS
Simulink.Annotation(modelName, ...
    sprintf(['SITRA TRAFFIC + POWER ELECTRONICS IMPLEMENTATION\n' ...
             'S1 ARCHITECTURE SKELETON\n' ...
             'Frozen Part 8 MPC remains the supervisory reference controller.']));

Simulink.Annotation(modelName, ...
    sprintf(['Traffic layer:\n' ...
             'Demand -> Queue Plant -> MPC -> Switching']));

Simulink.Annotation(modelName, ...
    sprintf(['Electrical layer:\n' ...
             'Switching -> Power Electronics -> Measurement -> Protection -> Hardware Interface']));

Simulink.Annotation(modelName, ...
    sprintf(['Signal timing:\n' ...
             'Cycle = %g s | Yellow/Clearance = %g s | Green = %g...%g s'], ...
             cycleLength, yellowTime, minGreen, maxGreen));

%% 10. CREATE MODEL DESCRIPTION
set_param(modelName, ...
    'Description', sprintf([ ...
    'S1 architecture for the SITRA traffic-management and ', ...
    'power-electronics implementation roadmap.\n\n', ...
    'Reference traffic network: HopeCollege, Kalapatti, Airport -> SITRA -> Goldwins.\n', ...
    'Frozen Part 8 MPC is the supervisory reference controller.\n', ...
    'S1 contains architecture only; detailed dynamics are implemented later.\n\n', ...
    'Simulation parameters:\n', ...
    'dt = %.1f s\n', ...
    'T = %.1f s\n', ...
    'Cycle = %.1f s\n', ...
    'Yellow/Clearance = %.1f s\n', ...
    'Minimum green = %.1f s\n', ...
    'Maximum green = %.1f s\n', ...
    'Normal demand = [%.2f %.2f %.2f] veh/s\n', ...
    'Surge demand = [%.2f %.2f %.2f] veh/s\n', ...
    'Surge interval = %.1f to %.1f s'], ...
    dt, T, ...
    cycleLength, yellowTime, minGreen, maxGreen, ...
    normalDemand(1), normalDemand(2), normalDemand(3), ...
    surgeDemand(1), surgeDemand(2), surgeDemand(3), ...
    surgeStart, surgeEnd));

%% 11. SAVE MODEL
save_system(modelName);

%% 12. AUTOMATIC STRUCTURAL CHECKS
fprintf('\n');
fprintf('============================================================\n');
fprintf('SITRA S1 ARCHITECTURE BUILD\n');
fprintf('============================================================\n');

fprintf('\nModel name:\n');
fprintf('  %s.slx\n', modelName);

fprintf('\nSimulation settings:\n');
fprintf('  Solver       = FixedStepDiscrete\n');
fprintf('  Fixed step   = %.1f s\n', dt);
fprintf('  Stop time    = %.1f s\n', T);

fprintf('\nSignal settings:\n');
fprintf('  Cycle length = %.1f s\n', cycleLength);
fprintf('  Yellow       = %.1f s\n', yellowTime);
fprintf('  Min green    = %.1f s\n', minGreen);
fprintf('  Max green    = %.1f s\n', maxGreen);

fprintf('\nDemand settings:\n');
fprintf('  Normal = [%.3f %.3f %.3f] veh/s\n', normalDemand);
fprintf('  Surge  = [%.3f %.3f %.3f] veh/s\n', surgeDemand);
fprintf('  Surge  = %.1f -> %.1f s\n', surgeStart, surgeEnd);

fprintf('\nTop-level subsystems:\n');

for k = 1:size(blocks,1)
    fprintf('  %s\n', blocks{k,1});
end

%% 13. VERIFY REQUIRED BLOCKS
requiredBlocks = {
    '01_Traffic_Demand'
    '02_Traffic_Queue_Plant'
    '03_MPC_Controller'
    '04_Switching_Logic'
    '05_Power_Electronics'
    '06_Measurement'
    '07_Protection_Interlock'
    '08_Hardware_Interface'
    '09_Output_Validation'
};

allBlocksPresent = true;

for k = 1:numel(requiredBlocks)

    blkPath = [modelName '/' requiredBlocks{k}];

    if getSimulinkBlockHandle(blkPath) == -1
        allBlocksPresent = false;
        fprintf('  MISSING: %s\n', requiredBlocks{k});
    else
        fprintf('  FOUND:   %s\n', requiredBlocks{k});
    end
end

%% 14. VERIFY MODEL SETTINGS
solverOK = strcmp(get_param(modelName, 'Solver'), 'FixedStepDiscrete');

stepOK = abs(str2double(get_param(modelName, 'FixedStep')) - dt) < 1e-12;

stopOK = abs(str2double(get_param(modelName, 'StopTime')) - T) < 1e-12;

%% 15. VALIDATION SUMMARY
fprintf('\n');
fprintf('------------------------------------------------------------\n');
fprintf('S1 STRUCTURAL VALIDATION\n');
fprintf('------------------------------------------------------------\n');

fprintf('Required blocks present : %s\n', ternary_text(allBlocksPresent));
fprintf('Solver configuration    : %s\n', ternary_text(solverOK));
fprintf('Fixed step configuration: %s\n', ternary_text(stepOK));
fprintf('Stop time configuration : %s\n', ternary_text(stopOK));

s1Pass = ...
    allBlocksPresent && ...
    solverOK && ...
    stepOK && ...
    stopOK;

fprintf('\n');

if s1Pass
    fprintf('S1 ARCHITECTURE CHECK = PASS\n');
else
    fprintf('S1 ARCHITECTURE CHECK = FAIL\n');
end

fprintf('============================================================\n');
fprintf('\n');

%% 16. OPEN FINAL MODEL
open_system(modelName);

%% LOCAL HELPER FUNCTION
function txt = ternary_text(condition)
    if condition
        txt = 'PASS';
    else
        txt = 'FAIL';
    end
end
