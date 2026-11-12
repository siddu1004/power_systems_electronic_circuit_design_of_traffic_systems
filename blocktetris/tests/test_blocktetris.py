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


# ── electrical twin (circuit solver) ────────────────────────────────────────
from blocktetris.circuit import Net, CircuitSim, Incident, PM, V3_OPTS


@pytest.mark.parametrize("ctrl,opts", [("fixed", None), ("maxp", None), ("bt", None), ("bt", V3_OPTS)])
def test_circuit_charge_conservation_clamp_and_interlock(ctrl, opts):
    net = Net(3, 3)
    sim = CircuitSim(net, ctrl, seed=4, demand=0.2, horizon=2400, opts=opts,
                     incident=Incident("line_block", int(net.inner[0])))
    for t in range(sim.T):
        sim.step(t)
        occ = sim.occ()
        assert (occ <= net.cap0 + 1e-6).all()            # Zener clamp holds
        assert (sim.V >= -1e-9).all()
        for j in range(net.J):
            g = sim.green[j * 16:(j + 1) * 16]
            if g.any():
                assert any((PM[p] == g).all() for p in range(len(PM)))  # only conflict-free pieces
    inside = sim.V.sum() + sim.entry.sum() + sim.gateq.sum() + sim.ring.sum()
    assert sim.arrived == pytest.approx(sim.served_out + inside, rel=1e-9)  # KCL: no charge lost


def test_v3_beats_fixed_under_overload():
    net = Net(4, 4)
    f = CircuitSim(net, "fixed", seed=1, demand=0.2).run()
    b = CircuitSim(net, "bt", seed=1, demand=0.2, opts=V3_OPTS).run()
    assert b["delay_s"] < f["delay_s"]


# ── existing SITRA benchmark port ───────────────────────────────────────────
def test_sitra_port_reproduces_published_matlab_numbers():
    from blocktetris import sitra_bench as B
    s = [x for x in B.scenarios() if x["id"] == "T6"][0]
    t, rate, count = B.make_arrivals(s["f"], s["T"], s["stoch"], 0)
    ref = {"SITRA": 24.281, "Webster": 34.807, "Actuated": 17.233, "MaxPressure": 20.049}
    for c, v in ref.items():
        got = B.metrics(B.simulate(c, t, rate, count, s["q0"], s["events"]))["avgDelay"]
        assert got == pytest.approx(v, abs=1e-3)
    bt = B.metrics(B.simulate("BlockTetris", t, rate, count, s["q0"], s["events"]))["avgDelay"]
    assert bt < ref["Actuated"]


# ── v4: state estimator + look-ahead transfer capability ─────────────────────
def test_kalman_estimator_beats_raw_faulty_sensors():
    from blocktetris.circuit import V3_OPTS
    net = Net(4, 4)
    kf = CircuitSim(net, "bt", seed=3, demand=0.13, horizon=1800, opts=dict(V3_OPTS, estimator="kf")).run()
    raw = CircuitSim(net, "bt", seed=3, demand=0.13, horizon=1800, opts=dict(V3_OPTS, estimator="raw")).run()
    assert kf["est_rmse"] < 0.8 * raw["est_rmse"]


def test_bad_data_rejection_catches_phantoms_and_frozen_cameras():
    from blocktetris.circuit import V3_OPTS
    sim = CircuitSim(Net(4, 4), "bt", seed=3, demand=0.13, horizon=1500,
                     opts=dict(V3_OPTS, estimator="kf", phantom_p=0.01))
    sim.run()
    assert sim.est.rejects > 0


def test_lookahead_throttles_inflow_two_hops_before_a_downstream_jam():
    from blocktetris.network_state import NetState
    net = Net(1, 4)                                   # a corridor J00-J01-J02-J03
    sim = CircuitSim(net, "bt", seed=1, demand=0.1, horizon=10)
    est = NetState(sim, mode="oracle", depth=3)
    exit_east = net.out_line[3, 1]                    # far end of the corridor
    est.z[:] = 0.2 * net.cap0
    est.lam[:] = 0.3
    est.mu[:] = 0.3
    est.mu[exit_east] = 0.0                           # downstream exit dead
    est.z[exit_east] = net.cap0[exit_east]            # and full
    est.atc(sim.ratio, sim.gateq)
    two_hops = net.out_line[1, 1]                     # J01 -> J02, two roads before the jam
    one_hop = net.out_line[2, 1]                      # J02 -> J03
    assert est.Cd[one_hop] < 0.3 and est.Cd[two_hops] < 0.3   # discharge capability cut upstream
    est_shallow = NetState(sim, mode="oracle", depth=1)
    est_shallow.z[:], est_shallow.lam[:], est_shallow.mu[:] = est.z, est.lam, est.mu
    est_shallow.atc(sim.ratio, sim.gateq)
    assert est.Cd[two_hops] < est_shallow.Cd[two_hops]       # depth 3 sees it, depth 1 does not


