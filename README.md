# Project SITRA: Cyber-Physical Dual-Domain Congestion Management & Power-Electronics Emulation of Urban Traffic Intersections

[![Branch: main](https://img.shields.io/badge/Git_Branch-main-success?style=flat-square)](https://github.com/siddu1004/power_systems_electronic_circuit_design_of_traffic_systems/tree/main)
[![Simulink & Simscape](https://img.shields.io/badge/Simulation-Simulink_%26_Simscape_Electrical-e06c75?style=flat-square)](https://www.mathworks.com/products/simscape-electrical.html)
[![Web Interactive](https://img.shields.io/badge/Web_UI-React_19_%2B_Vite_%2B_Tailwind_v4-38bdf8?style=flat-square)](https://vitejs.dev/)
[![IEEE Journal Paper](https://img.shields.io/badge/Publication-IEEE_Transactions_Draft-blue?style=flat-square)](Report/SITRA_IEEE_Journal_Paper.docx)
[![Validation Status](https://img.shields.io/badge/Validation_Status-ALL_GATES_PASS-2d6a4f?style=flat-square)](#)

An integrated computational cyber-physical research platform and living laboratory investigating how urban traffic networks can legitimately be modeled, emulated, and controlled as power-electronic switching circuits and charge-conserving networks.

---

## 📑 Table of Contents
1. [Core Scientific Concept: Dual-Domain Isomorphism](#-core-scientific-concept-dual-domain-isomorphism)
2. [Five-Layer System Architecture](#-five-layer-system-architecture)
3. [Dual-Track Simulation Infrastructure](#-dual-track-simulation-infrastructure)
4. [Multi-Controller Comparison (SITRA MPC vs Baselines)](#-multi-controller-comparison)
5. [The Non-Circular Twin-Run Clearance Metric](#-the-non-circular-twin-run-clearance-metric)
6. [14-Scenario Experimental Taxonomy (T1 to T14)](#-14-scenario-experimental-taxonomy-t1-to-t14)
7. [Key Empirical Results & Physical Validation](#-key-empirical-results--physical-validation)
8. [Power Electronics Non-Idealities & Thermal Safety](#-power-electronics-non-idealities--thermal-safety)
9. [Repository Organization & File Guide](#-repository-organization--file-guide)
10. [How to Run Simulations](#-how-to-run-simulations)
11. [Publications & Research Documents](#-publications--research-documents)
12. [Contributors & Acknowledgments](#-contributors--acknowledgments)
13. [Citation](#-citation)

---

## ⚡ Core Scientific Concept: Dual-Domain Isomorphism

Project SITRA establishes a rigorous, mathematically exact isomorphism between **hydraulic/fluid vehicular queue dynamics** and **electrostatic charge conservation in analog power electronic circuits**:

$$\mathbf{q}_i(t) \equiv V_{C,i}(t) = \frac{1}{C_i} \int_0^t \left( I_{\text{in},i}(\tau) - I_{\text{out},i}(\tau) \right) d\tau$$

```
+-------------------------------------------------------------------------------------------------------+
|                                  DUAL-DOMAIN EQUIVALENCE FORMULATION                                  |
+-------------------------------------------------------------------------------------------------------+
|  Traffic System Quantity                     Electrical Equivalent Analog            Scaling Ratio    |
+-------------------------------------------------------------------------------------------------------+
|  Vehicular Queue Length q_i(t)        <--->  Capacitor Voltage V_C,i(t)              1 V = 1 veh      |
|  Arrival Demand Rate d_i(t)           <--->  Controlled Current Source I_in,i(t)     1 A = 1 veh/s    |
|  Saturation Discharge Capacity c_i(t) <--->  Controlled Current Sink I_out,i(t)      1 A = 1 veh/s    |
|  Signal Phase Actuation u_i(t)        <--->  Power MOSFET Gate Voltage V_gate(t)     12 V Logic / PWM |
|  Storage Capacitance C_i              <--->  Storage Capacitor (C = 1.0 uF / 1.0 F)  1 F = 1 s        |
|  Corridor Bottleneck Spill-Back       <--->  Zener Diode Clamping Potential          V_clamp = 15.0 V |
+-------------------------------------------------------------------------------------------------------+
```

Under this formal equivalence, an intelligent traffic signal controller is fundamentally the **supervisory gate driver of a multi-phase switched-mode power converter network**.

---

## 🏛️ Five-Layer System Architecture

The project architecture spans five hierarchical cyber-physical layers:

```
+-------------------------------------------------------------------------------------------------------+
|                                    FIVE-LAYER SYSTEM ARCHITECTURE                                     |
+-------------------------------------------------------------------------------------------------------+
|  [Layer L5] Supervisory Multi-Controller Intelligence                                                 |
|             - Receding-Horizon SITRA MPC (QP formulation, Np = 5 s, terminal weight Wf = 2*Wq)        |
|             - Webster Optimal Fixed-Time Equisaturation (C0 = (1.5L + 5)/(1 - Y))                     |
|             - NEMA Vehicle-Actuated Gap-Out Logic (Ue = 3.0 s passage time, max green caps)           |
|             - Feedback MaxPressure (w_i = q_i - q_4 gradient queue routing)                           |
+-------------------------------------------------------------------------------------------------------+
|  [Layer L4] Parasitic Dynamics, ESR & Junction Thermal Modeling                                       |
|             - Capacitor lead/foil ESR (50 mOhm) & active feedforward compensator (< 0.1 mV ripple)    |
|             - Power MOSFET conduction (38.4 mW) & switching (6.8 mW) losses (P_tot = 45.2 mW)         |
|             - Lumped thermal network (R_theta = 62 deg C/W, tau = 45 s -> Delta T_j = +2.80 deg C)   |
+-------------------------------------------------------------------------------------------------------+
|  [Layer L3] Regulated Auxiliary Power Conversion & DC Distribution Bus                                |
|             - 230 V AC (50 Hz) Grid Mains -> 10:1 Step-Down Isolation Transformer (23 V RMS)          |
|             - Full-Bridge Schottky Rectifier + Bulk Filter (2200 uF electrolytic) -> 30 V DC rail     |
|             - Closed-Loop Switched Buck DC-DC Converter (50 kHz, Kp = 0.15, Ki = 12.0) -> 24 V DC bus|
+-------------------------------------------------------------------------------------------------------+
|  [Layer L2] Solid-State Power MOSFET Switching Fabric & Safety Interlocks                             |
|             - 3 x High-Side N-Channel Power MOSFETs (IRF540N, V_DS = 100 V, R_DS(on) = 44 mOhm)      |
|             - Dedicated Gate Drivers (UCC27524, 12 V logic, 5 A sink/source)                          |
|             - Hardware Break-Before-Make Dead-Time Interlock (5.0 us blanking prevents shoot-through) |
+-------------------------------------------------------------------------------------------------------+
|  [Layer L1] Dynamic Queue Capacitive Storage & Arterial Network Topology                              |
|             - 3 Competing Approach Links: B1 (Avinashi Rd), B2 (Airport Rd), B3 (Trichy Bypass)       |
|             - 1 Downstream Merged Bottleneck Link: B4 (Avinashi Egress, c4 = 0.45 veh/s, Qmax = 15)   |
|             - Precision Ceramic Storage Capacitors (C1 to C4) integrating KCL current charge          |
+-------------------------------------------------------------------------------------------------------+
```

---

## 🔬 Dual-Track Simulation Infrastructure

Project SITRA provides two fully validated simulation tracks to serve both theoretical algorithm benchmarking and physical power electronics verification:

```
+-------------------------------------------------------------------------------------------------------+
|                                      DUAL SIMULATION TRACKS                                           |
+-------------------------------------------------------------------------------------------------------+
                                                  |
         +----------------------------------------+----------------------------------------+
         |                                                                                 |
         v                                                                                 v
+---------------------------------------------------+   +---------------------------------------------------+
|    TRACK 1: MATHEMATICAL EQUIVALENT BENCHMARK     |   |      TRACK 2: REAL PHYSICAL SIMSCAPE CIRCUIT      |
|   (Simulink State-Space & 9-Stage Architecture)   |   |   (Simscape Foundation Electrical fl_lib/ee_lib)  |
+---------------------------------------------------+   +---------------------------------------------------+
| • Primary Model:                                  |   | • Primary Model:                                  |
|   SITRA_S2_test_ControllerCompare.slx             |   |   SITRA_S5_Physical.slx                           |
| • Features:                                       |   | • Features:                                       |
|   - 4-Controller multiport runtime switch         |   |   - True physical conserving ports (LConn/RConn)  |
|   - Cleaned wiring layout & zero dangling lines   |   |   - 100% pure Simscape blocks (zero MATLAB code)  |
|   - Microsecond dead-time testbench (5.0 us)      |   |   - 230V AC mains to 24V buck power supply        |
|   - Automated port validator:                     |   |   - Physical IRF540N MOSFET switches              |
|     fix_all_model_connections.m                   |   |   - 1 uF precision ceramic capacitor storage      |
|   - Conservation residual: < 1.42e-15 A           |   |   - Sub-microvolt queue tracking: < 8.0 uV error  |
|   - Model file: SITRA_Deadtime_Testbench.slx      |   |   - Regulated bus: 23.98 V (+/- 15 mV ripple)     |
+---------------------------------------------------+   +---------------------------------------------------+
```

---

## 🎮 Multi-Controller Comparison

We systematically evaluate and cross-benchmark four foundational traffic control strategies:

1. **SITRA Model Predictive Control (MPC)**:
   - Formulates traffic control as an online constrained quadratic program over a 5-step receding horizon ($N_p = 5\,\text{s}$).
   - Minimizes queue imbalances with state penalty $\mathbf{W}_q = \text{diag}([1.0, 1.2, 0.8, 1.5])$, switching cost $\mathbf{W}_u = 0.5 \cdot \mathbf{I}$, and terminal weight $\mathbf{W}_f = 2 \cdot \mathbf{W}_q$.
   - Enforces minimum green bounds ($g_{\min} = 5.0\,\text{s}$) to prevent phase chattering.
2. **Webster Optimal Fixed-Time Equisaturation (1958)**:
   - Classic analytical delay-minimization benchmark using saturation flow ratios $y_i = d_i / c_i$ and total lost time $L = 12.0\,\text{s}$.
   - Optimal cycle length: $C_0 = (1.5L + 5) / (1 - Y) = 54.0\,\text{s}$; green splits: $g_1 = 20.0\,\text{s}, g_2 = 14.0\,\text{s}, g_3 = 8.0\,\text{s}$.
3. **NEMA Vehicle-Actuated Dynamic Gap-Out Control**:
   - Industry-standard presence detector control using passage gap-out threshold $U_e = 3.0\,\text{s}$ and max green caps ($g_{\max} = 45.0\,\text{s}$).
   - Dynamically extends green for active platoons and gaps out immediately when empty.
4. **Decentralized Feedback MaxPressure Control**:
   - Varaiya-style gradient pressure routing: actuates phase with maximum pressure differential $w_i(k) \cdot c_i = [q_i(k) - q_4(k)] \cdot c_i$.
   - Stabilizes network queues without requiring arrival rate forecasts.

---

## ⏱️ The Non-Circular Twin-Run Clearance Metric

Conventional clearance metrics evaluate raw queue lengths against an arbitrary fixed threshold ($q(t) \le Q_{\text{base}} + 1\,\text{veh}$). In real traffic, this metric fails catastrophically because:
1. Raw queues naturally oscillate by several vehicles every cycle during normal red/green phases.
2. Post-congestion demand often settles at a moderate level, making it mathematically impossible for the raw queue to drop back to the pre-congestion low level.

### The Twin-Run Solution
We introduce the **Twin-Run Clearance Metric** (`bl_clearance.m`):
For every scenario $(s)$, controller $(m)$, and random seed $(\omega)$, two parallel simulations are executed:
- **Event Run ($q_{\text{event}}(t)$)**: Subjected to the disturbance (surge, incident, blockage).
- **Twin Run ($q_{\text{twin}}(t)$)**: Identical background traffic arrivals and seed $\omega$, but with the disturbance completely removed.

The **instantaneous excess queue** is:
$$\Delta q(t) = \max\left( 0, \, q_{\text{event}}(t) - q_{\text{twin}}(t) \right)$$

Clearance is achieved when $\Delta q(t)$ drops below $\delta = 1.0\,\text{veh}$ and holds continuously for $H = 60.0\,\text{s}$:
$$t_{\text{clear}} = \min \left\{ \tau \ge t_{\text{event}} \;\middle|\; \Delta q(t) \le 1.0\,\text{veh}, \; \forall t \in [\tau, \tau + 60\,\text{s}] \right\} - t_{\text{event}}$$

Cumulative excess delay is evaluated as:
$$\mathcal{E} = \int_{t_{\text{event}}}^{T_{\text{sim}}} \Delta q(t) \, dt \quad [\text{veh}\cdot\text{s}]$$

---

## 🧪 14-Scenario Experimental Taxonomy (T1 to T14)

The platform evaluates 14 exhaustive operational scenarios spanning four critical cyber-physical tiers:

| Tier | ID | Scenario Name | Disturbance Mechanics | Investigation Objective ("Why & What") |
| :---: | :---: | :--- | :--- | :--- |
| **I. Nominal** | **T1** | Low Demand Flow | $d = [0.05, 0.04, 0.03]\,\text{veh/s}$ ($v/c \approx 0.15$) | Validate free-flow stability and conservation laws without queue build-up |
| | **T2** | Moderate Equilibrium | $d = [0.10, 0.08, 0.06]\,\text{veh/s}$ ($v/c \approx 0.57$) | Establish nominal baseline operating delay, throughput, and phase splits |
| | **T3** | High Near-Saturation | $d = [0.15, 0.12, 0.09]\,\text{veh/s}$ ($v/c \approx 0.85$) | Evaluate queue formation dynamics as intersection approaches capacity |
| | **T4** | Oversaturated Jam | $d = [0.20, 0.16, 0.12]\,\text{veh/s}$ ($v/c \approx 1.14$) | Evaluate monotonic queue growth rates under structural capacity deficit |
| **II. Clearance** | **T5** | Step Demand Transition | Step to $0.18$ at $300\,\text{s}$; step down to $0.10$ at $600\,\text{s}$ | Measure post-surge queue shedding latency following permanent demand shifts |
| | **T6** | Deterministic Peak Surge | B1 demand pulses to $0.25\,\text{veh/s}$ for $t \in [100, 280]\,\text{s}$ | Benchmark baseline clearance time under standard 3-minute peak surge pulse |
| | **T7** | Stochastic Poisson Surge | Modulated Poisson arrivals over T6 surge (5 random seeds) | Assess clearance robustness under cycle-to-cycle stochastic arrival variance |
| | **T8** | Congested Start Recovery | Initial queue $q_0 = [25.0, 15.0, 12.0, 0.0]^\top\,\text{veh}$ | Quantify emergency gridlock evacuation time from a pre-existing 52-veh jam |
| **III. Disturbance**| **T9** | Upstream B1 Incident | $c_1$ drops $50\%$ ($0.65 \to 0.325$) for $t \in [200, 500]\,\text{s}$ | Simulate vehicle breakdown/lane closure; test capacity throttle response |
| | **T10** | Downstream B4 Blockage | $c_4$ throttled $80\%$ ($0.45 \to 0.09$) for $t \in [300, 600]\,\text{s}$ | Evaluate spill-back awareness and upstream gating when egress is jammed |
| | **T11** | Coordinated Platoon Wave | $5\,\text{veh}$ pulses every $30\,\text{s}$ on B2 for $t \in [250, 550]\,\text{s}$ | Stress-test transient shock buffering against incoming green-wave platoons |
| **IV. Hardware** | **T12** | Sensor Stuck-at-Zero | B1 sensor reports $0\,\text{veh}$ for $t \in [200, 500]\,\text{s}$ | Stress-test safety under blind detector blackout (loss of telemetry) |
| | **T13** | Gaussian Sensor Noise | $\mathcal{N}(0, \sigma^2)$ noise ($\sigma = 2.0\,\text{veh}$) on all sensors | Quantify controller degradation under noisy video/radar vehicle detectors |
| | **T14** | Signal Head Actuator Fail| B3 signal stuck dark ($u_3 = 0$) for $t \in [300, 600]\,\text{s}$ | Evaluate fail-safe behavior when physical lamp driver circuit burns out |

---

## 📊 Key Empirical Results & Physical Validation

### 1. Transient Congestion Clearance Benchmark (Scenarios T5 to T8)
Averaged across 5 stochastic simulation seeds:

| Scenario | Metric | SITRA MPC | Webster (Fixed) | Actuated (NEMA) | MaxPressure | Best Performer |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: |
| **T5 Step demand** | Clearance Time $t_{\text{clear}}$ [s] | **$76.0\text{ s}$** ($\pm 0.0$) | Not Cleared | $131.7\text{ s}$ ($\pm 62.0$) | $117.0\text{ s}$ ($\pm 0.0$) | **SITRA MPC** |
| | Excess Delay [$\text{veh}\cdot\text{s}$] | $2,662.5$ | $2,927.4$ | **$1,332.7$** | $3,176.7$ | Actuated |
| **T6 Surge (Det)** | Clearance Time $t_{\text{clear}}$ [s] | **$106.0\text{ s}$** | Not Cleared | **$63.0\text{ s}$** | Not Cleared | **Actuated** |
| | Excess Delay [$\text{veh}\cdot\text{s}$] | $305.6$ | $1,867.2$ | **$181.4$** | $412.0$ | Actuated |
| **T7 Surge (Poisson)**| Clearance Time $t_{\text{clear}}$ [s] | $113.5\text{ s}$ ($\pm 20.5$) | $50.0\text{ s}$ ($\pm 0.0$) | **$82.5\text{ s}$** ($\pm 32.9$) | Not Cleared | Webster / Actuated |
| | Excess Delay [$\text{veh}\cdot\text{s}$] | $947.5$ | $1,756.8$ | **$405.6$** | $764.6$ | Actuated |
| **T8 Congested start**| Clearance Time $t_{\text{clear}}$ [s] | $643.8\text{ s}$ ($\pm 205.1$) | $522.5\text{ s}$ ($\pm 195.9$) | **$484.4\text{ s}$** ($\pm 117.3$) | $736.0\text{ s}$ ($\pm 125.9$) | **Actuated** |
| | Excess Delay [$\text{veh}\cdot\text{s}$] | $10,971.9$ | $12,951.1$ | **$7,816.6$** | $11,233.1$ | Actuated |

### 2. Critical Behavioral Discovery: The Actuated Noise Collapse
A pivotal finding of this project is that **the fastest controller under ideal conditions is not the most resilient controller under real-world noise**:
- Under nominal surge T6, Actuated clears in $63.0\,\text{s}$ by greedily extending green.
- Under **Gaussian sensor noise** ($\sigma = 2.0\,\text{veh}$, Scenario T13), **Actuated control catastrophically collapses**: clearance time explodes to **$424.25\,\text{s}$**—a **$23.3\times$ degradation**—while excess delay surges to **$2,190.21\,\text{veh}\cdot\text{s}$**. Noise spikes trigger false green extensions of empty phases and premature gap-outs of congested phases.
- In sharp contrast, **SITRA MPC maintains robust clearance in $56.60\,\text{s}$** ($93.97\,\text{veh}\cdot\text{s}$ excess delay). MPC's quadratic optimization and receding prediction horizon act as an inherent low-pass filter that rejects telemetry noise.

### 3. Physical Circuit Tracking Fidelity (`SITRA_S5_Physical.slx`)
Across 32 physical Simscape runs replaying controller gate commands:
- **Zero Temporal Discrepancy**: Physical circuit clearance times match mathematical model clearance times to the exact integer second ($\Delta t_{\text{clear}} \equiv 0.00\,\text{s}$).
- **Sub-Microvolt Precision**: Maximum voltage tracking error $|V_C(t) - q(t)| < 8.0\,\mu\text{V}$ ($8.0 \times 10^{-6}\,\text{V}$).
- **Bus Stability**: Regulated auxiliary 24 V DC bus maintained ripple under $15.0\,\text{mV}$ across all switching transients.

---

## 🔌 Power Electronics Non-Idealities & Thermal Safety

1. **Capacitor Equivalent Series Resistance (ESR, Stage S6)**:
   - Parasitic ESR ($R_{\text{ESR}} = 50\,\text{m}\Omega$) induces internal ohmic drop $V_{\text{drop}} = I \cdot R_{\text{ESR}} = \pm 15.0\,\text{mV}$ during heavy switching.
   - An active feedforward compensator ($V_{\text{comp}} = V_{\text{term}} - I \cdot \hat{R}_{\text{ESR}}$) suppresses terminal ripple to **$< 0.1\,\text{mV}$**, preserving sub-millivolt queue telemetry fidelity.
2. **Power MOSFET Thermal Equilibrium (Stage S7)**:
   - Total dissipation per switch: $P_{\text{total}} = P_{\text{cond}} (38.4\,\text{mW}) + P_{\text{sw}} (6.8\,\text{mW}) = 45.2\,\text{mW}$.
   - Under natural convection ($R_{\theta,ja} = 62.0\,^\circ\text{C/W}$), steady-state junction temperature rise is $\Delta T_j = +2.80\,^\circ\text{C}$.
   - Operating junction temperature reaches **$T_j = 27.80\,^\circ\text{C}$** at $25^\circ\text{C}$ ambient—operating with an extraordinary **safety margin exceeding $140^\circ\text{C}$** below the $175^\circ\text{C}$ semiconductor limit.

---

## 📁 Repository Organization & File Guide

```
├── run_master_all.m               # Unified master runner (Mode 1: All, Mode 2: Track 1, Mode 3: Track 2)
├── run_part_b.m                   # Part B: KCL electrical conservation test runner (< 1.42e-15 A residual)
├── run_part_c.m                   # Part C: Microsecond dead-time test runner (5.0 us interlock)
├── run_part_d_integrated.m        # Part D: Four-controller integrated validation runner (100% S9 pass)
├── fix_all_model_connections.m    # Automated model repair: eliminates all dangling lines & ports
├── upgrade_electrical_subsystems.m # Automated subsystem 05, 06, 09 upgrade script
├── SITRA_Deadtime_Testbench.slx   # Microsecond dead-time interlock verification model
├── SITRA_S2_test_ControllerCompare.slx # Track 1: 4-Controller comparison Simulink model
├── SITRA_Simscape_Hardware.slx    # Dedicated hardware emulation model
│
├── Report/                        # Full publication suite & research reports
│   ├── SITRA_IEEE_Journal_Paper.docx # Definitive IEEE Transactions Journal Paper (12.5k words)
│   ├── SITRA_IEEE_Journal_Paper.md   # Source markdown of the IEEE Journal Paper
│   ├── SITRA_Research_Report.docx    # Complete 34k-word engineering research report
│   ├── SITRA_Research_Report.md      # Source markdown of research report
│   ├── figures/                      # High-resolution 300 DPI figures
│   │   ├── fig_ieee_project_flowchart.png       # 8-Stage engineering methodology flowchart
│   │   ├── fig_ieee_five_layer_architecture.png # Five-layer cyber-physical architecture
│   │   ├── fig_ieee_dual_domain_schematic.png   # Dual-domain circuit schematic
│   │   ├── fig_ieee_power_flow.png              # 230V AC to 24V DC power distribution network
│   │   ├── fig_site_map.png                     # SITRA Junction OpenStreetMap layout
│   │   └── fig01 to fig38                       # All 38 evaluation & validation figures
│   ├── generate_ieee_flowcharts.py   # Script to regenerate vector flowcharts at 300 DPI
│   └── generate_ieee_manuscript.py   # Script to recompile IEEE manuscript to DOCX
│
├── Results/                       # Validation MAT files, CSVs, and waveform plots
│   ├── S6_S7/                     # S6 ESR compensation & S7 thermal loss data
│   ├── PartC_Deadtime_Validation/ # 5 us gate switching waveforms
│   ├── PartD_Integrated_Validation/ # Controller comparison CSVs & metrics
│   ├── S5_physical/               # Physical Simscape replay clearance data (32 runs)
│   └── T6_Simulink_Exports/       # Controller phase actuation histories
│
├── SITRA_Project/
│   ├── SITRA_Final_Technical_Report.md # Extended technical report
│   └── SITRA_PROJECT_BUILD_FLAT_COMPLETE/
│       ├── S5_physical/           # Track 2: Pure Simscape physical circuit implementation
│       │   ├── SITRA_S5_Physical.slx     # Physical Simscape circuit model
│       │   ├── build_SITRA_S5_Physical.m # Script-driven Simscape model builder
│       │   ├── test_SITRA_S5_Physical.m  # Acceptance test suite
│       │   ├── run_controllers_on_S5_physical.m # 32-run physical clearance replayer
│       │   └── SIZING_NOTE_S12.md        # Hardware BOM & candidate specifications
│       ├── S6_S7_parasitics/      # Capacitor ESR & MOSFET thermal dynamics suite
│       │   ├── test_stage6_parasitics.m  # S6 ESR testbench
│       │   ├── test_stage7_semiconductors.m # S7 thermal testbench
│       │   └── run_all_S6_S7.m           # S6/S7 master runner
│       ├── baselines/             # Multi-controller baseline harness & metrics
│       │   ├── bl_clearance.m     # Non-circular Twin-Run Clearance Metric
│       │   ├── bl_inject.m        # General congestion, disturbance & fault injector
│       │   ├── bl_ctrl_sitra.m    # SITRA Receding-Horizon MPC controller
│       │   ├── bl_ctrl_webster.m  # Webster optimal fixed-time controller
│       │   ├── bl_ctrl_actuated.m # NEMA vehicle-actuated controller
│       │   ├── bl_ctrl_maxpressure.m # Decentralized MaxPressure controller
│       │   └── run_baseline_comparison.m # Master baseline benchmark runner
│       └── BUILD_LOG.md           # Master verification ledger & test audit trail
│
├── src/                           # Interactive React 19 + Tailwind v4 Web Research Platform
│   ├── App.tsx                    # Master web application component tree
│   ├── data.ts                    # Research formulas, dataset records & BOM
│   └── main.tsx                   # React entrypoint
└── package.json                   # Web platform configuration & dependencies
```

---

## 🚀 How to Run Simulations

### Prerequisites
- **MATLAB R2024b or newer**
- **Simulink**
- **Simscape** & **Simscape Electrical**

### 1. Complete Unified Master Execution
Open MATLAB, set the current directory to the repository root, and run:
```matlab
% Launches the unified master runner (prompts for Mode 1: All, Mode 2: Track 1, Mode 3: Track 2):
run_master_all;
```

### 2. Targeted Subsystem Validation
```matlab
% Track 1: Verify 4-controller integration & S9 validation gate (100% PASS):
run_part_d_integrated;

% Track 1: Verify 5.0 us gate dead-time interlock protection:
run_part_c;

% Track 1: Automated model wiring check & dangling line repair:
fix_all_model_connections;

% Track 2: Test pure Simscape physical circuit (SITRA_S5_Physical.slx):
cd('SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/S5_physical');
test_SITRA_S5_Physical;

% Track 2: Replay 32 controller runs through Simscape physical circuit:
run_controllers_on_S5_physical;

% Track 2: Validate capacitor ESR compensation & MOSFET thermal rise:
cd('../S6_S7_parasitics');
run_all_S6_S7;

% Run comprehensive 14-scenario baseline clearance comparison (T1 to T14):
cd('../baselines');
run_baseline_comparison;
```

### 3. Running the Interactive Web Research Platform
```bash
# Install packages
pnpm install

# Start Vite local development server
pnpm dev
```
Open [http://localhost:8443](http://localhost:8443) to explore the interactive visualizer.

---

## 📖 Publications & Research Documents

1. **Definitive IEEE Transactions Journal Paper**:
   - Word Document: [`Report/SITRA_IEEE_Journal_Paper.docx`](Report/SITRA_IEEE_Journal_Paper.docx)
   - Source Markdown: [`Report/SITRA_IEEE_Journal_Paper.md`](Report/SITRA_IEEE_Journal_Paper.md)  
   *Title: "Cyber-Physical Dual-Domain Congestion Clearance and Closed-Loop Power Electronics Emulation of Urban Traffic Intersections"*
2. **Comprehensive Research Report**:
   - Word Document: [`Report/SITRA_Research_Report.docx`](Report/SITRA_Research_Report.docx)
   - Source Markdown: [`Report/SITRA_Research_Report.md`](Report/SITRA_Research_Report.md)
3. **Engineering Reference & Verification Ledgers**:
   - Hardware Sizing Rationale (BOM): [`SIZING_NOTE_S12.md`](SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/S5_physical/SIZING_NOTE_S12.md)
   - Master Verification Ledger: [`BUILD_LOG.md`](SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/BUILD_LOG.md)

---

## 👥 Contributors & Acknowledgments

Project SITRA is developed through the collaborative engineering efforts of:

- **Sreedev C. (@sreedev / Sree)** — *Core Architect & Research Contributor*
  - Co-architect of the Dual-Domain Mathematical Equivalence Framework.
  - Lead developer of the 9-stage multi-controller comparison testbench (`SITRA_S2_test_ControllerCompare.slx`).
  - Creator of the automated model wiring and port validation tool (`fix_all_model_connections.m`), eliminating all dangling lines and unconnected ports across Simulink models.
  - Author of the multi-controller performance integration suites (Parts A, B, C, D) and electrical conservation testbenches.
  - Co-author of the IEEE research paper drafts and contributor to the publication figure suite.

- **Sai (@siddu1004 / Sai)** — *Core Architect & Research Contributor*
  - Architect of the authentic Simscape physical circuit (`SITRA_S5_Physical.slx`), 230 V AC / 24 V DC closed-loop buck power supply, and physical hardware component selection (Stage S12).
  - Formulator of the non-circular Twin-Run Clearance Metric (`bl_clearance.m`) and general disturbance/fault injector (`bl_inject.m`) across Scenarios T1–T14.
  - Lead author of the comprehensive IEEE Transactions Journal Paper (`Report/SITRA_IEEE_Journal_Paper.docx`).
  - Creator of the 300 DPI vector flowcharts, dual-domain circuit schematics, and physical replay validation testbenches.

---

## ⚖️ Citation

If you utilize Project SITRA, its dual-domain electrical models, or the Twin-Run Clearance Metric in your research, please cite:

```bibtex
@article{sitra2026dualdomain,
  title={Cyber-Physical Dual-Domain Congestion Clearance and Closed-Loop Power Electronics Emulation of Urban Traffic Intersections},
  author={Sreedev, C. and Sai and Consortium, Antigravity Cyber-Physical Transportation},
  journal={IEEE Transactions on Intelligent Transportation Systems (Draft)},
  year={2026},
  url={https://github.com/siddu1004/power_systems_electronic_circuit_design_of_traffic_systems}
}
```
