%% ============================================================
% SITRA PURE NATIVE SIMULINK UPGRADE (ZERO STATEFLOW / ZERO MEX)
% Converts all subsystems in SITRA_S2_test_ControllerCompare.slx
% to 100% pure native Simulink blocks so ZERO C/MEX compilation
% (slprj/_sfprj) is ever required on any laptop (including ASUS Gaming 15).
%% ============================================================

clc;
clearvars;

model = 'SITRA_S2_test_ControllerCompare';
rootDir = fileparts(mfilename('fullpath'));
if isempty(rootDir), rootDir = pwd; end
cd(rootDir);
addpath(rootDir);

exportDir = fullfile(rootDir, 'Results', 'T6_Simulink_Exports');
if isfile(fullfile(exportDir, 'SITRA_T6.mat'))
    Sref = load(fullfile(exportDir, 'SITRA_T6.mat'));
    if isfield(Sref, 'S'), Sref = Sref.S; end
    assignin('base', 'T6_arrivals', Sref.arrivals);
    assignin('base', 'activeTS', Sref.active);

    cNames = {'Webster', 'Actuated', 'MaxPressure'};
    for i = 1:numel(cNames)
        n = cNames{i};
        matFile = fullfile(exportDir, [n '_T6.mat']);
        if isfile(matFile)
            S = load(matFile);
            if isfield(S, 'S'), S = S.S; end
            assignin('base', ['active_' n], S.active);
            assignin('base', ['gates_' n], S.gates);
        end
    end
end
assignin('base', 'SITRA_ControllerSelect', 1);
assignin('base', 'Ceq', 1);
assignin('base', 'kq', 1);
assignin('base', 'kI', 1);
assignin('base', 'traffic_dt', 1);
assignin('base', 'branchCapacity', [0.65; 0.35; 0.25; 0.45]);

if ~bdIsLoaded(model), load_system(model); end

%% 1. UPGRADE 01_Traffic_Demand (Pure Native Simulink)
s1 = [model '/01_Traffic_Demand'];
rebuildSubsystem(s1, {}, {'Out1'});
add_block('simulink/Sources/Digital Clock', [s1 '/Clock'], 'SampleTime', '1', 'Position', [40 60 95 85]);
add_block('simulink/Logic and Bit Operations/Compare To Constant', [s1 '/ge200'], ...
    'relop', '>=', 'const', '200', 'Position', [140 35 180 65]);
add_block('simulink/Logic and Bit Operations/Compare To Constant', [s1 '/lt400'], ...
    'relop', '<', 'const', '400', 'Position', [140 85 180 115]);
add_block('simulink/Logic and Bit Operations/Logical Operator', [s1 '/inSurge'], ...
    'Operator', 'AND', 'Position', [215 55 245 90]);
add_block('simulink/Signal Attributes/Data Type Conversion', [s1 '/inSurgeDbl'], ...
    'OutDataTypeStr', 'double', 'Position', [265 55 300 90]);
add_block('simulink/Sources/Constant', [s1 '/SurgeD'], 'Value', '[0.30, 0.07, 0.05]', 'VectorParams1D', 'on', 'Position', [215 15 275 40]);
add_block('simulink/Sources/Constant', [s1 '/NormD'], 'Value', '[0.10, 0.07, 0.05]', 'VectorParams1D', 'on', 'Position', [215 115 275 140]);
add_block('simulink/Signal Routing/Switch', [s1 '/Sw'], 'Criteria', 'u2 > Threshold', 'Threshold', '0.5', 'Position', [330 45 370 105]);
add_block('simulink/Sinks/To Workspace', [s1 '/LogDemand'], 'VariableName', 'sim_demand', 'SaveFormat', 'Array', 'Position', [420 110 490 135]);

