% init_SITRA_workspace.m
% Run this script in MATLAB to load all baseline controller signals
% and simulation parameters into the base workspace.

clc;
pDir = fileparts(mfilename('fullpath'));
cd(pDir);

fprintf('Initializing SITRA Base Workspace...\n');

expDir = fullfile(pDir, 'Results', 'T6_Simulink_Exports');
assert(exist(expDir, 'dir') == 7, 'Exports directory not found: %s', expDir);

% 1. Load Reference MPC arrivals & active
sref = load(fullfile(expDir, 'SITRA_T6.mat'));
if isfield(sref, 'S'), sref = sref.S; end
assignin('base', 'T6_arrivals', sref.arrivals);

% 2. Load Webster, Actuated, MaxPressure
cNames = {'Webster', 'Actuated', 'MaxPressure'};
for ci = 1:numel(cNames)
    cn = cNames{ci};
    mf = fullfile(expDir, [cn '_T6.mat']);
    s = load(mf);
    if isfield(s, 'S'), s = s.S; end
    assignin('base', ['active_' cn], s.active);
    assignin('base', ['gates_' cn], s.gates);
    fprintf('  Loaded %s active and gate signals.\n', cn);
end

% 3. Set Controller Selector (Default: 1 = SITRA MPC)
% Options: 1=MPC, 2=Webster, 3=Actuated, 4=MaxPressure
if ~evalin('base', 'exist(''SITRA_ControllerSelect'', ''var'')')
    assignin('base', 'SITRA_ControllerSelect', 1);
end
fprintf('  SITRA_ControllerSelect = %d\n', evalin('base', 'SITRA_ControllerSelect'));

% 4. Electrical parameters
assignin('base', 'Ceq', 1);
assignin('base', 'kq', 1);
assignin('base', 'kI', 1);
assignin('base', 'traffic_dt', 1);
assignin('base', 'branchCapacity', [0.65; 0.35; 0.25; 0.45]);

fprintf('\n[SUCCESS] All workspace variables initialized successfully!\n');
fprintf('You can now open and run SITRA_S2_test_ControllerCompare.slx directly.\n');

