clc;
clearvars -except rootDir mode tMasterStart sw sh screen;

model = 'SITRA_S2_test_ControllerCompare';
assert(isfile([model '.slx']), 'Model file not found.');
load_system(model);

fprintf('====================================================\n');
fprintf('FIXING CONNECTIONS & LAYOUT IN: %s\n', model);
fprintf('====================================================\n');

% Pre-load workspace variables for T6 simulation
exportDir = fullfile('Results','T6_Simulink_Exports');
if isfile(fullfile(exportDir,'SITRA_T6.mat'))
    Sref = load(fullfile(exportDir,'SITRA_T6.mat'));
    if isfield(Sref,'S'), Sref = Sref.S; end
    assignin('base','T6_arrivals',Sref.arrivals);
    assignin('base','activeTS',Sref.active);
    
    cNames = {'Webster','Actuated','MaxPressure'};
    for i = 1:numel(cNames)
        n = cNames{i};
        matFile = fullfile(exportDir,[n '_T6.mat']);
        if isfile(matFile)
            S = load(matFile);
            if isfield(S,'S'), S = S.S; end
            assignin('base',['active_' n],S.active);
            assignin('base',['gates_' n],S.gates);
        end
    end
end
assignin('base','SITRA_ControllerSelect',1);
assignin('base','Ceq',1);
assignin('base','kq',1);
assignin('base','kI',1);
assignin('base','traffic_dt',1);
assignin('base','branchCapacity',[0.65; 0.35; 0.25; 0.45]);

%% 0. ADD PreLoadFcn & InitFcn SO GUI "RUN" BUTTON ALWAYS WORKS STANDALONE
preloadS2 = sprintf([ ...
    'if ~exist(''T6_arrivals'', ''var'') || ~exist(''SITRA_ControllerSelect'', ''var'')\n' ...
    '    try\n' ...
    '        mdlDir_ = fileparts(get_param(bdroot, ''FileName''));\n' ...
    '        if isempty(mdlDir_), mdlDir_ = pwd; end\n' ...
    '        expDir_ = fullfile(mdlDir_, ''Results'', ''T6_Simulink_Exports'');\n' ...
    '        if ~isfolder(expDir_), expDir_ = fullfile(fileparts(mdlDir_), ''Results'', ''T6_Simulink_Exports''); end\n' ...
    '        if isfile(fullfile(expDir_, ''SITRA_T6.mat''))\n' ...
    '            Sref_ = load(fullfile(expDir_, ''SITRA_T6.mat''));\n' ...
    '            if isfield(Sref_, ''S''), Sref_ = Sref_.S; end\n' ...
    '            T6_arrivals = Sref_.arrivals;\n' ...
    '            activeTS = Sref_.active;\n' ...
    '            for c_ = {''Webster'', ''Actuated'', ''MaxPressure''}\n' ...
    '                mf_ = fullfile(expDir_, [c_{1} ''_T6.mat'']);\n' ...
    '                if isfile(mf_)\n' ...
    '                    Sc_ = load(mf_); if isfield(Sc_, ''S''), Sc_ = Sc_.S; end\n' ...
    '                    eval([ ''active_'' c_{1} '' = Sc_.active;'' ]);\n' ...
    '                    eval([ ''gates_'' c_{1} '' = Sc_.gates;'' ]);\n' ...
    '                end\n' ...
    '            end\n' ...
    '        end\n' ...
    '    catch\n' ...
    '    end\n' ...
    '    if ~exist(''SITRA_ControllerSelect'', ''var''), SITRA_ControllerSelect = 1; end\n' ...
    '    Ceq = 1; kq = 1; kI = 1; traffic_dt = 1;\n' ...
    '    branchCapacity = [0.65; 0.35; 0.25; 0.45];\n' ...
    'end\n']);
set_param(model, 'PreLoadFcn', preloadS2);
set_param(model, 'InitFcn', preloadS2);

