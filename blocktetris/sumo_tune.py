"""Strengthen the Block-Tetris SUMO port where it lost (rain, festival surge,
signal power failure at demand 0.07) WITHOUT touching the test seeds.

Tuning uses seeds 1-3 only; the reported validation uses seeds 11-13.
Every variant is kept (nothing replaced); the winner is re-run on 11-13 by
sumo_experiments with --controllers.

    python -m blocktetris.sumo_tune
"""
import json
import os
import pickle
from multiprocessing import Pool

import numpy as np

from . import sumo_experiments as S

VARIANTS = {
    "Block-Tetris v7-final": S.BT_V7F,
    "BT tune A (short greens)": dict(S.BT_V7F, gmin=10.0, gsat=25.0, gmax=50.0),
    "BT tune B (back-pressure)": dict(S.BT_V7F, mp=0.25),
    "BT tune C (dark throttle)": dict(S.BT_V7F, dark_p=0.5),
    "BT tune D (A+B+C)": dict(S.BT_V7F, gmin=10.0, gsat=25.0, gmax=50.0, mp=0.25, dark_p=0.5),
}
BASE = ["MaxPressure", "Actuated"]
EVENTS = ["normal peak", "accident", "monsoon rain", "festival surge", "signal power failure"]
SEEDS = [1, 2, 3]
SCALE = 0.07


def _job(a):
    d, c, ev, s, r, tg = a
    S.BT_VARIANTS.update(VARIANTS)
    m = S.Runner(d, c, ev, s, r, tg).run()
    m.update(name=c, ev=ev, seed=s)
    return m


def main():
    out = "Results/BlockTetris/sumo_tune"
    os.makedirs(os.path.join(out, "jobs"), exist_ok=True)
    d = S.prepare("data/osm/coimbatore_peelamedu.json", "peelamedu")
    tg = json.load(open(f"Results/BlockTetris/sumo_peelamedu/targets_x{SCALE:g}.json"))
    base = {s: S.make_routes(d, s, SCALE) for s in SEEDS}
    surge = {s: S.make_routes(d, s, SCALE, surge=set(tg["gates3"])) for s in SEEDS}
    names = BASE + list(VARIANTS)
    rows, jobs = [], []
    for c in names:
        for e in EVENTS:
            for s in SEEDS:
                fp = os.path.join(out, "jobs", f"{c}|{e}|{s}".replace(" ", "_").replace("/", "_") + ".pkl")
                if os.path.exists(fp):
                    rows.append(pickle.load(open(fp, "rb")))
                else:
                    jobs.append((d, c, e, s, surge[s] if e == "festival surge" else base[s], tg))
    with Pool() as p:
        for i, r in enumerate(p.imap_unordered(_job, jobs, chunksize=1)):
            fp = os.path.join(out, "jobs", f"{r['name']}|{r['ev']}|{r['seed']}".replace(" ", "_").replace("/", "_") + ".pkl")
            pickle.dump(r, open(fp, "wb"))
            rows.append(r)
            print(f"[{i + 1}/{len(jobs)}] {r['name']} | {r['ev']} | {r['seed']}: {r['delay']:.0f}", flush=True)
    tab = {c: {e: float(np.mean([r["delay"] for r in rows if r["name"] == c and r["ev"] == e])) for e in EVENTS}
           for c in names}
    json.dump(dict(variants={k: v for k, v in VARIANTS.items()}, seeds=SEEDS, table=tab),
              open(os.path.join(out, "tune_results.json"), "w"), indent=1)
    print(f"\n{'variant':28s} " + " ".join(f"{e[:11]:>11s}" for e in EVENTS) + "        mean")
    for c in names:
        v = [tab[c][e] for e in EVENTS]
        print(f"{c:28s} " + " ".join(f"{x:11.0f}" for x in v) + f" {np.mean(v):11.0f}")


if __name__ == "__main__":
    main()
