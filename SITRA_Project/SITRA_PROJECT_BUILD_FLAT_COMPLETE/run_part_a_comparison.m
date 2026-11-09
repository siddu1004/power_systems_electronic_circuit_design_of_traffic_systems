clc;

%% ============================================================
% SITRA - FOUR CONTROLLER SIMULINK COMPARISON
% Scenario: T6 Deterministic Surge
% Model: SITRA_S2_test_ControllerCompare
% ============================================================

model = 'SITRA_S2_test_ControllerCompare';

load_system(model);

%% 1. PROJECT DIRECTORY

root = pwd;

exportDir = fullfile(root,'Results','T6_Simulink_Exports');

resultDir = fullfile(root,'Results','T6_Simulink_Metrics');

if ~isfolder(resultDir)
    mkdir(resultDir);
end

matFile = fullfile(exportDir,'SITRA_T6_All_Controllers.mat');

if ~isfile(matFile)
    error('T6 consolidated dataset not found.');
end

load(matFile,'T6');

%% 2. ENABLE SELECTED GATE LOGGING

gateBlock = [model '/Gate_Selector'];

ph = get_param(gateBlock,'PortHandles');

set_param(ph.Outport(1),'DataLogging','on');
set_param(ph.Outport(1),'DataLoggingNameMode','Custom');
set_param(ph.Outport(1),'DataLoggingName','selectedGates');

%% 3. ENABLE STAGE RESPONSE AND VALIDATION LOGGING

blocks = {
    '05_Power_Electronics'
    '09_Output_Validation'
};

signalNames = {
    's5_response'
    'validationStatus'
};

for k = 1:numel(blocks)

    path = [model '/' blocks{k}];

    ph = get_param(path,'PortHandles');

    set_param(ph.Outport(1),'DataLogging','on');
    set_param(ph.Outport(1),'DataLoggingNameMode','Custom');
    set_param(ph.Outport(1),'DataLoggingName',signalNames{k});

end

set_param(model, 'SignalLogging', 'on');
set_param(model, 'SignalLoggingName', 'logsout');
set_param(model, 'SaveTime', 'on');
set_param(model, 'TimeSaveName', 'tout');

save_system(model);

%% 4. CONTROLLER CONFIGURATION

controllers = {'SITRA','Webster','Actuated','MaxPressure'};

metrics = table();

simulationData = struct();

Sref = T6.SITRA.S;

assignin('base','T6_arrivals',Sref.arrivals);
assignin('base','activeTS',Sref.active);

% Pre-assign all controller signals so all From Workspace blocks resolve during simulation start
altNames = {'Webster','Actuated','MaxPressure'};
for j = 1:numel(altNames)
    n = altNames{j};
    S = T6.(n).S;
    assignin('base',['active_' n],S.active);
    assignin('base',['gates_' n],S.gates);
end

%% 5. RUN FOUR SIMULATIONS

