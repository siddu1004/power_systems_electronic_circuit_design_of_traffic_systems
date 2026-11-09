# S5_physical: SITRA as a real Simscape circuit

## Run

1. Copy this `S5_physical` folder into `SITRA_PROJECT_BUILD_FLAT_COMPLETE/` (next to `createNetwork.m` and `SITRA_baselines/`).
2. In MATLAB (needs Simulink, Simscape, Simscape Electrical):
   ```matlab
   cd SITRA_PROJECT_BUILD_FLAT_COMPLETE/S5_physical
   test_SITRA_S5_Physical
   ```
   This builds `SITRA_S5_Physical.slx`, runs the checks, and writes PNGs to `Results/S5_physical/`.

## What's in the model

**Traffic_Equivalent_Circuit** (1 vehicle = 1 C, 1 V = 1 vehicle)
- C_B1..C_B4: four 1 F Capacitor blocks (the queues)
- I_arrival_B1..B3: Controlled Current Sources (the arrivals)
- I_depart_Bb_to_B4: Controlled Current Sources wired between node Bb and node B4. The B4 node is a real Kirchhoff junction.
- I_exit_Goldwins + I_exit_meter: the capacity-limited exit, through a Current Sensor
- V_B1..V_B4: Voltage Sensors feeding the controller
- Simulink below the circuit: the S4 one-green interlock, plus the departure law `i = g·min(cap, v[k]/dt)` (sampled each 1 s and held)

**Power_Path** (every value PLACEHOLDER, see `S5_physical_params.m`)
AC mains → Ideal Transformer → leakage R/L → 4-diode bridge → DC-link (C, ESR, bleed) → buck converter (MOSFET, freewheel diode, L, C, RC damper) with PI + PWM voltage loop → 24 V bus → 3 channels (MOSFET, current sensor, signal-head load). Simulink below: interlock, over-current latch, bus under-voltage trip.

## Port self-calibration

Simscape doesn't expose terminal names to scripts in every release. So the build first wires a small test circuit, simulates it, and measures which terminal is which: sensor polarity, which current-source terminal delivers current, diode anode, MOSFET drain/source, gate unit, and the transformer ratio convention. The main model is then wired using those measured roles, and the results are printed after the build.

## Checks (`test_SITRA_S5_Physical`)

1. **Block audit:** inventory of physical blocks, zero code blocks in the physical subsystems, zero unconnected physical ports.
2. **T6 traffic run:** sensor voltages vs Part 8 `qRef` (< 1e-3 V), charge balance, no negative queue, no gate overlap. The power path is commented out for this 600 s run.
3. **Power run:** a 0.7 s compressed phase sequence. Bus regulation (±5% mean, ±10% band), channel current only when gated, and a two-greens command blocked by the interlock.

## Not done yet

- Closed loop: the MPC reading the sensors instead of replaying exported gates.
- Faults: a stuck MOSFET, mains sag, a branch short.
- Feeding measured MOSFET conduction back into the traffic circuit. The traffic run is 600 s, and simulating the 10 kHz power path for that long isn't practical, so the two runs are separate for now.
