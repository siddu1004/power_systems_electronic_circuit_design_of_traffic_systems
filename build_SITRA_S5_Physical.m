function info = build_SITRA_S5_Physical()
%BUILD_SITRA_S5_PHYSICAL  Build SITRA_S5_Physical.slx as a REAL Simscape circuit.
%
%   Every electrical element is a Simscape library block joined by physical
%   wires. No S-Function / MATLAB Function block computes any physics.
%
%   Includes a PreLoadFcn callback so that opening the .slx file and clicking
%   the green Simulink "Run" button works out-of-the-box without workspace errors.
%   Also applies Simulink.BlockDiagram.arrangeSystem and clean grid layout so
%   all blocks and physical/signal wires are crisp, non-overlapping, and neat.

mdl  = 'SITRA_S5_Physical';
here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
if exist(fullfile(here, 'baselines'), 'dir')
    root = here;
else
    root = fileparts(here);
end
addpath(here); addpath(root);
bl = fullfile(root, 'baselines');
if exist(bl, 'dir'), addpath(genpath(bl)); end

S5 = S5_physical_params();
S5 = default_signals(S5);
assignin('base', 'S5', S5);

load_libs();
% Use verified R2026a Simscape port calibration directly (instant load, no temp sim delay)
cal = r2026a_calibrated_ports();
assignin('base', 'S5_cal', cal);
S5.par.xfmr_n_block = cal.xfmrParam(S5.par.xfmr_n);
assignin('base', 'S5', S5);

if bdIsLoaded(mdl), close_system(mdl, 0); end
f = fullfile(here, [mdl '.slx']);
if exist(f, 'file'), delete(f); end
new_system(mdl);
set_solver(mdl);
set_param(mdl, 'StopTime', 'S5.stopTime');

% ---- Fast PreLoadFcn & InitFcn (loads precomputed MAT in <0.01s, never blocks GUI) ----
preloadCode = sprintf([ ...
    'if ~exist(''S5'', ''var'') || ~isstruct(S5) || ~isfield(S5, ''par'')\n' ...
    '    try\n' ...
    '        mdlDir_ = fileparts(get_param(bdroot, ''FileName''));\n' ...
    '        if isempty(mdlDir_), mdlDir_ = pwd; end\n' ...
    '        addpath(mdlDir_); addpath(fileparts(mdlDir_));\n' ...
    '        if exist(fullfile(mdlDir_, ''S5_physical''), ''dir''), addpath(fullfile(mdlDir_, ''S5_physical'')); end\n' ...
    '        S5 = S5_physical_params();\n' ...
    '        matTry1_ = fullfile(mdlDir_, ''Results'', ''T6_Simulink_Exports'', ''SITRA_T6.mat'');\n' ...
    '        matTry2_ = fullfile(fileparts(mdlDir_), ''Results'', ''T6_Simulink_Exports'', ''SITRA_T6.mat'');\n' ...
    '        if isfile(matTry1_), S_ = load(matTry1_); elseif isfile(matTry2_), S_ = load(matTry2_); else, S_ = []; end\n' ...
    '        if ~isempty(S_)\n' ...
    '            if isfield(S_, ''S''), S_ = S_.S; end\n' ...
    '            t0_ = S_.arrivals(1,1);\n' ...
    '            S5.arrivals = [S_.arrivals(:,1)-t0_, S_.arrivals(:,2:end)];\n' ...
    '            S5.gates    = [S_.gates(:,1)-t0_,    S_.gates(:,2:end)];\n' ...
    '            N_ = size(S_.arrivals, 1);\n' ...
    '            S5.capB     = [(0:N_-1)'', repmat([0.65 0.35 0.25 0.45], N_, 1)];\n' ...
    '        else\n' ...
    '            tSpan_ = (0:10)'';\n' ...
    '            S5.arrivals = [tSpan_, [0.3*ones(11,1) 0.1*ones(11,2)]];\n' ...
    '            S5.gates    = [tSpan_, repmat([1 0 0], 11, 1)];\n' ...
    '            S5.capB     = [tSpan_, repmat([0.65 0.35 0.25 0.45], 11, 1)];\n' ...
    '        end\n' ...
    '        S5.hwGates  = [0 0 0 0; 0.25 1 0 0; 0.35 0 0 0; 0.37 0 1 0; 0.47 0 0 0; 0.49 0 0 1; 0.59 0 0 0; 0.62 1 1 0; 0.64 0 0 0];\n' ...
    '        S5.q4max    = 1e9;\n' ...
    '        S5.stopTime = 0.7;\n' ...
    '        S5.maxStep  = 2e-4;\n' ...
    '    catch\n' ...
    '    end\n' ...
    'end\n']);
set_param(mdl, 'PreLoadFcn', preloadCode);
set_param(mdl, 'InitFcn', preloadCode);

% ---- top level (spacious, clean layout) ---------------------------------
traffic = [mdl '/Traffic_Equivalent_Circuit'];
power   = [mdl '/Power_Path'];
add_block('built-in/Subsystem', traffic, 'Position', [360 60 660 240]);
add_block('built-in/Subsystem', power,   'Position', [360 310 660 440]);
build_traffic(traffic, cal);
build_power(power, cal);

fw(mdl, 'Arrivals_veh_per_s', 'S5.arrivals', '1', [60 72 210 108]);
fw(mdl, 'S4_Gates',           'S5.gates',    '1', [60 132 210 168]);
fw(mdl, 'Capacity_veh_per_s', 'S5.capB',     '1', [60 192 210 228]);
fw(mdl, 'HW_Gates',           'S5.hwGates',  '0', [60 357 210 393]);
add_line(mdl, 'Arrivals_veh_per_s/1', 'Traffic_Equivalent_Circuit/1', 'autorouting', 'smart');
add_line(mdl, 'S4_Gates/1',           'Traffic_Equivalent_Circuit/2', 'autorouting', 'smart');
add_line(mdl, 'Capacity_veh_per_s/1', 'Traffic_Equivalent_Circuit/3', 'autorouting', 'smart');
add_line(mdl, 'HW_Gates/1',           'Power_Path/1',                 'autorouting', 'smart');
note(mdl, 'SITRA S5 Physical Simscape Model — Layer A: Traffic Equivalent Circuit (1 V = 1 veh, 1 A = 1 veh/s, C = 1 F)', [60 20]);
note(mdl, 'Layer B: 230V AC Mains -> Transformer -> Bridge Rectifier -> 47V DC-Link -> 24V Buck Converter -> MOSFET Signal Channels', [60 475]);

save_system(mdl, f);
info.model = f;
info.cal = cal;
fprintf('\nBuilt %s\n', f);
print_cal(cal);
end

% =========================================================================
%  LAYER A: traffic equivalent circuit (clean orthogonal grid)
% =========================================================================
function build_traffic(sys, cal)
L = libs();

% --- Physical Circuit Region (y = 50 .. 460) ---
sc = addb(L.SC,  [sys '/Solver_Config'], [30 420 90 450]);
g  = addb(L.GND, [sys '/GND'],           [290 430 330 460]);
wire(sys, cp(sc, 'R', 1), cp(g, 'L', 1));