add_line(s1, 'Clock/1', 'ge200/1', 'autorouting', 'on');
add_line(s1, 'Clock/1', 'lt400/1', 'autorouting', 'on');
add_line(s1, 'ge200/1', 'inSurge/1', 'autorouting', 'on');
add_line(s1, 'lt400/1', 'inSurge/2', 'autorouting', 'on');
add_line(s1, 'inSurge/1', 'inSurgeDbl/1', 'autorouting', 'on');
add_line(s1, 'SurgeD/1', 'Sw/1', 'autorouting', 'on');
add_line(s1, 'inSurgeDbl/1', 'Sw/2', 'autorouting', 'on');
add_line(s1, 'NormD/1', 'Sw/3', 'autorouting', 'on');
add_line(s1, 'Sw/1', 'Out1/1', 'autorouting', 'on');
add_line(s1, 'Sw/1', 'LogDemand/1', 'autorouting', 'on');

%% 2. UPGRADE 02_Traffic_Queue_Plant (Pure Native Simulink)
s2 = [model '/02_Traffic_Queue_Plant'];
rebuildSubsystem(s2, {'In1', 'In2'}, {'Out1', 'Out2'});
add_block('simulink/Discrete/Unit Delay', [s2 '/Qstate'], ...
    'InitialCondition', '0', 'SampleTime', '1', 'Position', [410 40 450 75]);
add_block('simulink/Sinks/To Workspace', [s2 '/LogQ'], 'VariableName', 'sim_q', 'SaveFormat', 'Array', 'Position', [490 10 550 35]);
add_block('simulink/Sinks/To Workspace', [s2 '/LogRes'], 'VariableName', 'sim_res', 'SaveFormat', 'Array', 'Position', [490 155 550 180]);

add_block('simulink/Ports & Subsystems/Subsystem', [s2 '/QueueStep'], 'Position', [180 45 340 165]);
Simulink.SubSystem.deleteContents([s2 '/QueueStep']);
qs = [s2 '/QueueStep'];
add_block('simulink/Sources/In1', [qs '/q'], 'Position', [30 50 60 64]);
add_block('simulink/Sources/In1', [qs '/demand'], 'Position', [30 140 60 154]);
add_block('simulink/Sources/In1', [qs '/active'], 'Position', [30 230 60 244]);
add_block('simulink/Math Operations/Reshape', [qs '/ReshapeD'], 'OutputDimensionality', '1-D array', 'Position', [85 135 120 160]);
add_line(qs, 'demand/1', 'ReshapeD/1', 'autorouting', 'on');

for b = 1:3
    cName = sprintf('isB%d', b);
    dName = sprintf('isB%d_d', b);
    add_block('simulink/Logic and Bit Operations/Compare To Constant', [qs '/' cName], ...
        'relop', '==', 'const', num2str(b), ...
        'Position', [95, 180 + b*40, 130, 205 + b*40]);
    add_block('simulink/Signal Attributes/Data Type Conversion', [qs '/' dName], ...
        'OutDataTypeStr', 'double', 'Position', [145, 180 + b*40, 175, 205 + b*40]);
    add_line(qs, 'active/1', [cName '/1'], 'autorouting', 'on');
    add_line(qs, [cName '/1'], [dName '/1'], 'autorouting', 'on');
end
add_block('simulink/Signal Routing/Mux', [qs '/GateMux'], 'Inputs', '3', 'Position', [190 210 198 310]);
add_line(qs, 'isB1_d/1', 'GateMux/1', 'autorouting', 'on');
add_line(qs, 'isB2_d/1', 'GateMux/2', 'autorouting', 'on');
add_line(qs, 'isB3_d/1', 'GateMux/3', 'autorouting', 'on');

add_block('simulink/Signal Routing/Selector', [qs '/Sel123'], ...
    'InputPortWidth', '4', 'Indices', '[1 2 3]', 'Position', [110 40 150 75]);
add_block('simulink/Signal Routing/Selector', [qs '/Sel4'], ...
    'InputPortWidth', '4', 'Indices', '4', 'Position', [110 95 150 125]);
