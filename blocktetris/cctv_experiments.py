"""v6 study: realistic inputs (60 m CCTV view, Google Maps travel times).

    python -m blocktetris.cctv_experiments --out Results/BlockTetris/cctv
"""
import argparse
import json
import os
from multiprocessing import Pool

import numpy as np

from .outputs import keep
from .circuit import Net, CircuitSim, Incident, V5_OPTS, V6_OPTS

VARIANTS = {
    "v5 ideal cameras (whole queue seen)": V5_OPTS,
    "v5 with real 60 m CCTV": dict(V5_OPTS, cctv_view_m=60.0),
    "v6 CCTV + estimator, no Google": dict(V6_OPTS, gmaps=False),
    "v6 CCTV + estimator + Google flag": V6_OPTS,
    "v6 with Google as quantity (rejected)": dict(V6_OPTS, gmaps_queue=True),
}
LOADS = (0.13, 0.16)


def cases(net):
    c = [("none", None)]
    c += [("block", Incident("line_block", int(l))) for l in net.inner[::4]]
    c += [("exit", Incident("sink_cut", int(l))) for l in net.sinks[::4]]
    c += [("camera", Incident("cam_fail", (5, 6), t0=1200, t1=2400))]
    return c


def _job(a):
    v, d, kind, inc, seed = a
    r = CircuitSim(Net(4, 4), "bt", seed=seed, demand=d, incident=inc, opts=VARIANTS[v]).run()
    return dict(v=v, d=d, kind=kind, delay=float(r["delay_s"]), served=float(r["served"] / r["arrived"]),
                rmse=float(r["est_rmse"]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Results/BlockTetris/cctv")
    ap.add_argument("--seeds", type=int, default=2)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    net = Net(4, 4)
    jobs = [(v, d, k, inc, s) for v in VARIANTS for d in LOADS for k, inc in cases(net) for s in range(1, a.seeds + 1)]
    with Pool() as p:
        res = p.map(_job, jobs, chunksize=2)
    out = {}
    for d in LOADS:
        print(f"\nload {d / 0.069:.1f}x normal")
        for v in VARIANTS:
            rs = [r for r in res if r["v"] == v and r["d"] == d]
            row = {k: float(np.mean([r["delay"] for r in rs if r["kind"] == k])) for k in ("none", "block", "exit", "camera")}
            row["all"] = float(np.mean([r["delay"] for r in rs]))
            row["served"] = float(np.mean([r["served"] for r in rs]))
            row["rmse"] = float(np.mean([r["rmse"] for r in rs]))
            out[f"{v}|{d}"] = row
            print(f"  {v:40s} delay {row['all']:6.1f}s (none {row['none']:5.0f} block {row['block']:5.0f} "
                  f"exit {row['exit']:5.0f} camera-fail {row['camera']:5.0f}) served {100 * row['served']:4.1f}% "
                  f"road err {row['rmse']:.2f}W")
    json.dump(out, open(keep(os.path.join(a.out, "results.json")), "w"), indent=1)


if __name__ == "__main__":
    main()
