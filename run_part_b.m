clc;
clearvars;

%% ============================================================
% SITRA PART B
% CAPACITOR VOLTAGE/CURRENT CONSERVATION VERIFICATION
%% ============================================================

model = 'SITRA_S2_test_ControllerCompare';
load_system(model);

fprintf('\n============================================\n');
fprintf('PART B: ELECTRICAL CONSERVATION VERIFICATION\n');
fprintf('============================================\n');

%% 1. LOAD T6 REFERENCE ARRIVALS & WORKSPACE PARAMETERS

dataFile = fullfile('Results','T6_Simulink_Exports','SITRA_T6.mat');
assert(isfile(dataFile), 'SITRA_T6.mat not found in Results/T6_Simulink_Exports.');

D = load(dataFile);
if isfield(D,'S')
    S = D.S;
else
    S = D;
end

assignin('base','T6_arrivals',S.arrivals);
assignin('base','activeTS',S.active);
assignin('base','SITRA_ControllerSelect',1);

% Ensure baseline signals are defined for all From Workspace blocks
cNames = {'Webster','Actuated','MaxPressure'};
exportDir = fullfile('Results','T6_Simulink_Exports');
for i = 1:numel(cNames)
    n = cNames{i};
    matFile = fullfile(exportDir,[n '_T6.mat']);
    if isfile(matFile)
        Sbl = load(matFile);
        assignin('base',['active_' n],Sbl.active);
        assignin('base',['gates_' n],Sbl.gates);
    end
end

% Set electrical parameters in base workspace
assignin('base','Ceq',1);
assignin('base','kq',1);
assignin('base','kI',1);
assignin('base','traffic_dt',1);
assignin('base','branchCapacity',[0.65; 0.35; 0.25; 0.45]);

%% 2. ENABLE SIGNAL LOGGING

logPort(model,'02_Traffic_Queue_Plant',1,'s2_queue');

logPort(model,'05_Power_Electronics',1,'s5_Vcap');
logPort(model,'05_Power_Electronics',2,'s5_Icap');
logPort(model,'05_Power_Electronics',3,'s5_Vdc');
logPort(model,'05_Power_Electronics',4,'s5_Idc');
logPort(model,'05_Power_Electronics',5,'s5_switchValid');

logPort(model,'09_Output_Validation',1,'s9_status');

set_param(model,'SignalLogging','on');
set_param(model,'SignalLoggingName','logsout');

%% 3. RUN SIMULATION

fprintf('\nRunning SITRA MPC simulation (600 s)...\n');

out = sim(model,'StopTime','600');
logs = out.logsout;

%% 4. EXTRACT SIGNALS

t = getSignal(logs,'s5_Vcap').Time;

Q = signalMatrix(logs,'s2_queue',numel(t));
V = signalMatrix(logs,'s5_Vcap',numel(t));
I = signalMatrix(logs,'s5_Icap',numel(t));

Vdc = signalMatrix(logs,'s5_Vdc',numel(t));
Idc = signalMatrix(logs,'s5_Idc',numel(t));

switchValid = signalMatrix(logs,'s5_switchValid',numel(t));
s9 = signalMatrix(logs,'s9_status',numel(t));

%% 5. DIMENSION CHECK

assert(size(Q,2)==4,'Queue signal must contain 4 branches.');
assert(size(V,2)==4,'Capacitor voltage must contain 4 channels.');
assert(size(I,2)==4,'Capacitor current must contain 4 channels.');

assert(size(Vdc,2)==1 && size(Idc,2)==1, ...
    'DC-link signals must be scalar.');

dt = mean(diff(t));

fprintf('\nSimulation samples: %d\n',numel(t));
fprintf('Sample interval: %.9f s\n',dt);

%% 6. VOLTAGE-QUEUE EQUIVALENCE

voltageError = V - Q;
maxVoltageError = max(abs(voltageError),[],'all');

%% 7. CAPACITOR CURRENT CONSERVATION

% Discrete voltage derivative.
dV = diff(V,1,1)/dt;

% Capacitor current prediction for Ceq = 1 F.
Ipredicted = dV;

% Compare current at time k against voltage change k -> k+1.
currentError = I(1:end-1,:) - Ipredicted;
maxCurrentError = max(abs(currentError),[],'all');

