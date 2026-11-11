function g = bl_gates(active)
%BL_GATES  S4 contract: active phase -> gate vector [g1 g2 g3].
%
%   active = 0 (clearance) or 1..3 (B1..B3 green).
%   At most one gate is on.  This is the same mapping the frozen S4
%   switching stage uses, so every baseline drives the S5 electrical
%   stage through the identical interface.

g = double([active==1, active==2, active==3]);
assert(sum(g) <= 1, 'bl_gates: more than one gate on (active = %g)', active);
end
