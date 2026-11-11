function A = bl_make_arrivals(s, p, seed)
%BL_MAKE_ARRIVALS  Arrival sequence for one scenario and one seed.
%
%   A.tVec      1xN time vector 0:dt:T
%   A.rate      Nx3 nominal demand [veh/s] (what controllers may "know")
%   A.count     Nx3 vehicles arriving in [t, t+dt) on B1..B3
%
%   Deterministic scenarios: count = rate*dt (fluid, exactly as Part 8).
%   Stochastic scenarios:    count ~ Poisson(rate*dt).
%
%   The generator is a self-contained Park-Miller LCG in double precision,
%   so MATLAB and Octave produce the SAME arrivals for the same seed.
%   It does not touch MATLAB's global rng, and needs no toolbox.

dt = p.dt;
tVec = 0:dt:s.T;
N = numel(tVec);
rate = zeros(N,3);
for k = 1:N
    rate(k,:) = s.demandFcn(tVec(k));
end

if ~s.stochastic
    count = rate*dt;
else
    x = mod(seed*7919 + 12345, 2147483646) + 1;   % LCG state in [1, 2^31-2]
    count = zeros(N,3);
    for k = 1:N
        for b = 1:3
            lam = rate(k,b)*dt;
            % Poisson by inversion: walk the CDF until it passes u
            [u, x] = lcg(x);
            n = 0; pk = exp(-lam); cdf = pk;
            while u > cdf && n < 50
                n = n + 1;
                pk = pk*lam/n;
                cdf = cdf + pk;
            end
            count(k,b) = n;
        end
    end
end

A.tVec = tVec;
A.rate = rate;
A.count = count;
A.seed = seed;
end

function [u, x] = lcg(x)
x = mod(16807*x, 2147483647);   % exact in doubles (16807*2^31 < 2^53)
u = x/2147483647;
end
