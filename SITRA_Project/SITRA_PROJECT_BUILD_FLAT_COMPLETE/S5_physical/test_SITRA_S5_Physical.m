%% test_SITRA_S5_Physical.m
% Builds SITRA_S5_Physical.slx and checks it:
%   1. Block audit   - real physical blocks, no code in the physical subsystems,
%                      every physical port wired
%   2. Traffic run   - T6 (Part 8 surge), SITRA gates replayed into the circuit;
%                      capacitor voltages read from the Voltage Sensors vs qRef
%   3. Power run     - AC -> rectifier -> DC-link -> buck -> MOSFET channels,
%                      compressed phase sequence incl. a two-gates-on command
%   4. Figures       - schematic PNGs + result plots in Results/S5_physical
%
% Put this folder (S5_physical) inside SITRA_PROJECT_BUILD_FLAT_COMPLETE.

clc;
clearvars -except rootDir mode tMasterStart s5Dir s6s7Dir flatDir sw sh screen f_act1 f_act2 f_act3 f_act4;
here = fileparts(mfilename('fullpath'));
if isempty(here), here = pwd; end
root = fileparts(here);
if ~exist(fullfile(root, 'baselines'), 'dir')
    candRoot = fullfile(here, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE');
    if exist(candRoot, 'dir')
        root = candRoot;
        here = fullfile(root, 'S5_physical');
    end
end
addpath(here); addpath(root); addpath(genpath(fullfile(root, 'baselines')));
outDir = fullfile(root, 'Results', 'S5_physical');
if ~exist(outDir, 'dir'), mkdir(outDir); end
mdl = 'SITRA_S5_Physical';
pass = struct();

%% 0. Load pre-built model fast (or build if missing)
slxFile = fullfile(here, [mdl '.slx']);
if ~isfile(slxFile)
    info = build_SITRA_S5_Physical();
else
    if ~bdIsLoaded(mdl), load_system(slxFile); end
    S5 = S5_physical_params();
    assignin('base', 'S5', S5);
end
S5 = evalin('base', 'S5');

%% 1. Block audit
phys = {[mdl '/Traffic_Equivalent_Circuit'], [mdl '/Power_Path']};
codeBlocks = 0;
for k = 1:numel(phys)
    sf  = find_system(phys{k}, 'LookUnderMasks', 'none', 'FollowLinks', 'off', 'BlockType', 'S-Function');
    mf  = find_system(phys{k}, 'LookUnderMasks', 'none', 'FollowLinks', 'off', 'SFBlockType', 'MATLAB Function');
    fcn = find_system(phys{k}, 'LookUnderMasks', 'none', 'FollowLinks', 'off', 'BlockType', 'Fcn');
    codeBlocks = codeBlocks + numel(sf) + numel(mf) + numel(fcn);
end
blocksAll = find_system(mdl, 'LookUnderMasks', 'none', 'FollowLinks', 'off', 'Type', 'Block');
ref = get_param(blocksAll, 'ReferenceBlock');
cnt = @(pat) sum(~cellfun(@isempty, regexp(ref, pat, 'once')));
inv = {
  'Capacitor',                 cnt('/Capacitor$'),                 7
  'Controlled Current Source', cnt('Controlled Current[\s\n]+Source'), 7
  'Diode',                     cnt('/Diode$'),                     5
  'MOSFET',                    cnt('MOSFET'),                      4
  'Inductor',                  cnt('/Inductor$'),                  2
  'Ideal Transformer',         cnt('Ideal Transformer$'),          1
  'AC Voltage Source',         cnt('AC Voltage Source$'),          1
  'Voltage Sensor',            cnt('Voltage Sensor$'),             6
  'Current Sensor',            cnt('Current Sensor$'),             4
  'Resistor',                  cnt('/Resistor$'),                  8 };
fprintf('\n=== 1. Block inventory ===\n');
fprintf('%-28s %6s %6s\n', 'Block', 'found', 'min');
invOK = true;
for k = 1:size(inv, 1)
    fprintf('%-28s %6d %6d\n', inv{k, 1}, inv{k, 2}, inv{k, 3});
    invOK = invOK && inv{k, 2} >= inv{k, 3};
end
dangling = 0;
for k = 1:numel(blocksAll)
    ph = get_param(blocksAll{k}, 'PortHandles');
    hs = [ph.LConn(:); ph.RConn(:)];
    for j = 1:numel(hs)
        if get_param(hs(j), 'Line') == -1
            dangling = dangling + 1;
            fprintf('  unconnected physical port on %s\n', blocksAll{k});
        end
    end
end
fprintf('Code blocks inside physical subsystems: %d\n', codeBlocks);
fprintf('Unconnected physical ports: %d\n', dangling);
pass.audit = invOK && codeBlocks == 0 && dangling == 0;

%% 2. Traffic run: T6, SITRA gates replayed
p = bl_config(); net = createNetwork(); scn = bl_scenarios(p);
A = bl_make_arrivals(scn(6), p, 0);
R = bl_simulate('SITRA', A, p, net);
S = bl_export_for_simulink(R);
t0 = S.arrivals(1, 1);
S5.arrivals = [S.arrivals(:, 1) - t0, S.arrivals(:, 2:end)];
S5.gates    = [S.gates(:, 1) - t0,    S.gates(:, 2:end)];
S5.hwGates  = S5.gates;
qRef = S.qRef(:, 2:5);
N = size(qRef, 1);
S5.stopTime = N - 1;
S5.maxStep  = 0.05;
S5.capB     = [(0:N-1)', repmat(net.capacity, N, 1)];
S5.q4max    = 1e9;
assignin('base', 'S5', S5);
set_param([mdl '/Power_Path'], 'Commented', 'on');   % 600 s of 10 kHz PWM is not needed for the traffic check
tic; out = sim(mdl, 'ReturnWorkspaceOutputs', 'on'); tTraffic = toc;
set_param([mdl '/Power_Path'], 'Commented', 'off');

vC = out.S5_vC.signals.values;  tv = out.S5_vC.time;
vC = vC(1:N, :);
err = max(max(abs(vC - qRef)));
arrived = sum(sum(S5.arrivals(1:N-1, 2:4))) * S5.dt;
exitQ = out.S5_exitQ.signals.values(N);
chargeErr = arrived - exitQ - sum(vC(N, :));
viol = sum(out.S5_gateViol.signals.values);
vMin = min(vC(:));
fprintf('\n=== 2. Traffic equivalence (T6, SITRA) ===\n');
fprintf('max |v_C - qRef|          = %.3e V   (pass < 1e-3)\n', err);
fprintf('charge balance error      = %.3e C   (pass < 1e-3)\n', chargeErr);
fprintf('min capacitor voltage     = %.3e V   (pass >= -1e-6)\n', vMin);
fprintf('gate-overlap steps        = %d\n', viol);
fprintf('sim time                  = %.1f s\n', tTraffic);
pass.traffic = err < 1e-3 && abs(chargeErr) < 1e-3 && vMin >= -1e-6 && viol == 0;

%% 3. Power run: compressed phase sequence
seq = [0    0 0 0
       0.25 1 0 0
       0.35 0 0 0
       0.37 0 1 0
       0.47 0 0 0
       0.49 0 0 1
       0.59 0 0 0
       0.62 1 1 0      % illegal: two greens -> interlock must block both
       0.64 0 0 0];
S5.hwGates = seq;
S5.stopTime = 0.7;
S5.maxStep  = 2e-4;
assignin('base', 'S5', S5);
set_param([mdl '/Traffic_Equivalent_Circuit'], 'Commented', 'on'); % isolate Power_Path for fast simulation
tic; outP = sim(mdl, 'ReturnWorkspaceOutputs', 'on'); tPower = toc;
set_param([mdl '/Traffic_Equivalent_Circuit'], 'Commented', 'off');
tp   = outP.S5_vBus.time;
vBus = outP.S5_vBus.signals.values(:);
vDC  = outP.S5_vDC.signals.values(:);
iCh  = outP.S5_iCh.signals.values;
st = tp > S5.par.t_blank;
busMean = mean(vBus(st)); busMin = min(vBus(st)); busMax = max(vBus(st));
Ion = 0.5 * S5.par.V_bus_ref / S5.par.R_load;
cmdAll = interp1(seq(:, 1), seq(:, 2:4), tp, 'previous', 'extrap');
legal = sum(cmdAll, 2) <= 1;
settled = abs(tp - round(tp / 0.01) * 0.01) > 2e-3;   % skip 2 ms around each edge
offLeak = 0; onLow = 0;
for b = 1:3
    offIdx = (cmdAll(:, b) == 0 | ~legal) & settled & st;
    onIdx  = (cmdAll(:, b) == 1 & legal) & settled & st;
    offLeak = max(offLeak, max([0; abs(iCh(offIdx, b))]));
    onLow   = onLow + sum(abs(iCh(onIdx, b)) < Ion);
end
twoOn = sum(sum(abs(iCh) > 1e-3, 2) > 1);
fprintf('\n=== 3. Power path ===\n');
fprintf('DC-link mean (after %.2f s)  = %.2f V\n', S5.par.t_blank, mean(vDC(st)));
fprintf('Bus mean / min / max          = %.2f / %.2f / %.2f V  (ref %.1f, pass +-10%%)\n', busMean, busMin, busMax, S5.par.V_bus_ref);
fprintf('Max channel current while off = %.2e A  (pass < 1e-3)\n', offLeak);
fprintf('Samples below %.2f A while on  = %d\n', Ion, onLow);
fprintf('Samples with two channels on  = %d  (pass 0)\n', twoOn);
fprintf('sim time                      = %.1f s\n', tPower);
pass.power = abs(busMean - S5.par.V_bus_ref) < 0.05 * S5.par.V_bus_ref && ...
             busMin > 0.9 * S5.par.V_bus_ref && busMax < 1.1 * S5.par.V_bus_ref && ...
             offLeak < 1e-3 && onLow == 0 && twoOn == 0;

%% 4. Figures
open_system(mdl);
if ~isfile(fullfile(outDir, 'schematic_top.png')) || ~isfile(fullfile(outDir, 'schematic_power_path.png'))
    try
        print(['-s' mdl], '-dpng', fullfile(outDir, 'schematic_top.png'));
        print(['-s' mdl '/Traffic_Equivalent_Circuit'], '-dpng', fullfile(outDir, 'schematic_traffic_circuit.png'));
        print(['-s' mdl '/Power_Path'], '-dpng', fullfile(outDir, 'schematic_power_path.png'));
    catch ME
        fprintf('Schematic export skipped: %s\n', ME.message);
    end
end
f1 = figure('Visible', 'off');
plot(tv(1:N), vC, 'LineWidth', 1.2); hold on; plot(tv(1:N), qRef, 'k:');
xlabel('t [s]'); ylabel('queue [veh] = capacitor voltage [V]'); grid on;
legend('C_{B1}', 'C_{B2}', 'C_{B3}', 'C_{B4}', 'qRef (Part 8)'); title('Traffic circuit vs Part 8 reference (T6)');
saveas(f1, fullfile(outDir, 'fig_vC_vs_qRef.png'));
f2 = figure('Visible', 'off');
semilogy(tv(1:N), max(abs(vC - qRef), [], 2) + 1e-16); grid on;
xlabel('t [s]'); ylabel('max |v_C - qRef| [V]'); title('Equivalence error');
saveas(f2, fullfile(outDir, 'fig_error.png'));
f3 = figure('Visible', 'off');
subplot(3, 1, 1); plot(tp, vDC); ylabel('V_{DC-link} [V]'); grid on; title('Power path (all values PLACEHOLDER)');
subplot(3, 1, 2); plot(tp, vBus); ylabel('V_{bus} [V]'); grid on;
subplot(3, 1, 3); plot(tp, iCh); ylabel('channel I [A]'); xlabel('t [s]'); grid on; legend('B1', 'B2', 'B3');
saveas(f3, fullfile(outDir, 'fig_power_path.png'));
close([f1 f2 f3]);

%% Summary
fprintf('\n=== SUMMARY ===\n');
fn = fieldnames(pass);
ok = true;
for k = 1:numel(fn)
    fprintf('%-10s %s\n', fn{k}, pf(pass.(fn{k})));
    ok = ok && pass.(fn{k});
end
fprintf('S5 PHYSICAL STATUS = %s\n', pf(ok));
save_system(mdl);
save(fullfile(outDir, 'S5_physical_results.mat'), 'pass', 'err', 'chargeErr', 'viol', ...
    'busMean', 'busMin', 'busMax', 'offLeak', 'twoOn', 'inv');

function s = pf(c)
if c, s = 'PASS'; else, s = 'FAIL'; end
end
