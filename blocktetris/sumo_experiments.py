"""SUMO validation: the same Coimbatore map, events and controllers, run in the
microscopic simulator SUMO (Eclipse) instead of the electrical twin.

Every controller drives the SAME signal phases (the phase sets netconvert
builds for each junction) through the same 3 s amber + 2 s all-red, so only
the decision logic differs.

  Fixed-40      40 s per green phase, cyclic
  Actuated      SUMO's own built-in actuated controller (gap-based, induction loops)
  MaxPressure   Varaiya: every 10 s serve argmax sum(queue_in - n_out)
  SITRA-MPC     repo mpcSignalModel.m generalised: 12 s base, greedy +1 s by q + 10*demand, max 30 s
  SCOOT-like    Webster plan from measured flows every 5 min
  SCATS-like    cycle follows the worst degree of saturation, splits follow DS
  Block-Tetris  v7-final junction logic + relay / perimeter metering / emergency
                rotation + 120 s service guarantee, on 60 m CCTV with 8 % noise

Not ported to SUMO (documented): diversion orders, Kalman look-ahead, police.

Metric: mean time loss per vehicle (SUMO timeLoss + departDelay), counting
unfinished and never-inserted vehicles up to the horizon.

    python -m blocktetris.sumo_experiments --osm data/osm/coimbatore_peelamedu.json --name peelamedu --seeds 3
"""
import argparse
import json
import os
import pickle
import xml.etree.ElementTree as ET
from collections import defaultdict
from multiprocessing import Pool

import numpy as np

from .sumo_net import build, sumo_bin

VTYPES = {"bike": (0.45, 0.2), "auto": (0.15, 0.3), "car": (0.30, 0.4), "heavy": (0.10, 0.9)}
VTYPE_XML = """<additional>
  <vType id="bike"  vClass="motorcycle" length="2.2" minGap="1.0" maxSpeed="16.7" accel="3.0" decel="6.0" sigma="0.5" tau="1.0" speedDev="0.1"/>
  <vType id="auto"  vClass="taxi"       length="3.0" minGap="1.5" maxSpeed="13.9" accel="1.6" decel="4.5" sigma="0.5" tau="1.0" speedDev="0.1"/>
  <vType id="car"   vClass="passenger"  length="4.3" minGap="2.0" maxSpeed="16.7" accel="2.4" decel="4.5" sigma="0.5" tau="1.0" speedDev="0.1"/>
  <vType id="heavy" vClass="bus"        length="10.0" minGap="2.5" maxSpeed="13.9" accel="1.0" decel="4.0" sigma="0.5" tau="1.2" speedDev="0.1"/>
</additional>
"""
WEIGHT = {k: v[1] for k, v in VTYPES.items()}
T0, T1, HORIZON = 1500, 2700, 5400
EVENTS = ["normal peak", "accident", "monsoon rain", "festival surge", "VIP closure",
          "signal power failure", "CCTV failure"]
CTRLS = ["Fixed-40", "Actuated", "MaxPressure", "SITRA-MPC", "SCOOT-like", "SCATS-like", "Block-Tetris v7-final"]
CLASS_W = {"trunk": 1.0, "primary": 1.0, "secondary": 0.6, "tertiary": 0.35,
           "trunk_link": 0.5, "primary_link": 0.5, "secondary_link": 0.35}
AMBER, ALLRED = 3.0, 2.0


# ───────────────────────────── scenario files ─────────────────────────────
def prepare(osm, name):
    d = os.path.join("sumo", name)
    nf = os.path.join(d, "net.net.xml")
    if not os.path.exists(nf):
        build(osm, d, "static")
    na = os.path.join(d, "net_act.net.xml")
    if not os.path.exists(na):
        os.rename(nf, nf + ".tmp")
        build(osm, d, "actuated")
        os.rename(nf, na)
        os.rename(nf + ".tmp", nf)
    with open(os.path.join(d, "vtypes.add.xml"), "w") as f:
        f.write(VTYPE_XML)
    return d


def fringe(net):
    """Boundary edges: leaving / entering a dead-end node of the major-road graph."""
    src, snk = [], []
    for nd in net.getNodes():
        nb = {e.getToNode().getID() for e in nd.getOutgoing()} | {e.getFromNode().getID() for e in nd.getIncoming()}
        if len(nb) == 1:
            src += [e for e in nd.getOutgoing()]
            snk += [e for e in nd.getIncoming()]
    return src, snk


def edge_w(e):
    t = (e.getType() or "").replace("highway.", "")
    return CLASS_W.get(t, 0.35) * e.getLaneNumber()