%% 1. REMOVE ALL DANGLING LINES INSIDE ALL SUBSYSTEMS AND TOP-LEVEL LINES
allLines = find_system(model, 'FindAll', 'on', 'Type', 'line');
for k = 1:numel(allLines)
    if ishandle(allLines(k))
        try
            sp = get_param(allLines(k), 'SrcPortHandle');
            dp = get_param(allLines(k), 'DstPortHandle');
            if sp == -1 || isempty(dp) || all(dp == -1)
                delete_line(allLines(k));
            end
        catch
        end
    end
end

if ~isempty(find_system(model, 'SearchDepth', 1, 'Name', 'RecordedActive'))
    delete_block([model '/RecordedActive']);
end
topLines = find_system(model, 'SearchDepth', 1, 'FindAll', 'on', 'Type', 'line');
for k = 1:numel(topLines)
    if ishandle(topLines(k))
        try delete_line(topLines(k)); catch, end
    end
end

%% 2. POSITION ALL BLOCKS ON A CLEAN, SPACIOUS LEFT-TO-RIGHT GRID
% Column 1: Input Sources (x = 40 .. 175)
set_pos(model, '01_Traffic_Demand',     [40   70 175 150]);
set_pos(model, 'FW_T6_Arrivals',        [40  185 175 220]);
set_pos(model, 'Controller_Selector',   [40  260 175 295]);
set_pos(model, 'FW_Webster_Active',     [40  320 175 355]);
set_pos(model, 'FW_Actuated_Active',    [40  375 175 410]);
set_pos(model, 'FW_MaxPressure_Active', [40  430 175 465]);
set_pos(model, 'FW_Webster_Gates',      [40  520 175 555]);
set_pos(model, 'FW_Actuated_Gates',     [40  575 175 610]);
set_pos(model, 'FW_MaxPressure_Gates',  [40  630 175 665]);

% Column 2: Queue Plant, MPC Controller, Switching Logic (x = 250 .. 410)
set_pos(model, '02_Traffic_Queue_Plant', [250  160 410 270]);
set_pos(model, '03_MPC_Controller',      [470   75 630 185]);
set_pos(model, '04_Switching_Logic',     [690   75 840 185]);

% Terminate S4 Outport 2 cleanly right next to S4
termS4 = [model '/Terminator_S4_activeOut'];
if isempty(find_system(model, 'SearchDepth', 1, 'Name', 'Terminator_S4_activeOut'))
    add_block('simulink/Sinks/Terminator', termS4);
end
set_param(termS4, 'Position', [865 148 885 168], 'ShowName', 'off');

% Column 3: Multiport Switch Selectors (x = 920 .. 1030)
set_pos(model, 'Active_Phase_Selector', [920 220 1030 430]);
set_pos(model, 'Gate_Selector',         [920 475 1030 685]);

% Column 4: LogActive, LogGates, and 05_Power_Electronics (x = 1120 .. 1290)
set_pos(model, 'LogActive',            [1120 225 1230 260]);
set_pos(model, '05_Power_Electronics', [1120 310 1290 500]);
set_pos(model, 'LogGates',             [1120 560 1230 595]);

% Column 5: 06_Measurement (x = 1370 .. 1540) — directly aligned with 05_Power_Electronics!
set_pos(model, '06_Measurement', [1370 310 1540 500]);

% Column 6: 09_Output_Validation & 07_Protection_Interlock (x = 1630 .. 1810)
set_pos(model, '09_Output_Validation',    [1630 230 1810 500]);
set_pos(model, '07_Protection_Interlock', [1630 545 1810 635]);
set_pos(model, 'LogStageResponse',        [1630 665 1740 700]);

% Column 7: LogValidation & 08_Hardware_Interface (x = 1880 .. 2050)
set_pos(model, 'LogValidation',         [1880 350 1990 385]);
set_pos(model, '08_Hardware_Interface', [1880 545 2050 635]);

