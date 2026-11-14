"""Physical layer: vehicles, road links (transmission lines), approaches (bottles)
and junctions (substations), plus the five-junction chowrasta network builder.

Electrical reading of every object is given in its docstring. The physics here
is the ground truth that controllers can only observe through sensors.
"""
from collections import deque
import math

from . import params as P
from .geometry import MOVES, TURNS


class Vehicle:
    """A charge carrier. Weight = its contribution to bottle voltage."""

    __slots__ = ("vid", "cls", "w", "length", "t_spawn", "ff", "t_join", "prio", "turn")

    def __init__(self, vid, cls, t):
        self.vid = vid
        self.cls = cls
        self.w = P.WEIGHT[cls]
        self.length = P.TRUE_LENGTH_M[cls]
        self.t_spawn = t
        self.ff = 0.0          # accumulated free-flow travel time
        self.t_join = t        # time it joined its current queue
        self.prio = 1 if cls == P.HEAVY else 0  # buses get priority class 1
        self.turn = None


class Link:
    """Transmission line. Capacity = metres of storage (ampacity analogue).

    Occupancy counts every vehicle on the line, moving or queued at the far
    end, so loading = occupancy / capacity is the line's thermal loading.
    """

    def __init__(self, lid, length, lanes, src, dst):
        self.lid = lid
        self.length = length
        self.lanes = lanes
        self.cap = length * lanes
        self.base_cap = self.cap
        self.occ = 0.0
        self.src = src          # ("J", j, arm) or ("SRC",)
        self.dst = dst          # ("J", j, arm) or ("SINK",)
        self.transit = deque()  # (t_arrive, vehicle)
        self.travel = length / P.FREE_SPEED
        # sink side (only for exit roads)
        self.sink_q = deque()
        self.sink_rate = P.SINK_RATE
        self.sink_credit = 0.0
        # source side (only for entry roads): vehicles waiting outside the network
        self.source_q = deque()

    def room(self, length):
        return self.occ + length <= self.cap + 1e-9

    @property
    def loading(self):
        return self.occ / self.cap

    def enter(self, v, t):
        self.occ += v.length
        v.ff += self.travel
        self.transit.append((t + self.travel, v))


class Movement:
    """One tap (MOSFET) of the bottle: approach arm -> exit arm."""

    __slots__ = ("idx", "arm", "turn", "to_arm", "lanes", "queue", "q_len_m", "q_w",
                 "pocket_cap", "credit", "startup", "exit_link", "in_link", "blocked_s",
                 "factor", "head_h", "starved", "was_blocked")

    def __init__(self, idx):
        a, k, b = MOVES[idx]
        self.idx, self.arm, self.turn, self.to_arm = idx, a, k, b
        self.lanes = P.LANES[k]
        self.queue = deque()
        self.q_len_m = 0.0
        self.q_w = 0.0
        self.pocket_cap = P.POCKET_M[k]
        self.credit = 0.0
        self.startup = 0.0
        self.exit_link = None
        self.in_link = None
        self.blocked_s = 0.0
        self.factor = 1.0  # incident multiplier on true headway
        self.head_h = None  # true headway of the current head vehicle (drawn once)
        self.starved = False      # queue ran dry during green since last crossing
        self.was_blocked = False  # exit was full since last crossing

    def push(self, v):
        self.queue.append(v)
        self.q_len_m += v.length
        self.q_w += v.w

    def pop(self):
        v = self.queue.popleft()
        self.q_len_m -= v.length
        self.q_w -= v.w
        return v


