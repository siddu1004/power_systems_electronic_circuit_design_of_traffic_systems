# Block-Tetris: holes found, fixes, and test results

Simulator: [`blocktetris/`](../blocktetris/README.md) (Python). Raw numbers: `Results/BlockTetris/results_tables.md`,
`results.json`, `ablation.md`. Figures: `Results/BlockTetris/fig*.png`.

## 1. Bottom line

| Scenario (8 seeds each) | Avg delay per vehicle, Fixed-40 → Block-Tetris v2 | vs MaxPressure | Max approach queue (blocks) | Minutes to clear after incident, Fixed → v2 |
|---|---|---|---|---|
| S0 Normal day | 205 s → **110 s (−46 %)** | 164 s | 76 → 40 | – |
| S1 North surge ×1.8, 20 min | 276 s → **171 s (−38 %)** | 319 s | 157 → 91 | not cleared in 50 min (0/8 runs) → 44 min (4/8 cleared) |
| S2 East exits blocked to 5 %, 15 min | 214 s → **119 s (−44 %)** | 170 s | 77 → 39 | **3 → 13 min (v2 slower, see 4.2)** |
| S3 Breakdown at chowrasta approach | 219 s → **122 s (−44 %)** | 203 s | 84 → 53 | 31 → **25 min** |
| S4 Stadium release ×2.6, 10 min | 294 s → **181 s (−38 %)** | 290 s | 180 → 116 | not cleared in 60 min → 53 min (3/8 cleared) |
| S5 25 % buses and trucks all day | 331 s → **208 s (−37 %)** | 337 s | 170 → 77 | – |
| S6 Sensor ghosts, then 5 min dead | 205 s → **112 s (−45 %)** | 148 s | 76 → 47 | 0 → 15 min (see 4.2) |
| S7 North surge + east blockage | 263 s → **158 s (−40 %)** | 241 s | 133 → 75 | 54 min (1/8 cleared) → **41 min (6/8 cleared)** |

- **The improved algorithm (v2) cut average delay by 37–46 % against the fixed 40 s cycle in all 8 scenarios.** It also beat MaxPressure, a strong published adaptive benchmark, by 24–46 % in every scenario.
- **The spec as literally written (v1) does not work.** It gridlocks the network even on a normal day: average delay 640 s, and only 7,300 of about 12,400 vehicles get out. Eleven holes had to be fixed. Section 3 lists them, and the ablation shows which ones matter.
- **Clearing speed:**
  - After the compound jam (S7), v2 returns to its normal level in about 41 min, against 54 min for fixed time, and it clears in 6 of 8 runs against 1 of 8.
  - After the two big surges (S1, S4), fixed time never clears within the run, while v2 clears in 4 of 8 runs (S1) and 3 of 8 runs (S4).
  - It is not faster in every case: after a pure downstream blockage (S2) fixed time gets back to its normal level sooner (section 4.2).
- **Safety held in every run:** zero conflicting greens, minimum green of 15 s never cut, amber plus all-red of 5 s never skipped, and vehicles conserved. These are checked by `blocktetris/tests`; 15 tests pass.

## 2. What was built

**Network.** A central four-arm chowrasta C with neighbours CN, CE, CS, CW. That gives 5 junction agents, 8 inner links of 300 m, 12 gateway roads in and 12 exit roads out. Traffic keeps left (India). Every junction has 16 movements: left, straight, right and U-turn from each arm. A U-turn discharges into its own arm's outbound pipe, so it loads the opposing direction and re-enters the network.

**Physics, hidden from the controller.** The mix is 45 % bikes, 15 % autos, 30 % cars and 10 % buses or trucks. Each vehicle has a true length and a true saturation headway:

| Vehicle | Length | Headway per lane |
|---|---|---|
| Bike | 2.5 m | 0.9 s |
| Auto | 3.5 m | 1.4 s |
| Car | 5.5 m | 2.0 s |
| Bus or truck | 13 m | 3.8 s |

Further realism:
- Headways vary randomly by ±25 %.
- 2 % of drivers hesitate for 4–8 s.
- Start-up loss is 2–3 s.
- Turns are slower: left ×1.05, right ×1.15, U-turn ×1.6.
- Each approach has a shared entry section that feeds turn pockets: left 40 m, right 40 m, U-turn 15 m. When a pocket is full, the vehicles behind are blocked (head-of-line blocking).

The controller only sees what a camera and a stop-line detector would see. It has to learn tau, L and sigma itself.