def make_routes(d, seed, scale, surge=None):
    """Poisson trips fringe -> fringe with the e-twin morning-peak profile, routed by duarouter."""
    import subprocess
    import sumolib
    net = sumolib.net.readNet(os.path.join(d, "net.net.xml"))
    src, snk = fringe(net)
    rng = np.random.default_rng(seed)
    ws = np.array([edge_w(e) for e in src])
    wk = np.array([edge_w(e) for e in snk])
    wk = wk / wk.sum()
    types = list(VTYPES)
    tp = np.array([VTYPES[k][0] for k in types])
    trips = []
    for i, e in enumerate(src):
        for t in range(HORIZON):
            lam = scale * ws[i] * (0.7 + 0.9 * np.exp(-((t - 2400.0) / 1000.0) ** 2))
            if surge and e.getID() in surge and T0 <= t < T1:
                lam *= 2.5
            for _ in range(rng.poisson(lam)):
                for _try in range(5):
                    k = snk[rng.choice(len(snk), p=wk)]
                    if k.getFromNode() != e.getToNode() and k.getToNode() != e.getFromNode():
                        break
                trips.append((t + rng.random(), e.getID(), k.getID(), types[rng.choice(4, p=tp)]))
    trips.sort()
    tag = f"s{seed}_x{scale:g}" + ("_surge" if surge else "")
    tf = os.path.join(d, f"trips_{tag}.xml")
    with open(tf, "w") as f:
        f.write("<routes>\n")
        for n, (t, a, b, ty) in enumerate(trips):
            f.write(f'  <trip id="v{n}" depart="{t:.2f}" from="{a}" to="{b}" type="{ty}" departLane="best" departSpeed="max"/>\n')
        f.write("</routes>\n")
    rf = os.path.join(d, f"routes_{tag}.rou.xml")
    subprocess.run([sumo_bin("duarouter"), "-n", os.path.join(d, "net.net.xml"), "--route-files", tf,
                    "--additional-files", os.path.join(d, "vtypes.add.xml"), "-o", rf, "--ignore-errors",
                    "--no-warnings", "--no-step-log", "--seed", str(seed)], check=True,
                   stdout=subprocess.DEVNULL)
    txt = open(rf).read()                       # vTypes come from vtypes.add.xml (loaded up front)
    import re
    open(rf, "w").write(re.sub(r"\s*<vType[^>]*/>|\s*<vType.*?</vType>", "", txt, flags=re.S))
    return rf


# ───────────────────────────── controllers ─────────────────────────────
class TLS:
    """One signalised junction: phase machine + measurements shared by all controller types."""

    def __init__(self, tc, tid, kind, rng):
        self.tc, self.id, self.kind, self.rng = tc, tid, kind, rng
        logic = tc.trafficlight.getAllProgramLogics(tid)[0]
        links = tc.trafficlight.getControlledLinks(tid)
        self.n = len(links)
        self.inl = [l[0][0] if l else None for l in links]
        self.outl = [l[0][1] if l else None for l in links]
        self.oute = [o.rsplit("_", 1)[0] if o else None for o in self.outl]
        st = [p.state for p in logic.phases if "y" not in p.state.lower() and ("G" in p.state or "g" in p.state)]
        seen, self.greens = set(), []
        for s in st:
            if s not in seen:
                seen.add(s)
                self.greens.append(s)
        self.G = np.array([[c in "Gg" for c in s] for s in self.greens], bool)
        self.P = len(self.greens)
        self.cur, self.mode, self.t_mode, self.nxt = 0, "G", 0.0, 0
        self.g_start = 0.0
        self.planned = 15.0
        self.last_served = np.zeros(self.n)
        self.wait_since = np.zeros(self.n)
        self.blocked_run = 0
        self.plan_g = np.full(self.P, 30.0)
        self.k_order = 0
        self.ds_busy = np.zeros(self.P)
        self.ds_green = np.zeros(self.P)
        self.flow = np.zeros(self.P)
        self.plan_C = 90.0
        self.last_plan = -1e9
        self.off = False
        self.blind = False
        self.state_str = self.greens[0]
        tc.trafficlight.setRedYellowGreenState(tid, self.state_str)

    def set_state(self, s):
        if s != self.state_str:
            self.state_str = s
            self.tc.trafficlight.setRedYellowGreenState(self.id, s)

    def go(self, nxt, t):
        if nxt == self.cur:
            return
        self.mode, self.t_mode, self.nxt = "Y", t, nxt
        a, b = self.G[self.cur], self.G[nxt]
        self.set_state("".join("G" if a[i] and b[i] else ("y" if a[i] else "r") for i in range(self.n)))

    def tick(self, t):
        """advance amber -> all-red -> green; returns True while a green is running"""
        if self.mode == "Y" and t - self.t_mode >= AMBER:
            a, b = self.G[self.cur], self.G[self.nxt]
            self.mode = "R"
            self.set_state("".join("G" if a[i] and b[i] else "r" for i in range(self.n)))
        if self.mode == "R" and t - self.t_mode >= AMBER + ALLRED:
            self.mode, self.cur, self.g_start = "G", self.nxt, t
            self.set_state(self.greens[self.cur])
            return "new"
        return self.mode == "G"


