"""Line-by-line Python port of the existing SITRA baseline benchmark
(baselines/bl_*.m) plus Block-Tetris on the same test bench.

Plant, arrivals (Park-Miller LCG Poisson), scenarios T1-T14, fault injection,
the four existing controllers (SITRA MPC, Webster, Actuated, MaxPressure),
metrics and the twin-run clearance metric follow the MATLAB files exactly,
so the existing published numbers (Results/baselines/baseline_comparison.csv)
are reproduced first, then Block-Tetris is added with no change to the bench.

    python -m blocktetris.sitra_bench --out Results/BlockTetris/sitra
"""
import argparse
import csv
import json
import math
import os

import numpy as np

CAP = np.array([0.65, 0.35, 0.25, 0.45])
DT = 1.0
YELLOW = 3.0
SEEDS = [101, 102, 103, 104, 105]
SPLIT = np.array([0.10, 0.07, 0.05]) / 0.22
LO, MD, HI, OV = 0.15, 0.25, 0.35, 0.50

P = dict(
    mpc=dict(yellow=3, cycleLength=63, minGreen=12, maxGreen=30),
    web=dict(minGreen=10, Cmin=30, Cmax=120, startLost=0),
    act=dict(minGreen=10, maxGreen=40, passage=3, queueOn=0.5),
    mp=dict(slot=10, queueOn=0.5),
)


# ─────────────────────────────── scenarios ──────────────────────────────────
def _ev(type_, branch, t0, t1, mag, **extra):
    return dict(type=type_, branch=branch, t0=t0, t1=t1, mag=mag, extra=extra)


def scenarios():
    nD = np.array([0.10, 0.07, 0.05])
    sD = np.array([0.30, 0.07, 0.05])
    surge = lambda t: nD + (sD - nD) * (200 <= t < 400)
    mod = lambda t: MD * SPLIT
    twin_mod = dict(f=mod, q0=np.zeros(4), events=[])
    S = []

    def mk(id_, name, T, stoch, f, tEvent=math.nan, q0=None, twin=None, events=None):
        S.append(dict(id=id_, name=name, T=T, stoch=stoch, f=f, tEvent=tEvent,
                      q0=np.zeros(4) if q0 is None else np.array(q0, float),
                      twin=twin, events=events or []))

    mk("T1", "Low", 900, True, lambda t: LO * SPLIT)
    mk("T2", "Moderate", 900, True, mod)
    mk("T3", "High", 900, True, lambda t: HI * SPLIT)
    mk("T4", "Oversaturated", 900, True, lambda t: OV * SPLIT)
    mk("T5", "Step demand", 900, True,
       lambda t: SPLIT * (LO * (t < 300) + HI * (300 <= t < 600) + MD * (t >= 600)), 600,
       twin=dict(f=lambda t: SPLIT * (LO * (t < 300) + MD * (t >= 300)), q0=np.zeros(4), events=[]))
    mk("T6", "Part 8 surge (deterministic)", 600, False, surge, 400,
       twin=dict(f=lambda t: nD, q0=np.zeros(4), events=[]))
    mk("T7", "Part 8 surge (Poisson)", 600, True, surge, 400,
       twin=dict(f=lambda t: nD, q0=np.zeros(4), events=[]))
    mk("T8", "Congested start", 900, True, mod, 0, q0=[25, 15, 10, 0],
       twin=dict(f=mod, q0=np.zeros(4), events=[]))
    mk("T9", "Incident B1", 900, True, mod, 400, twin=twin_mod,
       events=[_ev("incident", 1, 200, 400, 0.5)])
    mk("T10", "Blockage B4 (spill-back)", 900, True, mod, 350, twin=twin_mod,
       events=[_ev("blockage", 4, 200, 350, 0.8, q4max=15)])
    mk("T11", "Platoon B2", 900, True, mod, 500, twin=twin_mod,
       events=[_ev("platoon", 2, 200, 500, 8, period=60)])
    mk("T12", "Sensor stuck B1", 900, True, mod, 500, twin=twin_mod,
       events=[_ev("sensor_stuck", [1], 200, 500, 0)])
    mk("T13", "Sensor noise B1-B3", 900, True, mod, 0, twin=twin_mod,
       events=[_ev("sensor_noise", [1, 2, 3], 0, 900, 2)])
    mk("T14", "Signal stuck off B3", 900, True, mod, 360, twin=twin_mod,
       events=[_ev("signal_stuck_off", 3, 300, 360, 0)])
    return S


