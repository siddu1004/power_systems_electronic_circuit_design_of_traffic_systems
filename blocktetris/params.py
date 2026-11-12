"""Physical constants of the simulated world and tunable controller parameters.

Two kinds of numbers live here and they must never be mixed:

* GROUND TRUTH (TRUE_*): how simulated vehicles actually behave. The controller
  never reads these. It has to learn them from stop-line measurements, exactly
  as a real deployment would have to.
* CONTROLLER PARAMETERS (BTParams): the Block-Tetris spec values (weights,
  tau, L, a, b, thresholds) plus switches for each fix added in v2.
"""
from dataclasses import dataclass, replace

# ── Vehicle classes ──────────────────────────────────────────────────────────
BIKE, AUTO, CAR, HEAVY = 0, 1, 2, 3
CLASS_NAMES = ("bike", "auto", "car", "heavy")

# Spec section 2: "voltage" weights (controller-side, uncalibrated guesses)
WEIGHT = (0.2, 0.3, 0.4, 0.9)

# Ground truth: road space occupied at standstill, including the gap (m)
TRUE_LENGTH_M = (2.5, 3.5, 5.5, 13.0)
# Ground truth: saturation headway per lane (s). The controller does NOT know this.
TRUE_HEADWAY = (0.9, 1.4, 2.0, 3.8)
TRUE_HEADWAY_CV = 0.25          # lognormal spread of individual headways
TRUE_STALL_P = 0.02             # hesitant driver / jaywalker: rare extra gap
TRUE_STALL_S = (4.0, 8.0)
TRUE_STARTUP_LOSS = (2.0, 3.0)  # spec: L = 2-3 s
# Turn penalty on the true headway (left is easy under left-hand traffic)
TRUE_TURN_FACTOR = {"L": 1.05, "S": 1.0, "R": 1.15, "U": 1.6}

# Default Coimbatore-like mix: bikes, autos, cars, buses/trucks
DEFAULT_MIX = (0.45, 0.15, 0.30, 0.10)

# ── Geometry / roads ─────────────────────────────────────────────────────────
DT = 1.0                       # simulation step (s)
FREE_SPEED = 8.33              # m/s (30 km/h urban)
CROSS_TIME = 2.0               # s to cross the junction box
INNER_LINK_M = 300.0           # chowrasta <-> neighbour
OUTER_LINK_M = 300.0           # neighbour <-> outside world
LINK_LANES = 2
LANES = {"L": 1, "S": 2, "R": 1, "U": 1}
POCKET_M = {"L": 40.0, "R": 40.0, "U": 15.0, "S": float("inf")}
SINK_RATE = 1.6                # veh/s that the outside world accepts per exit road
AMBER_ALLRED = 5.0             # 3 s amber + 2 s all-red, never violated


@dataclass(frozen=True)
class BTParams:
    # Spec values
    block_len: float = 7.5
    tau0: float = 2.0            # s per weight unit (spec start value)
    L0: float = 2.5              # start-up lost time
    k_sigma: float = 1.0
    g_min: float = 15.0
    g_max: float = 70.0
    g_base: float = 40.0
    a_age: float = 0.01          # score per second of block age
    b_prio: float = 0.5          # score per priority class unit (buses)
    alarm_on: float = 0.80
    alarm_off: float = 0.80      # v1: no hysteresis
    attenuation: float = 0.5     # per hop
    ramp: float = 0.02           # pressure units per second on recovery
    ema: float = 0.15
    window: int = 30
    low_mark_w: float = 0.5      # weight below which a bottle is "nearly empty"
    # Fixes (all False = spec as literally written = v1)
    tau_per_class: bool = False      # learn tau per block class and turn
    clean_samples: bool = False      # drop samples polluted by empty queue / blocked exit
    arrivals_in_green: bool = False  # T/(1-rho): queue keeps filling while it drains
    partial_exit: bool = False       # release only the blocks that fit downstream
    hysteresis: bool = False         # alarm latch 0.80 on / 0.60 off
    smart_early_end: bool = False    # early-end only when bottle is low or exit blocked
    max_wait_guard: float = 0.0      # 0 = off; else force service after this many s
    switch_cost: bool = False        # keep current phase unless clearly beaten
    sanity_persist: bool = False     # accept a jump if it persists (real surge)
    hol_aware: bool = False          # charge vehicles stuck behind a blocked lane to the blocker
    rolling: float = 0.0             # 0 = off; else re-run the Tetris placement every N s of green


V1 = BTParams()
V2 = replace(
    V1,
    alarm_off=0.60,
    tau_per_class=True,
    clean_samples=True,
    arrivals_in_green=True,
    partial_exit=True,
    hysteresis=True,
    smart_early_end=True,
    max_wait_guard=150.0,
    switch_cost=True,
    sanity_persist=True,
    hol_aware=True,
    rolling=5.0,
)
