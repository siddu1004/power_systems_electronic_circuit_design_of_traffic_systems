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
import zlib
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
CTRLS = ["Fixed-40", "Actuated", "MaxPressure", "SITRA-MPC", "SCOOT-like", "SCATS-like", "Block-Tetris v7-final",
         "Block-Tetris v8"]
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
        self.mu = np.zeros(self.n)
        self.var = np.zeros(self.n)
        self.alerted = False
        self.last_move = 0.0
        self.gmin_j = None
        self.low_off = False
        self.calm_since = 0.0
        self.off_since = 0.0
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


BT_V7F = dict(gmin=15.0, gsat=35.0, gmax=70.0, low=0.5, roll=2.0, mp=0.0, dark_p=0.0,
              dyn=False, z=1.0, gdyn=60.0, reroute=False, comply=0.5, alert=False,
              lowoff=False, adapt_gmin=False, area=False, cam=False, est=False)
# v8 = v7-final + back-pressure in weight units (exit-lane load subtracted from the stack),
# chosen on tuning seeds 1-3 (sumo_tune.py); validated on the untouched seeds 11-13
BT_V8 = dict(BT_V7F, mp=0.25)
# v9 (design from the project owner, 13 Nov):
#  * fixed + dynamic green: every served phase keeps a fixed minimum; the extension is shared by
#    the phases' queue mean + standard deviation (EWMA statistics of each stack)
#  * forward/backward thinking: a stack is valued by the probability that its exit road does NOT
#    overflow (exit fill mean / std), and a green is cut where the exit would fill (mean + z*std)
#  * pressure rerouting: every 60 s each road's cost = travel + queue / measured leave rate +
#    capacity penalty; a share of vehicles headed into a hot road re-route (navigation-app style)
#  * green-but-not-moving -> police alert with the decision and its justification (logged)
BT_V9 = dict(BT_V7F, dyn=True, reroute=True, alert=True)
BT_VARIANTS = {"Block-Tetris v7-final": BT_V7F, "Block-Tetris v8": BT_V8, "Block-Tetris v9": BT_V9,
               "Block-Tetris v9 (no reroute)": dict(BT_V9, reroute=False),
               "Block-Tetris v7-final + reroute": dict(BT_V7F, reroute=True, alert=True)}
# v10 = v9 + (owner, 13 Nov): signal off when traffic is very light (give-way rules, hysteresis);
# the fixed minimum green shrinks where it is wasted (>= 7 s) and grows back where queues remain;
# block area per road: the stack a road may take depends on its lanes, its average fill and its
# incident history (each spill-back tightens it, quiet periods relax it) - used in every room test
BT_V10 = dict(BT_V9, lowoff=True, adapt_gmin=True, area=True)
BT_VARIANTS["Block-Tetris v10"] = BT_V10
BT_VARIANTS["Block-Tetris v10 (no reroute)"] = dict(BT_V10, reroute=False)
# v11 = every version combined (v3 core + v4/v6 estimation + v5 blind rebuild + v7-final guarantee and
# police alerts + v9 dynamic green / look-ahead / rerouting + v10 signal-off / adaptive fixed time /
# block area) on REALISTIC cameras (60 m view, noise, occlusion, outliers, failures) through the
# robust lane estimator (KCL counts + Kalman + gate + Huber + lower bound + frozen-camera test).
# Ablations on the same realistic cameras show what the estimator itself is worth.
BT_V11 = dict(BT_V10, cam=True, est=True)
BT_VARIANTS["Block-Tetris v11 (unified)"] = BT_V11
BT_VARIANTS["Block-Tetris v10 (real camera, no estimator)"] = dict(BT_V10, cam=True)
BT_VARIANTS["Block-Tetris v7-final (real camera, no estimator)"] = dict(BT_V7F, cam=True)
# v12 candidate: tuning showed v9's statistics-timed green (dyn) costs delay while rerouting helps,
# so v12 = v11 without dyn: v7-final core + pressure rerouting + police alerts + v10 signal-off /
# adaptive fixed time / block area + realistic cameras through the robust estimator
BT_V12 = dict(BT_V11, dyn=False)
BT_VARIANTS["Block-Tetris v12"] = BT_V12
BT_VARIANTS["Block-Tetris v12 (oracle camera)"] = dict(BT_V12, cam=False, est=False)


