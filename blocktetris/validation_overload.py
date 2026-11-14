"""Held-out check of the overload claims (seeds 11-20, held-out demand pattern):
v4 vs v3 at 2.3x and 2.9x, and v6 vs v5-with-60 m-CCTV at 2.3x.

    python -m blocktetris.validation_overload --out Results/BlockTetris/validation
"""
import argparse
import json
import os
from multiprocessing import Pool

import numpy as np
from scipy.stats import wilcoxon

from .outputs import keep
from .validation import boot_ci
from .circuit import Net, CircuitSim, Incident, V3_OPTS, V4_OPTS, V5_OPTS, V6_OPTS

V = {"v3": V3_OPTS, "v4": V4_OPTS, "v5 + 60 m CCTV": dict(V5_OPTS, cctv_view_m=60.0), "v6": V6_OPTS}
PAIRS = [("v4", "v3", (0.16, 0.20)), ("v6", "v5 + 60 m CCTV", (0.16,))]


def _job(a):
    v, d, case, seed = a
    net = Net(4, 4)
    inc = Incident("line_block", int(net.inner[17])) if case == "road closed" else None
    r = CircuitSim(net, "bt", seed=seed, demand=d, opts=dict(V[v], heldout_pattern=True), incident=inc).run()
    return v, d, case, seed, float(r["delay_s"])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Results/BlockTetris/validation")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    jobs = sorted({(v, d, c, s) for new, base, ds in PAIRS for v in (new, base) for d in ds
                   for c in ("none", "road closed") for s in range(11, 21)})
    with Pool() as p:
        rows = p.map(_job, jobs)
    res = {}
    for new, base, ds in PAIRS:
        for d in ds:
            for c in ("none", "road closed"):
                x = np.array([r[4] for r in sorted(rows) if r[0] == new and r[1] == d and r[2] == c])
                y = np.array([r[4] for r in sorted(rows) if r[0] == base and r[1] == d and r[2] == c])
                diff = x - y
                p = float(wilcoxon(x, y).pvalue) if np.any(diff != 0) else 1.0
                lo, hi = boot_ci(diff)
                k = f"{new} vs {base} | {d / 0.069:.1f}x | {c}"
                res[k] = dict(new=float(x.mean()), base=float(y.mean()), diff=float(diff.mean()),
                              rel=float(diff.mean() / y.mean()), ci95=[lo, hi], p=p, wins=int((diff < 0).sum()))
                print(f"{k:45s} {x.mean():7.1f} vs {y.mean():7.1f}  {100 * diff.mean() / y.mean():+5.1f}% "
                      f"[{lo:+.0f},{hi:+.0f}] p={p:.2g} better {int((diff < 0).sum())}/10")
    json.dump(res, open(keep(os.path.join(a.out, "overload.json")), "w"), indent=1)


if __name__ == "__main__":
    main()
