"""Closing the statistical plot holes.

1. SITRA bench: Block-Tetris vs Actuated (best existing) on 30 paired seeds
   per stochastic scenario, Wilcoxon signed-rank test + bootstrap 95 % CI.
2. Grid, held-out: seeds 11-20 (tuning used 1-2) and a demand pattern never
   used in tuning (N-S x1.4, E-W x0.7, peak bump); Fixed, MaxPressure, v3, v4, v6.

    python -m blocktetris.validation --out Results/BlockTetris/validation
"""
import argparse
import json
import math
import os
from multiprocessing import Pool

import numpy as np
from scipy.stats import wilcoxon

from .outputs import keep
from . import sitra_bench as B
from .circuit import Net, CircuitSim, Incident, V3_OPTS, V4_OPTS, V6_OPTS


def boot_ci(d, n=4000, seed=0):
    r = np.random.default_rng(seed)
    m = [np.mean(r.choice(d, len(d))) for _ in range(n)]
    return float(np.percentile(m, 2.5)), float(np.percentile(m, 97.5))


def _sitra(args):
    sid, seed = args
    s = [x for x in B.scenarios() if x["id"] == sid][0]
    t, rate, count = B.make_arrivals(s["f"], s["T"], s["stoch"], seed)
    rate, count = B.apply_demand(t, rate, count, s["events"])
    out = {}
    for c in ("Actuated", "BlockTetris"):
        out[c] = B.metrics(B.simulate(c, t, rate, count, s["q0"], s["events"]))["avgDelay"]
    return sid, seed, out


GRID = {"Fixed-40": ("fixed", None), "MaxPressure": ("maxp", None), "v3": ("bt", V3_OPTS),
        "v4": ("bt", V4_OPTS), "v6 (60 m CCTV)": ("bt", V6_OPTS)}


def _grid(args):
    name, case, seed = args
    ctrl, o = GRID[name]
    net = Net(4, 4)
    inc = {"none": None, "road closed": Incident("line_block", int(net.inner[17])),
           "camera dead": Incident("cam_fail", (5, 6), t0=1200, t1=2400)}[case]
    o = dict(o or {}, heldout_pattern=True)
    r = CircuitSim(net, ctrl, seed=seed, demand=0.13, opts=o, incident=inc).run()
    return name, case, seed, float(r["delay_s"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Results/BlockTetris/validation")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    res = {}
    sids = [x["id"] for x in B.scenarios() if x["stoch"]]
    with Pool() as p:
        rows = p.map(_sitra, [(s, k) for s in sids for k in range(101, 131)])
    print("SITRA bench, Block-Tetris vs Actuated, 30 paired seeds (avg delay s/veh)")
    for s in sids:
        act = np.array([r[2]["Actuated"] for r in rows if r[0] == s])
        bt = np.array([r[2]["BlockTetris"] for r in rows if r[0] == s])
        d = bt - act
        p = float(wilcoxon(bt, act).pvalue) if np.any(d != 0) else 1.0
        lo, hi = boot_ci(d)
        res[f"sitra|{s}"] = dict(actuated=float(act.mean()), blocktetris=float(bt.mean()),
                                 diff=float(d.mean()), ci95=[lo, hi], p=p, wins=int((d < 0).sum()), n=len(d))
        print(f"  {s:4s} Act {act.mean():6.1f}  BT {bt.mean():6.1f}  diff {d.mean():+6.1f} [{lo:+.1f},{hi:+.1f}]  "
              f"p={p:.2g}  BT better in {(d < 0).sum()}/30")
    jobs = [(nm, c, k) for nm in GRID for c in ("none", "road closed", "camera dead") for k in range(11, 21)]
    with Pool() as p:
        g = p.map(_grid, jobs)
    print("\nGrid 4x4, HELD-OUT seeds 11-20 and held-out demand pattern (delay s)")
    for c in ("none", "road closed", "camera dead"):
        vals = {nm: np.array([x[3] for x in g if x[0] == nm and x[1] == c]) for nm in GRID}
        line = "  ".join(f"{nm} {v.mean():6.1f}" for nm, v in vals.items())
        print(f"  {c:12s} {line}")
        for base in ("Fixed-40", "MaxPressure", "v3"):
            for new in ("v4", "v6 (60 m CCTV)"):
                d = vals[new] - vals[base]
                p = float(wilcoxon(vals[new], vals[base]).pvalue) if np.any(d != 0) else 1.0
                res[f"grid|{c}|{new} vs {base}"] = dict(diff=float(d.mean()), ci95=list(boot_ci(d)), p=p,
                                                        wins=int((d < 0).sum()), n=len(d))
        res[f"grid|{c}|means"] = {nm: float(v.mean()) for nm, v in vals.items()}
    for k, v in res.items():
        if k.startswith("grid|") and "vs" in k:
            print(f"  {k[5:]:40s} diff {v['diff']:+7.1f} [{v['ci95'][0]:+.1f},{v['ci95'][1]:+.1f}] p={v['p']:.2g} "
                  f"better in {v['wins']}/{v['n']}")
    json.dump(res, open(keep(os.path.join(a.out, "results.json")), "w"), indent=1)


if __name__ == "__main__":
    main()