%% 8. DOWNSTREAM B4 CONSERVATION

% B4 net current must equal the change in B4 voltage.
B4CurrentError = I(1:end-1,4) - dV(:,4);
maxB4Error = max(abs(B4CurrentError));

%% 9. SIGNAL VALIDITY

voltageFinite = all(isfinite(V),'all');
currentFinite = all(isfinite(I),'all');

dcFinite = all(isfinite(Vdc),'all') && ...
           all(isfinite(Idc),'all');

voltageNonnegative = all(V>=0,'all');
switchingPassed = all(switchValid==1);
S9Passed = all(s9==1);

%% 10. REPORT

fprintf('\n============================================\n');
fprintf('PART B VERIFICATION RESULTS\n');
fprintf('============================================\n');

fprintf('\n1. Voltage-queue equivalence\n');
fprintf('Maximum voltage error: %.12g V\n',maxVoltageError);

fprintf('\n2. Capacitor current conservation\n');
fprintf('Maximum current error: %.12g A\n',maxCurrentError);

fprintf('\n3. B4 downstream conservation\n');
fprintf('Maximum B4 error: %.12g A\n',maxB4Error);

fprintf('\n4. Signal validity\n');
fprintf('Voltage finite: %d\n',voltageFinite);
fprintf('Current finite: %d\n',currentFinite);
fprintf('DC signals finite: %d\n',dcFinite);
fprintf('Voltage non-negative: %d\n',voltageNonnegative);

fprintf('\n5. Switching and validation\n');
fprintf('S5 switching validity: %d\n',switchingPassed);
fprintf('S9 validation: %d\n',S9Passed);

%% 11. PASS/FAIL

tolerance = 1e-8;

PASS = ...
    maxVoltageError < tolerance && ...
    maxCurrentError < tolerance && ...
    maxB4Error < tolerance && ...
    voltageFinite && ...
    currentFinite && ...
    dcFinite && ...
    voltageNonnegative && ...
    switchingPassed && ...
    S9Passed;

fprintf('\n============================================\n');

if PASS
    fprintf('PART B RESULT: PASS\n');
else
    fprintf('PART B RESULT: FAIL\n');
end

fprintf('============================================\n');

%% 12. SAVE RESULTS

PartB.maxVoltageError = maxVoltageError;
PartB.maxCurrentError = maxCurrentError;
PartB.maxB4Error = maxB4Error;

PartB.voltageFinite = voltageFinite;
PartB.currentFinite = currentFinite;
PartB.dcFinite = dcFinite;

PartB.switchingPassed = switchingPassed;
PartB.S9Passed = S9Passed;
PartB.PASS = PASS;

PartB.time = t;
PartB.queue = Q;
PartB.voltage = V;
PartB.current = I;
PartB.Vdc = Vdc;
PartB.Idc = Idc;

resultDir = fullfile('Results','PartB_Electrical_Validation');

if ~exist(resultDir,'dir')
    mkdir(resultDir);
end

save(fullfile(resultDir,'PartB_Results.mat'),'PartB');
fprintf('\nResults saved to %s\n',resultDir);

%% ============================================================
% LOCAL HELPER FUNCTIONS
%% ============================================================

function logPort(model,subsystem,portNumber,signalName)
    path = [model '/' subsystem];
    ph = get_param(path,'PortHandles');
    set_param(ph.Outport(portNumber), ...
        'DataLogging','on', ...
        'DataLoggingNameMode','Custom', ...
        'DataLoggingName',signalName);
end

function ts = getSignal(logs,name)
    element = logs.getElement(name);
    if isa(element, 'Simulink.SimulationData.Dataset')
        element = element{1};
    end
    ts = element.Values;
end

function M = signalMatrix(logs,name,N)
    ts = getSignal(logs,name);
    D = squeeze(ts.Data);

    if isvector(D)
        D = D(:);
    elseif size(D,1)==N
        % Already time x channels.
    elseif size(D,2)==N
        D = D.';
    else
        error('Unexpected signal dimensions for %s.',name);
    end

    M = D;
    assert(size(M,1)==N, ['Time dimension mismatch for ' name]);
end