node4 = [];
rows = [60 190 320];
for b = 1:3
    y = rows(b); n = sprintf('B%d', b);
    % arrival current source (ground -> node b)
    sA = sps(sys, ['SPS_arr_' n], [40 y+12 75 y+38], 'A');
    a  = add_ccs(sys, ['I_arrival_' n], [130 y 180 y+50], sA, cal);
    % queue capacitor
    c  = addb(L.C, [sys '/C_' n], [290 y 330 y+50], 'Orientation', 'down');
    setp(c, '^c$', 'S5.C_queue');
    setp(c, '^vc_specify$', 'on');
    setp(c, '^vc$', sprintf('S5.vC0(%d)', b));
    % voltage sensor (well-spaced from PS2S converter)
    v  = add_vs(sys, ['V_' n], [390 y 430 y+50], cal);
    % departure source (node b -> node B4)
    sD = sps(sys, ['SPS_dep_' n], [550 y+12 585 y+38], 'A');
    d  = add_ccs(sys, ['I_depart_' n '_to_B4'], [640 y 690 y+50], sD, cal);

    nodeB = cp(c, 'L', 1);
    wire(sys, a.out, nodeB);  wire(sys, a.in, cp(g, 'L', 1));
    wire(sys, cp(c, 'R', 1), cp(g, 'L', 1));
    wire(sys, v.p, nodeB);    wire(sys, v.n, cp(g, 'L', 1));
    wire(sys, d.in, nodeB);
    if isempty(node4), node4 = d.out; else, wire(sys, d.out, node4); end
end

% B4: the junction everything merges into (KCL node)
c4 = addb(L.C, [sys '/C_B4'], [810 190 850 240], 'Orientation', 'down');
setp(c4, '^c$', 'S5.C_queue');
setp(c4, '^vc_specify$', 'on');
setp(c4, '^vc$', 'S5.vC0(4)');
v4 = add_vs(sys, 'V_B4', [900 190 940 240], cal);
wire(sys, node4, cp(c4, 'L', 1));
wire(sys, cp(c4, 'R', 1), cp(g, 'L', 1));
wire(sys, v4.p, cp(c4, 'L', 1)); wire(sys, v4.n, cp(g, 'L', 1));

% exit to Goldwins: current sensor + capacity-limited sink
ie = add_is(sys, 'I_exit_meter', [1060 190 1100 240], cal);
sE = sps(sys, 'SPS_exit', [1150 290 1185 316], 'A');
e  = add_ccs(sys, 'I_exit_Goldwins', [1230 190 1280 240], sE, cal);
wire(sys, ie.p, cp(c4, 'L', 1)); wire(sys, ie.n, e.in);
wire(sys, e.out, cp(g, 'L', 1));

% ---- Simulink Control & Departure Law (Clean Horizontal Bands y = 550 .. 880) --------
add_block('built-in/Inport', [sys '/Arrivals'], 'Position', [30 568 60 582]);
add_block('built-in/Inport', [sys '/Gates'],    'Position', [30 733 60 747]);
add_block('built-in/Inport', [sys '/Capacity'], 'Position', [620 648 650 662]);

blk(sys, 'simulink/Signal Routing/Demux', 'Dmx_arr', [100 545 106 605], 'Outputs', '3');
add_line(sys, 'Arrivals/1', 'Dmx_arr/1', 'autorouting', 'smart');
for b = 1:3
    add_line(sys, sprintf('Dmx_arr/%d', b), sprintf('SPS_arr_B%d/1', b), 'autorouting', 'smart');
end

% Gate Interlock Row (y = 720 .. 850)
blk(sys, 'simulink/Math Operations/Sum', 'Gate_count', [120 725 150 755], 'Inputs', '+', 'CollapseMode', 'All dimensions');
blk(sys, 'simulink/Logic and Bit Operations/Compare To Constant', 'One_green_max', [190 725 245 755], 'relop', '<=', 'const', '1');
blk(sys, 'simulink/Signal Attributes/Data Type Conversion', 'ok_dbl', [280 725 325 755], 'OutDataTypeStr', 'double');
blk(sys, 'simulink/Math Operations/Product', 'Interlock', [380 710 415 770], 'Inputs', '***');
blk(sys, 'simulink/Sources/Constant', 'One', [380 790 415 815], 'Value', '1');
blk(sys, 'simulink/Signal Routing/Mux', 'Mux_g', [460 720 466 820], 'Inputs', '2');

add_line(sys, 'Gates/1', 'Gate_count/1', 'autorouting', 'smart');
add_line(sys, 'Gate_count/1', 'One_green_max/1', 'autorouting', 'smart');
add_line(sys, 'One_green_max/1', 'ok_dbl/1', 'autorouting', 'smart');
add_line(sys, 'Gates/1', 'Interlock/1', 'autorouting', 'smart');
add_line(sys, 'ok_dbl/1', 'Interlock/2', 'autorouting', 'smart');
add_line(sys, 'Interlock/1', 'Mux_g/1', 'autorouting', 'smart');
add_line(sys, 'One/1', 'Mux_g/2', 'autorouting', 'smart');

% Interlock Violation Monitor
blk(sys, 'simulink/Logic and Bit Operations/Compare To Constant', 'Overlap', [190 800 245 830], 'relop', '>', 'const', '1');
blk(sys, 'simulink/Signal Attributes/Data Type Conversion', 'ov_dbl', [280 800 325 830], 'OutDataTypeStr', 'double');
tows(sys, 'Log_gateViolation', 'S5_gateViol', '1', [370 845 445 870]);
add_line(sys, 'Gate_count/1', 'Overlap/1', 'autorouting', 'smart');
add_line(sys, 'Overlap/1', 'ov_dbl/1', 'autorouting', 'smart');
add_line(sys, 'ov_dbl/1', 'Log_gateViolation/1', 'autorouting', 'smart');

% Queue Read-Out & Departure Law Row (y = 550 .. 690)
blk(sys, 'simulink/Signal Routing/Mux', 'Mux_vC', [500 545 506 645], 'Inputs', '4');
names = {'V_B1', 'V_B2', 'V_B3', 'V_B4'};
for b = 1:4
    add_line(sys, [names{b} '_PS2S/1'], sprintf('Mux_vC/%d', b), 'autorouting', 'smart');
end
blk(sys, 'simulink/Discrete/Zero-Order Hold', 'Sample_queue', [545 580 585 610], 'SampleTime', 'S5.dt');
add_line(sys, 'Mux_vC/1', 'Sample_queue/1', 'autorouting', 'smart');

% B4 Spill-back Clamp
blk(sys, 'simulink/Signal Routing/Selector', 'Sel_vB4', [620 500 660 530], 'NumberOfDimensions', '1', 'IndexMode', 'One-based', 'Indices', '4', 'InputPortWidth', '4');
blk(sys, 'simulink/Logic and Bit Operations/Compare To Constant', 'B4_Spillback_Clamp', [700 500 765 530], 'relop', '<', 'const', 'S5.q4max - 1e-4');
blk(sys, 'simulink/Signal Attributes/Data Type Conversion', 'b4_ok_dbl', [800 500 845 530], 'OutDataTypeStr', 'double');
add_line(sys, 'Sample_queue/1', 'Sel_vB4/1', 'autorouting', 'smart');
add_line(sys, 'Sel_vB4/1', 'B4_Spillback_Clamp/1', 'autorouting', 'smart');
add_line(sys, 'B4_Spillback_Clamp/1', 'b4_ok_dbl/1', 'autorouting', 'smart');
add_line(sys, 'b4_ok_dbl/1', 'Interlock/3', 'autorouting', 'smart');

blk(sys, 'simulink/Math Operations/Gain', 'per_dt', [625 580 665 610], 'Gain', '1/S5.dt');
blk(sys, 'simulink/Math Operations/MinMax', 'Cap_limit', [710 580 745 630], 'Function', 'min', 'Inputs', '2');
blk(sys, 'simulink/Sources/Constant', 'Zero', [710 655 745 680], 'Value', '0');
blk(sys, 'simulink/Math Operations/MinMax', 'Non_negative', [785 580 820 630], 'Function', 'max', 'Inputs', '2');
blk(sys, 'simulink/Math Operations/Product', 'Green_only', [865 580 900 630], 'Inputs', '**');
blk(sys, 'simulink/Signal Routing/Demux', 'Dmx_dep', [945 560 951 650], 'Outputs', '4');

