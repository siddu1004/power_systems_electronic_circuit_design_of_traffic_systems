# SITRA Traffic + Power-Electronics-Inspired MATLAB Simulation

## Current purpose

This package builds the MATLAB behavioral simulation around the validated SITRA traffic-management reference. The frozen Part 8 MPC controller remains the supervisory reference. The discrete switching representation reproduces the recorded Part 8 active-phase behavior.

The supplied specification requires the following workflow:

**Implement -> Run -> Inspect -> Validate -> Update BUILD_LOG -> PASS/FAIL -> Next stage**

The project assumptions and graphing requirements follow the supplied simulation specification. The network consists of HopeCollege, Kalapatti, and Airport feeding SITRA, with SITRA -> Goldwins as B4 and the intentional downstream bottleneck.

## Network assumptions

| Branch | Route | Capacity |
|---|---|---:|
| B1 | HopeCollege -> SITRA | 0.65 veh/s |
| B2 | Kalapatti -> SITRA | 0.35 veh/s |
| B3 | Airport -> SITRA | 0.25 veh/s |
| B4 | SITRA -> Goldwins | 0.45 veh/s |

Capacities are simulation assumptions, not field measurements.

## Demand scenario

Normal demand: `[0.10 0.07 0.05] veh/s`

Surge demand: `[0.30 0.07 0.05] veh/s`

B1 surge interval: 200 -> 400 s

Simulation: 600 s, dt = 1 s

## Signal constraints

Cycle = 63 s

Yellow/clearance = 3 s

Available green = 54 s

Minimum green = 12 s

Maximum green = 30 s

Only one approach is active at a time.

Switching states:

- 0 = clearance / all OFF
- 1 = B1 active
- 2 = B2 active
- 3 = B3 active

## Frozen-reference rule

The package must not rewrite the validated controller. The master script executes `part8_mpc_controller.m` as the frozen reference and captures `qHist`, `residual`, `greenHist`, `tVec`, and `activeHist`.

`signalModel.m` must remain a standalone function and must never call itself.

## Main entry point

From the project root in MATLAB:

```matlab
run_all_SITRA
```

Or run the master simulation directly after placing the frozen Part 8 files in `MATLAB/`:

```matlab
cd MATLAB
run_SITRA_Master_Simulation
```

## Outputs

The master simulation writes:

`Results/data/SITRA_master_results.mat`

`Results/comparison_tables/SITRA_reference_vs_switching.csv`

and 13 PNG engineering figures under:

`Results/figures/`

The figure set includes queue trajectories, total queue, demand, MPC green allocation, switching state, binary switching commands, Part 8 vs switching equivalence, queue error, conservation residual, network schematic, switching architecture, and a conceptual power-electronics layer.

## Validation gates

The master script checks:

- simulation duration
- timestep
- demand surge
- minimum/maximum green
- 54 s green sum
- mutual exclusion
- valid switching states
- active-phase conversion
- conservation
- queue non-negativity
- queue trajectory equivalence
- peak queue equivalence
- recovery equivalence

The script reports **OVERALL SIMULATION STATUS = PASS** only when all mandatory checks pass.

## Electrical scope

This package contains a conceptual power-electronics-inspired visualization only. It deliberately does not invent a DC-link voltage, capacitor value, semiconductor rating, gate resistance, inductance, fuse rating, thermal design, or other device-level parameter. Those belong to the later electrical-design stages after the topology and operating point are defined.

## Current status

This package is **IMPLEMENTED — MATLAB EXECUTION / FIGURE INSPECTION PENDING** in the project build log. A PASS must not be claimed until the user runs the package in MATLAB and inspects the generated figures.
