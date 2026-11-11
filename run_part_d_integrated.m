clc;
clearvars -except rootDir mode tMasterStart sw sh screen;

%% ============================================================
% SITRA PART D
% FOUR-CONTROLLER INTEGRATED ELECTRICAL VALIDATION
%% ============================================================

rootDir = fileparts(mfilename('fullpath'));
if isempty(rootDir), rootDir = pwd; end
addpath(rootDir);
flatDir = fullfile(rootDir, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE');
if exist(flatDir, 'dir'), addpath(flatDir); end

model = 'SITRA_S2_test_ControllerCompare';
assert(exist(model,'file') > 0, 'Comparison model file not found.');
load_system(model);

resultDir = fullfile('Results','PartD_Integrated_Validation');
if ~exist(resultDir,'dir')
    mkdir(resultDir);
end

%% 1. AUTO-LOAD REQUIRED WORKSPACE SIGNALS & PARAMETERS
exportDir = fullfile('Results','T6_Simulink_Exports');

% Reference SITRA MPC
Sref = load(fullfile(exportDir,'SITRA_T6.mat'));
if isfield(Sref,'S'), Sref = Sref.S; end
assignin('base','T6_arrivals',Sref.arrivals);
assignin('base','activeTS',Sref.active);

% Baseline exports
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

% Electrical parameters
assignin('base','Ceq',1);
assignin('base','kq',1);
assignin('base','kI',1);
assignin('base','traffic_dt',1);
assignin('base','branchCapacity',[0.65; 0.35; 0.25; 0.45]);

%% 2. CONTROLLER DEFINITIONS
controllers = {'SITRA','Webster','Actuated','MaxPressure'};
selectors = [1 2 3 4];

%% 3. ENABLE LOGGING
enableLog(model,'02_Traffic_Queue_Plant',1,'D_queue');
enableLog(model,'Gate_Selector',1,'D_gates');
enableLog(model,'05_Power_Electronics',1,'D_Vcap');
enableLog(model,'05_Power_Electronics',2,'D_Icap');
enableLog(model,'05_Power_Electronics',3,'D_Vdc');
enableLog(model,'05_Power_Electronics',4,'D_Idc');
enableLog(model,'05_Power_Electronics',5,'D_switchValid');
enableLog(model,'09_Output_Validation',1,'D_S9');

set_param(model,'SignalLogging','on');
set_param(model,'SignalLoggingName','logsout');

%% 4. RUN ALL CONTROLLERS
Results = struct();

for k = 1:numel(controllers)
    name = controllers{k};

    fprintf('\n========================================\n');
    fprintf('PART D: SIMULATING %s\n',upper(name));
    fprintf('========================================\n');

    assignin('base','SITRA_ControllerSelect',selectors(k));
    set_param(model,'SimulationCommand','update');

    out = sim(model,'StopTime','600');
    logs = out.logsout;

    %% Extract signals
    qTS = getSignalTS(logs,'D_queue');
    gTS = getSignalTS(logs,'D_gates');
    vTS = getSignalTS(logs,'D_Vcap');
    iTS = getSignalTS(logs,'D_Icap');
    vdcTS = getSignalTS(logs,'D_Vdc');
    idcTS = getSignalTS(logs,'D_Idc');
    swTS = getSignalTS(logs,'D_switchValid');
    s9TS = getSignalTS(logs,'D_S9');

    t = qTS.Time;

    Q = orientData(qTS.Data,numel(t));
    G = orientData(gTS.Data,numel(t));
    V = orientData(vTS.Data,numel(t));
    I = orientData(iTS.Data,numel(t));
    Vdc = orientData(vdcTS.Data,numel(t));
    Idc = orientData(idcTS.Data,numel(t));
    sw = orientData(swTS.Data,numel(t));
    s9 = orientData(s9TS.Data,numel(t));

    %% Traffic metrics
    totalQ = sum(Q,2);
    averageQueue = mean(totalQ);
    peakQueue = max(totalQ);
    peakBranchQueue = max(Q(:,1:3),[],'all');
    averageB4 = mean(Q(:,4));
    peakB4 = max(Q(:,4));

    %% Electrical validation
    voltageError = max(abs(V-Q),[],'all');
    dt = mean(diff(t));
    currentError = max(abs(I(1:end-1,:) - diff(V,1,1)/dt),[],'all');

    finiteSignals = ...
        all(isfinite(Q),'all') && ...
        all(isfinite(G),'all') && ...
        all(isfinite(V),'all') && ...
        all(isfinite(I),'all') && ...
        all(isfinite(Vdc),'all') && ...
        all(isfinite(Idc),'all');

    voltageNonnegative = all(V>=0,'all');

    %% Gate validation
    maxSimultaneous = max(sum(G,2));
    gateBinary = all((G(:)==0)|(G(:)==1));
    gateExclusive = maxSimultaneous<=1;
    gateViolations = sum(sum(G,2)>1);

    %% S5 and S9 validation
    switchValid = all(sw==1);
    validSamples = sum(s9==1);
    invalidSamples = sum(s9~=1);
    S9Passed = invalidSamples==0;

    %% Consolidate result
    Results.(name).time = t;
    Results.(name).queue = Q;
    Results.(name).gates = G;
    Results.(name).Vcap = V;
    Results.(name).Icap = I;
    Results.(name).Vdc = Vdc;
    Results.(name).Idc = Idc;

    Results.(name).averageQueue = averageQueue;
    Results.(name).peakQueue = peakQueue;
    Results.(name).peakBranchQueue = peakBranchQueue;
    Results.(name).averageB4 = averageB4;
    Results.(name).peakB4 = peakB4;

    Results.(name).voltageError = voltageError;
    Results.(name).currentError = currentError;

    Results.(name).finiteSignals = finiteSignals;
    Results.(name).voltageNonnegative = voltageNonnegative;

    Results.(name).maxSimultaneousGates = maxSimultaneous;
    Results.(name).gateViolations = gateViolations;
    Results.(name).gateBinary = gateBinary;
    Results.(name).gateExclusive = gateExclusive;

    Results.(name).switchValid = switchValid;
    Results.(name).validSamples = validSamples;
    Results.(name).invalidSamples = invalidSamples;
    Results.(name).S9Passed = S9Passed;

    Results.(name).PASS = ...
        voltageError<1e-8 && ...
        currentError<1e-8 && ...
        finiteSignals && ...
        voltageNonnegative && ...
        gateBinary && ...
        gateExclusive && ...
        gateViolations==0 && ...
        switchValid && ...
        S9Passed;

    fprintf('Average queue: %.4f veh\n',averageQueue);
    fprintf('Peak total queue: %.4f veh\n',peakQueue);
    fprintf('Peak branch queue: %.4f veh\n',peakBranchQueue);
    fprintf('Average B4 queue: %.4f veh\n',averageB4);

    fprintf('Voltage error: %.3e V\n',voltageError);
    fprintf('Current error: %.3e A\n',currentError);

    fprintf('Maximum simultaneous gates: %d\n',maxSimultaneous);
    fprintf('Gate violations: %d\n',gateViolations);

    fprintf('S9 valid samples: %d / %d\n',validSamples,numel(t));
    fprintf('Controller integrated result: %d\n',Results.(name).PASS);

    %% Save individual run
    individualResult = Results.(name);
    save(fullfile(resultDir,[name '_Integrated.mat']),'individualResult');
end

%% 5. SUMMARY TABLE
Controller = strings(4,1);
AverageQueue = zeros(4,1);
PeakQueue = zeros(4,1);
PeakBranchQueue = zeros(4,1);
AverageB4 = zeros(4,1);

VoltageError = zeros(4,1);
CurrentError = zeros(4,1);

GateViolations = zeros(4,1);
ValidSamples = zeros(4,1);
IntegratedPASS = false(4,1);

for k = 1:4
    name = controllers{k};
    R = Results.(name);

    Controller(k) = name;
    AverageQueue(k) = R.averageQueue;
    PeakQueue(k) = R.peakQueue;
    PeakBranchQueue(k) = R.peakBranchQueue;
    AverageB4(k) = R.averageB4;

    VoltageError(k) = R.voltageError;
    CurrentError(k) = R.currentError;

    GateViolations(k) = R.gateViolations;
    ValidSamples(k) = R.validSamples;
    IntegratedPASS(k) = R.PASS;
end

Summary = table(Controller,AverageQueue,PeakQueue, ...
    PeakBranchQueue,AverageB4,VoltageError, ...
    CurrentError,GateViolations,ValidSamples,IntegratedPASS);

disp(Summary);

%% 6. FINAL STATUS
overallPASS = all(IntegratedPASS);

if overallPASS
    fprintf('\nPART D RESULT: ALL FOUR CONTROLLERS PASS\n');
else
    fprintf('\nPART D RESULT: INTEGRATED VALIDATION FAILED\n');
end

%% 7. SAVE CONSOLIDATED RESULTS
save(fullfile(resultDir,'PartD_AllControllers.mat'), ...
    'Results','Summary','overallPASS');

writetable(Summary, fullfile(resultDir,'PartD_Summary.csv'));
fprintf('\nResults saved to:\n%s\n',resultDir);

%% ============================================================
% LOCAL HELPERS
%% ============================================================

function enableLog(model,subsystem,port,name)
    ph = get_param([model '/' subsystem],'PortHandles');
    if port <= length(ph.Outport)
        set_param(ph.Outport(port), ...
            'DataLogging','on', ...
            'DataLoggingNameMode','Custom', ...
            'DataLoggingName',name);
    end
end

function ts = getSignalTS(logs,name)
    el = logs.getElement(name);
    if isa(el,'Simulink.SimulationData.Dataset')
        el = el{1};
    end
    ts = el.Values;
end

function M = orientData(D,N)
    M = squeeze(D);
    if isvector(M)
        M = M(:);
    elseif size(M,1)==N
        % Correct orientation.
    elseif size(M,2)==N
        M = M.';
    else
        error('Unexpected logged signal dimensions.');
    end
    assert(size(M,1)==N, 'Logged signal time dimension mismatch.');
end

