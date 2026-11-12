# Block-Tetris traffic signal simulator (Python)

A from-scratch, dependency-light (numpy + matplotlib) simulator for the
Block-Tetris algorithm and its electrical-network equivalent. It covers one
central four-arm chowrasta (C) with one neighbouring signal on each outgoing
road (CN, CE, CS, CW): five junction agents and 32 road links.

```
python -m pip install numpy matplotlib pytest
python -m pytest blocktetris/tests -q                       # 15 unit + safety tests
python -m blocktetris.experiments --seeds 8 --ablation 4 --out Results/BlockTetris
```

The results, figures and full write-up are in `Results/BlockTetris/` and
[`Report/BlockTetris_Results.md`](../Report/BlockTetris_Results.md).

## Files

| File | What it is |
|---|---|
| `params.py` | Ground-truth physics (hidden from controllers), plus spec parameters and the v1/v2 switches |
| `geometry.py` | Left-hand-traffic conflict matrix (chord crossing and merge rule) and the 53 maximal conflict-free "Tetris pieces" |
| `model.py` | Vehicles, links (transmission lines), turn pockets plus shared entry section (bottles), junctions, and the 5-junction network |
| `controllers.py` | Sensors with faults, pressure bus, and the Fixed-40, MaxPressure, Block-Tetris v1 and v2 controllers |
| `sim.py` | 1-second engine, safety interlock, 8 congestion scenarios, metrics |
| `experiments.py` | Experiment matrix, twin-run clearance metric, ablation, figures |

## Electrical equivalent: the component list

| Traffic element | Electrical component | Where in the code |
|---|---|---|
| Approach queue weight V = sum of block weights | Capacitor voltage | `Movement.q_w`, `make_blocks` |
| Arrivals | Current source | `Sim.step`, sources |
| Green phase for a movement | MOSFET gate on | `Junction.green` |
| Amber + all-red | Dead-time, break-before-make | `Sim._interlock` (5 s, never skipped) |
| Conflict matrix | Shoot-through interlock | `geometry.CONFLICT`, checked again in the interlock |
| Road link with storage capacity | Transmission line with ampacity | `Link.cap`, `Link.loading` |
| Exit room check | Never close onto a dead line | `exit_link.room()` in discharge |
| Pressure alarm, 80 % loading | Protective relay / under-voltage load shedding | `PressureBus` |
| Attenuation per hop | Line impedance damping the disturbance | `attenuation = 0.5` |
| Ramped recovery | Soft-start / slew-rate limiter | `ramp = 0.02 /s` |
| **NEW** Alarm hysteresis 80 % on / 60 % off | Schmitt trigger | `hysteresis` |
| **NEW** Turn pocket + shared entry section | Buffer capacitor behind a series bottleneck | `Junction.entry`, `POCKET_M` |
| **NEW** Head-of-line attribution | Fault current traced to the blocking element | `hol_aware` |
| **NEW** Max-wait guard | Watchdog timer | `max_wait_guard = 150 s` |
| **NEW** Rolling re-placement | Closed-loop PWM duty update | `rolling = 5 s` |
| Sensor sanity filter | Surge arrester / plausibility check | `_sanity` |
| Fixed-time fallback | UPS / backup supply | `FixedTime` inside each smart controller |
| EMA on tau, L, arrival rates | RC low-pass filter | `Learner`, `lam` |

## Versions: each builds on the previous one, and all stay runnable

| Version | Where | Adds | Select with |
|---|---|---|---|
| v1 | `sim.py` | The spec as literally written | `params.V1`, controller `"BT-v1 (spec)"` |
| v2 | `sim.py` | 11 hole fixes (head-of-line, rolling re-placement, partial exit release, tau learning, …) | `params.V2`, controller `"BT-v2 (fixed)"` |
| v3-pre-divert | `circuit.py` | Current-based rolling, saturation minimum green, back-pressure, boundary metering, emergency rotation | `circuit.VERSIONS["v3-pre-divert"]` |
| v3 | `circuit.py` | + diversion orders on tripped roads | `circuit.V3_OPTS` |
| v3-SITRA first variant | `sitra_bench.py` | Junction controller with score rolling and planned end | `bt_kw=sitra_bench.BT_FIRST_KW` |
| v3-SITRA | `sitra_bench.py` | Exhaustive service, q × s choice, observer, platoon hold | default `"BlockTetris"` |
| v4a-throttle | `circuit.py` | Kalman estimator + direct look-ahead throttle | `circuit.V4A_OPTS` |
| v4 | `circuit.py` | Kalman estimator + 3-level look-ahead; protections act on the predicted load | `circuit.V4_OPTS` |
| v5 | `circuit.py` | Camera layer; a blind junction is rebuilt from its neighbours (hybrid) | `circuit.V5_OPTS` |

**Results are never overwritten.** Every script writes through `outputs.keep()`: if a file already exists, the new run goes to `name_2`, `name_3`, …. Results that earlier runs had replaced are restored from git history into `Results/BlockTetris/archive/`.
