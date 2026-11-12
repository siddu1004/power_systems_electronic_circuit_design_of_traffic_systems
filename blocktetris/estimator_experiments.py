"""v4 study: state estimator + look-ahead inflow control on the 4x4 e-twin.

Sensors are degraded for every non-oracle variant: cameras on 50 % of roads,
sigma = 3 W noise, 2 cameras freeze at t = 600 s, phantom ghost queues, 5 % count error.

    python -m blocktetris.estimator_experiments --out Results/BlockTetris/estimator
"""
import argparse
import json
import os
from multiprocessing import Pool

import numpy as np

from .circuit import Net, CircuitSim, Incident, V3_OPTS, V4_OPTS

VARIANTS = {
    "v3 perfect sensors": V3_OPTS,
    "v3 raw faulty sensors": dict(V3_OPTS, estimator="raw"),
    "v3 + Kalman estimator": dict(V3_OPTS, estimator="kf"),
    "v4 (Kalman + 3-level look-ahead)": V4_OPTS,
}
LOADS = (0.13, 0.16, 0.20)


def cases(net):
    c = [("none", None)]
    c += [("block", Incident("line_block", int(l))) for l in net.inner[::3]]
    c += [("exit", Incident("sink_cut", int(l))) for l in net.sinks[::2]]
    c += [("surge", Incident("gate_surge", int(l))) for l in net.gates[::2]]
    return c


def _job(a):
    v, d, kind, inc, seed = a
    sim = CircuitSim(Net(4, 4), "bt", seed=seed, demand=d, incident=inc, opts=VARIANTS[v])
    r = sim.run()
    return dict(v=v, d=d, kind=kind, seed=seed, delay=float(r["delay_s"]),
                served=float(r["served"] / r["arrived"]), rmse=float(r["est_rmse"]), warn=r["warn"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Results/BlockTetris/estimator")
    ap.add_argument("--seeds", type=int, default=2)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    net = Net(4, 4)
    jobs = [(v, d, k, inc, s) for v in VARIANTS for d in LOADS for k, inc in cases(net)
            for s in range(1, a.seeds + 1)]
    with Pool() as p:
        res = p.map(_job, jobs, chunksize=2)
    out = {}
    for v in VARIANTS:
        for d in LOADS:
            rs = [r for r in res if r["v"] == v and r["d"] == d]
            row = {"delay_all": float(np.mean([r["delay"] for r in rs])),
                   "served_all": float(np.mean([r["served"] for r in rs])),
                   "rmse_W": float(np.mean([r["rmse"] for r in rs]))}
            for k in ("none", "block", "exit", "surge"):
                row[f"delay_{k}"] = float(np.mean([r["delay"] for r in rs if r["kind"] == k]))
            ws = [r["warn"] for r in rs if r["warn"]]
            if ws:
                row["warn_recall"] = float(np.nanmean([w["recall"] for w in ws]))
                row["warn_precision"] = float(np.nanmean([w["precision"] for w in ws]))
                row["warn_median_lead_s"] = float(np.mean([w["median_lead_s"] for w in ws if w["spills"]] or [0]))
                row["spills_per_run"] = float(np.mean([w["spills"] for w in ws]))
            out[f"{v}|{d}"] = row
    json.dump(out, open(os.path.join(a.out, "results.json"), "w"), indent=1)
    for d in LOADS:
        print(f"\nload {d / 0.069:.1f}x normal")
        for v in VARIANTS:
            r = out[f"{v}|{d}"]
            extra = (f" | warn recall {r['warn_recall']:.2f} precision {r['warn_precision']:.2f} "
                     f"lead {r['warn_median_lead_s']:.0f}s") if "warn_recall" in r else ""
            print(f"  {v:34s} delay {r['delay_all']:6.1f}s (none {r['delay_none']:5.0f} block {r['delay_block']:5.0f} "
                  f"exit {r['delay_exit']:5.0f} surge {r['delay_surge']:5.0f}) served {100 * r['served_all']:4.1f}% "
                  f"rmse {r['rmse_W']:.2f}W{extra}")


if __name__ == "__main__":
    main()
