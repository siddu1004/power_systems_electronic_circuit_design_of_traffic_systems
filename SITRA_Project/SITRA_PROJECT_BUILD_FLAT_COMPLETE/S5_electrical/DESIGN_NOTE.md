# SITRA S5 Electrical Simulation Architecture & Design Note

## 1. Executive Summary & Purpose
This design note establishes the mathematical, physical, and architectural implementation of **Stage S5: Physical / Electrical Simulation of the SITRA Network** in MATLAB/Simulink and Simscape Electrical. It defines the formal mapping between the validated 1-second discrete traffic queue dynamics and the physical electrical network, solving the "discrete-time trap" via sample-and-hold discharge dynamics, and decoupling Layer A (traffic equivalent circuit) from Layer B (physical power stage and hardware interface).

---

## 2. Mathematical Analogy & Conservation Isomorphism
In normalized units:
- **1 Vehicle $\equiv$ 1 Coulomb of Charge ($1\text{ C}$)**
- **Traffic Flow Rate ($1\text{ veh/s}$) $\equiv$ Electrical Current ($1\text{ A}$)**
- **Queue Length on branch $b$ ($q_b$ [veh]) $\equiv$ Capacitor Voltage $V_{C_b}$ [V] across $C_b = 1.0\text{ F}$**
- **SITRA Intersection Contention $\equiv$ Kirchhoff's Current Law (KCL) Summing Node**
- **Signal Clearance (Yellow = 3 s) $\equiv$ Gate Driver Hardware Dead-Time**
- **Unidirectional Traffic Flow ($q_b \ge 0$) $\equiv$ Non-reversal Clamping Diodes**

Conservation of vehicles is identical to Kirchhoff's Current Law and Charge Conservation:
$$\Delta Q_b = \int (I_{in,b} - I_{dep,b}) dt = C_b \cdot \Delta V_{C_b}$$

---

## 3. Resolution of the "Discrete-Time Trap"
### Problem:
A continuous resistor or constant current sink connected across capacitor $C_b$ yields exponential decay $v(t) = v(0)e^{-t/RC}$ or continuous non-linear cutoff as $v \to 0$. In the validated discrete traffic reference (`bl_plant_step.m`), queue departure is calculated from the state at the beginning of the 1-second step:
$$\text{dep}(b) = \min\left(\text{cap}(b), \frac{q_b(k)}{\Delta t}\right)$$
and applied uniformly over the interval $\Delta t = 1.0\text{ s}$.

### Solution:
To achieve exact mathematical equivalence to $< 10^{-6}$ (machine precision):
1. **Sample-and-Hold Current Computation**:
   At the start of each interval $t = k \Delta t$, the capacitor voltage $V_{C_b}(k)$ is sampled (zero-order hold).
2. **Held Controlled Current Discharge**:
   The discharge current $I_{dep,b}(t)$ is maintained at exactly $\min(\text{cap}(b), V_{C_b}(k)/\Delta t)$ for the entire 1-second window.
3. Over 1 second, the charge removed is:
   $$\Delta Q_{dep} = \int_{k}^{k+1} I_{dep,b}(t) dt = \min(\text{cap}(b) \Delta t, V_{C_b}(k))$$
   This guarantees:
   - Exactly matches the discrete Euler update $q(k+1) = q(k) + \Delta t (\text{arr} - \text{dep})$.
   - Capacitor voltage satisfies $V_{C_b}(t) \ge 0$ unconditionally without artificial post-clipping.
   - Downstream link B4 receives the exact charge discharged from the active approach link in that same time-step.

---

## 4. Two-Layer Architecture
The system is partitioned into two strictly decoupled layers:
```
+-----------------------------------------------------------------------------------+
| LAYER A: Traffic Equivalent Circuit (Normalized Physics)                         |
|   - Inputs: Arrival Current Sources (S.arrivals: 1 A = 1 veh/s)                   |
|   - Approach Capacitors: C1, C2, C3 (1.0 F each)                                  |
|   - Downstream Bottleneck: C4 (1.0 F) + Regulated Sink (0.45 A)                   |
|   - Discharge paths commutated by gate signals [g1 g2 g3]                         |
+-----------------------------------------------------------------------------------+
                                      ^
                                      | Gate Signals [g1 g2 g3] / Switch Feedback
                                      v
+-----------------------------------------------------------------------------------+
| LAYER B: Physical Power Stage & Hardware Interface                                |
|   - 24 VDC Power Rail (V_dc_nominal = 24.0 V, PLACEHOLDER)                        |
|   - DC-link decoupling capacitor (C_dc_link = 1000 uF, PLACEHOLDER)               |
|   - Power MOSFET switches with gate-driver dead-time interlock                    |
|   - Branch signal-head loads (R_load = 24 Ohm, 24 W LED aspects, PLACEHOLDER)     |
|   - Fast protection fuse & overcurrent/undervoltage monitoring                    |
+-----------------------------------------------------------------------------------+
```

---

## 5. Simscape & Solver Configuration
- **Solver**: `FixedStepDiscrete` (for Simulink discrete state-space blocks) and Simscape local solver (`daessc` / backward Euler) with step size $\Delta t = 1.0\text{ s}$ (or multi-rate sub-stepping for physical transient verification).
- **Mutual Exclusion**: Interlock assertion $\sum g_k \le 1$ continuously monitored.

---

## 6. Directory & File Organization
```
SITRA_PROJECT_BUILD_FLAT_COMPLETE/
  ├── S5_electrical/
  │     ├── DESIGN_NOTE.md                   (This design document)
  │     ├── params_electrical.m             (Single parameters repository with PLACEHOLDER flags)
  │     ├── sim_layerA_circuit.m            (Layer A equivalent circuit engine)
  │     ├── test_stage0_recon.m             (Stage 0 verification runner)
  │     ├── test_stage1_openloop_T6.m       (Stage 1 open-loop T6 replay test)
  │     ├── test_stage2_cross_controller.m  (Stage 2 controllers x scenarios test)
  │     ├── test_stage3_closed_loop.m       (Stage 3 closed-loop MPC/Actuated test)
  │     ├── test_stage4_layerB_power.m      (Stage 4 Layer B physical power stage test)
  │     ├── test_stage5_faults.m            (Stage 5 fault injection & protection test)
  │     └── run_S5_all.m                    (Master test runner for all S5 stages)
```
