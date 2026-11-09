# Appendices

## Appendix A: Complete Software and Codebase Architecture Map

Table A.1: Comprehensive Codebase Architecture Map. Source: Repository inventory on branch `sai_dev`.

| Source File Path | Architectural Layer | Primary Functionality & Responsibilities | Sections Referenced | Supporting Figures |
|---|---|---|---|---|
| `run_master_all.m` | Master Orchestrator | Top-level entry point executing Tracks 1, 2, and 3 | Sec. 4.6, 8.5 | Fig. 4.1 |
| `FLAT/createNetwork.m` | Layer L1 (Plant) | Defines 5-node, 4-branch geometry, lengths, and capacities | Sec. 6.2, 8.1 | Fig. 4.3, 8.1 |
| `FLAT/signalModel.m` | Layer L1 (Plant) | Base discrete-time traffic plant state integration | Sec. 6.1 | Fig. 10.1 |
| `FLAT/mpcSignalModel.m` | Layer L5 (Control) | Frozen Part 8 receding-horizon MPC quadratic program | Sec. 6.3, 10.1 | Fig. 10.1, 10.2 |
| `FLAT/run_SITRA_Master_Simulation.m` | Master Testbench | Executes frozen Part 8 simulation, generating Figs. 01–20 | Sec. 4.6, 10.1 | Figs. 10.1–10.5 |
| `FLAT/baselines/bl_config.m` | Layer L5 (Config) | Global simulation parameters ($\Delta t = 1\text{ s}$, $T_{\text{cycle}} = 63\text{ s}$) | Sec. 5.1, 9.1 | Table 0.1 |
| `FLAT/baselines/bl_scenarios.m` | Layer L1 (Scenarios) | Complete definitions for Scenarios T1–T14 and twin pairs | Sec. 8.4, 9.2 | Table 8.3 |
| `FLAT/baselines/bl_make_arrivals.m` | Layer L1 (Disturbance) | Multi-seed arrival matrix generation (LCG / Poisson) | Sec. 6.8 | Fig. 10.1 |
| `FLAT/baselines/bl_plant_step.m` | Layer L1 (Plant) | Time-varying capacity plant step with B4 spill-back clamp | Sec. 5.1, 6.1 | Fig. 4.3 |
| `FLAT/baselines/bl_simulate.m` | Layer L5 (Simulation) | Multi-controller stepping engine with sensor fault injection | Sec. 4.7, 7.1 | Figs. 7.1–7.8 |
| `FLAT/baselines/bl_ctrl_webster.m` | Layer L5 (Control) | Webster fixed-time equisaturation split allocator | Sec. 6.4, 7.1 | Fig. 7.2 |
| `FLAT/baselines/bl_ctrl_actuated.m` | Layer L5 (Control) | Vehicle-actuated green extension and gap-out controller | Sec. 6.5, 7.1 | Fig. 7.3 |
| `FLAT/baselines/bl_ctrl_maxpressure.m` | Layer L5 (Control) | Varaiya max-pressure differential feedback controller | Sec. 6.6, 7.1 | Fig. 7.4 |
| `FLAT/baselines/bl_gates.m` | Layer L4 (Actuation) | One-hot binary gate conversion and mutual exclusion check | Sec. 6.7 | Fig. 4.4 |
| `FLAT/baselines/bl_clearance.m` | Layer L5 (Metrics) | 120-second moving average twin-run clearance metric | Sec. 6.9, 9.1 | Fig. 10.7 |
| `FLAT/baselines/bl_inject.m` | Disturbance Engine | Fault injector: incidents, blockages, noise, stuck gates | Sec. 6.14, 10.15 | Fig. 10.14 |
| `FLAT/baselines/run_baseline_comparison.m` | Master Benchmark | Full Mode 1 execution across T1–T14 $\times$ 4 ctrls $\times$ 5 seeds | Sec. 8.4, 10.4 | Figs. 10.6, 10.7 |
| `FLAT/baselines/plot_dual_domain.m` | Dual-Domain Tool | Generates synchronized 4-panel waveforms (8 PNGs) | Sec. 7.2 | Figs. 7.1–7.8 |
| `FLAT/S5_physical/S5_physical_params.m` | Layer L2/L3 (Params) | Complete component values and S12 placeholder ratings | Sec. 8.3 | Table 8.2 |
| `FLAT/S5_physical/build_SITRA_S5_Physical.m` | Simscape Compiler | Programmatically compiles pure Simscape physical model | Sec. 8.2, 8.3 | Figs. 8.2, 8.3 |
| `FLAT/S5_physical/SITRA_S5_Physical.slx` | Physical Model | Multi-domain Simscape model (0 software code blocks) | Sec. 8.2 | Figs. 8.2, 8.3 |
| `FLAT/S5_physical/test_SITRA_S5_Physical.m` | Verification Suite | Verifies block inventory, traffic equivalence, and power path | Sec. 8.2, 10.6 | Figs. 10.8, 10.9 |
| `FLAT/S5_physical/run_controllers_on_S5_physical.m` | Circuit Benchmark | Executes 32 full physical circuit runs, measuring clearance | Sec. 10.7 | Fig. 10.10 |
| `FLAT/S6_S7_parasitics/run_all_S6_S7.m` | Parasitic / Thermal | Evaluates capacitor ESR/ESL compensation and thermal rise | Sec. 6.15, 6.16 | Figs. 10.12, 10.13 |
| `run_part_b.m` | Track 1 Stage 1.1 | Verifies voltage equivalence and KCL current conservation | Sec. 10.9 | Table 10.8 |
| `run_part_c.m` | Track 1 Stage 1.2 | Verifies $5\,\mu\text{s}$ semiconductor dead-time interlock | Sec. 6.7, 10.9 | Table 10.8 |
| `run_part_d_integrated.m` | Track 1 Stage 1.3 | Integrated S9 four-controller validation harness | Sec. 10.9 | Table 10.8 |

