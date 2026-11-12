"""Run the full experiment matrix, compute clearance times, draw plots, write
results JSON + a markdown table.

    python -m blocktetris.experiments --seeds 8 --out Results/BlockTetris
"""
import argparse
import json
import os
import time
from multiprocessing import Pool

import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from .sim import SCENARIOS, CONTROLLERS, HORIZON, run_one

# Reference categorical palette, fixed order (blue, orange, aqua, yellow)
COLORS = {"Fixed-40": "#2a78d6", "MaxPressure": "#eb6834",
          "BT-v1 (spec)": "#1baf7a", "BT-v2 (fixed)": "#eda100"}
INK, INK2, GRID, SURF = "#0b0b0b", "#52514e", "#e4e3df", "#fcfcfb"
plt.rcParams.update({
    "figure.facecolor": SURF, "axes.facecolor": SURF, "axes.edgecolor": GRID,
    "axes.labelcolor": INK2, "xtick.color": INK2, "ytick.color": INK2,
    "axes.grid": True, "grid.color": GRID, "grid.linewidth": 0.8,
    "axes.spines.top": False, "axes.spines.right": False, "font.size": 10,
    "axes.titlesize": 11, "axes.titleweight": "bold", "text.color": INK,
})


def _job(args):
    ctrl, sc, seed = args
    keep = seed == 1
    return run_one(ctrl, sc, seed, keep_series=keep)


