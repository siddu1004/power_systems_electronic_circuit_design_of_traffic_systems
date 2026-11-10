# SITRA Master Simulation and Architectural Guide

This document describes the unified structure of Project SITRA, integrating both the **Mathematical Equivalent Model** and the **Physical Simscape Circuit**.

---

## 1. Dual-Track Architecture Overview

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
| - Scale: 1 V = 1 veh, 1 A = 1 veh/s, C = 1.0 F   |   | - No physics in code (0 function/S-fn blocks)    |
| - 4-Controller Selector:                         |   | - Real AC Mains (230 V, 50 Hz) -> Transformer    |
|   * SITRA Receding-Horizon MPC                   |   | - Full-wave 4-Diode Bridge Rectifier             |
|   * Webster Fixed-Time Equal-Saturation          |   | - DC-Link (2200 uF + ESR + Bleed resistor)       |
|   * Vehicle-Actuated Dynamic Gap-Out             |   | - Closed-loop Buck DC-DC Converter (24V PI+PWM)  |
|   * Decentralized MaxPressure                    |   | - 3 High-side MOSFET Signal-Head Channels (24W)  |
| - Validated Subsystems:                          |   | - 4 x 1F Capacitor Physical KCL Traffic Network  |
|   * 05_Power_Electronics (Analytical Equivalent) |   | - S6: Capacitor parasitics (ESR/ESL/leakage)     |
|   * 06_Measurement                               |   | - S7: MOSFET switching dynamics & thermal rise   |
|   * 09_Output_Validation (Multi-Signal Gate)     |   | - Microsecond ADC Delays break algebraic loops   |
| - Microsecond Interlock:                         |   | - Measured Tracking Error: 1.30e-6 V (< 1e-3 V)  |
|   * SITRA_Deadtime_Testbench.slx (5 us blanking) |   | - Power Bus Regulation: 23.98 V (+/- 6.8%)       |
| - Current Conservation Residual: < 1.42e-15 A    |   | - Status: PASS                                   |
| - Status: PASS                                   |   |                                                  |
+--------------------------------------------------+   +--------------------------------------------------+
```

---

## 2. Key Files Reference

### A. Master Runners
- `run_master_all.m`: One-click master script executing both Track 1 (Mathematical Equivalent) and Track 2 (Physical Simscape).
- `run_part_b.m`: Evaluates mathematical current conservation across all 4 controllers.
- `run_part_c.m`: Evaluates $5\ \mu\text{s}$ semiconductor dead-time interlock in `SITRA_Deadtime_Testbench.slx`.
- `run_part_d_integrated.m`: Integrated validation of all 4 controllers with Subsystem 09 Output Validation.

### B. Physical Simscape Simulation Suite (Stage S5, S6, S7)
- `SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/S5_physical/SITRA_S5_Physical.slx`: The authoritative physical Simscape model.
- `SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/S5_physical/build_SITRA_S5_Physical.m`: Automated programmatic script that creates the Simscape model from scratch.
- `SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/S5_physical/test_SITRA_S5_Physical.m`: Complete acceptance test suite (Block audit, traffic equivalence, power path regulation).
- `SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/S6_S7_parasitics/run_all_S6_S7.m`: Master runner for Stage S6 (parasitics) and Stage S7 (semiconductor thermal).

### C. Mathematical Multi-Controller Comparison Suite
- `SITRA_S2_test_ControllerCompare.slx`: Simulink model with 4-controller selector.
- `upgrade_electrical_subsystems.m`: Automated upgrade script for Subsystems 05, 06, and 09.
- `SITRA_Deadtime_Testbench.slx`: Microsecond ($1\ \mu\text{s}$) semiconductor gate switching testbench.

### D. Documentation & Scientific Publications
- `SITRA_IEEE_Research_Paper.md`: Complete, publication-ready research paper synthesizing mathematical equivalence, multi-controller comparison, physical Simscape hardware circuit, and thermal dynamics.
- `SITRA_Project/SITRA_Final_Technical_Report.md`: In-depth engineering technical report.
- `SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/BUILD_LOG.md`: Authoritative part-by-part verification ledger.

---

## 3. How to Run in MATLAB

Open MATLAB R2026a, navigate to this directory, and run:
```matlab
% Run the complete unified suite
run_master_all;
```
Or run individual components:
```matlab
% Track 1: Mathematical multi-controller evaluation
run_part_d_integrated;

% Track 2: Real Simscape physical circuit simulation
cd('SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/S5_physical');
test_SITRA_S5_Physical;

% Track 2 (cont.): S6 & S7 parasitics and thermal dynamics
cd('../S6_S7_parasitics');
run_all_S6_S7;
```
