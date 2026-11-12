"""N-1 contingency sweep and capacity test on the electrical twin.

    python -m blocktetris.circuit_experiments --grid 4 --seeds 2 --out Results/BlockTetris/circuit
"""
import argparse
import json
import os
import time
from multiprocessing import Pool

import numpy as np

from .circuit import Net, CircuitSim, Incident, V3_OPTS

CTRLS = ("fixed", "maxp", "bt", "bt3")
T_END = 2100


def make_net(spec):
    return Net.chowrasta() if spec == "chowrasta" else Net(int(spec), int(spec))


def contingencies(net, rng):
    out = [("none", None)]
    out += [(f"block {net.line_name(l)}", Incident("line_block", int(l))) for l in net.inner]
    out += [(f"exit cut {net.line_name(l)}", Incident("sink_cut", int(l))) for l in net.sinks]
    out += [(f"surge {net.line_name(l)}", Incident("gate_surge", int(l))) for l in net.gates]
    for j in range(net.J):
        a = int(rng.integers(4))
        out.append((f"slow J{net.pos[j][0]}{net.pos[j][1]} arm {'NESW'[a]}", Incident("slow", (j, a))))
    return out


def clearance(inc, base, t_end=T_END, hold=300):
    ex = np.asarray(inc) - np.asarray(base)
    k = 12
    ex = np.convolve(np.pad(ex, (k // 2, k - k // 2 - 1), mode="edge"), np.ones(k) / k, mode="valid")
    peak = ex.max()
    thr = max(3.0, 0.10 * peak)
    if peak <= thr:
        return 0.0, True
    i0, step = t_end // 5, hold // 5
    for i in range(i0, len(ex) - step):
        if (ex[i:i + step] <= thr).all():
            return float((i - i0) * 5), True
    return float((len(ex) - i0) * 5), False


def _job(args):
    spec, ctrl, seed, name, inc, opts, demand = args
    o = V3_OPTS if ctrl == "bt3" else opts
    r = CircuitSim(make_net(spec), "bt" if ctrl.startswith("bt") else ctrl, seed=seed,
                   incident=inc, opts=o, demand=demand).run()
    return {"ctrl": ctrl, "seed": seed, "name": name, "delay_s": float(r["delay_s"]),
            "peak": float(r["peak_stored"]), "end": float(r["stored_end"]), "series": r["series"],
            "spill": r["spill"]}


def sweep(spec, seeds, opts=None, ctrls=CTRLS, procs=None, demand=0.069):
    net = make_net(spec)
    cons = contingencies(net, np.random.default_rng(0))
    jobs = [(spec, c, s, nm, inc, opts if c == "bt" else None, demand)
            for nm, inc in cons for c in ctrls for s in range(1, seeds + 1)]
    with Pool(procs) as p:
        res = p.map(_job, jobs, chunksize=2)
    base = {(r["ctrl"], r["seed"]): r for r in res if r["name"] == "none"}
    rows = {}
    for r in res:
        b = base[(r["ctrl"], r["seed"])]
        r["clear_s"], r["cleared"] = clearance(r["series"], b["series"]) if r["name"] != "none" else (0.0, True)
        r["gridlock"] = r["end"] > 3 * b["end"] + 60  # still jammed at the end of the run
        rows.setdefault(r["name"], {}).setdefault(r["ctrl"], []).append(r)
    summary = {}
    for nm, d in rows.items():
        summary[nm] = {c: {"delay_s": float(np.mean([x["delay_s"] for x in v])),
                           "clear_s": float(np.mean([x["clear_s"] for x in v])),
                           "cleared": float(np.mean([x["cleared"] for x in v])),
                           "gridlock": float(np.mean([x["gridlock"] for x in v])),
                           "peak": float(np.mean([x["peak"] for x in v]))} for c, v in d.items()}
    return summary


def failures(summary, key="bt3"):
    """BT fails a contingency if it gridlocks, never clears, or loses to Fixed (5 %) or MaxPressure (10 %)."""
    out = []
    for nm, d in summary.items():
        b = d[key]
        why = []
        if b["gridlock"] > 0:
            why.append("gridlock")
        if b["cleared"] < 1:
            why.append("not cleared")
        if "fixed" in d and b["delay_s"] > 1.05 * d["fixed"]["delay_s"]:
            why.append("worse than Fixed")
        if "maxp" in d and b["delay_s"] > 1.10 * d["maxp"]["delay_s"]:
            why.append("worse than MaxPressure")
        if why:
            out.append((nm, why))
    return out


def report(summary, label):
    names = [n for n in summary if n != "none"]
    agg = {}
    for c in summary["none"]:
        v = [summary[n][c] for n in names]
        agg[c] = {"normal_delay_s": summary["none"][c]["delay_s"],
                  "mean_delay_s": float(np.mean([x["delay_s"] for x in v])),
                  "mean_clear_min": float(np.mean([x["clear_s"] for x in v])) / 60,
                  "p90_clear_min": float(np.percentile([x["clear_s"] for x in v], 90)) / 60,
                  "cleared_pct": 100 * float(np.mean([x["cleared"] for x in v])),
                  "gridlock_pct": 100 * float(np.mean([x["gridlock"] for x in v]))}
    f = failures(summary)
    f2 = failures(summary, "bt")
    print(f"\n== {label}: {len(names)} contingencies ==")
    for c, a in agg.items():
        print(f"{c:6s} normal {a['normal_delay_s']:6.1f}s | contingency avg delay {a['mean_delay_s']:6.1f}s | "
              f"clear mean {a['mean_clear_min']:5.1f} min p90 {a['p90_clear_min']:5.1f} | cleared {a['cleared_pct']:5.1f}% | "
              f"gridlock {a['gridlock_pct']:4.1f}%")
    print(f"BT-v2 failures: {len(f2)}   BT-v3 failures: {len(f)}")
    for nm, why in f[:40]:
        print("  ", nm, why, {c: round(summary[nm][c]["delay_s"]) for c in summary[nm]})
    return agg, {"v3": f, "v2": f2}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--grid", default="4")
    ap.add_argument("--seeds", type=int, default=2)
    ap.add_argument("--out", default="Results/BlockTetris/circuit")
    ap.add_argument("--opts", default="{}")
    ap.add_argument("--demand", type=float, default=0.069)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    t0 = time.time()
    s = sweep(a.grid, a.seeds, json.loads(a.opts), demand=a.demand)
    agg, f = report(s, f"grid {a.grid} opts {a.opts} demand {a.demand}")
    print(f"{time.time() - t0:.0f} s")
    with open(os.path.join(a.out, f"sweep_{a.grid}_{a.demand}.json"), "w") as fh:
        json.dump({"opts": a.opts, "agg": agg, "failures": f, "summary": s}, fh, indent=1)


if __name__ == "__main__":
    main()