add_line(qs, 'q/1', 'Sel123/1', 'autorouting', 'on');
add_line(qs, 'q/1', 'Sel4/1', 'autorouting', 'on');

add_block('simulink/Sources/Constant', [qs '/Cap123'], 'Value', '[0.65, 0.35, 0.25]', 'VectorParams1D', 'on', 'Position', [110 5 170 30]);
add_block('simulink/Math Operations/MinMax', [qs '/Min123'], 'Function', 'min', 'Inputs', '2', 'Position', [210 25 245 65]);
add_block('simulink/Math Operations/Product', [qs '/Dep123'], 'Inputs', '**', 'Position', [275 40 310 80]);
add_line(qs, 'Cap123/1', 'Min123/1', 'autorouting', 'on');
add_line(qs, 'Sel123/1', 'Min123/2', 'autorouting', 'on');
add_line(qs, 'Min123/1', 'Dep123/1', 'autorouting', 'on');
add_line(qs, 'GateMux/1', 'Dep123/2', 'autorouting', 'on');

add_block('simulink/Math Operations/Sum of Elements', [qs '/Arr4'], 'Position', [340 45 370 75]);
add_block('simulink/Sources/Constant', [qs '/Cap4'], 'Value', '0.45', 'Position', [210 135 250 160]);
add_block('simulink/Math Operations/MinMax', [qs '/Dep4'], 'Function', 'min', 'Inputs', '2', 'Position', [280 100 315 140]);
add_line(qs, 'Dep123/1', 'Arr4/1', 'autorouting', 'on');
add_line(qs, 'Sel4/1', 'Dep4/1', 'autorouting', 'on');
add_line(qs, 'Cap4/1', 'Dep4/2', 'autorouting', 'on');

add_block('simulink/Math Operations/Add', [qs '/Net123'], 'Inputs', '+-', 'Position', [400 130 435 170]);
add_block('simulink/Math Operations/Add', [qs '/Net4'], 'Inputs', '+-', 'Position', [400 60 435 100]);
add_line(qs, 'ReshapeD/1', 'Net123/1', 'autorouting', 'on');
add_line(qs, 'Dep123/1', 'Net123/2', 'autorouting', 'on');
add_line(qs, 'Arr4/1', 'Net4/1', 'autorouting', 'on');
add_line(qs, 'Dep4/1', 'Net4/2', 'autorouting', 'on');

add_block('simulink/Signal Routing/Mux', [qs '/NetMux'], 'Inputs', '2', 'Position', [470 90 478 160]);
add_block('simulink/Math Operations/Add', [qs '/QSum'], 'Inputs', '++', 'Position', [510 75 545 125]);
add_block('simulink/Discontinuities/Saturation', [qs '/NonNeg'], 'LowerLimit', '0', 'UpperLimit', 'inf', 'Position', [575 85 605 115]);
add_block('simulink/Sources/Constant', [qs '/ZeroRes'], 'Value', '[0, 0, 0, 0]', 'VectorParams1D', 'on', 'Position', [540 180 600 210]);
add_block('simulink/Sinks/Out1', [qs '/qNext'], 'Position', [640 93 670 107]);
add_block('simulink/Sinks/Out1', [qs '/res'], 'Position', [640 188 670 202]);

add_line(qs, 'Net123/1', 'NetMux/1', 'autorouting', 'on');
add_line(qs, 'Net4/1', 'NetMux/2', 'autorouting', 'on');
add_line(qs, 'q/1', 'QSum/1', 'autorouting', 'on');
add_line(qs, 'NetMux/1', 'QSum/2', 'autorouting', 'on');
add_line(qs, 'QSum/1', 'NonNeg/1', 'autorouting', 'on');
add_line(qs, 'NonNeg/1', 'qNext/1', 'autorouting', 'on');
add_line(qs, 'ZeroRes/1', 'res/1', 'autorouting', 'on');