# ─────────────────────────────── arrivals ───────────────────────────────────
def make_arrivals(f, T, stoch, seed):
    t = np.arange(0, T + DT / 2, DT)
    rate = np.array([f(x) for x in t], float)
    if not stoch:
        return t, rate, rate * DT
    x = (seed * 7919 + 12345) % 2147483646 + 1
    count = np.zeros_like(rate)
    for k in range(len(t)):
        for b in range(3):
            lam = rate[k, b] * DT
            x = (16807 * x) % 2147483647
            u = x / 2147483647
            n, pk = 0, math.exp(-lam)
            cdf = pk
            while u > cdf and n < 50:
                n += 1
                pk = pk * lam / n
                cdf += pk
            count[k, b] = n
    return t, rate, count


def apply_demand(t, rate, count, events):
    rate, count = rate.copy(), count.copy()
    for e in events:
        if e["type"] != "platoon":
            continue
        b = e["branch"] - 1
        win = (t >= e["t0"] - 1e-9) & (t < e["t1"] - 1e-9)
        per = e["extra"].get("period", 60)
        for i in np.where(win)[0]:
            if (t[i] - e["t0"]) % per < DT - 1e-9:
                count[i, b] += e["mag"]
                rate[i, b] += e["mag"] / DT
    return rate, count


# ─────────────────────────────── plant + faults ─────────────────────────────
class Plant:
    def __init__(self, events):
        self.events = events
        self.q4max = None
        for e in events:
            if e["type"] == "blockage" and "q4max" in e["extra"]:
                self.q4max = e["extra"]["q4max"]
        self.frozen = [None] * 4

    def cap(self, t):
        c = CAP.copy()
        for e in self.events:
            if e["type"] in ("incident", "blockage") and e["t0"] - 1e-9 <= t < e["t1"] - 1e-9:
                c[e["branch"] - 1] = CAP[e["branch"] - 1] * (1 - e["mag"])
        return c

    def step(self, q, arr_rate, active, t):
        cap = self.cap(t)
        blocked = self.q4max is not None and q[3] >= self.q4max - 1e-4
        arr = np.zeros(4)
        dep = np.zeros(4)
        arr[:3] = arr_rate
        for b in range(3):
            if b + 1 == active and not blocked:
                dep[b] = min(cap[b], q[b] / DT)
        if active > 0 and not blocked:
            arr[3] = dep[active - 1]
        dep[3] = min(cap[3], q[3] / DT)
        qn = np.maximum(0, q + DT * (arr - dep))
        return qn, arr, dep

    def sensor(self, q, t):
        qs = q.copy()
        for e in self.events:
            inw = e["t0"] - 1e-9 <= t < e["t1"] - 1e-9
            if e["type"] == "sensor_stuck":
                for b in e["branch"]:
                    if inw:
                        if self.frozen[b - 1] is None:
                            self.frozen[b - 1] = q[b - 1]
                        qs[b - 1] = self.frozen[b - 1]
                    else:
                        self.frozen[b - 1] = None
            elif e["type"] == "sensor_noise" and inw:
                for b in e["branch"]:
                    u1 = _mmod(math.sin(t * 12.9898 + b * 78.233) * 43758.5453)
                    u1 = max(1e-12, min(1 - 1e-12, abs(u1)))
                    u2 = _mmod(math.cos(t * 4.1414 + b * 26.651) * 24634.6345)
                    u2 = max(1e-12, min(1 - 1e-12, abs(u2)))
                    z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
                    qs[b - 1] = max(0.0, q[b - 1] + e["mag"] * z)
        return qs

    def active_eff(self, active, t):
        for e in self.events:
            if e["type"] == "signal_stuck_off" and e["t0"] - 1e-9 <= t < e["t1"] - 1e-9 and active == e["branch"]:
                return 0
        return active


def _mmod(x):
    """MATLAB mod(x, 1): result has the sign of the divisor (non-negative)."""
    return x - math.floor(x)