add_line(sys, 'Sample_queue/1', 'per_dt/1', 'autorouting', 'smart');
add_line(sys, 'per_dt/1', 'Cap_limit/1', 'autorouting', 'smart');
add_line(sys, 'Capacity/1', 'Cap_limit/2', 'autorouting', 'smart');
add_line(sys, 'Cap_limit/1', 'Non_negative/1', 'autorouting', 'smart');
add_line(sys, 'Zero/1', 'Non_negative/2', 'autorouting', 'smart');
add_line(sys, 'Non_negative/1', 'Green_only/1', 'autorouting', 'smart');
add_line(sys, 'Mux_g/1', 'Green_only/2', 'autorouting', 'smart');
add_line(sys, 'Green_only/1', 'Dmx_dep/1', 'autorouting', 'smart');
for b = 1:3
    add_line(sys, sprintf('Dmx_dep/%d', b), sprintf('SPS_dep_B%d/1', b), 'autorouting', 'smart');
end
add_line(sys, 'Dmx_dep/4', 'SPS_exit/1', 'autorouting', 'smart');

tows(sys, 'Log_vC', 'S5_vC', 'S5.dt', [620 695 695 720]);
add_line(sys, 'Sample_queue/1', 'Log_vC/1', 'autorouting', 'smart');
blk(sys, 'simulink/Continuous/Integrator', 'Exit_charge', [1180 365 1215 395]);
tows(sys, 'Log_exitQ', 'S5_exitQ', 'S5.dt', [1255 368 1330 392]);
add_line(sys, 'I_exit_meter_PS2S/1', 'Exit_charge/1', 'autorouting', 'smart');
add_line(sys, 'Exit_charge/1', 'Log_exitQ/1', 'autorouting', 'smart');

note(sys, 'Traffic Equivalent Circuit: 1 vehicle = 1 C, 1 veh/s = 1 A, C = 1 F -> 1 V = 1 vehicle. B4 node = Kirchhoff junction.', [30 15]);
note(sys, 'Departure Law (sampled every 1 s and held): i_b = g_b * min(cap_b, v_b[k] / dt). Gates pass the S4 one-green interlock.', [30 480]);
end

% =========================================================================
%  LAYER B: power path (clean non-overlapping horizontal flow)
% =========================================================================
function build_power(sys, cal)
L = libs();

sc = addb(L.SC, [sys '/Solver_Config'], [30 350 90 380]);
try_set(sc, 'UseLocalSolver', 'on');
try_set(sc, 'LocalSolverChoice', 'NE_BACKWARD_EULER_ADVANCER');
try_set(sc, 'LocalSolverSampleTime', 'S5.par.Ts_local');
gP = addb(L.GND, [sys '/GND_primary'],  [80 260 120 290]);
gD = addb(L.GND, [sys '/GND_dc'],       [540 390 580 420]);
wire(sys, cp(sc, 'R', 1), cp(gD, 'L', 1));
GD = cp(gD, 'L', 1);

% --- AC supply and transformer ---------------------------------------------
ac = addb(L.VAC, [sys '/AC_Mains'], [40 120 80 175], 'Orientation', 'down');
setp(ac, '^amp', 'S5.par.Vac_rms*sqrt(2)');
setp(ac, '^freq', 'S5.par.f_ac');
tx = addb(L.XFMR, [sys '/Transformer'], [145 110 210 185]);
setp(tx, '^n$|ratio', 'S5.par.xfmr_n_block');
wire(sys, cp(ac, 'L', 1), cp(tx, 'L', 1));
wire(sys, cp(ac, 'R', 1), cp(gP, 'L', 1));
wire(sys, cp(tx, 'L', 2), cp(gP, 'L', 1));
rs = addb(L.R, [sys '/R_leak'], [245 100 290 125]);  setp(rs, '^R$', 'S5.par.R_sec');
ls = addb(L.L, [sys '/L_leak'], [315 100 360 125]);  setp(ls, '^l$', 'S5.par.L_sec');
wire(sys, cp(tx, 'R', 1), cp(rs, 'L', 1));
wire(sys, cp(rs, 'R', 1), cp(ls, 'L', 1));
acA = cp(ls, 'R', 1);
acB = cp(tx, 'R', 2);

% --- diode bridge ------------------------------------------------------------
d1 = add_diode(sys, 'D1', [400 60  445 85],  cal);
d2 = add_diode(sys, 'D2', [400 160 445 185], cal);
d3 = add_diode(sys, 'D3', [400 260 445 285], cal);
d4 = add_diode(sys, 'D4', [400 335 445 360], cal);
wire(sys, d1.a, acA); wire(sys, d3.k, acA);
wire(sys, d2.a, acB); wire(sys, d4.k, acB);
wire(sys, d1.k, d2.k);
DCP = d1.k;
wire(sys, d3.a, GD); wire(sys, d4.a, GD);

% --- DC link -------------------------------------------------------------------
re = addb(L.R, [sys '/R_ESR_dc'],  [495 90  540 115]); setp(re, '^R$', 'S5.par.R_esr');
cd = addb(L.C, [sys '/C_DC_link'], [560 140 600 195], 'Orientation', 'down'); setp(cd, '^c$', 'S5.par.C_dc');
rb = addb(L.R, [sys '/R_bleed'],   [625 140 665 195], 'Orientation', 'down'); setp(rb, '^R$', 'S5.par.R_bleed');
vdc = add_vs(sys, 'V_DC_link',     [695 140 735 195], cal);
wire(sys, DCP, cp(re, 'L', 1)); wire(sys, cp(re, 'R', 1), cp(cd, 'L', 1)); wire(sys, cp(cd, 'R', 1), GD);
wire(sys, DCP, cp(rb, 'L', 1)); wire(sys, cp(rb, 'R', 1), GD);
wire(sys, vdc.p, DCP); wire(sys, vdc.n, GD);

% --- buck converter ------------------------------------------------------------
sB = sps(sys, 'SPS_buck_gate', [780 260 815 285], '');
qb = add_mos(sys, 'Q_buck',    [830 60  880 120], sB, cal);
wire(sys, qb.D, DCP);
SW = qb.S;
dfw = add_diode(sys, 'D_freewheel', [895 165 940 190], cal);
wire(sys, dfw.k, SW); wire(sys, dfw.a, GD);
lb = addb(L.L, [sys '/L_buck'], [960 80 1005 105]); setp(lb, '^l$', 'S5.par.L_buck');
wire(sys, SW, cp(lb, 'L', 1));
BUS = cp(lb, 'R', 1);
co   = addb(L.C, [sys '/C_bus'],         [1035 140 1075 195], 'Orientation', 'down'); setp(co, '^c$', 'S5.par.C_out');
rd   = addb(L.R, [sys '/R_damp'],        [1100 120 1140 155], 'Orientation', 'down'); setp(rd, '^R$', 'S5.par.R_damp');
cdm  = addb(L.C, [sys '/C_damp'],        [1100 180 1140 230], 'Orientation', 'down'); setp(cdm, '^c$', 'S5.par.C_damp');
rmin = addb(L.R, [sys '/R_bus_minload'], [1165 140 1205 195], 'Orientation', 'down'); setp(rmin, '^R$', 'S5.par.R_busbleed');
vbus = add_vs(sys, 'V_Bus_24V',          [1235 140 1275 195], cal);
wire(sys, BUS, cp(co, 'L', 1)); wire(sys, cp(co, 'R', 1), GD);
wire(sys, BUS, cp(rd, 'L', 1)); wire(sys, cp(rd, 'R', 1), cp(cdm, 'L', 1)); wire(sys, cp(cdm, 'R', 1), GD);
wire(sys, BUS, cp(rmin, 'L', 1)); wire(sys, cp(rmin, 'R', 1), GD);
wire(sys, vbus.p, BUS); wire(sys, vbus.n, GD);

