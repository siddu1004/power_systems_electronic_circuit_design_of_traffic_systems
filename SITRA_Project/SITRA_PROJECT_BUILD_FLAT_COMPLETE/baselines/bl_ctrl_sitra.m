function [active, st] = bl_ctrl_sitra(t, q, info, st, p, net)
%BL_CTRL_SITRA  SITRA's own controller, unchanged: frozen MPC (S3) + S4.
%
%   Calls the frozen mpcSignalModel.m exactly as part8_mpc_controller.m
%   does, with the Part 8 parameters, the current queue vector and the
%   nominal demand rate.  The S4 stage then maps 'active' to the gates
%   (see bl_gates).  Nothing in the frozen files is modified.
%
%   Common controller interface (all bl_ctrl_* files):
%     t    current time [s]
%     q    1x4 queue vector at t [veh]
%     info .rate     1x3 nominal demand at t [veh/s]
%          .vehPrev  1x3 whole vehicles that crossed the detector last step
%          .design   1x3 design demand for fixed-time plans [veh/s]
%     st   controller state ([] on the first call)
%   Returns active = 0 (clearance) or 1..3, and the updated state.

if isempty(st)
    st.name = 'SITRA';
    st.greenHist = [];
end
[active, greenTimes] = mpcSignalModel(t, q, net, p.mpc, info.rate);
st.lastGreen = greenTimes;
end
