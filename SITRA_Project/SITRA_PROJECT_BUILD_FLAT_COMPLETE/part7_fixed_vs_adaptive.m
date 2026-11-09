%% PART 7 — FIXED-TIME VS ADAPTIVE COMPARISON
clear; clc; close all;

fprintf('\n====================================================\n');
fprintf('PART 7 — FIXED-TIME VS ADAPTIVE COMPARISON\n');
fprintf('====================================================\n');

% Run fixed baseline and capture outputs.
clear adaptiveSignalModel
run('fixedsignalbaseline.m');
qFixed = qHist; tFixed = tVec; totalFixed = sum(qFixed,2);
resFixed = residual;

% Run adaptive controller and capture outputs.
clear adaptiveSignalModel
run('part6_adaptive_controller.m');
qAdaptive = qHist; tAdaptive = tVec; totalAdaptive = sum(qAdaptive,2);
resAdaptive = residual;

if ~isequal(tFixed(:),tAdaptive(:)), error('Time vectors do not match.'); end
surgeStart=200; surgeEnd=400; threshold=5;
before = tFixed < surgeStart; during=tFixed>=surgeStart & tFixed<surgeEnd; after=tFixed>=surgeEnd;

m = @(x,mask) mean(x(mask));
metrics = [m(totalFixed,before) m(totalFixed,during) m(totalFixed,after) max(totalFixed) max(qFixed(:,1)) totalFixed(end) qFixed(end,1); ...
           m(totalAdaptive,before) m(totalAdaptive,during) m(totalAdaptive,after) max(totalAdaptive) max(qAdaptive(:,1)) totalAdaptive(end) qAdaptive(end,1)];

fprintf('\n                          Fixed       Adaptive\n');
fprintf('Mean before surge       %8.3f     %8.3f veh\n',metrics(1,1),metrics(2,1));
fprintf('Mean during surge       %8.3f     %8.3f veh\n',metrics(1,2),metrics(2,2));
fprintf('Mean after surge        %8.3f     %8.3f veh\n',metrics(1,3),metrics(2,3));
fprintf('Maximum total queue     %8.3f     %8.3f veh\n',metrics(1,4),metrics(2,4));
fprintf('Maximum B1 queue        %8.3f     %8.3f veh\n',metrics(1,5),metrics(2,5));
fprintf('Final total queue       %8.3f     %8.3f veh\n',metrics(1,6),metrics(2,6));
fprintf('Final B1 queue          %8.3f     %8.3f veh\n',metrics(1,7),metrics(2,7));

fprintf('\nMaximum residual fixed   = %.3e\n',max(abs(resFixed(:))));
fprintf('Maximum residual adaptive= %.3e\n',max(abs(resAdaptive(:))));
post=tFixed(after); pf=totalFixed(after); pa=totalAdaptive(after);
idxF=find(pf<=threshold,1,'first'); idxA=find(pa<=threshold,1,'first');
recF=NaN; recA=NaN; if ~isempty(idxF),recF=post(idxF)-surgeEnd;end; if ~isempty(idxA),recA=post(idxA)-surgeEnd;end
fprintf('Recovery fixed          = %g s after surge end\n',recF);
fprintf('Recovery adaptive       = %g s after surge end\n',recA);

figure('Name','Part 7 - Total Queue'); plot(tFixed,totalFixed,'LineWidth',1.4); hold on; plot(tAdaptive,totalAdaptive,'LineWidth',1.4); yline(threshold,'--'); xline(surgeStart,'--'); xline(surgeEnd,'--'); hold off; grid on; xlabel('Time [s]'); ylabel('Total Queue [veh]'); title('Part 7 — Fixed-Time vs Adaptive Total Queue'); legend('Fixed','Adaptive','Threshold','Surge Start','Surge End','Location','best');
figure('Name','Part 7 - B1 Queue'); plot(tFixed,qFixed(:,1),'LineWidth',1.4); hold on; plot(tAdaptive,qAdaptive(:,1),'LineWidth',1.4); xline(surgeStart,'--'); xline(surgeEnd,'--'); hold off; grid on; xlabel('Time [s]'); ylabel('B1 Queue [veh]'); title('Part 7 — Fixed-Time vs Adaptive B1 Queue'); legend('Fixed','Adaptive','Surge Start','Surge End','Location','best');
figure('Name','Part 7 - Queue Metrics'); bar(metrics'); grid on; xticklabels({'Mean before','Mean during','Mean after','Peak total','Peak B1','Final total','Final B1'}); ylabel('Queue [veh]'); title('Part 7 — Queue Metric Comparison'); legend('Fixed','Adaptive','Location','best');

pass = max(abs(resFixed(:)))<1e-10 && max(abs(resAdaptive(:)))<1e-10 && metrics(2,2)<metrics(1,2) && metrics(2,4)<metrics(1,4);
fprintf('\nPART 7 VALIDATION = %s\n', iff(pass,'PASS','FAIL'));

function s=iff(tf,a,b), if tf,s=a;else,s=b;end,end
