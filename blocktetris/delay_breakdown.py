"""Where does the delay sit? Splits stored-queue delay on a city map into
signalised-junction stacks, unsignalised (give-way) stacks, road-entry queues
and gate (boundary) queues, per controller.  Normal peak, one seed."""
import argparse
import json
import os
from multiprocessing import Pool

import numpy as np

from . import realtime_experiments as R
from .circuit import CircuitSim
from .city import CityNet


def _one(a):
    name, osm, horizon, demand = a
    net = CityNet.from_osm(osm)
    ctrl, o = R.CTRL[name]
    sim = CircuitSim(net, ctrl, seed=11, demand=demand, opts=dict(o or {}, peak_profile=True), horizon=horizon)
    sig = np.repeat(np.asarray(net.signalised, bool), 16)
    acc = np.zeros(4)
    step = sim.step

    def wrapped(t):
        step(t)
        acc[:] += (sim.V[sig].sum(), sim.V[~sig].sum(), sim.entry.sum(), sim.gateq.sum())

    sim.step = wrapped
    r = sim.run()
    d = acc / max(r["arrived"], 1e-9)        # DT = 1 s
    return dict(name=name, total=float(r["delay_s"]), signal=float(d[0]), giveway=float(d[1]),
                entry=float(d[2]), gate=float(d[3]))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--osm", default="data/osm/coimbatore_city.json")
    ap.add_argument("--out", default="Results/BlockTetris/city_full")
    ap.add_argument("--horizon", type=int, default=5400)
    ap.add_argument("--demand", type=float, default=0.06)
    ap.add_argument("--controllers", default="Fixed-40,SITRA-MPC,Actuated,MaxPressure,Block-Tetris v3,Block-Tetris v7-final")
    a = ap.parse_args()
    names = a.controllers.split(",")
    with Pool() as p:
        rows = p.map(_one, [(n, a.osm, a.horizon, a.demand) for n in names])
    os.makedirs(a.out, exist_ok=True)
    with open(os.path.join(a.out, "delay_breakdown.json"), "w") as f:
        json.dump(rows, f, indent=1)
    print(f"{'controller':24s} {'total':>6s} {'signal':>7s} {'giveway':>8s} {'entry':>6s} {'gate':>6s}")
    for r in rows:
        print(f"{r['name']:24s} {r['total']:6.0f} {r['signal']:7.0f} {r['giveway']:8.0f} {r['entry']:6.0f} {r['gate']:6.0f}")


if __name__ == "__main__":
    main()
