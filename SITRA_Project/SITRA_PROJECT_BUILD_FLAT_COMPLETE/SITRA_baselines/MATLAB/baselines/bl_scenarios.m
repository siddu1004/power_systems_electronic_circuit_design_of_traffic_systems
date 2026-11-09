function scn = bl_scenarios(p)
%BL_SCENARIOS  Test scenarios T1-T7 for the baseline comparison.
%
%   Named T1..T7 so they do not clash with the Simulink build stages S1..S12.
%
%   Demand is split across B1:B2:B3 in the Part 8 "normal" ratio
%   0.10 : 0.07 : 0.05, and scaled to a total entering flow.  The
%   downstream bottleneck B4 = 0.45 veh/s, so total/0.45 is the B4
%   degree of saturation x.
%
%   T1  low            total 0.15 veh/s  (x = 0.33)   900 s, Poisson
%   T2  moderate       total 0.25 veh/s  (x = 0.56)   900 s, Poisson
%   T3  high           total 0.35 veh/s  (x = 0.78)   900 s, Poisson
%   T4  oversaturated  total 0.50 veh/s  (x = 1.11)   900 s, Poisson
%   T5  step demand    low 0-300 s, high 300-600 s, moderate 600-900 s
%   T6  Part 8 B1 surge, deterministic fluid arrivals (reproduces qHist)
%   T7  Part 8 B1 surge with Poisson arrivals
%
%   demandFcn(t) returns the NOMINAL rate [B1 B2 B3] (veh/s).  Controllers
%   that need a demand estimate (SITRA MPC, Webster design) get this
%   nominal profile; the plant gets the realised arrivals.

split = [0.10 0.07 0.05] / 0.22;
lo = 0.15; md = 0.25; hi = 0.35; ov = 0.50;

scn = struct('id',{},'name',{},'T',{},'stochastic',{},'demandFcn',{},'totalDemand',{});

scn(end+1) = mk('T1','Low',           900, true, @(t) lo*split, lo);
scn(end+1) = mk('T2','Moderate',      900, true, @(t) md*split, md);
scn(end+1) = mk('T3','High',          900, true, @(t) hi*split, hi);
scn(end+1) = mk('T4','Oversaturated', 900, true, @(t) ov*split, ov);
scn(end+1) = mk('T5','Step demand',   900, true, ...
    @(t) split*( lo*(t<300) + hi*(t>=300 && t<600) + md*(t>=600) ), NaN);

normalD = [0.10 0.07 0.05];
surgeD  = [0.30 0.07 0.05];
surgeF  = @(t) normalD + (surgeD-normalD)*(t>=200 && t<400);
scn(end+1) = mk('T6','Part 8 surge (deterministic)', 600, false, surgeF, NaN);
scn(end+1) = mk('T7','Part 8 surge (Poisson)',       600, true,  surgeF, NaN);
end

function s = mk(id,name,T,stoch,f,tot)
s.id = id; s.name = name; s.T = T; s.stochastic = stoch;
s.demandFcn = f; s.totalDemand = tot;
end
