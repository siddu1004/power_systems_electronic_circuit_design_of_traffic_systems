"""Camera failures on the 4x4 e-twin: what a blind junction does.

  fixed      junction drops to a 40 s fixed cycle (classic fallback)
  frozen     junction keeps using its last camera frame
  neighbour  junction's stacks are rebuilt from neighbour camera messages
             (upstream send counts in, downstream landing counts correcting)
  hybrid     neighbour rebuild; fixed rotation only while the network is saturated

    python -m blocktetris.blind_experiments --out Results/BlockTetris/blind
"""
import argparse
import json
import os
from multiprocessing import Pool

import numpy as np

from .outputs import keep

from .circuit import Net, CircuitSim, Incident, V4_OPTS

MODES = ("fixed", "frozen", "neighbour", "hybrid")
LOADS = (0.13, 0.16)


def failure_sets(net):
    pos = {p: j for j, p in enumerate(net.pos)}
    singles = [(j,) for j in range(net.J)]
    pairs = [(pos[(1, 1)], pos[(1, 2)]), (pos[(2, 1)], pos[(2, 2)]), (pos[(1, 1)], pos[(2, 1)])]
    core = [tuple(pos[p] for p in [(1, 1), (1, 2), (2, 1), (2, 2)])]
    return [("1 junction", s) for s in singles] + [("2 adjacent", p) for p in pairs] + [("4 central", c) for c in core]


def _job(a):
    mode, d, kind, tgt, seed = a
    o = dict(V4_OPTS, blind_mode=mode)
    inc = Incident("cam_fail", tgt, t0=1200, t1=2400) if tgt else None
    r = CircuitSim(Net(4, 4), "bt", seed=seed, demand=d, opts=o, incident=inc).run()
    return dict(mode=mode, d=d, kind=kind, seed=seed, delay=float(r["delay_s"]),
                served=float(r["served"] / r["arrived"]), rmse=float(r["blind_rmse"]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Results/BlockTetris/blind")
    ap.add_argument("--seeds", type=int, default=2)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    net = Net(4, 4)
    sets = [("no failure", None)] + failure_sets(net)
    jobs = [(m, d, k, t, s) for m in MODES for d in LOADS for k, t in sets for s in range(1, a.seeds + 1)]
    with Pool() as p:
        res = p.map(_job, jobs, chunksize=2)
    out = {}
    for d in LOADS:
        print(f"\nload {d / 0.069:.1f}x normal (cameras dead 20 min)")
        for k in ["no failure", "1 junction", "2 adjacent", "4 central"]:
            row = {}
            for m in MODES:
                rs = [r for r in res if r["d"] == d and r["kind"] == k and r["mode"] == m]
                row[m] = dict(delay=float(np.mean([r["delay"] for r in rs])),
                              served=float(np.mean([r["served"] for r in rs])),
                              rmse=float(np.mean([r["rmse"] for r in rs])))
            out[f"{d}|{k}"] = row
            print(f"  {k:11s} " + " | ".join(f"{m}: {row[m]['delay']:6.1f}s served {100 * row[m]['served']:4.1f}% "
                                             f"err {row[m]['rmse']:.2f}W" for m in MODES))
    json.dump(out, open(keep(os.path.join(a.out, "results.json")), "w"), indent=1)


if __name__ == "__main__":
    main()
