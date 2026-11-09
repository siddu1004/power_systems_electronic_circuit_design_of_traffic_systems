function PE = simulate_power_electronic_circuit(activeHistory, demandProfile, tVec, net, dt)
%% SIMULATE_POWER_ELECTRONIC_CIRCUIT
% Simulates the equivalent power-electronic circuit of the SITRA traffic network.
%
% CIRCUIT - TRAFFIC ISOMORPHISM:
%   - Traffic Queue q_i [veh]        <-> Capacitor Voltage V_Ci [V] (C = 1.0 F)
%   - Traffic Flow Rate [veh/s]       <-> Electrical Current I [A] (1 A = 1 veh/s)
%   - Road Approach Link B1..B3       <-> Storage Capacitors C1..C3 with Chokes L1..L3
%   - Road Saturation Capacity        <-> Semiconductor Max Current Rating I_sat [A]
%   - Traffic Signal Phases           <-> Semiconductor Switches S1..S3 (MOSFET/IGBT)
%   - Signal Clearance (Yellow)       <-> Gate Driver Dead-Time (All Switches OFF)
%   - SITRA Junction Intersection     <-> Switched Common DC Bus Summing Node
%   - Downstream Bottleneck B4        <-> Downstream Capacitor C4 + Regulated Current Sink
%   - Non-negative Queue Constraint   <-> Clamping Diodes D1..D4 (Preventing Reverse Voltage)
%
% INPUTS:
%   activeHistory : [N x 1] active phase history (0=clearance, 1=B1, 2=B2, 3=B3)
%   demandProfile : [N x 3] demand current profile [I_in1, I_in2, I_in3] in A
%   tVec          : [N x 1] time vector in seconds
%   net           : network struct from createNetwork() (optional, default loaded)
%   dt            : simulation time step in seconds (default 1.0 s)
%
% OUTPUT:
%   PE struct containing electrical waveforms:
%     PE.tVec          : time vector [s]
%     PE.Vc            : [N x 4] capacitor voltages [V] (corresponds to q_i)
%     PE.I_in          : [N x 4] input branch currents [A] (corresponds to arrivals)
%     PE.I_dep         : [N x 4] departure branch currents [A] (corresponds to departures)
%     PE.I_bus         : [N x 1] SITRA junction DC bus current [A]
%     PE.gates         : [N x 3] semiconductor gate drive signals [g1, g2, g3]
%     PE.deadtimeState : [N x 1] logical dead-time indicator (1 during clearance)
%     PE.energy        : [N x 4] stored capacitive energy [Joules] E = 0.5 * C * V^2
%     PE.totalEnergy   : [N x 1] total network stored electrostatic energy [J]
%     PE.powerLoss     : [N x 1] conduction power loss in semiconductor switches [W]
%     PE.residual      : [N x 4] Kirchhoff Current Law (KCL) conservation residual [A]
%     PE.params        : circuit component parameters

if nargin < 4 || isempty(net)
    net = createNetwork();
end
if nargin < 5 || isempty(dt)
    dt = 1.0;
end

N = numel(tVec);

%% 1. Circuit Component Parameters
C = [1.0, 1.0, 1.0, 1.0];             % Capacitances [F] (1 F -> 1 V per Coulomb/vehicle)
L = [0.05, 0.05, 0.05, 0.05];         % Inertia smoothing inductances [H]
R_on = 0.01;                          % Switch on-state resistance [Ohm]
R_esr = 0.005;                        % Capacitor ESR [Ohm]
I_sat = [net.capacity(1), net.capacity(2), net.capacity(3), net.capacity(4)]; % [0.65, 0.35, 0.25, 0.45] A

%% 2. Pre-allocate Electrical Waveform Matrices
Vc = zeros(N, 4);                     % Capacitor voltages [V] (Approach B1..B3, Exit B4)
I_in = zeros(N, 4);                   % Input currents to capacitors [A]
I_dep = zeros(N, 4);                  % Discharging currents from capacitors [A]
I_bus = zeros(N, 1);                  % DC junction bus current [A]
gates = zeros(N, 3);                  % Gate driving pulses [g1, g2, g3]
deadtimeState = zeros(N, 1);          % Dead-time status
energy = zeros(N, 4);                 % Stored energy in each branch [J]
powerLoss = zeros(N, 1);              % Semiconductor conduction loss [W]
residual = zeros(N, 4);               % KCL residual: I_in - I_dep - C*dVc/dt

