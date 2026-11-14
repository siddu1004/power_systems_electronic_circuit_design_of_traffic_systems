"""Robust per-lane queue estimator for the SUMO port (v11).

Sensors (as deployed): a CCTV camera at each stop line seeing the last 60 m of
every approach lane, plus vehicle counts at lane entry and stop line (the
neighbouring junctions' cameras / loops). The camera is imperfect:
  * 8 % multiplicative noise,
  * occlusion: each visible bus/truck hides ~0.3 W behind it,
  * outliers: 2 % of readings are garbage (x0 .. x3),
  * view limit: a queue longer than 60 m is only seen as "view full",
  * failures: dead (no reading) or frozen (same value repeated).

Estimator (one scalar Kalman filter per lane, weight units W):
  predict   Q- = clip(Q + arrivals that reach the stop line now - departures, 0, cap)
            (arrivals = entry counts delayed by the lane's free travel time: KCL)
  update    camera z, R = (0.08 z + 0.15)^2 + occlusion term
            * view full  -> inequality update Q = max(Q-, z)      (v6 lower bound)
            * gate       -> nu^2 / S > 9 rejects the reading        (v4 bad-data test)
            * Huber      -> large but accepted innovations are down-weighted
            * frozen     -> identical readings for 60 s while vehicles move = camera suspect
            * dead       -> predict only (KCL rebuild from neighbours' counts, v5)
Movement split: the lane estimate is split by the turn mix of vehicles in view,
or by the lane's running turn mix when none is visible.
"""
from collections import defaultdict, deque

import numpy as np

VIEW_M = 60.0
W_PER_M = 0.075


class RobustQueueEstimator:
    def __init__(self, tc, lanes, rng, weight, speed_of):
        self.tc, self.rng, self.weight = tc, rng, weight
        self.lanes = list(lanes)
        self.L = {l: tc.lane.getLength(l) for l in self.lanes}
        self.cap = {l: max(1.0, self.L[l] * W_PER_M * 1.2) for l in self.lanes}
        self.D = {l: self.L[l] / max(speed_of(l), 1.0) for l in self.lanes}
        self.Q = defaultdict(float)
        self.P = defaultdict(lambda: 1.0)
        self.buf = {l: deque() for l in self.lanes}
        self.prev = {l: set() for l in self.lanes}
        self.mix = defaultdict(dict)                 # lane -> {next_edge: share}
        self.last_z = {}
        self.same_since = {}
        self.suspect = set()
        self.dead = set()
        self.err_est, self.err_cam, self.n_rej = [], [], 0

    def camera(self, l, vis_q, vis_heavy, full):
        if l in self.dead:
            return None
        z = max(0.0, vis_q - 0.3 * vis_heavy) * (1 + 0.08 * self.rng.standard_normal())
        if self.rng.random() < 0.02:
            z *= 3.0 * self.rng.random()
        return max(0.0, z)

    def step(self, t, truth_q, vis):
        """truth_q[l]: true weighted queue (scoring only); vis[l] = (visible queue W, heavy vehicles
        in view, view full, {next edge: W in view}). Returns {lane: Qhat}."""
        tc = self.tc
        for l in self.lanes:
            ids = set(tc.lane.getLastStepVehicleIDs(l))
            ent = ids - self.prev[l]
            lef = self.prev[l] - ids
            self.prev[l] = ids
            win = sum(self.weight(v) for v in ent if self.rng.random() > 0.03)   # 3 % missed counts
            wout = sum(self.weight(v) for v in lef if self.rng.random() > 0.03)
            if win:
                self.buf[l].append((t + self.D[l], win))
            arr = 0.0
            while self.buf[l] and self.buf[l][0][0] <= t:
                arr += self.buf[l].popleft()[1]
            q = min(self.cap[l], max(0.0, self.Q[l] + arr - wout))
            P = self.P[l] + 0.05 + 0.02 * (arr + wout)
            vq, nh, full, comp = vis.get(l, (0.0, 0, False, {}))
            z = self.camera(l, vq, nh, full)
            if z is not None:                                    # frozen-camera test
                if l in self.last_z and abs(z - self.last_z[l]) < 1e-9 and (win or wout):
                    if t - self.same_since.get(l, t) >= 60:
                        self.suspect.add(l)
                else:
                    self.same_since[l] = t
                    self.suspect.discard(l)
                self.last_z[l] = z
            if z is not None and l not in self.suspect:
                if full:
                    q = max(q, z)                                # lower-bound (inequality) update
                    P = max(P, 0.5)
                else:
                    R = (0.08 * z + 0.15) ** 2 + (0.3 * nh) ** 2
                    S = P + R
                    nu = z - q
                    if nu * nu / S > 9.0:
                        self.n_rej += 1                          # bad data rejected
                    else:
                        k = P / S
                        hub = 1.0 if abs(nu) <= 2.0 * np.sqrt(S) else 2.0 * np.sqrt(S) / abs(nu)
                        q = q + k * hub * nu
                        P = (1 - k * hub) * P
            self.Q[l], self.P[l] = min(self.cap[l], max(0.0, q)), P
            if comp:
                tot = sum(comp.values())
                m = self.mix[l]
                for e, w in comp.items():
                    m[e] = 0.9 * m.get(e, 0.0) + 0.1 * w / tot
                for e in list(m):
                    if e not in comp:
                        m[e] *= 0.9
            if t % 10 == 0 and l in truth_q:
                self.err_est.append(self.Q[l] - truth_q[l])
                if z is not None:
                    self.err_cam.append(min(z, self.cap[l]) - truth_q[l])
        return self.Q

    def split(self, l, nxt):
        m = self.mix.get(l)
        if not m:
            return None
        tot = sum(m.values())
        return m.get(nxt, 0.0) / tot if tot > 0 else None

    def rmse(self):
        e = np.array(self.err_est) if self.err_est else np.zeros(1)
        c = np.array(self.err_cam) if self.err_cam else np.zeros(1)
        return float(np.sqrt((e ** 2).mean())), float(np.sqrt((c ** 2).mean()))