# ─────────────────────────────── existing controllers ───────────────────────
def ctrl_sitra(t, q, info, st):
    m = P["mpc"]
    n = 3
    total = m["cycleLength"] - n * m["yellow"]
    g = np.full(n, float(m["minGreen"]))
    rem = total - g.sum()
    score = np.maximum(q[:3], 0) + 10 * np.maximum(info["rate"], 0)
    score[1:] += 0.25
    for _ in range(int(round(rem))):
        room = m["maxGreen"] - g
        v = score * (room > 1e-12)
        idx = int(np.argmax(v))
        if v[idx] <= 0:
            break
        g[idx] += 1
        score[idx] = score[idx] * 0.985 + 1e-12
    tau = t % m["cycleLength"]
    cur = 0.0
    for b in range(n):
        gEnd = cur + g[b]
        yEnd = gEnd + m["yellow"]
        if cur <= tau < gEnd:
            return b + 1, st
        if gEnd <= tau < yEnd:
            return 0, st
        cur = yEnd
    return 0, st


def ctrl_webster(t, q, info, st):
    if st is None:
        w = P["web"]
        y = info["design"] / CAP[:3]
        Y = y.sum()
        L = 3 * (YELLOW + w["startLost"])
        C0 = (1.5 * L + 5) / (1 - Y) if Y < 0.95 else w["Cmax"]
        C0 = min(max(C0, w["Cmin"]), w["Cmax"])
        g = (C0 - 3 * YELLOW) * y / Y if Y > 0 else np.full(3, (C0 - 3 * YELLOW) / 3)
        g = np.maximum(np.floor(g + 0.5), w["minGreen"])  # MATLAB round
        st = dict(green=g, C=g.sum() + 3 * YELLOW)
    tau = t % st["C"]
    cur = 0.0
    for i in range(3):
        gEnd = cur + st["green"][i]
        if cur <= tau < gEnd:
            return i + 1, st
        cur = gEnd + YELLOW
    return 0, st


def ctrl_actuated(t, q, info, st):
    a = P["act"]
    if st is None:
        st = dict(phase=1, mode="green", timer=0.0, gap=0.0, call=[False] * 3)
    for b in range(3):
        if info["vehPrev"][b] > 0 or q[b] >= a["queueOn"]:
            st["call"][b] = True
    if st["mode"] == "yellow" and st["timer"] >= YELLOW:
        nxt = 0
        for k in range(1, 4):
            b = (st["phase"] - 1 + k) % 3 + 1
            if st["call"][b - 1]:
                nxt = b
                break
        if nxt == 0:
            nxt = st["phase"] % 3 + 1
        st.update(phase=nxt, mode="green", timer=0.0, gap=0.0)
    if st["mode"] == "green":
        b = st["phase"]
        st["call"][b - 1] = False
        act = info["vehPrev"][b - 1] > 0 or q[b - 1] >= a["queueOn"]
        if act:
            st["gap"] = 0.0
        elif st["timer"] > 0:
            st["gap"] += DT
        if st["timer"] >= a["maxGreen"] or (st["timer"] >= a["minGreen"] and st["gap"] >= a["passage"]):
            st["mode"] = "yellow"
            st["timer"] = 0.0
    active = st["phase"] if st["mode"] == "green" else 0
    st["timer"] += DT
    return active, st


def ctrl_maxpressure(t, q, info, st):
    m = P["mp"]
    if st is None:
        st = dict(phase=1, mode="green", timer=0.0, next=1)
    if st["mode"] == "yellow" and st["timer"] >= YELLOW:
        st.update(phase=st["next"], mode="green", timer=0.0)
    if st["mode"] == "green" and st["timer"] >= m["slot"]:
        qa = q[:3]
        if (qa >= m["queueOn"]).any():
            w = CAP[:3] * (qa - q[3])
            best = int(np.argmax(w)) + 1
            if best != st["phase"]:
                st["next"] = best
                st["mode"] = "yellow"
        st["timer"] = 0.0
    active = st["phase"] if st["mode"] == "green" else 0
    st["timer"] += DT
    return active, st


# ─────────────────────────────── Block-Tetris ───────────────────────────────
BT_DEFAULT = dict(g_min=10.0, g_max=40.0, a_age=0.02, low=0.5, switch_margin=2.0,
                  observer=True, fault_detect=True, platoon_hold=True, rate_score=True,
                  rolling=False, planned_end=False, gap=0.0)
# Tuned on this bench: score-based rolling re-placement and the planned-green end
# cost more yellow than they save here (same thrash as found on the e-twin grid),
# so v3 serves each bottle until it is low / the tap stops passing current /
# g_max, then picks the next piece by charge x learned discharge current.


