% RUN_POWER_SIMULATION
% One-click runner for SITRA Physical Power Simulation.
% Runs 10 seconds of high-frequency power electronics (500 AC cycles, 100,000 PWM steps)
% in ~30 seconds and pops up all live results.

clc;
fprintf('=========================================================\n');
fprintf('  STARTING SITRA PHYSICAL POWER SIMULATION (10.0 s)\n');
fprintf('=========================================================\n');

% 1. Load model if not loaded
mdl = 'SITRA_S5_Physical';
if ~bdIsLoaded(mdl)
    load_system(mdl);
end

% 2. Ensure Power_Path is active (uncommented)
set_param([mdl '/Power_Path'], 'Commented', 'off');

% 3. Set Stop time to 10.0 s
set_param(mdl, 'StopTime', '10.0');

% 4. Run simulation
fprintf('Simulating 500 AC mains cycles & 100,000 PWM periods...\n');
tic;
sim(mdl);
elapsed = toc;

fprintf('\n===> Simulation finished in %.2f seconds!\n', elapsed);
fprintf('Displaying all result figures on screen...\n');
