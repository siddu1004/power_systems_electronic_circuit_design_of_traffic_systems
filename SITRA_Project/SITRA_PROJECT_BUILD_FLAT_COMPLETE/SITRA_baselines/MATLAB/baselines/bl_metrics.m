function M = bl_metrics(R)
%BL_METRICS  Performance measures for one run of bl_simulate.
%
%   avgDelay   [s/veh]  sum_k sum_{B1..B3} q(k)*dt / vehicles that arrived
%                       (signal delay; this is what the HCM LOS uses)
%   netDelay   [s/veh]  same, including the downstream B4 queue
%   avgQueue   [veh]    time-mean of the total B1..B3 queue
%   maxQueue   [veh]    largest single-approach queue (B1..B3) in the run
%   maxQueueB4 [veh]    largest B4 queue
%   throughput [veh]    vehicles that left B4 to Goldwins in the run
%   throughputRate [veh/h]
%   finalQueue [veh]    vehicles still queued (B1..B4) at the end
%   LOS        HCM signalised-intersection level of service from avgDelay
%   maxResidual         conservation check (should be ~1e-15)
%
%   Vehicles still queued at the end count with the delay they have had so
%   far, so oversaturated delays are lower bounds.

dt = R.dt;
veh = sum(R.count(:));
qa = R.qHist(:,1:3);

M.vehicles   = veh;
M.avgDelay   = sum(qa(:))*dt / max(veh, eps);
M.netDelay   = sum(R.qHist(:))*dt / max(veh, eps);
M.avgQueue   = mean(sum(qa,2));
M.maxQueue   = max(qa(:));
M.maxQueueB4 = max(R.qHist(:,4));
M.throughput = sum(R.depHist(:,4))*dt;
M.throughputRate = M.throughput / (numel(R.tVec)*dt) * 3600;
M.finalQueue = sum(R.qFinal);
M.LOS        = bl_hcm_los(M.avgDelay);
M.maxResidual = max(abs(R.residual(:)));
end