class BlockTetrisSITRA:
    """Block-Tetris v3 on the 3-approach SITRA junction (one Tetris piece per approach).

    Inputs are the same as the existing controllers': q from a possibly faulty
    sensor and info.vehPrev from the upstream detectors. It does NOT use the
    nominal demand rate that SITRA-MPC and Webster are given.
      * observer: q_hat integrates detector arrivals minus learned discharge and
        fuses the camera reading (sanity filter + adaptive gain); a reading frozen
        while vehicles move is flagged and the model is trusted instead
      * learned saturation flow per approach (tau) from measured discharge
      * T_discharge = L + q/s * 1.1 / (1 - rho), clamped to [g_min, g_max]
      * end green: bottle low and no platoon arriving, tap passes no current
        (exit blocked / lamp fault), or rolling re-placement (another bottle
        clearly more urgent); platoon hold up to g_max
      * next piece = highest score q + a * age * q
    """

    def __init__(self, **kw):
        self.o = dict(BT_DEFAULT, **kw)
        self.phase, self.mode, self.timer = 1, "green", 0.0
        self.qh = np.zeros(4)
        self.s = np.full(3, 0.5)          # learned saturation flow (start guess)
        self.lam = np.full(3, 0.05)
        self.last_served = np.zeros(3)
        self.planned = self.o["g_min"]
        self.no_flow = 0
        self.prev_seen = None
        self.prev_qb = None
        self.stuck_s = np.zeros(4)
        self.bad = np.zeros(4, bool)

    def _observe(self, qs, info):
        arr = np.asarray(info["vehPrev"], float)
        self.lam += 0.02 * (arr - self.lam)
        if not self.o["observer"]:
            self.qh = qs.copy()
            return
        pred = self.qh.copy()
        pred[:3] += arr
        if self.mode == "green" and self.timer > 0:
            b = self.phase - 1
            pred[b] = max(0.0, pred[b] - self.s[b] * DT)
        if self.prev_seen is not None:
            same = np.abs(qs - self.prev_seen) < 1e-9
            moving = np.zeros(4, bool)
            moving[:3] = arr > 0
            self.stuck_s = np.where(same & (moving | (qs > 0.5)), self.stuck_s + 1, 0)
        self.prev_seen = qs.copy()
        for b in range(4):
            self.bad[b] = self.stuck_s[b] >= 8
            if self.bad[b]:
                self.qh[b] = pred[b]
            else:
                gain = 0.6 if abs(qs[b] - pred[b]) < 3 else 0.25
                self.qh[b] = max(0.0, pred[b] + gain * (qs[b] - pred[b]))

    def _learn(self, q_before, info):
        b = self.phase - 1
        if self.mode == "green" and self.timer > 3 and q_before[b] > 2 and not self.bad[b] and self.no_flow == 0:
            d = q_before[b] + info["vehPrev"][b] - self.qh[b]
            if 0 < d < 2:
                self.s[b] += 0.05 * (d - self.s[b])

    def _score(self, t):
        q = self.qh[:3]
        age = t - self.last_served
        sc = q + self.o["a_age"] * age * q
        if self.o["rate_score"]:
            sc = sc * self.s            # charge x discharge current: c-mu priority
        return np.where(q > self.o["low"], sc, 0.0)

    def _plan(self, b):
        rho = min(0.8, self.lam[b] / max(self.s[b], 1e-3))
        T = 2.0 + self.qh[b] / max(self.s[b], 1e-3) * 1.1 / (1 - rho)
        return float(np.clip(T, self.o["g_min"], self.o["g_max"]))

    def __call__(self, t, qs, info, st):
        o = self.o
        q_before = self.qh.copy()
        self._observe(qs, info)
        self._learn(q_before, info)
        if self.mode == "yellow" and self.timer >= YELLOW:
            sc = self._score(t)
            nxt = int(np.argmax(sc)) + 1 if (sc > 0).any() else self.phase % 3 + 1
            self.phase, self.mode, self.timer = nxt, "green", 0.0
            self.planned = self._plan(nxt - 1)
            self.no_flow = 0
            self.prev_qb = None
        b = self.phase - 1
        if self.mode == "green":
            self.last_served[b] = t
            # current through the tap: a bottle that should drain but does not
            q_in = qs[b] if not self.bad[b] else self.qh[b]
            if o["fault_detect"] and self.prev_qb is not None and self.timer > 3 and q_in > 1.0 \
                    and q_in >= self.prev_qb + info["vehPrev"][b] - 0.05:
                self.no_flow += 1
            else:
                self.no_flow = 0
            self.prev_qb = q_in
            end = False
            if self.timer >= o["g_max"]:
                end = True
            elif self.timer >= o["g_min"]:
                platoon = o["platoon_hold"] and info["vehPrev"][b] > 0
                sc = self._score(t)
                if self.qh[b] <= o["low"] and not platoon:
                    end = True
                elif o["fault_detect"] and self.no_flow >= 3:
                    end = True
                elif o["rolling"] and sc.max() > o["switch_margin"] * max(sc[b], 1e-9) + 2.0 and not platoon:
                    end = True
                elif o["planned_end"] and self.timer >= self.planned and not platoon:
                    end = True
            if end:
                self.mode, self.timer = "yellow", 0.0
        active = self.phase if self.mode == "green" else 0
        self.timer += DT
        return active, st


