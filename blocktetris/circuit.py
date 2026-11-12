"""Electrical-equivalent network solver (the "e-twin").

Every traffic element is replaced by its circuit component and the network is
integrated as a switched circuit (explicit Euler, dt = 1 s). Charge unit = 1
weight unit W (spec voltage); current = W/s.

  Movement queue (turn pocket) ........ capacitor C, voltage V = stored weight
  Green tap ........................... MOSFET: saturation current I_sat when
                                        V > V_knee, linear region below
  Start-up lost time .................. gate turn-on delay (Miller plateau)
  Road ................................ ideal delay line (travel time) + storage
  Road capacity / spillback ........... Zener clamp: no current into a full line
  Shared lane before pockets .......... series bottleneck: a full pocket blocks
                                        the whole arm (head-of-line blocking)
  Exit to the outside world ........... current-limited load
  Gate (vehicles waiting to enter) .... unbounded source capacitor
  Pressure alarm / recovery ........... relay with per-hop attenuation, soft start

Topology: any rows x cols grid of 4-arm junctions with an optional mask, so
the 5-junction chowrasta is the 3x3 grid without corners.
"""
import numpy as np

from .geometry import MOVES, PHASES, SPLIT_PHASES

DT = 1.0
W_PER_M = 0.075            # mean weight per metre of queue (mix 45/15/30/10)
TAU_TRUE = 4.62            # s per weight unit per lane (hidden ground truth)
TURN_F = np.array([1.05, 1.0, 1.15, 1.6])        # L S R U
LANES = np.array([1.0, 2.0, 1.0, 1.0])
POCKET = np.array([40, np.inf, 40, 15]) * W_PER_M
RATIO = np.array([0.25, 0.50, 0.20, 0.05])
V_KNEE = 0.4               # W: below this the tap runs in its linear region
STARTUP = 2.5
CLEAR = 5.0
G_MIN, G_MAX = 15.0, 70.0
BLOCK_W = 0.55             # weight of a 7.5 m block
_DR = {0: (-1, 0), 1: (0, 1), 2: (1, 0), 3: (0, -1)}

PM = np.zeros((len(PHASES), 16), bool)
for _p, _ph in enumerate(PHASES):
    PM[_p, list(_ph)] = True
SPLIT_IDX = [PHASES.index(next(p for p in PHASES if s <= p)) for s in SPLIT_PHASES]

DEFAULT_OPTS = dict(alarm_on=0.80, alarm_off=0.60, attenuation=0.5, ramp=0.02, a_age=0.01,
                    max_wait=150.0, rate_alarm=False, rate_horizon=60.0, gridlock_guard=False,
                    perimeter=False, n_crit=0.35, n_band=0.25, fill_limit=1.0,
                    rate_rolling=False, sat_gmin=15.0, hol_low=False,
                    backpressure=False, bp_exp=2.0, emergency=False, em_on=0.50, em_off=0.40,
                    em_green=40.0, em_actuated=False, divert=False, compliance=0.7,
                    divert_on=0.9, divert_off=0.4,
                    estimator="oracle", atc=False, atc_apply=False, atc_depth=3, atc_H=120.0,
                    sensor_cover=0.5, sensor_sigma=3.0, count_noise=0.05, stuck=2, phantom_p=0.002)


