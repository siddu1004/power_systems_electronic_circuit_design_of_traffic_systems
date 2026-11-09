function out = sim_layerA_circuit(arrivals, gates, tVec, p)
%% SIM_LAYERA_CIRCUIT
% Simulates Layer A: The physical/electrical normalized equivalent circuit of SITRA.
% Implements the exact sample-and-hold controlled-current discharge dynamics
% to eliminate the "discrete-time trap" and preserve machine-precision equivalence.
%
% Inputs:
%   arrivals : [N x 3] Arrival current matrix [I_in1, I_in2, I_in3] in A (1 A = 1 veh/s)
%   gates    : [N x 3] Semiconductor gate control signals [g1, g2, g3] in {0, 1}
%   tVec     : [N x 1] Time vector [s]
%   p        : Parameter struct from params_electrical() (optional)
%
% Outputs:
%   out.tVec         : [N x 1] Time vector
%   out.v_C          : [N x 4] Capacitor voltages [V] (V_C1..V_C4)
%   out.I_in         : [N x 4] Inflow branch currents [A]
%   out.I_dep        : [N x 4] Departure branch currents [A]
%   out.I_bus        : [N x 1] Switched DC junction bus current [A]
%   out.gates        : [N x 3] Validated gate signals
%   out.chargeArr    : Total external charge entered [Coulombs]
%   out.chargeExit   : Total charge exited through B4 [Coulombs]
%   out.chargeStored : Total charge stored in C1..C4 at end [Coulombs]
%   out.chargeError  : Absolute charge conservation error [Coulombs]
%   out.gateOverlapCount : Number of mutual exclusion violations detected

if nargin < 4 || isempty(p)
    p = params_electrical();
end

C = p.normalized.C;       % [1.0 1.0 1.0 1.0] F
cap = p.normalized.cap;   % [0.65 0.35 0.25 0.45] A
dt = p.normalized.dt;     % 1.0 s
N = numel(tVec);

v_C   = zeros(N, 4);
I_in  = zeros(N, 4);
I_dep = zeros(N, 4);
I_bus = zeros(N, 1);

v_current = reshape(p.normalized.q0, 1, 4);
gateViolations = 0;

for k = 1:N
    % 1. Record state at sample instant k
    v_C(k, :) = v_current;
    
    % 2. Gate Mutual-Exclusion Monitor
    g = gates(k, 1:3);
    if sum(g) > 1.0 + 1e-9
        gateViolations = gateViolations + 1;
    end
    
    % 3. External Arrivals into Approach Capacitors C1..C3
    i_in_step = zeros(1, 4);
    i_in_step(1:3) = arrivals(k, 1:3);
    
    % 4. Sample-and-Hold Departure Currents from C1..C3
    % Current is calculated from sampled capacitor voltage at start of step
    % and held constant for the 1.0 s interval:
    i_dep_step = zeros(1, 4);
    for b = 1:3
        if g(b) > 0.5
            i_dep_step(b) = min(cap(b), v_current(b) / dt);
        else
            i_dep_step(b) = 0.0;
        end
    end
    
    % 5. Kirchhoff Current Law (KCL) Junction Bus Summing Node
    % The active approach discharge current enters Downstream Capacitor C4:
    i_bus_current = sum(i_dep_step(1:3));
    I_bus(k) = i_bus_current;
    i_in_step(4) = i_bus_current;
    
    % 6. Downstream Bottleneck Exit Sink (Goldwins)
    % Departure from C4 calculated from sampled C4 voltage at start of step:
    i_dep_step(4) = min(cap(4), v_current(4) / dt);
    
    % 7. Capacitor Charge Integration
    % dV_C = (I_in - I_dep) * dt / C
    % Because i_dep(b) <= v_current(b)/dt, v_next >= 0 unconditionally!
    v_next = v_current + (dt ./ C) .* (i_in_step - i_dep_step);
    
    % Store logged currents
    I_in(k, :) = i_in_step;
    I_dep(k, :) = i_dep_step;
    
    % Advance state
    v_current = v_next;
end

%% 8. Global Charge Conservation (Charge Balance Check)
total_in = sum(I_in(:, 1:3), 'all') * dt;
total_exit = sum(I_dep(:, 4)) * dt;
total_stored = sum(C .* v_current);
charge_error = abs(total_in - total_exit - total_stored);

%% Pack Output Struct
out.tVec = tVec(:);
out.v_C = v_C;
out.I_in = I_in;
out.I_dep = I_dep;
out.I_bus = I_bus;
out.gates = gates;
out.chargeArr = total_in;
out.chargeExit = total_exit;
out.chargeStored = total_stored;
out.chargeError = charge_error;
out.gateOverlapCount = gateViolations;

end
