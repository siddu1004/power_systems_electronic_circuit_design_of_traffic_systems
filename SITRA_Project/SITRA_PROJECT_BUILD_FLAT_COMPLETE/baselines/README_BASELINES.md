# SITRA baseline controllers (T1–T7 comparison)

New files only. Nothing in the frozen Part 4–9 or S1–S4 files is changed.

## Where it goes

```
<SITRA root>/
  MATLAB/                      createNetwork.m, mpcSignalModel.m, part8_mpc_controller.m ...
  MATLAB/baselines/            <- unzip this folder here
  Results/baselines/           <- created automatically
```

A flat layout also works, as long as `baselines/` sits inside the folder that holds `createNetwork.m` and `mpcSignalModel.m`.

## Run

```matlab
cd MATLAB/baselines
test_bl_integration          % must print INTEGRATION STATUS = PASS
run_baseline_comparison      % table + CSV + MAT + 6 figures
```

`run_baseline_comparison` runs the integration test first and stops if it fails.

## Files

| File | What it does |
|---|---|
| `bl_config.m` | Shared settings: dt, yellow, q0, seeds, Part 8 MPC parameters, Webster/actuated/max-pressure settings |
| `bl_scenarios.m` | Scenarios T1–T7 (named T so they don't clash with S1–S12) |
| `bl_make_arrivals.m` | One arrival sequence per scenario and seed, shared by all controllers. Built-in LCG + Poisson, so MATLAB and Octave give the same arrivals |
| `bl_plant_step.m` | The Part 8 / S2 queue update, same equations and order |
| `bl_gates.m` | S4 contract: `active` -> `[g1 g2 g3]`, asserts at most one gate on |
| `bl_ctrl_sitra.m` | SITRA's own controller: calls frozen `mpcSignalModel.m` with Part 8 parameters |
| `bl_ctrl_webster.m` | Webster fixed-time: C0 = (1.5L+5)/(1−Y), greens ∝ y_i, min green 10 s, C in [30,120] s |
| `bl_ctrl_actuated.m` | Vehicle-actuated: min green 10 s, max green 40 s, passage 3 s, gap-out/max-out, phase skipping |
| `bl_ctrl_maxpressure.m` | Max-pressure (optional): every 10 s pick argmax s_i(q_i − q_B4), yellow on change |
| `bl_simulate.m` | Integration harness: any controller + shared arrivals -> plant, Part 8 loop order |
| `bl_metrics.m`, `bl_hcm_los.m` | Delay, queue, throughput, HCM LOS |
| `bl_export_for_simulink.m` | Turns a run into `[t ...]` matrices for From Workspace blocks (active, gates, arrivals, qRef) |
| `bl_paths.m` | Adds the frozen folder to the path and creates `Results/baselines` |
| `test_bl_integration.m` | Runs frozen Part 8, then SITRA through the harness on T6; requires identical qHist and activeHist |
| `run_baseline_comparison.m` | The results script |

## Fairness rules (enforced in code)

* Same arrivals: `bl_make_arrivals` is called once per (scenario, seed) and the same `A` goes to every controller.
* Same capacities (`createNetwork`), initial queues (`p.q0`), dt, duration and seeds (`p.seeds = 101:105`).
* Same plant (`bl_plant_step`), same S4 gate check every step.
* SITRA and Webster get the nominal demand profile (`A.rate`); actuated and max-pressure use only detector/queue information.

## Scenarios

| ID | Demand (total veh/s, B1:B2:B3 = 10:7:5) | Length | Arrivals |
|---|---|---|---|
| T1 | Low 0.15 (B4 x = 0.33) | 900 s | Poisson, 5 seeds |
| T2 | Moderate 0.25 (x = 0.56) | 900 s | Poisson, 5 seeds |
| T3 | High 0.35 (x = 0.78) | 900 s | Poisson, 5 seeds |
| T4 | Oversaturated 0.50 (x = 1.11) | 900 s | Poisson, 5 seeds |
| T5 | Step: 0.15 (0–300 s), 0.35 (300–600 s), 0.25 (600–900 s) | 900 s | Poisson, 5 seeds |
| T6 | Part 8 B1 surge (200–400 s) | 600 s | Deterministic, reproduces qHist |
| T7 | Part 8 B1 surge | 600 s | Poisson, 5 seeds |

## Metrics

* Average delay = Σ q_B1..B3 · dt / vehicles arrived (s/veh). This is the LOS basis. `NetDelay` also includes the B4 queue.
* Average queue = time-mean of q_B1+q_B2+q_B3. Max queue = largest single-approach queue.
* Throughput = vehicles leaving B4 to Goldwins.
* HCM LOS: A ≤10, B ≤20, C ≤35, D ≤55, E ≤80, F >80 s/veh.
* Vehicles still queued at the end count only the delay they've had so far, so T3/T4 delays are lower bounds.

## Using a baseline inside the Simulink model

```matlab
p = bl_config(); net = createNetwork(); scn = bl_scenarios(p);
A = bl_make_arrivals(scn(6), p, 0);               % T6
R = bl_simulate('Actuated', A, p, net);
S = bl_export_for_simulink(R, 'actuated_T6.mat'); % S.active, S.gates, S.arrivals, S.qRef
```

Feed `S.active` to the S2 queue plant the same way `test_SITRA_S2` feeds `activeHist`, or `S.gates` + `S.arrivals` to the S5 equivalent circuit. Capacitor voltages should then track `S.qRef`.

## Limits

* Capacities are ASSUMED placeholders (createNetwork.m), so the numbers compare controllers on this model. They are not field predictions.
* Webster uses approach capacities as saturation flows. It doesn't see the B4 bottleneck, which is the textbook method's blind spot.
* No electrical ratings are introduced.
