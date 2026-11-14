"""Full-city e-twin run on a real OpenStreetMap network.

    python -m blocktetris.city_experiments --osm data/osm/coimbatore_peelamedu.json --out Results/BlockTetris/city

Compares Fixed-40, MaxPressure, Block-Tetris v3 and v6 (60 m CCTV + estimator)
on the real road graph: normal day, the busiest interior road closed, and the
cameras of the two busiest signalised junctions dead. Draws the network as a
circuit map coloured by road loading.
"""
import argparse
import json
import os
from multiprocessing import Pool

import numpy as np

from .outputs import keep
from .city import CityNet
from .circuit import CircuitSim, Incident, V3_OPTS, V6_OPTS

CTRL = {"Fixed-40": ("fixed", None), "MaxPressure": ("maxp", None),
        "Block-Tetris v3": ("bt", V3_OPTS), "Block-Tetris v6": ("bt", V6_OPTS)}


def _job(a):
    osm, name, case, d, seed, tgt = a
    net = CityNet.from_osm(osm)
    ctrl, o = CTRL[name]
    inc = None
    if case == "busiest road closed":
        inc = Incident("line_block", tgt["road"])
    elif case == "2 cameras dead":
        inc = Incident("cam_fail", tuple(tgt["cams"]), t0=1200, t1=2400)
    sim = CircuitSim(net, ctrl, seed=seed, demand=d, opts=o, incident=inc, record=(seed == 11))
    r = sim.run()
    out = dict(name=name, case=case, d=d, seed=seed, delay=float(r["delay_s"]),
               served=float(r["served"] / r["arrived"]))
    if seed == 11 and case == "normal":
        out["load"] = np.mean(sim.load_series[len(sim.load_series) // 2:], axis=0).tolist()
    return out


def draw(net, load, path, title):
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(9, 7), facecolor="#fcfcfb")
    ax.set_facecolor("#fcfcfb")
    cmap = plt.get_cmap("Oranges")
    for l in net.inner:
        (ja, _), (jb, _) = net.src[l], net.dst[l]
        (y1, x1), (y2, x2) = net.pos[ja], net.pos[jb]
        ax.plot([x1, x2], [y1, y2], color=cmap(0.15 + 0.85 * min(1.0, load[l])),
                lw=1 + 1.2 * net.lanes_l[l], solid_capstyle="round")
    sig = np.array(net.signalised)
    P = np.array(net.pos)
    ax.scatter(P[~sig, 1], P[~sig, 0], s=12, c="#52514e", zorder=3, label="give-way junction")
    ax.scatter(P[sig, 1], P[sig, 0], s=40, c="#2a78d6", zorder=4, label="signalised junction")
    ax.set_aspect(1 / np.cos(np.radians(P[:, 0].mean())))
    ax.set_title(title, fontweight="bold")
    ax.set_xlabel("longitude")
    ax.set_ylabel("latitude")
    ax.legend(frameon=False, loc="lower right")
    sm = plt.cm.ScalarMappable(cmap=cmap, norm=plt.Normalize(0, 1))
    fig.colorbar(sm, ax=ax, label="road loading (occupancy / capacity)", shrink=0.7)
    fig.tight_layout()
    fig.savefig(keep(path), dpi=150)
    plt.close(fig)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--osm", default="data/osm/coimbatore_peelamedu.json")
    ap.add_argument("--out", default="Results/BlockTetris/city")
    ap.add_argument("--demands", default="0.04,0.06")
    ap.add_argument("--seeds", type=int, default=4)
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    net = CityNet.from_osm(a.osm)
    print("network:", net.summary())
    # targets from a Fixed-40 probe run: busiest interior road, two busiest signalised junctions
    probe = CircuitSim(net, "fixed", seed=1, demand=float(a.demands.split(",")[0]), record=True)
    probe.run()
    L = np.mean(probe.load_series, axis=0)
    road = int(net.inner[np.argmax(L[net.inner])])
    jl = [(sum(L[net.in_line[j]][net.arm_present[j]]), j) for j in range(net.J) if net.signalised[j]]
    cams = [j for _, j in sorted(jl, reverse=True)[:2]] or [0]
    tgt = dict(road=road, cams=cams)
    cases = ["normal", "busiest road closed", "2 cameras dead"]
    jobs = [(a.osm, nm, c, float(d), s, tgt) for nm in CTRL for c in cases for d in a.demands.split(",")
            for s in range(11, 11 + a.seeds)]
    with Pool() as p:
        rows = p.map(_job, jobs, chunksize=1)
    res = {"network": net.summary(), "targets": {"road": net.line_name(road), "cameras": cams}, "table": {}}
    for d in a.demands.split(","):
        print(f"\ndemand {d} W/s per entering lane")
        for c in cases:
            line = []
            for nm in CTRL:
                v = [r for r in rows if r["name"] == nm and r["case"] == c and r["d"] == float(d)]
                res["table"][f"{d}|{c}|{nm}"] = dict(delay=float(np.mean([x["delay"] for x in v])),
                                                     served=float(np.mean([x["served"] for x in v])))
                line.append(f"{nm} {np.mean([x['delay'] for x in v]):6.1f}s")
            print(f"  {c:20s} " + " | ".join(line))
    json.dump(res, open(keep(os.path.join(a.out, "results.json")), "w"), indent=1)
    d0 = a.demands.split(",")[-1]
    for nm in ("Fixed-40", "Block-Tetris v6"):
        r = [x for x in rows if x["name"] == nm and x["case"] == "normal" and x["d"] == float(d0) and "load" in x]
        if r:
            draw(net, np.array(r[0]["load"]), os.path.join(a.out, f"city_map_{nm.split()[0].lower()}.png"),
                 f"Coimbatore e-twin, {nm}: mean road loading")


if __name__ == "__main__":
    main()
