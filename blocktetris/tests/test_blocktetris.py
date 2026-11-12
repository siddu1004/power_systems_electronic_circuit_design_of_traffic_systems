"""Unit and safety tests.  Run:  python -m pytest blocktetris/tests -q"""
import math

import numpy as np
import pytest

from blocktetris import params as P
from blocktetris.geometry import CONFLICT, PHASES, SPLIT_PHASES, MOVES, is_compatible, move_name
from blocktetris.controllers import make_blocks, Learner
from blocktetris.sim import Sim, SCENARIOS, run_one

IDX = {move_name(i): i for i in range(16)}


# ── conflict matrix ─────────────────────────────────────────────────────────
def test_conflict_matrix_symmetric_and_irreflexive():
    for i in range(16):
        assert not CONFLICT[i][i]
        for j in range(16):
            assert CONFLICT[i][j] == CONFLICT[j][i]


def test_opposite_straights_compatible_crossing_straights_conflict():
    assert not CONFLICT[IDX["NS"]][IDX["SS"]]
    assert not CONFLICT[IDX["ES"]][IDX["WS"]]
    assert CONFLICT[IDX["NS"]][IDX["ES"]]


def test_right_turn_crosses_opposing_straight_left_turn_is_free():
    assert CONFLICT[IDX["NR"]][IDX["SS"]]
    # under left-hand traffic a left turn crosses nothing; it only merges
    for j in range(16):
        if CONFLICT[IDX["NL"]][j]:
            assert MOVES[j][2] == MOVES[IDX["NL"]][2]


def test_u_turn_merges_with_traffic_into_its_own_arm():
    assert CONFLICT[IDX["NU"]][IDX["SS"]]  # S straight exits north too


def test_phases_are_maximal_and_conflict_free():
    for ph in PHASES:
        assert is_compatible(ph)
        for m in range(16):
            if m not in ph:
                assert not is_compatible(ph | {m}), "phase is not maximal"
    for ph in SPLIT_PHASES:
        assert is_compatible(ph)


# ── block model and statistics ──────────────────────────────────────────────
def test_blocks_respect_length_and_sum_weights():
    veh = [(P.CAR, 0.4, 5.5, 0.0, 0), (P.BIKE, 0.2, 2.5, 1.0, 0),
           (P.HEAVY, 0.9, 13.0, 2.0, 1), (P.BIKE, 0.2, 2.5, 3.0, 0)]
    b = make_blocks(veh, 7.5)
    assert len(b) == 3
    assert b[0][0] == pytest.approx(0.6)       # car + bike
    assert b[1][2] == 2                        # heavy class
    assert sum(x[0] for x in b) == pytest.approx(1.7)


def test_sigma_total_is_root_sum_square():
    lr = Learner(P.V2)
    for c in range(3):
        lr.resid[c].extend([-1.0, 1.0] * 10)  # std = 1
    s = [lr.sigma(c) for c in range(3)]
    assert math.sqrt(sum(x * x for x in s)) == pytest.approx(math.sqrt(3), rel=1e-6)
    assert math.sqrt(sum(x * x for x in s)) < sum(s)  # never add sigmas directly


def test_learner_converges_to_true_tau():
    lr = Learner(P.V2)
    lr.green_start(0.0, [IDX["NS"]])
    rng = np.random.default_rng(0)

    class V:
        cls, w, length = P.CAR, 0.4, 5.5
    t = 3.0
    for _ in range(400):
        t += 2.0 * rng.lognormal(0, 0.1) / 2  # 2 lanes, true car headway 2 s per lane
        lr.crossing(t, IDX["NS"], V, 2, "S", False, False)
    assert lr.tau[1] == pytest.approx(5.0, rel=0.08)  # 2.0 s / 0.4 weight


# ── network pressure layer ──────────────────────────────────────────────────
def test_pressure_attenuates_per_hop_and_ramps_down():
    sim = Sim("BT-v2 (fixed)", SCENARIOS["S0"], 1, horizon=10)
    bus = sim.bus
    sink = sim.sink_of(1, 0)                      # east neighbour's exit road
    sink.occ = sink.cap                           # jam it
    for _ in range(5):
        bus.update()
    feeder = sim.net.junctions[0].out_links[1]    # C -> CE feeds that neighbour
    assert bus.p[sink.lid] == pytest.approx(1.0)
    assert bus.p[feeder.lid] == pytest.approx(P.V2.attenuation)
    sink.occ = 0.0
    before = bus.p[sink.lid]
    bus.update()
    assert before - bus.p[sink.lid] == pytest.approx(P.V2.ramp)  # soft-start, not a snap


# ── whole-system invariants ─────────────────────────────────────────────────
@pytest.mark.parametrize("ctrl", ["Fixed-40", "MaxPressure", "BT-v1 (spec)", "BT-v2 (fixed)"])
def test_safety_and_conservation(ctrl):
    sim = Sim(ctrl, SCENARIOS["S7"], 3, horizon=2400)
    for t in range(sim.horizon):
        sim.step(t)
        for j in sim.net.junctions:
            assert is_compatible(j.green)
    assert sum(j.violations for j in sim.net.junctions) == 0
    for jid, start, dur, ph in sim.greens_log:
        assert 15.0 <= dur <= 70.0
    by_j = {}
    for jid, start, dur, ph in sim.greens_log:
        by_j.setdefault(jid, []).append((start, dur))
    for seq in by_j.values():
        for (s0, d0), (s1, _) in zip(seq, seq[1:]):
            assert s1 - (s0 + d0) >= P.AMBER_ALLRED  # amber + all-red never skipped
    net = sim.net
    inside = sum(len(lk.source_q) + len(lk.transit) + len(lk.sink_q) for lk in net.links)
    inside += sum(len(e) for j in net.junctions for e in j.entry)
    inside += sum(len(m.queue) for j in net.junctions for m in j.moves)
    assert net._vid == len(net.done) + inside   # no vehicle created or lost
    for lk in net.links:
        assert lk.occ <= lk.cap + 1e-6          # storage never exceeded


def test_fixed_time_fallback_and_sanity_filter():
    sim = Sim("BT-v2 (fixed)", SCENARIOS["S6"], 2, horizon=2000)
    for t in range(sim.horizon):
        sim.step(t)
    c = sim.ctrls[0]
    assert c.in_fallback        # sensors dead from t=1800
    assert c.rejected > 0       # phantom spikes during the noisy window were rejected


def test_v2_beats_fixed_on_normal_day():
    f = run_one("Fixed-40", "S0", 5, horizon=3000)
    b = run_one("BT-v2 (fixed)", "S0", 5, horizon=3000)
    assert b["avg_delay_s"] < f["avg_delay_s"]
