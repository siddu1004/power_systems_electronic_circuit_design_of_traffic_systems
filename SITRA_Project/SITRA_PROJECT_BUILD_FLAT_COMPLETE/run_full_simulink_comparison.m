clc;

%% RUN COMPLETE 4-CONTROLLER SIMULINK COMPARISON
model = 'SITRA_S2_test_ControllerCompare';
load_system(model);

% Add logging for stageResponse, gates, and validationStatus if not present
blocksToAdd = {
    'LogStageResponse', '05_Power_Electronics/1', 's2_stageResp', [1050 480 1150 510];
    'LogValidation',    '09_Output_Validation/1',  's2_valid',     [1050 700 1150 730];
    'LogGates',         'Gate_Selector/1',         's2_gates',     [1050 380 1150 410];
    'LogActive',        'Active_Phase_Selector/1', 's2_active',    [1050 250 1150 280]
};

for k = 1:size(blocksToAdd,1)
    blkName = [model '/' blocksToAdd{k,1}];
    srcPort = [model '/' blocksToAdd{k,2}];
    varName = blocksToAdd{k,3};
    pos = blocksToAdd{k,4};
    
    if getSimulinkBlockHandle(blkName) == -1
        add_block('simulink/Sinks/To Workspace', blkName, ...
            'VariableName', varName, ...
            'SaveFormat', 'Array', ...
            'Position', pos);
        add_line(model, blocksToAdd{k,2}, [blocksToAdd{k,1} '/1'], 'autorouting', 'on');
    end
end

% Set SaveFormat for s2_q and s2_res to Array
set_param([model '/02_Traffic_Queue_Plant/LogQ'], 'SaveFormat', 'Array');
set_param([model '/02_Traffic_Queue_Plant/LogRes'], 'SaveFormat', 'Array');

save_system(model);

% Load T6 data
matFile = fullfile(pwd,'Results','T6_Simulink_Exports','SITRA_T6_All_Controllers.mat');
load(matFile,'T6');

names = {'Webster','Actuated','MaxPressure'};
for k = 1:numel(names)
    name = names{k};
    S = T6.(name).S;
    assignin('base',['active_' name],S.active);
    assignin('base',['gates_' name],S.gates);
end

Sref = T6.SITRA.S;
assignin('base','T6_arrivals',Sref.arrivals);
assignin('base','activeTS',Sref.active);

ctrlNames = {'SITRA MPC','Webster','Actuated','MaxPressure'};
simSummary = struct();

fprintf('\n========================================================================================\n');
fprintf('SITRA SIMULINK HARDWARE/BEHAVIORAL COMPARISON — 4 CONTROLLERS (T6 DETERMINISTIC SURGE)\n');
fprintf('========================================================================================\n');

resultsTable = cell(4, 8);

for c = 1:4
    fprintf('\nExecuting Controller %d: %-15s ...\n', c, ctrlNames{c});
    assignin('base','SITRA_ControllerSelect',c);
    
    out = sim(model, 'StopTime', '600');
    
    % Extract signals from base workspace
    q = evalin('base', 's2_q');
    res = evalin('base', 's2_res');
    stg = evalin('base', 's2_stageResp');
    val = evalin('base', 's2_valid');
    gates = evalin('base', 's2_gates');
    
    % Metrics calculation
    totalVeh = sum(Sref.arrivals(:,2:4), 'all') * 1.0; % dt = 1 s
    avgDelay = sum(q(:,1:3), 'all') / totalVeh;
    avgQueue = mean(sum(q(:,1:3), 2));
    peakQueue = max(max(q(:,1:3)));
    peakB4 = max(q(:,4));
    meanStage = mean(stg);
    maxStage = max(stg);
    gateExcl = all(sum(gates, 2) <= 1 + 1e-6);
    validAll = all(val >= 0);
    
    simSummary.(strrep(ctrlNames{c},' ','_')).q = q;
    simSummary.(strrep(ctrlNames{c},' ','_')).stageResp = stg;
    simSummary.(strrep(ctrlNames{c},' ','_')).validation = val;
    simSummary.(strrep(ctrlNames{c},' ','_')).metrics = [avgDelay, avgQueue, peakQueue, peakB4, meanStage, maxStage];
    
    resultsTable{c,1} = ctrlNames{c};
    resultsTable{c,2} = sprintf('%.2f s', avgDelay);
    resultsTable{c,3} = sprintf('%.2f veh', avgQueue);
    resultsTable{c,4} = sprintf('%.2f veh', peakQueue);
    resultsTable{c,5} = sprintf('%.2f veh', peakB4);
    resultsTable{c,6} = sprintf('%.3f', meanStage);
    if gateExcl, resultsTable{c,7} = 'PASS'; else, resultsTable{c,7} = 'FAIL'; end
    if validAll, resultsTable{c,8} = 'PASS'; else, resultsTable{c,8} = 'FAIL'; end
end

close_system(model, 0);

fprintf('\n----------------------------------------------------------------------------------------\n');
fprintf('%-15s | %-10s | %-10s | %-10s | %-9s | %-10s | %-9s | %-8s\n', ...
    'Controller', 'Avg Delay', 'Avg Queue', 'Peak Queue', 'Peak B4', 'Mean Stage', 'Gate Excl', 'S9 Valid');
fprintf('----------------------------------------------------------------------------------------\n');
for c = 1:4
    fprintf('%-15s | %-10s | %-10s | %-10s | %-9s | %-10s | %-9s | %-8s\n', ...
        resultsTable{c,1}, resultsTable{c,2}, resultsTable{c,3}, resultsTable{c,4}, ...
        resultsTable{c,5}, resultsTable{c,6}, resultsTable{c,7}, resultsTable{c,8});
end
fprintf('----------------------------------------------------------------------------------------\n');

% Save Simulink comparative results
outPath = fullfile(pwd,'Results','T6_Simulink_Exports','SITRA_Simulink_4Controller_Comparison.mat');
save(outPath, 'simSummary', 'resultsTable');
fprintf('\nComparison results exported to: %s\n', outPath);