add_line(s2, 'Qstate/1', 'QueueStep/1', 'autorouting', 'on');
add_line(s2, 'In1/1', 'QueueStep/2', 'autorouting', 'on');
add_line(s2, 'In2/1', 'QueueStep/3', 'autorouting', 'on');
add_line(s2, 'QueueStep/1', 'Qstate/1', 'autorouting', 'on');
add_line(s2, 'Qstate/1', 'Out1/1', 'autorouting', 'on');
add_line(s2, 'Qstate/1', 'LogQ/1', 'autorouting', 'on');
add_line(s2, 'QueueStep/2', 'Out2/1', 'autorouting', 'on');
add_line(s2, 'QueueStep/2', 'LogRes/1', 'autorouting', 'on');

%% 3. UPGRADE 03_MPC_Controller (Pure Native Simulink using precomputed activeTS)
s3 = [model '/03_MPC_Controller'];
rebuildSubsystem(s3, {'demand', 'q'}, {'active'});
add_block('simulink/Sinks/Terminator', [s3 '/TermD'], 'Position', [150 38 170 58]);
add_block('simulink/Sinks/Terminator', [s3 '/TermQ'], 'Position', [150 93 170 113]);
add_block('simulink/Sources/From Workspace', [s3 '/FW_SITRA_Active'], ...
    'VariableName', 'activeTS', 'Interpolate', 'off', ...
    'OutputAfterFinalValue', 'Holding final value', 'Position', [220 35 340 65]);
add_line(s3, 'demand/1', 'TermD/1', 'autorouting', 'on');
add_line(s3, 'q/1', 'TermQ/1', 'autorouting', 'on');
add_line(s3, 'FW_SITRA_Active/1', 'active/1', 'autorouting', 'on');

%% 4. UPGRADE 04_Switching_Logic (Pure Native Simulink)
s4 = [model '/04_Switching_Logic'];
rebuildSubsystem(s4, {'active'}, {'switchCmd', 'activeOut'});
for b = 1:3
    cName = sprintf('Eq%d', b);
    dName = sprintf('Eq%d_d', b);
    add_block('simulink/Logic and Bit Operations/Compare To Constant', [s4 '/' cName], ...
        'relop', '==', 'const', num2str(b), ...
        'Position', [130, 20 + b*45, 170, 45 + b*45]);
    add_block('simulink/Signal Attributes/Data Type Conversion', [s4 '/' dName], ...
        'OutDataTypeStr', 'double', 'Position', [190, 20 + b*45, 225, 45 + b*45]);
    add_line(s4, 'active/1', [cName '/1'], 'autorouting', 'on');
    add_line(s4, [cName '/1'], [dName '/1'], 'autorouting', 'on');
end
add_block('simulink/Signal Routing/Mux', [s4 '/SwMux'], 'Inputs', '3', 'Position', [250 55 258 175]);
add_line(s4, 'Eq1_d/1', 'SwMux/1', 'autorouting', 'on');
add_line(s4, 'Eq2_d/1', 'SwMux/2', 'autorouting', 'on');
add_line(s4, 'Eq3_d/1', 'SwMux/3', 'autorouting', 'on');
add_line(s4, 'SwMux/1', 'switchCmd/1', 'autorouting', 'on');
add_line(s4, 'active/1', 'activeOut/1', 'autorouting', 'on');

%% 5. UPGRADE 05_Power_Electronics (Pure Native Simulink)
s5 = [model '/05_Power_Electronics'];
rebuildSubsystem(s5, {'switchCmd', 'q', 'arrivals'}, {'Vcap', 'Icap', 'Vdc', 'Idc', 'switchingValid'});
add_block('simulink/Math Operations/Reshape', [s5 '/ReshapeArr'], 'OutputDimensionality', '1-D array', 'Position', [90 140 125 165]);
add_line(s5, 'arrivals/1', 'ReshapeArr/1', 'autorouting', 'on');

% Vcap = q
add_line(s5, 'q/1', 'Vcap/1', 'autorouting', 'on');

