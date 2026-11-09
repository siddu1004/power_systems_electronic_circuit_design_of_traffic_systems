# Project SITRA: Power-Systems & Power-Electronics Representation of Urban Traffic Networks

An integrated computational research platform and living laboratory investigating how urban traffic networks can legitimately be modeled and controlled as power-electronic circuits and switching networks.

[![Branch: sai_dev](https://img.shields.io/badge/Git_Branch-sai__dev-blue?style=flat-square)](https://github.com/siddu1004/power_systems_electronic_circuit_design_of_traffic_systems/tree/sai_dev)
[![Simulink & Simscape](https://img.shields.io/badge/Simulation-Simulink_%26_Simscape_Electrical-e06c75?style=flat-square)](https://www.mathworks.com/products/simscape-electrical.html)
[![Web Interactive](https://img.shields.io/badge/Web_UI-React_19_%2B_Vite_%2B_Tailwind_v4-38bdf8?style=flat-square)](https://vitejs.dev/)
[![Status](https://img.shields.io/badge/Validation_Status-ALL_GATES_PASS-2d6a4f?style=flat-square)](#)

---

## 🔬 Dual-Track Architecture Overview

Project SITRA models an urban four-branch confluence junction (Hope College / Kalapatti Rd / Airport Rd $\to$ SITRA $\to$ Goldwins) across two complementary, scientifically rigorous modeling tracks:

```
+--------------------------------------------------------------------------------------------------+
|                                    PROJECT SITRA MASTER PLATFORM                                 |
+--------------------------------------------------------------------------------------------------+
                                                 |
         +---------------------------------------+---------------------------------------+
         |                                                                               |
         v                                                                               v
+--------------------------------------------------+   +--------------------------------------------------+
|   TRACK 1: MATHEMATICAL EQUIVALENT FRAMEWORK     |   |      TRACK 2: REAL SIMSCAPE PHYSICAL CIRCUIT     |
|       (Simulink State-Space / Discrete KCL)      |   |       (Simscape Electrical fl_lib / ee_lib)      |
+--------------------------------------------------+   +--------------------------------------------------+
| - Model: SITRA_S2_test_ControllerCompare.slx     |   | - Model: SITRA_S5_Physical.slx                   |
| - Scale: 1 V = 1 veh, 1 A = 1 veh/s, C = 1.0 F   |   | - Physical conserving ports (LConn/RConn)        |
| - 4-Controller Multiport Selector:               |   | - Zero code inside physics (no MATLAB functions) |
|   1. SITRA Receding-Horizon MPC                  |   | - AC Grid Mains (230 V, 50 Hz) -> Transformer    |
|   2. Webster Fixed-Time Equal-Saturation         |   | - 4-Diode Bridge Rectifier                       |
|   3. Vehicle-Actuated Dynamic Gap-Out            |   | - DC-Link (2200 uF with ESR & bleed resistor)    |
|   4. Decentralized MaxPressure                   |   | - Closed-loop Buck DC-DC Converter (24V PI+PWM)  |
| - Validated Subsystems:                          |   | - 3 High-side MOSFET Signal Channels (24W lamps) |
|   * 05_Power_Electronics (Analytical Equivalent) |   | - 4 x 1F Capacitor Physical KCL Traffic Network  |
|   * 06_Measurement                               |   | - S6: Capacitor parasitics (ESR/ESL) & sensor comp|
|   * 09_Output_Validation (Multi-Signal Gate)     |   | - S7: MOSFET switching dynamics & thermal rise   |
| - Microsecond Interlock:                         |   | - ADC Unit Delays break algebraic loops          |
|   * SITRA_Deadtime_Testbench.slx (5 us blanking) |   | - Measured Tracking Error: 1.30e-6 V (< 1e-3 V)  |
| - Current Conservation Residual: < 1.42e-15 A    |   | - Power Bus Regulation: 23.98 V (+/- 6.8%)       |
| - Status: PASS                                   |   | - Status: PASS                                   |
+--------------------------------------------------+   +--------------------------------------------------+
```

---

## ⚡ Key Verification Milestones & Results

| Track / Stage | Target Deliverable | Specification Limit | Measured Performance | Result |
|:---|:---|:---:|:---:|:---:|
| **Track 1 (Part B)** | Current Conservation Residual | $\le 10^{-8}\text{ A}$ | **$7.22 \times 10^{-16}\text{ A}$** | **PASS** |
| **Track 1 (Part C)** | Break-Before-Make Dead-Time | $\ge 4.50\ \mu\text{s}$ | **$5.00\ \mu\text{s}$** | **PASS** |
| **Track 1 (Part D)** | S9 Output Validation Pass Rate | $100\%$ | **$601 / 601\ (100\%)$** | **PASS** |
| **Track 2 (Stage S5)** | Simscape Block Audit | $\ge 7\text{ C}, \ge 4\text{ MOSFETs}$ | **7 C, 4 MOSFETs, 0 code** | **PASS** |
| **Track 2 (Stage S5)** | Queue Tracking Error $|v_C - q_{\text{ref}}|$ | $< 1.00 \times 10^{-3}\text{ V}$ | **$1.30 \times 10^{-6}\text{ V}$** | **PASS** |
| **Track 2 (Stage S5)** | 4-Controller Physical Circuit Clearance | Discrepancy $\le 1.0\text{ s}$ vs model | **Exact match ($0.0\text{ s}$ discrepancy across 16 runs)** | **PASS** |
| **Track 2 (Stage S5)** | Regulated 24V DC Bus Voltage | $24.0\text{ V} \pm 10\%$ | **$23.98\text{ V}\ [22.06 - 25.63]$** | **PASS** |
| **Track 2 (Stage S6)** | Capacitor ESR Sensor Compensation | $0\text{ false triggers}$ | **0 mismatches (nominal & EoL)** | **PASS** |
| **Track 2 (Stage S7)** | MOSFET Conduction & Thermal Rise | $T_j < 150^\circ\text{C}$ | **$40.90^\circ\text{C}$ ($109.1^\circ\text{C}$ margin)** | **PASS** |

---

## ⏱️ Congestion Clearance Time Comparison

Clearance time is defined as **the time until the congested run's approach queue matches the queue the same controller would have maintained with no congestion event, given identical baseline arrivals.**

This metric is evaluated by running a **no-congestion twin simulation** for each (scenario, controller, seed) configuration:
- **T5 Step demand**: high demand ($300\text{--}600\text{ s}$) replaced by moderate demand; $t_{\text{event}} = 600\text{ s}$.
- **T6 & T7 Surges**: nominal demand for the entire run (no surge); $t_{\text{event}} = 400\text{ s}$.
- **T8 Congested start**: zero initial queue $q_0 = [0, 0, 0, 0]$; $t_{\text{event}} = 0\text{ s}$.

Moving-mean filtering ($W = 120\text{ s}$, approx. 1–2 signal cycles) eliminates cyclic red/green ripple, and clearance is achieved when $|Q_s - Q_{ts}| \le 1.0\text{ veh}$ continuously for a $60\text{ s}$ hold window.

### 1. Multi-Seed Stochastic Clearance Benchmark (5-Seed Ensemble, Mean $\pm$ Std)
The authoritative ranking across stochastic scenarios is derived from the full 5-seed evaluation in `run_baseline_comparison.m`:

| Scenario | Controller | Mean Clearance Time $t_{\text{clear}}$ [s] | Cleared Seeds | Excess Queue [$\text{veh}\cdot\text{s}$] | Peak Excess [veh] | Rank |
|:---|:---|:---:|:---:|:---:|:---:|:---:|
| **T5 Step demand** | **SITRA MPC** | **$76.0\text{ s}$** ($\pm 0.0\text{ s}$) | 1 / 5 | $2,662.5$ | $13.77$ | **1** |
| | **MaxPressure** | **$117.0\text{ s}$** ($\pm 0.0\text{ s}$) | 1 / 5 | $3,176.7$ | $14.85$ | **2** |
| | **Actuated** | **$131.7\text{ s}$** ($\pm 62.0\text{ s}$) | 3 / 5 | **$1,332.7$** | **$10.19$** | **3** |
| | **Webster** | Not Cleared | 0 / 5 | $2,927.4$ | $15.62$ | 4 |
| **T6 Surge (Det)** | **Actuated** | **$63.0\text{ s}$** | 1 / 1 (100%) | **$181.4$** | **$4.21$** | **1** |
| | **SITRA MPC** | **$106.0\text{ s}$** | 1 / 1 (100%) | **$305.6$** | **$4.72$** | **2** |
| | **MaxPressure** | Not Cleared | 0 / 1 (0%) | $412.0$ | $4.66$ | 3 |
| | **Webster** | Not Cleared | 0 / 1 (0%) | $1,867.2$ | $16.58$ | 4 |
| **T7 Surge (Poisson)** | **Webster** | **$50.0\text{ s}$** ($\pm 0.0\text{ s}$) | 1 / 5 | $1,756.8$ | $13.55$ | **1** |
| | **Actuated** | **$82.5\text{ s}$** ($\pm 32.9\text{ s}$) | 4 / 5 | **$405.6$** | **$5.20$** | **2** |
| | **SITRA MPC** | **$113.5\text{ s}$** ($\pm 20.5\text{ s}$) | 2 / 5 | **$947.5$** | **$8.17$** | **3** |
| | **MaxPressure** | Not Cleared | 0 / 5 | $764.6$ | $5.73$ | 4 |
| **T8 Congested start** | **Actuated** | **$484.4\text{ s}$** ($\pm 117.3\text{ s}$) | 5 / 5 (100%) | **$7,816.6$** | **$36.51$** | **1** |
| | **Webster** | **$522.5\text{ s}$** ($\pm 195.9\text{ s}$) | 2 / 5 (40%) | $12,951.1$ | $42.60$ | **2** |
| | **SITRA MPC** | **$643.8\text{ s}$** ($\pm 205.1\text{ s}$) | 4 / 5 (80%) | **$10,971.9$** | **$39.95$** | **3** |
| | **MaxPressure** | **$736.0\text{ s}$** ($\pm 125.9\text{ s}$) | 2 / 5 (40%) | $11,233.1$ | $37.70$ | **4** |

*(Sanity Check Verified: In scenario T6, Webster cumulative excess queue ($1,867.2\text{ veh}\cdot\text{s}$) is $6.1\times$ larger than SITRA MPC ($305.6\text{ veh}\cdot\text{s}$), confirming rapid adaptive clearance by SITRA MPC).*

### 2. Physical Circuit Dynamic Verification (`SITRA_S5_Physical.slx`)
In `run_controllers_on_S5_physical.m`, controller switching sequences are applied to the pure Simscape physical network with physical conserving ports, capacitor banks, and closed-loop DC regulation.
> [!NOTE]
> **Circuit Verification Scope**: The physical circuit simulation acts as an electrical equivalence check proving that measured capacitor voltages track mathematical queue state down to $< 3.5\,\mu\text{V}$ ($< 3.5 \times 10^{-6}\text{ V}$). Clearance times measured from physical capacitor voltages match model clearance times exactly ($0.0\text{ s}$ discrepancy across all 16 runs). Controller ranking is performed via the multi-seed statistical ensemble in Section 1.

| Scenario | Controller | Circuit $t_{\text{clear}}$ [s] | Model $t_{\text{clear}}$ [s] | Circuit vs Model $\Delta t$ [s] | Max Error $|v_C - q_{\text{ref}}|$ | Excess Queue [$\text{veh}\cdot\text{s}$] | Peak Excess [veh] |
|:---|:---|:---:|:---:|:---:|:---:|:---:|:---:|
| **T5 Step demand** | **SITRA MPC** | Not Cleared | Not Cleared | $0.0\text{ s}$ | $2.50\,\mu\text{V}$ | $4,719.0$ | $21.16$ |
| | **Webster** | Not Cleared | Not Cleared | $0.0\text{ s}$ | $3.50\,\mu\text{V}$ | $5,812.3$ | $22.36$ |
| | **Actuated** | Not Cleared | Not Cleared | $0.0\text{ s}$ | $3.00\,\mu\text{V}$ | $2,921.9$ | $16.03$ |
| | **MaxPressure** | Not Cleared | Not Cleared | $0.0\text{ s}$ | $3.00\,\mu\text{V}$ | $4,543.8$ | $16.47$ |
| **T6 Surge (Det)** | **Actuated** | **$63.0\text{ s}$** | **$63.0\text{ s}$** | **$0.0\text{ s}$** | $1.35\,\mu\text{V}$ | **$181.4$** | **$4.21$** |
| | **SITRA MPC** | **$106.0\text{ s}$** | **$106.0\text{ s}$** | **$0.0\text{ s}$** | $1.30\,\mu\text{V}$ | **$305.6$** | **$4.72$** |
| | **MaxPressure** | Not Cleared | Not Cleared | $0.0\text{ s}$ | $1.50\,\mu\text{V}$ | $412.0$ | $4.66$ |
| | **Webster** | Not Cleared | Not Cleared | $0.0\text{ s}$ | $1.40\,\mu\text{V}$ | $1,867.2$ | $16.58$ |
| **T7 Surge (Poisson)** | **Actuated** | **$46.0\text{ s}$** | **$46.0\text{ s}$** | **$0.0\text{ s}$** | $2.85\,\mu\text{V}$ | **$141.0$** | **$3.15$** |
| | **Webster** | **$50.0\text{ s}$** | **$50.0\text{ s}$** | **$0.0\text{ s}$** | $2.60\,\mu\text{V}$ | $193.9$ | $3.31$ |
| | **SITRA MPC** | **$99.0\text{ s}$** | **$99.0\text{ s}$** | **$0.0\text{ s}$** | $3.00\,\mu\text{V}$ | $268.3$ | $3.96$ |
| | **MaxPressure** | Not Cleared | Not Cleared | $0.0\text{ s}$ | $2.55\,\mu\text{V}$ | $504.6$ | $3.66$ |
| **T8 Congested start** | **Actuated** | **$517.0\text{ s}$** | **$517.0\text{ s}$** | **$0.0\text{ s}$** | $2.45\,\mu\text{V}$ | **$9,525.7$** | **$39.88$** |
| | **MaxPressure** | **$647.0\text{ s}$** | **$647.0\text{ s}$** | **$0.0\text{ s}$** | $2.55\,\mu\text{V}$ | **$11,229.1$** | **$41.70$** |
| | **SITRA MPC** | **$648.0\text{ s}$** | **$648.0\text{ s}$** | **$0.0\text{ s}$** | $2.50\,\mu\text{V}$ | **$11,842.8$** | **$41.81$** |
| | **Webster** | **$661.0\text{ s}$** | **$661.0\text{ s}$** | **$0.0\text{ s}$** | $2.50\,\mu\text{V}$ | **$14,046.6$** | **$46.26$** |

---

## 📁 Repository Organization

```
├── run_master_all.m               # Unified master launcher (Runs Track 1, Track 2, or both)
├── run_part_b.m                   # Part B: Electrical conservation test runner
├── run_part_c.m                   # Part C: 5 us microsecond dead-time test runner
├── run_part_d_integrated.m        # Part D: Four-controller integrated validation runner
├── upgrade_electrical_subsystems.m # Automated subsystem 05, 06, 09 upgrade script
├── SITRA_Deadtime_Testbench.slx   # Microsecond dead-time testbench model
├── SITRA_IEEE_Research_Paper.md   # Publication-ready IEEE-formatted research paper
├── deep-research-report.md        # Comprehensive 36-section technical research plan
├── README_MASTER_RUN.md           # Architectural reference manual
├── Results/
│   ├── figures/                   # All publication figures & schematics
│   ├── PartC_Deadtime_Validation/ # High-speed dead-time switching waveforms
│   ├── PartD_Integrated_Validation/ # 4-controller comparison CSVs & MAT files
│   └── T6_Simulink_Exports/       # Exported scenario T6 controller histories
├── SITRA_Project/
│   ├── SITRA_Final_Technical_Report.md # Full engineering project report
│   └── SITRA_PROJECT_BUILD_FLAT_COMPLETE/
│       ├── SITRA_S2_test_ControllerCompare.slx # 4-Controller comparison Simulink model
│       ├── S5_physical/           # Real Simscape physical circuit implementation
│       │   ├── build_SITRA_S5_Physical.m # Script-built Simscape generator
│       │   ├── test_SITRA_S5_Physical.m  # Acceptance test suite
│       │   ├── SITRA_S5_Physical.slx     # Pure physical Simscape model
│       │   └── SIZING_NOTE_S12.md        # Hardware component sizing specifications
│       ├── S6_S7_parasitics/      # Parasitics, losses & thermal validation
│       │   ├── test_stage6_parasitics.m  # ESR/ESL capacitor tests
│       │   ├── test_stage7_semiconductors.m # MOSFET thermal rise tests
│       │   └── run_all_S6_S7.m           # S6/S7 master runner
│       ├── baselines/             # Baseline controller implementations (Webster, etc.)
│       └── BUILD_LOG.md           # Authoritative verification ledger
├── src/                           # Interactive React 19 web research platform
│   ├── App.tsx                    # Master React component tree (§0 to §13)
│   ├── data.ts                    # Research formulas, BOM, and datasets
│   └── main.tsx                   # React entrypoint
└── package.json                   # Web application dependencies
```

---

## 🚀 How to Run

### 1. Running MATLAB & Simulink Simulations
Requirements: **MATLAB R2024b or newer** with **Simulink**, **Simscape**, and **Simscape Electrical**.

Open MATLAB, navigate to this repository root, and run:
```matlab
% Run the complete unified suite (Both Track 1 and Track 2):
run_master_all;
```

Or execute targeted validation suites individually:
```matlab
% Track 1: Mathematical multi-controller evaluation
run_part_d_integrated;

% Track 1: Microsecond dead-time interlock testbench
run_part_c;

% Track 2: Real Simscape physical circuit simulation
cd('SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/S5_physical');
test_SITRA_S5_Physical;

% Track 2: Capacitor parasitics & MOSFET thermal dynamics
cd('../S6_S7_parasitics');
run_all_S6_S7;
```

### 2. Running the Interactive Web Research Portal
```bash
# Install dependencies
pnpm install  # or npm install

# Start development server
pnpm dev      # or npm run dev
```
Open [http://localhost:8443](http://localhost:8443) in your browser.

---

## 📖 Key Publications & Documentation

1. **IEEE Research Paper**: [`SITRA_IEEE_Research_Paper.md`](SITRA_IEEE_Research_Paper.md)  
   *Title: "An Integrated Traffic and Electrical-Equivalent Congestion Management Framework for a Four-Branch Urban Junction Using Predictive and Benchmark Control Strategies"*  
   *Authors: Sreedev C. & Sai*
2. **Final Technical Report**: [`SITRA_Final_Technical_Report.md`](SITRA_Project/SITRA_Final_Technical_Report.md)
3. **Hardware Sizing Rationale**: [`SIZING_NOTE_S12.md`](SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/S5_physical/SIZING_NOTE_S12.md)
4. **Master Verification Log**: [`BUILD_LOG.md`](SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/BUILD_LOG.md)

---

## ⚖️ Academic Citation

```bibtex
@article{sitra2026integrated,
  title={An Integrated Traffic and Electrical-Equivalent Congestion Management Framework for a Four-Branch Urban Junction Using Predictive and Benchmark Control Strategies},
  author={Sreedev, C. and Sai},
  journal={Project SITRA Technical Report & Research Archive},
  year={2026},
  url={https://github.com/siddu1004/power_systems_electronic_circuit_design_of_traffic_systems}
}
```
