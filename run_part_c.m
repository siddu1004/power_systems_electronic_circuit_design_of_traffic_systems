clc;
clearvars -except rootDir mode tMasterStart sw sh screen f_act1 f_act2 f_act3 f_act4;

%% ============================================================
% SITRA PART C
% 5 MICROSECOND SEMICONDUCTOR DEAD-TIME TESTBENCH
%% ============================================================

model = 'SITRA_Deadtime_Testbench';

Ts = 1e-6;
Td = 5e-6;

deadSamples = round(Td/Ts);

assert(abs(deadSamples*Ts-Td)<1e-12, ...
    'Dead-time must be an integer number of simulation steps.');

%% 1. CREATE GATE COMMAND TEST DATA

time = (0:100e-6:600e-6).';

gateData = [
    1 0 0
    0 1 0
    0 0 1
    1 0 0
    0 1 0
    0 0 1
    0 0 0
];

gateCmdTS = timeseries(gateData,time);

assignin('base','gateCmdTS',gateCmdTS);

%% 2. LOAD OR BUILD PURE NATIVE SIMULINK MODEL (ZERO STATEFLOW / ZERO MEX COMPILER)
% Uses pure discrete Simulink blocks (5x Unit Delay + Product + Exclusivity Gate)
% so it runs in <0.2s on any laptop without C/MEX compilation!

rebuildC = ~isfile([model '.slx']);
if ~rebuildC
    if ~bdIsLoaded(model), load_system(model); end
    if ~isempty(find_system(model, 'SFBlockType', 'MATLAB Function'))
        close_system(model, 0);
        delete([model '.slx']);
        rebuildC = true;
    end
end

if rebuildC
    new_system(model);
    open_system(model);

    set_param(model, ...
        'SolverType','Fixed-step', ...
        'Solver','FixedStepDiscrete', ...
        'FixedStep',num2str(Ts,16), ...
        'StopTime','0.0006', ...
        'SignalLogging','on', ...
        'SignalLoggingName','logsout');

    add_block('simulink/Sources/From Workspace', ...
        [model '/Requested_Gates'], ...
        'VariableName','gateCmdTS', ...
        'Interpolate','off', ...
        'OutputAfterFinalValue','Holding final value', ...
        'Position',[60 120 180 160]);

    add_block('simulink/Ports & Subsystems/Subsystem', ...
        [model '/Deadtime_Interlock'], ...
        'Position',[270 110 440 180]);
    Simulink.SubSystem.deleteContents([model '/Deadtime_Interlock']);

    sub = [model '/Deadtime_Interlock'];
    add_block('simulink/Sources/In1', [sub '/gateIn'], 'Position', [30 80 60 94]);
    add_block('simulink/Math Operations/Sum of Elements', [sub '/SumGates'], 'Position', [110 140 140 170]);
    add_block('simulink/Logic and Bit Operations/Compare To Constant', [sub '/ExclCheck'], ...
        'relop', '<=', 'const', '1', 'Position', [170 140 205 170]);
    add_block('simulink/Signal Attributes/Data Type Conversion', [sub '/ExclDbl'], ...
        'OutDataTypeStr', 'double', 'Position', [220 140 250 170]);
    add_block('simulink/Math Operations/Product', [sub '/ValidGate'], 'Inputs', '**', 'Position', [270 75 300 110]);
    add_line(sub, 'gateIn/1', 'SumGates/1', 'autorouting', 'on');
    add_line(sub, 'SumGates/1', 'ExclCheck/1', 'autorouting', 'on');
    add_line(sub, 'ExclCheck/1', 'ExclDbl/1', 'autorouting', 'on');
    add_line(sub, 'gateIn/1', 'ValidGate/1', 'autorouting', 'on');
    add_line(sub, 'ExclDbl/1', 'ValidGate/2', 'autorouting', 'on');

    add_block('simulink/Math Operations/Product', [sub '/AndChain'], 'Inputs', '******', 'Position', [650 60 690 210]);
    add_line(sub, 'ValidGate/1', 'AndChain/1', 'autorouting', 'on');
    prevBlk = 'ValidGate';
    for dIdx = 1:5
        dName = sprintf('Delay_%dus', dIdx);
        add_block('simulink/Discrete/Unit Delay', [sub '/' dName], ...
            'InitialCondition', '0', 'SampleTime', '-1', ...
            'Position', [300 + dIdx*60, 120, 335 + dIdx*60, 150]);
        add_line(sub, [prevBlk '/1'], [dName '/1'], 'autorouting', 'on');
        add_line(sub, [dName '/1'], sprintf('AndChain/%d', dIdx+1), 'autorouting', 'on');
        prevBlk = dName;
    end
    add_block('simulink/Sinks/Out1', [sub '/gateOut'], 'Position', [740 128 770 142]);
    add_line(sub, 'AndChain/1', 'gateOut/1', 'autorouting', 'on');

    add_block('simulink/Sinks/To Workspace', ...
        [model '/Requested_Logging'], ...
        'VariableName','requestedGates', ...
        'SaveFormat','Timeseries', ...
        'Position',[270 250 390 290]);

    add_block('simulink/Sinks/To Workspace', ...
        [model '/Actual_Logging'], ...
        'VariableName','actualGates', ...
        'SaveFormat','Timeseries', ...
        'Position',[540 120 660 160]);

    p1 = get_param([model '/Requested_Gates'],'PortHandles');
    p2 = get_param([model '/Deadtime_Interlock'],'PortHandles');
    p3 = get_param([model '/Requested_Logging'],'PortHandles');
    p4 = get_param([model '/Actual_Logging'],'PortHandles');

    add_line(model,p1.Outport(1),p2.Inport(1),'autorouting','on');
    add_line(model,p1.Outport(1),p3.Inport(1),'autorouting','on');
    add_line(model,p2.Outport(1),p4.Inport(1),'autorouting','on');

    save_system(model);
