clc;

model = 'SITRA_S2_test_ControllerCompare';
load_system(model);

% Load signals
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

ctrls = {'SITRA MPC','Webster','Actuated','MaxPressure'};
simResults = struct();

fprintf('\n==================================================\n');
fprintf('TESTING SIMULINK EXECUTION FOR ALL 4 CONTROLLERS\n');
fprintf('==================================================\n');

for c = 1:4
    fprintf('\nSimulating Controller %d: %s...\n', c, ctrls{c});
    assignin('base','SITRA_ControllerSelect',c);
    
    tic;
    out = sim(model, 'StopTime', '600');
    elapsed = toc;
    
    fprintf('  Simulation finished in %.2f s.\n', elapsed);
    
    % Check logged variables
    if exist('qHist','var')
        fprintf('  Logged qHist: %d x %d\n', size(qHist,1), size(qHist,2));
    end
end

close_system(model, 0);
fprintf('\nALL 4 CONTROLLER SIMULATIONS COMPLETED SUCCESSFULLY.\n');