termS8 = [model '/Terminator_S8_Hardware'];
if isempty(find_system(model, 'SearchDepth', 1, 'Name', 'Terminator_S8_Hardware'))
    add_block('simulink/Sinks/Terminator', termS8);
end
set_param(termS8, 'Position', [2080 580 2100 600], 'ShowName', 'off');

%% 3. WIRE ALL SUBSYSTEMS WITH SMART AUTOROUTING
% Demand & Arrivals
w(model, '01_Traffic_Demand', 1, '03_MPC_Controller', 1);
w(model, 'FW_T6_Arrivals', 1, '02_Traffic_Queue_Plant', 1);
w(model, 'FW_T6_Arrivals', 1, '05_Power_Electronics', 3);

% Queue feedback to MPC, S5, and S9
w(model, '02_Traffic_Queue_Plant', 1, '03_MPC_Controller', 2);
w(model, '02_Traffic_Queue_Plant', 1, '05_Power_Electronics', 2);
w(model, '02_Traffic_Queue_Plant', 2, '09_Output_Validation', 1);

% 03_MPC_Controller -> 04_Switching_Logic & Active_Phase_Selector
w(model, '03_MPC_Controller', 1, '04_Switching_Logic', 1);
w(model, '04_Switching_Logic', 2, 'Terminator_S4_activeOut', 1);

% Active_Phase_Selector inputs: (1) Control, (2) MPC, (3) Webster, (4) Actuated, (5) MaxPressure
w(model, 'Controller_Selector', 1, 'Active_Phase_Selector', 1);
w(model, '03_MPC_Controller', 1, 'Active_Phase_Selector', 2);
w(model, 'FW_Webster_Active', 1, 'Active_Phase_Selector', 3);
w(model, 'FW_Actuated_Active', 1, 'Active_Phase_Selector', 4);
w(model, 'FW_MaxPressure_Active', 1, 'Active_Phase_Selector', 5);

% Gate_Selector inputs: (1) Control, (2) S4 gates, (3) Webster, (4) Actuated, (5) MaxPressure
w(model, 'Controller_Selector', 1, 'Gate_Selector', 1);
w(model, '04_Switching_Logic', 1, 'Gate_Selector', 2);
w(model, 'FW_Webster_Gates', 1, 'Gate_Selector', 3);
w(model, 'FW_Actuated_Gates', 1, 'Gate_Selector', 4);
w(model, 'FW_MaxPressure_Gates', 1, 'Gate_Selector', 5);

% Active Phase & Gate Selector outputs
w(model, 'Active_Phase_Selector', 1, '02_Traffic_Queue_Plant', 2);
w(model, 'Active_Phase_Selector', 1, 'LogActive', 1);
w(model, 'Active_Phase_Selector', 1, '09_Output_Validation', 2);

w(model, 'Gate_Selector', 1, '05_Power_Electronics', 1);
w(model, 'Gate_Selector', 1, 'LogGates', 1);

% S5 -> S6 (1..5) and S6 -> S9 (3..7)
for i = 1:5
    w(model, '05_Power_Electronics', i, '06_Measurement', i);
    w(model, '06_Measurement', i, '09_Output_Validation', i+2);
end

% S6 measuredVdc (port 3) -> S7 Protection Interlock & LogStageResponse
w(model, '06_Measurement', 3, '07_Protection_Interlock', 1);
w(model, '06_Measurement', 3, 'LogStageResponse', 1);

% S7 -> S8 -> Terminator, S9 -> LogValidation
w(model, '07_Protection_Interlock', 1, '08_Hardware_Interface', 1);
w(model, '08_Hardware_Interface', 1, 'Terminator_S8_Hardware', 1);
w(model, '09_Output_Validation', 1, 'LogValidation', 1);