class Net:
    def __init__(self, rows, cols, mask=None, link_m=300.0, lanes=2, speed=8.33):
        mask = np.ones((rows, cols), bool) if mask is None else np.asarray(mask, bool)
        pos = [(r, c) for r in range(rows) for c in range(cols) if mask[r, c]]
        jid = {p: i for i, p in enumerate(pos)}
        self.J = len(pos)
        self.pos = pos
        cap0, src, dst, kind = [], [], [], []
        self.out_line = -np.ones((self.J, 4), int)
        self.in_line = -np.ones((self.J, 4), int)

        def add(c, s, d, k):
            cap0.append(c); src.append(s); dst.append(d); kind.append(k)
            return len(cap0) - 1

        cap = link_m * lanes * W_PER_M
        for (r, c), j in jid.items():
            for a in range(4):
                dr, dc = _DR[a]
                nb = jid.get((r + dr, c + dc))
                if nb is not None:
                    l = add(cap, (j, a), (nb, (a + 2) % 4), "inner")
                    self.out_line[j, a] = l
                    self.in_line[nb, (a + 2) % 4] = l
                else:
                    self.in_line[j, a] = add(cap, (-1, -1), (j, a), "gate")
                    self.out_line[j, a] = add(cap, (j, a), (-1, -1), "sink")
        self.L = len(cap0)
        self.cap0 = np.array(cap0)
        self.src, self.dst, self.kind = src, dst, np.array(kind)
        self.D = int(round(link_m / speed))
        self.G = self.J * 16
        m_arm = np.array([MOVES[m][0] for m in range(16)])
        m_turn = np.array([m % 4 for m in range(16)])
        m_to = np.array([MOVES[m][2] for m in range(16)])
        self.g_j = np.repeat(np.arange(self.J), 16)
        self.g_turn = np.tile(m_turn, self.J)
        self.g_lanes = LANES[self.g_turn]
        self.g_pocket = POCKET[self.g_turn]
        self.g_exit = np.array([self.out_line[j, m_to[m]] for j in range(self.J) for m in range(16)])
        self.g_in = np.array([self.in_line[j, m_arm[m]] for j in range(self.J) for m in range(16)])
        self.line_moves = -np.ones((self.L, 4), int)
        for l in range(self.L):
            j, a = self.dst[l]
            if j >= 0:
                self.line_moves[l] = j * 16 + a * 4 + np.arange(4)
        self.gates = np.where(self.kind == "gate")[0]
        self.sinks = np.where(self.kind == "sink")[0]
        self.inner = np.where(self.kind == "inner")[0]
        self.down_out = []
        for l in range(self.L):
            j, a = self.dst[l]
            self.down_out.append([self.out_line[j, b] for b in range(4) if b != a] if j >= 0 else [])

    @staticmethod
    def chowrasta():
        return Net(3, 3, mask=[[0, 1, 0], [1, 1, 1], [0, 1, 0]])

    def line_name(self, l):
        s, d = self.src[l], self.dst[l]
        f = "IN" if s[0] < 0 else "J%d%d" % self.pos[s[0]]
        to = "OUT" if d[0] < 0 else "J%d%d" % self.pos[d[0]]
        return f"{f}->{to}"


class Incident:
    """kind: line_block (crash at the end of a road), sink_cut (exit accepts 5 %),
    gate_surge (demand x mult), slow (approach saturation current x mult)."""

    def __init__(self, kind, target, t0=1200, t1=2100, mult=None):
        self.kind, self.target, self.t0, self.t1 = kind, target, t0, t1
        self.mult = mult if mult is not None else {"gate_surge": 2.2, "sink_cut": 0.05, "slow": 0.45}.get(kind, 0.0)

    def on(self, t):
        return self.t0 <= t < self.t1