**Controllers compared.**
- **Fixed-40:** split phasing, one arm at a time, 40 s green and 5 s clearance (180 s cycle).
- **MaxPressure:** back-pressure on queue minus downstream occupancy over the same 53 conflict-free phase sets.
- **BT-v1:** the spec, implemented literally, including its robustness section.
- **BT-v2:** v1 plus the fixes below.

**Metrics.**
- Average and 95th-percentile delay. This includes time spent waiting outside the network at a gate, so throttling cannot hide a queue.
- Maximum approach queue in blocks, including vehicles held at the gate.
- Spillback events: a road reaching 95 % of its storage.
- Twin-run clearance: the incident run is compared with the same controller on the same seed with no incident. The jam counts as cleared once the excess stays below max(15 blocks, 10 % of its peak) for 5 minutes.

### Electrical equivalent: component list (new components marked NEW)

| Traffic | Electrical |
|---|---|
| Bottle level V = sum of block weights | Capacitor voltage |
| Arrivals | Current source |
| Green | MOSFET gate on |
| Amber + all-red | Dead-time (break-before-make) |
| Conflict matrix | Shoot-through interlock |
| Road segment, loading = occupancy / capacity | Transmission line, thermal loading |
| Exit room check | Never close a breaker onto a dead line |
| 80 % pressure alarm, attenuating per hop | Protective relay / under-voltage load shedding |
| Ramped recovery | Soft-start / slew-rate limiter |
| NEW: alarm latch, 80 % on / 60 % off | Schmitt trigger |
| NEW: turn pocket behind a shared lane | Buffer capacitor behind a series bottleneck |
| NEW: charging stuck vehicles to the lane that blocks them | Tracing fault current to the faulted element |
| NEW: rolling re-placement every 5 s | Closed-loop PWM duty update |
| NEW: max-wait guard, 150 s | Watchdog timer |
| EMA on tau, L, arrival rates | RC low-pass filter |
| Sanity filter | Surge arrester / plausibility check |
| Fixed-time fallback | UPS / backup supply |

## 3. Holes found and how they were filled

The ablation table shows the effect of reverting **one** fix in v2 to the spec version. It reports average delay in seconds over 4 seeds.

| # | Hole in the spec | Fix in v2 | Delay without the fix (S0 / S7 / S6) vs full v2 (108 / 162 / 111) |
|---|---|---|---|
| H1 | **The plan is fixed once per green.** Green = clamp(T_discharge) is held even when the situation changes (new platoons, a lane clearing, a jam forming). | **Rolling Tetris re-placement:** every 5 s after minimum green, re-score all 53 pieces and switch if another beats the current one by 30 %. | **243 / 564 / 364**: the largest single effect |
| H2 | **Head-of-line blocking is invisible.** Splitting "by turn intent" assumes every movement has its own lane. On real Indian approaches a full right-turn pocket blocks the shared lane, so the straight queue looks long but cannot move. The controller then gives green to an empty lane while the real blocker starves. This gridlocked MaxPressure too until it was given the same fix. | Charge every vehicle stuck in the shared section to the movement whose pocket is blocking it. | 125 / **648** / 123 |
| H3 | **The exit check is too strict.** "Room for all the blocks it would release" means a movement with 20 blocks waiting is held as long as the exit has room for only 19, even though most of the queue could move. | Allow green if at least one block fits, release only the blocks that fit, and size the green to them. | 108 / **226** / 113 |
| H4 | **tau = 2 s is wrong by more than 2×.** Measured truth is 4.2–5.0 s per weight unit per lane: a car at 2 s headway / 0.4 = 5 s. A green sized with tau = 2 is less than half what it needs. (The good news: the weights are a good proxy for discharge *time*, since all classes land within 4.2–5.0.) | Learn tau online per block class (light / mixed / heavy) plus a turn factor. Learned values: tau about 4.6 / 4.9 / 4.1, U-turn factor about 1.3–1.6, right turn about 1.05–1.1, L about 2.3–2.8 s (fig 6). | 117 / **185** / 114 |
| H5 | **Learning samples are polluted.** "Record every block that discharges" also records the gaps when a queue runs dry or the exit is blocked, so tau drifts up to about 6 and jumps around (fig 6, v1 line). | Drop a sample if the queue ran empty or the exit was blocked during that block. | 118 / 160 / 119 |
| H6 | **Early termination on a headway spike ends green while the bottle is still full.** One hesitant driver (2 % of drivers) triggers it. | Early-end only when the bottle is below the low mark, or when the exit has been blocked for 3 s. | 118 / 170 / 116 |
| H7 | **T_discharge ignores vehicles arriving during green.** | T = L + drain / (1 − rho), with rho = arrival rate / service rate. | 112 / 158 / 112: **no measurable gain**, kept because it is theoretically right |
| H8 | **No hysteresis on the 80 % alarm**, so it chatters on and off at the threshold. | Latch at 80 %, release at 60 %, then ramp down. | No measurable change in these scenarios |
| H9 | **The sanity filter has two failure modes.** Comparing with the previous raw reading accepts a ghost that lasts more than 1 s. Comparing with the last good reading rejects a real surge forever. | Compare with the last good reading, but accept a jump that persists consistently for 4 s. | No measurable change; correctness is covered by a test |
| H10 | **Starvation.** W + a·age alone can leave a small U-turn queue waiting for minutes. | Watchdog: any movement waiting more than 150 s is served next. | 104 / **137** / 104: **it costs average delay.** Keep it for fairness (U-turns, side streets, pedestrians); the threshold is an open tuning point |
| H11 | **Switching is treated as free.** Every phase change costs 5 s of amber plus all-red. The spec's 160 s budget (4 × 40) ignores the 20 s lost per cycle. | Keep the current phase unless the best alternative beats it by 15 %. | No measurable change on top of H1 |

