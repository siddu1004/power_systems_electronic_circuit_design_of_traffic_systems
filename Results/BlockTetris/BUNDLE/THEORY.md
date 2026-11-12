# Block-Tetris: theory reference (all versions)

This is a technical reference for the team, not the paper. Code: `blocktetris/`. All versions stay runnable (`circuit.VERSIONS`, `params.V1/V2`).

## 1. Electrical equivalent

| Traffic | Circuit | Equation / rule |
|---|---|---|
| Stacked (queued) blocks on a movement | Capacitor, voltage V = Σ block weights | dV/dt = i_in − i_out |
| Arrivals | Current source | λ (W/s), AR(1) noise |
| Green tap | MOSFET | i = min(V, s·min(1, V/V_k)·Δt): saturation above the knee V_k, linear below |
| Start-up lost time | Gate turn-on delay | 2.5 s |
| Amber + all-red | Dead time | 5 s, never skipped |
| Conflict matrix | Shoot-through interlock | 53 maximal conflict-free sets of 16 movements |
| Road | Delay line + Zener clamp | travel delay D = length / speed; no current into a road with occupancy ≥ capacity C |
| Shared lane before pockets | Series bottleneck | a full pocket stops the whole arm (head-of-line blocking) |
| Exit | Current-limited load | sink rate |
| Network | KCL | z(k+1) = z(k) + c_in − c_out (charge conserved to machine precision in every test) |

Weights: bike 0.2, auto 0.3, car 0.4, bus/truck 0.9. One block = 7.5 m. Only blocks that have **landed** on the stack count as queue; blocks still falling (moving on the road) do not.

## 2. Junction logic (Tetris placement)

- **Movements:** 16 per junction (left, straight, right, U-turn per arm; left-hand traffic). Two movements conflict if their chords cross or they merge into the same exit.
- **Discharge time of a stack:** T = L + Σ W_i·τ_c(i) + k·√(Σ σ_c(i)²). The deviations add in root-sum-square; τ is learned per block class (truth ≈ 4.2–5.0 s per weight unit per lane; the starting guess of 2 s is wrong).
- **Head-of-line attribution:** vehicles stuck in the shared section are counted against the pocket that blocks them.
- **v3 rule:**
  - Serve the chosen set until its stack is below the low mark with no platoon arriving, its taps pass no current (exit blocked or lamp fault), or 70 s.
  - Switch early only if another set could pass at least 2× the current (rolling re-placement on discharge current).
  - Next set = argmax Σ (V + a·V·age)·ŝ·(1 − p)·(1 − (z/C)²).
  - Minimum green is 35 s when the junction is saturated.

## 3. Network layer (v3)

- **Relay:** latches when a road's load reaches 0.8 and releases at 0.6 (Schmitt trigger); pressure drops by 0.5 per hop upstream; recovery is ramped (soft start).
- **Boundary metering:** gate inflow is metered once interior accumulation exceeds 0.30.
- **Emergency rotation:** above 0.45, actuated rotation through every arm (gridlock guard).
- **Diversion:** when a road's pressure reaches 0.9, 70 % of the traffic heading for it re-routes to the other exits.

## 4. v4: state estimator and look-ahead

- **Kalman filter per road:** process = KCL with counted flows; measurements = cameras; bad readings are rejected when ν²/S > 9.
- **Transit capacity, 3 levels downstream, horizon H = 120 s:**
  - A_e = μ_e + (0.9 C_e − z_e)/H
  - C_u = min(μ_u, min_k (f_uk / F_ek)·A_ek / r_k)
  - predicted load at t + H = (z + H(F − C))/capacity
- **Use:** the relay, diversion and emergency layers act on the predicted load. This helps when roads close under overload (−33 % at 2.9×, p = 0.006).

## 5. v5: camera failure

A blind junction's stacks are rebuilt from its neighbours:
- **Inflow:** upstream send counts, delayed by travel time D.
- **Outflow:** predicted from its own signal state × learned τ.
- **Correction:** downstream landing counts, D seconds later.

It runs a fixed rotation only while network accumulation is ≥ 0.40 (hybrid mode).

## 6. v6: realistic inputs

- **CCTV:** sees about 60 m of each approach.
  - Short stack: measured directly.
  - Overflowing stack: treated as a lower bound; the hidden tail = road estimate − moving blocks.
- **Google Maps:**
  - Used only as a congestion flag (travel time > free-flow + 60 s) on interior roads with no working camera.
  - Not used as a quantity: Little's law gave correlation 0.3 with true stacks, and it made control worse.

## 7. v7: v3 everywhere, v6 only in special cases

- **Always:** v3 junction and network logic, on realistic CCTV.
- **Special mode, held 300 s after the last trigger:**
  - Triggers: a dead camera, network accumulation ≥ 0.40, or ≥ 2 roads predicted to overflow for ≥ 30 s.
  - While on: v6 predictive protection runs.
  - Camera rebuild runs whenever a camera is blind.

## 8. Real-world controllers implemented in the same circuit (for comparison)

- **Fixed-40:** split phasing; 40 s per arm present.
- **Actuated (NEMA-style):** minimum 10 s, maximum 40 s, gap-out when the arm empties, arms with no call skipped.
- **SCATS-like:** each cycle, the degree of saturation (DS) = busy green / green.
  - Cycle length C changes by +10 s if max DS > 0.9 and by −10 s if max DS < 0.6, within 40–160 s.
  - Splits are proportional to each arm's DS.
- **SCOOT-like:** every 5 min, a Webster plan C = (1.5L + 5)/(1 − Y), with greens proportional to y_i, from measured arm flows and saturation flows.
- **MaxPressure (Varaiya):** Σ (q − 0.25·downstream occupancy)·lanes.

These are simplified re-implementations of the published logic, not the commercial products.

## 9. City model

- **Source:** OpenStreetMap, Peelamedu – Avinashi Road – SITRA (`data/osm/coimbatore_peelamedu.json`).
- **Junctions:** nodes with ≥ 3 distinct neighbours, clustered within 30 m. Arms are binned by compass bearing; a missing arm is a dead line.
- **Roads:** directed delay lines with real length, lanes and class speed; one-ways respected; U-turns allowed.
- **Signals:** signalised if tagged in OSM, or if ≥ 3 arms with ≥ 2 of them major roads (OSM tags only 3 of 32).
- **Size:** 36 junctions, 56 directed roads, 43.8 km, 15 gates and 15 exits.

## 10. Validation discipline

- Paired seeds, Wilcoxon signed-rank test, bootstrap 95 % confidence intervals.
- Held-out seeds 11–20 and a held-out demand pattern.
- Common random numbers: each sensor has its own random stream.
- An exact port of the existing SITRA MATLAB benchmark, matching within 0.002 %.
- Every negative result is kept and reported.
