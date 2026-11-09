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

A central question in urban traffic control and power-analogous congestion relief is: **after peak congestion builds up, how quickly does each controller restore the network to normal queue levels?**

We evaluated all four controllers across four challenging scenarios:
1. **T5 Step demand**: high demand ($600\text{ s}$ overload) step-down.
2. **T6 Part 8 surge (deterministic)**: sharp surge during $t \in [200, 400]\text{ s}$.
3. **T7 Part 8 surge (Poisson)**: stochastic surge arrivals.
4. **T8 Congested start (queue drain)**: initial network queue $q_0 = [25, 15, 10, 0]\text{ veh}$ ($50\text{ veh}$ total) draining under moderate demand.

### 1. Physical Circuit Verification (`SITRA_S5_Physical.slx`)
In `run_controllers_on_S5_physical.m`, the gate trajectories from all 4 controllers were executed directly across the real physical Simscape circuit with physical conserving ports and capacitor dynamics.
> [!NOTE]
> **Experiment Scope**: The physical circuit experiment validates the dynamic electrical equivalence by replaying the controller-generated gate switching signals into the true Simscape physical model (Layer A: physical capacitors, controlled sources, and diode-isolated links; Layer B: regulated power supply). The measured capacitor voltages $v_C$ track the queue state down to $< 3.5\,\mu\text{V}$ ($< 3.5 \times 10^{-6}\text{ V}$), verifying sub-millivolt equivalence. True online MPC feedback operating directly inside continuous-time Simscape solvers without discrete step delays remains an area of ongoing work.

| Scenario | Controller | Clearance Time $t_{\text{clear}}$ [s] | Circuit vs Model Discrepancy [s] | Max Circuit Voltage Error $|v_C - q_{\text{ref}}|$ | Total Excess Queue [$\text{veh}\cdot\text{s}$] | Peak Approach Queue [veh] |
|:---|:---|:---:|:---:|:---:|:---:|:---:|
| **T5 Step demand** | **Actuated** | Not Cleared | $0.0\text{ s}$ | $3.00 \times 10^{-6}\text{ V}$ | **$4,454.6$** | $32.50$ |
| | **SITRA MPC** | Not Cleared | $0.0\text{ s}$ | $2.50 \times 10^{-6}\text{ V}$ | **$6,848.5$** | $37.30$ |
| | **MaxPressure** | Not Cleared | $0.0\text{ s}$ | $3.00 \times 10^{-6}\text{ V}$ | **$7,272.1$** | $32.25$ |
| | **Webster** | Not Cleared | $0.0\text{ s}$ | $3.50 \times 10^{-6}\text{ V}$ | **$8,377.0$** | $39.60$ |
| **T6 Surge (Det)** | **Actuated** | Not Cleared | $0.0\text{ s}$ | $1.35 \times 10^{-6}\text{ V}$ | **$166.8$** | $13.74$ |
| | **SITRA MPC** | Not Cleared | $0.0\text{ s}$ | $1.30 \times 10^{-6}\text{ V}$ | **$364.4$** | $14.79$ |
| | **MaxPressure** | Not Cleared | $0.0\text{ s}$ | $1.50 \times 10^{-6}\text{ V}$ | **$389.0$** | $11.24$ |
| | **Webster** | Not Cleared | $0.0\text{ s}$ | $1.40 \times 10^{-6}\text{ V}$ | **$1,756.0$** | $24.12$ |
| **T7 Surge (Poisson)** | **Actuated** | Not Cleared | $0.0\text{ s}$ | $2.85 \times 10^{-6}\text{ V}$ | **$248.6$** | $11.35$ |
| | **SITRA MPC** | Not Cleared | $0.0\text{ s}$ | $3.00 \times 10^{-6}\text{ V}$ | **$275.4$** | $11.75$ |
| | **Webster** | Not Cleared | $0.0\text{ s}$ | $2.60 \times 10^{-6}\text{ V}$ | **$476.7$** | $15.05$ |
| | **MaxPressure** | Not Cleared | $0.0\text{ s}$ | $2.55 \times 10^{-6}\text{ V}$ | **$516.8$** | $9.15$ |
| **T8 Congested start** | **Actuated** | **$611.0\text{ s}$** | **$0.0\text{ s}$** | $2.45 \times 10^{-6}\text{ V}$ | **$10,405.0$** | $51.80$ |
| | **SITRA MPC** | **$641.0\text{ s}$** | **$0.0\text{ s}$** | $2.50 \times 10^{-6}\text{ V}$ | **$12,151.0$** | $51.80$ |
| | **MaxPressure** | **$641.0\text{ s}$** | **$0.0\text{ s}$** | $2.55 \times 10^{-6}\text{ V}$ | **$12,235.4$** | $51.80$ |
| | **Webster** | **$655.0\text{ s}$** | **$0.0\text{ s}$** | $2.50 \times 10^{-6}\text{ V}$ | **$14,318.0$** | $57.85$ |

*(Note on T5–T7: In cyclic signal operation where queues oscillate cyclically across green/red phases, the strict clearance threshold requires the queue to stay continuously $\le Q_{\text{base}} + 1.0\text{ veh}$ for $60\text{ s}$; because cyclic red phases introduce queue pulses, the continuous cumulative excess queue $[\text{veh}\cdot\text{s}]$ serves as the continuous clearing efficiency metric).*

### 2. Multi-Seed Stochastic Clearance Distribution (Scenario T8 across Seeds 101–105)
| Controller | Mean Clearance Time $t_{\text{clear}}$ [s] | Standard Deviation [s] | Cleared Runs Ratio | Rank |
|:---|:---:|:---:|:---:|:---:|
| **Actuated** | **$508.6\text{ s}$** | $\pm 142.7\text{ s}$ | $5 / 5\ (100\%)$ | **1** |
| **MaxPressure** | **$626.2\text{ s}$** | $\pm 181.4\text{ s}$ | $5 / 5\ (100\%)$ | **2** |
| **Webster** | **$672.2\text{ s}$** | $\pm 116.6\text{ s}$ | $5 / 5\ (100\%)$ | **3** |
| **SITRA MPC** | **$714.4\text{ s}$** | $\pm 77.8\text{ s}$ | $5 / 5\ (100\%)$ | **4** |

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
