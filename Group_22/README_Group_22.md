# AMRITA VISHWA VIDYAPEETHAM
## SCHOOL OF ENGINEERING, COIMBATORE
### DEPARTMENT OF ELECTRICAL AND ELECTRONICS ENGINEERING

---

# PROJECT SUBMISSION DOSSIER: GROUP 22

**Course Project**: Power Systems & Power Electronics Representation of Urban Traffic Systems (Project SITRA)  
**Faculty Evaluator**: **Dr. S. Sampath Kumar** (Department of EEE)  
**Submission Portal**: [Amrita SharePoint Evaluation Folder](https://amritavishwavidyapeetham-my.sharepoint.com/:f:/g/personal/s_sampathkumar_cb_amrita_edu/IgAK4dvf6TUlTKKTGJSpx1OLAXrJC_bJiNnfLnpgnP1RPHk?e=ytyGOd)  
**Date of Submission**: November 10, 2026  

---

## 👥 Student Team Information (Group 22)

| S.No | Student Full Name | Amrita Roll Number | Branch & Section | Institutional Email ID |
| :---: | :--- | :---: | :---: | :--- |
| **1** | **Sreedev C.** | `CB.EN.U4EEE24142` | B.Tech EEE | `cb.en.u4eee24142@cb.students.amrita.edu` |
| **2** | **Vanguri Satya Sai Siddardh** | `CB.EN.U4EEE24152` | B.Tech EEE | `cb.en.u4eee24152@cb.students.amrita.edu` |
| **3** | **Vishal S.** | `CB.EN.U4EEE24155` | B.Tech EEE | `cb.en.u4eee24155@cb.students.amrita.edu` |

---

## 📑 Project Title & Abstract

### **"Cyber-Physical Dual-Domain Congestion Clearance and Closed-Loop Power Electronics Emulation of Urban Traffic Intersections"**

> **Executive Abstract**:  
> Urban traffic congestion has traditionally been analyzed using steady-state, time-averaged delay and Level of Service (LOS) metrics that obscure the transient recovery dynamics of signalized intersections during acute shockwaves. Furthermore, conventional traffic simulators treat vehicular queues in isolation from real-world electrical power distribution, actuator switching, and sensor degradation.  
> In this project, **Group 22** formulates and validates an exact mathematical isomorphism between hydraulic traffic queue dynamics and electrostatic charge conservation in analog power electronic circuits ($1\,\text{V} \equiv 1\,\text{veh}$, $1\,\text{A} \equiv 1\,\text{veh/s}$, $1\,\text{F} \equiv 1\,\text{s}$). We implement the physical analog of the four-phase SITRA Junction in Coimbatore, India, inside MathWorks Simscape Electrical, complete with a utility $230\,\text{V AC}$ to $24\,\text{V DC}$ auxiliary buck power supply, solid-state power MOSFET switching with $5\,\mu\text{s}$ interlocks, parasitic equivalent series resistance (ESR) compensation, and semiconductor junction thermal modeling.  
> To solve the cycle-oscillation and demand-shift artifacts of conventional metrics, we formulate a novel **Twin-Run Clearance Metric** that measures post-disturbance evacuation against an uncongested counterfactual baseline. Across 14 operational scenarios (T1–T14) and 32 physical Simscape runs, we benchmark Model Predictive Control (SITRA MPC), Webster Optimal Fixed-Time, NEMA Vehicle-Actuated Gap-Out, and Feedback MaxPressure controllers. We demonstrate sub-microvolt physical tracking ($< 8.0\,\mu\text{V}$), sub-15 mV DC bus regulation, and uncover a critical operational discovery: while Actuated control clears nominal deterministic surges fastest ($63.0\,\text{s}$ vs $106.0\,\text{s}$ for MPC), it catastrophically collapses under Gaussian sensor noise ($\sigma = 2.0\,\text{veh}$), taking $424.25\,\text{s}$ to clear ($23.3\times$ degradation), whereas SITRA MPC maintains robust, stable clearance ($56.60\,\text{s}$).

---

## 📁 Submission Folder Structure (`Group_22`)

```
Group_22/
│
├── README_Group_22.md                 # Complete submission overview & project documentation
├── README_Group_22.docx               # Formatted Word version of this submission dossier
│
├── 01_Reports_and_Documentation/      # Academic Research Papers and Technical Documentation
│   ├── SITRA_IEEE_Journal_Paper.docx  # PRIMARY DELIVERABLE: Complete IEEE Transactions Journal Paper (~12.5k words)
│   ├── SITRA_IEEE_Journal_Paper.md    # Source Markdown of the IEEE Journal Paper
│   ├── SITRA_Research_Report.docx     # Comprehensive 34k-word Engineering Research Report
│   ├── SITRA_Research_Report.md       # Source Markdown of the Research Report
│   ├── SITRA_Final_Technical_Report.md# Engineering Technical Specification Report
│   ├── SIZING_NOTE_S12.md             # Hardware Component Sizing Rationale & Candidate Part BOM
│   ├── BUILD_LOG.md                   # Verification Audit Ledger & Acceptance Gate Records
│   └── README_MASTER_RUN.md           # Architectural Simulation Manual
│
├── 02_Simulation_Models_and_Code/     # Complete MATLAB / Simulink / Simscape Simulation Suite
│   ├── SITRA_S5_Physical.slx          # TRACK 2: Pure Simscape Physical Circuit (230V AC/24V DC Buck, MOSFETs, Capacitors)
│   ├── SITRA_S2_test_ControllerCompare.slx # TRACK 1: 4-Controller Multi-Port Comparison Model (Zero Dangling Lines)
│   ├── SITRA_Deadtime_Testbench.slx   # Microsecond Gate Dead-Time Interlock Testbench (5.0 us blanking)
│   ├── SITRA_Simscape_Hardware.slx    # Dedicated Hardware Emulation Model
│   ├── run_master_all.m               # UNIFIED MASTER LAUNCHER (One-click execution of Track 1, Track 2, or Baselines)
│   ├── fix_all_model_connections.m    # Automated Model Validator & Zero-Dangling Port Repair Tool
│   ├── run_part_b.m                   # Part B: KCL Current Conservation Test Runner (< 1.42e-15 A residual)
│   ├── run_part_c.m                   # Part C: Microsecond Dead-Time Interlock Test Runner
│   ├── run_part_d_integrated.m        # Part D: Four-Controller Integrated Validation Runner (100% S9 Gate Pass)
│   ├── test_SITRA_S5_Physical.m       # Simscape Physical Circuit Automated Acceptance Test Suite
│   ├── run_controllers_on_S5_physical.m # 32 Physical Replay Runs with Voltage Tracking & Clearance Evaluation
│   ├── run_all_S6_S7.m                # S6 ESR Parasitics & S7 MOSFET Thermal Equilibrium Runner
│   ├── run_baseline_comparison.m      # 14-Scenario Master Multi-Controller Evaluation Runner (T1 to T14)
│   ├── bl_clearance.m                 # Non-Circular Twin-Run Clearance Metric Algorithm
│   ├── bl_inject.m                    # General Congestion, Incident, Blockage, Noise & Fault Injector
│   └── (All supporting controller & plant scripts: bl_ctrl_sitra, bl_ctrl_webster, bl_ctrl_actuated, etc.)
│
└── 03_Supplementary_Results_and_Figures/ # Quantitative Datasets, Simulation MATs, and 300 DPI Vector Figures
    ├── controller_clearance_physical.csv # Physical Circuit Clearance Times & Voltage Errors (32 runs)
    ├── baseline_comparison.csv        # Comprehensive 14-Scenario Performance Metrics Across 4 Controllers
    ├── baseline_runs_per_seed.csv     # Individual Stochastic Seed Performance Data
    ├── SITRA_PartD_Four_Controller_Comparison.csv # Part D Integrated Comparison Table
    ├── PartD_Summary.csv              # Part D Validation Summary
    ├── S6_S7_results.mat              # S6 ESR & S7 Thermal Simulation Dataset
    ├── S6_capacitor_parasitics_compensation.png # Active ESR Compensation Waveforms
    ├── S7_semiconductor_thermal_losses.png      # Power Semiconductor Thermal Rise Curves
    ├── fig_ieee_project_flowchart.png # 300 DPI 8-Stage Engineering Methodology Flowchart
    ├── fig_ieee_five_layer_architecture.png # 300 DPI Five-Layer Dual-Domain Architecture Diagram
    ├── fig_ieee_dual_domain_schematic.png   # 300 DPI Power Electronic Circuit Schematic
    ├── fig_ieee_power_flow.png        # 300 DPI AC-DC Power Distribution Flowchart
    ├── fig_site_map.png               # SITRA Junction Satellite & Arterial OpenStreetMap
    └── (Fig 04, Fig 20, Fig 21, Fig 25, Fig 27, Fig 28, Fig 29, Fig 30 - High-Resolution Result Waveforms)
```

---

## 🚀 Quick Execution Guide for Faculty Evaluator

### Requirements
- **MATLAB R2024b or newer**
- **Simulink**
- **Simscape** & **Simscape Electrical**

### Running the Complete Simulation Suite
1. Launch **MATLAB**.
2. Set the current MATLAB working directory to the folder:
   `Group_22/02_Simulation_Models_and_Code`
3. In the MATLAB Command Window, execute:
   ```matlab
   run_master_all
   ```
4. When prompted, select execution mode:
   - **`[1] Run All`**: Executes Track 1 (Mathematical Equivalents), Track 2 (Simscape Physical Circuit), and baseline validation.
   - **`[2] Track 1 Only`**: Executes Parts B, C, and D (`SITRA_S2_test_ControllerCompare.slx`).
   - **`[3] Track 2 Only`**: Executes S5 Physical Circuit (`SITRA_S5_Physical.slx`), S6 ESR compensation, and S7 thermal analysis.
   - **`[4] Baselines Only`**: Runs the 14-scenario multi-controller benchmark suite (T1 to T14).

### Verifying Model Wiring Integrity
To verify that all Simulink blocks are autorouted with zero dangling ports:
```matlab
fix_all_model_connections
```

---

## 🏆 Key Scientific & Engineering Findings

1. **Sub-Microvolt Cyber-Physical Equivalence**:
   - Replaying 32 controller scenarios through the real Simscape analog circuit confirmed that measured capacitor voltages track mathematical queue lengths with maximum absolute error strictly under **$8.0\,\mu\text{V}$** ($8.0 \times 10^{-6}\,\text{V}$).
   - Measured physical clearance times match traffic model clearance times to the exact integer second ($\Delta t_{\text{clear}} \equiv 0.00\,\text{s}$).

2. **The Actuated Noise Collapse (Critical Finding)**:
   - Under nominal deterministic surges (Scenario T6), Vehicle-Actuated control evacuated traffic in $63.0\,\text{s}$ (excess delay $181.4\,\text{veh}\cdot\text{s}$).
   - Under **Gaussian sensor telemetry noise** ($\sigma = 2.0\,\text{veh}$, Scenario T13), **Actuated control suffered catastrophic degradation**: clearance time exploded to **$424.25\,\text{s}$** ($23.3\times$ slowdown) with $2,190.21\,\text{veh}\cdot\text{s}$ excess delay due to spurious phase extensions and premature gap-outs.
   - **SITRA MPC maintained robust clearance at $56.60\,\text{s}$** ($93.97\,\text{veh}\cdot\text{s}$ excess delay) because its quadratic cost horizon inherently filters zero-mean telemetry noise.

3. **Power Electronics Reliability & Safety**:
   - Auxiliary buck converter maintains $V_{\text{bus}} = 23.98\,\text{V DC}$ with peak switching ripple under $15.0\,\text{mV}$.
   - Parasitic ESR voltage spikes ($\pm 15.0\,\text{mV}$) are suppressed to **$< 0.1\,\text{mV}$** via active feedforward compensation.
   - Power MOSFET junction operating temperature reaches equilibrium at **$T_j = 27.80^\circ\text{C}$** ($\Delta T_j = +2.80^\circ\text{C}$), operating with a **$> 140^\circ\text{C}$ safety margin** below the $175^\circ\text{C}$ maximum limit.

---

*Submitted on behalf of **Group 22** — Department of Electrical & Electronics Engineering, Amrita Vishwa Vidyapeetham, Coimbatore.*
