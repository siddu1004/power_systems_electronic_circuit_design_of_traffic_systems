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
| **Track 2 (Stage S5)** | Regulated 24V DC Bus Voltage | $24.0\text{ V} \pm 10\%$ | **$23.98\text{ V}\ [22.06 - 25.63]$** | **PASS** |
| **Track 2 (Stage S6)** | Capacitor ESR Sensor Compensation | $0\text{ false triggers}$ | **0 mismatches (nominal & EoL)** | **PASS** |
| **Track 2 (Stage S7)** | MOSFET Conduction & Thermal Rise | $T_j < 150^\circ\text{C}$ | **$40.90^\circ\text{C}$ ($109.1^\circ\text{C}$ margin)** | **PASS** |

---

## 📁 Repository Organization

```
├── run_master_all.m               # Unified master launcher (Runs Track 1, Track 2, or both)
├── run_part_b.m                   # Part B: Electrical conservation test runner
├── run_part_c.m                   # Part C: 5 us microsecond dead-time test runner
├── run_part_d_integrated.m        # Part D: Four-controller integrated validation runner
├── upgrade_electrical_subsystems.m # Automated subsystem 05, 06, 09 upgrade script
├── SITRA_Deadtime_Testbench.slx   # Microsecond dead-time testbench model
├── SITRA_S2_test_ControllerCompare.slx # 4-Controller comparison Simulink model
├── SITRA_IEEE_Research_Paper.md   # Publication-ready IEEE-formatted research paper
├── deep-research-report.md        # Comprehensive 36-section technical research plan
├── README_MASTER_RUN.md           # Architectural reference manual
├── Results/
│   ├── figures/                   # All 12 publication figures & schematics
│   ├── PartC_Deadtime_Validation/ # High-speed dead-time switching waveforms
│   ├── PartD_Integrated_Validation/ # 4-controller comparison CSVs & MAT files
│   └── T6_Simulink_Exports/       # Exported scenario T6 controller histories
├── SITRA_Project/
│   ├── SITRA_Final_Technical_Report.md # Full engineering project report
│   └── SITRA_PROJECT_BUILD_FLAT_COMPLETE/
│       ├── S5_physical/           # Real Simscape physical circuit implementation
│       │   ├── build_SITRA_S5_Physical.m # Script-built Simscape generator
│       │   ├── test_SITRA_S5_Physical.m  # Acceptance test suite
│       │   └── SITRA_S5_Physical.slx     # Pure physical Simscape model
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

1. **IEEE Research Paper**: [`SITRA_IEEE_Research_Paper.md`](file:///c:/Users/saisi/Downloads/SITRA_Project/SITRA_IEEE_Research_Paper.md)  
   *Title: "An Integrated Traffic and Electrical-Equivalent Congestion Management Framework for a Four-Branch Urban Junction Using Predictive and Benchmark Control Strategies"*  
   *Authors: Sreedev C. & Sai*
2. **Final Technical Report**: [`SITRA_Final_Technical_Report.md`](file:///c:/Users/saisi/Downloads/SITRA_Project/SITRA_Project/SITRA_Final_Technical_Report.md)
3. **Hardware Sizing Rationale**: [`SIZING_NOTE_S12.md`](file:///c:/Users/saisi/Downloads/SITRA_Project/SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/S5_electrical/SIZING_NOTE_S12.md)
4. **Master Verification Log**: [`BUILD_LOG.md`](file:///c:/Users/saisi/Downloads/SITRA_Project/SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/BUILD_LOG.md)

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
