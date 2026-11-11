function S = bl_export_for_simulink(R, matFile)
%BL_EXPORT_FOR_SIMULINK  Turn a baseline run into From Workspace signals.
%
%   S = bl_export_for_simulink(R)            returns the struct
%   S = bl_export_for_simulink(R, 'x.mat')   also saves it
%
%   Lets any baseline controller drive the existing Simulink stages in
%   place of the SITRA MPC, without editing S1-S4:
%     S.active   [t active]        -> S2 queue plant 'active' input
%                                     (same as test_SITRA_S2 uses activeHist)
%     S.gates    [t g1 g2 g3]      -> S5 electrical stage gate inputs
%     S.arrivals [t a1 a2 a3]      -> S2/S5 arrival current sources [veh/s = A]
%     S.qRef     [t q1 q2 q3 q4]   -> S10/S11 comparison reference (capacitor V)
%   Use a From Workspace block with Interpolate data = off and
%   Form output after final data value = Holding final value, sample
%   time 1 s, so the signals are zero-order held like the traffic blocks.

t = R.tVec(:);
S.active   = [t, R.activeHist(:)];
S.gates    = [t, R.gates];
S.arrivals = [t, R.count / R.dt];
S.qRef     = [t, R.qHist];
S.controller = R.controller;
S.seed = R.seed;

if nargin > 1 && ~isempty(matFile)
    save(matFile, '-struct', 'S');
end
end
