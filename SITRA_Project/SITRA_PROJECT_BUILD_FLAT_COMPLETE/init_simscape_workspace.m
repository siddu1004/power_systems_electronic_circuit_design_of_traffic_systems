%% init_simscape_workspace.m
% Initializes From Workspace variables for SITRA_Simscape_Hardware.slx
% Ensures model can simulate out-of-the-box by any user or test script.

thisDir = fileparts(mfilename('fullpath'));
if isempty(thisDir), thisDir = pwd; end
addpath(genpath(fullfile(thisDir, 'SITRA_baselines')));
addpath(genpath(fullfile(thisDir, 'S5_electrical')));

p = bl_config();
net = createNetwork();
scn = bl_scenarios(p);
A_t6 = bl_make_arrivals(scn(6), p, 0);
R_t6 = bl_simulate('SITRA', A_t6, p, net);
S_t6 = bl_export_for_simulink(R_t6);

assignin('base', 'sim_arrivals', S_t6.arrivals);
assignin('base', 'sim_gates', S_t6.gates);
assignin('base', 'refQ', S_t6.qRef);
assignin('base', 'refActive', S_t6.active);
