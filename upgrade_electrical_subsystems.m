%% ============================================================
% SITRA ELECTRICAL EQUIVALENT MODEL UPGRADE
% S5: Power Electronics
% S6: Measurement
% S9: Output Validation
%
% Upgrades SITRA_S2_test_ControllerCompare.slx
%% ============================================================

clc;
clearvars;

model = 'SITRA_S2_test_ControllerCompare';
modelPath = which([model '.slx']);
if isempty(modelPath)
    cand = fullfile(pwd, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE', [model '.slx']);
    if isfile(cand)
        addpath(fileparts(cand));
        modelPath = cand;
    end
end

assert(~isempty(modelPath) && isfile(modelPath), ...
    'Comparison model file not found.');

exportDir = fullfile('Results', 'T6_Simulink_Exports');
if isfile(fullfile(exportDir, 'SITRA_T6.mat'))
    Sref = load(fullfile(exportDir, 'SITRA_T6.mat'));
    assignin('base', 'T6_arrivals', Sref.arrivals);
    assignin('base', 'activeTS', Sref.active);
    
    cNames = {'Webster', 'Actuated', 'MaxPressure'};
    for i = 1:numel(cNames)
        n = cNames{i};
        matFile = fullfile(exportDir, [n '_T6.mat']);
        if isfile(matFile)
            S = load(matFile);
            assignin('base', ['active_' n], S.active);
            assignin('base', ['gates_' n], S.gates);
        end
    end
    fprintf('Loaded and assigned T6 signals into base workspace\n');
end

if ~exist('SITRA_ControllerSelect', 'var')
    SITRA_ControllerSelect = 1;
end
assignin('base', 'SITRA_ControllerSelect', SITRA_ControllerSelect);

load_system(model);

%% 1. BACKUP
modelDir = fileparts(modelPath);
backupModel = fullfile(modelDir, [model '_BeforeElectricalUpgrade']);

if ~isfile([backupModel '.slx'])
    copyfile(modelPath, [backupModel '.slx']);
end
fprintf('\nBackup created: %s.slx\n', backupModel);

if ~bdIsLoaded(model)
    load_system(model);
end

%% 2. PARAMETERS
assignin('base','Ceq',1);
assignin('base','kq',1);
assignin('base','kI',1);
assignin('base','traffic_dt',1);

cap = [0.65; 0.35; 0.25; 0.45];
assignin('base','branchCapacity',cap);

%% 3. HELPER FUNCTION LOGIC
% We will rebuild S5, S6, S9

%% 4. REBUILD S5
S5 = [model '/05_Power_Electronics'];
rebuildSubsystem(S5, ...
    {'switchCmd','q','arrivals'}, ...
    {'Vcap','Icap','Vdc','Idc','switchingValid'});

add_block('simulink/User-Defined Functions/MATLAB Function', ...
    [S5 '/Electrical_Equivalent_Model'], ...
    'Position',[220 130 360 300]);

s5Code = [
"function [Vcap,Icap,Vdc,Idc,switchingValid] = fcn(switchCmd,q,arrivals)"
""
"% Scaled traffic-electrical equivalent model"
"% 1 veh = 1 V; 1 veh/s = 1 A; Ceq = 1 F"
""
"switchCmd = switchCmd(:);"
"q = q(:);"
"arrivals = arrivals(:);"
""
"cap = [0.65;0.35;0.25;0.45];"
"dt = 1;"
""
"Vcap = zeros(4,1);"
"Icap = zeros(4,1);"
"Vdc = 0;"
"Idc = 0;"
"switchingValid = 0;"
""
"if numel(switchCmd) ~= 3 || numel(q) ~= 4 || numel(arrivals) ~= 3"
"    return;"
"end"
""
"binaryValid = all((switchCmd == 0) | (switchCmd == 1));"
"exclusiveValid = sum(switchCmd) <= 1;"
"queueValid = all(isfinite(q)) && all(q >= 0);"
"arrivalValid = all(isfinite(arrivals)) && all(arrivals >= 0);"
""
"if ~(binaryValid && exclusiveValid && queueValid && arrivalValid)"
"    return;"
"end"
""
"% Upstream arrival currents"
"Iarr = [arrivals;0];"
""
"% Controlled branch departure currents"
"Idep = zeros(4,1);"
""
"for i = 1:3"
"    if switchCmd(i) == 1"
"        Idep(i) = min(cap(i),q(i)/dt);"
"    end"
"end"
""
"% Downstream B4 receives upstream departures"
"Iarr(4) = sum(Idep(1:3));"
""
"% B4 bottleneck departure current"
"Idep(4) = min(cap(4),q(4)/dt);"
""
"% Equivalent capacitor voltages"
"Vcap = q;"
""
"% Net capacitor currents: C*dV/dt = Iarr - Idep"
"Icap = Iarr - Idep;"
""
"% Shared downstream DC-link equivalent"
"Vdc = Vcap(4);"
"Idc = Idep(4);"
""
"switchingValid = 1;"
"end"
];

writeMATLABFunction([S5 '/Electrical_Equivalent_Model'], s5Code);

% Connect S5 internal ports
connectBlocks(S5,'switchCmd','Electrical_Equivalent_Model',1);
connectBlocks(S5,'q','Electrical_Equivalent_Model',2);
connectBlocks(S5,'arrivals','Electrical_Equivalent_Model',3);

connectOutput(S5,'Electrical_Equivalent_Model',1,'Vcap');
connectOutput(S5,'Electrical_Equivalent_Model',2,'Icap');
connectOutput(S5,'Electrical_Equivalent_Model',3,'Vdc');
connectOutput(S5,'Electrical_Equivalent_Model',4,'Idc');
connectOutput(S5,'Electrical_Equivalent_Model',5,'switchingValid');

%% 5. REBUILD S6
S6 = [model '/06_Measurement'];
rebuildSubsystem(S6, ...
    {'Vcap','Icap','Vdc','Idc','switchingValid'}, ...
    {'measuredVcap','measuredIcap','measuredVdc', ...
     'measuredIdc','measuredSwitchingValid'});

for i = 1:5
    inNames = {'Vcap','Icap','Vdc','Idc','switchingValid'};
    outNames = {'measuredVcap','measuredIcap','measuredVdc', ...
               'measuredIdc','measuredSwitchingValid'};
    connectBlocks(S6, inNames{i}, outNames{i}, 1);
end

%% 6. REBUILD S9
S9 = [model '/09_Output_Validation'];
rebuildSubsystem(S9, ...
    {'queueState','activePhase','Vcap','Icap', ...
     'Vdc','Idc','switchingValid'}, ...
    {'validationStatus'});

add_block('simulink/User-Defined Functions/MATLAB Function', ...
    [S9 '/Electrical_Validation_Logic'], ...
    'Position',[230 150 390 330]);

s9Code = [
"function status = fcn(q,active,Vcap,Icap,Vdc,Idc,switchingValid)"
""
"q = q(:);"
"Vcap = Vcap(:);"
"Icap = Icap(:);"
""
"queueOK = numel(q)==4 && all(isfinite(q)) && all(q>=0);"
""
"phaseOK = isfinite(active) && active>=0 && ..."
"          active<=3 && active==round(active);"
""
"voltageOK = numel(Vcap)==4 && all(isfinite(Vcap)) && all(Vcap>=0);"
""
"currentOK = numel(Icap)==4 && all(isfinite(Icap));"
""
"dcOK = isfinite(Vdc) && Vdc>=0 && isfinite(Idc) && Idc>=0;"
""
"switchOK = isfinite(switchingValid) && switchingValid==1;"
""
"status = double(queueOK && phaseOK && voltageOK && ..."
"                currentOK && dcOK && switchOK);"
"end"
];

writeMATLABFunction([S9 '/Electrical_Validation_Logic'], s9Code);

s9InNames = {'queueState','activePhase','Vcap','Icap','Vdc','Idc','switchingValid'};
for i = 1:7
    connectBlocks(S9, s9InNames{i}, 'Electrical_Validation_Logic', i);
end
connectOutput(S9, 'Electrical_Validation_Logic', 1, 'validationStatus');

%% 7. RECONNECT TOP-LEVEL SUBSYSTEMS
removeDestinationLines([model '/05_Power_Electronics']);
removeDestinationLines([model '/06_Measurement']);
removeDestinationLines([model '/09_Output_Validation']);

% Connect Gate Command to S5 input 1:
% Use Gate_Selector if present so all 4 controllers drive S5; else 04_Switching_Logic
if ~isempty(find_system(model, 'SearchDepth', 1, 'Name', 'Gate_Selector'))
    connectTop(model, 'Gate_Selector', 1, '05_Power_Electronics', 1);
    fprintf('Connected Gate_Selector -> S5 Inport 1\n');
else
    connectTop(model, '04_Switching_Logic', 1, '05_Power_Electronics', 1);
    fprintf('Connected 04_Switching_Logic -> S5 Inport 1\n');
end

% S2 queue vector -> S5 input 2
connectTop(model, '02_Traffic_Queue_Plant', 1, '05_Power_Electronics', 2);
fprintf('Connected S2 Queue Plant -> S5 Inport 2\n');

% Branch S2 arrival input source to S5 input 3
s2 = [model '/02_Traffic_Queue_Plant'];
s5 = [model '/05_Power_Electronics'];
s2ph = get_param(s2, 'PortHandles');
s5ph = get_param(s5, 'PortHandles');

arrivalLine = get_param(s2ph.Inport(1), 'Line');
assert(arrivalLine ~= -1, 'S2 Input 1 has no connected arrival signal.');
arrivalSource = get_param(arrivalLine, 'SrcPortHandle');
add_line(model, arrivalSource, s5ph.Inport(3), 'autorouting', 'on');
fprintf('Branched Arrivals Source -> S5 Inport 3\n');

% S5 outputs -> S6 inputs
for i = 1:5
    connectTop(model, '05_Power_Electronics', i, '06_Measurement', i);
end
fprintf('Connected S5 Outputs (1..5) -> S6 Inputs (1..5)\n');

% S6 outputs -> S9 inputs 3 to 7
for i = 1:5
    connectTop(model, '06_Measurement', i, '09_Output_Validation', i+2);
end
fprintf('Connected S6 Outputs (1..5) -> S9 Inputs (3..7)\n');

% S9 queue input: S2 Outport 1
connectTop(model, '02_Traffic_Queue_Plant', 1, '09_Output_Validation', 1);
fprintf('Connected S2 Queue Plant -> S9 Inport 1\n');

% S9 active phase input: selected controller output
if ~isempty(find_system(model, 'SearchDepth', 1, 'Name', 'Active_Phase_Selector'))
    connectTop(model, 'Active_Phase_Selector', 1, '09_Output_Validation', 2);
    fprintf('Connected Active_Phase_Selector -> S9 Inport 2\n');
else
    connectTop(model, '03_SITRA_Controller', 1, '09_Output_Validation', 2);
    fprintf('Connected 03_SITRA_Controller -> S9 Inport 2\n');
end

% Reconnect S9 Outport 1 to LogValidation if LogValidation exists and is disconnected
if ~isempty(find_system(model, 'SearchDepth', 1, 'Name', 'LogValidation'))
    lv = [model '/LogValidation'];
    lvph = get_param(lv, 'PortHandles');
    if ~isempty(lvph.Inport) && get_param(lvph.Inport(1), 'Line') == -1
        connectTop(model, '09_Output_Validation', 1, 'LogValidation', 1);
        fprintf('Reconnected S9 Outport 1 -> LogValidation\n');
    else
        fprintf('LogValidation is already connected\n');
    end
end

%% 8. UPDATE MODEL & VERIFY
set_param(model, 'SimulationCommand', 'update');
save_system(model);

fprintf('\n============================================\n');
fprintf('ELECTRICAL UPGRADE COMPLETE\n');
fprintf('============================================\n');

% Query and display port counts
s5ph = get_param(S5, 'PortHandles');
s6ph = get_param(S6, 'PortHandles');
s9ph = get_param(S9, 'PortHandles');

fprintf('S5: %d inputs, %d outputs\n', numel(s5ph.Inport), numel(s5ph.Outport));
fprintf('S6: %d inputs, %d outputs\n', numel(s6ph.Inport), numel(s6ph.Outport));
fprintf('S9: %d inputs, %d outputs\n', numel(s9ph.Inport), numel(s9ph.Outport));
fprintf('Original traffic plant preserved\n');
fprintf('Comparison model saved successfully\n');

%% ============================================================
% LOCAL HELPER FUNCTIONS
%% ============================================================

function rebuildSubsystem(path, inputNames, outputNames)
    % Delete existing internal blocks
    blocks = find_system(path, ...
        'SearchDepth', 1, ...
        'Type', 'Block');
    for i = 2:numel(blocks)
        delete_block(blocks{i});
    end

    % Create input ports
    for i = 1:numel(inputNames)
        add_block('simulink/Ports & Subsystems/In1', ...
            [path '/' inputNames{i}], ...
            'Port', num2str(i), ...
            'Position', [30, 40+60*i, 60, 60+60*i]);
    end

    % Create output ports
    for i = 1:numel(outputNames)
        add_block('simulink/Ports & Subsystems/Out1', ...
            [path '/' outputNames{i}], ...
            'Port', num2str(i), ...
            'Position', [500, 40+60*i, 530, 60+60*i]);
    end
end

function writeMATLABFunction(path, code)
    rt = sfroot;
    chart = rt.find('-isa', 'Stateflow.EMChart', 'Path', path);
    assert(~isempty(chart), ['MATLAB Function chart not found: ' path]);
    chart.Script = strjoin(cellstr(code), newline);
end

function connectBlocks(path, source, destination, destinationPort)
    ph1 = get_param([path '/' source], 'PortHandles');
    ph2 = get_param([path '/' destination], 'PortHandles');
    add_line(path, ph1.Outport(1), ph2.Inport(destinationPort), 'autorouting', 'on');
end

function connectOutput(path, source, sourcePort, destination)
    ph1 = get_param([path '/' source], 'PortHandles');
    ph2 = get_param([path '/' destination], 'PortHandles');
    add_line(path, ph1.Outport(sourcePort), ph2.Inport(1), 'autorouting', 'on');
end

function connectTop(model, source, sourcePort, destination, destinationPort)
    ph1 = get_param([model '/' source], 'PortHandles');
    ph2 = get_param([model '/' destination], 'PortHandles');
    add_line(model, ph1.Outport(sourcePort), ph2.Inport(destinationPort), 'autorouting', 'on');
end

function removeDestinationLines(path)
    ph = get_param(path, 'PortHandles');
    for k = 1:numel(ph.Inport)
        line = get_param(ph.Inport(k), 'Line');
        if line ~= -1
            delete_line(line);
        end
    end
end

