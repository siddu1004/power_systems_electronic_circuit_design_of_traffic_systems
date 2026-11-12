"""Engine: advances the physical network one second at a time, runs every
junction's controller behind a safety interlock, injects scenario disturbances
and records metrics.
"""
from dataclasses import dataclass, field, replace
import numpy as np

from . import params as P
from .geometry import CONFLICT, TURNS, is_compatible
from .model import Network
from .controllers import (Sensor, PressureBus, FixedTime, MaxPressure, BlockTetris)

T_INC0, T_INC1 = 1200, 2100   # standard incident window (s)
HORIZON = 5400                 # 90 minutes


# ─────────────────────────────────────────────────────────────────────────────
# Scenarios: where and how congestion is induced
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class Scenario:
    key: str
    title: str
    demand: float = 0.20
    mix: tuple = P.DEFAULT_MIX
    surge: dict = field(default_factory=dict)      # nbr arm -> (mult, t0, t1)
    sink_cut: dict = field(default_factory=dict)   # (nbr arm, sink idx) -> (rate mult, t0, t1)
    approach_cut: tuple = None                     # (jid, arm, factor, t0, t1)
    sensor_fault: tuple = None                     # (jid, [(mode, t0, t1), ...])
    incident: tuple = (T_INC0, T_INC1)

    def apply(self, t, sim):
        net = sim.net
        for src in net.sources:
            nb = src.dst[1] - 1
            mult = 1.0
            if nb in self.surge:
                m, t0, t1 = self.surge[nb]
                if t0 <= t < t1:
                    mult = m
            net.demand[src.lid] = self.demand * mult
        for (nb, k), (m, t0, t1) in self.sink_cut.items():
            lk = sim.sink_of(nb, k)
            lk.sink_rate = P.SINK_RATE * (m if t0 <= t < t1 else 1.0)
        if self.approach_cut:
            jid, arm, f, t0, t1 = self.approach_cut
            on = t0 <= t < t1
            for ti in range(4):
                net.junctions[jid].moves[arm * 4 + ti].factor = f if on else 1.0
        if self.sensor_fault:
            jid, plan = self.sensor_fault
            mode = "ok"
            for md, t0, t1 in plan:
                if t0 <= t < t1:
                    mode = md
            sim.sensors[jid].mode = mode


SCENARIOS = {
    "S0": Scenario("S0", "Normal day (no incident)", incident=None),
    "S1": Scenario("S1", "Peak surge: north corridor demand x1.8 for 20 min",
                   surge={0: (1.8, T_INC0, T_INC0 + 1200)}, incident=(T_INC0, T_INC0 + 1200)),
    "S2": Scenario("S2", "Downstream blockage: east neighbour exits accept 5% for 15 min",
                   sink_cut={(1, 0): (0.05, T_INC0, T_INC1), (1, 1): (0.05, T_INC0, T_INC1)}),
    "S3": Scenario("S3", "Breakdown at chowrasta south approach (headways x2.2) for 15 min",
                   approach_cut=(0, 2, 2.2, T_INC0, T_INC1)),
    "S4": Scenario("S4", "Stadium release: west corridor demand x2.6 for 10 min",
                   surge={3: (2.6, T_INC0, T_INC0 + 600)}, incident=(T_INC0, T_INC0 + 600)),
    "S5": Scenario("S5", "Heavy-vehicle day: 25% buses/trucks all day", demand=0.18,
                   mix=(0.38, 0.12, 0.25, 0.25), incident=None),
    "S6": Scenario("S6", "Sensor faults at chowrasta: phantom spikes 10 min, then dead 5 min",
                   sensor_fault=(0, [("noisy", T_INC0, T_INC0 + 600), ("dead", T_INC0 + 600, T_INC1)])),
    "S7": Scenario("S7", "Compound: north surge + east blockage together",
                   surge={0: (1.8, T_INC0, T_INC1)},
                   sink_cut={(1, 0): (0.05, T_INC0, T_INC1), (1, 1): (0.05, T_INC0, T_INC1)}),
}

CONTROLLERS = ("Fixed-40", "MaxPressure", "BT-v1 (spec)", "BT-v2 (fixed)")


# ─────────────────────────────────────────────────────────────────────────────
# Simulation
# ─────────────────────────────────────────────────────────────────────────────

