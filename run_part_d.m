clc;
clearvars -except rootDir mode tMasterStart;

%% ============================================================
% SITRA PART D
% FOUR-CONTROLLER INTEGRATED ELECTRICAL & TRAFFIC VALIDATION
% Model: SITRA_S2_test_ControllerCompare (Upgraded S5-S6-S9)
% Scenario: T6 Deterministic Surge (600 s)
%% ============================================================

rootDir = fileparts(mfilename('fullpath'));
if isempty(rootDir), rootDir = pwd; end
addpath(rootDir);
flatDir = fullfile(rootDir, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE');
if exist(flatDir, 'dir'), addpath(flatDir); end

model = 'SITRA_S2_test_ControllerCompare';
assert(exist(model,'file') > 0, 'Comparison model file not found.');
load_system(model);

fprintf('\n============================================================\n');
fprintf('SITRA PART D: FOUR-CONTROLLER INTEGRATED EVALUATION\n');
fprintf('============================================================\n');

%% 1. LOAD WORKSPACE VARIABLES & PARAMETERS
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

%% 2. CONFIGURE SIGNAL LOGGING
logPort(model,'02_Traffic_Queue_Plant',1,'s2_queue');
logPort(model,'Gate_Selector',1,'gate_selected');
logPort(model,'05_Power_Electronics',1,'s5_Vcap');
logPort(model,'05_Power_Electronics',2,'s5_Icap');
logPort(model,'05_Power_Electronics',3,'s5_Vdc');
logPort(model,'05_Power_Electronics',4,'s5_Idc');
logPort(model,'05_Power_Electronics',5,'s5_switchValid');
logPort(model,'09_Output_Validation',1,'s9_status');

set_param(model,'SignalLogging','on');
set_param(model,'SignalLoggingName','logsout');

%% 3. CONTROLLERS DEFINITION
controllers = {
    1, 'SITRA MPC';
    2, 'Webster Fixed-Time';
    3, 'Vehicle-Actuated';
    4, 'MaxPressure'
};

N_ctrl = size(controllers,1);
results = struct();

%% 4. RUN ALL FOUR CONTROLLERS
for k = 1:N_ctrl
    cID = controllers{k,1};
    cName = controllers{k,2};
    
    fprintf('\n--- Running Controller %d/4: %s ---\n', cID, cName);
    assignin('base','SITRA_ControllerSelect',cID);
    
    out = sim(model,'StopTime','600');
    logs = out.logsout;
    
    % Extract signals
    t = getSignal(logs,'s5_Vcap').Time;
    N = numel(t);
    dt = mean(diff(t));
    
    Q = signalMatrix(logs,'s2_queue',N);
    G = signalMatrix(logs,'gate_selected',N);
    V = signalMatrix(logs,'s5_Vcap',N);
    I = signalMatrix(logs,'s5_Icap',N);
    Vdc = signalMatrix(logs,'s5_Vdc',N);
    Idc = signalMatrix(logs,'s5_Idc',N);
    switchValid = signalMatrix(logs,'s5_switchValid',N);
    s9 = signalMatrix(logs,'s9_status',N);
    
    % Traffic Metrics (consistent with Part A)
    arrivalRates = Sref.arrivals(:, 2:4);
    totalVehicles = trapz(t, sum(arrivalRates, 2));
    approachQueue = sum(Q(:, 1:3), 2);
    delayArea = trapz(t, approachQueue);
    meanDelay = delayArea / totalVehicles;
    
    maxQueue = max(sum(Q, 2));
    maxBranch = max(max(Q(:, 1:3)));
    maxB4 = max(Q(:, 4));
    throughput = trapz(t, Idc); % total cleared bottleneck throughput
    
    % Electrical & Conservation Metrics
    dV = diff(V,1,1)/dt;
    maxCurrentError = max(abs(I(1:end-1,:) - dV), [], 'all');
    maxVoltageError = max(abs(V - Q), [], 'all');
    maxVcap = max(V, [], 'all');
    maxVdc = max(Vdc);
    meanIdc = mean(Idc);
    totalCharge = sum(Idc) * dt; % Coulombs
    
    % Exclusivity & Validity
    gateExclusivity = all(sum(G,2) <= 1) && all((G(:)==0)|(G(:)==1));
    s5ValidRatio = mean(switchValid == 1) * 100;
    s9ValidRatio = mean(s9 == 1) * 100;
    
    % Store
    key = sprintf('C%d', cID);
    results.(key).name = cName;
    results.(key).meanDelay = meanDelay;
    results.(key).maxQueue = maxQueue;
    results.(key).maxBranch = maxBranch;
    results.(key).maxB4 = maxB4;
    results.(key).throughput = throughput;
    results.(key).maxCurrentError = maxCurrentError;
    results.(key).maxVoltageError = maxVoltageError;
    results.(key).maxVcap = maxVcap;
    results.(key).maxVdc = maxVdc;
    results.(key).meanIdc = meanIdc;
    results.(key).totalCharge = totalCharge;
    results.(key).gateExclusivity = gateExclusivity;
    results.(key).s5ValidRatio = s5ValidRatio;
    results.(key).s9ValidRatio = s9ValidRatio;
    results.(key).t = t;
    results.(key).Q = Q;
    results.(key).V = V;
    results.(key).I = I;
    results.(key).Vdc = Vdc;
    results.(key).Idc = Idc;
    
    fprintf('  Mean Delay:        %.2f s\n', meanDelay);
    fprintf('  Max Total Queue:   %.2f veh (%.2f V)\n', maxQueue, maxQueue);
    fprintf('  Max Branch Queue:  %.2f veh\n', maxBranch);
    fprintf('  Max Bottleneck B4: %.2f veh (Vdc peak: %.2f V)\n', maxB4, maxVdc);
    fprintf('  Throughput:        %.1f veh (Charge: %.1f C)\n', throughput, totalCharge);
    fprintf('  Max Current Error: %.2e A\n', maxCurrentError);
    fprintf('  S5 Validity:       %.1f%%\n', s5ValidRatio);
    fprintf('  S9 Validation:     %.1f%%\n', s9ValidRatio);
end

%% 5. CONSOLIDATED COMPARISON TABLE
fprintf('\n========================================================================================================================\n');
fprintf('PART D CONSOLIDATED FOUR-CONTROLLER RESULTS (UPGRADED ELECTRICAL-TRAFFIC SYSTEM)\n');
fprintf('========================================================================================================================\n');
fprintf('%-18s | %-9s | %-11s | %-10s | %-10s | %-9s | %-12s | %-10s | %-10s\n', ...
    'Controller', 'Delay (s)', 'Max Q (veh)', 'Max B (veh)', 'Max B4 (V)', 'Peak Vdc', 'Throughput', 'Curr Err (A)', 'S9 Valid');
fprintf('------------------------------------------------------------------------------------------------------------------------\n');

for k = 1:N_ctrl
    cID = controllers{k,1};
    res = results.(sprintf('C%d', cID));
    fprintf('%-18s | %9.2f | %11.2f | %10.2f | %10.2f | %9.2f | %12.1f | %12.2e | %9.1f%%\n', ...
        res.name, res.meanDelay, res.maxQueue, res.maxBranch, res.maxB4, res.maxVdc, ...
        res.throughput, res.maxCurrentError, res.s9ValidRatio);
end
fprintf('========================================================================================================================\n');

%% 6. SAVE RESULTS
outDir = fullfile('Results','PartD_Four_Controller_Integration');
if ~exist(outDir,'dir'), mkdir(outDir); end

save(fullfile(outDir,'PartD_Results.mat'),'results');

% Write CSV summary
csvPath = fullfile(outDir,'SITRA_PartD_Four_Controller_Comparison.csv');
fid = fopen(csvPath,'w');
fprintf(fid,'Controller,MeanDelay_s,MaxQueue_veh,MaxBranch_veh,MaxB4_veh,PeakVdc_V,Throughput_veh,TotalCharge_C,MaxCurrentError_A,S5ValidPct,S9ValidPct\n');
for k = 1:N_ctrl
    cID = controllers{k,1};
    res = results.(sprintf('C%d', cID));
    fprintf(fid,'%s,%.4f,%.4f,%.4f,%.4f,%.4f,%.2f,%.2f,%.4e,%.1f,%.1f\n', ...
        res.name, res.meanDelay, res.maxQueue, res.maxBranch, res.maxB4, res.maxVdc, ...
        res.throughput, res.totalCharge, res.maxCurrentError, res.s5ValidRatio, res.s9ValidRatio);
end
fclose(fid);
fprintf('\nResults successfully saved to:\n  - %s\n  - %s\n', fullfile(outDir,'PartD_Results.mat'), csvPath);

%% ============================================================
% HELPER FUNCTIONS
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
        % already time x channels
    elseif size(D,2)==N
        D = D.';
    else
        error('Unexpected signal dimensions for %s.',name);
    end
    M = D;
    assert(size(M,1)==N, ['Time dimension mismatch for ' name]);
end