class Runner:
    def __init__(self, d, ctrl, event, seed, routes, targets):
        self.d, self.ctrl, self.event, self.seed, self.targets = d, ctrl, event, seed, targets
        self.routes = routes
        self.rng = np.random.default_rng(1000 + seed)

    # measurements -----------------------------------------------------------
    def measure(self, t):
        tc = self.tc
        q, cnt, hal = defaultdict(float), defaultdict(float), defaultdict(int)
        for ln in self.in_lanes:
            for v in tc.lane.getLastStepVehicleIDs(ln):
                w = WEIGHT.get(self.vtype[v], 0.4)
                cnt[ln] += w
                if tc.vehicle.getSpeed(v) < 1.0:
                    r = self.route[v]
                    i = tc.vehicle.getRouteIndex(v)
                    nxt = r[i + 1] if 0 <= i < len(r) - 1 else None
                    q[(ln, nxt)] += w
                    hal[(ln, nxt)] += 1
        self.q, self.cnt, self.hal = q, cnt, hal
        fill = {}
        for ln in self.out_lanes:
            fill[ln] = min(1.0, tc.lane.getLastStepOccupancy(ln) / 100.0 * 1.35)
        self.fill = fill
        self.nveh = {ln: tc.lane.getLastStepVehicleNumber(ln) for ln in self.out_lanes}

    def V(self, j):
        """weighted queue per link of junction j (BT: 60 m CCTV + road-count tail, 8 % noise; blind = counts only)"""
        V = np.zeros(j.n)
        share = defaultdict(int)
        for i in range(j.n):
            share[(j.inl[i], j.oute[i])] += 1
        for i in range(j.n):
            if j.inl[i] is None:
                continue
            if j.blind:
                V[i] = 0.6 * self.cnt[j.inl[i]] / max(1, sum(1 for k in range(j.n) if j.inl[k] == j.inl[i]))
            else:
                V[i] = self.q[(j.inl[i], j.oute[i])] / share[(j.inl[i], j.oute[i])]
        if self.ctrl.startswith("Block"):
            V *= np.clip(1 + 0.08 * self.rng.standard_normal(j.n), 0.5, 1.5)
        return V

    def fills(self, j):
        return np.array([self.fill.get(o, 0.0) if o else 1.0 for o in j.outl])

    # network layer (Block-Tetris) -------------------------------------------
    def relay(self):
        tc = self.tc
        load = np.array([min(1.0, tc.edge.getLastStepOccupancy(e) / 100.0 * 1.35) for e in self.edges])
        trig = load >= 0.80
        self.latched = np.where(trig, True, np.where(load < 0.60, False, self.latched))
        local = np.where(self.latched, np.clip((load - 0.60) / 0.40, 0.15, 1.0), 0.0)
        pe = np.append(self.p, 0.0)
        prop = pe[self.down_idx].max(1)
        target = np.maximum(local, 0.5 * prop)
        self.p = np.where(target >= self.p, target, np.maximum(target, self.p - 0.02))
        inner = load[self.inner_mask]
        self.acc = float(inner.mean()) if inner.size else 0.0
        if self.acc >= 0.45:
            self.em = True
        elif self.acc < 0.35:
            self.em = False

    def pe(self, e):
        return self.p[self.eidx[e]] if e in self.eidx else 0.0

    def bt(self, j, t):
        V = self.V(j)
        fz = self.fills(j)
        room_ok = fz < 0.95
        pex = np.array([self.pe(e) if e else 0.0 for e in j.oute])
        age = np.where(V > 0.05, t - j.last_served, 0.0)
        meter = 1.0
        if self.acc > 0.30:
            meter = float(np.clip(1 - (self.acc - 0.30) / 0.15, 0.05, 1.0))
        gate = np.array([(l.rsplit("_", 1)[0] in self.src_ids) if l else False for l in j.inl])
        score = (V + 0.01 * (V / 0.55) * age) * (1 - pex) * np.clip(1 - fz ** 2, 0, 1)
        score = np.where(gate, score * meter, score)
        elig = room_ok & (V > 0.05)
        score = np.where(elig, score, 0.0)
        ps = j.G.astype(float) @ score
        # service bookkeeping
        dem = (V > 0.3) & room_ok
        g = j.G[j.cur] if j.mode == "G" else np.zeros(j.n, bool)
        j.wait_since = np.where(~dem | g, t, j.wait_since)
        j.last_served = np.where(g & (V > 0.05), t, j.last_served)
        if j.mode != "G":
            return
        el = t - j.g_start
        isat = 1.0 / 4.62
        busy = V > 0.5
        gmin = 15.0
        if busy.sum() >= 6 and np.median(V[busy] / isat) > 40.0:
            gmin = 35.0
        if el < gmin:
            return
        if self.em:                                  # emergency rotation (gridlock guard)
            if (V * j.G[j.cur]).sum() < 0.5 or el >= 50.0:
                j.go((j.cur + 1) % j.P, t)
            return
        forced = el >= 70.0
        ph = j.G[j.cur]
        end = forced
        if not end:
            waited = t - j.wait_since
            if (~ph & (waited > 120.0)).any():
                end = True
            blk = (ph & (V > 0.05) & ~room_ok).any()
            j.blocked_run = j.blocked_run + 1 if blk else 0
            if (V * ph).sum() < 0.5 or j.blocked_run >= 3:
                end = True
            if not end and int(el) % 5 == 0:
                r = isat * np.minimum(1.0, V / 0.4) * room_ok * (1 - pex)
                pr = j.G.astype(float) @ r
                if pr.max() > 2.0 * (r * ph).sum() + 0.05:
                    end = True
            if not end and el >= j.planned:
                end = True
        if not end:
            return
        cur = j.cur
        if forced:
            ps[cur] = -1.0
        waited = t - j.wait_since
        late = np.where(waited > 120.0)[0]
        starving = np.where(elig & (age > 150.0))[0]
        pick = None
        for grp, key in ((late, waited), (starving, age)):
            if grp.size and pick is None:
                worst = grp[np.argmax(key[grp])]
                cand = np.where(j.G[:, worst])[0]
                if forced:
                    cand = cand[cand != cur]
                if cand.size:
                    pick = int(cand[np.argmax(ps[cand])])
        if pick is None:
            pick = int(np.argmax(ps))
            if not forced and ps[cur] >= 0.85 * ps[pick] and ps[cur] > 0:
                j.planned = min(70.0, el + 10.0)
                return
        if pick == cur:
            j.planned = min(70.0, el + 10.0)
            return
        j.go(pick, t)

    def on_green_bt(self, j, t):
        V = self.V(j)
        fz = self.fills(j)
        room = (1 - fz) * 10.0                      # ~ W of room on the exit lane
        pex = np.array([self.pe(e) if e else 0.0 for e in j.oute])
        drain = np.minimum(V, np.clip(room, 0, None)) * 4.62
        T = (2.5 + 1.15 * drain) * (1 - 0.5 * pex)
        Ts = T[j.G[j.cur] & (V > 0.05)]
        j.planned = float(np.clip(Ts.max() if Ts.size else 15.0, 15.0, 70.0))
        j.blocked_run = 0

    # cyclic controllers -------------------------------------------------------
    def phase_q(self, j):
        V = self.V(j)
        return np.array([(V * j.G[k]).sum() for k in range(j.P)])

    def cyclic(self, j, t, new):
        V = self.V(j)
        g = j.G[j.cur]
        if j.mode == "G":
            j.ds_green[j.cur] += 1
            if (V * g).sum() > 0.2:
                j.ds_busy[j.cur] += 1
        if new:
            if self.ctrl == "SITRA-MPC" and j.cur == 0:
                self.plan_sitra(j)
            if self.ctrl == "SCATS-like" and j.cur == 0:
                self.plan_scats(j)
        if j.mode != "G":
            return
        el = t - j.g_start
        gk = 40.0 if self.ctrl == "Fixed-40" else max(10.0, j.plan_g[j.cur])
        if self.ctrl == "SCOOT-like" and t - j.last_plan >= 300.0:
            self.plan_scoot(j, t)
        if el >= gk:
            j.go((j.cur + 1) % j.P, t)

    def plan_sitra(self, j):
        q = self.phase_q(j)
        dem = j.flow / max(1.0, j.plan_g.sum() + 5 * j.P)
        g = np.full(j.P, 12.0)
        score = q + 10.0 * dem + np.r_[0.0, np.full(j.P - 1, 0.25)]
        for _ in range(6 * j.P):
            cand = np.where(g < 30.0)[0]
            if not cand.size:
                break
            a = cand[np.argmax(score[cand])]
            if score[a] <= 0:
                break
            g[a] += 1.0
            score[a] = score[a] * 0.985 + 1e-12
        j.plan_g = g
        j.flow[:] = 0.0

    def plan_scats(self, j):
        L = 5.0 * j.P
        ds = np.where(j.ds_green > 0, j.ds_busy / np.maximum(j.ds_green, 1), 0.0)
        dmax = ds.max() if ds.size else 0.0
        C = j.plan_C + (10.0 if dmax > 0.9 else -10.0 if dmax < 0.6 else 0.0)
        C = float(np.clip(C, 40.0, 160.0))
        w = np.maximum(ds, 0.2)
        j.plan_C = C
        j.plan_g = np.maximum(10.0, (C - L) * w / w.sum())
        j.ds_busy[:] = 0
        j.ds_green[:] = 0

    def plan_scoot(self, j, t):
        L = 5.0 * j.P
        dt = max(60.0, t - j.last_plan) if j.last_plan > 0 else max(60.0, t)
        lanes_per = np.array([max(1, len({j.inl[i] for i in range(j.n) if j.G[k, i] and j.inl[i]})) for k in range(j.P)])
        y = (j.flow / dt) / (0.5 * lanes_per)          # veh/s over saturation 1800 veh/h/lane
        Y = y.sum()
        C = (1.5 * L + 5.0) / (1.0 - Y) if Y < 0.9 else 150.0
        C = float(np.clip(C, 40.0, 150.0))
        j.plan_g = np.maximum(10.0, (C - L) * y / max(Y, 1e-9)) if Y > 0 else np.full(j.P, (C - L) / j.P)
        j.flow[:] = 0.0
        j.last_plan = t

    def maxp(self, j, t):
        if j.mode != "G" or t - j.g_start < 10.0 or int(t - j.g_start) % 10:
            return
        w = np.zeros(j.n)
        for i in range(j.n):
            if j.inl[i] is None:
                continue
            w[i] = self.hal[(j.inl[i], j.oute[i])] - 0.25 * self.nveh.get(j.outl[i], 0)
        w = np.clip(w, 0, None)
        ps = j.G.astype(float) @ w
        k = int(np.argmax(ps))
        if ps[k] > ps[j.cur]:
            j.go(k, t)

    # ───────────────────────────── run ─────────────────────────────
    def run(self):
        import libsumo as tc
        self.tc = tc
        d = self.d
        net_file = os.path.join(d, "net_act.net.xml" if self.ctrl == "Actuated" else "net.net.xml")
        trip_out = os.path.join(d, f"_trip_{os.getpid()}.xml")
        tc.start([sumo_bin("sumo"), "-n", net_file, "-r", self.routes,
                  "--additional-files", os.path.join(d, "vtypes.add.xml"),
                  "--tripinfo-output", trip_out, "--tripinfo-output.write-unfinished", "true",
                  "--time-to-teleport", "300", "--seed", str(self.seed), "--no-warnings", "true",
                  "--no-step-log", "true", "--end", str(HORIZON)])
        import sumolib
        net = sumolib.net.readNet(os.path.join(d, "net.net.xml"))
        src, _ = fringe(net)
        self.src_ids = {e.getID() for e in src}
        self.edges = [e.getID() for e in net.getEdges()]
        self.eidx = {e: i for i, e in enumerate(self.edges)}
        self.inner_mask = np.array([e not in self.src_ids for e in self.edges])
        down = []
        for e in net.getEdges():
            nx = [self.eidx[o.getID()] for o in e.getOutgoing()][:3]
            down.append((nx + [-1, -1, -1])[:3])
        self.down_idx = np.array(down)
        self.p = np.zeros(len(self.edges))
        self.latched = np.zeros(len(self.edges), bool)
        self.acc, self.em = 0.0, False
        tg = self.targets
        ev = self.event
        juncs = {}
        if self.ctrl != "Actuated":
            for tid in tc.trafficlight.getIDList():
                juncs[tid] = TLS(tc, tid, self.ctrl, self.rng)
        self.in_lanes = sorted({l for j in juncs.values() for l in j.inl if l})
        self.out_lanes = sorted({l for j in juncs.values() for l in j.outl if l})
        self.vtype, self.route = {}, {}
        prev_ids = {ln: set() for ln in self.in_lanes}
        self.lane_j = defaultdict(list)
        for j in juncs.values():
            for k in range(j.P):
                for ln in {j.inl[i] for i in range(j.n) if j.G[k, i] and j.inl[i]}:
                    self.lane_j[ln].append((j, k))
        teleports = 0
        closed = set()
        rain_on = False
        base_tau = {k: tc.vehicletype.getTau(k) for k in VTYPES}
        base_sf = {k: tc.vehicletype.getSpeedFactor(k) for k in VTYPES}
        allowed = {}
        for t in range(HORIZON):
            # ── events ──
            if ev == "accident" and t in (T0, T1):
                e = tg["road"]
                nl = tc.edge.getLaneNumber(e)
                for k in range(nl):
                    ln = f"{e}_{k}"
                    if t == T0:
                        allowed[ln] = tc.lane.getAllowed(ln)
                        if k < nl - 1:
                            tc.lane.setAllowed(ln, ["custom1"])
                        tc.lane.setMaxSpeed(ln, 2.0)
                    else:
                        tc.lane.setAllowed(ln, allowed[ln])
                        tc.lane.setMaxSpeed(ln, net.getEdge(e).getSpeed())
                if t == T0 and nl == 1:
                    tc.lane.setMaxSpeed(f"{e}_0", 1.0)
            if ev == "VIP closure" and t in (T0, T0 + 600):
                for e in tg["roads3"]:
                    for k in range(tc.edge.getLaneNumber(e)):
                        ln = f"{e}_{k}"
                        if t == T0:
                            allowed[ln] = tc.lane.getAllowed(ln)
                            tc.lane.setAllowed(ln, ["custom1"])
                        else:
                            tc.lane.setAllowed(ln, allowed[ln])
                    tc.edge.adaptTraveltime(e, 1e6 if t == T0 else net.getEdge(e).getLength() / net.getEdge(e).getSpeed())
                closed = set(tg["roads3"]) if t == T0 else set()
                if t == T0:
                    for v in tc.vehicle.getIDList():
                        r = tc.vehicle.getRoute(v)
                        i = tc.vehicle.getRouteIndex(v)
                        if closed & set(r[i + 1:]):
                            try:
                                tc.vehicle.rerouteTraveltime(v)
                            except Exception:
                                pass
            if ev == "monsoon rain" and t in (T0, T1 + 600):
                rain_on = t == T0
                for k in VTYPES:
                    tc.vehicletype.setTau(k, base_tau[k] * (1.6 if rain_on else 1.0))
                    tc.vehicletype.setSpeedFactor(k, base_sf[k] * (0.8 if rain_on else 1.0))
            if ev == "signal power failure" and t in (T0, T1):
                for tid in tg["junc2"]:
                    if t == T0:
                        tc.trafficlight.setProgram(tid, "off")
                        if tid in juncs:
                            juncs[tid].off = True
                    else:
                        if tid in juncs:
                            juncs[tid].off = False
                            juncs[tid].state_str = ""
                            juncs[tid].set_state(juncs[tid].greens[juncs[tid].cur])
                        else:
                            tc.trafficlight.setProgram(tid, "0")
            if ev == "CCTV failure" and t in (T0, T1):
                for tid in tg["junc2"]:
                    if tid in juncs:
                        juncs[tid].blind = t == T0
            tc.simulationStep()
            teleports += tc.simulation.getStartingTeleportNumber()
            for v in tc.simulation.getDepartedIDList():
                self.vtype[v] = tc.vehicle.getTypeID(v)
                if closed:
                    r = tc.vehicle.getRoute(v)
                    if closed & set(r):
                        try:
                            tc.vehicle.rerouteTraveltime(v)
                        except Exception:
                            pass
                self.route[v] = tc.vehicle.getRoute(v)
            if closed and t == T0:
                for v in tc.vehicle.getIDList():
                    self.route[v] = tc.vehicle.getRoute(v)
            if not juncs:
                continue
            self.measure(t)
            # arrivals per phase (flow counters for SITRA / SCOOT)
            if self.ctrl in ("SITRA-MPC", "SCOOT-like"):
                for ln in self.in_lanes:
                    ids = set(tc.lane.getLastStepVehicleIDs(ln))
                    newc = len(ids - prev_ids[ln])
                    prev_ids[ln] = ids
                    if newc:
                        for j in self.lane_j.get(ln, ()):
                            jj, ks = j
                            jj.flow[ks] += newc
            if self.ctrl.startswith("Block"):
                self.relay()
            for j in juncs.values():
                if j.off:
                    continue
                new = j.tick(t)
                if self.ctrl.startswith("Block"):
                    if new == "new":
                        self.on_green_bt(j, t)
                    self.bt(j, t)
                elif self.ctrl == "MaxPressure":
                    self.maxp(j, t)
                else:
                    self.cyclic(j, t, new == "new")
        loaded = tc.simulation.getLoadedNumber() if hasattr(tc.simulation, "getLoadedNumber") else None
        tc.close()
        return self.metrics(trip_out, teleports)

    def metrics(self, trip_out, teleports):
        tl, waits, arrived, n = [], [], 0, 0
        seen = set()
        for _, el in ET.iterparse(trip_out):
            if el.tag != "tripinfo":
                continue
            seen.add(el.get("id"))
            loss = float(el.get("timeLoss")) + float(el.get("departDelay"))
            tl.append(loss)
            waits.append(float(el.get("waitingTime")))
            arrived += el.get("arrival", "-1") not in ("-1", "-1.00")
            el.clear()
        os.remove(trip_out)
        # vehicles never inserted by the horizon: their whole wait is delay
        for _, el in ET.iterparse(self.routes):
            if el.tag == "vehicle" and el.get("id") not in seen:
                dep = float(el.get("depart"))
                if dep < HORIZON:
                    tl.append(HORIZON - dep)
                    waits.append(HORIZON - dep)
            el.clear() if el.tag == "vehicle" else None
        tl, waits = np.array(tl), np.array(waits)
        return dict(delay=float(tl.mean()), p95_wait=float(np.percentile(waits, 95)), max_wait=float(waits.max()),
                    arrived=int(arrived), vehicles=int(len(tl)), served=float(arrived / max(1, len(tl))),
                    teleports=int(teleports))


