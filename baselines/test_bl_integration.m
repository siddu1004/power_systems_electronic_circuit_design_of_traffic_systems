function pass = test_bl_integration()
%TEST_BL_INTEGRATION  Prove the baseline harness IS the frozen SITRA model.
%
%   1. Runs the frozen part8_mpc_controller.m (unchanged) to get qHist,
%      activeHist and residual.
%   2. Runs SITRA's controller through bl_simulate on scenario T6
%      (same deterministic Part 8 surge, same dt, same q0).
%   3. Requires max|q_harness - qHist| <= 1e-9, identical activeHist,
%      a valid S4 gate vector every step, and conservation.
%   If this passes, the other controllers are being compared on the
%   exact plant that the Simulink S2-S5 stages are validated against.

[~, outDir] = bl_paths();
p = bl_config();
net = createNetwork();

% ---- 1. Frozen reference --------------------------------------------------
ref = runFrozenPart8();

% ---- 2. Harness, SITRA controller, scenario T6 ----------------------------
scn = bl_scenarios(p);
s = scn(strcmp({scn.id}, 'T6'));
A = bl_make_arrivals(s, p, 0);
R = bl_simulate('SITRA', A, p, net);

% ---- 3. Checks ----------------------------------------------------------
errQ   = max(abs(R.qHist(:) - ref.qHist(:)));
sameA  = isequal(R.activeHist(:), ref.activeHist(:));
gatesOK = all(sum(R.gates,2) <= 1) && all(ismember(R.activeHist, 0:3));
errRes = max(abs(R.residual(:)));
errD   = max(abs(R.rate(:) - ref.demandHist(:)));

checks = { ...
  'Queue trajectory = frozen Part 8 qHist (<=1e-9)', errQ <= 1e-9, errQ; ...
  'Active-phase history identical',                  sameA, double(~sameA); ...
  'Demand profile identical',                        errD <= 1e-12, errD; ...
  'S4 gates: at most one on, states in {0..3}',      gatesOK, double(~gatesOK); ...
  'Conservation residual (<=1e-9)',                  errRes <= 1e-9, errRes};

fprintf('\n=== SITRA baseline harness vs frozen Part 8 ===\n');
for i = 1:size(checks,1)
    fprintf('%-50s %s   (%.3e)\n', checks{i,1}, passStr(checks{i,2}), checks{i,3});
end
pass = all([checks{:,2}]);
fprintf('INTEGRATION STATUS = %s\n\n', passStr(pass));

fid = fopen(fullfile(outDir, 'integration_check.txt'), 'w');
for i = 1:size(checks,1)
    fprintf(fid, '%s,%s,%.3e\n', checks{i,1}, passStr(checks{i,2}), checks{i,3});
end
fprintf(fid, 'INTEGRATION STATUS,%s\n', passStr(pass));
fclose(fid);
end

function ref = runFrozenPart8()
% Runs the frozen script in THIS function's workspace, so its 'clear'
% cannot touch the caller.  Its plotting section may differ between
% MATLAB versions/Octave; the numbers are computed before any plotting.
try
    run('part8_mpc_controller.m');
catch err
    if ~exist('qHist','var')
        rethrow(err);
    end
    fprintf('(part8 plotting raised "%s"; numeric results were already computed)\n', err.message);
end
close all;
ref.qHist = qHist;
ref.activeHist = activeHist;
ref.residual = residual;
ref.demandHist = demandHist;
end

function s = passStr(ok)
if ok, s = 'PASS'; else, s = 'FAIL'; end
end
