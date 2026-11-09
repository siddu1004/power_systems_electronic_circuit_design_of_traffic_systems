function scn = bl_scenarios(p)
%BL_SCENARIOS  Test scenarios T1-T14 for the baseline comparison.
%
%   Named T1..T14 so they do not clash with the Simulink build stages S1..S12.
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
%   T8  Congested start (queue drain), moderate demand, initial queue [25 15 10 0]
%   T9  Incident B1 (capacity -50% during 200-400s)
%   T10 Blockage B4 (spill-back clamp at q4max=15 veh, exit cap -80% during 200-350s)
%   T11 Platoon B2 (pulse 8 veh every 60s during 200-500s)
%   T12 Sensor stuck B1 (detector frozen at tStart during 200-500s)
%   T13 Sensor noise B1-B3 (sigma = 2 veh during 0-900s)
%   T14 Signal stuck off B3 (gate forced low during 300-360s)
%
%   demandFcn(t) returns the NOMINAL rate [B1 B2 B3] (veh/s).  Controllers
%   that need a demand estimate (SITRA MPC, Webster design) get this
%   nominal profile; the plant gets the realised arrivals.

split = [0.10 0.07 0.05] / 0.22;
lo = 0.15; md = 0.25; hi = 0.35; ov = 0.50;

scn = struct('id',{},'name',{},'T',{},'stochastic',{},'demandFcn',{},'totalDemand',{}, ...
             'tEvent',{},'tBaseWin',{},'q0',{},'twin',{},'events',{});

scn(end+1) = mk('T1','Low',           900, true, @(t) lo*split, lo, NaN, [NaN NaN], zeros(1,4), struct());
scn(end+1) = mk('T2','Moderate',      900, true, @(t) md*split, md, NaN, [NaN NaN], zeros(1,4), struct());
scn(end+1) = mk('T3','High',          900, true, @(t) hi*split, hi, NaN, [NaN NaN], zeros(1,4), struct());
scn(end+1) = mk('T4','Oversaturated', 900, true, @(t) ov*split, ov, NaN, [NaN NaN], zeros(1,4), struct());

% T5 Twin: Demand is lo for t < 300 and md for t >= 300. High step is replaced by moderate.
twinT5 = struct('demandFcn', @(t) split*( lo*(t<300) + md*(t>=300) ), 'q0', zeros(1,4));
scn(end+1) = mk('T5','Step demand',   900, true, ...
    @(t) split*( lo*(t<300) + hi*(t>=300 && t<600) + md*(t>=600) ), NaN, 600, [240 300], zeros(1,4), twinT5);

normalD = [0.10 0.07 0.05];
surgeD  = [0.30 0.07 0.05];
surgeF  = @(t) normalD + (surgeD-normalD)*(t>=200 && t<400);

% T6 & T7 Twin: Demand is normalD for the whole run (no surge).
twinT6 = struct('demandFcn', @(t) normalD, 'q0', zeros(1,4));
scn(end+1) = mk('T6','Part 8 surge (deterministic)', 600, false, surgeF, NaN, 400, [140 200], zeros(1,4), twinT6);

twinT7 = struct('demandFcn', @(t) normalD, 'q0', zeros(1,4));
scn(end+1) = mk('T7','Part 8 surge (Poisson)',       600, true,  surgeF, NaN, 400, [140 200], zeros(1,4), twinT7);

% T8: Congested start (queue drain)
% Moderate demand (same as T2), T = 900 s, stochastic, seeds 101 to 105.
% Initial queues q0 = [25 15 10 0] veh.
% T8 Twin: q0 = zeros(1,4), with everything else the same as T8.
twinT8 = struct('demandFcn', @(t) md*split, 'q0', zeros(1,4));
scn(end+1) = mk('T8','Congested start', 900, true, @(t) md*split, md, 0, [600 900], [25 15 10 0], twinT8);

% Common twin for T9-T14: T2 moderate background without faults/events
twinMod = struct('demandFcn', @(t) md*split, 'q0', zeros(1,4), 'events', []);

% T9: Incident B1 (capacity -50% during 200-400s)
evT9 = bl_inject('create', 'incident', 1, 200, 400, 0.5);
scn(end+1) = mk('T9', 'Incident B1', 900, true, @(t) md*split, md, 400, [140 200], zeros(1,4), twinMod, evT9);

% T10: Blockage B4 (exit cap -80% during 200-350s, q4max = 15 veh spill-back clamp)
evT10 = bl_inject('create', 'blockage', 4, 200, 350, 0.8, struct('q4max', 15));
scn(end+1) = mk('T10', 'Blockage B4 (spill-back)', 900, true, @(t) md*split, md, 350, [140 200], zeros(1,4), twinMod, evT10);

% T11: Platoon B2 (pulse 8 veh every 60s during 200-500s)
evT11 = bl_inject('create', 'platoon', 2, 200, 500, 8, struct('period', 60));
scn(end+1) = mk('T11', 'Platoon B2', 900, true, @(t) md*split, md, 500, [140 200], zeros(1,4), twinMod, evT11);

% T12: Sensor stuck B1 (detector frozen at tStart during 200-500s)
evT12 = bl_inject('create', 'sensor_stuck', 1, 200, 500, 0);
scn(end+1) = mk('T12', 'Sensor stuck B1', 900, true, @(t) md*split, md, 500, [140 200], zeros(1,4), twinMod, evT12);

% T13: Sensor noise B1-B3 (sigma = 2 veh during 0-900s)
evT13 = bl_inject('create', 'sensor_noise', 1:3, 0, 900, 2);
scn(end+1) = mk('T13', 'Sensor noise B1-B3', 900, true, @(t) md*split, md, 0, [NaN NaN], zeros(1,4), twinMod, evT13);

% T14: Signal stuck off B3 (gate forced low during 300-360s)
evT14 = bl_inject('create', 'signal_stuck_off', 3, 300, 360, 0);
scn(end+1) = mk('T14', 'Signal stuck off B3', 900, true, @(t) md*split, md, 360, [240 300], zeros(1,4), twinMod, evT14);

end

function s = mk(id,name,T,stoch,f,tot,tEvent,tBaseWin,q0,twin,events)
s.id = id; s.name = name; s.T = T; s.stochastic = stoch;
s.demandFcn = f; s.totalDemand = tot;
if nargin < 7 || isempty(tEvent), tEvent = NaN; end
if nargin < 8 || isempty(tBaseWin), tBaseWin = [NaN NaN]; end
if nargin < 9 || isempty(q0), q0 = zeros(1,4); end
if nargin < 10 || isempty(twin), twin = struct(); end
if nargin < 11 || isempty(events), events = []; end
s.tEvent = tEvent;
s.tBaseWin = tBaseWin;
s.q0 = q0;
s.twin = twin;
s.events = events;
end