Smaller points:
- **The "three outputs" are four** because of the U-turn.
- **Throttling only moves the queue.** Holding traffic back means vehicles wait at the gate instead, so the metrics count that waiting time.
- **Clearance lost time** belongs in the cycle budget.

## 4. Results in detail

### 4.1 Where the improvement comes from

v2 runs the same physical network with shorter, better-fitted greens:
- **Opposite straights go together** (NS + SS + NL + SL) instead of one arm at a time.
- **The order changes in response to traffic** (rolling re-placement).
- **It never gives green to a lane that cannot move** (head-of-line attribution plus the exit check).

The result is more throughput: about 12,400–13,000 vehicles served against 12,100–12,500 for fixed time. Network queues stay roughly half as large (fig 3, fig 5).

### 4.2 Honest negatives

- **S2 (pure downstream blockage): fixed time clears faster on the twin-run metric (3 vs 13 min). Excess queue is 22 vs 31 block-hours.**
  - Fixed time's split phasing serves the C→CE road only 40 s out of every 180 s, so it throttles flow into the jam by accident.
  - v2 normally pushes much more through C→CE. When the exit dies, it takes the alarm to cut that flow, and then the ramp reopens it slowly.
  - In absolute terms v2 still has lower queues and delay than fixed time throughout S2 (119 vs 214 s average delay). The twin-run metric measures the return to each controller's *own* normal level, and v2's normal level is much lower.
  - Next step: let the alarm act on the *rate* of loading rise, not only the level (look-ahead).
- **S6 (sensor faults): 15 min to recover against 0 for fixed time.** Fixed time doesn't use sensors, so faults cannot hurt it. v2 falls back to fixed time while blind, and after that its excess builds up and drains like any other disturbance. Even so, v2's S6 delay (112 s) is far below fixed time's (205 s).
- **Spillback events are slightly higher for v2 in S1 and S4** (6.8 vs 5.2 and 9.2 vs 6.6). v2 moves more vehicles into the inner links during a surge. Its max queues and delays are still much lower.
- **H7, H8, H9, H11 showed no measurable benefit here.** They are kept for robustness and theory, not because the data demanded them.

### 4.3 The pressure wave (fig 4)

In S7 the jammed exit road CE→OUT goes to pressure 1.0. The road feeding it, C→CE, gets about 0.5 (one hop). The roads feeding C (CN→C, CS→C, CW→C) get about 0.25 (two hops). So the response is strong near the jam and gentle far away, as the spec intended. The pressure then ramps down after the incident instead of snapping off.

## 5. Limitations (read before quoting numbers)

- **Synthetic calibration.** Headways and lengths are textbook-style values, not Coimbatore measurements. Absolute delays will change with real data; the relative ranking is the claim.
- **Mixed traffic is simplified.** There are no pedestrians, no lane indiscipline and no red-light running, and drivers do not reroute.
- **v2's thresholds were tuned on these same scenarios.** That includes the 5 s rolling period, the 1.3× switch margin and the 150 s guard, so there is some risk of overfitting. The ablation used seeds 1–4, which are also in the main 8-seed run.
- **Clearance figures are lower bounds where runs were censored.** When a run never cleared before the end of the simulation, its clearance time is cut off at the end (the "cleared runs" column shows how many did clear).

**Next steps:**
- Re-run on held-out seeds and demand levels.
- Port the controller to SUMO via TraCI with Avinashi Road / Peelamedu counts.
- Tune the max-wait guard, and add a rate-of-rise trigger to the alarm (fix for S2).