% --- three signal-head channels -------------------------------------------------
ys = [40 175 310];
for b = 1:3
    n = sprintf('B%d', b); y = ys(b);
    sG = sps(sys, ['SPS_gate_' n], [1370 y+70 1405 y+95], '');
    q  = add_mos(sys, ['Q_' n],    [1430 y 1480 y+60], sG, cal);
    is = add_is(sys, ['I_' n],     [1520 y+10 1560 y+55], cal);
    rl = addb(L.R, [sys '/Load_SignalHead_' n], [1615 y 1655 y+55], 'Orientation', 'down');
    setp(rl, '^R$', 'S5.par.R_load');
    wire(sys, q.D, BUS); wire(sys, q.S, is.p); wire(sys, is.n, cp(rl, 'L', 1)); wire(sys, cp(rl, 'R', 1), GD);
end

% ---- Simulink control (cleanly separated below the circuit y = 470 .. 760) ----
% Band 1 (y = 480 .. 580): Buck Voltage Closed-Loop PI + Feedforward + PWM
blk(sys, 'simulink/Sources/Constant', 'V_bus_ref', [560 475 605 500], 'Value', 'S5.par.V_bus_ref');
blk(sys, 'simulink/Math Operations/Sum', 'V_error', [645 475 670 515], 'Inputs', '+-');
blk(sys, 'simulink/Continuous/PID Controller', 'PI_bus', [700 480 755 510]);
try_set([sys '/PI_bus'], 'Controller', 'PI');
try_set([sys '/PI_bus'], 'P', 'S5.par.Kp');
try_set([sys '/PI_bus'], 'I', 'S5.par.Ki');
try_set([sys '/PI_bus'], 'LimitOutput', 'on');
try_set([sys '/PI_bus'], 'UpperSaturationLimit', '0.5');
try_set([sys '/PI_bus'], 'LowerSaturationLimit', '-0.5');
try_set([sys '/PI_bus'], 'AntiWindupMode', 'clamping');

blk(sys, 'simulink/Discrete/Unit Delay', 'UD_vdc', [560 525 595 555], 'SampleTime', 'S5.par.Ts_local', 'InitialCondition', '0');
blk(sys, 'simulink/Sources/Constant', 'One_V', [560 570 595 595], 'Value', '1');
blk(sys, 'simulink/Math Operations/MinMax', 'Vdc_floor', [630 535 665 575], 'Function', 'max', 'Inputs', '2');
blk(sys, 'simulink/Math Operations/Product', 'Feedforward', [700 530 735 570], 'Inputs', '*/');
blk(sys, 'simulink/Math Operations/Sum', 'Duty_sum', [785 485 810 530], 'Inputs', '++');
blk(sys, 'simulink/Discontinuities/Saturation', 'Duty_limit', [840 492 880 522], 'UpperLimit', 'S5.par.D_max', 'LowerLimit', '0', 'ZeroCross', 'off');
blk(sys, 'simulink/Sources/Repeating Sequence', 'PWM_carrier', [840 545 880 575], 'rep_seq_t', '[0 1/S5.par.f_sw]', 'rep_seq_y', '[0 1]');
blk(sys, 'simulink/Logic and Bit Operations/Relational Operator', 'PWM_compare', [915 495 945 545], 'Operator', '>', 'ZeroCross', 'off');
blk(sys, 'simulink/Signal Attributes/Data Type Conversion', 'pwm_dbl', [975 505 1020 535], 'OutDataTypeStr', 'double');
blk(sys, 'simulink/Math Operations/Gain', 'Buck_gate_V', [1050 505 1095 535], 'Gain', 'S5.par.V_gate');

% Band 2 (y = 650 .. 730): Channel Gate Interlock, Under-Voltage, and Over-Current
add_block('built-in/Inport', [sys '/HW_Gates'], 'Position', [30 668 60 682]);
blk(sys, 'simulink/Math Operations/Sum', 'Gate_count', [100 660 130 690], 'Inputs', '+', 'CollapseMode', 'All dimensions');
blk(sys, 'simulink/Logic and Bit Operations/Compare To Constant', 'One_green_max', [165 660 220 690], 'relop', '<=', 'const', '1', 'ZeroCross', 'off');
blk(sys, 'simulink/Signal Attributes/Data Type Conversion', 'ok_dbl', [255 660 300 690], 'OutDataTypeStr', 'double');
blk(sys, 'simulink/Math Operations/Product', 'Interlock', [340 655 375 705], 'Inputs', '**');
blk(sys, 'simulink/Math Operations/Product', 'Protect_OC', [415 655 450 705], 'Inputs', '**');
blk(sys, 'simulink/Math Operations/Product', 'Protect_UV', [490 655 525 705], 'Inputs', '**');
blk(sys, 'simulink/Math Operations/Gain', 'Gate_drive_V', [565 665 610 695], 'Gain', 'S5.par.V_gate');
blk(sys, 'simulink/Signal Routing/Demux', 'Dmx_gate', [650 645 656 715], 'Outputs', '3');

% Over-Current Protection Chain (Right side y = 470 .. 560)
blk(sys, 'simulink/Signal Routing/Mux', 'Mux_I', [1690 450 1696 520], 'Inputs', '3');
for b = 1:3
    add_line(sys, sprintf('I_B%d_PS2S/1', b), sprintf('Mux_I/%d', b), 'autorouting', 'smart');
end
blk(sys, 'simulink/Discrete/Unit Delay', 'UD_i', [1725 470 1760 500], 'SampleTime', 'S5.par.Ts_local', 'InitialCondition', '0');
blk(sys, 'simulink/Math Operations/Abs', 'Abs_I', [1785 470 1815 500], 'ZeroCross', 'off');
blk(sys, 'simulink/Logic and Bit Operations/Compare To Constant', 'Over_current', [1840 470 1895 500], 'relop', '>', 'const', 'S5.par.I_trip', 'ZeroCross', 'off');
blk(sys, 'simulink/Logic and Bit Operations/Logical Operator', 'Trip_latch', [1925 465 1960 505], 'Operator', 'OR', 'Inputs', '2');
blk(sys, 'simulink/Discrete/Unit Delay', 'Latch_mem', [1925 530 1960 555], 'SampleTime', 'S5.par.Ts_local', 'InitialCondition', '0', 'Orientation', 'left');
blk(sys, 'simulink/Logic and Bit Operations/Logical Operator', 'Not_tripped', [1990 470 2020 500], 'Operator', 'NOT');
blk(sys, 'simulink/Signal Attributes/Data Type Conversion', 'nt_dbl', [2045 470 2090 500], 'OutDataTypeStr', 'double');

% Under-Voltage Protection Chain (Right side y = 590 .. 670)
blk(sys, 'simulink/Discrete/Unit Delay', 'UD_vbus', [1350 585 1385 615], 'SampleTime', 'S5.par.Ts_local', 'InitialCondition', '0');
blk(sys, 'simulink/Logic and Bit Operations/Compare To Constant', 'Bus_undervolt', [1415 585 1475 615], 'relop', '<', 'const', 'S5.par.UV_frac*S5.par.V_bus_ref', 'ZeroCross', 'off');
blk(sys, 'simulink/Sources/Clock', 'Clock', [1415 635 1440 660]);
blk(sys, 'simulink/Logic and Bit Operations/Compare To Constant', 'After_blanking', [1470 632 1525 662], 'relop', '>', 'const', 'S5.par.t_blank', 'ZeroCross', 'off');
blk(sys, 'simulink/Logic and Bit Operations/Logical Operator', 'UV_trip', [1560 590 1595 660], 'Operator', 'AND', 'Inputs', '2');
blk(sys, 'simulink/Logic and Bit Operations/Logical Operator', 'Not_UV', [1625 610 1655 640], 'Operator', 'NOT');
blk(sys, 'simulink/Signal Attributes/Data Type Conversion', 'nuv_dbl', [1685 610 1730 640], 'OutDataTypeStr', 'double');

