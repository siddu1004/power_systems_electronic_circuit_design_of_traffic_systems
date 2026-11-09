# 4. Flow Diagrams, Power Flow Architecture, and System Analogy

This section establishes the complete visual architecture of the SITRA framework. To provide rigorous architectural mapping across both electrical and traffic domains, we partition the entire system into five distinct functional layers (L1 through L5). Every algorithm, circuit block, and figure in subsequent sections is explicitly tagged with its corresponding layer label.

## 4.1 System Architectural Layer Definitions
- **Layer L1 (Traffic Plant & Isomorphic Equivalent Circuit):** Represents the macroscopic traffic storage dynamics at the intersection. Vehicles accumulate in approaches modeled as one-Farad capacitors ($C_{B1}..C_{B4} = 1.0\text{ F}$). Vehicular inflows correspond to controlled current sources ($i_{\text{in}} = \lambda$), and vehicular departures correspond to controlled current sinks ($i_{\text{dep}} = \mu$).
- **Layer L2 (Power Conditioning & DC-Link Intermediate Stage):** Comprises the utility grid interface, stepping down $230\text{ V}_{\text{rms}}$ mains AC voltage to $36\text{ V}_{\text{rms}}$ via a magnetic transformer, rectifying AC to unregulated DC via a 4-diode full-wave bridge, and buffering energy in bulk capacitor $C_{\text{dc}} = 2200\,\mu\text{F}$ at an average intermediate potential of $V_{\text{DC}} = 47.31\text{ V}$.
- **Layer L3 (Buck DC-DC Regulation & Protection Layer):** Incorporates a switched-mode buck converter operating at $10\text{ kHz}$ switching frequency, regulated by a closed-loop Proportional-Integral (PI) compensator and PWM modulator to maintain a stable $24.0\text{ V}$ DC bus across load transients. Includes hardware over-current (OC) latching, bus under-voltage (UV) trips with start-up blanking, and a $5.0\,\mu\text{s}$ mutual-exclusion dead-time interlock.
- **Layer L4 (Physical Actuation & Signal-Head Hardware):** Consists of three high-side N-channel MOSFET switching channels that drive physical LED traffic signal heads ($24\,\Omega$ resistive load, drawing $1.0\text{ A}$ nominal current per active phase).
- **Layer L5 (Control Intelligence & Decision Architecture):** Houses the algorithmic decision engines (SITRA MPC, Webster, Actuated, MaxPressure) that observe traffic states and generate discrete phase switching commands.

Table 4.1: Comprehensive Dual-Domain Isomorphism Mapping. Source: `FLAT/baselines/bl_plant_step.m`, `FLAT/S5_physical/build_SITRA_S5_Physical.m`.

