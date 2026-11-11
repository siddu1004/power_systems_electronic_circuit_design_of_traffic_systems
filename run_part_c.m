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

%% 2. CREATE SIMULINK MODEL

if bdIsLoaded(model)
    close_system(model,0);
end

if isfile([model '.slx'])
    delete([model '.slx']);
end

new_system(model);
open_system(model);

%% 3. MODEL CONFIGURATION

set_param(model, ...
    'SolverType','Fixed-step', ...
    'Solver','FixedStepDiscrete', ...
    'FixedStep',num2str(Ts,16), ...
    'StopTime','0.0006', ...
    'SignalLogging','on', ...
    'SignalLoggingName','logsout');

%% 4. ADD BLOCKS

add_block('simulink/Sources/From Workspace', ...
    [model '/Requested_Gates'], ...
    'VariableName','gateCmdTS', ...
    'Interpolate','off', ...
    'OutputAfterFinalValue','Holding final value', ...
    'Position',[60 120 180 160]);

add_block('simulink/User-Defined Functions/MATLAB Function', ...
    [model '/Deadtime_Interlock'], ...
    'Position',[270 110 440 180]);

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

%% 5. DEAD-TIME MATLAB FUNCTION

code = [
"function gateOut = fcn(gateIn)"
""
"% Three-channel break-before-make interlock"
"% Ts = 1 us; dead-time = 5 us"
""
"persistent lastDesired blankCount initialized"
""
"if isempty(initialized)"
"    lastDesired = double(0);"
"    blankCount = double(0);"
"    initialized = true;"
"end"
""
"gateOut = zeros(1,3);"
""
"g1 = gateIn(1);"
"g2 = gateIn(2);"
"g3 = gateIn(3);"
""
"binaryValid = (g1==0 || g1==1) && (g2==0 || g2==1) && (g3==0 || g3==1);"
"exclusiveValid = (g1 + g2 + g3) <= 1;"
""
"if ~(binaryValid && exclusiveValid)"
"    blankCount = double(5);"
"    lastDesired = double(0);"
"    return;"
"end"
""
"desired = double(0);"
"if g1 == 1"
"    desired = double(1);"
"elseif g2 == 1"
"    desired = double(2);"
"elseif g3 == 1"
"    desired = double(3);"
"end"
""
"if desired ~= lastDesired"
"    blankCount = double(5);"
"    lastDesired = desired;"
"end"
""
"if blankCount > 0"
"    blankCount = blankCount - 1;"
"    return;"
"end"
""
"if desired == 1"
"    gateOut(1) = 1;"
"elseif desired == 2"
"    gateOut(2) = 1;"
"elseif desired == 3"
"    gateOut(3) = 1;"
"end"
""
"end"
];

rt = sfroot;

chart = rt.find('-isa','Stateflow.EMChart', ...
    'Path',[model '/Deadtime_Interlock']);

chart.Script = strjoin(cellstr(code),newline);

%% 6. CONNECT BLOCKS

p1 = get_param([model '/Requested_Gates'],'PortHandles');
p2 = get_param([model '/Deadtime_Interlock'],'PortHandles');
p3 = get_param([model '/Requested_Logging'],'PortHandles');
p4 = get_param([model '/Actual_Logging'],'PortHandles');

add_line(model,p1.Outport(1),p2.Inport(1),'autorouting','on');

add_line(model,p1.Outport(1),p3.Inport(1),'autorouting','on');

add_line(model,p2.Outport(1),p4.Inport(1),'autorouting','on');

%% 7. COMPILE AND SAVE

set_param(model,'SimulationCommand','update');

save_system(model);

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