class Runner:
    def __init__(self, d, ctrl, event, seed, routes, targets):
        self.d, self.ctrl, self.event, self.seed, self.targets = d, ctrl, event, seed, targets
        self.routes = routes
        self.bo = BT_VARIANTS.get(ctrl, BT_V7F)
        self.rng = np.random.default_rng(1000 + seed)

    # measurements -----------------------------------------------------------
    def measure(self, t):
        tc = self.tc
        q, cnt, hal = defaultdict(float), defaultdict(float), defaultdict(int)
        for ln in self.in_lanes:
            for v in tc.lane.getLastStepVehicleIDs(ln):
                if v not in self.route:
                    continue
                w = WEIGHT.get(self.vtype[v], 0.4)
                cnt[ln] += w
                if tc.vehicle.getSpeed(v) < 1.0:
                    r = self.route[v]
                    i = tc.vehicle.getRouteIndex(v)
                    nxt = r[i + 1] if 0 <= i < len(r) - 1 else None
                    q[(ln, nxt)] += w
                    hal[(ln, nxt)] += 1
        self.q, self.cnt, self.hal = q, cnt, hal
        if self.ctrl.startswith("Block") and (self.bo["cam"] or self.bo["est"]):
            vis = {}
            for ln in self.in_lanes:
                Lh = self.lane_len[ln]
                vq, nh, full, comp = 0.0, 0, False, defaultdict(float)
                for v in tc.lane.getLastStepVehicleIDs(ln):
                    if v not in self.route:
                        continue
                    pos = tc.vehicle.getLanePosition(v)
                    if pos < Lh - 60.0:
                        continue
                    w = WEIGHT.get(self.vtype[v], 0.4)
                    r = self.route[v]
                    i = tc.vehicle.getRouteIndex(v)
                    comp[r[i + 1] if 0 <= i < len(r) - 1 else None] += w
                    if self.vtype[v] == "heavy":
                        nh += 1
                    if tc.vehicle.getSpeed(v) < 1.0:
                        vq += w
                        if pos < Lh - 52.0:
                            full = True
                vis[ln] = (vq, nh, full, dict(comp))
            self.vis = vis
            if self.bo["est"]:
                truth = defaultdict(float)
                for (ln, _), w in q.items():
                    truth[ln] += w
                self.Qhat = self.est.step(t, truth, vis)
            else:
                self.zcam = {}
                for ln in self.in_lanes:
                    vq, nh, full, _ = vis[ln]
                    self.zcam[ln] = self.est.camera(ln, vq, nh, full)
        fill = {}
        for ln in self.out_lanes:
            fill[ln] = min(1.0, tc.lane.getLastStepOccupancy(ln) / 100.0 * 1.35)
        self.fill = fill
        self.nveh = {ln: tc.lane.getLastStepVehicleNumber(ln) for ln in self.out_lanes}
        if self.bo["dyn"]:
            a = 0.05
            for ln, f in fill.items():
                m = self.fmu.get(ln, f)
                v = self.fvar.get(ln, 0.0)
                d = f - m
                self.fmu[ln] = m + a * d
                self.fvar[ln] = (1 - a) * (v + a * d * d)

    def V(self, j):
        """weighted queue per link of junction j (BT: 60 m CCTV + road-count tail, 8 % noise; blind = counts only)"""
        V = np.zeros(j.n)
        share = defaultdict(int)
        for i in range(j.n):
            share[(j.inl[i], j.oute[i])] += 1
        real = self.ctrl.startswith("Block") and (self.bo["cam"] or self.bo["est"])
        for i in range(j.n):
            l = j.inl[i]
            if l is None:
                continue
            if real:
                nx = {j.oute[k] for k in range(j.n) if j.inl[k] == l}
                f = self.est.split(l, j.oute[i])
                if f is None:
                    f = 1.0 / max(1, len(nx))
                if self.bo["est"]:
                    lane_q = self.Qhat.get(l, 0.0)
                else:
                    z = self.zcam.get(l)
                    lane_q = (0.6 * self.cnt[l]) if (z is None or j.blind) else z
                V[i] = lane_q * f / share[(l, j.oute[i])]
            elif j.blind:
                V[i] = 0.6 * self.cnt[l] / max(1, sum(1 for k in range(j.n) if j.inl[k] == l))
            else:
                V[i] = self.q[(l, j.oute[i])] / share[(l, j.oute[i])]
        if self.ctrl.startswith("Block") and not real:
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
        if self.bo["dark_p"] > 0 and self.dark_edges:
            # a dark junction discharges at give-way rates: throttle what is sent into it
            for e in self.dark_edges:
                if e in self.eidx:
                    self.p[self.eidx[e]] = max(self.p[self.eidx[e]], self.bo["dark_p"])
        inner = load[self.inner_mask]
        self.acc = float(inner.mean()) if inner.size else 0.0
        if self.acc >= 0.45:
            self.em = True
        elif self.acc < 0.35:
            self.em = False

    def pe(self, e):
        return self.p[self.eidx[e]] if e in self.eidx else 0.0

    def lim(self, j):
        """block area of each exit lane: fill a lane may take before it counts as full"""
        if not self.bo["area"]:
            return np.full(j.n, 0.9)
        return np.array([self.area_lim(l) for l in j.outl])

    def area_lim(self, l):
        if not l:
            return 0.0
        h = self.lim_hist.get(l)
        if h is None:
            nl = self.tc.edge.getLaneNumber(l.rsplit("_", 1)[0])
            h = self.lim_base[l] = self.lim_hist[l] = {1: 0.75, 2: 0.85}.get(nl, 0.9)
        return max(0.55, h - 0.1 * max(0.0, self.fmu.get(l, 0.0) - 0.5))

    def area_update(self, t):
        """incident history: a spill-back (fill >= 0.95) tightens that lane's block area by 0.05
        (floor 0.6); 5 quiet minutes relax it by 0.01 back toward its base"""
        for l, f in self.fill.items():
            if l not in self.lim_hist:
                self.area_lim(l)
            full = f >= 0.95
            if full and not self.spilled.get(l):
                self.lim_hist[l] = max(0.6, self.lim_hist[l] - 0.05)
                self.last_inc[l] = t
            self.spilled[l] = full
            if t - self.last_inc.get(l, -1e9) >= 300 and t % 300 == 0:
                self.lim_hist[l] = min(self.lim_base[l], self.lim_hist[l] + 0.01)

    def low_traffic(self, j, t):
        """very light traffic: hand the junction to give-way rules; back on as soon as a stack builds"""
        V = self.V(j)
        tot = V.sum()
        if not j.low_off:
            calm = tot < 0.8 and V.max() < 0.5
            if not calm:
                j.calm_since = t
            elif t - j.calm_since >= 120.0 and j.mode == "G":
                j.low_off, j.off_since = True, t
                self.tc.trafficlight.setProgram(j.id, "off")
                self.low_off_s += 0
            return j.low_off
        self.low_off_s += 1
        if (tot > 2.0 or V.max() > 1.2) and t - j.off_since >= 30.0:
            j.low_off = False
            j.calm_since = t
            j.state_str = ""
            j.mode, j.g_start = "G", t
            j.set_state(j.greens[j.cur])
            self.on_green_bt(j, t)
        return j.low_off

    def bt(self, j, t):
        V = self.V(j)
        fz = self.fills(j)
        LIM = self.lim(j)
        room_ok = fz < (LIM + 0.05 if self.bo["area"] else 0.95)
        pex = np.array([self.pe(e) if e else 0.0 for e in j.oute])
        age = np.where(V > 0.05, t - j.last_served, 0.0)
        meter = 1.0
        if self.acc > 0.30:
            meter = float(np.clip(1 - (self.acc - 0.30) / 0.15, 0.05, 1.0))
        gate = np.array([(l.rsplit("_", 1)[0] in self.src_ids) if l else False for l in j.inl])
        o = self.bo
        Vn = V
        if o["mp"] > 0:                              # back-pressure in weight units (MaxPressure-style)
            wout = np.array([0.4 * self.nveh.get(l, 0) if l else 0.0 for l in j.outl])
            Vn = np.clip(V - o["mp"] * wout, 0, None)
        if o["dyn"]:
            a = 0.05
            d = V - j.mu
            j.mu = j.mu + a * d
            j.var = (1 - a) * (j.var + a * d * d)
            # backward thinking: chance that the exit road does NOT overflow (Gaussian on its fill)
            from math import erf
            fm = np.array([self.fmu.get(l, 0.0) if l else 1.0 for l in j.outl])
            fs = np.sqrt(np.array([self.fvar.get(l, 0.0) if l else 0.0 for l in j.outl])) + 0.03
            safe = np.array([0.5 * (1 + erf(x / 1.41421356)) for x in (LIM - np.maximum(fm, fz)) / fs])
            score = (Vn + 0.01 * (V / 0.55) * age) * (1 - pex) * safe
        else:
            score = (Vn + 0.01 * (V / 0.55) * age) * (1 - pex) * np.clip(1 - fz ** 2, 0, 1)
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
        if o["alert"] and not j.alerted and el >= 20.0 and (V * j.G[j.cur]).sum() > 1.0 \
                and t - j.last_move >= 20.0:
            j.alerted = True
            self.alerts.append(dict(t=int(t), tls=j.id, phase=int(j.cur), queue_W=round(float((V * j.G[j.cur]).sum()), 2),
                                    exit_fill=round(float(self.fills(j)[j.G[j.cur]].max()), 2),
                                    decision="green held, no discharge for 20 s: request officer; "
                                             "upstream signals throttle feed into this junction",
                                    why="stack waiting under green while the exits are not moving"))
        busy = V > 0.5
        gmin = o["gmin"] if not o["adapt_gmin"] or j.gmin_j is None else j.gmin_j
        if busy.sum() >= 6 and np.median(V[busy] / isat) > 40.0:
            gmin = o["gsat"]
        if el < gmin:
            return
        if self.em:                                  # emergency rotation (gridlock guard)
            if (V * j.G[j.cur]).sum() < 0.5 or el >= 50.0:
                j.go((j.cur + 1) % j.P, t)
            return
        forced = el >= o["gmax"]
        ph = j.G[j.cur]
        end = forced
        if not end:
            waited = t - j.wait_since
            if (~ph & (waited > 120.0)).any():
                end = True
            blk = (ph & (V > 0.05) & ~room_ok).any()
            j.blocked_run = j.blocked_run + 1 if blk else 0
            if (V * ph).sum() < o["low"] or j.blocked_run >= 3:
                end = True
                if o["adapt_gmin"] and (V * ph).sum() < o["low"] and el <= gmin + 1.0:
                    # the fixed part outlasted the stack: shrink this junction's fixed time
                    j.gmin_j = max(7.0, (j.gmin_j or o["gmin"]) - 1.0)
            elif o["adapt_gmin"] and el >= j.planned and (V * ph).sum() >= 2.0:
                j.gmin_j = min(o["gmin"], (j.gmin_j or o["gmin"]) + 0.5)
            if not end and int(el) % 5 == 0:
                r = isat * np.minimum(1.0, V / 0.4) * room_ok * (1 - pex)
                pr = j.G.astype(float) @ r
                if pr.max() > o["roll"] * (r * ph).sum() + 0.05:
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
                j.planned = min(o["gmax"], el + 10.0)
                return
        if pick == cur:
            j.planned = min(o["gmax"], el + 10.0)
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
        o = self.bo
        j.planned = float(np.clip(Ts.max() if Ts.size else o["gmin"], o["gmin"], o["gmax"]))
        j.blocked_run = 0
        j.alerted = False
        if o["dyn"]:
            # fixed allocation (gmin) + dynamic share of gdyn by mean + std of each phase's stacks
            S = j.G.astype(float) @ (j.mu + np.sqrt(j.var))
            tot = S[S > 0.05].sum()
            Tdyn = o["gdyn"] * S[j.cur] / tot if tot > 0 else 0.0
            # forward thinking: stop before the exit fills (mean + z * std of its fill)
            Troom = []
            for i in np.where(j.G[j.cur] & (V > 0.05))[0]:
                l = j.outl[i]
                if not l:
                    continue
                capW = self.tc.lane.getLength(l) * 0.075
                head = (self.area_lim(l) if o["area"] else 0.9) - self.fmu.get(l, fz[i]) \
                    - o["z"] * np.sqrt(self.fvar.get(l, 0.0))
                Troom.append(max(0.0, head) * capW * 4.62)
            Tplan = o["gmin"] + Tdyn
            if Troom:
                Tplan = min(Tplan, max(o["gmin"], min(Troom)))
            j.planned = float(np.clip(Tplan, o["gmin"], o["gmax"]))

    def reroute(self, t, closed):
        """pressure rerouting: road cost = free travel + queue / measured leave rate + capacity
        penalty; vehicles whose next roads are hot re-route (compliance share, at most every 120 s)"""
        tc = self.tc
        qe = defaultdict(float)
        for (ln, _), w in self.q.items():
            qe[ln.rsplit("_", 1)[0]] += w
        hot = set()
        for e, lanes in self.edge_lanes.items():
            if e in closed or e.startswith(":"):
                continue
            rate = max(sum(self.orate.get(l, 0.0) for l in lanes), 0.05)
            delay = min(qe.get(e, 0.0) / rate, 900.0)
            fill = min(1.0, tc.edge.getLastStepOccupancy(e) / 100.0 * 1.35)
            pen = 0.0 if fill < 0.8 else (fill - 0.8) / 0.2 * 300.0
            tc.edge.adaptTraveltime(e, self.edge_tt[e] + delay + pen)
            if fill >= 0.8 or delay >= 90.0:
                hot.add(e)
        if not hot:
            return
        for v in tc.vehicle.getIDList():
            if v.startswith("_") or v not in self.route:
                continue
            if (zlib.crc32(v.encode()) % 100) >= 100 * self.bo["comply"] or t - self.last_rr.get(v, -1e9) < 120:
                continue
            r = self.route[v]
            i = tc.vehicle.getRouteIndex(v)
            if hot & set(r[i + 1:i + 4]):
                try:
                    tc.vehicle.rerouteTraveltime(v, False)
                    nr = tc.vehicle.getRoute(v)
                    if list(nr) != list(r):
                        self.n_reroute += 1
                    self.route[v] = nr
                    self.last_rr[v] = t
                except Exception:
                    pass

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
        self.dark_edges = set()
        self.fmu, self.fvar = {}, {}
        self.lim_hist, self.lim_base, self.spilled, self.last_inc = {}, {}, {}, {}
        self.low_off_s = 0
        self.alerts, self.n_reroute = [], 0
        self.orate = defaultdict(float)
        self.last_rr = {}
        self.edge_lanes = {e.getID(): [l.getID() for l in e.getLanes()] for e in net.getEdges()}
        self.edge_tt = {e.getID(): e.getLength() / max(e.getSpeed(), 1.0) for e in net.getEdges()}
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
        self.lane_len = {ln: tc.lane.getLength(ln) for ln in self.in_lanes}
        self.est, self.Qhat, self.zcam, self.vis = None, {}, {}, {}
        if self.ctrl.startswith("Block") and (self.bo["cam"] or self.bo["est"]):
            from .sumo_estimator import RobustQueueEstimator
            self.est = RobustQueueEstimator(tc, self.in_lanes, np.random.default_rng(2000 + self.seed),
                                            lambda v: WEIGHT.get(self.vtype.get(v, "car"), 0.4),
                                            lambda l: tc.lane.getMaxSpeed(l))
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
                # crash: stopped vehicles block all lanes but one; traffic squeezes past at low speed
                e = tg["road"]
                nl = tc.edge.getLaneNumber(e)
                L = net.getEdge(e).getLength()
                if t == T0:
                    tc.route.add("_acc_r", [e])
                    for k in range(max(0, nl - 1)):
                        vid = f"_acc{k}"
                        tc.vehicle.add(vid, "_acc_r", typeID="car", departLane=str(k), departPos=str(L * 0.5))
                        tc.vehicle.setStop(vid, e, pos=min(L - 1, L * 0.5 + 5), laneIndex=k, duration=T1 - T0)
                    for k in range(nl):
                        tc.lane.setMaxSpeed(f"{e}_{k}", 3.0 if nl > 1 else 1.5)
                else:
                    for k in range(max(0, nl - 1)):
                        try:
                            tc.vehicle.remove(f"_acc{k}")
                        except Exception:
                            pass
                    for k in range(nl):
                        tc.lane.setMaxSpeed(f"{e}_{k}", net.getEdge(e).getSpeed())
            if ev == "VIP closure" and t in (T0, T0 + 600):
                # barricade: the 3 roads pass (almost) nothing; routing avoids them where an alternative exists
                for e in tg["roads3"]:
                    for k in range(tc.edge.getLaneNumber(e)):
                        tc.lane.setMaxSpeed(f"{e}_{k}", 0.1 if t == T0 else net.getEdge(e).getSpeed())
                    tc.edge.adaptTraveltime(e, 1e6 if t == T0 else net.getEdge(e).getLength() / net.getEdge(e).getSpeed())
                closed = set(tg["roads3"]) if t == T0 else set()
                if t == T0:
                    for v in tc.vehicle.getIDList():
                        if v.startswith("_"):
                            continue
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
                            self.dark_edges |= {l.rsplit("_", 1)[0] for l in juncs[tid].inl if l}
                    else:
                        self.dark_edges = set()
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
                        if self.est is not None:
                            ls = {l for l in juncs[tid].inl if l}
                            self.est.dead = (self.est.dead | ls) if t == T0 else (self.est.dead - ls)
            tc.simulationStep()
            teleports += tc.simulation.getStartingTeleportNumber()
            for v in tc.simulation.getDepartedIDList():
                if v.startswith("_"):
                    continue
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
                    if not v.startswith("_"):
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
            if self.ctrl.startswith("Block") and (self.bo["reroute"] or self.bo["alert"]):
                for ln in self.in_lanes:
                    ids = set(tc.lane.getLastStepVehicleIDs(ln))
                    left = len(prev_ids[ln] - ids)
                    prev_ids[ln] = ids
                    self.orate[ln] += 0.02 * (0.4 * left - self.orate[ln])
                    if left:
                        for jj, ks in self.lane_j.get(ln, ()):
                            if jj.mode == "G" and ks == jj.cur:
                                jj.last_move = t
            if self.ctrl.startswith("Block") and self.bo["reroute"] and t % 60 == 30 and t > 300:
                self.reroute(t, closed)
            if self.ctrl.startswith("Block"):
                self.relay()
            if self.ctrl.startswith("Block") and self.bo["area"]:
                self.area_update(t)
            for j in juncs.values():
                if j.off:
                    continue
                if self.ctrl.startswith("Block") and self.bo["lowoff"] and not self.em and self.low_traffic(j, t):
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
        m = self.metrics(trip_out, teleports)
        m.update(police_alerts=len(self.alerts), alert_log=self.alerts[:20], reroutes=self.n_reroute,
                 signal_off_s=int(self.low_off_s))
        if self.est is not None and self.bo["est"]:
            e, c = self.est.rmse()
            m.update(est_rmse=e, cam_rmse=c, rejected=int(self.est.n_rej))
        return m

    def metrics(self, trip_out, teleports):
        tl, waits, arrived, n = [], [], 0, 0
        seen = set()
        for _, el in ET.iterparse(trip_out):
            if el.tag != "tripinfo" or el.get("id", "").startswith("_"):
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
    try:
        r = Runner(d, ctrl, ev, seed, routes, tg).run()
    except Exception:                                   # SWIG exceptions do not pickle
        import traceback
        raise RuntimeError(f"{ctrl} | {ev} | {seed}\n" + traceback.format_exc()) from None
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
    plots(table, events, ctrls, out, a.scale)


def plots(table, events, ctrls, out, scale):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    cols = {"Fixed-40": "#999999", "Actuated": "#22aa77", "MaxPressure": "#ee6633", "SITRA-MPC": "#7a3fa0",
            "SCOOT-like": "#6655dd", "SCATS-like": "#e57aa0", "Block-Tetris v7-final": "#555555",
            "Block-Tetris v8": "#111111"}
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
    fig.savefig(os.path.join(out, f"sumo1_delay_by_event_x{scale:g}.png"), dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    main()