---

## Appendix B: Reproduction Instructions and Environment Specifications

To reproduce every simulation, benchmark table, and figure reported in this work from scratch:
1. **Clone Repository and Checkout Working Branch:**
   ```bash
   git clone https://github.com/siddu1004/power_systems_electronic_circuit_design_of_traffic_systems.git
   cd power_systems_electronic_circuit_design_of_traffic_systems
   git checkout sai_dev
   ```
2. **Launch MATLAB and Execute Unified Master Runner:**
   In the MATLAB command prompt, execute:
   ```matlab
   cd('c:/Users/saisi/Downloads/SITRA_Project');
   run_master_all;
   ```
3. **Execution Sequence:**
   - *Track 1 (Approx. 4.2 s):* Validates Part B voltage-queue equivalence, Part C $5\,\mu\text{s}$ dead-time testbench, and Part D integrated 4-controller S9 simulation.
   - *Track 2 (Approx. 78.4 s):* Compiles and tests `SITRA_S5_Physical.slx`, runs 32 physical Simscape circuit simulations across T5–T14, generates `controller_clearance_physical.csv`, and executes Stages S6 and S7.
   - *Track 3 (Approx. 38.6 s):* Runs frozen Part 8 MPC reference, executes Mode 1 baseline comparison across 14 scenarios $\times$ 4 controllers $\times$ 5 seeds, generates `baseline_comparison.csv` and `baseline_runs_per_seed.csv`, and renders publication figures.
4. **Output Verification:**
   All generated artifacts are deposited automatically in `SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/Results/`.

---

## Appendix C: Complete Experimental Benchmark CSV Data Tables

Table C.1: Full Experimental Baseline Comparison (Scenarios T1–T14, Mode 1 Batch). Source: `FLAT/Results/baselines/baseline_comparison.csv`.