% Initial state: all capacitor voltages start at zero
vc_current = zeros(1, 4);

%% 3. Numerical Circuit Simulation Loop (KCL + Solid-State Switching)
for k = 1:N
    t = tVec(k);
    act = activeHistory(k);
    
    % --- Block 5: Gate Driver & Dead-Time Unit ---
    % Generate gate pulses with hardware mutual exclusion & clearance dead-time
    g = zeros(1, 3);
    if act >= 1 && act <= 3
        g(act) = 1.0;
        deadtimeState(k) = 0;
    else
        % act == 0 is clearance/yellow interval -> all gate pulses zero (Dead-Time)
        deadtimeState(k) = 1;
    end
    gates(k, :) = g;
    
    % Verify hardware interlock: at most one switch ON
    assert(sum(g) <= 1, 'Protection Fault: Shoot-through detected! Multiple switches active.');
    
    % --- Block 1: Input Current Sources ---
    % Incoming traffic demand acts as controlled current sources feeding C1..C3
    i_arr = zeros(1, 4);
    i_arr(1:3) = demandProfile(k, 1:3);
    
    % --- Block 3: Semiconductor Switching Matrix (Switches S1..S3) ---
    % When switch S_b is ON (g(b)=1), current flows from C_b to SITRA junction bus.
    % Flow is clamped by road saturation capacity I_sat(b) and available charge V_c/dt.
    % Clamping diode ensures V_c >= 0 (no reverse discharge).
    i_dep = zeros(1, 4);
    for b = 1:3
        if g(b) > 0.5
            % Switch S_b is conducting
            i_dep(b) = min(I_sat(b), vc_current(b) / dt);
        else
            % Switch S_b is OFF (open circuit)
            i_dep(b) = 0.0;
        end
    end
    
    % --- SITRA Junction Common DC Bus ---
    % Sum of currents leaving conducting approach switches enters B4 link
    i_bus_instant = sum(i_dep(1:3));
    I_bus(k) = i_bus_instant;
    i_arr(4) = i_bus_instant;
    
    % --- Block 4: Downstream DC-DC Bottleneck Sink (Goldwins Exit) ---
    % Link B4 discharges into the Goldwins bottleneck sink, limited to 0.45 A
    i_dep(4) = min(I_sat(4), vc_current(4) / dt);
    
    % --- Block 2: Capacitor State Integration (KCL: dVc/dt = (I_arr - I_dep)/C) ---
    % Clamping diode ensures Vc >= 0 (charge non-negativity)
    vc_next = max(zeros(1, 4), vc_current + (dt ./ C) .* (i_arr - i_dep));
    
    % --- KCL Conservation Residual ---
    % KCL: I_in - I_dep - C * (Vc_next - Vc)/dt = 0
    kcl_res = i_arr - i_dep - (C ./ dt) .* (vc_next - vc_current);
    
    % --- Block 8: Conduction Losses & Energy Calculation ---
    % Conduction loss: P = I_dep^2 * R_on
    p_loss = sum(i_dep(1:3).^2) * R_on;
    
    % Record step values
    Vc(k, :) = vc_current;
    I_in(k, :) = i_arr;
    I_dep(k, :) = i_dep;
    residual(k, :) = kcl_res;
    energy(k, :) = 0.5 .* C .* (vc_current.^2);
    powerLoss(k) = p_loss;
    
    % Update state for next step
    vc_current = vc_next;
end

%% 4. Pack Results
PE.tVec = tVec(:);
PE.Vc = Vc;
PE.I_in = I_in;
PE.I_dep = I_dep;
PE.I_bus = I_bus;
PE.gates = gates;
PE.deadtimeState = deadtimeState;
PE.energy = energy;
PE.totalEnergy = sum(energy, 2);
PE.powerLoss = powerLoss;
PE.totalEnergyDissipated = cumsum(powerLoss) * dt;
PE.residual = residual;
PE.params.C = C;
PE.params.L = L;
PE.params.R_on = R_on;
PE.params.R_esr = R_esr;
PE.params.I_sat = I_sat;

end
