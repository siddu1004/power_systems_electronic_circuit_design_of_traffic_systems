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
                    estimator="oracle", atc=False, pred_pressure=False, blind_mode="hybrid", hybrid_acc=0.40,
                    cctv_view_m=float("inf"), cctv_noise=0.08, gmaps=False, gmaps_tau=180.0,
                    gmaps_period=60.0, gmaps_sigma=0.10, gmaps_queue=False, atc_apply=False, atc_depth=3, atc_H=120.0,
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
        self.Dl = np.full(self.L, self.D)          # per-road travel delay (s); city graphs differ
        self.Dmax = self.D
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
    gate_surge (demand x mult), slow (approach saturation current x mult),
    cam_fail (camera of junction(s) `target` dead: that junction is blind),
    rain (network-wide saturation current x mult, demand x 0.9),
    dark (signal power failure at junction(s) `target`: give-way, discharge x 0.6).
    line_block / gate_surge targets may be a single index or a list."""

    def __init__(self, kind, target, t0=1200, t1=2100, mult=None):
        self.kind, self.target, self.t0, self.t1 = kind, target, t0, t1
        self.mult = mult if mult is not None else {"gate_surge": 2.2, "sink_cut": 0.05, "slow": 0.45,
                                                   "rain": 0.75, "dark": 0.6}.get(kind, 0.0)

    def on(self, t):
        return self.t0 <= t < self.t1


class CircuitSim:
    def __init__(self, net, ctrl, seed=1, demand=0.069, horizon=5400, incident=None, opts=None,
                 sink_rate=0.55, record=False):
        self.n, self.ctrl, self.T, self.inc = net, ctrl, horizon, incident
        self.rng = np.random.default_rng(seed)
        self.seed = seed
        self.opts = dict(DEFAULT_OPTS)
        self.opts.update(opts or {})
        n = net
        self.V = np.zeros(n.G)
        self.ring = np.zeros((n.L, n.Dmax))
        self.head = 0
        self.entry = np.zeros(n.L)
        self.gateq = np.zeros(n.L)
        self.lam = np.zeros(n.L)
        self.lam[n.gates] = demand
        if hasattr(n, "lanes_l"):                  # city: demand per entering lane
            self.lam[n.gates] = demand * n.lanes_l[n.gates]
        self.noise = np.zeros(n.L)
        self.sink_rate = np.full(n.L, sink_rate)
        self.isat_mult = np.ones(n.G)
        self.green = np.zeros(n.G, bool)
        self.startup = np.zeros(n.G)
        self.last_served = np.zeros(n.G)
        self.wait_since = np.zeros(n.G)        # fairness: time a movement has had demand without service
        self.max_wait = 0.0
        self.wait_hist = []
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
            # (estimator "kf6" = v6 CCTV + Google Maps fusion, NetState.update_v6)
            from .network_state import NetState
            self.est = NetState(self, mode=o["estimator"], coverage=o["sensor_cover"],
                                sigma=o["sensor_sigma"], count_noise=o["count_noise"], stuck=o["stuck"],
                                phantom_p=o["phantom_p"], seed=seed + 99, H=o["atc_H"], depth=o["atc_depth"])
        self.occ_c = np.zeros(n.L)
        self._priority = getattr(n, "priority", set())
        self._dark = set()
        # classic real-world controllers (per junction, split phasing through present arms)
        arms_ok = getattr(n, "arm_present", np.ones((n.J, 4), bool))
        self.plan_C = np.full(n.J, 80.0)
        self.plan_g = np.where(arms_ok, 20.0, 0.0)
        self.green_s = np.zeros((n.J, 4))
        self.busy_s = np.zeros((n.J, 4))
        self.q_arm = np.zeros((n.J, 4))
        self.last_plan_t = np.zeros(n.J)
        # police failsafe (v7): alert -> officer dispatched -> manual control on arrival
        self.police_on = bool(self.opts.get("police"))
        self.officers_free = int(self.opts.get("officers", 3))
        self.police = {}            # j -> dict(arrive, calm_since)
        self.police_alerts = []     # (t, j, reason)
        self.police_log = []        # (t_arrive, t_leave, j)
        self._jam_since = np.full(n.J, -1.0)
        self._grid_since = np.full(n.J, -1.0)
        self._alerted = {}
        # v7: v6 protections only in special cases
        self.special = False
        self.special_until = -1.0
        self.special_s = 0
        self._arm_ok = getattr(n, "arm_present", np.ones((n.J, 4), bool))
        # camera layer: what the controllers SEE (aliases of the truth unless a camera is dead)
        self.Vo, self.Eo = self.V, self.entry
        self.blind = set()
        self.blind_est = {}         # j -> dict(V=16, E=4 per arm)
        self.landed = np.zeros(n.L)
        self.sent = np.zeros(n.L)
        self.pred_ring = np.zeros((n.L, n.Dmax))  # predicted sends of blind junctions
        self.blind_err2, self.blind_n = 0.0, 0
        self.est_err2, self.est_n = 0.0, 0
        self.raw_err2 = 0.0
        self.warn_start = {}
        self.warn_eps = []          # (line, start, end)
        self.spill_events = []      # (line, t)
        self.leads = []
        # turn split of each road's arrivals (city graphs zero impossible turns)
        self.base_ratio = n.base_ratio.copy() if hasattr(n, "base_ratio") else np.tile(RATIO, (n.L, 1))
        self.ratio = self.base_ratio.copy()
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
        if self.opts.get("peak_profile"):
            # real-time morning peak: demand rises to 1.6x around t = 40 min
            lam = lam * (0.7 + 0.9 * np.exp(-((t - 2400.0) / 1000.0) ** 2))
        if self.opts.get("heldout_pattern"):
            # held-out demand: N-S corridors x1.4, E-W x0.7, and a peak bump 20-60 min
            if not hasattr(self, "_gm"):
                self._gm = np.ones(n.L)
                for l in n.gates:
                    self._gm[l] = 1.4 if n.dst[l][1] in (0, 2) else 0.7
            peak = 0.8 + 0.5 * np.exp(-((t - 2400.0) / 900.0) ** 2)
            lam = lam * self._gm * peak
        sink_rate = self.sink_rate.copy()
        blocked = np.zeros(n.L, bool)
        self._dark = set()
        self.isat_mult[:] = 1.0
        if inc and inc.on(t):
            if inc.kind == "gate_surge":
                lam[inc.target] *= inc.mult
            elif inc.kind == "sink_cut":
                sink_rate[inc.target] *= inc.mult
            elif inc.kind == "line_block":
                blocked[np.atleast_1d(inc.target)] = True
            elif inc.kind == "rain":
                self.isat_mult[:] = inc.mult
                lam = lam * 0.9
            elif inc.kind == "dark":
                self._dark = set(np.atleast_1d(inc.target).tolist())
                for j in self._dark:
                    on_duty = j in self.police and self.police[j]["arrive"] <= t
                    self.isat_mult[j * 16:(j + 1) * 16] = 0.9 if on_duty else inc.mult
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
        self.ring[g, (self.head - 1 + n.Dl[g] - n.Dmax) % n.Dmax] += mv
        # 2. delay lines deliver
        self.landed = self.ring[:, self.head].copy()     # blocks landing on the stacks now
        self._pred_landing = self.pred_ring[:, self.head].copy()   # predicted D s ago
        self.pred_ring[:, self.head] = 0.0
        self.entry += self.landed
        self.ring[:, self.head] = 0.0
        self.head = (self.head + 1) % n.Dmax
        # 3. shared section -> pockets (head-of-line blocking)
        lm = n.line_moves
        has = np.where(lm[:, 0] >= 0)[0]
        Vm = self.V[lm[has]]
        R = self.ratio[has]
        headroom = np.where(R > 1e-9, (n.g_pocket[lm[has]] - Vm) / np.maximum(R, 1e-9), np.inf)
        if self.police:
            pj = np.array([n.dst[l][0] in self.police and self.police[n.dst[l][0]]["arrive"] <= t for l in has])
            headroom[pj] = np.inf                       # officer waves blocked vehicles past the full pocket
        x = np.minimum(self.entry[has], np.clip(headroom.min(1), 0, None))
        x[blocked[has]] = 0.0
        self.entry[has] -= x
        np.add.at(self.V, lm[has].ravel(), (x[:, None] * R).ravel())
        # 4. current-limited exits
        s = n.sinks
        sr = sink_rate[s].copy()
        sr[blocked[s]] = 0.0
        d = np.minimum(self.entry[s], sr * DT)
        self.entry[s] -= d
        self.c_out[s] += d
        self.served_out += d.sum()
        # 5. network layer, learning, controllers, interlock
        occ = self.occ()
        load = occ / n.cap0
        occ_c = occ
        if self.est is not None:
            if self.opts["estimator"] == "kf6":
                occ_c = self._update_v6(t)
            else:
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
        self.acc_c = occ_c[n.inner].sum() / n.cap0[n.inner].sum()
        load_c = occ_c / n.cap0
        if self.opts.get("special_only"):
            # event triggers: dead camera, network-wide overload, or >= 2 roads predicted
            # to overflow (load at t+H >= 1) continuously for 30 s
            trig = bool(self.blind) or (self.opts.get("special_acc", True) and self.acc_c >= 0.40)
            if self.est is not None and self.opts["atc"]:
                over = int((self.est.load_pred[n.inner] >= 1.0).sum()) >= 2
                self._over_run = getattr(self, "_over_run", 0) + 1 if over else 0
                trig = trig or self._over_run >= 30
            if trig:
                self.special_until = t + 300.0
            self.special = t < self.special_until
            self.special_s += int(self.special)
        if self.est is not None and self.opts["atc"] and self.opts["pred_pressure"] and \
                (not self.opts.get("special_only") or self.special):
            # protections act on the PREDICTED load (t + H), i.e. before the overload arrives
            load_c = np.maximum(load_c, np.minimum(self.est.load_pred, 1.0))
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
        if self.ctrl == "bt":
            self._cameras(t, occ_c)
        if self.police_on:
            self._police(t)
        for j in range(n.J):
            self._interlock(j, t, occ_c)
        # 6. MOSFET taps discharge into Zener-clamped lines
        gi = np.where(self.green)[0]
        on = gi[self.startup[gi] <= 0]
        self.startup[gi] = np.maximum(0, self.startup[gi] - DT)
        isat = n.g_lanes[on] / (TAU_TRUE * TURN_F[n.g_turn[on]]) * self.isat_mult[on] \
            * (1 + 0.1 * self.rng.normal(size=len(on)))
        want = np.minimum(self.V[on], isat * np.minimum(1.0, self.V[on] / V_KNEE) * DT)
        self.blocked_now[:] = False
        self.discharged[:] = 0.0
        self.sent = np.zeros(n.L)
        for k, gg in enumerate(on):
            ex = n.g_exit[gg]
            q = min(want[k], max(0.0, n.cap0[ex] - occ[ex]))
            if q < want[k] - 1e-9:
                self.blocked_now[gg] = True
            if q > 0:
                self.V[gg] -= q
                self.ring[ex, (self.head - 1 + n.Dl[ex] - n.Dmax) % n.Dmax] += q
                occ[ex] += q
                occ[n.g_in[gg]] -= q
                self.c_in[ex] += q
                self.c_out[n.g_in[gg]] += q
                self.last_served[gg] = t
                self.discharged[gg] = q
                self.sent[ex] += q
        if self.ctrl in ("scats", "scoot"):
            arm_busy = self.discharged.reshape(n.J, 4, 4).sum(2) > 0
            for j in range(n.J):
                if self.state[j] == "G":
                    a = self.k_fixed[j]
                    self.green_s[j, a] += 1
                    self.busy_s[j, a] += int(arm_busy[j, a])
            land = np.array([[self.landed[n.in_line[j, a]] for a in range(4)] for j in range(n.J)])
            self.q_arm += (land - self.q_arm) / 300.0
        # fairness: how long has each movement with demand gone without green?
        # count only waits a signal could have served (exit road not full)
        has_dem = (self.V > 0.5) & (n.cap0[n.g_exit] - occ[n.g_exit] >= BLOCK_W)
        served_now = self.discharged > 0
        self.wait_since = np.where(~has_dem | served_now, t, self.wait_since)
        w = t - self.wait_since
        self.max_wait = max(self.max_wait, float(w.max()))
        if t % 30 == 0:
            self.wait_hist.append(float(np.percentile(w[has_dem], 95)) if has_dem.any() else 0.0)
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
        if not hasattr(n, "down_idx"):
            n.down_idx = np.array([(n.down_out[l] + [-1, -1, -1])[:3] for l in range(n.L)])
        pe = np.append(self.p, 0.0)                    # index -1 -> 0
        prop = pe[n.down_idx].max(1)
        target = np.maximum(local, o["attenuation"] * prop)
        self.p = np.where(target >= self.p, target, np.maximum(target, self.p - o["ramp"]))

    # ── v6 inputs: CCTV with a limited view, Google Maps travel times ────────
    def _view_W(self):
        return self.opts["cctv_view_m"] * 2 * W_PER_M        # 2 lanes of view

    def _update_v6(self, t):
        n, o = self.n, self.opts
        # true stack (landed blocks) of every road and its true outflow rate
        q = self.entry.copy()
        has = n.line_moves[:, 0] >= 0
        q[has] += self.V[n.line_moves[has]].sum(1)
        if not hasattr(self, "out_ema"):
            self.out_ema = np.full(n.L, 0.1)
            self.gm_g = n.Dl.astype(float).copy()
            self.gm_T = None
        self.out_ema += (self.c_out - self.out_ema) / 60.0
        # Google Maps: lagged average travel time, refreshed every period, noisy
        T_true = n.Dl + np.minimum(q / np.maximum(self.out_ema, 0.02), 3600.0)
        self.gm_g += (T_true - self.gm_g) * DT / o["gmaps_tau"]
        if o["gmaps"] and t % int(o["gmaps_period"]) == 0:
            if not hasattr(self, "gm_rng"):          # own stream: sensors never shift the physics noise
                self.gm_rng = np.random.default_rng(self.seed + 7777)
            self.gm_T = self.gm_g * (1 + o["gmaps_sigma"] * self.gm_rng.normal(size=n.L))
        # CCTV at the downstream junction of each road (not on roads into blind junctions)
        W = self._view_W()
        has_cam = np.array([n.dst[l][0] >= 0 and n.dst[l][0] not in self.blind for l in range(n.L)])
        sat = q > W
        if not hasattr(self, "cam_rng"):
            self.cam_rng = np.random.default_rng(self.seed + 5555)
        vis = np.minimum(q, W) * (1 + o["cctv_noise"] * self.cam_rng.normal(size=n.L))
        return self.est.update_v6(t, self.c_in, self.c_out, np.maximum(vis, 0), sat, has_cam, W,
                                  self.gm_T if o["gmaps"] else None, n.Dl.astype(float),
                                  gm_queue=o["gmaps_queue"])

    def _cctv_view(self):
        """What a CCTV sees: the stack within view_m of the stop line (short pockets
        first, then the straight lane, then the shared section). The hidden tail of
        an overflowing stack is filled in from the road estimate (z - moving blocks)."""
        n, o = self.n, self.opts
        W = self._view_W()
        Vo, Eo = self.V.copy(), self.entry.copy()
        if not hasattr(self, "cam_rng"):
            self.cam_rng = np.random.default_rng(self.seed + 5555)
        rng = self.cam_rng
        est = self.est
        for j in range(n.J):
            if j in self.blind:
                continue
            for a in range(4):
                l = n.in_line[j, a]
                g = j * 16 + a * 4
                budget = W
                for k in (0, 2, 3, 1):                     # L, R, U pockets, then S
                    v = min(self.V[g + k], budget)
                    Vo[g + k] = v
                    budget -= v
                Eo[l] = min(self.entry[l], max(budget, 0.0))
                stack = self.V[g:g + 4].sum() + self.entry[l]
                if stack > W and est is not None and hasattr(est, "transit"):
                    hidden = max(0.0, est.z[l] - est.transit[l] - W)
                    if Eo[l] > 0:
                        Eo[l] += hidden                        # queue behind a blocked lane
                    else:
                        Vo[g + 1] += hidden                    # long straight queue
            sl = slice(j * 16, (j + 1) * 16)
            Vo[sl] *= np.clip(1 + o["cctv_noise"] * rng.normal(size=16), 0, None)
        return Vo, Eo

    # ── camera layer and neighbour-based reconstruction of a blind junction ──
    def _cameras(self, t, occ_c):
        """Each junction's camera sees its own stacks (landed blocks) and counts
        blocks leaving. If a camera dies, the junction's stacks are rebuilt from
        the messages of the connected junctions:
          inflow  = upstream cameras' send counts (they arrive D s later = now)
          outflow = predicted from the known signal state and learned tau,
                    corrected by downstream cameras' landing counts D s later."""
        n, o, inc = self.n, self.opts, self.inc
        now = set()
        if inc and inc.kind == "cam_fail" and inc.on(t):
            now = set(inc.target if isinstance(inc.target, (list, tuple)) else [inc.target])
        for j in now - self.blind:                     # camera just died: start from last frame
            self.blind_est[j] = dict(V=self.V[j * 16:(j + 1) * 16].copy(),
                                     E=np.array([self.entry[n.in_line[j, a]] for a in range(4)]),
                                     frozenV=self.V[j * 16:(j + 1) * 16].copy(),
                                     frozenE=np.array([self.entry[n.in_line[j, a]] for a in range(4)]))
        for j in self.blind - now:
            self.blind_est.pop(j, None)
        self.blind = now
        if self.est is not None:
            cov = self.est.cover
            if not hasattr(self, "_cover0"):
                self._cover0 = cov.copy()
            cov[:] = self._cover0
            for j in now:                                # its road cameras are gone too
                cov[n.in_line[j]] = False
        limited = np.isfinite(o["cctv_view_m"])
        if not now and not limited:
            self.Vo, self.Eo = self.V, self.entry
            return
        if limited:
            self.Vo, self.Eo = self._cctv_view()
        else:
            self.Vo, self.Eo = self.V.copy(), self.entry.copy()
        if not now:
            return
        slot_of = lambda e: (self.head - 1 + n.Dl[e] - n.Dmax) % n.Dmax   # arrives D_e s later
        for j in now:
            est = self.blind_est[j]
            sl = slice(j * 16, (j + 1) * 16)
            if o["blind_mode"] == "frozen":
                self.Vo[sl] = est["frozenV"]
                for a in range(4):
                    self.Eo[n.in_line[j, a]] = est["frozenE"][a]
            elif o["blind_mode"] in ("neighbour", "hybrid"):
                Ve, Ee = est["V"], est["E"]
                for a in range(4):
                    l = n.in_line[j, a]
                    src = n.src[l][0]
                    if src >= 0 and src in now:
                        arr = self._pred_landing[l]               # upstream also blind: its prediction
                    else:
                        arr = self.landed[l] * (1 + 0.03 * self.rng.normal())   # upstream count message
                    Ee[a] += max(0.0, arr)
                    r = self.ratio[l]
                    g = slice(a * 4, a * 4 + 4)
                    head = np.where(r > 1e-9, (POCKET - Ve[g]) / np.maximum(r, 1e-9), np.inf)
                    x = min(Ee[a], max(0.0, head.min()))
                    Ee[a] -= x
                    Ve[g] += x * r
                # predicted discharge with the junction's own (known) signal state
                tau = self.tau[j, n.g_turn[sl]] * TURN_F[n.g_turn[sl]]
                isat = n.g_lanes[sl] / tau
                on = self.green[sl] & (self.startup[sl] <= 0)
                q = np.where(on, np.minimum(Ve, isat * np.minimum(1.0, Ve / V_KNEE)), 0.0)
                ex = n.g_exit[sl]
                room = np.maximum(0.0, n.cap0[ex] - occ_c[ex])
                q = np.minimum(q, room)
                Ve -= q
                for k in range(16):
                    if q[k] > 0:
                        self.pred_ring[ex[k], slot_of(ex[k])] += q[k]
                # downstream landing counts correct the sends predicted D s ago
                for b in range(4):
                    e = n.out_line[j, b]
                    d = n.dst[e][0]
                    if d < 0 or d in now:
                        continue
                    meas = self.landed[e] * (1 + 0.03 * self.rng.normal())
                    err = meas - self._pred_landing[e]
                    m = np.where(ex == e)[0]
                    tot = Ve[m].sum()
                    if tot > 1e-6:
                        Ve[m] = np.maximum(0.0, Ve[m] - err * Ve[m] / tot)
                np.maximum(Ve, 0.0, out=Ve)
                self.Vo[sl] = Ve
                for a in range(4):
                    self.Eo[n.in_line[j, a]] = Ee[a]
            e2 = (self.Vo[sl] - self.V[sl]) ** 2
            self.blind_err2 += float(e2.sum())
            self.blind_n += 16

    def _police(self, t):
        """Failsafe. A junction alerts the traffic police when the situation is
        beyond automatic control:
          dark signal (power failure)                       -> immediate
          gridlock: its green taps blocked >= 60 s
          local jam: stacked load >= 70 % of its approach storage for >= 120 s
        Free officers are dispatched (worst first) and arrive after the response
        delay; on duty they run longest-queue-first and wave vehicles past blocked
        pockets; they leave after 300 s of calm (load < 40 %, no gridlock)."""
        n, o = self.n, self.opts
        if t % 5:
            return
        delay = float(o.get("police_delay", 300.0))
        for j in range(n.J):
            ok = self._arm_ok[j]
            q = sum(self._arm_q(j, a) for a in range(4) if ok[a])
            cap = sum(n.cap0[n.in_line[j, a]] for a in range(4) if ok[a])
            ratio = q / max(cap, 1e-9)
            sl = slice(j * 16, (j + 1) * 16)
            grid = bool((self.blocked_now[sl] & self.green[sl]).any()) and \
                not bool((self.discharged[sl] > 0).any())
            self._jam_since[j] = (self._jam_since[j] if self._jam_since[j] >= 0 else t) if ratio >= 0.7 else -1
            self._grid_since[j] = (self._grid_since[j] if self._grid_since[j] >= 0 else t) if grid else -1
            reason = None
            if j in self._dark:
                reason, sev = "signal dark", 3
            elif self._grid_since[j] >= 0 and t - self._grid_since[j] >= 60:
                reason, sev = "gridlock", 2
            elif self._jam_since[j] >= 0 and t - self._jam_since[j] >= 120:
                reason, sev = "jam beyond control", 1
            if j in self.police:
                cop = self.police[j]
                calm = reason is None and ratio < 0.4
                cop["calm_since"] = (cop["calm_since"] if cop["calm_since"] >= 0 else t) if calm else -1
                if cop["calm_since"] >= 0 and t - cop["calm_since"] >= 300:
                    self.police_log.append((cop["arrive"], t, j))
                    del self.police[j]
                    self.officers_free += 1
            elif reason is not None:
                if j not in self._alerted or t - self._alerted[j] > 600:
                    self.police_alerts.append((t, j, reason))
                    self._alerted[j] = t
                self._pending = getattr(self, "_pending", {})
                self._pending[j] = max(self._pending.get(j, 0), sev)
        pend = getattr(self, "_pending", {})
        for j in sorted(pend, key=lambda x: -pend[x]):
            if self.officers_free <= 0:
                break
            if j not in self.police:
                self.police[j] = dict(arrive=t + delay, calm_since=-1.0)
                self.officers_free -= 1
        self._pending = {j: v for j, v in pend.items() if j not in self.police}

    def _replan(self, j, t):
        """SCATS-like: cycle length follows the worst degree of saturation (DS) and
        splits follow each arm's DS. SCOOT-like: every 5 min a Webster plan from the
        measured arm flows and saturation flows (cyclic flow-profile optimisation)."""
        ok = self._arm_ok[j]
        nA = int(ok.sum())
        L = 5.0 * nA
        if self.ctrl == "scats":
            ds = np.where(self.green_s[j] > 0, self.busy_s[j] / np.maximum(self.green_s[j], 1), 0.0)
            dmax = ds[ok].max() if nA else 0.0
            C = self.plan_C[j] + (10.0 if dmax > 0.9 else -10.0 if dmax < 0.6 else 0.0)
            C = float(np.clip(C, 40.0, 160.0))
            w = np.where(ok, np.maximum(ds, 0.2), 0.0)
            self.plan_C[j] = C
            self.plan_g[j] = np.where(ok, np.maximum(10.0, (C - L) * w / max(w.sum(), 1e-9)), 0.0)
            self.green_s[j] = 0.0
            self.busy_s[j] = 0.0
        else:
            if t - self.last_plan_t[j] < 300.0:
                return
            self.last_plan_t[j] = t
            n = self.n
            y = np.zeros(4)
            for a in range(4):
                if not ok[a]:
                    continue
                r = self.base_ratio[n.in_line[j, a]]
                sat = n.g_lanes[j * 16 + a * 4: j * 16 + a * 4 + 4] / (TAU_TRUE * TURN_F)
                s_arm = min(sat[k] / r[k] for k in range(4) if r[k] > 1e-9)
                y[a] = self.q_arm[j, a] / max(s_arm, 1e-6)
            Y = y.sum()
            C = (1.5 * L + 5.0) / (1.0 - Y) if Y < 0.9 else 150.0
            C = float(np.clip(C, 40.0, 150.0))
            self.plan_C[j] = C
            self.plan_g[j] = np.where(ok, np.maximum(10.0, (C - L) * y / max(Y, 1e-9)), 0.0)

    def _divert(self):
        """Diversion orders (VMS / police): when an exit road trips, the share of
        approaching traffic that wanted it is re-routed to the other exits
        (current redistributes over parallel paths). Partial compliance."""
        n, o = self.n, self.opts
        if not hasattr(n, "from_junction"):
            n.from_junction = np.array([n.src[l][0] >= 0 for l in range(n.L)])
        prev = self.diverted.copy()
        self.diverted = np.where(n.from_junction & (self.p >= o["divert_on"]), True,
                                 np.where(self.p <= o["divert_off"], False, self.diverted))
        self.diverted &= n.from_junction
        if (self.diverted == prev).all() and getattr(self, "_ratio_ready", False):
            return                                     # nothing changed: keep the split
        self._ratio_ready = True
        for l in range(n.L):
            j, a = n.dst[l]
            if j < 0:
                continue
            base = self.base_ratio[l]
            r = base.copy()
            for k in range(4):
                b = MOVES[a * 4 + k][2]
                if r[k] > 0 and self.diverted[n.out_line[j, b]] and b != a:
                    moved = r[k] * o["compliance"]
                    r[k] -= moved
                    ok = [i for i in range(4) if i != k and base[i] > 0
                          and not self.diverted[n.out_line[j, MOVES[a * 4 + i][2]]]]
                    if ok:
                        w = base[ok] / base[ok].sum()
                        r[ok] += moved * w
                    else:
                        r[k] += moved
            self.ratio[l] = r

    def _learn(self):
        """tau from the measured saturation current of each unblocked tap."""
        n, d = self.n, self.discharged
        ok = np.where((d > 0) & ~self.blocked_now & (self.V > V_KNEE))[0]
        for gg in ok:
            if n.g_j[gg] in self.blind:
                continue                      # no camera, no measurement
            j, k = n.g_j[gg], n.g_turn[gg]
            meas = n.g_lanes[gg] * DT / d[gg] / TURN_F[k]
            self.tau[j, k] += 0.05 * (meas - self.tau[j, k])

    # ── controllers ─────────────────────────────────────────────────────────
    def _hol_V(self, j):
        """Charge stuck in an arm's shared section is charged to the pocket
        that blocks it (fault current traced to the faulted element)."""
        n = self.n
        V = self.Vo[j * 16:j * 16 + 16].copy()
        for a in range(4):
            e = self.Eo[n.in_line[j, a]]
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
        if self.ctrl == "bt" and G_MIN <= el < self.opts["sat_gmin"] and self._saturated(j, occ):
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

    def _blind_fixed(self, j):
        if j not in self.blind:
            return False
        m = self.opts["blind_mode"]
        if m == "hybrid":
            # saturated network: a blind junction meters best with a fixed rotation;
            # otherwise it runs Block-Tetris on the neighbour-rebuilt stacks
            return self.acc_c >= self.opts["hybrid_acc"]
        return m == "fixed"

    def _arm_q(self, j, a):
        return self.V[j * 16 + a * 4: j * 16 + a * 4 + 4].sum() + self.entry[self.n.in_line[j, a]]

    def _manual(self, j, t):
        return j in self.police and self.police[j]["arrive"] <= t

    def _wants_end(self, j, t, el, occ):
        if self._manual(j, t):                       # officer: hold until the arm clears, max 60 s
            return el >= 60.0 or self._arm_q(j, self.k_fixed[j]) < 0.5
        if j in self._priority or j in self._dark:
            return el >= 20.0                        # give-way / dark signal: short alternation
        if self.ctrl == "actuated":                  # NEMA-style: gap-out when the arm empties
            return el >= 40.0 or self._arm_q(j, self.k_fixed[j]) < 0.5
        if self.ctrl in ("scats", "scoot"):
            return el >= max(10.0, self.plan_g[j, self.k_fixed[j]])
        if self.ctrl == "bt" and self._blind_fixed(j):
            return el >= 40.0
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
        if self.opts.get("hard_wait_cap") and el >= G_MIN:
            _, extra = self._scores(j, t, occ)
            _, elig, age = extra
            if (elig & ~ph & (age > self.opts["max_wait"])).any():
                return True                          # starving movement waiting: hand over now
        if j not in self.blind and self.blocked_now[sl][ph & (self.V[sl] > 0.05)].any():
            self.blocked_run[j] += 1
        else:
            self.blocked_run[j] = 0
        Vph = (self._hol_V(j) if self.opts["hol_low"] else self.Vo[sl])[ph].sum()
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
        busy = V > 0.5
        nb = int(busy.sum())
        if nb < 6:
            return False
        need = np.sort(V[busy] / isat[busy])
        med = need[nb // 2] if nb % 2 else 0.5 * (need[nb // 2 - 1] + need[nb // 2])
        return med > 40.0

    def _choose(self, j, t, occ, forced):
        if self._manual(j, t):                       # officer: longest queue first
            q = [self._arm_q(j, a) if self._arm_ok[j, a] else -1 for a in range(4)]
            if forced:
                q[self.k_fixed[j]] = -1
            self.k_fixed[j] = int(np.argmax(q))
            return SPLIT_IDX[self.k_fixed[j]]
        if self.ctrl in ("fixed", "actuated", "scats", "scoot") or j in self._priority or j in self._dark or \
                (self.ctrl == "bt" and (self.em or self._blind_fixed(j))):
            prev = self.k_fixed[j]
            for _ in range(4):                       # next arm that physically exists
                self.k_fixed[j] = (self.k_fixed[j] + 1) % 4
                if not self._arm_ok[j, self.k_fixed[j]]:
                    continue
                if self.ctrl == "actuated" and j not in self._priority and j not in self._dark \
                        and self._arm_q(j, self.k_fixed[j]) < 0.5:
                    continue                         # skip arms with no call
                break
            else:
                self.k_fixed[j] = prev
            if self.ctrl in ("scats", "scoot") and self.k_fixed[j] <= prev:
                self._replan(j, t)                   # a cycle has completed
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
            "max_wait_s": self.max_wait,
            "police_alerts": len(self.police_alerts),
            "police_dispatches": len(self.police_log) + len(self.police),
            "p95_wait_s": float(np.mean(self.wait_hist)) if self.wait_hist else 0.0,
            "series": self.series,
            "est_rmse": (self.est_err2 / self.est_n) ** 0.5 if self.est_n else 0.0,
            "blind_rmse": (self.blind_err2 / self.blind_n) ** 0.5 if self.blind_n else 0.0,
            "warn": self.warning_stats() if (self.est is not None and self.opts["atc"]) else None,
        }