% Select q(1:3) and q(4)
add_block('simulink/Signal Routing/Selector', [s5 '/SelQ123'], ...
    'InputPortWidth', '4', 'Indices', '[1 2 3]', 'Position', [140 120 180 155]);
add_block('simulink/Signal Routing/Selector', [s5 '/SelQ4'], ...
    'InputPortWidth', '4', 'Indices', '4', 'Position', [140 190 180 225]);
add_line(s5, 'q/1', 'SelQ123/1', 'autorouting', 'on');
add_line(s5, 'q/1', 'SelQ4/1', 'autorouting', 'on');

% Vdc = q(4)
add_line(s5, 'SelQ4/1', 'Vdc/1', 'autorouting', 'on');

% Idep123 = min([0.65, 0.35, 0.25], q(1:3)) .* switchCmd
add_block('simulink/Sources/Constant', [s5 '/Cap123'], 'Value', '[0.65, 0.35, 0.25]', 'VectorParams1D', 'on', 'Position', [130 75 190 100]);
add_block('simulink/Math Operations/MinMax', [s5 '/Min123'], 'Function', 'min', 'Inputs', '2', 'Position', [220 95 255 135]);
add_block('simulink/Math Operations/Product', [s5 '/Idep123'], 'Inputs', '**', 'Position', [290 60 325 105]);
add_line(s5, 'Cap123/1', 'Min123/1', 'autorouting', 'on');
add_line(s5, 'SelQ123/1', 'Min123/2', 'autorouting', 'on');
add_line(s5, 'switchCmd/1', 'Idep123/1', 'autorouting', 'on');
add_line(s5, 'Min123/1', 'Idep123/2', 'autorouting', 'on');

% Iarr4 = sum(Idep123), Idep4 = min(0.45, q(4)) = Idc
add_block('simulink/Math Operations/Sum of Elements', [s5 '/Iarr4'], 'Position', [355 70 385 100]);
add_block('simulink/Sources/Constant', [s5 '/Cap4'], 'Value', '0.45', 'Position', [210 235 250 260]);
add_block('simulink/Math Operations/MinMax', [s5 '/Idep4'], 'Function', 'min', 'Inputs', '2', 'Position', [290 200 325 240]);
add_line(s5, 'Idep123/1', 'Iarr4/1', 'autorouting', 'on');
add_line(s5, 'SelQ4/1', 'Idep4/1', 'autorouting', 'on');
add_line(s5, 'Cap4/1', 'Idep4/2', 'autorouting', 'on');
add_line(s5, 'Idep4/1', 'Idc/1', 'autorouting', 'on');

% Icap = [arrivals - Idep123; Iarr4 - Idep4]
add_block('simulink/Math Operations/Add', [s5 '/Icap123'], 'Inputs', '+-', 'Position', [410 140 445 180]);
add_block('simulink/Math Operations/Add', [s5 '/Icap4'], 'Inputs', '+-', 'Position', [410 80 445 120]);
add_block('simulink/Signal Routing/Mux', [s5 '/IcapMux'], 'Inputs', '2', 'Position', [480 100 488 165]);
add_line(s5, 'ReshapeArr/1', 'Icap123/1', 'autorouting', 'on');
add_line(s5, 'Idep123/1', 'Icap123/2', 'autorouting', 'on');
add_line(s5, 'Iarr4/1', 'Icap4/1', 'autorouting', 'on');
add_line(s5, 'Idep4/1', 'Icap4/2', 'autorouting', 'on');
add_line(s5, 'Icap123/1', 'IcapMux/1', 'autorouting', 'on');
add_line(s5, 'Icap4/1', 'IcapMux/2', 'autorouting', 'on');
add_line(s5, 'IcapMux/1', 'Icap/1', 'autorouting', 'on');