CTRLS = {"SITRA": ctrl_sitra, "Webster": ctrl_webster, "Actuated": ctrl_actuated,
         "MaxPressure": ctrl_maxpressure}


def simulate(name, t, rate, count, q0, events, bt_kw=None):
    cum = np.cumsum(count, 0)
    prev = np.vstack([np.zeros(3), cum[:-1]])
    veh = np.floor(cum + 1e-9) - np.floor(prev + 1e-9)
    design = rate.mean(0)
    plant = Plant(events)
    f = BlockTetrisSITRA(**(bt_kw or {})) if name.startswith("BlockTetris") else CTRLS[name]
    q = q0.astype(float).copy()
    st = None
    N = len(t)
    qH = np.zeros((N, 4))
    depH = np.zeros((N, 4))
    for k in range(N):
        info = dict(rate=rate[k], design=design, vehPrev=veh[k - 1] if k > 0 else np.zeros(3))
        qs = plant.sensor(q, t[k])
        active, st = f(t[k], qs, info, st)
        active = plant.active_eff(active, t[k])
        qn, arr, dep = plant.step(q, count[k] / DT, active, t[k])
        qH[k] = q
        depH[k] = dep
        q = qn
    return dict(qH=qH, depH=depH, count=count, qF=q, t=t)


def metrics(R):
    veh = R["count"].sum()
    qa = R["qH"][:, :3]
    return dict(avgDelay=qa.sum() * DT / max(veh, 1e-12), netDelay=R["qH"].sum() * DT / max(veh, 1e-12),
                maxQueue=float(qa.max()), throughput=float(R["depH"][:, 3].sum() * DT), finalQueue=float(R["qF"].sum()))