# v3 = v2 plus the fixes found by stress-testing the electrical twin
V3_OPTS = dict(rate_rolling=True, sat_gmin=35.0, hol_low=True, backpressure=True,
               perimeter=True, n_crit=0.30, n_band=0.15,
               emergency=True, em_on=0.45, em_off=0.35, em_actuated=True, em_green=50.0,
               divert=True, compliance=0.7)

# v4 = v3 + network state estimator (Kalman, bad-data rejection) + 3-level
# look-ahead transfer capability; the relay, diversion and emergency layers act
# on the PREDICTED road load at t + 120 s instead of the present load
V4_OPTS = dict(V3_OPTS, estimator="kf", atc=True, pred_pressure=True, atc_apply=False,
               atc_depth=3, atc_H=120.0)
# Tested and rejected: applying the ATC throttle phi directly to phase scores
# (atc_apply=True) gave no gain on top of predictive protection.


# ── every version stays selectable (nothing is replaced, each builds on the last) ──
V3_PRE_DIVERT_OPTS = dict(V3_OPTS, divert=False)            # v3 as first found by the N-1 sweep
V4A_OPTS = dict(V3_OPTS, estimator="kf", atc=True, atc_apply=True, pred_pressure=False,
                atc_depth=3, atc_H=120.0)                   # first v4: direct look-ahead throttle