class Junction:
    """Substation: four inbound bottles split into 16 taps, one signal head."""

    def __init__(self, jid, name):
        self.jid = jid
        self.name = name
        self.in_links = [None] * 4
        self.out_links = [None] * 4
        self.entry = [deque() for _ in range(4)]  # shared section before turn pockets
        self.entry_len = [0.0] * 16  # entry-section metres per movement intent
        self.entry_w = [0.0] * 16
        self.moves = [Movement(i) for i in range(16)]
        self.turn_probs = [None] * 4  # per arm: probabilities for L,S,R,U
        self.green = frozenset()
        self.events = []    # (t_cross, move_idx, vehicle, queue_nonempty, blocked_during)
        self.joins = []     # (t, move_idx, vehicle) — camera sees a vehicle join a queue
        self.violations = 0

    def wire(self):
        for m in self.moves:
            m.in_link = self.in_links[m.arm]
            m.exit_link = self.out_links[m.to_arm]

    def approach_queue_m(self, arm):
        return sum(v.length for v in self.entry[arm]) + sum(
            self.moves[arm * 4 + t].q_len_m for t in range(4))


class Network:
    """Central four-arm chowrasta (C) with one neighbour on each outgoing road."""

    def __init__(self, rng, demand=0.30, mix=P.DEFAULT_MIX):
        self.rng = rng
        self.mix = list(mix)
        self.junctions = []
        self.links = []
        self.sources = []   # links fed from outside
        self.sinks = []     # links draining to outside
        self.base_demand = demand
        self.demand = {}    # source link id -> veh/s
        self._vid = 0
        self.done = []      # (t_exit, vehicle)
        self._build()

    def _link(self, length, src, dst):
        lk = Link(len(self.links), length, P.LINK_LANES, src, dst)
        self.links.append(lk)
        return lk

    def _build(self):
        C = Junction(0, "C")
        nbrs = [Junction(1 + a, "C" + "NESW"[a]) for a in range(4)]
        self.junctions = [C] + nbrs
        for a in range(4):
            nb = nbrs[a]
            back = (a + 2) % 4  # neighbour's arm that faces C
            l_in = self._link(P.INNER_LINK_M, ("J", nb.jid, back), ("J", 0, a))
            l_out = self._link(P.INNER_LINK_M, ("J", 0, a), ("J", nb.jid, back))
            C.in_links[a], C.out_links[a] = l_in, l_out
            nb.out_links[back], nb.in_links[back] = l_in, l_out
            for arm in range(4):
                if arm == back:
                    continue
                src = self._link(P.OUTER_LINK_M, ("SRC",), ("J", nb.jid, arm))
                snk = self._link(P.OUTER_LINK_M, ("J", nb.jid, arm), ("SINK",))
                nb.in_links[arm], nb.out_links[arm] = src, snk
                self.sources.append(src)
                self.sinks.append(snk)
                self.demand[src.lid] = self.base_demand
        # turn probabilities
        for arm in range(4):
            C.turn_probs[arm] = [0.25, 0.50, 0.20, 0.05]
        for nb in nbrs:
            back = next(a for a in range(4) if nb.in_links[a].src[0] == "J")
            for arm in range(4):
                if arm == back:
                    nb.turn_probs[arm] = [0.30, 0.40, 0.25, 0.05]
                else:
                    pr = [0.0] * 4
                    to_c = next(i for i, k in enumerate(TURNS) if (arm + (1, 2, 3, 0)[i]) % 4 == back)
                    pr[to_c] = 0.50
                    others = [i for i in range(4) if i != to_c]
                    rest = {0: 0.20, 1: 0.20, 2: 0.07, 3: 0.03}
                    s = sum(rest[i] for i in others)
                    for i in others:
                        pr[i] = 0.5 * rest[i] / s
                    nb.turn_probs[arm] = pr
        for j in self.junctions:
            j.wire()

    # ── helpers used by the engine ──────────────────────────────────────────
    def new_vehicle(self, t):
        self._vid += 1
        cls = self.rng.choice(4, p=self.mix)
        return Vehicle(self._vid, int(cls), t)

    def true_headway(self, v, mv):
        h = P.TRUE_HEADWAY[v.cls] * P.TRUE_TURN_FACTOR[mv.turn] * mv.factor
        h *= math.exp(self.rng.normal(0.0, P.TRUE_HEADWAY_CV) - 0.5 * P.TRUE_HEADWAY_CV ** 2)
        if self.rng.random() < P.TRUE_STALL_P:
            h += self.rng.uniform(*P.TRUE_STALL_S)
        return h