# ───────────────────────────── experiment ─────────────────────────────
def probe_targets(d, routes):
    """busiest road / 3 roads / 3 gates / 2 junctions under Fixed-40 normal peak (like the e-twin)"""
    import libsumo as tc
    import sumolib
    net = sumolib.net.readNet(os.path.join(d, "net.net.xml"))
    src, snk = fringe(net)
    srcs, snks = {e.getID() for e in src}, {e.getID() for e in snk}
    tc.start([sumo_bin("sumo"), "-n", os.path.join(d, "net.net.xml"), "-r", routes,
              "--additional-files", os.path.join(d, "vtypes.add.xml"), "--no-warnings", "true",
              "--no-step-log", "true", "--end", str(T1)])
    edges = [e.getID() for e in net.getEdges()]
    occ = defaultdict(float)
    hal = defaultdict(float)
    gate = defaultdict(int)
    tls = tc.trafficlight.getIDList()
    tl_in = {t: {l[0][0] for l in tc.trafficlight.getControlledLinks(t) if l} for t in tls}
    for t in range(T1):
        tc.simulationStep()
        for v in tc.simulation.getDepartedIDList():
            gate[tc.vehicle.getRoute(v)[0]] += 1
        if t % 10 == 0 and t >= 600:
            for e in edges:
                occ[e] += tc.edge.getLastStepOccupancy(e)
            for x in tls:
                hal[x] += sum(tc.lane.getLastStepHaltingNumber(l) for l in tl_in[x])
    tc.close()
    inner = [e for e in edges if e not in srcs and e not in snks and not e.startswith(":")
             and net.getEdge(e).getLength() > 60]
    inner.sort(key=lambda e: -occ[e])
    return dict(road=inner[0], roads3=inner[:3], gates3=sorted(gate, key=lambda g: -gate[g])[:3],
                junc2=sorted(tls, key=lambda x: -hal[x])[:2])


