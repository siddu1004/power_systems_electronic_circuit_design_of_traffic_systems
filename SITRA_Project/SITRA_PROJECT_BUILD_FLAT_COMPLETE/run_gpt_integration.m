clc;

%% SITRA FOUR-CONTROLLER INTEGRATION

model = 'SITRA_S2_test';

load_system(model);

%% 1. LOCATE PROJECT AND BASELINE RESULTS

projectRoot = pwd;

matFile = fullfile(projectRoot,...
    'Results','T6_Simulink_Exports',...
    'SITRA_T6_All_Controllers.mat');

if ~isfile(matFile)
    error('T6 consolidated MAT file not found.');
end

load(matFile,'T6');

%% 2. CREATE A SEPARATE MODEL COPY

outputModel = fullfile(projectRoot,...
    'SITRA_S2_test_ControllerCompare.slx');

save_system(model,outputModel);
% Note: In Simulink, save_system(model, newFile) renames the active system in memory to the new model name!
model = 'SITRA_S2_test_ControllerCompare';

fprintf('\nSeparate comparison model created and active in memory: %s\n', model);

%% 3. PREPARE WORKSPACE SIGNALS

names = {'Webster','Actuated','MaxPressure'};

for k = 1:numel(names)

    name = names{k};
    S = T6.(name).S;

    assignin('base',...
        ['active_' name],S.active);

    assignin('base',...
        ['gates_' name],S.gates);

end

% Identical T6 arrival profile
Sref = T6.SITRA.S;

assignin('base','T6_arrivals',Sref.arrivals);
assignin('base','activeTS',Sref.active);

% Controller selector:
% 1 = SITRA
% 2 = Webster
% 3 = Actuated
% 4 = MaxPressure

assignin('base','SITRA_ControllerSelect',1);

%% 4. ADD BLOCKS

sub = [model '/'];

% From Workspace blocks
blocks = {
    'FW_Webster_Active'
    'FW_Actuated_Active'
    'FW_MaxPressure_Active'
    'FW_Webster_Gates'
    'FW_Actuated_Gates'
    'FW_MaxPressure_Gates'
    'FW_T6_Arrivals'
};

variables = {
    'active_Webster'
    'active_Actuated'
    'active_MaxPressure'
    'gates_Webster'
    'gates_Actuated'
    'gates_MaxPressure'
    'T6_arrivals'
};

positions = {
    [80 400 220 430]
    [80 470 220 500]
    [80 540 220 570]
    [400 400 540 430]
    [400 470 540 500]
    [400 540 540 570]
    [80 650 220 680]
};

for k = 1:numel(blocks)

    path = [model '/' blocks{k}];

    if getSimulinkBlockHandle(path) ~= -1
        delete_block(path);
    end

    add_block('simulink/Sources/From Workspace',...
        path,...
        'VariableName',variables{k},...
        'Position',positions{k});

end

% Controller selector constant
selectorBlock = [model '/Controller_Selector'];

if getSimulinkBlockHandle(selectorBlock) ~= -1
    delete_block(selectorBlock);
end

add_block('simulink/Sources/Constant',...
    selectorBlock,...
    'Value','SITRA_ControllerSelect',...
    'Position',[600 100 720 130]);

%% 5. CREATE MULTIPORT SWITCHES

activeSwitch = [model '/Active_Phase_Selector'];
gateSwitch = [model '/Gate_Selector'];

if getSimulinkBlockHandle(activeSwitch) ~= -1
    delete_block(activeSwitch);
end

if getSimulinkBlockHandle(gateSwitch) ~= -1
    delete_block(gateSwitch);
end

add_block('simulink/Signal Routing/Multiport Switch',...
    activeSwitch,...
    'Position',[850 150 1000 300]);

add_block('simulink/Signal Routing/Multiport Switch',...
    gateSwitch,...
    'Position',[850 400 1000 550]);

set_param(activeSwitch,...
    'DataPortOrder','One-based contiguous',...
    'Inputs','4');

set_param(gateSwitch,...
    'DataPortOrder','One-based contiguous',...
    'Inputs','4');

%% 6. REMOVE EXISTING INPUT CONNECTIONS

% S2 Input 1 = Demand
% S2 Input 2 = Active
% S4 Input 1 = Active
% S5 Input 1 = Switch command

destinations = {
    [model '/02_Traffic_Queue_Plant'],2
    [model '/02_Traffic_Queue_Plant'],1
    [model '/04_Switching_Logic'],1
    [model '/05_Power_Electronics'],1
};

for k = 1:size(destinations,1)

    block = destinations{k,1};
    portNumber = destinations{k,2};

    ph = get_param(block,'PortHandles');

    lineHandle = get_param(ph.Inport(portNumber),'Line');

    if lineHandle ~= -1
        delete_line(lineHandle);
    end

end

%% 7. CONNECT CONTROLLER SELECTOR

add_line(model,...
    'Controller_Selector/1',...
    'Active_Phase_Selector/1',...
    'autorouting','on');

add_line(model,...
    'Controller_Selector/1',...
    'Gate_Selector/1',...
    'autorouting','on');

% Active phase data ports
add_line(model,...
    '03_MPC_Controller/1',...
    'Active_Phase_Selector/2',...
    'autorouting','on');

add_line(model,...
    'FW_Webster_Active/1',...
    'Active_Phase_Selector/3',...
    'autorouting','on');

add_line(model,...
    'FW_Actuated_Active/1',...
    'Active_Phase_Selector/4',...
    'autorouting','on');

add_line(model,...
    'FW_MaxPressure_Active/1',...
    'Active_Phase_Selector/5',...
    'autorouting','on');

% Gate data ports
add_line(model,...
    '04_Switching_Logic/1',...
    'Gate_Selector/2',...
    'autorouting','on');

add_line(model,...
    'FW_Webster_Gates/1',...
    'Gate_Selector/3',...
    'autorouting','on');

add_line(model,...
    'FW_Actuated_Gates/1',...
    'Gate_Selector/4',...
    'autorouting','on');

add_line(model,...
    'FW_MaxPressure_Gates/1',...
    'Gate_Selector/5',...
    'autorouting','on');

%% 8. CONNECT SELECTED SIGNALS

% Active phase to S2
add_line(model,...
    'Active_Phase_Selector/1',...
    '02_Traffic_Queue_Plant/2',...
    'autorouting','on');

% Active phase to S4
add_line(model,...
    'Active_Phase_Selector/1',...
    '04_Switching_Logic/1',...
    'autorouting','on');

% Selected gates to S5
add_line(model,...
    'Gate_Selector/1',...
    '05_Power_Electronics/1',...
    'autorouting','on');

% T6 arrivals to S2
add_line(model,...
    'FW_T6_Arrivals/1',...
    '02_Traffic_Queue_Plant/1',...
    'autorouting','on');

%% 9. COMPILE MODEL

set_param(model,'StopTime','600');

fprintf('\nUpdating model diagram...\n');
set_param(model,'SimulationCommand','update');
fprintf('Model diagram updated successfully.\n');

save_system(model);
save_system(model, outputModel);

fprintf('\n====================================\n');
fprintf('FOUR-CONTROLLER INTEGRATION COMPLETE\n');
fprintf('====================================\n');

fprintf('1 = SITRA MPC\n');
fprintf('2 = Webster\n');
fprintf('3 = Actuated\n');
fprintf('4 = MaxPressure\n');

fprintf('\nComparison model saved:\n%s\n',outputModel);
close_system(model, 0);