for k = 1:numel(controllers)

    name = controllers{k};

    fprintf('\n====================================\n');
    fprintf('SIMULATING %s\n',upper(name));
    fprintf('====================================\n');

    % Controller selection
    assignin('base','SITRA_ControllerSelect',k);

    % Load alternative controller signals
    if k > 1

        S = T6.(name).S;

        assignin('base',['active_' name],S.active);
        assignin('base',['gates_' name],S.gates);

    end

    % Simulation
    out = sim(model,'StopTime','600');

    %% QUEUE DATA

    if isa(out.s2_q, 'timeseries')
        q = squeeze(out.s2_q.Data);
    else
        q = squeeze(out.s2_q);
    end

    if size(q,1) ~= 4
        q = q.';
    end

    if isprop(out, 'tout') && ~isempty(out.tout)
        t = out.tout(:);
    elseif isa(out.s2_q, 'timeseries')
        t = out.s2_q.Time(:);
    else
        t = (0:size(q,2)-1).';
    end

    if size(q,2) ~= numel(t)
        error('Queue/time dimension mismatch: %s',name);
    end

    totalQueue = sum(q,1);
    approachQueue = sum(q(1:3,:),1);

    %% QUEUE METRICS

    avgQueue = mean(totalQueue);

    peakQueue = max(totalQueue);

    peakBranchQueue = max(q(:));

    avgB4Queue = mean(q(4,:));

    peakB4Queue = max(q(4,:));

    %% DELAY

    arrivalRates = Sref.arrivals(:,2:4);
    arrivalTime = Sref.arrivals(:,1);

    totalVehicles = trapz(arrivalTime,...
        sum(arrivalRates,2));

    delayArea = trapz(t,approachQueue);

    avgDelay = delayArea/totalVehicles;

    %% LOGGED SIGNALS

    ds = out.logsout;

    gateTS = getSignalValues(ds, 'selectedGates');
    stageTS = getSignalValues(ds, 's5_response');
    validationTS = getSignalValues(ds, 'validationStatus');

    gateMatrix = squeeze(gateTS.Data);

    if size(gateMatrix,1) ~= numel(t)
        gateMatrix = gateMatrix.';
    end

    stage = squeeze(stageTS.Data);
    validation = squeeze(validationTS.Data);

    stage = stage(:);
    validation = validation(:);

    %% GATE EXCLUSIVITY

    maxGates = max(sum(gateMatrix,2));

    gateBinary = all(gateMatrix(:)==0 | gateMatrix(:)==1);

    gateExclusive = gateBinary && maxGates<=1;

    gateViolations = sum(sum(gateMatrix,2)>1);

    %% STAGE RESPONSE

    avgStage = mean(stage);
    peakStage = max(stage);

    %% S9 VALIDATION

    validSamples = sum(validation==1);
    invalidSamples = sum(validation==0);

    s9Pass = all(validation==1);

    %% CHECK FINITE VALUES

    finiteSignals = all(isfinite(q(:))) && ...
                    all(isfinite(gateMatrix(:))) && ...
                    all(isfinite(stage));

    %% STORE METRICS

    row = table(...
        string(name),...
        avgQueue,...
        peakQueue,...
        peakBranchQueue,...
        avgDelay,...
        avgB4Queue,...
        peakB4Queue,...
        avgStage,...
        peakStage,...
        maxGates,...
        gateViolations,...
        validSamples,...
        invalidSamples,...
        logical(gateExclusive),...
        logical(s9Pass),...
        logical(finiteSignals),...
        'VariableNames',{...
        'Controller',...
        'AverageQueue',...
        'PeakTotalQueue',...
        'PeakBranchQueue',...
        'AverageDelay',...
        'AverageB4Queue',...
        'PeakB4Queue',...
        'AverageStageResponse',...
        'PeakStageResponse',...
        'MaxSimultaneousGates',...
        'GateViolations',...
        'ValidSamples',...
        'InvalidSamples',...
        'GateExclusivity',...
        'S9Validation',...
        'FiniteSignals'});

    metrics = [metrics;row];

    %% SAVE INDIVIDUAL RESULTS

    simulationData.(name).out = out;
    simulationData.(name).queue = q;
    simulationData.(name).gates = gateMatrix;
    simulationData.(name).stage = stage;
    simulationData.(name).validation = validation;

    save(fullfile(resultDir,[name '_T6_Simulink.mat']),...
        'out','q','gateMatrix','stage','validation');

    fprintf('\n--- %s ---\n',name);

    fprintf('Average queue: %.4f veh\n',avgQueue);
    fprintf('Peak queue: %.4f veh\n',peakQueue);
    fprintf('Average delay: %.4f s/veh\n',avgDelay);
    fprintf('Average B4 queue: %.4f veh\n',avgB4Queue);
    fprintf('Average stage response: %.6f\n',avgStage);
    fprintf('Gate exclusivity: %d\n',gateExclusive);
    fprintf('S9 validation: %d\n',s9Pass);

end

%% 6. EXPORT COMPARISON TABLE

fprintf('\n============================================\n');
fprintf('FINAL SIMULINK COMPARISON\n');
fprintf('============================================\n');

disp(metrics);

writetable(metrics,...
    fullfile(resultDir,'SITRA_T6_Simulink_Comparison.csv'));

save(fullfile(resultDir,...
    'SITRA_T6_Simulink_Comparison.mat'),...
    'metrics','simulationData');

%% 7. FINAL STATUS

fprintf('\n============================================\n');
fprintf('SIMULINK COMPARISON COMPLETE\n');
fprintf('============================================\n');

fprintf('Controllers tested: %d\n',height(metrics));

fprintf('All gate checks passed: %d\n',...
    all(metrics.GateExclusivity));

fprintf('All S9 checks passed: %d\n',...
    all(metrics.S9Validation));

fprintf('All signals finite: %d\n',...
    all(metrics.FiniteSignals));

fprintf('Results directory:\n%s\n',resultDir);

close_system(model, 0);

function val = getSignalValues(ds, name)
    el = ds.getElement(name);
    if isa(el, 'Simulink.SimulationData.Dataset')
        el = el{1};
    end
    val = el.Values;
end