# ── camera failure: neighbour reconstruction ────────────────────────────────
def test_blind_junction_rebuilt_from_neighbours_beats_frozen_camera():
    from blocktetris.circuit import V4_OPTS
    net = Net(4, 4)
    inc = lambda: Incident("cam_fail", (5, 6), t0=300, t1=1200)
    nb = CircuitSim(net, "bt", seed=2, demand=0.13, horizon=1300, incident=inc(),
                    opts=dict(V4_OPTS, blind_mode="neighbour"))
    fr = CircuitSim(net, "bt", seed=2, demand=0.13, horizon=1300, incident=inc(),
                    opts=dict(V4_OPTS, blind_mode="frozen"))
    a, b = nb.run(), fr.run()
    assert a["blind_rmse"] < 0.6 * b["blind_rmse"]
    inside = nb.V.sum() + nb.entry.sum() + nb.gateq.sum() + nb.ring.sum()
    assert nb.arrived == pytest.approx(nb.served_out + inside, rel=1e-9)   # physics untouched


# ── city builder (OpenStreetMap -> circuit) ─────────────────────────────────
def _toy_osm(tmp_path):
    import json as _j
    # 4-way signalised crossing A (11.0, 77.0); T-junction B 400 m east; one-way link
    N = {1: (11.0, 77.0), 2: (11.0036, 77.0), 3: (10.9964, 77.0), 4: (11.0, 76.9963),
         5: (11.0, 77.00366), 6: (11.0036, 77.00366), 7: (11.0, 77.0073), 8: (11.0036, 76.9963)}
    el = [{"type": "node", "id": k, "lat": v[0], "lon": v[1]} for k, v in N.items()]
    el[0]["tags"] = {"highway": "traffic_signals"}
    ways = [(10, [4, 1, 5, 7], {"highway": "primary", "name": "Avinashi Road"}),
            (11, [3, 1, 2], {"highway": "secondary", "name": "Cross Road"}),
            (12, [5, 6], {"highway": "tertiary", "name": "Side Road"}),
            (13, [2, 8], {"highway": "tertiary", "oneway": "yes", "name": "One Way"})]
    el += [{"type": "way", "id": i, "nodes": ns, "tags": t} for i, ns, t in ways]
    p = tmp_path / "toy.json"
    p.write_text(_j.dumps({"elements": el}))
    return p


def test_city_builder_topology_and_physics(tmp_path):
    from blocktetris.city import CityNet
    from blocktetris.circuit import V6_OPTS
    net = CityNet.from_osm(str(_toy_osm(tmp_path)), signal_policy="osm")
    s = net.summary()
    assert s["junctions"] >= 2 and s["signalised"] == 1
    assert len(net.priority) == s["junctions"] - 1                 # unsignalised = give-way
    # T-junction: one arm slot is the dead dummy line, its turns are impossible
    assert (~net.arm_present).sum() >= 1
    for l in range(net.L):
        if net.dst[l][0] >= 0:
            assert abs(net.base_ratio[l].sum() - 1.0) < 1e-9
    assert len(set(net.Dl[net.inner])) >= 1 and net.Dmax >= 2       # real travel delays
    for ctrl, o in (("fixed", None), ("bt", V6_OPTS)):
        sim = CircuitSim(net, ctrl, seed=1, demand=0.05, horizon=900, opts=o)
        r = sim.run()
        inside = sim.V.sum() + sim.entry.sum() + sim.gateq.sum() + sim.ring.sum()
        assert sim.arrived == pytest.approx(sim.served_out + inside, rel=1e-9)   # KCL on a real graph
        assert sim.V[[g for g in range(net.G) if net.g_exit[g] == net.dummy]].sum() == pytest.approx(0.0)