| Traffic System Quantity | Electrical Equivalent Quantity | Unit Mapping & Scale Factor | Implementation in Codebase | Layer Tag |
|---|---|---|---|---|
| Vehicular Queue $q_b(t)$ | Electrostatic Charge $Q_b(t)$ / Potential $v_{Cb}(t)$ | $1\text{ vehicle} = 1\text{ Coulomb}$, $C = 1\text{ F} \implies 1\text{ V} = 1\text{ veh}$ | `R.qHist(:, b)`, `S5_vC.signals.values(:, b)` | Layer L1 |
| Arrival Demand $\lambda_b(t)$ | Inflow Current $i_{\text{in}, b}(t)$ | $1\text{ veh/s} = 1\text{ Ampere}$ | `A(:, b)`, `From Workspace (Arrivals)` | Layer L1 |
| Departure Flow $\mu_b(t)$ | Discharge Sink Current $i_{\text{dep}, b}(t)$ | $1\text{ veh/s} = 1\text{ Ampere}$ | `R.depHist(:, b)`, `SPS_dep_B(b)` | Layer L1 |
| Stop-Line Saturation Capacity $C_b$ | Maximum Sink Current Limit $I_{\max, b}$ | $1\text{ veh/s} = 1\text{ Ampere}$ (Assumed values) | `net.capacity(b)`, `Capacity_veh_per_s` | Layer L1 |
| Green Signal Indication $g_b(t) \in \{0, 1\}$ | MOSFET Gate Conduction State | $0\text{ (Red)} \implies V_{\text{gs}} = 0\text{ V}$, $1\text{ (Green)} \implies V_{\text{gs}} = 10\text{ V}$ | `R.gates(:, b)`, `S5.gates`, `SPS_gate` | Layer L4 |
| All-Red Clearance Interval $r_{\text{all}}$ | Semiconductor Dead-Time $t_d$ | $1\text{ s (Macro)} \longleftrightarrow 5.0\,\mu\text{s (Micro)}$ | `bl_gates.m`, `SITRA_Deadtime_Testbench.slx` | Layer L3 |
| Downstream Bottleneck Link (Branch 4) | Common DC-Link Energy Buffer | Vehicular accumulation $\longleftrightarrow$ Capacitor voltage | `qHist(:, 4)`, `vC(:, 4)`, `C_dc` | Layer L1, L2 |
| Junction Vehicular Conservation | Kirchhoff's Current Law (KCL) | $\sum \lambda - \sum \mu = \frac{dq}{dt} \longleftrightarrow \sum I_{\text{in}} - \sum I_{\text{out}} = C\frac{dv}{dt}$ | `bl_plant_step.m`, `KCL Residual Check` | Layer L1 |
| Downstream Spill-Back Obstruction | Voltage-Controlled Clamp / Limiter | $q_4 \ge q_{4\max} \implies$ Upstream sinks disabled | `B4_Spillback_Clamp`, `Interlock/3` | Layer L1, L3 |
| Vehicle Detector Sensor | Analog-to-Digital Converter (ADC) / Voltmeter | Queue voltage sensing $\implies$ Digital controller word | `qSeen`, `Sample_queue` ($T_s = 1.0\text{ s}$) | Layer L5 |

## 4.2 Overall Project Workflow
Fig. 4.1 illustrates the end-to-end engineering methodology implemented across the SITRA project.

![Fig. 4.1. Overall Project Workflow: From empirical urban traffic problem formulation to pure physical circuit validation (Layers L1–L5).](figures/fig_project_flowchart.png){width=100%}

The workflow proceeds sequentially through eight distinct phases:
1. **Empirical Problem Formulation:** Identifying bottleneck congestion at the SITRA 3-approach junction on Avinashi Road, Coimbatore.
2. **Traffic Geometry & Demand Modeling:** Constructing network parameters (`createNetwork.m`), defining approach capacities ($C_1..C_4$), and generating stochastic Poisson arrival profiles (`bl_make_arrivals.m`).
3. **Multi-Controller Synthesis:** Implementing four distinct control policies—SITRA MPC, Webster fixed-time, vehicle-actuated, and Varaiya max-pressure—within unified baseline harness `bl_simulate.m`.
4. **Isomorphic Dual-Domain Mapping:** Formalizing the $1\text{ C} = 1\text{ veh}$ and $1\text{ A} = 1\text{ veh/s}$ mathematical equivalence.
5. **Simscape Physical Model Synthesis:** Compiling `SITRA_S5_Physical.slx` with pure electrical library components, complete 230 V power conversion, and zero embedded interpreter blocks.
6. **Multi-Track Validation:** Enforcing rigorous numerical gates: $0.000\text{ V}$ error against frozen Part 8 MPC reference, $< 1\text{ mV}$ circuit voltage error, and $< 10^{-15}\text{ A}$ KCL residual.
7. **Twin-Run Congestion Clearance Testing:** Quantifying exact recovery seconds ($t_{\text{clear}}$) and excess vehicle delay ($E_{\text{veh}}$) across fourteen scenarios.
8. **Dual-Domain Evaluation:** Cross-examining synchronized waveforms of gates, capacitor voltages, branch currents, and sensor distortions.

## 4.3 Power Flow Architecture
Fig. 4.2 illustrates the electrical power distribution and conversion topology implemented in `SITRA_S5_Physical.slx` (Layers L2, L3, and L4).