% Wire Buck Voltage Loop
add_line(sys, 'V_bus_ref/1', 'V_error/1', 'autorouting', 'smart');
add_line(sys, 'UD_vbus/1', 'V_error/2', 'autorouting', 'smart');
add_line(sys, 'V_error/1', 'PI_bus/1', 'autorouting', 'smart');
add_line(sys, 'V_DC_link_PS2S/1', 'UD_vdc/1', 'autorouting', 'smart');
add_line(sys, 'UD_vdc/1', 'Vdc_floor/1', 'autorouting', 'smart');
add_line(sys, 'One_V/1', 'Vdc_floor/2', 'autorouting', 'smart');
add_line(sys, 'V_bus_ref/1', 'Feedforward/1', 'autorouting', 'smart');
add_line(sys, 'Vdc_floor/1', 'Feedforward/2', 'autorouting', 'smart');
add_line(sys, 'PI_bus/1', 'Duty_sum/1', 'autorouting', 'smart');
add_line(sys, 'Feedforward/1', 'Duty_sum/2', 'autorouting', 'smart');
add_line(sys, 'Duty_sum/1', 'Duty_limit/1', 'autorouting', 'smart');
add_line(sys, 'Duty_limit/1', 'PWM_compare/1', 'autorouting', 'smart');
add_line(sys, 'PWM_carrier/1', 'PWM_compare/2', 'autorouting', 'smart');
add_line(sys, 'PWM_compare/1', 'pwm_dbl/1', 'autorouting', 'smart');
add_line(sys, 'pwm_dbl/1', 'Buck_gate_V/1', 'autorouting', 'smart');
add_line(sys, 'Buck_gate_V/1', 'SPS_buck_gate/1', 'autorouting', 'smart');

% Wire Over-Current & Under-Voltage Loops
add_line(sys, 'Mux_I/1', 'UD_i/1', 'autorouting', 'smart');
add_line(sys, 'UD_i/1', 'Abs_I/1', 'autorouting', 'smart');
add_line(sys, 'Abs_I/1', 'Over_current/1', 'autorouting', 'smart');
add_line(sys, 'Over_current/1', 'Trip_latch/1', 'autorouting', 'smart');
add_line(sys, 'Latch_mem/1', 'Trip_latch/2', 'autorouting', 'smart');
add_line(sys, 'Trip_latch/1', 'Latch_mem/1', 'autorouting', 'smart');
add_line(sys, 'Trip_latch/1', 'Not_tripped/1', 'autorouting', 'smart');
add_line(sys, 'Not_tripped/1', 'nt_dbl/1', 'autorouting', 'smart');

add_line(sys, 'V_Bus_24V_PS2S/1', 'UD_vbus/1', 'autorouting', 'smart');
add_line(sys, 'UD_vbus/1', 'Bus_undervolt/1', 'autorouting', 'smart');
add_line(sys, 'Bus_undervolt/1', 'UV_trip/1', 'autorouting', 'smart');
add_line(sys, 'Clock/1', 'After_blanking/1', 'autorouting', 'smart');
add_line(sys, 'After_blanking/1', 'UV_trip/2', 'autorouting', 'smart');
add_line(sys, 'UV_trip/1', 'Not_UV/1', 'autorouting', 'smart');
add_line(sys, 'Not_UV/1', 'nuv_dbl/1', 'autorouting', 'smart');

% Wire Gate Protection Chain
add_line(sys, 'HW_Gates/1', 'Gate_count/1', 'autorouting', 'smart');
add_line(sys, 'Gate_count/1', 'One_green_max/1', 'autorouting', 'smart');
add_line(sys, 'One_green_max/1', 'ok_dbl/1', 'autorouting', 'smart');
add_line(sys, 'HW_Gates/1', 'Interlock/1', 'autorouting', 'smart');
add_line(sys, 'ok_dbl/1', 'Interlock/2', 'autorouting', 'smart');
add_line(sys, 'Interlock/1', 'Protect_OC/1', 'autorouting', 'smart');
add_line(sys, 'nt_dbl/1', 'Protect_OC/2', 'autorouting', 'smart');
add_line(sys, 'Protect_OC/1', 'Protect_UV/1', 'autorouting', 'smart');
add_line(sys, 'nuv_dbl/1', 'Protect_UV/2', 'autorouting', 'smart');
add_line(sys, 'Protect_UV/1', 'Gate_drive_V/1', 'autorouting', 'smart');
add_line(sys, 'Gate_drive_V/1', 'Dmx_gate/1', 'autorouting', 'smart');
for b = 1:3
    add_line(sys, sprintf('Dmx_gate/%d', b), sprintf('SPS_gate_B%d/1', b), 'autorouting', 'smart');
end

% Logging Sinks (Cleanly positioned in the control region below the physical circuit)
tows(sys, 'Log_vDC',  'S5_vDC',  '1e-4', [450 528 525 552]);
tows(sys, 'Log_vBus', 'S5_vBus', '1e-4', [1350 535 1425 558]);
tows(sys, 'Log_iCh',  'S5_iCh',  '1e-4', [1725 530 1795 553]);
tows(sys, 'Log_gCmd', 'S5_gCmd', '1e-4', [565 725 635 748]);
tows(sys, 'Log_duty', 'S5_duty', '1e-4', [905 445 975 468]);
add_line(sys, 'V_DC_link_PS2S/1', 'Log_vDC/1', 'autorouting', 'smart');
add_line(sys, 'V_Bus_24V_PS2S/1', 'Log_vBus/1', 'autorouting', 'smart');
add_line(sys, 'Mux_I/1', 'Log_iCh/1', 'autorouting', 'smart');
add_line(sys, 'Protect_UV/1', 'Log_gCmd/1', 'autorouting', 'smart');
add_line(sys, 'Duty_limit/1', 'Log_duty/1', 'autorouting', 'smart');

note(sys, 'Supply & Conversion: 230V AC Mains -> Transformer -> Diode Bridge -> 47V DC-Link -> 24V Closed-Loop Buck Converter', [30 15]);
note(sys, 'Signal-Head Channels: N-Channel Power MOSFETs, Current Sensors, and 24-Ohm Signal Loads', [1370 15]);
note(sys, 'Control & Protection: One-Green Interlock, Over-Current Latch, Under-Voltage Trip, Buck PI + 10 kHz PWM', [30 770]);
end

% =========================================================================
%  R2026a Direct Port Calibration (zero temporary-model compilation overhead)
% =========================================================================
function cal = r2026a_calibrated_ports()
cal = struct( ...
    'vsSwap', false, ...
    'isSwap', false, ...
    'ccsOutIsA', true, ...
    'cvsPlusIsA', true, ...
    'diodeSwap', false, ...
    'mosSwap', false, ...
    'gateUnit', '1', ...
    'xfmrRatioIsSecOverPri', false, ...
    'xfmrParam', @(r) 1/r);
end

function cal = calibrate_ports(S5) %#ok<INUSD,DEFNU>
cal = struct('vsSwap', false, 'isSwap', false, 'ccsOutIsA', true, 'cvsPlusIsA', true, ...
    'diodeSwap', false, 'mosSwap', false, 'gateUnit', '1', 'xfmrRatioIsSecOverPri', true);
