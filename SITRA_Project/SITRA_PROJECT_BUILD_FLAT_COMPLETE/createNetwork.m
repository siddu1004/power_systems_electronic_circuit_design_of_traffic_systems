function net = createNetwork()
%CREATENETWORK  Real 4-junction Peelamedu/SITRA network — structure only.
%
%   PART 1 of the build: topology + capacities. No dynamics, no signal
%   logic, no simulation yet — just the object every later part will
%   read from. Run createNetwork() and inspect the struct before moving
%   to Part 2.
%
%   Topology:
%
%       Hope College --B1--> SITRA --B4--> Goldwins (sink)
%       Kalapatti Rd --B2-->   ^
%       Airport Rd   --B3------|
%
%   SITRA is the one contested node: B1, B2, B3 all feed it, and only
%   B4 carries traffic onward. That makes B4 the structural bottleneck
%   -- matching the real junction's reputation, not assumed for
%   modelling convenience.

net = struct();

net.nodeNames  = {'HopeCollege','Kalapatti','Airport','SITRA','Goldwins'};
net.sourceNodes = [1 2 3];   % HopeCollege, Kalapatti, Airport: demand enters here
net.busNode     = 4;         % SITRA: the contested node
net.sinkNode    = 5;         % Goldwins: traffic leaves the network here

net.branchNames = {'B1 (HopeCollege->SITRA)', 'B2 (Kalapatti->SITRA)', ...
                    'B3 (Airport->SITRA)', 'B4 (SITRA->Goldwins)'};
net.from = [1 2 3 4];
net.to   = [4 4 4 5];
net.nBranches = numel(net.from);
net.nNodes    = numel(net.nodeNames);

% --- Capacities [veh/s] — ASSUMED placeholders, not measured -----------
% Reasoning for each (Section 23 of the handoff doc: every parameter
% must be labeled by provenance; these are all ASSUMED until replaced
% with MEASURED or PUBLISHED values):
%
%   B1 HopeCollege->SITRA  0.65  Main arterial, fed by the GD Naidu
%                                elevated flyover -- assumed the
%                                widest, highest-volume approach.
%   B2 Kalapatti->SITRA    0.35  Secondary feeder road, narrower,
%                                assumed roughly half of B1.
%   B3 Airport->SITRA      0.25  Lowest -- airport-bound traffic is
%                                assumed less continuous than city
%                                arterial flow.
%   B4 SITRA->Goldwins     0.45  Deliberately LESS than B1+B2+B3
%                                (0.65+0.35+0.25 = 1.25), so B4 is the
%                                structural bottleneck by construction
%                                -- consistent with SITRA's reputation
%                                as the chokepoint, not the approaches.
net.capacity = [0.65 0.35 0.25 0.45];

% B4 is the only branch that can ever be signal/contention-limited in
% this first version (only one node -- SITRA -- has more than one
% inbound branch). B1/B2/B3 are only capacity-limited for now.
net.contestedBranch = 4;
net.feedingBranches  = [1 2 3];   % branches competing for B4

end