![Fig. 4.2. Complete Power Flow Chart: AC mains conditioning to 24 V regulated DC signal-head channels (Layers L2, L3, L4).](figures/fig_power_flow.png){width=100%}

Electrical energy enters the system from the single-phase $230\text{ V}_{\text{rms}}$, $50\text{ Hz}$ AC utility grid (`Vac_rms`). An ideal step-down transformer with turns ratio $n = 36 / 230 \approx 0.1565$ steps the voltage down to $36\text{ V}_{\text{rms}}$. A full-wave four-diode bridge rectifier converts the secondary AC voltage to pulsating DC. The rectified waveform is filtered by bulk electrolytic capacitor $C_{\text{dc}} = 2200\,\mu\text{F}$ (with equivalent series resistance $R_{\text{esr}} = 50\,\text{m}\Omega$ and safety bleed resistance $R_{\text{bleed}} = 10\,\text{k}\Omega$), establishing an intermediate DC-link bus at $V_{\text{DC}} = 47.31\text{ V}$.

A buck DC-DC power converter steps the intermediate potential down to a regulated $V_{\text{bus}} = 24.0\text{ V}$ distribution rail. The buck stage comprises an N-channel switching MOSFET, a freewheeling diode, power inductor $L_{\text{buck}} = 2.0\text{ mH}$, output filter capacitor $C_{\text{out}} = 3300\,\mu\text{F}$, and an RC damping network ($R_{\text{damp}} = 1.0\,\Omega$, $C_{\text{damp}} = 4.7\text{ mF}$). Closed-loop voltage regulation is executed by a discrete Proportional-Integral (PI) compensator ($K_p = 0.03\text{ V}^{-1}$, $K_i = 25.0\,(\text{V}\cdot\text{s})^{-1}$) modulating a $10\text{ kHz}$ PWM pulse train clamped to a maximum duty cycle of $D_{\max} = 0.95$. 

The regulated 24 V rail passes through protection logic incorporating an under-voltage (UV) trip threshold at $75\%$ ($18.0\text{ V}$) with a $246\text{ ms}$ startup blanking timer, and a channel over-current (OC) latch set at $2.0\text{ A}$. The bus feeds three high-side MOSFET switches driving the traffic signal heads ($24\,\Omega$ resistive load, drawing $1.0\text{ A}$ nominal current when commanded green).

## 4.4 Traffic Network Flow Topology
Fig. 4.3 details the vehicular flow topology of the SITRA junction modeled in Layer L1.

![Fig. 4.3. Traffic Network Flow Topology: 3-approach convergence into downstream bottleneck link B4 (Layer L1).](figures/fig_traffic_flow.png){width=100%}

Vehicles arrive on three conflicting upstream approaches:
- **Branch 1 (Hope College / Avinashi Road Eastbound):** Arrival demand $\lambda_1(t)$ varies from $0.10\text{ veh/s}$ in normal conditions to $0.30\text{ veh/s}$ during peak surges. Stop-line discharge capacity is $C_1 = 0.65\text{ veh/s}$.
- **Branch 2 (Kalapatti Road):** Intermittent commuter demand $\lambda_2(t) = 0.07\text{–}0.15\text{ veh/s}$, with stop-line capacity $C_2 = 0.35\text{ veh/s}$.
- **Branch 3 (Airport Road):** Feeder flow $\lambda_3(t) = 0.05\text{–}0.12\text{ veh/s}$, with stop-line capacity $C_3 = 0.25\text{ veh/s}$.

The three approaches merge at the internal junction conflict zone (the physical intersection box). Under mutual exclusion, exactly one approach discharges at any time instant ($\sum_{b=1}^{3} g_b(t) \le 1$). Discharging vehicles flow into **Branch 4 (Avinashi Road onward to Goldwins)**, which possesses a bottleneck exit capacity of $C_4 = 0.45\text{ veh/s}$ and an assumed physical storage limit of $q_{4\max} = 15.0\text{ veh}$. In the physical circuit, the B4 node functions as an electrical Kirchhoff summing junction where branch departure currents combine to charge the downstream capacitor $C_{B4}$.