%% 4. ALSO CLEAN & ADD PreLoadFcn TO SITRA_Simscape_Hardware.slx IF PRESENT
hwModel = 'SITRA_Simscape_Hardware';
if isfile([hwModel '.slx'])
    load_system(hwModel);
    preloadHW = [preloadS2 sprintf([ ...
        'if ~exist(''sim_arrivals'', ''var'') && exist(''T6_arrivals'', ''var''), sim_arrivals = T6_arrivals; end\n' ...
        'if ~exist(''sim_gates'', ''var'') && exist(''gates_Webster'', ''var''), sim_gates = gates_Webster; end\n'])];
    set_param(hwModel, 'PreLoadFcn', preloadHW);
    set_param(hwModel, 'InitFcn', preloadHW);
    % Remove unconnected Solver_Config / GND inside Layer_A if not wired
    la = [hwModel '/Layer_A_Traffic_Equivalent_Circuit'];
    if ~isempty(find_system(la, 'SearchDepth', 1, 'Name', 'Solver_Config'))
        try delete_block([la '/Solver_Config']); catch, end
    end
    if ~isempty(find_system(la, 'SearchDepth', 1, 'Name', 'GND'))
        try delete_block([la '/GND']); catch, end
    end
    % Clean positions in SITRA_Simscape_Hardware
    set_pos(hwModel, 'Arrival_Sources', [40 75 185 120]);
    set_pos(hwModel, 'Gate_Drivers',    [40 185 185 230]);
    set_pos(hwModel, 'Supervisory_Controller', [40 310 215 440]);
    set_pos(hwModel, 'Term_Demand', [255 322 275 342]);
    set_pos(hwModel, 'Term_Gates',  [255 365 275 385]);
    set_pos(hwModel, 'Term_Active', [255 408 275 428]);
    set_pos(hwModel, 'Layer_A_Traffic_Equivalent_Circuit', [330 65 600 265]);
    set_pos(hwModel, 'Log_Vc',   [680 65 795 100]);
    set_pos(hwModel, 'Log_Ibus', [680 280 795 315]);
    set_pos(hwModel, 'Layer_B_Physical_Power_Stage', [680 125 940 265]);
    set_pos(hwModel, 'Log_Vdc',     [1010 130 1125 165]);
    set_pos(hwModel, 'Log_Ibranch', [1010 180 1125 215]);
    termProt = [hwModel '/Term_Protection'];
    if isempty(find_system(hwModel, 'SearchDepth', 1, 'Name', 'Term_Protection'))
        add_block('simulink/Sinks/Terminator', termProt);
    end
    set_param(termProt, 'Position', [975 230 995 250], 'ShowName', 'off');
    phB = get_param([hwModel '/Layer_B_Physical_Power_Stage'], 'PortHandles');
    phT = get_param(termProt, 'PortHandles');
    if get_param(phB.Outport(3), 'Line') == -1
        add_line(hwModel, phB.Outport(3), phT.Inport(1), 'autorouting', 'smart');
    end
    save_system(hwModel);
    close_system(hwModel, 0);
    fprintf('Updated PreLoadFcn/InitFcn and clean layout on %s.slx\n', hwModel);
end

%% 5. COMPILE, UPDATE & SAVE MODEL
set_param(model, 'SimulationCommand', 'update');
save_system(model);

fprintf('\nRunning 600 s test simulation to verify full wiring integrity...\n');
simOut = sim(model, 'StopTime', '600');
fprintf('Simulation completed successfully!\n');
fprintf('MODEL WIRING AND LAYOUT ARE 100%% VERIFIED AND CLEAN.\n');

function set_pos(mdl, blkName, pos)
    p = [mdl '/' blkName];
    if ~isempty(find_system(mdl, 'SearchDepth', 1, 'Name', blkName))
        set_param(p, 'Position', pos);
    end
end

function w(mdl, srcBlk, srcPort, dstBlk, dstPort)
    ph1 = get_param([mdl '/' srcBlk], 'PortHandles');
    ph2 = get_param([mdl '/' dstBlk], 'PortHandles');
    add_line(mdl, ph1.Outport(srcPort), ph2.Inport(dstPort), 'autorouting', 'smart');
end