V5_OPTS = dict(V4_OPTS, blind_mode="hybrid", hybrid_acc=0.40)   # v4 + neighbour rebuild of blind junctions
VERSIONS = {
    "v2": {},                       # Part 1 algorithm on the e-twin
    "v3-pre-divert": V3_PRE_DIVERT_OPTS,
    "v3": V3_OPTS,                  # + current rolling, saturation green, back-pressure, metering, emergency, diversion
    "v4a-throttle": V4A_OPTS,
    "v4": V4_OPTS,                  # + Kalman state estimator, 3-level look-ahead, predictive protection
    "v5": V5_OPTS,                  # + camera layer, blind junction rebuilt from neighbour messages
}


# v6 = v5 + realistic inputs: CCTV with a limited view (hidden queue tail inferred)
# and Google Maps travel times fused into the network Kalman filter
V6_OPTS = dict(V5_OPTS, estimator="kf6", cctv_view_m=60.0, gmaps=True)
VERSIONS["v6"] = V6_OPTS


# v7 = v3 behaviour normally; v6 protections only in special cases
# (camera failure, a road alarm / predicted spill-back, or network accumulation >= 0.35)
V7_OPTS = dict(V6_OPTS, special_only=True)
V7_IDEAL_OPTS = dict(V7_OPTS, cctv_view_m=float("inf"))
VERSIONS["v7"] = V7_OPTS


# v7 with the traffic-police failsafe (3 officers, 5-min response)
V7P_OPTS = dict(V7_OPTS, police=True, officers=3, police_delay=300.0)
VERSIONS["v7+police"] = V7P_OPTS
