"""Real-time congestion events x real-world signal controllers on the Coimbatore e-twin.

Controllers (all on the same electrical circuit of the real road network):
  Fixed-40            plain fixed time (what most Indian junctions run)
  SCOOT-like          Webster plan re-optimised every 5 min from measured flows
  SCATS-like          cycle length and splits adapted every cycle to degree of saturation
  Actuated            NEMA-style gap-out / max-out, skips arms with no call
  MaxPressure         Varaiya back-pressure
  Block-Tetris v3     generic algorithm (ideal queue knowledge)
  Block-Tetris v6     estimator + look-ahead + camera rebuild, real 60 m CCTV
  Block-Tetris v7     v3 behaviour normally, v6 protections only in special cases, real 60 m CCTV

Events (all on a morning-peak demand profile):
  normal peak, accident on the busiest road, monsoon rain, festival surge at the
  three busiest gates, VIP closure of the three busiest roads, signal power failure
  at the two busiest junctions, CCTV failure at the two busiest junctions.

    python -m blocktetris.realtime_experiments --out Results/BlockTetris/realtime
"""
import argparse
import json
import os
from multiprocessing import Pool

import numpy as np

from .outputs import keep
from .city import CityNet
from .circuit import CircuitSim, Incident, V3_OPTS, V6_OPTS, V7_OPTS

OSM = "data/osm/coimbatore_peelamedu.json"
CTRL = {"Fixed-40": ("fixed", None), "SCOOT-like": ("scoot", None), "SCATS-like": ("scats", None),
        "Actuated": ("actuated", None), "MaxPressure": ("maxp", None),
        "Block-Tetris v3": ("bt", V3_OPTS), "Block-Tetris v6": ("bt", V6_OPTS),
        "Block-Tetris v7": ("bt", V7_OPTS)}
EVENTS = ["normal peak", "accident", "monsoon rain", "festival surge", "VIP closure",
          "signal power failure", "CCTV failure"]
T0, T1 = 1500, 2700          # event window (min 25-45, inside the peak)


def targets(net, demand):
    probe = CircuitSim(net, "fixed", seed=1, demand=demand, record=True, opts={"peak_profile": True})
    probe.run()
    L = np.mean(probe.load_series, axis=0)
    inner = net.inner[np.argsort(-L[net.inner])]
    gates = net.gates[np.argsort(-net.lanes_l[net.gates])]
    jl = sorted(((sum(L[net.in_line[j]][net.arm_present[j]]), j) for j in range(net.J) if net.signalised[j]),
                reverse=True)
    return dict(road=int(inner[0]), roads3=[int(x) for x in inner[:3]], gates3=[int(x) for x in gates[:3]],
                junc2=[int(j) for _, j in jl[:2]])


def incident(ev, tg):
    return {"normal peak": None,
            "accident": Incident("line_block", tg["road"], t0=T0, t1=T1),
            "monsoon rain": Incident("rain", None, t0=T0, t1=T1 + 600),
            "festival surge": Incident("gate_surge", tg["gates3"], t0=T0, t1=T1, mult=2.5),
            "VIP closure": Incident("line_block", tg["roads3"], t0=T0, t1=T0 + 600),
            "signal power failure": Incident("dark", tg["junc2"], t0=T0, t1=T1),
            "CCTV failure": Incident("cam_fail", tuple(tg["junc2"]), t0=T0, t1=T1)}[ev]