| Scn | Name | Controller | AvgDelay [s] | StdDelay [s] | LOS | NetDelay [s] | AvgQ [veh] | MaxQ [veh] | MaxQB4 [veh] | Thr [vph] | FinalQ [veh] | tClear [s] | Cleared | ExcessVehS | PeakExcess [veh] |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| T1 | Low | SITRA | 17.335 | 2.479 | B | 18.814 | 2.518 | 5.680 | 2.190 | 509.7 | 2.230 | NaN | N/A | NaN | NaN |
| T1 | Low | Webster | 16.450 | 1.040 | B | 17.841 | 2.373 | 5.470 | 2.090 | 511.6 | 1.760 | NaN | N/A | NaN | NaN |
| T1 | Low | Actuated | 11.726 | 1.524 | B | 13.058 | 1.698 | 5.000 | 1.820 | 512.6 | 1.510 | NaN | N/A | NaN | NaN |
| T1 | Low | MaxPressure | 13.932 | 2.049 | B | 15.232 | 2.017 | 4.240 | 1.610 | 511.2 | 1.870 | NaN | N/A | NaN | NaN |
| T2 | Moderate | SITRA | 25.592 | 4.470 | C | 27.697 | 6.505 | 10.660 | 3.620 | 881.8 | 6.500 | NaN | N/A | NaN | NaN |
| T2 | Moderate | Webster | 26.774 | 4.650 | C | 28.637 | 6.819 | 10.640 | 2.650 | 868.4 | 9.860 | NaN | N/A | NaN | NaN |
| T2 | Moderate | Actuated | 17.853 | 3.126 | B | 19.770 | 4.551 | 9.800 | 4.000 | 882.1 | 6.430 | NaN | N/A | NaN | NaN |
| T2 | Moderate | MaxPressure | 25.411 | 6.389 | C | 27.027 | 6.500 | 7.800 | 2.660 | 881.3 | 6.640 | NaN | N/A | NaN | NaN |
| T3 | High | SITRA | 60.713 | 19.224 | E | 63.221 | 21.776 | 20.710 | 4.530 | 1115.8 | 38.340 | NaN | N/A | NaN | NaN |
| T3 | High | Webster | 62.209 | 13.785 | E | 66.962 | 22.166 | 20.890 | 6.650 | 1154.6 | 28.630 | NaN | N/A | NaN | NaN |
| T3 | High | Actuated | 40.286 | 11.897 | D | 44.260 | 14.446 | 17.520 | 7.580 | 1182.3 | 21.700 | NaN | N/A | NaN | NaN |
| T3 | High | MaxPressure | 64.941 | 17.738 | E | 66.728 | 23.234 | 21.600 | 2.850 | 1100.1 | 42.270 | NaN | N/A | NaN | NaN |
| T4 | Oversaturated | SITRA | 136.975 | 18.326 | F | 139.476 | 67.766 | 51.810 | 4.930 | 1224.8 | 136.050 | NaN | N/A | NaN | NaN |
| T4 | Oversaturated | Webster | 128.376 | 23.498 | F | 132.591 | 63.673 | 60.120 | 6.650 | 1269.6 | 124.840 | NaN | N/A | NaN | NaN |
| T4 | Oversaturated | Actuated | 107.520 | 16.578 | F | 113.223 | 53.254 | 46.310 | 8.450 | 1335.2 | 108.440 | NaN | N/A | NaN | NaN |
| T4 | Oversaturated | MaxPressure | 130.917 | 16.385 | F | 132.788 | 64.695 | 60.950 | 4.510 | 1238.3 | 132.680 | NaN | N/A | NaN | NaN |
| T5 | Step demand | SITRA | 42.482 | 11.489 | D | 44.825 | 11.025 | 15.430 | 4.450 | 876.4 | 10.650 | 76.00 | 1/5 | 2662.47 | 13.77 |
| T5 | Step demand | Webster | 46.335 | 12.907 | D | 48.231 | 12.027 | 15.820 | 2.650 | 859.3 | 14.940 | NaN | 0/5 | 2927.43 | 15.62 |
| T5 | Step demand | Actuated | 29.299 | 7.210 | C | 32.533 | 7.592 | 14.600 | 7.010 | 900.5 | 4.620 | 131.67 | 3/5 | 1332.67 | 10.19 |
| T5 | Step demand | MaxPressure | 45.267 | 14.087 | D | 47.077 | 11.787 | 14.000 | 3.250 | 866.8 | 13.050 | 117.00 | 1/5 | 3176.66 | 14.85 |
| T6 | Surge (Det.) | SITRA | 24.281 | 0.000 | C | 28.022 | 6.958 | 12.300 | 6.250 | 1004.4 | 4.540 | 106.00 | 1/1 | 305.59 | 4.72 |
| T6 | Surge (Det.) | Webster | 34.807 | 0.000 | C | 38.125 | 9.974 | 22.450 | 3.850 | 1003.1 | 4.760 | NaN | 0/1 | 1867.21 | 16.58 |
| T6 | Surge (Det.) | Actuated | 17.233 | 0.000 | B | 21.066 | 4.938 | 12.000 | 6.450 | 1009.6 | 3.670 | 63.00 | 1/1 | 181.43 | 4.21 |
| T6 | Surge (Det.) | MaxPressure | 20.049 | 0.000 | C | 22.400 | 5.745 | 7.700 | 4.450 | 1007.1 | 4.090 | NaN | 0/1 | 411.96 | 4.66 |
| T7 | Surge (Poisson) | SITRA | 28.825 | 10.417 | C | 32.171 | 8.412 | 15.800 | 5.650 | 988.4 | 6.990 | 113.50 | 2/5 | 947.54 | 8.17 |
| T7 | Surge (Poisson) | Webster | 37.393 | 11.049 | D | 40.362 | 10.949 | 19.970 | 3.850 | 963.6 | 11.130 | 50.00 | 1/5 | 1756.76 | 13.55 |
| T7 | Surge (Poisson) | Actuated | 20.428 | 5.423 | C | 24.367 | 5.955 | 13.210 | 6.620 | 996.4 | 5.650 | 82.50 | 4/5 | 405.56 | 5.20 |
| T7 | Surge (Poisson) | MaxPressure | 25.087 | 7.388 | C | 27.397 | 7.325 | 9.900 | 4.360 | 972.8 | 9.600 | NaN | 0/5 | 764.59 | 5.73 |
| T8 | Congested start | SITRA | 73.887 | 8.072 | E | 77.117 | 18.710 | 25.000 | 4.250 | 1079.9 | 6.920 | 643.75 | 4/5 | 10971.92 | 39.95 |
| T8 | Congested start | Webster | 83.834 | 11.862 | F | 86.407 | 21.222 | 25.770 | 2.650 | 1064.8 | 10.710 | 522.50 | 2/5 | 12951.07 | 42.60 |
| T8 | Congested start | Actuated | 51.514 | 5.621 | D | 55.928 | 12.978 | 25.000 | 8.370 | 1084.3 | 5.830 | 484.40 | 5/5 | 7816.55 | 36.51 |
| T8 | Congested start | MaxPressure | 74.751 | 10.188 | E | 77.784 | 18.974 | 25.000 | 6.450 | 1074.6 | 8.260 | 736.00 | 2/5 | 11233.13 | 37.70 |
| T9 | Incident B1 | SITRA | 30.798 | 9.080 | C | 32.852 | 7.864 | 11.450 | 4.030 | 881.8 | 6.500 | 174.60 | 5/5 | 829.10 | 4.25 |
| T9 | Incident B1 | Webster | 37.203 | 12.259 | D | 39.014 | 9.564 | 13.920 | 2.650 | 865.8 | 10.500 | 148.00 | 3/5 | 1462.16 | 6.19 |
| T9 | Incident B1 | Actuated | 19.609 | 3.588 | B | 21.471 | 4.991 | 9.400 | 4.380 | 884.1 | 5.930 | 80.00 | 5/5 | 272.85 | 2.23 |
| T9 | Incident B1 | MaxPressure | 28.873 | 9.733 | C | 30.375 | 7.413 | 8.350 | 2.690 | 876.5 | 7.830 | 136.67 | 3/5 | 644.17 | 2.40 |
| T10 | Blockage B4 | SITRA | 34.001 | 13.199 | C | 44.781 | 8.705 | 11.650 | 14.742 | 881.5 | 6.580 | 247.75 | 4/5 | 1767.58 | 6.12 |
| T10 | Blockage B4 | Webster | 34.031 | 11.483 | C | 45.277 | 8.721 | 11.460 | 14.218 | 867.4 | 10.100 | 153.00 | 4/5 | 1336.24 | 7.18 |
| T10 | Blockage B4 | Actuated | 21.989 | 7.469 | C | 33.627 | 5.634 | 10.440 | 15.058 | 884.0 | 5.950 | 141.40 | 5/5 | 871.57 | 5.74 |
| T10 | Blockage B4 | MaxPressure | 30.063 | 9.086 | C | 40.165 | 7.704 | 9.640 | 14.870 | 877.8 | 7.500 | 172.50 | 4/5 | 870.22 | 5.67 |
| T11 | Platoon B2 | SITRA | 51.664 | 14.730 | D | 53.673 | 15.474 | 21.670 | 3.250 | 1026.7 | 10.230 | 223.00 | 1/5 | 4266.98 | 20.05 |
| T11 | Platoon B2 | Webster | 63.702 | 7.479 | E | 65.828 | 18.946 | 29.430 | 3.450 | 1007.7 | 15.000 | 283.00 | 1/5 | 5334.77 | 24.14 |
| T11 | Platoon B2 | Actuated | 42.291 | 12.815 | D | 44.743 | 12.703 | 22.870 | 5.820 | 1045.0 | 5.670 | 188.50 | 2/5 | 3360.91 | 18.77 |
| T11 | Platoon B2 | MaxPressure | 51.748 | 15.863 | D | 53.358 | 15.574 | 16.620 | 2.450 | 1011.7 | 14.000 | 232.00 | 1/5 | 4549.45 | 17.16 |
| T12 | Sensor stuck B1 | SITRA | 25.814 | 3.024 | C | 27.973 | 6.540 | 10.770 | 4.050 | 881.8 | 6.500 | 2.60 | 5/5 | 32.62 | 0.65 |
| T12 | Sensor stuck B1 | Webster | 26.774 | 4.650 | C | 28.637 | 6.819 | 10.640 | 2.650 | 868.4 | 9.860 | 0.00 | 5/5 | 0.00 | 0.00 |
| T12 | Sensor stuck B1 | Actuated | 23.974 | 3.526 | C | 26.096 | 6.095 | 11.930 | 4.830 | 884.2 | 5.900 | 140.60 | 5/5 | 516.93 | 5.03 |
| T12 | Sensor stuck B1 | MaxPressure | 43.083 | 17.028 | D | 46.038 | 11.081 | 21.000 | 6.050 | 873.7 | 8.540 | 136.50 | 2/5 | 1697.81 | 12.89 |
| T13 | Sensor noise | SITRA | 21.546 | 3.006 | C | 23.490 | 5.478 | 9.360 | 3.270 | 883.7 | 6.040 | 56.60 | 5/5 | 93.97 | 0.31 |
| T13 | Sensor noise | Webster | 26.774 | 4.650 | C | 28.637 | 6.819 | 10.640 | 2.650 | 868.4 | 9.860 | 0.00 | 5/5 | 0.00 | 0.00 |
| T13 | Sensor noise | Actuated | 27.008 | 2.882 | C | 29.405 | 6.852 | 11.670 | 5.060 | 868.6 | 9.820 | 424.25 | 4/5 | 2190.21 | 4.93 |
| T13 | Sensor noise | MaxPressure | 29.912 | 8.513 | C | 31.530 | 7.628 | 9.230 | 2.460 | 870.4 | 9.360 | 0.00 | 4/5 | 1262.41 | 3.98 |
| T14 | Stuck off B3 | SITRA | 29.597 | 7.464 | C | 31.722 | 7.543 | 11.010 | 3.570 | 881.8 | 6.500 | 219.20 | 5/5 | 842.33 | 3.60 |
| T14 | Stuck off B3 | Webster | 29.770 | 7.120 | C | 31.633 | 7.606 | 10.710 | 2.650 | 868.4 | 9.860 | 213.00 | 5/5 | 649.33 | 2.27 |
| T14 | Stuck off B3 | Actuated | 21.650 | 5.581 | C | 23.798 | 5.538 | 11.480 | 4.750 | 883.3 | 6.130 | 189.80 | 5/5 | 849.60 | 4.84 |
| T14 | Stuck off B3 | MaxPressure | 31.474 | 9.586 | C | 33.066 | 8.074 | 9.400 | 2.330 | 874.7 | 8.270 | 143.00 | 3/5 | 1302.96 | 4.58 |