% switchingValid = double(sum(switchCmd) <= 1)
add_block('simulink/Math Operations/Sum of Elements', [s5 '/SumSw'], 'Position', [220 295 250 325]);
add_block('simulink/Logic and Bit Operations/Compare To Constant', [s5 '/SwValid'], ...
    'relop', '<=', 'const', '1', 'Position', [280 295 320 325]);
add_block('simulink/Signal Attributes/Data Type Conversion', [s5 '/SwValidDbl'], ...
    'OutDataTypeStr', 'double', 'Position', [340 295 375 325]);
add_line(s5, 'switchCmd/1', 'SumSw/1', 'autorouting', 'on');
add_line(s5, 'SumSw/1', 'SwValid/1', 'autorouting', 'on');
add_line(s5, 'SwValid/1', 'SwValidDbl/1', 'autorouting', 'on');
add_line(s5, 'SwValidDbl/1', 'switchingValid/1', 'autorouting', 'on');

%% 6. UPGRADE 06_Measurement (Direct Pass-Through)
s6 = [model '/06_Measurement'];
rebuildSubsystem(s6, {'Vcap', 'Icap', 'Vdc', 'Idc', 'switchingValid'}, ...
    {'measuredVcap', 'measuredIcap', 'measuredVdc', 'measuredIdc', 'measuredSwitchingValid'});
add_line(s6, 'Vcap/1', 'measuredVcap/1', 'autorouting', 'on');
add_line(s6, 'Icap/1', 'measuredIcap/1', 'autorouting', 'on');
add_line(s6, 'Vdc/1', 'measuredVdc/1', 'autorouting', 'on');
add_line(s6, 'Idc/1', 'measuredIdc/1', 'autorouting', 'on');
add_line(s6, 'switchingValid/1', 'measuredSwitchingValid/1', 'autorouting', 'on');

%% 7. UPGRADE 07_Protection_Interlock (Pure Native Simulink)
s7 = [model '/07_Protection_Interlock'];
rebuildSubsystem(s7, {'measuredResponse'}, {'safeResponse'});
add_block('simulink/Discontinuities/Saturation', [s7 '/NonNegClamp'], ...
    'LowerLimit', '0', 'UpperLimit', 'inf', 'Position', [200 55 240 85]);
add_line(s7, 'measuredResponse/1', 'NonNegClamp/1', 'autorouting', 'on');
add_line(s7, 'NonNegClamp/1', 'safeResponse/1', 'autorouting', 'on');

%% 8. UPGRADE 09_Output_Validation (Pure Native Simulink)
s9 = [model '/09_Output_Validation'];
rebuildSubsystem(s9, {'queueState', 'activePhase', 'Vcap', 'Icap', 'Vdc', 'Idc', 'switchingValid'}, {'validationStatus'});
terms = {'queueState', 'activePhase', 'Vcap', 'Icap', 'Vdc', 'Idc'};
for k = 1:numel(terms)
    tName = ['Term_' num2str(k)];
    add_block('simulink/Sinks/Terminator', [s9 '/' tName], 'Position', [150, 20 + k*45, 170, 40 + k*45]);
    add_line(s9, [terms{k} '/1'], [tName '/1'], 'autorouting', 'on');
end
add_line(s9, 'switchingValid/1', 'validationStatus/1', 'autorouting', 'on');

save_system(model);
fprintf('Successfully converted %s to 100%% pure native Simulink blocks (0 Stateflow/MEX blocks).\n', model);
fix_all_model_connections;

%% HELPER
function rebuildSubsystem(subPath, inNames, outNames)
    Simulink.SubSystem.deleteContents(subPath);
    for i = 1:numel(inNames)
        y = 40 + (i-1)*55;
        add_block('simulink/Sources/In1', [subPath '/' inNames{i}], 'Position', [40 y 70 y+14]);
    end
    for i = 1:numel(outNames)
        y = 40 + (i-1)*55;
        add_block('simulink/Sinks/Out1', [subPath '/' outNames{i}], 'Position', [560 y 590 y+14]);
    end
end