## 4.5 Signal and Information Flow Architecture
Fig. 4.4 illustrates the information and feedback topology linking the physical plant, sensors, controllers, and actuators.

![Fig. 4.4. Information and Signal Flow Architecture: Replay vs. closed-loop sensing loops (Layers L1, L4, L5).](figures/fig_signal_flow.png){width=100%}

In the current project implementation, signal control operates in **open-loop replay mode**:
1. External arrival matrices $A(t)$ are fed to the discrete baseline simulation engine (`bl_simulate.m`).
2. The active controller (SITRA MPC, Webster, Actuated, or MaxPressure) computes the optimal phase sequence $u(k)$ based on observed queue states $q_{\text{seen}}(k)$.
3. The resulting gate switching matrix $g_b(t)$ is exported via `bl_export_for_simulink.m`.
4. The Simscape physical model (`SITRA_S5_Physical.slx`) imports $g_b(t)$ into `From Workspace` blocks, applying gate drives to the MOSFET switches to verify physical circuit tracking against model queue references.
5. In future deployment (Section 13), the feedback arrow will close: analog voltage sensors across $C_{B1}..C_{B4}$ will sample true capacitor potentials through an analog-to-digital converter (ADC), driving real-time controller updates in closed-loop operation.

## 4.6 Code Execution and Script Hierarchy
The unified software architecture is orchestrated from root script `run_master_all.m`. The execution flow is structured into three formal validation tracks:
- **Track 1: Mathematical Equivalent & Multi-Controller Suite:** Executes `run_part_b.m` (Part B: Electrical conservation and voltage equivalence verification), `run_part_c.m` (Part C: $5\,\mu\text{s}$ semiconductor dead-time testbench), and `run_part_d_integrated.m` (Part D: Integrated 4-controller S9 validation).
- **Track 2: Pure Physical Simscape Circuit & Hardware Suite:** Executes `test_SITRA_S5_Physical.m` (inventory audit, traffic equivalence, and power path regulation), `run_controllers_on_S5_physical.m` (32 physical circuit runs measuring capacitor clearance times across T5–T14), and `run_all_S6_S7.m` (capacitor parasitics, ESR compensation, and semiconductor switching loss/thermal modeling).
- **Track 3: Master Traffic Behavioral Simulation & Baselines:** Executes `run_SITRA_Integrated_Suite.m`, which triggers `run_SITRA_Master_Simulation.m` (frozen Part 8 MPC reference), `run_baseline_comparison.m` (Mode 1 full batch across T1–T14 $\times$ 4 controllers $\times$ 5 seeds), `test_power_electronic_circuit.m` (waveforms PE1–PE6), and `test_SITRA_Hardware_Simulation.m`.

## 4.7 End-to-End Data Flow Pipeline
Data flows through the codebase via structured transformations:
1. Scenario configurations in `bl_scenarios.m` define simulation duration $T$, seed arrays, demand profiles, and paired twin parameters.
2. `bl_make_arrivals.m` instantiates arrival matrix $A \in \mathbb{R}^{N \times 4}$ using linear congruential generators or Poisson sampling.
3. Fault events defined in `bl_inject.m` distort demand profiles ($A$), modify network capacities (`net.capFcn`), inject sensor noise ($q_{\text{seen}}$), or clamp gate drives ($g_{\text{eff}}$).
4. `bl_simulate.m` executes discrete time-stepping, calling the selected controller script (`bl_ctrl_*.m`) at every step and updating queues via `bl_plant_step.m`.
5. Simulation trajectories are exported to `Results/baselines/` as structured MAT files (`baseline_results.mat`) and summarized in CSV tables (`baseline_comparison.csv`, `baseline_runs_per_seed.csv`).
6. Workspace structures (`S5.arrivals`, `S5.gates`, `S5.capB`, `S5.q4max`) feed the Simscape physical model, which records physical voltages and currents into `controller_clearance_physical.csv` and generates publication figures.