---

## Appendix D: Skipped Duplicate Figures Inventory

In strict adherence to Rule 0.6 ("No duplicate figures"), identical or redundant plot artifacts existing across different repository folders were inventoried, consolidated, and mapped to a single canonical file in the report:

Table D.1: Skipped Duplicate Figures Inventory. Source: Repository asset audit.

| Canonical Figure in Report | Repository File Path Used | Skipped Redundant Duplicate Paths in Repository | Rationale for Selection |
|---|---|---|---|
| **Fig. 10.1** | `Results/figures/01_network_queue_dynamics.png` | `Results/figures/Fig1.png`, `fig1.png` | Canonical high-resolution numbered master export |
| **Fig. 10.2** | `Results/figures/02_total_queue_response.png` | `Results/figures/Fig2.png`, `fig2.png` | Master labeled surge envelope plot |
| **Fig. 10.3** | `Results/figures/10_conservation_residual.png` | `Results/power_electronics/PE6_kcl_residuals.png`, `Results/figures/20_PE_kcl_residuals.png` | Exact mathematical identical content (max residual $7.22\times 10^{-16}$) |
| **Fig. 10.5** | `Results/figures/07_part8_vs_switching_total_queue.png` | `Results/figures/Fig7.png` | Complete legend and axis labeled export |
| **Fig. 10.6** | `Results/baselines/fig2_delay_vs_demand.png` | `Results/figures/14_fixed_adaptive_mpc_peak_comparison.png` | Specific 4-controller T1–T4 delay curves with exact units |
| **Fig. 10.8** | `Results/S5_physical/fig_vC_vs_qRef.png` | `Results/power_electronics/PE1_capacitor_voltages.png`, `Results/figures/15_PE_capacitor_voltages.png` | Physical Simscape S5 sensor output vs discrete reference |
| **Fig. 10.10** | `Results/S5_physical/fig_clearance_physical.png` | `Results/S5_physical/fig_clearance_physical_legacy.png` | Updated 8-scenario ($4\times 2$) grid with twin run clearance labels |
| **Fig. 10.11** | `Results/S5_physical/fig_power_path.png` | `Results/power_electronics/PE4_bus_and_bottleneck.png`, `Results/figures/18_PE_bus_and_bottleneck.png` | Full S5 power path output with DC-link, 24V bus, and channel currents |