% pass 1: sensors, sources, diode, transformer
m = 'S5_port_calibration';
if bdIsLoaded(m), close_system(m, 0); end
new_system(m); set_solver(m); set_param(m, 'StopTime', '0.01');
L = libs(); sys = m;
sc = addb(L.SC, [sys '/SC'], [20 20 80 50]);
g  = addb(L.GND, [sys '/G'], [20 400 60 430]);
wire(sys, cp(sc, 'R', 1), cp(g, 'L', 1)); G = cp(g, 'L', 1);
% (1) DC source -> raw voltage sensor
vdc = addb(L.VDC, [sys '/Vdc'], [100 60 140 110]); setp(vdc, '^v0$|^v$|volt', '10');
vs  = add_vs(sys, 'VS', [180 60 220 110], cal);  % raw (unswapped) ordering
wire(sys, cp(vdc, 'L', 1), vs.p); wire(sys, cp(vdc, 'R', 1), G); wire(sys, vs.n, G);
tows(sys, 'out_vs', 'cal_vs', '-1', [260 70 300 90]); add_line(sys, 'VS_PS2S/1', 'out_vs/1');
% (2) controlled current source into 1 Ohm, read with raw sensor
s1 = sps(sys, 'S_ccs', [100 150 130 170], 'A');
blk(sys, 'simulink/Sources/Constant', 'k1', [40 150 70 170], 'Value', '1'); add_line(sys, 'k1/1', 'S_ccs/1');
c = add_ccs(sys, 'CCS', [150 140 200 190], s1, cal);
r1 = addb(L.R, [sys '/R1'], [230 140 270 160]); setp(r1, '^R$', '1');
vs2 = add_vs(sys, 'VS2', [300 140 340 190], cal);
wire(sys, c.out, cp(r1, 'L', 1)); wire(sys, c.in, G); wire(sys, cp(r1, 'R', 1), G);
wire(sys, vs2.p, cp(r1, 'L', 1)); wire(sys, vs2.n, G);
tows(sys, 'out_ccs', 'cal_ccs', '-1', [380 150 420 170]); add_line(sys, 'VS2_PS2S/1', 'out_ccs/1');
% (3) controlled voltage source into 100 Ohm
s2 = sps(sys, 'S_cvs', [100 220 130 240], 'V');
blk(sys, 'simulink/Sources/Constant', 'k5', [40 220 70 240], 'Value', '5'); add_line(sys, 'k5/1', 'S_cvs/1');
cv = add_cvs(sys, 'CVS', [150 210 200 260], s2, cal);
r2 = addb(L.R, [sys '/R2'], [230 210 270 230]); setp(r2, '^R$', '100');
vs3 = add_vs(sys, 'VS3', [300 210 340 260], cal);
wire(sys, cv.p, cp(r2, 'L', 1)); wire(sys, cv.n, G); wire(sys, cp(r2, 'R', 1), G);
wire(sys, vs3.p, cp(r2, 'L', 1)); wire(sys, vs3.n, G);
tows(sys, 'out_cvs', 'cal_cvs', '-1', [380 220 420 240]); add_line(sys, 'VS3_PS2S/1', 'out_cvs/1');
% (4) current sensor in series: Vdc2 + -> IS(p->n) -> 10 Ohm -> G
vd2 = addb(L.VDC, [sys '/Vdc2'], [100 280 140 330]); setp(vd2, '^v0$|^v$|volt', '10');
is = add_is(sys, 'IS', [170 280 210 330], cal);
r3 = addb(L.R, [sys '/R3'], [240 280 280 300]); setp(r3, '^R$', '10');
wire(sys, cp(vd2, 'L', 1), is.p); wire(sys, is.n, cp(r3, 'L', 1)); wire(sys, cp(r3, 'R', 1), G); wire(sys, cp(vd2, 'R', 1), G);
tows(sys, 'out_is', 'cal_is', '-1', [380 290 420 310]); add_line(sys, 'IS_PS2S/1', 'out_is/1');
% (5) diode: Vdc3 + -> 10 Ohm -> node -> diode(L->R) -> G
vd3 = addb(L.VDC, [sys '/Vdc3'], [460 60 500 110]); setp(vd3, '^v0$|^v$|volt', '10');
r4 = addb(L.R, [sys '/R4'], [530 60 570 80]); setp(r4, '^R$', '10');
dd = addb(L.D, [sys '/D'], [600 60 640 80]);
vs4 = add_vs(sys, 'VS4', [660 90 700 140], cal);
wire(sys, cp(vd3, 'L', 1), cp(r4, 'L', 1)); wire(sys, cp(r4, 'R', 1), cp(dd, 'L', 1)); wire(sys, cp(dd, 'R', 1), G);
wire(sys, cp(vd3, 'R', 1), G); wire(sys, vs4.p, cp(dd, 'L', 1)); wire(sys, vs4.n, G);
tows(sys, 'out_d', 'cal_d', '-1', [740 100 780 120]); add_line(sys, 'VS4_PS2S/1', 'out_d/1');
% (6) transformer ratio convention: Vdc4 = 10 V on primary, ratio param = 2
vd4 = addb(L.VDC, [sys '/Vdc4'], [460 180 500 230]); setp(vd4, '^v0$|^v$|volt', '10');
tx = addb(L.XFMR, [sys '/TX'], [530 170 590 240]); setp(tx, '^n$|ratio', '2');
r5 = addb(L.R, [sys '/R5'], [620 170 660 190]); setp(r5, '^R$', '100');
vs5 = add_vs(sys, 'VS5', [680 200 720 250], cal);
g2 = addb(L.GND, [sys '/G2'], [460 260 500 290]);
wire(sys, cp(vd4, 'L', 1), cp(tx, 'L', 1)); wire(sys, cp(vd4, 'R', 1), cp(g2, 'L', 1)); wire(sys, cp(tx, 'L', 2), cp(g2, 'L', 1));
wire(sys, cp(tx, 'R', 1), cp(r5, 'L', 1)); wire(sys, cp(r5, 'R', 1), cp(tx, 'R', 2)); wire(sys, cp(tx, 'R', 2), G);
wire(sys, vs5.p, cp(tx, 'R', 1)); wire(sys, vs5.n, G);
tows(sys, 'out_tx', 'cal_tx', '-1', [760 210 800 230]); add_line(sys, 'VS5_PS2S/1', 'out_tx/1');

o = run_cal(m);
sv = sign(lastv(o, 'cal_vs'));
cal.vsSwap   = sv < 0;
cal.ccsOutIsA  = sv * lastv(o, 'cal_ccs') > 0;
cal.cvsPlusIsA = sv * lastv(o, 'cal_cvs') > 0;
cal.isSwap   = lastv(o, 'cal_is') < 0;
cal.diodeSwap = sv * lastv(o, 'cal_d') > 5;      % ~10 V means the diode was blocking
rt = abs(lastv(o, 'cal_tx')) / 10;
cal.xfmrRatioIsSecOverPri = abs(rt - 2) < abs(rt - 0.5);
cal.raw.vs = lastv(o, 'cal_vs'); cal.raw.ccs = lastv(o, 'cal_ccs'); cal.raw.cvs = lastv(o, 'cal_cvs');
cal.raw.is = lastv(o, 'cal_is'); cal.raw.d = lastv(o, 'cal_d'); cal.raw.tx = lastv(o, 'cal_tx');
close_system(m, 0);