def smooth(x, k=12):
    x = np.asarray(x, float)
    pad = np.concatenate([np.full(k // 2, x[0]), x, np.full(k - k // 2 - 1, x[-1])])
    return np.convolve(pad, np.ones(k) / k, mode="valid")


SHORT = {"S0": "Normal day", "S1": "Peak surge (north)", "S2": "Downstream blockage (east)",
         "S3": "Breakdown at chowrasta", "S4": "Stadium release (west)", "S5": "Heavy-vehicle day",
         "S6": "Sensor faults", "S7": "Compound surge + blockage"}


def clearance(inc, base, t, t_end, hold=300):
    """Twin-run clearance: first time after the incident ends from which the
    excess stored queue (incident run minus same-seed normal run) stays below
    max(5 blocks, 10% of its peak) for `hold` seconds. Returns (seconds, cleared,
    excess block-hours)."""
    ex = smooth(np.asarray(inc) - np.asarray(base))
    t = np.asarray(t)
    peak = ex.max()
    thr = max(15.0, 0.10 * peak)
    excess_bh = float(np.clip(ex, 0, None).sum() * 5 / 3600)
    if peak <= thr:
        return 0.0, True, excess_bh  # the incident never built a real jam
    step = int(hold / 5)
    idx0 = int(np.searchsorted(t, t_end))
    for i in range(idx0, len(ex) - step):
        if (ex[i:i + step] <= thr).all():
            return float(t[i] - t_end), True, excess_bh
    return float(t[-1] - t_end), False, excess_bh


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--seeds", type=int, default=8)
    ap.add_argument("--out", default="Results/BlockTetris")
    ap.add_argument("--procs", type=int, default=os.cpu_count())
    ap.add_argument("--ablation", type=int, default=0, help="seeds for the ablation study (0 = skip)")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    jobs = [(c, s, seed) for s in SCENARIOS for c in CONTROLLERS for seed in range(1, a.seeds + 1)]
    t0 = time.time()
    with Pool(a.procs) as pool:
        res = pool.map(_job, jobs, chunksize=1)
    print(f"{len(jobs)} runs in {time.time() - t0:.0f} s")
    R = {(r["ctrl"], r["scenario"], r["seed"]): r for r in res}

    # clearance against the same-controller, same-seed normal day
    for (c, s, seed), r in R.items():
        sc = SCENARIOS[s]
        if sc.incident is None:
            continue
        base = R[(c, "S0", seed)]
        r["clear_s"], r["cleared"], r["excess_bh"] = clearance(
            r["series_total"], base["series_total"], r["series_t"], sc.incident[1])

    metrics = ["avg_delay_s", "p95_delay_s", "max_queue_blocks", "spillbacks",
               "throughput", "clear_s", "excess_bh", "violations"]
    table = {}
    for s in SCENARIOS:
        for c in CONTROLLERS:
            rows = [R[(c, s, k)] for k in range(1, a.seeds + 1)]
            d = {}
            for m in metrics:
                vals = [r[m] for r in rows if m in r]
                if vals:
                    d[m] = (float(np.mean(vals)), float(np.std(vals, ddof=1) / np.sqrt(len(vals))) if len(vals) > 1 else 0.0)
            if "cleared" in rows[0]:
                d["cleared_frac"] = float(np.mean([r["cleared"] for r in rows]))
            table[f"{s}|{c}"] = d

    with open(os.path.join(a.out, "results.json"), "w") as f:
        json.dump({"seeds": a.seeds, "horizon_s": HORIZON,
                   "scenarios": {k: v.title for k, v in SCENARIOS.items()},
                   "table": table,
                   "learned_tau_C_seed1": {s: R[("BT-v2 (fixed)", s, 1)].get("tau_C") for s in SCENARIOS},
                   "learned_fturn_C_seed1": {s: R[("BT-v2 (fixed)", s, 1)].get("fturn_C") for s in SCENARIOS},
                   "learned_L_C_seed1": {s: R[("BT-v2 (fixed)", s, 1)].get("L_C") for s in SCENARIOS},
                   }, f, indent=1)
    write_markdown(table, a)
    plots(R, table, a)
    if a.ablation:
        ablation(a)


ABLATE = ["hol_aware", "rolling", "partial_exit", "max_wait_guard", "clean_samples",
          "tau_per_class", "arrivals_in_green", "smart_early_end", "switch_cost",
          "hysteresis", "sanity_persist"]


def ablation(a):
    """Remove one v2 fix at a time (revert it to the spec value)."""
    variants = ["BT-v2 (fixed)"] + [f"BT-abl:{f}" for f in ABLATE] + ["BT-v1 (spec)"]
    scs = ["S0", "S7", "S6"]
    seeds = range(1, a.ablation + 1)
    jobs = [(v, s, k) for v in variants for s in scs for k in seeds]
    with Pool(a.procs) as pool:
        res = pool.map(_job_light, jobs, chunksize=1)
    out = {}
    for (v, s, k), r in zip(jobs, res):
        out.setdefault(v, {}).setdefault(s, []).append(r["avg_delay_s"])
    L = [f"# Ablation: v2 with ONE fix reverted to the spec ({a.ablation} seeds, avg delay s)\n",
         "| Variant | " + " | ".join(scs) + " |", "|---|" + "---|" * len(scs)]
    for v in variants:
        L.append(f"| {v.replace('BT-abl:', 'v2 without ')} | " +
                 " | ".join(f"{np.mean(out[v][s]):.0f} ± {np.std(out[v][s], ddof=1) / np.sqrt(len(out[v][s])):.0f}" for s in scs) + " |")
    with open(os.path.join(a.out, "ablation.md"), "w") as f:
        f.write("\n".join(L) + "\n")
    with open(os.path.join(a.out, "ablation.json"), "w") as f:
        json.dump(out, f, indent=1)
    print("\n".join(L))


def _job_light(args):
    ctrl, sc, seed = args
    r = run_one(ctrl, sc, seed)
    return {"avg_delay_s": r["avg_delay_s"]}


def fmt(d, m, nd=0):
    if m not in d:
        return "–"
    mu, se = d[m]
    return f"{mu:.{nd}f} ± {se:.{nd}f}"


def write_markdown(table, a):
    L = [f"# Block-Tetris results ({a.seeds} seeds per cell, mean ± standard error)\n"]
    for s, sc in SCENARIOS.items():
        L.append(f"\n## {s}: {sc.title}\n")
        L.append("| Controller | Avg delay (s) | 95th pct delay (s) | Max approach queue (blocks) | Spillbacks | Served vehicles | Clearance after incident (s) | Cleared runs | Excess queue (block·h) |")
        L.append("|---|---|---|---|---|---|---|---|---|")
        for c in CONTROLLERS:
            d = table[f"{s}|{c}"]
            cf = f"{d['cleared_frac'] * 100:.0f}%" if "cleared_frac" in d else "–"
            L.append(f"| {c} | {fmt(d, 'avg_delay_s')} | {fmt(d, 'p95_delay_s')} | {fmt(d, 'max_queue_blocks', 1)} | "
                     f"{fmt(d, 'spillbacks', 1)} | {fmt(d, 'throughput')} | {fmt(d, 'clear_s')} | {cf} | {fmt(d, 'excess_bh', 1)} |")
    with open(os.path.join(a.out, "results_tables.md"), "w") as f:
        f.write("\n".join(L) + "\n")


def plots(R, table, a):
    out = a.out
    scs = list(SCENARIOS)
    x = np.arange(len(scs))
    w = 0.2

    # 1. headline bars
    fig, axs = plt.subplots(3, 1, figsize=(11, 10), sharex=True)
    for ax, (m, lab) in zip(axs, [("avg_delay_s", "Average delay per vehicle (s)"),
                                  ("max_queue_blocks", "Max approach queue (blocks)"),
                                  ("spillbacks", "Spillback events")]):
        for i, c in enumerate(CONTROLLERS):
            mu = [table[f"{s}|{c}"][m][0] for s in scs]
            se = [table[f"{s}|{c}"][m][1] for s in scs]
            ax.bar(x + (i - 1.5) * w, mu, w * 0.9, yerr=se, color=COLORS[c], label=c,
                   error_kw={"ecolor": INK2, "lw": 0.8})
        ax.set_ylabel(lab)
        ax.grid(axis="x", visible=False)
    axs[0].legend(ncol=4, frameon=False, loc="upper left")
    axs[-1].set_xticks(x, scs)
    axs[0].set_title("Controller comparison across the 8 congestion scenarios")
    fig.tight_layout()
    fig.savefig(os.path.join(out, "fig1_comparison_bars.png"), dpi=150)
    plt.close(fig)

    # 2. clearance bars
    inc = [s for s in scs if SCENARIOS[s].incident]
    xi = np.arange(len(inc))
    fig, ax = plt.subplots(figsize=(11, 4.8))
    cl = [c for c in CONTROLLERS if "v1" not in c]  # v1's own baseline gridlocks: metric undefined
    w3 = 0.26
    for i, c in enumerate(cl):
        mu = [table[f"{s}|{c}"]["clear_s"][0] / 60 for s in inc]
        se = [table[f"{s}|{c}"]["clear_s"][1] / 60 for s in inc]
        ax.bar(xi + (i - 1) * w3, mu, w3 * 0.9, yerr=se, color=COLORS[c], label=c,
               error_kw={"ecolor": INK2, "lw": 0.8})
    ax.set_xticks(xi, [f"{s}\n{SHORT[s]}" for s in inc], fontsize=8)
    ax.set_ylabel("Minutes to clear after incident ends")
    ax.set_title("Congestion clearance time (twin-run metric, lower is better; "
                 "see table for runs not cleared by the end)")
    ax.set_ylim(0, 75)
    ax.legend(ncol=3, frameon=False, loc="upper center")
    ax.grid(axis="x", visible=False)
    fig.tight_layout()
    fig.savefig(os.path.join(out, "fig2_clearance.png"), dpi=150)
    plt.close(fig)

    # 3. stored-queue trajectories (seed 1) for the incident scenarios
    fig, axs = plt.subplots(2, 3, figsize=(13, 7), sharex=True)
    for ax, s in zip(axs.flat, ["S1", "S2", "S3", "S4", "S6", "S7"]):
        sc = SCENARIOS[s]
        for c in CONTROLLERS:
            if "v1" in c:
                continue
            r = R[(c, s, 1)]
            ax.plot(np.asarray(r["series_t"]) / 60, smooth(r["series_total"]), color=COLORS[c], lw=2, label=c)
        t0, t1 = sc.incident
        ax.axvspan(t0 / 60, t1 / 60, color=GRID, alpha=0.6, lw=0)
        ax.set_title(f"{s}: {SHORT[s]}", fontsize=10)
        ax.set_ylabel("Stored queue (blocks)")
    for ax in axs[-1]:
        ax.set_xlabel("Time (min); shaded = incident")
    axs[0, 0].legend(frameon=False, fontsize=8)
    fig.suptitle("Stored queue in the whole network incl. vehicles held at the gates (seed 1; "
                 "BT-v1 omitted: it gridlocks and runs off the scale)",
                 fontweight="bold")
    fig.tight_layout()
    fig.savefig(os.path.join(out, "fig3_queue_levels.png"), dpi=150)
    plt.close(fig)

    # 4. pressure wave heatmap, BT-v2, S7 and S2
    for s in ("S2", "S7"):
        r = R[("BT-v2 (fixed)", s, 1)]
        P = np.asarray(r["series_p"]).T
        names = r["link_names"]
        keep = [i for i, n in enumerate(names) if "IN->" not in n]
        fig, axs = plt.subplots(2, 1, figsize=(12, 8))
        tt = np.arange(P.shape[1]) * 10 / 60
        im = axs[0].imshow(P[keep], aspect="auto", cmap="Oranges", vmin=0, vmax=1,
                           extent=[tt[0], tt[-1], len(keep) - 0.5, -0.5], interpolation="nearest")
        axs[0].set_yticks(range(len(keep)), [names[i] for i in keep], fontsize=7)
        axs[0].set_title(f"{s} pressure wave (BT-v2): alarm strength on each road, attenuating per hop")
        axs[0].grid(False)
        fig.colorbar(im, ax=list(axs), label="pressure (top panel)", shrink=0.5, anchor=(0, 1))
        Lf = np.asarray(R[("Fixed-40", s, 1)]["series_load"]).T
        Lb = np.asarray(r["series_load"]).T
        for lab, Lm, c in (("Fixed-40", Lf, COLORS["Fixed-40"]), ("BT-v2", Lb, COLORS["BT-v2 (fixed)"])):
            axs[1].plot(tt, Lm[keep].max(axis=0), color=c, lw=2, label=f"{lab}: worst road loading")
        axs[1].axhline(0.8, color=INK2, lw=1, ls="--")
        axs[1].text(tt[-1], 0.81, "80% alarm", ha="right", va="bottom", color=INK2, fontsize=8)
        axs[1].set_ylabel("Loading (occupancy / capacity)")
        axs[1].set_xlabel("Time (min)")
        axs[1].legend(frameon=False)
        t0, t1 = SCENARIOS[s].incident
        for ax in axs:
            ax.set_xlim(0, tt[-1])
            ax.axvline(t0 / 60, color=INK2, lw=0.8)
            ax.axvline(t1 / 60, color=INK2, lw=0.8)
        fig.savefig(os.path.join(out, f"fig4_pressure_wave_{s}.png"), dpi=150, bbox_inches="tight")
        plt.close(fig)

    # 5. per-junction bottle levels, S2, Fixed vs v2
    fig, axs = plt.subplots(1, 2, figsize=(12, 4), sharey=True)
    names = ["C (chowrasta)", "CN", "CE", "CS", "CW"]
    jc = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4"]
    for ax, c in zip(axs, ["Fixed-40", "BT-v2 (fixed)"]):
        r = R[(c, "S2", 1)]
        Q = np.asarray(r["series_q"])
        tt = np.asarray(r["series_t"]) / 60
        for k in range(5):
            ax.plot(tt, smooth(Q[:, k]), color=jc[k], lw=2, label=names[k])
        ax.axvspan(SCENARIOS["S2"].incident[0] / 60, SCENARIOS["S2"].incident[1] / 60, color=GRID, alpha=0.6, lw=0)
        ax.set_title(f"S2 east blockage: junction queues, {c}")
        ax.set_xlabel("Time (min)")
    axs[0].set_ylabel("Approach queue (blocks)")
    axs[0].legend(frameon=False, fontsize=8)
    fig.tight_layout()
    fig.savefig(os.path.join(out, "fig5_junction_levels_S2.png"), dpi=150)
    plt.close(fig)

    # 6. tau learning
    fig, ax = plt.subplots(figsize=(8, 4))
    for c, ls in (("BT-v1 (spec)", "-"), ("BT-v2 (fixed)", "-")):
        st = R[(c, "S0", 1)]["series_tau"]
        tt = [x[0] / 60 for x in st]
        if "v1" in c:
            ax.plot(tt, [x[1][0] for x in st], color=COLORS[c], lw=2, label="v1: one tau (polluted by idle gaps)")
        else:
            for k, (nm, col) in enumerate(zip(("light", "mixed", "heavy"), ("#eda100", "#e87ba4", "#6250d6"))):
                ax.plot(tt, [x[1][k] for x in st], color=col, lw=2, label=f"v2 tau, {nm} blocks")
    ax.axhspan(4.2, 5.0, color=GRID, alpha=0.8, lw=0)
    ax.text(89, 3.95, "true range 4.2–5.0 s per weight unit per lane", color=INK2, fontsize=8, ha="right", va="top")
    ax.axhline(2.0, color=INK2, ls="--", lw=1)
    ax.text(89, 2.1, "spec start value tau = 2 s", color=INK2, fontsize=8, ha="right", va="bottom")
    ax.set_xlabel("Time (min)")
    ax.set_ylabel("tau (s per weight unit per lane)")
    ax.set_title("Online calibration of tau at the chowrasta (S0, seed 1)")
    ax.legend(frameon=False, fontsize=8, loc="upper right")
    ax.set_ylim(1.5, 13)
    fig.tight_layout()
    fig.savefig(os.path.join(out, "fig6_tau_learning.png"), dpi=150)
    plt.close(fig)


if __name__ == "__main__":
    main()
