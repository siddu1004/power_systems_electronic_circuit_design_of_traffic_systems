"""Figures + tables for the electrical-twin study.

    python -m blocktetris.circuit_report --out Results/BlockTetris/circuit
"""
import argparse
import json
import os
from multiprocessing import Pool

import numpy as np

from .outputs import keep
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from .circuit import Net, CircuitSim, V3_OPTS
from .experiments import INK2, GRID, SURF  # shared style

COL = {"fixed": "#2a78d6", "maxp": "#eb6834", "bt": "#1baf7a", "bt3": "#eda100"}
LAB = {"fixed": "Fixed-40", "maxp": "MaxPressure", "bt": "Block-Tetris v2", "bt3": "Block-Tetris v3"}
DEMANDS = (0.069, 0.10, 0.13, 0.16, 0.20, 0.24, 0.28)


def _cap(a):
    c, d, s = a
    o = V3_OPTS if c == "bt3" else None
    r = CircuitSim(Net(4, 4), "bt" if c.startswith("bt") else c, seed=s, demand=d, opts=o).run()
    return c, d, r["delay_s"], r["served"] / r["arrived"]


def capacity_curve(out):
    jobs = [(c, d, s) for c in COL for d in DEMANDS for s in (1, 2, 3)]
    with Pool() as p:
        res = p.map(_cap, jobs)
    agg = {}
    for c, d, dl, sv in res:
        agg.setdefault(c, {}).setdefault(d, []).append((dl, sv))
    table = {c: {str(d): [float(np.mean([x[0] for x in v])), float(np.mean([x[1] for x in v]))]
                 for d, v in dd.items()} for c, dd in agg.items()}
    fig, axs = plt.subplots(1, 2, figsize=(12, 4.2))
    x = np.array(DEMANDS) / 0.069
    for c in COL:
        axs[0].plot(x, [table[c][str(d)][0] for d in DEMANDS], color=COL[c], lw=2, marker="o", ms=5, label=LAB[c])
        axs[1].plot(x, [100 * table[c][str(d)][1] for d in DEMANDS], color=COL[c], lw=2, marker="o", ms=5, label=LAB[c])
    axs[0].set_ylabel("Delay per unit of traffic (s)")
    axs[1].set_ylabel("Traffic that got out of the network (%)")
    for ax in axs:
        ax.set_xlabel("Demand (× normal day)")
    axs[0].set_title("4×4 grid (16 junctions): delay as load rises")
    axs[1].set_title("Throughput: where gridlock sets in")
    axs[0].legend(frameon=False)
    fig.tight_layout()
    fig.savefig(keep(os.path.join(out, "fig7_capacity_curve.png")), dpi=150)
    plt.close(fig)
    return table


def contingency_fig(out):
    kinds = [("block", "Road closed"), ("exit cut", "Exit blocked"), ("surge", "Gate surge ×2.2"), ("slow", "Slow approach")]
    loads = [("0.069", "Normal load"), ("0.13", "Heavy (1.9×)"), ("0.16", "Overload (2.3×)")]
    fig, axs = plt.subplots(1, 3, figsize=(14, 4.2))
    summary = {}
    for ax, (d, title) in zip(axs, loads):
        S = json.load(open(os.path.join(out, f"sweep_4_{d}.json")))["summary"]
        x = np.arange(len(kinds))
        for i, c in enumerate(COL):
            v = []
            for k, _ in kinds:
                ks = [n for n in S if n.startswith(k)]
                v.append(np.mean([S[n][c]["delay_s"] for n in ks]))
            summary.setdefault(d, {})[c] = v
            ax.bar(x + (i - 1.5) * 0.2, v, 0.18, color=COL[c], label=LAB[c])
        ax.set_xticks(x, [k[1] for k in kinds], fontsize=8)
        ax.set_title(f"{title}: 88 single faults")
        ax.grid(axis="x", visible=False)
    axs[0].set_ylabel("Delay per unit of traffic (s)")
    axs[0].legend(frameon=False, fontsize=8)
    fig.tight_layout()
    fig.savefig(keep(os.path.join(out, "fig8_n1_contingency.png")), dpi=150)
    plt.close(fig)
    return summary


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Results/BlockTetris/circuit")
    a = ap.parse_args()
    cap = capacity_curve(a.out)
    con = contingency_fig(a.out)
    json.dump({"capacity": cap, "contingency_by_kind": con}, open(keep(os.path.join(a.out, "summary.json")), "w"), indent=1)
    for c, v in cap.items():
        print(c, {d: (round(x[0]), round(100 * x[1])) for d, x in v.items()})


if __name__ == "__main__":
    main()
