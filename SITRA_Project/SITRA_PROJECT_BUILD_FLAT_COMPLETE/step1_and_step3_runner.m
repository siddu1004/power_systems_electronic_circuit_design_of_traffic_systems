clc;

%% STEP 1 — SITRA T6 CONTROLLER EXPORT
root = pwd;

baselineDir = fullfile(root,'MATLAB','baselines');
if ~isfolder(baselineDir)
    baselineDir = fullfile(root,'baselines');
end

addpath(root);
addpath(genpath(baselineDir));

p = bl_config();
net = createNetwork();
scn = bl_scenarios(p);

idx = find(strcmp({scn.id},'T6'),1);
if isempty(idx)
    error('T6 scenario not found.');
end

A = bl_make_arrivals(scn(idx),p,0);
controllers = {'SITRA','Webster','Actuated','MaxPressure'};

outDir = fullfile(root,'Results','T6_Simulink_Exports');
if ~isfolder(outDir)
    mkdir(outDir);
end

T6 = struct();

fprintf('\n========================================\n');
fprintf('SITRA T6 CONTROLLER EXPORT\n');
fprintf('========================================\n');

for k = 1:numel(controllers)
    name = controllers{k};
    fprintf('\nRunning %s...\n',name);

    R = bl_simulate(name,A,p,net);
    S = bl_export_for_simulink(R);

    T6.(name).R = R;
    T6.(name).S = S;

    save(fullfile(outDir,[name '_T6.mat']),'-struct','S');

    gateValid = all(sum(S.gates(:,2:4),2)<=1);
    queueValid = all(isfinite(S.qRef(:,2:5)),'all') && ...
                 all(S.qRef(:,2:5)>=-1e-10,'all');
    residual = max(abs(R.residual(:)));

    fprintf('Samples: %d\n',size(S.active,1));
    fprintf('Active dimensions: %d\n',size(S.active,2));
    fprintf('Gate dimensions: %d\n',size(S.gates,2)-1);
    fprintf('Arrival dimensions: %d\n',size(S.arrivals,2)-1);
    fprintf('Queue dimensions: %d\n',size(S.qRef,2)-1);
    fprintf('Maximum conservation residual: %.3e\n',residual);

    if gateValid && queueValid && residual<1e-9
        fprintf('%s EXPORT VALIDATION = PASS\n',name);
    else
        error('%s export validation failed.',name);
    end
end

save(fullfile(outDir,'SITRA_T6_All_Controllers.mat'),'T6','p','A');

fprintf('\n========================================\n');
fprintf('ALL FOUR CONTROLLERS EXPORTED.\n');
fprintf('Output directory:\n%s\n',outDir);
fprintf('========================================\n');

%% STEP 3 — INSPECT ACTUAL SIMULINK PORT INTERFACES
model = 'SITRA_S2_test';
load_system(model);

subsystems = {
    '02_Traffic_Queue_Plant'
    '03_MPC_Controller'
    '04_Switching_Logic'
    '05_Power_Electronics'
    '06_Measurement'
    '07_Protection_Interlock'
    '08_Hardware_Interface'
    '09_Output_Validation'
};

fprintf('\n===== SITRA INTERFACE INSPECTION =====\n');

for k = 1:numel(subsystems)
    path = [model '/' subsystems{k}];
    ph = get_param(path,'PortHandles');

    fprintf('\n%s\n',subsystems{k});
    fprintf('Inputs: %d | Outputs: %d\n',...
        numel(ph.Inport),numel(ph.Outport));

    for j = 1:numel(ph.Inport)
        fprintf('  Input %d\n',j);
    end

    for j = 1:numel(ph.Outport)
        fprintf('  Output %d\n',j);
    end
end

close_system(model, 0);

