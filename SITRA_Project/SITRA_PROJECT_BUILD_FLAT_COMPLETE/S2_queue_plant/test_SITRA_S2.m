%% test_SITRA_S2.m
% S2 validation: drives the Simulink queue plant with the FROZEN Part 8
% active-phase history and compares against Part 8's qHist / demand / residual.
% Run from the project root after build_SITRA_S2 (and after setup_SITRA_folders).

rootDir = 'C:\Users\Sreedev\OneDrive\Desktop\Sreedev\pe lab\peproject\SITRA_PROJECT_BUILD_FLAT_COMPLETE\SITRA_Project\SITRA_PROJECT_BUILD_FLAT_COMPLETE';

addpath(rootDir);
addpath(fullfile(rootDir,'SITRA_S2_extracted'));

% 1) frozen reference (it begins with CLEAR, so define everything after it)
run(fullfile(rootDir,'part8_mpc_controller.m'));
refQ = qHist;  refActive = activeHist(:);  refDemand = demandHist;
refRes = residual;  refT = tVec(:);
close all;

% 2) harness copy of the model: replace Switching->Queue line with recorded active
mdl = 'SITRA_Traffic_Hardware';  tst = 'SITRA_S2_test';
load_system(mdl);
if bdIsLoaded(tst), close_system(tst,0); end
save_system(mdl, tst);          % save-as: the open model is now SITRA_S2_test
delete_line(tst,'04_Switching_Logic/1','02_Traffic_Queue_Plant/2');

add_block('simulink/Sources/From Workspace',[tst '/RecordedActive'], ...
    'VariableName','activeTS','SampleTime','1','Interpolate','off', ...
    'OutputAfterFinalValue','Holding final value','Position',[480 380 560 410]);


add_line(tst,'RecordedActive/1','02_Traffic_Queue_Plant/2');
activeTS = timeseries([refActive; refActive(end)], ...
                      [refT; refT(end)+1]);
assignin('base','activeTS',activeTS);

% 3) simulate
out = sim(tst,'StopTime','600');
q   = squeeze(out.s2_q);   if size(q,1)==4, q = q.'; end
res = squeeze(out.s2_res); if size(res,1)==4, res = res.'; end
d   = squeeze(out.s2_demand); if size(d,1)==3, d = d.'; end

% 4) compare
n = min(size(q,1), size(refQ,1));
eQ   = max(abs(q(1:n,:)   - refQ(1:n,:)),[],'all');
eD   = max(abs(d(1:n,:)   - refDemand(1:n,:)),[],'all');
eRes = max(abs(res(1:n,:) - refRes(1:n,:)),[],'all');
tol = 1e-9;
ok = [size(q,1)==size(refQ,1), eQ<tol, eD<tol, eRes<tol, all(q(:)>=0)];

fprintf('\n====================================================\n');
fprintf('S2 TRAFFIC / QUEUE PLANT VALIDATION\n');
fprintf('====================================================\n');
fprintf('Samples (sim / ref)            = %d / %d   %s\n', size(q,1), size(refQ,1), pf(ok(1)));
fprintf('max |q_sim - qHist|            = %.3e   %s\n', eQ,   pf(ok(2)));
fprintf('max |demand_sim - demandHist|  = %.3e   %s\n', eD,   pf(ok(3)));
fprintf('max |res_sim - residual|       = %.3e   %s\n', eRes, pf(ok(4)));
fprintf('queues non-negative            =             %s\n', pf(ok(5)));
fprintf('peak total queue sim / ref     = %.3f / %.3f veh\n', max(sum(q,2)), max(sum(refQ,2)));
fprintf('----------------------------------------------------\n');
fprintf('S2 OVERALL = %s\n', pf(all(ok)));
fprintf('(Record this in BUILD_LOG.md only after you also inspect the plot.)\n');

figure('Name','S2 queue plant vs Part 8');
subplot(2,1,1); plot(refT(1:n), sum(refQ(1:n,:),2),'k','LineWidth',1.6); hold on;
plot(refT(1:n), sum(q(1:n,:),2),'r--','LineWidth',1.2); grid on;
legend('Part 8 (MATLAB)','S2 (Simulink)'); ylabel('total queue [veh]'); title('Total queue');
subplot(2,1,2); plot(refT(1:n), q(1:n,:)-refQ(1:n,:)); grid on;
xlabel('time [s]'); ylabel('error [veh]'); title('Per-branch queue error (should be 0)');

function s = pf(tf), if tf, s='PASS'; else, s='FAIL'; end, end
