function res = sim_fault_injection(faultType, arrivals, gates, tVec, p)
%% SIM_FAULT_INJECTION
% Stage 5: Injects hardware faults into Layer B / Layer A and verifies protection interlocks.
% Supported faultTypes:
%   1. 'shoot_through'       : Multiple gates commanded active simultaneously
%   2. 'switch_stuck_open'   : Branch 1 switch fails open-circuit (no discharge)
%   3. 'switch_stuck_closed' : Branch 2 switch shorts closed (current when gate==0)
%   4. 'supply_sag'          : 24V DC bus sags to 10V (undervoltage trip)
%   5. 'overcurrent'         : Branch load short-circuit (I_load > 2.0 A)

if nargin < 5 || isempty(p)
    p = params_electrical();
end

dt = p.normalized.dt;
N = numel(tVec);
C = p.normalized.C;
cap = p.normalized.cap;

faultLog = {};
tripped = false;
safeStateActive = false;

v_C = zeros(N, 4);
I_in = zeros(N, 4);
I_dep = zeros(N, 4);
V_dc = zeros(N, 1);
I_branch = zeros(N, 3);
gatesEffective = zeros(N, 3);

v_curr = p.normalized.q0;
v_dc_curr = p.layerB.V_dc_nominal;

for k = 1:N
    t = tVec(k);
    v_C(k, :) = v_curr;
    g = gates(k, 1:3);
    
    % --- FAULT INJECTIONS ---
    switch lower(faultType)
        case 'shoot_through'
            % Inject conflicting simultaneous green at t = 250s
            if t >= 250 && t < 280
                g = [1, 1, 0]; % Both B1 and B2 commanded ON!
            end
            
            % Protection: Cross-conduction Interlock
            if sum(g) > 1.0
                faultLog{end+1} = sprintf('t=%.1fs: Shoot-through attempt detected! Interlock forcing safe all-red clearance.', t); %#ok<AGROW>
                g = [0, 0, 0]; % Interlock clamps gates to 0 (all-red)
            end
            
        case 'switch_stuck_open'
            % Branch 1 switch fails open from t = 200s onward
            if t >= 200
                if g(1) == 1
                    faultLog{end+1} = sprintf('t=%.1fs: Switch S1 stuck open! Gate is ON but no discharge occurs.', t); %#ok<AGROW>
                end
                g(1) = 0; % Switch fails to conduct physically
            end
            
        case 'switch_stuck_closed'
            % Branch 2 switch shorts closed at t = 180s
            if t >= 180
                faultLog{end+1} = sprintf('t=%.1fs: Switch S2 short-circuit detected! Tripping main contactor to safe all-red.', t); %#ok<AGROW>
                tripped = true;
                safeStateActive = true;
            end
            if safeStateActive
                g = [0, 0, 0]; % Safe all-red shutdown
            end
            
        case 'supply_sag'
            % DC power supply drops from 24V to 10V at t = 220s
            if t >= 220
                v_dc_curr = 10.0; % Severe voltage sag
            end
            
            % Protection: Undervoltage detection (V_dc < 18 V)
            if v_dc_curr < p.layerB.V_undervoltage_trip
                faultLog{end+1} = sprintf('t=%.1fs: DC Undervoltage (%.1f V < 18.0 V)! Initiating emergency fail-safe all-red.', t, v_dc_curr); %#ok<AGROW>
                tripped = true;
                safeStateActive = true;
                g = [0, 0, 0]; % Safe state
            end
            
        case 'overcurrent'
            % Short circuit across branch 3 signal lamp at t = 160s
            if t >= 160 && g(3) == 1
                faultCurrent = 5.0; % 5 A short circuit
                faultLog{end+1} = sprintf('t=%.1fs: Overcurrent fault (%.1f A > 2.0 A)! High-speed electronic fuse tripped.', t, faultCurrent); %#ok<AGROW>
                tripped = true;
                safeStateActive = true;
                g = [0, 0, 0];
            end
    end
    
    gatesEffective(k, :) = g;
    V_dc(k) = v_dc_curr;
    
    % Layer A circuit response to effective physical switch states
    i_in_step = zeros(1, 4);
    i_in_step(1:3) = arrivals(k, 1:3);
    
    i_dep_step = zeros(1, 4);
    for b = 1:3
        if g(b) > 0.5
            i_dep_step(b) = min(cap(b), v_curr(b) / dt);
        end
    end
    
    i_bus = sum(i_dep_step(1:3));
    i_in_step(4) = i_bus;
    i_dep_step(4) = min(cap(4), v_curr(4) / dt);
    
    v_next = v_curr + (dt ./ C) .* (i_in_step - i_dep_step);
    
    I_in(k, :) = i_in_step;
    I_dep(k, :) = i_dep_step;
    v_curr = v_next;
end

res.faultType = faultType;
res.faultLog = unique(faultLog);
res.numFaultEvents = numel(faultLog);
res.tripped = tripped;
res.safeStateActive = safeStateActive;
res.v_C = v_C;
res.I_in = I_in;
res.I_dep = I_dep;
res.V_dc = V_dc;
res.gatesEffective = gatesEffective;
res.maxQueueB1 = max(v_C(:, 1));
res.finalTotalQueue = sum(v_curr);

end