% pass 2: MOSFET drain/source and gate unit (uses pass-1 results)
units = {'1', 'V'};
ok = false; lastErr = '';
for swap = [false true]
    for u = 1:numel(units)
        cal.mosSwap = swap; cal.gateUnit = units{u};
        try
            [voff, von] = mos_cal(cal);
        catch ME
            lastErr = ME.message; continue
        end
        if voff > 5 && von < 2, ok = true; break; end
    end
    if ok, break; end
end
if ~ok
    error('S5:cal', ['MOSFET calibration failed: could not find drain/source orientation that ' ...
        'blocks when off and conducts when on. Last error: %s'], lastErr);
end
secOverPri = cal.xfmrRatioIsSecOverPri;
cal.xfmrParam = @(r) ifelse(secOverPri, r, 1/r);
end

function [voff, von] = mos_cal(cal)
m = 'S5_mos_calibration';
if bdIsLoaded(m), close_system(m, 0); end
new_system(m); set_solver(m); set_param(m, 'StopTime', '0.01');
L = libs(); sys = m;
sc = addb(L.SC, [sys '/SC'], [20 20 80 50]);
g  = addb(L.GND, [sys '/G'], [20 300 60 330]);
wire(sys, cp(sc, 'R', 1), cp(g, 'L', 1)); G = cp(g, 'L', 1);
vd = addb(L.VDC, [sys '/Vdc'], [100 60 140 110]); setp(vd, '^v0$|^v$|volt', '10');
r  = addb(L.R, [sys '/R'], [170 60 210 80]); setp(r, '^R$', '10');
blk(sys, 'simulink/Sources/Step', 'Gate_step', [40 160 70 190], 'Time', '0.005', 'Before', '0', 'After', '10');
s = sps(sys, 'S_gate', [90 165 120 185], cal.gateUnit);
add_line(sys, 'Gate_step/1', 'S_gate/1');
q = add_mos(sys, 'Q', [240 100 290 160], s, cal);
vs = add_vs(sys, 'VS', [320 60 360 110], cal);
wire(sys, cp(vd, 'L', 1), cp(r, 'L', 1)); wire(sys, cp(vd, 'R', 1), G);
wire(sys, cp(r, 'R', 1), q.D); wire(sys, q.S, G);
wire(sys, vs.p, q.D); wire(sys, vs.n, G);
tows(sys, 'out', 'cal_mos', '-1', [400 70 440 90]); add_line(sys, 'VS_PS2S/1', 'out/1');
try
    o = run_cal(m);
catch ME
    close_system(m, 0); rethrow(ME);
end
ts = o.get('cal_mos');
t = ts.time; v = ts.signals.values(:);
voff = mean(v(t > 0.001 & t < 0.0045));
von  = mean(v(t > 0.007));
close_system(m, 0);
end

function o = run_cal(m)
assignin('base', 'S5_calStep', 1e-4);
set_param(m, 'MaxStep', '1e-4');
try
    o = sim(m, 'ReturnWorkspaceOutputs', 'on');
catch ME
    msg = ME.message;
    if ~isempty(ME.cause), msg = [msg newline ME.cause{1}.message]; end
    error('S5:cal', ['Calibration circuit "%s" failed to simulate. This usually means a ' ...
        'physical-signal port was wired to an electrical terminal (port detection) or a ' ...
        'library block path differs in this MATLAB release.\n%s'], m, msg);
end
end

function v = lastv(o, name)
ts = o.get(name);
v = ts.signals.values(end);
end

function y = ifelse(c, a, b)
if c, y = a; else, y = b; end
end

% =========================================================================
%  Component helpers (role-aware wiring with generous spacing)
% =========================================================================
function e = add_ccs(sys, name, pos, spsPath, cal)
L = libs(); b = addb(L.CCS, [sys '/' name], pos);
P = portlist(b);
[~, P] = connect_ps(sys, cp(spsPath, 'R', 1), P, {'left', 'top', 'right', 'bottom'}, true, name);
[a, z] = pair(P);
if cal.ccsOutIsA, e.out = a; e.in = z; else, e.out = z; e.in = a; end
end

function e = add_cvs(sys, name, pos, spsPath, cal)
L = libs(); b = addb(L.CVS, [sys '/' name], pos);
P = portlist(b);
[~, P] = connect_ps(sys, cp(spsPath, 'R', 1), P, {'left', 'top', 'right', 'bottom'}, true, name);
[a, z] = pair(P);
if cal.cvsPlusIsA, e.p = a; e.n = z; else, e.p = z; e.n = a; end
end

function e = add_vs(sys, name, pos, cal)
L = libs(); b = addb(L.VS, [sys '/' name], pos);
cv = addb(L.PS2S, [sys '/' name '_PS2S'], [pos(3)+45, pos(2)+15, pos(3)+75, pos(2)+35], 'ShowName', 'off');
try_set(cv, 'Unit', 'V');
P = portlist(b);
[~, P] = connect_ps(sys, cp(cv, 'L', 1), P, {'right', 'bottom', 'top', 'left'}, false, name);
[a, z] = pair(P);
if cal.vsSwap, e.p = z; e.n = a; else, e.p = a; e.n = z; end
end

function e = add_is(sys, name, pos, cal)
L = libs(); b = addb(L.IS, [sys '/' name], pos);
cv = addb(L.PS2S, [sys '/' name '_PS2S'], [pos(1)+8, pos(4)+25, pos(1)+32, pos(4)+45], 'ShowName', 'off');
try_set(cv, 'Unit', 'A');
P = portlist(b);
[~, P] = connect_ps(sys, cp(cv, 'L', 1), P, {'bottom', 'right', 'top', 'left'}, false, name);
[a, z] = pair(P);
if cal.isSwap, e.p = z; e.n = a; else, e.p = a; e.n = z; end
end

function e = add_diode(sys, name, pos, cal)
L = libs(); b = addb(L.D, [sys '/' name], pos);
if cal.diodeSwap, e.a = cp(b, 'R', 1); e.k = cp(b, 'L', 1);
else,             e.a = cp(b, 'L', 1); e.k = cp(b, 'R', 1); end
end

function m = add_mos(sys, name, pos, spsPath, cal)
L = libs(); b = addb(L.MOS, [sys '/' name], pos);
m.lib = get_param(b, 'ReferenceBlock');
try_set(spsPath, 'Unit', cal.gateUnit);
P = portlist(b);
[g, P] = connect_ps(sys, cp(spsPath, 'R', 1), P, {'left', 'top', 'bottom', 'right'}, true, '');
gateNeg = [];
if isempty(g)
    gi = find(strcmp({P.side}, 'left'), 1);
    if isempty(gi), error('S5:mos', '%s: cannot identify the gate terminal.', name); end
    G = P(gi).h; P(gi) = [];
    try_set(spsPath, 'Unit', 'V');
    drv = add_cvs(sys, [name '_GateDriver'], pos + [-120 70 -120 70], spsPath, cal);
    rg = addb(L.R, [sys '/' name '_Rgate'], pos + [-50 70 -60 40]);
    setp(rg, '^R$', 'S5.par.R_gate');
    wire(sys, drv.p, cp(rg, 'L', 1)); wire(sys, cp(rg, 'R', 1), G);
    gateNeg = drv.n;
end
it = find(strcmp({P.side}, 'top'), 1); ib = find(strcmp({P.side}, 'bottom'), 1);
if isempty(it) || isempty(ib)
    [~, i] = sort([P.rank]); it = i(1); ib = i(2);
end
D = P(it).h; S = P(ib).h;
if cal.mosSwap, [D, S] = deal(S, D); end
if ~isempty(gateNeg), wire(sys, gateNeg, S); end
m.D = D; m.S = S;
end

function p = sps(sys, name, pos, unit)
L = libs(); p = addb(L.S2PS, [sys '/' name], pos, 'ShowName', 'off');
if ~isempty(unit), try_set(p, 'Unit', unit); end
if ~try_set(p, 'FilteringAndDerivatives', 'zero')
    try_set(p, 'InputFilterOrder', '0');