def _job(a):
    d, ctrl, ev, seed, routes, tg = a
    r = Runner(d, ctrl, ev, seed, routes, tg).run()
    r.update(name=ctrl, ev=ev, seed=seed)
    return r


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--osm", default="data/osm/coimbatore_peelamedu.json")
    ap.add_argument("--name", default="peelamedu")
    ap.add_argument("--seeds", type=int, default=3)
    ap.add_argument("--scale", type=float, default=0.05, help="veh/s per lane-weight at a gate (off-peak)")
    ap.add_argument("--events", default="")
    ap.add_argument("--controllers", default="")
    ap.add_argument("--out", default="")
    ap.add_argument("--procs", type=int, default=0)
    a = ap.parse_args()
    out = a.out or f"Results/BlockTetris/sumo_{a.name}"
    os.makedirs(os.path.join(out, "jobs"), exist_ok=True)
    d = prepare(a.osm, a.name)
    events = a.events.split(",") if a.events else EVENTS
    ctrls = a.controllers.split(",") if a.controllers else CTRLS
    seeds = list(range(11, 11 + a.seeds))
    base = {s: make_routes(d, s, a.scale) for s in seeds}
    tgf = os.path.join(out, f"targets_x{a.scale:g}.json")
    if os.path.exists(tgf):
        tg = json.load(open(tgf))
    else:
        tg = probe_targets(d, base[seeds[0]])
        json.dump(tg, open(tgf, "w"), indent=1)
    print("targets", tg, flush=True)
    surge = {s: make_routes(d, s, a.scale, surge=set(tg["gates3"])) for s in seeds} if "festival surge" in events else {}
    jobs, rows = [], []
    key = lambda c, e, s: f"{c}|{e}|{s}|x{a.scale:g}".replace(" ", "_").replace("/", "_")
    for c in ctrls:
        for e in events:
            for s in seeds:
                fp = os.path.join(out, "jobs", key(c, e, s) + ".pkl")
                if os.path.exists(fp):
                    rows.append(pickle.load(open(fp, "rb")))
                else:
                    jobs.append((d, c, e, s, surge[s] if e == "festival surge" else base[s], tg))
    print(f"{len(rows)} cached, {len(jobs)} to run", flush=True)
    with Pool(a.procs or None) as p:
        for i, r in enumerate(p.imap_unordered(_job, jobs, chunksize=1)):
            pickle.dump(r, open(os.path.join(out, "jobs", key(r["name"], r["ev"], r["seed"]) + ".pkl"), "wb"))
            rows.append(r)
            print(f"[{i + 1}/{len(jobs)}] {r['name']} | {r['ev']} | seed {r['seed']}: delay {r['delay']:.0f} s, "
                  f"served {r['served']:.2f}, teleports {r['teleports']}", flush=True)
    table = {}
    for c in ctrls:
        for e in events:
            rr = [r for r in rows if r["name"] == c and r["ev"] == e]
            if rr:
                table[f"{e}|{c}"] = {k: float(np.mean([r[k] for r in rr])) for k in
                                     ("delay", "p95_wait", "max_wait", "served", "teleports", "vehicles")}
    json.dump(dict(scale=a.scale, seeds=seeds, targets=tg, table=table, rows=rows),
              open(os.path.join(out, f"results_x{a.scale:g}.json"), "w"), indent=1)
    print(f"\nmean time loss per vehicle (s)\n{'event':22s} " + " ".join(f"{c[:12]:>12s}" for c in ctrls))
    for e in events:
        print(f"{e:22s} " + " ".join(f"{table.get(f'{e}|{c}', {}).get('delay', float('nan')):12.0f}" for c in ctrls))
    print(f"\nserved fraction / teleports")
    for e in events:
        print(f"{e:22s} " + " ".join(f"{table.get(f'{e}|{c}', {}).get('served', float('nan')):6.2f}/"
                                     f"{table.get(f'{e}|{c}', {}).get('teleports', float('nan')):5.0f}" for c in ctrls))
    plots(table, events, ctrls, out)


def plots(table, events, ctrls, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    cols = {"Fixed-40": "#999999", "Actuated": "#22aa77", "MaxPressure": "#ee6633", "SITRA-MPC": "#7a3fa0",
            "SCOOT-like": "#6655dd", "SCATS-like": "#e57aa0", "Block-Tetris v7-final": "#111111"}
    fig, ax = plt.subplots(figsize=(14, 4.5))
    w = 0.8 / len(ctrls)
    for i, c in enumerate(ctrls):
        ys = [table.get(f"{e}|{c}", {}).get("delay", np.nan) for e in events]
        ax.bar(np.arange(len(events)) + (i - len(ctrls) / 2 + 0.5) * w, ys, w, label=c, color=cols.get(c))
    ax.set_xticks(range(len(events)))
    ax.set_xticklabels(events)
    ax.set_ylabel("Mean time loss per vehicle (s)")
    ax.set_title("SUMO validation (microscopic): same map, events and controllers")
    ax.legend(ncol=4, fontsize=8, frameon=False)
    ax.spines[["top", "right"]].set_visible(False)
    fig.tight_layout()
    fig.savefig(os.path.join(out, "sumo1_delay_by_event.png"), dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    main()