class Sim:
    def __init__(self, ctrl, scenario, seed, horizon=HORIZON, record=True):
        self.rng = np.random.default_rng(seed)
        self.sc = scenario
        self.horizon = horizon
        self.net = Network(np.random.default_rng(seed + 7919), demand=scenario.demand, mix=scenario.mix)
        self.sensors = [Sensor(j, np.random.default_rng(seed + 31 * j.jid)) for j in self.net.junctions]
        self.bus = None
        self.ctrl_name = ctrl
        self.ctrls = []
        for j, s in zip(self.net.junctions, self.sensors):
            if ctrl == "Fixed-40":
                c = FixedTime(j)
            elif ctrl == "MaxPressure":
                c = MaxPressure(j, s)
            else:
                if ctrl.startswith("BT-abl:"):
                    fld = ctrl.split(":", 1)[1]
                    kw = {fld: getattr(P.V1, fld)}
                    if fld == "hysteresis":
                        kw["alarm_off"] = P.V1.alarm_off
                    prm = replace(P.V2, **kw)
                else:
                    prm = P.V1 if "v1" in ctrl else P.V2
                if self.bus is None:
                    self.bus = PressureBus(self.net, prm)
                c = BlockTetris(j, s, self.bus, prm)
            self.ctrls.append(c)
        # interlock state
        self.state = ["C"] * 5
        self.c_end = [P.AMBER_ALLRED] * 5
        self.nxt = [c.first_phase(0) for c in self.ctrls]
        self.phase = [frozenset()] * 5
        self.g_start = [0.0] * 5
        # metrics
        self.record = record
        self.series_t = []
        self.series_q = []          # per junction approach queue (blocks)
        self.series_total = []      # network stored queue incl. gates (blocks)
        self.series_p = []          # pressure per link
        self.series_load = []
        self.max_q_m = 0.0
        self.spill = 0
        self._full = [False] * len(self.net.links)
        self.blocked_box_s = 0
        self.greens_log = []        # (jid, t_start, duration, phase) for safety tests
        self.series_tau = []        # (t, tau per class, L) at the chowrasta

    def sink_of(self, nb_arm, k):
        nb = self.net.junctions[1 + nb_arm]
        outs = [lk for lk in nb.out_links if lk.dst[0] == "SINK"]
        return outs[k]

    # ── one second ─────────────────────────────────────────────────────────
    def step(self, t):
        net, rng = self.net, self.rng
        self.sc.apply(t, self)
        for s in self.sensors:
            s.tick()
        # 1. sources -> entry roads (vehicles wait outside if the road is full)
        for src in net.sources:
            for _ in range(rng.poisson(net.demand[src.lid] * P.DT)):
                src.source_q.append(net.new_vehicle(t))
            while src.source_q and src.room(src.source_q[0].length):
                src.enter(src.source_q.popleft(), t)
        # 2. vehicles reaching the end of a link
        for lk in net.links:
            tr = lk.transit
            while tr and tr[0][0] <= t:
                _, v = tr.popleft()
                if lk.dst[0] == "J":
                    j = net.junctions[lk.dst[1]]
                    arm = lk.dst[2]
                    k = int(rng.choice(4, p=j.turn_probs[arm]))
                    v.turn = k
                    v.t_join = t
                    m = arm * 4 + k
                    j.entry[arm].append(v)
                    j.entry_len[m] += v.length
                    j.entry_w[m] += v.w
                    j.joins.append((t, m, v))
                else:
                    lk.sink_q.append(v)
        # 3. shared entry section -> turn pockets (head-of-line blocking)
        for j in net.junctions:
            for arm in range(4):
                e = j.entry[arm]
                while e:
                    v = e[0]
                    mv = j.moves[arm * 4 + v.turn]
                    if mv.queue and mv.q_len_m + v.length > mv.pocket_cap:
                        break
                    e.popleft()
                    j.entry_len[mv.idx] -= v.length
                    j.entry_w[mv.idx] -= v.w
                    mv.push(v)
        # 4. outside world accepts vehicles from exit roads
        for lk in net.sinks:
            lk.sink_credit = min(lk.sink_credit + lk.sink_rate * P.DT, max(1.0, lk.sink_rate))
            while lk.sink_q and lk.sink_credit >= 1.0:
                v = lk.sink_q.popleft()
                lk.sink_credit -= 1.0
                lk.occ -= v.length
                net.done.append((t, v))
        # 5. network layer + controllers + interlock
        if self.bus:
            self.bus.update()
        for jid, j in enumerate(net.junctions):
            self.ctrls[jid].observe(t)
            self._interlock(jid, j, t)
        # 6. discharge through green taps
        for j in net.junctions:
            for m in j.green:
                self._discharge(j, j.moves[m], t)
        # 7. metrics
        self._metrics(t)

    def _interlock(self, jid, j, t):
        c = self.ctrls[jid]
        if self.state[jid] == "C":
            if t >= self.c_end[jid]:
                ph = self.nxt[jid]
                if not is_compatible(ph):  # never energise conflicting taps
                    j.violations += 1
                    ph = frozenset()
                self.state[jid] = "G"
                self.phase[jid] = ph
                self.g_start[jid] = t
                j.green = ph
                for m in ph:
                    mv = j.moves[m]
                    mv.credit = 0.0
                    mv.startup = float(self.rng.uniform(*P.TRUE_STARTUP_LOSS))
                    mv.starved = mv.was_blocked = False
                c.on_green(t, ph)
            else:
                j.green = frozenset()
            return
        el = t - self.g_start[jid]
        prm_min, prm_max = 15.0, 70.0
        if el < prm_min:
            return
        forced = el >= prm_max
        if forced or c.wants_end(t, el):
            nxt = c.choose(t, self.phase[jid], forced)
            if nxt == self.phase[jid] and not forced:
                return  # continuation of the same green
            self.greens_log.append((jid, self.g_start[jid], el, self.phase[jid]))
            self.state[jid] = "C"
            self.c_end[jid] = t + P.AMBER_ALLRED
            self.nxt[jid] = nxt
            j.green = frozenset()

    def _discharge(self, j, mv, t):
        budget = P.DT
        if mv.startup > 0:
            use = min(mv.startup, budget)
            mv.startup -= use
            budget -= use
        mv.credit += budget * mv.lanes
        while True:
            if not mv.queue:
                mv.credit = 0.0
                mv.starved = True
                return
            v = mv.queue[0]
            if mv.head_h is None:
                mv.head_h = self.net.true_headway(v, mv)
            if mv.credit < mv.head_h:
                return
            if not mv.exit_link.room(v.length):
                mv.credit = min(mv.credit, mv.head_h)
                mv.was_blocked = True
                self.blocked_box_s += 1
                return
            mv.pop()
            mv.credit -= mv.head_h
            mv.head_h = None
            mv.in_link.occ -= v.length
            v.ff += P.CROSS_TIME
            mv.exit_link.enter(v, t + P.CROSS_TIME)
            tc = t + P.DT - mv.credit / mv.lanes
            j.events.append((tc, mv.idx, v, mv.starved, mv.was_blocked))
            mv.starved = mv.was_blocked = False

    def _metrics(self, t):
        net = self.net
        for lk in net.links:
            L = lk.loading
            if L >= 0.95 and not self._full[lk.lid]:
                self._full[lk.lid] = True
                self.spill += 1
            elif L < 0.85:
                self._full[lk.lid] = False
        if t % 5:
            return
        qj = []
        for j in net.junctions:
            # queue at each approach, including vehicles held outside at a network gate
            arms = [j.approach_queue_m(a) + sum(v.length for v in j.in_links[a].source_q)
                    for a in range(4)]
            self.max_q_m = max(self.max_q_m, max(arms))
            qj.append(sum(j.approach_queue_m(a) for a in range(4)) / 7.5)
        gate = sum(sum(v.length for v in s.source_q) for s in net.sources) / 7.5
        sink = sum(sum(v.length for v in s.sink_q) for s in net.sinks) / 7.5
        if self.record:
            self.series_t.append(t)
            self.series_q.append(qj)
            self.series_total.append(sum(qj) + gate + sink)
            if t % 60 == 0 and isinstance(self.ctrls[0], BlockTetris):
                lr = self.ctrls[0].learn
                self.series_tau.append((t, list(lr.tau), lr.L))
            if t % 10 == 0:
                self.series_p.append(list(self.bus.p) if self.bus else [0.0] * len(net.links))
                self.series_load.append([lk.loading for lk in net.links])

    def run(self):
        for t in range(self.horizon):
            self.step(t)
        return self.summary()

    def summary(self):
        net, T = self.net, self.horizon
        delays = [te - v.t_spawn - v.ff for te, v in net.done]
        # vehicles still inside: charge their delay so far (no reward for hoarding)
        inside = []
        for lk in net.links:
            inside += list(lk.source_q) + [v for _, v in lk.transit] + list(lk.sink_q)
        for j in net.junctions:
            for e in j.entry:
                inside += list(e)
            for mv in j.moves:
                inside += list(mv.queue)
        delays += [max(0.0, T - v.t_spawn - v.ff) for v in inside]
        out = {
            "ctrl": self.ctrl_name,
            "scenario": self.sc.key,
            "avg_delay_s": float(np.mean(delays)) if delays else 0.0,
            "p95_delay_s": float(np.percentile(delays, 95)) if delays else 0.0,
            "max_queue_blocks": self.max_q_m / 7.5,
            "spillbacks": self.spill,
            "throughput": len(net.done),
            "in_network_end": len(inside),
            "blocked_box_s": self.blocked_box_s,
            "violations": sum(j.violations for j in net.junctions),
        }
        bt = [c for c in self.ctrls if isinstance(c, BlockTetris)]
        if bt:
            out["tau_C"] = list(bt[0].learn.tau)
            out["fturn_C"] = dict(bt[0].learn.fturn)
            out["L_C"] = bt[0].learn.L
            out["sanity_rejects"] = sum(c.rejected for c in bt)
            out["alarms"] = self.bus.alarms
        return out


def run_one(ctrl, scen_key, seed, horizon=HORIZON, keep_series=False):
    sim = Sim(ctrl, SCENARIOS[scen_key], seed, horizon)
    res = sim.run()
    res["seed"] = seed
    res["series_t"] = sim.series_t
    res["series_total"] = sim.series_total
    if keep_series:
        res["series_q"] = sim.series_q
        res["series_p"] = sim.series_p
        res["series_load"] = sim.series_load
        res["link_names"] = [link_name(sim.net, lk) for lk in sim.net.links]
        res["series_tau"] = sim.series_tau
        res["greens_log"] = [(a, b, c) for a, b, c, _ in sim.greens_log]
    return res


def link_name(net, lk):
    def end(e):
        if e[0] == "J":
            return net.junctions[e[1]].name
        return "OUT"
    return f"{end(lk.src) if lk.src[0] == 'J' else 'IN'}->{end(lk.dst)}"