else
    open_system(model);
end

%% 8. RUN TESTBENCH

fprintf('\nRunning 5 us dead-time testbench...\n');

out = sim(model);

requestedTS = out.get('requestedGates');
actualTS = out.get('actualGates');

t = actualTS.Time;

requested = squeeze(requestedTS.Data);
actual = squeeze(actualTS.Data);

if size(actual,1)~=numel(t)
    actual=actual.';
end

if size(requested,1)~=numel(t)
    requested=requested.';
end

%% 9. GATE SAFETY CHECKS

binaryOK = all((actual(:)==0)|(actual(:)==1));

simultaneous = sum(actual,2);

maxSimultaneous = max(simultaneous);

exclusivityOK = maxSimultaneous<=1;

%% 10. DEAD-TIME MEASUREMENT

risingTimes = [];
fallingTimes = [];

for channel = 1:3

    g = actual(:,channel);

    rising = find(diff(g)==1)+1;
    falling = find(diff(g)==-1)+1;

    risingTimes = [risingTimes; ...
        [repmat(channel,numel(rising),1),t(rising)]];

    fallingTimes = [fallingTimes; ...
        [repmat(channel,numel(falling),1),t(falling)]];

end

measuredDeadTimes = [];

for i = 1:size(fallingTimes,1)

    oldChannel = fallingTimes(i,1);
    fallTime = fallingTimes(i,2);

    candidates = risingTimes( ...
        risingTimes(:,1)~=oldChannel & ...
        risingTimes(:,2)>fallTime,:);

    if ~isempty(candidates)

        nextRise = min(candidates(:,2));

        measuredDeadTimes(end+1,1) = ...
            nextRise-fallTime;

    end

end

if isempty(measuredDeadTimes)

    minimumDeadTime = NaN;
    deadtimeOK = false;

else

    minimumDeadTime = min(measuredDeadTimes);

    deadtimeOK = minimumDeadTime >= Td-0.5*Ts;

end

%% 11. RESULTS

fprintf('\n============================================\n');
fprintf('DEAD-TIME VERIFICATION RESULTS\n');
fprintf('============================================\n');

fprintf('Simulation step: %.2f us\n',Ts*1e6);
fprintf('Configured dead-time: %.2f us\n',Td*1e6);

fprintf('Maximum simultaneous gates: %d\n', ...
    maxSimultaneous);

fprintf('Binary gate signals: %d\n',binaryOK);
fprintf('Mutual exclusion: %d\n',exclusivityOK);

fprintf('Measured minimum dead-time: %.2f us\n', ...
    minimumDeadTime*1e6);

fprintf('Dead-time requirement: %d\n',deadtimeOK);

PASS = binaryOK && exclusivityOK && deadtimeOK;

fprintf('\n============================================\n');

if PASS
    fprintf('PART C RESULT: PASS\n');
else
    fprintf('PART C RESULT: FAIL\n');
end

fprintf('============================================\n');

%% 12. SAVE RESULTS

PartC.Ts = Ts;
PartC.Td = Td;
PartC.minimumDeadTime = minimumDeadTime;
PartC.maxSimultaneousGates = maxSimultaneous;
PartC.binaryOK = binaryOK;
PartC.exclusivityOK = exclusivityOK;
PartC.deadtimeOK = deadtimeOK;
PartC.PASS = PASS;

PartC.time = t;
PartC.requestedGates = requested;
PartC.actualGates = actual;

resultDir = fullfile('Results','PartC_Deadtime_Validation');

if ~exist(resultDir,'dir')
    mkdir(resultDir);
end

save(fullfile(resultDir,'PartC_Results.mat'),'PartC');

fprintf('\nResults saved to %s\n',resultDir);