class CircuitSim:
    def __init__(self, net, ctrl, seed=1, demand=0.069, horizon=5400, incident=None, opts=None,
                 sink_rate=0.55, record=False):
        self.n, self.ctrl, self.T, self.inc = net, ctrl, horizon, incident
        self.rng = np.random.default_rng(seed)
        self.opts = dict(DEFAULT_OPTS)
        self.opts.update(opts or {})
        n = net
        self.V = np.zeros(n.G)
        self.ring = np.zeros((n.L, n.D))
        self.head = 0
        self.entry = np.zeros(n.L)
        self.gateq = np.zeros(n.L)
        self.lam = np.zeros(n.L)
        self.lam[n.gates] = demand
        self.noise = np.zeros(n.L)
        self.sink_rate = np.full(n.L, sink_rate)
        self.isat_mult = np.ones(n.G)
        self.green = np.zeros(n.G, bool)
        self.startup = np.zeros(n.G)
        self.last_served = np.zeros(n.G)
        self.blocked_now = np.zeros(n.G, bool)
        self.discharged = np.zeros(n.G)
        self.state = ["C"] * n.J
        self.c_end = np.full(n.J, CLEAR)
        self.phase = np.full(n.J, -1)
        self.nxt = np.array([SPLIT_IDX[0]] * n.J)
        self.g_start = np.zeros(n.J)
        self.planned = np.full(n.J, 40.0)
        self.k_fixed = np.zeros(n.J, int)
        self.blocked_run = np.zeros(n.J)
        self.tau = np.full((n.J, 4), 2.0)   # spec start value, learned online
        self.p = np.zeros(n.L)
        self.latched = np.zeros(n.L, bool)
        self.prev_load = np.zeros(n.L)
        self.arrived = 0.0
        self.served_out = 0.0
        self.stored_int = 0.0
        self.series = []
        self.record = record
        self.load_series, self.p_series = [], []
        self.spill = 0
        self._full = np.zeros(n.L, bool)
        self._load_now = np.zeros(n.L)
        self.em = False
        self.em_seconds = 0
        self.c_in = np.zeros(n.L)
        self.c_out = np.zeros(n.L)
        self.est = None
        o = self.opts
        if ctrl == "bt" and (o["estimator"] != "oracle" or o["atc"]):
            from .network_state import NetState
            self.est = NetState(self, mode=o["estimator"], coverage=o["sensor_cover"],
                                sigma=o["sensor_sigma"], count_noise=o["count_noise"], stuck=o["stuck"],
                                phantom_p=o["phantom_p"], seed=seed + 99, H=o["atc_H"], depth=o["atc_depth"])
        self.occ_c = np.zeros(n.L)
        self.est_err2, self.est_n = 0.0, 0
        self.raw_err2 = 0.0
        self.warn_start = {}
        self.warn_eps = []          # (line, start, end)
        self.spill_events = []      # (line, t)
        self.leads = []
        self.ratio = np.tile(RATIO, (n.L, 1))      # turn split of each road's arrivals
        self.diverted = np.zeros(n.L, bool)        # exit roads under a diversion order

    def occ(self):
        n = self.n
        o = self.ring.sum(1) + self.entry
        has = n.line_moves[:, 0] >= 0
        o[has] += self.V[n.line_moves[has]].sum(1)
        return o

    def step(self, t):
        n, inc = self.n, self.inc
        lam = self.lam.copy()
        sink_rate = self.sink_rate.copy()
        blocked_line = -1
        self.isat_mult[:] = 1.0
        if inc and inc.on(t):
            if inc.kind == "gate_surge":
                lam[inc.target] *= inc.mult
            elif inc.kind == "sink_cut":
                sink_rate[inc.target] *= inc.mult
            elif inc.kind == "line_block":
                blocked_line = inc.target
            elif inc.kind == "slow":
                j, a = inc.target
                self.isat_mult[j * 16 + a * 4: j * 16 + a * 4 + 4] = inc.mult
        # 1. current sources with correlated (AR(1)) demand noise
        self.noise = 0.97 * self.noise + 0.0851 * self.rng.normal(size=n.L)
        inj = lam * np.clip(1 + self.noise, 0, None) * DT
        self.gateq += inj
        self.arrived += inj.sum()
        occ = self.occ()
        occ_c = self.occ_c if self.est is not None else occ
        g = n.gates
        meter = 1.0
        if self.ctrl == "bt" and self.opts["perimeter"]:
            # load shedding at the network boundary: meter entry when interior accumulation is critical
            acc = occ_c[n.inner].sum() / n.cap0[n.inner].sum()
            self.acc = acc
            meter = float(np.clip(1 - (acc - self.opts["n_crit"]) / self.opts["n_band"], 0.05, 1.0))
        meter = np.full(len(g), meter)
        if self.est is not None and self.opts["atc"] and self.opts["atc_apply"]:
            # look-ahead gate metering: admit no more than the road's 3-level acceptance rate
            meter = np.minimum(meter, np.clip(self.est.A[g], 0.05, 1.0))
        mv = np.minimum(np.minimum(self.gateq[g], np.clip(n.cap0[g] - occ[g], 0, None)), 1.0 * DT * meter)
        self.c_in[g] += mv
        self.gateq[g] -= mv
        tail = (self.head - 1) % n.D
        self.ring[g, tail] += mv
        # 2. delay lines deliver
        self.entry += self.ring[:, self.head]
        self.ring[:, self.head] = 0.0
        self.head = (self.head + 1) % n.D
        # 3. shared section -> pockets (head-of-line blocking)
        lm = n.line_moves
        has = np.where(lm[:, 0] >= 0)[0]
        Vm = self.V[lm[has]]
        R = self.ratio[has]
        headroom = np.where(R > 1e-9, (n.g_pocket[lm[has]] - Vm) / np.maximum(R, 1e-9), np.inf)
        x = np.minimum(self.entry[has], np.clip(headroom.min(1), 0, None))
        if blocked_line >= 0:
            x[has == blocked_line] = 0.0
        self.entry[has] -= x
        np.add.at(self.V, lm[has].ravel(), (x[:, None] * R).ravel())
        # 4. current-limited exits
        s = n.sinks
        sr = sink_rate[s].copy()
        sr[s == blocked_line] = 0.0
        d = np.minimum(self.entry[s], sr * DT)
        self.entry[s] -= d
        self.c_out[s] += d
        self.served_out += d.sum()
        # 5. network layer, learning, controllers, interlock
        occ = self.occ()
        load = occ / n.cap0
        occ_c = occ
        if self.est is not None:
            occ_c = self.est.update(t, occ, self.c_in, self.c_out)
            self.c_in[:] = 0.0
            self.c_out[:] = 0.0
            if self.opts["atc"]:
                self.est.atc(self.ratio, self.gateq)
                self._track_warnings(t, load)
            e = occ_c[n.inner] - occ[n.inner]
            self.est_err2 += float((e ** 2).sum())
            self.est_n += len(e)
            self.occ_c = occ_c.copy()
        load_c = occ_c / n.cap0
        self._load_now = load_c
        if self.ctrl == "bt":
            self._pressure(load_c)
            self._learn()
            if self.opts["divert"]:
                self._divert()
            if self.opts["emergency"]:
                acc = occ_c[n.inner].sum() / n.cap0[n.inner].sum()
                if acc >= self.opts["em_on"]:
                    self.em = True
                elif acc <= self.opts["em_off"]:
                    self.em = False
        for j in range(n.J):
            self._interlock(j, t, occ_c)
        # 6. MOSFET taps discharge into Zener-clamped lines
        gi = np.where(self.green)[0]
        on = gi[self.startup[gi] <= 0]
        self.startup[gi] = np.maximum(0, self.startup[gi] - DT)
        tail = (self.head - 1) % n.D
        isat = n.g_lanes[on] / (TAU_TRUE * TURN_F[n.g_turn[on]]) * self.isat_mult[on] \
            * (1 + 0.1 * self.rng.normal(size=len(on)))
        want = np.minimum(self.V[on], isat * np.minimum(1.0, self.V[on] / V_KNEE) * DT)
        self.blocked_now[:] = False
        self.discharged[:] = 0.0
        for k, gg in enumerate(on):
            ex = n.g_exit[gg]
            q = min(want[k], max(0.0, n.cap0[ex] - occ[ex]))
            if q < want[k] - 1e-9:
                self.blocked_now[gg] = True
            if q > 0:
                self.V[gg] -= q
                self.ring[ex, tail] += q
                occ[ex] += q
                occ[n.g_in[gg]] -= q
                self.c_in[ex] += q
                self.c_out[n.g_in[gg]] += q
                self.last_served[gg] = t
                self.discharged[gg] = q
        # 7. metrics
        self.em_seconds += int(self.em)
        stored = self.V.sum() + self.entry.sum() + self.gateq.sum()
        self.stored_int += stored * DT
        full = load >= 0.95
        new = np.where(full & ~self._full)[0]
        for l in new:
            if n.kind[l] == "inner":
                self.spill_events.append((int(l), t))
                ws = self.warn_start.get(int(l))
                self.leads.append(t - ws if ws is not None else 0.0)
        self.spill += int((full & ~self._full).sum())
        self._full = np.where(load < 0.85, False, self._full | full)
        if t % 5 == 0:
            self.series.append(float(stored))
            if self.record and t % 10 == 0:
                self.load_series.append(load.copy())
                self.p_series.append(self.p.copy())

    # ── network layer: relay with attenuation, hysteresis, soft-start ───────
    def _pressure(self, load):
        o, n = self.opts, self.n
        on, off = o["alarm_on"], o["alarm_off"]
        rise = (load - self.prev_load) / DT
        self.prev_load = load
        trig = load >= on
        if o["rate_alarm"]:
            trig |= (load + rise * o["rate_horizon"] >= on) & (load >= 0.5)
        self.latched = np.where(trig, True, np.where(load < off, False, self.latched))
        local = np.where(self.latched, np.clip((load - off) / (1 - off), 0.15, 1.0), 0.0)
        prop = np.array([max((self.p[x] for x in n.down_out[l]), default=0.0) for l in range(n.L)])
        target = np.maximum(local, o["attenuation"] * prop)
        self.p = np.where(target >= self.p, target, np.maximum(target, self.p - o["ramp"]))

    def _divert(self):
        """Diversion orders (VMS / police): when an exit road trips, the share of
        approaching traffic that wanted it is re-routed to the other exits
        (current redistributes over parallel paths). Partial compliance."""
        n, o = self.n, self.opts
        for l in range(n.L):
            if n.src[l][0] < 0:
                continue
            if not self.diverted[l] and self.p[l] >= o["divert_on"]:
                self.diverted[l] = True
            elif self.diverted[l] and self.p[l] <= o["divert_off"]:
                self.diverted[l] = False
        for l in range(n.L):
            j, a = n.dst[l]
            if j < 0:
                continue
            r = RATIO.copy()
            for k in range(4):
                b = MOVES[a * 4 + k][2]
                if self.diverted[n.out_line[j, b]] and b != a:
                    moved = r[k] * o["compliance"]
                    r[k] -= moved
                    ok = [i for i in range(4) if i != k and not self.diverted[n.out_line[j, MOVES[a * 4 + i][2]]]]
                    if ok:
                        w = RATIO[ok] / RATIO[ok].sum()
                        r[ok] += moved * w
                    else:
                        r[k] += moved
            self.ratio[l] = r

    def _learn(self):
        """tau from the measured saturation current of each unblocked tap."""
        n, d = self.n, self.discharged
        ok = np.where((d > 0) & ~self.blocked_now & (self.V > V_KNEE))[0]
        for gg in ok:
            j, k = n.g_j[gg], n.g_turn[gg]
            meas = n.g_lanes[gg] * DT / d[gg] / TURN_F[k]
            self.tau[j, k] += 0.05 * (meas - self.tau[j, k])

    # ── controllers ─────────────────────────────────────────────────────────
    def _hol_V(self, j):
        """Charge stuck in an arm's shared section is charged to the pocket
        that blocks it (fault current traced to the faulted element)."""
        n = self.n
        V = self.V[j * 16:j * 16 + 16].copy()
        for a in range(4):
            e = self.entry[n.in_line[j, a]]
            if e > 1e-6:
                g = slice(a * 4, a * 4 + 4)
                head = (POCKET - V[g]) / RATIO
                V[a * 4 + int(np.argmin(head))] += e
        return V

    def _scores(self, j, t, occ):
        n, o = self.n, self.opts
        sl = slice(j * 16, j * 16 + 16)
        V = self._hol_V(j)
        ex = n.g_exit[sl]
        room = n.cap0[ex] - occ[ex]
        if self.ctrl == "maxp":
            w = np.clip(V - 0.25 * occ[ex] / 2.0, 0, None) * n.g_lanes[sl]
            return np.where(room > BLOCK_W, w, 0.0), None
        age = np.where(V > 0.05, t - self.last_served[sl], 0.0)
        score = (V + o["a_age"] * (V / BLOCK_W) * age) * (1.0 - self.p[ex])
        if o["atc"] and o["atc_apply"] and self.est is not None:
            score *= self.est.phi[ex]             # look-ahead inflow throttle (2-3 hops)
        if o["backpressure"]:
            # smooth back-pressure: value of sending charge falls as the receiving line fills
            score *= np.clip(1.0 - (occ[ex] / n.cap0[ex]) ** o["bp_exp"], 0.0, 1.0)
        if o["fill_limit"] < 1.0:
            inner = n.kind[ex] == "inner"
            room = np.where(inner, n.cap0[ex] * o["fill_limit"] - occ[ex], room)
        elig = (room >= BLOCK_W) & (V > 0.05)
        if o["gridlock_guard"]:
            elig &= ~np.array([self._line_stuck(e) for e in ex])
        score = np.where(elig, score, 0.0)
        tau = self.tau[j, n.g_turn[sl]] * TURN_F[n.g_turn[sl]]
        drain = np.minimum(V, np.clip(room, 0, None)) * tau / n.g_lanes[sl]
        T = (STARTUP + 1.15 * drain) * (1 - 0.5 * self.p[ex])
        return score, (T, elig, age)

    def _track_warnings(self, t, load):
        w = self.est.warn
        for l in self.n.inner:
            l = int(l)
            if w[l] and l not in self.warn_start:
                self.warn_start[l] = t
            elif not w[l] and l in self.warn_start:
                self.warn_eps.append((l, self.warn_start.pop(l), t))

    def warning_stats(self, follow=300):
        eps = self.warn_eps + [(l, s, self.T) for l, s in self.warn_start.items()]
        sp = {}
        for l, t in self.spill_events:
            sp.setdefault(l, []).append(t)
        hit = sum(1 for l, s, e in eps if any(s <= t <= e + follow for t in sp.get(l, [])))
        caught = [x for x in self.leads if x > 0]
        return {"episodes": len(eps), "precision": hit / len(eps) if eps else float("nan"),
                "spills": len(self.leads), "recall": len(caught) / len(self.leads) if self.leads else float("nan"),
                "median_lead_s": float(np.median(caught)) if caught else 0.0}

    def _line_stuck(self, l):
        n = self.n
        j, a = n.dst[l]
        if j < 0:
            return False
        return all(self._load_now[n.out_line[j, b]] >= 0.97 for b in range(4) if b != a)

    def _interlock(self, j, t, occ):
        sl = slice(j * 16, j * 16 + 16)
        if self.state[j] == "C":
            if t >= self.c_end[j]:
                p = self.nxt[j]
                self.state[j], self.phase[j], self.g_start[j] = "G", p, t
                self.green[sl] = PM[p]
                self.startup[sl] = np.where(PM[p], STARTUP, 0.0)
                self._on_green(j, t, occ)
            return
        el = t - self.g_start[j]
        gmin = G_MIN
        if self.ctrl == "bt" and self.opts["sat_gmin"] > G_MIN and self._saturated(j, occ):
            gmin = self.opts["sat_gmin"]
        if el < gmin:
            return
        forced = el >= G_MAX
        if forced or self._wants_end(j, t, el, occ):
            nxt = self._choose(j, t, occ, forced)
            if nxt == self.phase[j] and not forced:
                return
            self.state[j], self.c_end[j], self.nxt[j] = "C", t + CLEAR, nxt
            self.green[sl] = False

    def _on_green(self, j, t, occ):
        if self.ctrl == "bt":
            _, (T, elig, _) = self._scores(j, t, occ)
            Ts = T[PM[self.phase[j]] & elig]
            self.planned[j] = float(np.clip(Ts.max() if Ts.size else G_MIN, G_MIN, G_MAX))
        self.blocked_run[j] = 0

    def _wants_end(self, j, t, el, occ):
        if self.ctrl == "bt" and self.em:
            # emergency: rotate through every arm (no movement can be starved into a loop)
            if self.opts["em_actuated"]:
                ph = PM[self.phase[j]]
                if self._hol_V(j)[ph].sum() < 0.5:
                    return True
            return el >= self.opts["em_green"]
        if self.ctrl == "fixed":
            return el >= 40.0
        sl = slice(j * 16, j * 16 + 16)
        ph = PM[self.phase[j]]
        if self.ctrl == "maxp":
            w, _ = self._scores(j, t, occ)
            return (PM @ w).max() > 1.1 * (w * ph).sum() + 0.75
        if self.blocked_now[sl][ph & (self.V[sl] > 0.05)].any():
            self.blocked_run[j] += 1
        else:
            self.blocked_run[j] = 0
        Vph = (self._hol_V(j) if self.opts["hol_low"] else self.V[sl])[ph].sum()
        if Vph < 0.5 or self.blocked_run[j] >= 3:
            return True
        if int(el) % 5 == 0:
            if self.opts["rate_rolling"]:
                # switch only when the current taps pass much less current than another piece could
                r = self._rates(j, occ)
                if (PM @ r).max() > 2.0 * (r * ph).sum() + 0.05:
                    return True
            else:
                s, _ = self._scores(j, t, occ)
                if (PM @ s).max() > 1.3 * (s * ph).sum() + 1.0:
                    return True
        return el >= self.planned[j]

    def _rates(self, j, occ):
        """Achievable discharge current of each tap right now (W/s)."""
        n = self.n
        sl = slice(j * 16, j * 16 + 16)
        V = self._hol_V(j)
        ex = n.g_exit[sl]
        room = n.cap0[ex] - occ[ex]
        isat = n.g_lanes[sl] / (self.tau[j, n.g_turn[sl]] * TURN_F[n.g_turn[sl]])
        r = isat * np.minimum(1.0, V / V_KNEE) * (room >= BLOCK_W)
        return r * (1.0 - self.p[ex])

    def _saturated(self, j, occ):
        """Saturated junction: every tap with demand holds more than one max green of charge."""
        n = self.n
        sl = slice(j * 16, j * 16 + 16)
        V = self._hol_V(j)
        isat = n.g_lanes[sl] / (self.tau[j, n.g_turn[sl]] * TURN_F[n.g_turn[sl]])
        need = V / isat
        busy = V > 0.5
        return busy.sum() >= 6 and np.median(need[busy]) > 40.0

    def _choose(self, j, t, occ, forced):
        if self.ctrl == "fixed" or (self.ctrl == "bt" and self.em):
            self.k_fixed[j] = (self.k_fixed[j] + 1) % 4
            return SPLIT_IDX[self.k_fixed[j]]
        s, extra = self._scores(j, t, occ)
        ps = PM.astype(float) @ s
        cur = self.phase[j]
        if forced:
            ps[cur] = -1.0
        if self.ctrl == "bt":
            _, elig, age = extra
            starving = np.where(elig & (age > self.opts["max_wait"]))[0]
            if starving.size:
                worst = starving[np.argmax(age[starving])]
                cand = np.where(PM[:, worst])[0]
                if forced:
                    cand = cand[cand != cur]
                if cand.size:
                    return int(cand[np.argmax(ps[cand])])
            best = int(np.argmax(ps))
            if not forced and ps[cur] >= 0.85 * ps[best] and ps[cur] > 0:
                best = cur
                self.planned[j] = min(G_MAX, (t - self.g_start[j]) + 10.0)
            return best
        return int(np.argmax(ps))

    def run(self):
        for t in range(self.T):
            self.step(t)
        return {
            "delay_s": self.stored_int / max(self.arrived, 1e-9),
            "served": self.served_out,
            "arrived": self.arrived,
            "stored_end": self.series[-1],
            "peak_stored": max(self.series),
            "spill": self.spill,
            "series": self.series,
            "est_rmse": (self.est_err2 / self.est_n) ** 0.5 if self.est_n else 0.0,
            "warn": self.warning_stats() if (self.est is not None and self.opts["atc"]) else None,
        }


# v3 = v2 plus the fixes found by stress-testing the electrical twin
V3_OPTS = dict(rate_rolling=True, sat_gmin=35.0, hol_low=True, backpressure=True,
               perimeter=True, n_crit=0.30, n_band=0.15,
               emergency=True, em_on=0.45, em_off=0.35, em_actuated=True, em_green=50.0,
               divert=True, compliance=0.7)

# v4 = v3 + network state estimator (Kalman, bad-data rejection) + 3-level
# look-ahead transfer-capability inflow throttling and gate metering
V4_OPTS = dict(V3_OPTS, estimator="kf", atc=True, atc_apply=True, atc_depth=3, atc_H=120.0)