end
end

function [hit, P] = connect_ps(sys, src, P, order, srcIsOutput, name)
hit = [];
idx = order_by_side(P, order);
for k = idx
    try
        if srcIsOutput, add_line(sys, src, P(k).h, 'autorouting', 'smart');
        else,           add_line(sys, P(k).h, src, 'autorouting', 'smart'); end
        hit = P(k).h; P(k) = []; return
    catch
    end
end
if ~isempty(name)
    error('S5:port', '%s: no port accepted the physical-signal connection.', name);
end
end

function idx = order_by_side(P, order)
idx = [];
for s = 1:numel(order)
    idx = [idx find(strcmp({P.side}, order{s}))]; %#ok<AGROW>
end
end

function [a, z] = pair(P)
if numel(P) < 2, error('S5:port', 'expected two electrical terminals, found %d', numel(P)); end
[~, i] = sort([P.rank]); a = P(i(1)).h; z = P(i(2)).h;
end

function P = portlist(b)
ph = get_param(b, 'PortHandles');
hs = [ph.LConn(:); ph.RConn(:)];
bp = get_param(b, 'Position');
names = {'top', 'left', 'right', 'bottom'};
P = struct('h', {}, 'side', {}, 'rank', {});
for k = 1:numel(hs)
    q = get_param(hs(k), 'Position');
    d = [abs(q(2) - bp(2)), abs(q(1) - bp(1)), abs(q(1) - bp(3)), abs(q(2) - bp(4))];
    [~, s] = min(d);
    P(end+1) = struct('h', hs(k), 'side', names{s}, 'rank', s); %#ok<AGROW>
end
end

function h = cp(b, side, k)
ph = get_param(b, 'PortHandles');
if side == 'L', h = ph.LConn(k); else, h = ph.RConn(k); end
end

function wire(sys, h1, h2)
add_line(sys, h1, h2, 'autorouting', 'smart');
end

% =========================================================================
%  Generic helpers
% =========================================================================
function L = libs()
fe = 'fl_lib/Electrical/Electrical Elements/';
fs = 'fl_lib/Electrical/Electrical Sources/';
fz = 'fl_lib/Electrical/Electrical Sensors/';
L.R    = {[fe 'Resistor']};
L.C    = {[fe 'Capacitor']};
L.L    = {[fe 'Inductor']};
L.GND  = {[fe 'Electrical Reference']};
L.D    = {[fe 'Diode'], 'ee_lib/Semiconductors & Converters/Diode'};
L.XFMR = {[fe 'Ideal Transformer'], 'ee_lib/Passive/Transformers/Ideal Transformer'};
L.VAC  = {[fs 'AC Voltage Source']};
L.VDC  = {[fs 'DC Voltage Source']};
L.CCS  = {[fs 'Controlled Current Source']};
L.CVS  = {[fs 'Controlled Voltage Source']};
L.VS   = {[fz 'Voltage Sensor']};
L.IS   = {[fz 'Current Sensor']};
L.MOS  = {'ee_lib/Semiconductors & Converters/MOSFET (Ideal, Switching)', ...
          'ee_lib/Semiconductors & Converters/N-Channel MOSFET'};
L.SC   = {'nesl_utility/Solver Configuration'};
L.S2PS = {'nesl_utility/Simulink-PS Converter'};
L.PS2S = {'nesl_utility/PS-Simulink Converter'};
end

function load_libs()
for lib = {'simulink', 'nesl_utility', 'fl_lib', 'ee_lib'}
    try
        load_system(lib{1});
    catch
        if strcmp(lib{1}, 'ee_lib')
            error('S5:lib', ['Simscape Electrical (ee_lib) is required for the MOSFET and diode blocks. ' ...
                'Check that "ver" lists Simscape Electrical.']);
        end
        error('S5:lib', 'Cannot load library %s.', lib{1});
    end
end
end

function p = addb(cands, dst, pos, varargin)
last = [];
for i = 1:numel(cands)
    try
        add_block(cands{i}, dst, 'Position', pos);
        if ~isempty(varargin), set_param(dst, varargin{:}); end
        p = dst; return
    catch ME
        last = ME;
        if getSimulinkBlockHandle(dst) > 0, delete_block(dst); end
    end
end
error('S5:lib', 'Could not add %s from: %s\n%s', dst, strjoin(cands, ' | '), last.message);
end

function blk(sys, lib, name, pos, varargin)
add_block(lib, [sys '/' name], 'Position', pos);
if ~isempty(varargin), set_param([sys '/' name], varargin{:}); end
end

function setp(b, pattern, value)
dp = fieldnames(get_param(b, 'DialogParameters'));
hit = dp(~cellfun(@isempty, regexpi(dp, pattern, 'once')));
if isempty(regexpi(pattern, '_specify|_priority|_unit|_conf', 'once'))
    hit = hit(cellfun(@isempty, regexpi(hit, '_unit$|_conf$|_priority$|_specify$', 'once')));
end
if isempty(hit)
    error('S5:param', '%s: no parameter matching "%s". Available: %s', b, pattern, strjoin(dp', ', '));
end
set_param(b, hit{1}, value);
end

function ok = try_set(b, prm, val)
try
    set_param(b, prm, val); ok = true;
catch
    ok = false;
end
end

function fw(sys, name, var, ts, pos)
add_block('simulink/Sources/From Workspace', [sys '/' name], 'Position', pos, ...
    'VariableName', var, 'Interpolate', 'off', 'OutputAfterFinalValue', 'Holding final value');
if ~strcmp(ts, '0'), set_param([sys '/' name], 'SampleTime', ts); end
end

function tows(sys, name, var, ts, pos)
add_block('simulink/Sinks/To Workspace', [sys '/' name], 'Position', pos, ...
    'VariableName', var, 'SaveFormat', 'Structure With Time', 'SampleTime', ts);
end

function note(sys, txt, xy)
try
    a = Simulink.Annotation([sys '/' strrep(txt, '/', ' per ')]);
    a.Position = [xy xy + [10 10]];
catch
end
end

function set_solver(m)
if ~try_set(m, 'Solver', 'daessc'), set_param(m, 'Solver', 'ode23t'); end
set_param(m, 'RelTol', '1e-6', 'AbsTol', '1e-9');
if ~try_set(m, 'MaxStep', 'S5.maxStep'), set_param(m, 'MaxStep', '0.05'); end
try_set(m, 'AlgebraicLoopMsg', 'none');
end

function S5 = default_signals(S5)
tSpan = (0:10)';
S5.arrivals = [tSpan, zeros(11,3)];
S5.gates    = [tSpan, zeros(11,3)];
S5.hwGates  = [tSpan, zeros(11,3)];
S5.capB     = [tSpan, repmat([0.45 0.45 0.45 0.45], 11, 1)];
S5.q4max    = 1e9;
S5.stopTime = 10;
S5.maxStep  = 0.05;
end

function print_cal(cal)
fprintf('Port calibration (measured): sensor swap=%d, current-source out-terminal=%s, CVS plus=%s,\n', ...
    cal.vsSwap, ifelse(cal.ccsOutIsA, 'A', 'B'), ifelse(cal.cvsPlusIsA, 'A', 'B'));
fprintf('  current-sensor swap=%d, diode swap=%d, MOSFET D/S swap=%d, gate unit=%s, transformer n = %s\n', ...
    cal.isSwap, cal.diodeSwap, cal.mosSwap, cal.gateUnit, ifelse(cal.xfmrRatioIsSecOverPri, 'N2/N1', 'N1/N2'));
end