---

## Appendix E: Comprehensive Technical Glossary for Non-Electrical Readers

Table E.1: Dual-Domain Technical Glossary.

| Term | Domain | Definition and Physical Significance in SITRA |
|---|---|---|
| **Coulomb (C)** | Electrical | Standard International unit of electric charge ($1\text{ C} = 1\text{ A}\cdot\text{s}$). In SITRA, exactly equals one vehicle ($1\text{ C} = 1\text{ veh}$). |
| **Farad (F)** | Electrical | Unit of electrical capacitance ($C = Q/V$). A $1\text{ F}$ capacitor stores $1\text{ C}$ of charge at $1\text{ V}$, mapping $1\text{ V}$ directly to $1\text{ vehicle}$. |
| **Kirchhoff's Current Law (KCL)** | Electrical | Physical law stating that the algebraic sum of currents entering any node equals zero. In traffic, represents exact vehicular conservation ($\sum \text{in} - \sum \text{out} = \Delta \text{queue}$). |
| **MOSFET** | Electrical | Metal-Oxide-Semiconductor Field-Effect Transistor. High-speed solid-state electronic switch controlling branch current conduction via gate voltage. |
| **Dead-Time ($t_d$)** | Electrical | A microsecond non-conduction interval inserted during phase transitions to prevent cross-conduction between switches. Corresponds to the all-red traffic clearance interval. |
| **Buck DC-DC Converter** | Electrical | Switched-mode power electronic circuit stepping down high DC voltage to lower regulated DC voltage ($47.3\text{ V} \to 24.0\text{ V}$) via PWM control. |
| **Pulse-Width Modulation (PWM)** | Electrical | High-frequency switching technique regulating average voltage by modulating the conduction duty cycle of a semiconductor switch. |
| **ESR / ESL** | Electrical | Equivalent Series Resistance and Inductance; physical parasitic non-idealities in real capacitors that introduce ohmic voltage drops during current steps. |
| **Spill-Back** | Traffic | Condition where downstream vehicular accumulation exceeds road storage capacity, obstructing upstream discharge and causing intersection gridlock. |
| **Equisaturation** | Traffic | Webster signal timing principle allocating green times proportionally to approach volume-to-capacity ratios to equalize degree of saturation. |
| **Gap-Out** | Traffic | Vehicle-actuated control condition terminating green when the time headway between consecutive arriving vehicles exceeds a pre-set threshold. |
| **Max-Pressure** | Traffic | Decentralized routing and signal control algorithm that prioritizes phases with maximum spatial queue differentials between upstream and downstream links. |
| **Level of Service (LOS)** | Traffic | Highway Capacity Manual qualitative grading scale (A through F) evaluating intersection performance based on average control delay per vehicle. |
