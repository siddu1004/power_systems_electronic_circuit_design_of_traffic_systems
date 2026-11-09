function p = bl_config()
%BL_CONFIG  Shared settings for the SITRA baseline-controller comparison.
%
%   Every controller in the comparison reads THIS struct, so all of them
%   see the same time step, clearance, initial queues and random seeds.
%   Nothing here changes the frozen S1-S4 / Part 4-9 files.
%
%   Provenance: capacities come from createNetwork.m (ASSUMED placeholders).
%   Signal-timing values below are design choices for the comparison,
%   not field measurements.

% --- Simulation (same as frozen Part 8) ---------------------------------
p.dt = 1.0;                 % [s] traffic step, identical to Part 8
p.q0 = zeros(1,4);          % initial queues [B1 B2 B3 B4] for every run

% --- Common signal constraint --------------------------------------------
p.yellow = 3;               % [s] clearance between phases (Part 8 value)

% --- SITRA's own controller (frozen Part 8 MPC + S4 gate mapping) -------
% Copied verbatim from part8_mpc_controller.m, section 4. Do not tune.
p.mpc.yellow           = 3;
p.mpc.cycleLength      = 63;
p.mpc.minGreen         = 12;
p.mpc.maxGreen         = 30;
p.mpc.predictionCycles = 3;
p.mpc.wTotal           = 1.0;
p.mpc.wB1              = 0.5;
p.mpc.wDelta           = 0.02;

% --- Webster fixed-time ---------------------------------------------------
p.web.minGreen   = 10;      % [s] floor applied to each Webster split
p.web.Cmin       = 30;      % [s] cycle bounds
p.web.Cmax       = 120;
p.web.startLost  = 0;       % [s] start-up lost time per phase (model has none)
p.web.designFlow = 'mean';  % 'mean' or 'peak' of the scenario demand profile

% --- Vehicle-actuated -----------------------------------------------------
p.act.minGreen  = 10;       % [s]
p.act.maxGreen  = 40;       % [s]
p.act.passage   = 3;        % [s] unit extension / allowed gap
p.act.queueOn   = 0.5;      % [veh] queue that still occupies the stop-line detector

% --- Max-pressure (optional baseline) ------------------------------------
p.mp.slot     = 10;         % [s] decision interval = minimum green
p.mp.queueOn  = 0.5;        % [veh] below this every approach counts as empty

% --- Random arrivals -------------------------------------------------------
% Seeds are fixed, and arrivals are generated ONCE per (scenario, seed)
% and then fed to every controller.
p.seeds = 101:105;

% --- Controllers in the comparison (order = table/plot order) -----------
p.controllers = {'SITRA','Webster','Actuated','MaxPressure'};

% --- Output ---------------------------------------------------------------
p.showFigures = true;       % false = render off-screen (batch runs)
end