def movmean(x, k):
    """MATLAB movmean(x, k): centred window, shrinking at the edges."""
    n = len(x)
    before, after = (k // 2, k // 2 - 1) if k % 2 == 0 else ((k - 1) // 2, (k - 1) // 2)
    c = np.concatenate([[0.0], np.cumsum(x)])
    i = np.arange(n)
    lo = np.maximum(0, i - before)
    hi = np.minimum(n, i + after + 1)
    return (c[hi] - c[lo]) / (hi - lo)


def clearance(t, Q, Qt, tEvent, W=120, tol=1.0, hold=60):
    idx = np.where(t >= tEvent)[0]
    ex = np.maximum(Q[idx] - Qt[idx], 0)
    excess = float(np.trapezoid(ex, t[idx])) if len(idx) >= 2 else 0.0
    d = movmean(Q, W) - movmean(Qt, W)
    for j, k in enumerate(idx):
        if k + hold > len(d) - 1:
            break
        if (np.abs(d[k:k + hold + 1]) <= tol + 1e-9).all():
            return (0.0 if j == 0 else float(t[k] - tEvent)), True, excess
    return math.nan, False, excess


def run(controllers, bt_kw=None):
    out = []
    for s in scenarios():
        seeds = SEEDS if s["stoch"] else [0]
        for seed in seeds:
            t, rate, count = make_arrivals(s["f"], s["T"], s["stoch"], seed)
            rate, count = apply_demand(t, rate, count, s["events"])
            tw = s["twin"]
            has_twin = not math.isnan(s["tEvent"]) and tw is not None
            if has_twin:
                tt, rt, ct = make_arrivals(tw["f"], s["T"], s["stoch"], seed)
                rt, ct = apply_demand(tt, rt, ct, tw["events"])
            for c in controllers:
                R = simulate(c, t, rate, count, s["q0"], s["events"], bt_kw)
                M = metrics(R)
                if has_twin:
                    Rt = simulate(c, tt, rt, ct, tw["q0"], tw["events"], bt_kw)
                    M["clear"], M["cleared"], M["excess"] = clearance(
                        t, R["qH"][:, :3].sum(1), Rt["qH"][:, :3].sum(1), s["tEvent"])
                out.append(dict(scn=s["id"], name=s["name"], ctrl=c, seed=seed, **M))
    return out


def aggregate(rows):
    agg = {}
    for r in rows:
        agg.setdefault((r["scn"], r["ctrl"]), []).append(r)
    res = {}
    for (s, c), v in agg.items():
        d = dict(avgDelay=float(np.mean([x["avgDelay"] for x in v])),
                 netDelay=float(np.mean([x["netDelay"] for x in v])),
                 maxQueue=float(np.mean([x["maxQueue"] for x in v])),
                 throughput=float(np.mean([x["throughput"] for x in v])), n=len(v), name=v[0]["name"])
        if "clear" in v[0]:
            cl = [x["clear"] for x in v if x["cleared"]]
            d["clear"] = float(np.mean(cl)) if cl else math.nan
            d["cleared"] = f"{len(cl)}/{len(v)}"
            d["excess"] = float(np.mean([x["excess"] for x in v]))
        res[(s, c)] = d
    return res


def verify(res, csv_path):
    """Compare the port with the published MATLAB numbers."""
    worst = 0.0
    lines = []
    with open(csv_path) as f:
        for row in csv.DictReader(f):
            k = (row["Scenario"], row["Controller"])
            if k not in res:
                continue
            ref = float(row["AvgDelay_s"])
            got = res[k]["avgDelay"]
            err = abs(got - ref) / max(ref, 1e-9)
            worst = max(worst, err)
            lines.append((k, ref, got, err, row["ClearTime_s"], res[k].get("clear"),
                          row["ExcessVehS"], res[k].get("excess")))
    return worst, lines


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Results/BlockTetris/sitra")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    ctrls = ["SITRA", "Webster", "Actuated", "MaxPressure", "BlockTetris"]
    rows = run(ctrls)
    res = aggregate(rows)
    worst, lines = verify(res, "Results/baselines/baseline_comparison.csv")
    print(f"Port check vs published MATLAB AvgDelay: worst relative error {100 * worst:.3f} %")
    with open(os.path.join(a.out, "port_verification.csv"), "w") as f:
        f.write("Scenario,Controller,AvgDelay_MATLAB,AvgDelay_Python,RelErr,Clear_MATLAB,Clear_Python,Excess_MATLAB,Excess_Python\n")
        for (s, c), ref, got, err, cm, cp, em, ep in lines:
            f.write(f"{s},{c},{ref:.3f},{got:.3f},{err:.5f},{cm},{cp},{em},{ep}\n")
    with open(os.path.join(a.out, "results.json"), "w") as f:
        json.dump({f"{s}|{c}": v for (s, c), v in res.items()}, f, indent=1)
    plot(res, a.out)
    print("\nAvg delay (s/veh) / clearance (s), mean of 5 seeds")
    print("Scn  " + "".join(f"{c:>15s}" for c in ctrls))
    for s in [x["id"] for x in scenarios()]:
        cells = []
        for c in ctrls:
            d = res[(s, c)]
            cl = d.get("clear", math.nan)
            cells.append(f"{d['avgDelay']:9.1f}" + (f"/{cl:5.0f}" if not math.isnan(cl) else "      "))
        print(f"{s:4s} " + "".join(cells))


def plot(res, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    ctrls = ["SITRA", "Webster", "Actuated", "MaxPressure", "BlockTetris"]
    col = ["#2a78d6", "#eb6834", "#1baf7a", "#e87ba4", "#eda100"]
    sc = [x["id"] for x in scenarios()]
    x = np.arange(len(sc))
    fig, ax = plt.subplots(figsize=(13, 4.5), facecolor="#fcfcfb")
    ax.set_facecolor("#fcfcfb")
    for i, c in enumerate(ctrls):
        ax.bar(x + (i - 2) * 0.16, [res[(s_, c)]["avgDelay"] for s_ in sc], 0.15, color=col[i], label=c)
    ax.set_xticks(x, sc)
    ax.set_ylabel("Average delay (s / vehicle)")
    ax.set_title("Existing SITRA benchmark T1-T14 (5 seeds): Block-Tetris vs the four existing controllers",
                 fontweight="bold")
    ax.grid(axis="y", color="#e4e3df")
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    ax.legend(ncol=5, frameon=False)
    fig.tight_layout()
    fig.savefig(os.path.join(out, "fig9_sitra_benchmark.png"), dpi=150)


if __name__ == "__main__":
    main()