def _job(a):
    name, ev, seed, d, tg = a
    net = CityNet.from_osm(OSM)
    ctrl, o = CTRL[name]
    o = dict(o or {}, peak_profile=True)
    sim = CircuitSim(net, ctrl, seed=seed, demand=d, opts=o, incident=incident(ev, tg), record=(seed == 11))
    r = sim.run()
    out = dict(name=name, ev=ev, seed=seed, delay=float(r["delay_s"]), served=float(r["served"] / r["arrived"]),
               peak=float(r["peak_stored"]), series=r["series"], special=int(sim.special_s))
    if seed == 11:
        out["load"] = np.mean(sim.load_series[T0 // 10:T1 // 10], axis=0).tolist()
    return out


def clearance(inc, base, t_end, hold=300):
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


def plots(rows, net, out):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    names = list(CTRL)
    col = dict(zip(names, ["#9a9893", "#6250d6", "#e87ba4", "#1baf7a", "#eb6834", "#2a78d6", "#008300", "#eda100"]))
    mean = lambda nm, ev, key: float(np.mean([r[key] for r in rows if r["name"] == nm and r["ev"] == ev]))
    w = 0.1
    fig, ax = plt.subplots(figsize=(14, 5), facecolor="#fcfcfb")
    x = np.arange(len(EVENTS))
    for i, nm in enumerate(names):
        ax.bar(x + (i - 3.5) * w, [mean(nm, ev, "delay") for ev in EVENTS], w * 0.92, color=col[nm], label=nm)
    ax.set_xticks(x, EVENTS)
    ax.set_ylabel("Average delay per unit of traffic (s)")
    ax.set_title("Coimbatore e-twin: real-time congestion events x real-world controllers", fontweight="bold")
    ax.legend(ncol=4, frameon=False, fontsize=8)
    ax.grid(axis="y", color="#e4e3df")
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    fig.tight_layout()
    fig.savefig(keep(os.path.join(out, "rt1_delay_by_event.png")), dpi=150)
    plt.close(fig)
    M = np.array([[mean(nm, ev, "delay") / mean("Fixed-40", ev, "delay") for ev in EVENTS] for nm in names])
    fig, ax = plt.subplots(figsize=(11, 4.8), facecolor="#fcfcfb")
    im = ax.imshow(M, cmap="Blues_r", vmin=0, vmax=1.2, aspect="auto")
    ax.set_xticks(range(len(EVENTS)), EVENTS, rotation=20, ha="right")
    ax.set_yticks(range(len(names)), names)
    for i in range(len(names)):
        for k in range(len(EVENTS)):
            ax.text(k, i, f"{M[i, k]:.2f}", ha="center", va="center", fontsize=8,
                    color="white" if M[i, k] < 0.55 else "#0b0b0b")
    ax.set_title("Delay relative to Fixed-40 (lower is better)", fontweight="bold")
    fig.colorbar(im, ax=ax, shrink=0.8)
    fig.tight_layout()
    fig.savefig(keep(os.path.join(out, "rt2_relative_heatmap.png")), dpi=150)
    plt.close(fig)
    fig, axs = plt.subplots(2, 3, figsize=(15, 7.5), sharex=True, facecolor="#fcfcfb")
    for ax, ev in zip(axs.flat, EVENTS[1:]):
        for nm in names:
            r = [x for x in rows if x["name"] == nm and x["ev"] == ev and x["seed"] == 11]
            if r:
                ax.plot(np.arange(len(r[0]["series"])) * 5 / 60, r[0]["series"], color=col[nm], lw=1.6, label=nm)
        ax.axvspan(T0 / 60, T1 / 60, color="#e4e3df", alpha=0.6, lw=0)
        ax.set_title(ev, fontsize=10)
        ax.set_ylabel("Stored queue (W)")
    for ax in axs[-1]:
        ax.set_xlabel("Time (min); shaded = event")
    axs[0, 0].legend(frameon=False, fontsize=7)
    fig.suptitle("Network stored queue during each event (seed 11)", fontweight="bold")
    fig.tight_layout()
    fig.savefig(keep(os.path.join(out, "rt3_queue_timeseries.png")), dpi=150)
    plt.close(fig)
    fig, ax = plt.subplots(figsize=(14, 4.5), facecolor="#fcfcfb")
    evs = EVENTS[1:]
    x = np.arange(len(evs))
    for i, nm in enumerate(names):
        ax.bar(x + (i - 3.5) * w, [mean(nm, ev, "clear") / 60 for ev in evs], w * 0.92, color=col[nm], label=nm)
    ax.set_xticks(x, evs)
    ax.set_ylabel("Minutes to clear after the event")
    ax.set_title("How fast each controller clears the congestion (twin-run metric)", fontweight="bold")
    ax.legend(ncol=4, frameon=False, fontsize=8)
    ax.grid(axis="y", color="#e4e3df")
    fig.tight_layout()
    fig.savefig(keep(os.path.join(out, "rt4_clearance.png")), dpi=150)
    plt.close(fig)
    from .city_experiments import draw
    for nm in ("SCATS-like", "Block-Tetris v7"):
        r = [x for x in rows if x["name"] == nm and x["ev"] == "accident" and x["seed"] == 11]
        if r:
            draw(net, np.array(r[0]["load"]), os.path.join(out, f"rt5_map_accident_{nm.split()[0].lower()}.png"),
                 f"Accident on the busiest road, {nm}: road loading during the event")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Results/BlockTetris/realtime")
    ap.add_argument("--seeds", type=int, default=4)
    ap.add_argument("--demand", type=float, default=0.06)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    net = CityNet.from_osm(OSM)
    tg = targets(net, a.demand)
    jobs = [(nm, ev, s, a.demand, tg) for nm in CTRL for ev in EVENTS for s in range(11, 11 + a.seeds)]
    with Pool() as p:
        rows = p.map(_job, jobs, chunksize=1)
    base = {(r["name"], r["seed"]): r["series"] for r in rows if r["ev"] == "normal peak"}
    ends = {"normal peak": T1, "accident": T1, "monsoon rain": T1 + 600, "festival surge": T1,
            "VIP closure": T0 + 600, "signal power failure": T1, "CCTV failure": T1}
    for r in rows:
        r["clear"], r["cleared"] = (0.0, True) if r["ev"] == "normal peak" else \
            clearance(r["series"], base[(r["name"], r["seed"])], ends[r["ev"]])
    table = {}
    print(f"network {net.summary()}\ntargets {tg}\n")
    print(f"{'event':22s} " + " ".join(f"{nm[-11:]:>11s}" for nm in CTRL))
    for ev in EVENTS:
        cells = []
        for nm in CTRL:
            v = [r for r in rows if r["name"] == nm and r["ev"] == ev]
            table[f"{ev}|{nm}"] = dict(delay=float(np.mean([x["delay"] for x in v])),
                                       served=float(np.mean([x["served"] for x in v])),
                                       peak=float(np.mean([x["peak"] for x in v])),
                                       clear_s=float(np.mean([x["clear"] for x in v])),
                                       cleared=float(np.mean([x["cleared"] for x in v])),
                                       special_s=float(np.mean([x["special"] for x in v])))
            cells.append(f"{table[f'{ev}|{nm}']['delay']:11.1f}")
        print(f"{ev:22s} " + " ".join(cells))
    print("\nminutes to clear:")
    for ev in EVENTS[1:]:
        print(f"{ev:22s} " + " ".join(f"{table[f'{ev}|{nm}']['clear_s'] / 60:11.1f}" for nm in CTRL))
    json.dump({"network": net.summary(), "targets": tg, "demand": a.demand, "seeds": a.seeds,
               "event_window_s": [T0, T1], "table": table},
              open(keep(os.path.join(a.out, "results.json")), "w"), indent=1)
    plots(rows, net, a.out)


if __name__ == "__main__":
    main()
