# 8. Simulation Description and Physical Testbed Architecture

This section details the empirical study site, physical Simscape circuit implementation, component parameters, scenario configurations, and simulation settings.

## 8.1 Study Site: SITRA Junction, Coimbatore
The study site is the SITRA (South India Textile Research Association) intersection situated along the Avinashi Road arterial corridor (National Highway 544) in Coimbatore, Tamil Nadu, India (Coordinates: $11.0305^\circ\text{ N}, 77.0345^\circ\text{ E}$). 

![Fig. 8.1. Empirical Study Site: SITRA Junction on Avinashi Road arterial corridor, Coimbatore, Tamil Nadu, India. (Base map © OpenStreetMap contributors).](figures/fig_site_map.png){width=100%}

As illustrated in Fig. 8.1, the intersection manages three conflicting upstream approaches that merge into a single downstream arterial:
- **Branch 1 (B1):** Avinashi Road Eastbound, carrying heavy arterial transit from Hope College toward the airport bypass.
- **Branch 2 (B2):** Kalapatti Road, carrying intense commuter traffic from northern IT parks and residential zones.
- **Branch 3 (B3):** Airport Road (Civil Aerodrome Road), feeding traffic from Coimbatore International Airport terminal.
- **Branch 4 (B4):** Avinashi Road onward to Goldwins, functioning as the downstream bottleneck link.

Table 8.1: Site-to-Model Structural Cross-Reference. Source: OpenStreetMap survey, `createNetwork.m`, `SITRA_S5_Physical.slx`.

| Road / Physical Element on Map | Network Model Element | Circuit Element (Block Name in `SITRA_S5_Physical.slx`) | Nominal Value / Capacity |
|---|---|---|---|
| Avinashi Road (Eastbound from Hope College) | Upstream Approach Branch 1 | Storage Capacitor `C_B1`, Current Source `SPS_arr_B1` | $C_1 = 0.65\text{ veh/s}$ ($2340\text{ veh/h}$), $1.0\text{ F}$ |
| Kalapatti Road (Southbound to Junction) | Upstream Approach Branch 2 | Storage Capacitor `C_B2`, Current Source `SPS_arr_B2` | $C_2 = 0.35\text{ veh/s}$ ($1260\text{ veh/h}$), $1.0\text{ F}$ |
| Airport Road (Northbound from Terminal) | Upstream Approach Branch 3 | Storage Capacitor `C_B3`, Current Source `SPS_arr_B3` | $C_3 = 0.25\text{ veh/s}$ ($900\text{ veh/h}$), $1.0\text{ F}$ |
| Avinashi Road (Eastbound toward Goldwins) | Downstream Bottleneck Link B4 | Storage Capacitor `C_B4`, Exit Sink `SPS_exit` | $C_4 = 0.45\text{ veh/s}$ ($1620\text{ veh/h}$), $1.0\text{ F}$ |
| Intersection Box / Conflict Zone | Kirchhoff Summing Node | Common Ground Reference & Summing Bus Node | KCL Summing Node ($\sum I_{\text{in}} = \sum I_{\text{out}}$) |
| Physical Traffic Signal Heads (LED R/Y/G) | Actuation Gate Signals | High-Side MOSFET Channels `Q_B1`, `Q_B2`, `Q_B3` | $24\,\Omega$ resistive load ($1.0\text{ A}$ nominal current) |
| Vehicle Presence Detectors | Queue Length Sensing | Voltage Sensors `V_B1`, `V_B2`, `V_B3`, `V_B4` | $1.0\text{ V} = 1.0\text{ vehicle}$ ($0\text{–}15\text{ V}$ range) |

---

## 8.2 Physical Simscape Model Architecture (`SITRA_S5_Physical.slx`)
The physical circuit is constructed in MathWorks Simscape (Electrical Foundation Library) with strictly **zero software code blocks, zero MATLAB Function blocks, and zero S-Function blocks** inside physical subsystems.

![Fig. 8.2. Simscape Physical Top-Level Schematic: Traffic Equivalent Circuit (Layer L1) and Power Path (Layers L2, L3, L4).](figures/fig23_s5_schematic_top.png){width=100%}

Fig. 8.2 illustrates the top-level schematic of `SITRA_S5_Physical.slx`. The model is structured into two primary physical subsystems:
1. `Traffic_Equivalent_Circuit`: Implements the four 1 F capacitor branches, seven controlled current sources/sinks, four voltage sensors, and physical spill-back comparator logic.
2. `Power_Path`: Implements the 230 V AC grid utility feed, transformer, 4-diode rectifier bridge, 2200 µF DC-link, closed-loop buck DC-DC converter, and three MOSFET driver channels.

![Fig. 8.3. Simscape Traffic Equivalent Circuit Subsystem: 4-Capacitor Network and Controlled Current Sinks.](figures/fig24_s5_schematic_traffic.png){width=100%}

Fig. 8.3 shows the internal architecture of the `Traffic_Equivalent_Circuit` subsystem. The four storage capacitors ($C_{B1}..C_{B4} = 1.0\text{ F}$) are grounded to a common electrical reference. Inflow currents are injected into capacitors $C_{B1}..C_{B3}$ by three Simscape Controlled Current Sources (`CCS_arr_B1` through `CCS_arr_B3`), driven by external arrival matrices via Simulink-PS Converters. Departures are extracted from $C_{B1}..C_{B3}$ by three Controlled Current Sinks (`CCS_dep_B1` through `CCS_dep_B3`), which discharge directly into downstream capacitor $C_{B4}$. Downstream discharge from $C_{B4}$ is governed by sink `CCS_exit`.

---

## 8.3 Component Ratings and Hardware Candidate Table
In strict compliance with Rule 0.2, all power-electronic component ratings in `S5_physical_params.m` represent functional simulation placeholders to be finalized in hardware procurement stage S12. Table 8.2 details every physical component, its Simscape library block, simulation value, hardware candidate (with verified datasheet URL) or S12 sizing rule, engineering selection rationale, and traffic domain equivalent.

Table 8.2: Comprehensive Physical Component Inventory and Hardware Mapping. Source: `S5_physical_params.m`, `build_SITRA_S5_Physical.m`.

| Ref | Component | Type / Simscape Block | Value (Params) | Real-Hardware Candidate / Stage S12 | Why Chosen (Engineering Design Reason) | What It Represents in Traffic Domain |
|---|---|---|---|---|---|---|
| $C_{B1}..C_{B4}$ | Queue Storage Capacitors | `fl_lib/Electrical/Electrical Elements/Capacitor` | $1.0\text{ F}$, initial $0\text{ V}$ | Normalized mathematical fact (not a commercial part) | Establishes exact $1\text{ V} = 1\text{ veh}$ electrostatic charge duality | Approach vehicular queues $q_1(t)..q_4(t)$ |
| $V_{\text{AC}}$ | Utility Grid AC Source | `fl_lib/Electrical/Electrical Sources/AC Voltage Source` | $230\text{ V}_{\text{rms}}$, $50\text{ Hz}$ | Indian Municipal Grid Supply (TANGEDCO single-phase) | Standard low-voltage utility distribution in Tamil Nadu | Exogenous municipal electrical utility supply |
| $T_1$ | Step-Down Transformer | `fl_lib/Electrical/Electrical Elements/Ideal Transformer` | $n = 36 / 230 \approx 0.1565$ | S12: Sized for $100\text{ VA}$, $230\text{V}/36\text{V}_{\text{rms}}$, $50\text{ Hz}$ chassis transformer | Yields $47.3\text{ V}$ peak rectified DC to provide buck headroom | Substation power step-down interface |
| $D_1..D_4$ | Bridge Rectifier Diodes | `fl_lib/Electrical/Electrical Elements/Diode` | $V_f = 0.8\text{ V}$, $R_{\text{on}} = 10\,\text{m}\Omega$ | Vishay 2W10G (1000V, 2A Full-Wave Bridge, datasheet: `https://www.vishay.com/docs/88503/2w005g.pdf`) [S12 candidate] | Converts 50 Hz AC to DC with low conduction loss | Unregulated raw power generation |
| $C_{\text{dc}}$ | Bulk DC-Link Capacitor | `fl_lib/Electrical/Electrical Elements/Capacitor` | $2200\,\mu\text{F}$, $R_{\text{esr}} = 50\,\text{m}\Omega$ | Nichicon UVY1J222MHD (63V, 2200uF, datasheet: `https://www.nichicon.co.jp/en/products/aluminum-electrolytic/uvy/`) [S12 candidate] | Limits 100 Hz rectified ripple to $\Delta V_{\text{DC}} < 2.5\text{ V}$ at 1 A load; simulation confirms mean $47.31\text{ V}$ | Intermediate energy buffer (akin to downstream B4 storage) |
| $R_{\text{bleed}}$ | DC-Link Safety Bleeder | `fl_lib/Electrical/Electrical Elements/Resistor` | $10.0\,\text{k}\Omega$ | S12: 5W metal oxide safety discharge resistor | Safely discharges 2200 µF DC-link below $50\text{ V}$ in $< 60\text{ s}$ upon AC disconnect | Energy dissipation fail-safe |
| $Q_{\text{buck}}$ | Buck Switching MOSFET | `fl_lib/Electrical/Electrical Elements/N-Channel MOSFET` | $R_{\text{ds(on)}} = 44\,\text{m}\Omega$ | Vishay IRF540N (100V, 33A, TO-220AB, datasheet: `https://www.vishay.com/docs/91021/91021.pdf`) [S12 candidate] | Low conduction losses at 10 kHz switching frequency | Primary DC-DC voltage regulation valve |
| $D_{\text{free}}$ | Buck Freewheeling Diode | `fl_lib/Electrical/Electrical Elements/Diode` | $V_f = 0.5\text{ V}$, $R_{\text{on}} = 10\,\text{m}\Omega$ | STMicroelectronics STPS10H100D (100V, 10A Schottky, datasheet: `https://www.st.com/resource/en/datasheet/stps10h100d.pdf`) [S12 candidate] | Ultra-fast recovery Schottky preventing inductive voltage spikes | Continuous inductor current freewheeling |
| $L_{\text{buck}}$ | Buck Choke Inductor | `fl_lib/Electrical/Electrical Elements/Inductor` | $2.0\text{ mH}$, $R_{\text{dc}} = 0.1\,\Omega$ | S12: Toroidal ferrite power inductor rated for 3A continuous | Limits peak-to-peak inductor ripple current to $\Delta I_L < 0.3\text{ A}$ at 10 kHz | Energy smoothing choke |
| $C_{\text{out}}$ | Bus Output Capacitor | `fl_lib/Electrical/Electrical Elements/Capacitor` | $3300\,\mu\text{F}$, $R_{\text{esr}} = 30\,\text{m}\Omega$ | Panasonic EEU-FC1V332 (35V, 3300uF, Low ESR, datasheet: `https://industrial.panasonic.com/cdbs/www-data/pdf/RDF0000/ABA0000C1209.pdf`) [S12 candidate] | Suppresses bus transient voltage droop during 1 A load steps | 24 V signal-head bus energy reservoir |
| $R_{\text{damp}}, C_{\text{damp}}$ | Bus Damping Network | Linear Resistor & Capacitor | $1.0\,\Omega$, $4.7\text{ mF}$ | S12: RC snubber damping network | Damps LC resonant ringing ($Q < 1.0$) during MOSFET channel transitions | Bus transient oscillation suppression |
| $Q_{\text{B1}}..Q_{\text{B3}}$ | Channel MOSFET Switches | `fl_lib/Electrical/Electrical Elements/N-Channel MOSFET` | $R_{\text{ds(on)}} = 17.5\,\text{m}\Omega$ | Infineon IRFZ44N (55V, 49A, TO-220, datasheet: `https://www.infineon.com/dgdl/Infineon-IRFZ44N-DataSheet-v01_01-EN.pdf?fileId=5546d462533600a40153563b3a9f220b`) [S12 candidate] | Minimal voltage drop ($< 0.02\text{ V}$) when switching 1 A signal head load | Signal-head driver switch (green light actuation) |
| $R_{\text{load1}}..R_{\text{load3}}$ | Signal Head Resistive Loads | `fl_lib/Electrical/Electrical Elements/Resistor` | $24.0\,\Omega$ ($1.0\text{ A}$ at $24\text{ V}$) | S12: Industrial 24V LED signal head module (24W rating) | Replicates electrical load of standard commercial 24V LED traffic signals | Physical traffic signal lamp head illumination |
| $CCS_{\text{arr}}, CCS_{\text{dep}}$ | Controlled Current Sources/Sinks | `fl_lib/Electrical/Electrical Sources/Controlled Current Source` | Dynamic flow inputs | Pure simulation ideal transfer block | Enforces exact volumetric vehicle flow rates into/out of capacitors | Vehicle arrival inflows and stop-line departures |
| $VS_{1}..VS_{4}$ | Channel Voltage Sensors | `fl_lib/Electrical/Electrical Sensors/Voltage Sensor` | High impedance ($> 10^9\,\Omega$) | S12: Isolated differential operational amplifier (e.g., TI AMC1301) | Senses capacitor potentials without drawing leakage charge | Queue length detection sensors (stop-line loops/cameras) |

---

## 8.4 Traffic Benchmark Scenarios (T1–T14)
To benchmark performance across the full operational spectrum, fourteen distinct scenarios are evaluated. Each clearance scenario (T5–T14) is paired with a strictly defined "no-congestion" twin run sharing identical random arrival seeds.

Table 8.3: Benchmark Traffic Scenario Definitions and Paired Twin Configurations. Source: `FLAT/baselines/bl_scenarios.m`.

| Scenario ID | Scenario Name | Duration $T$ | Seed / Sampling | Demand Profile & Injected Events | Paired Twin Configuration (Clearance Baseline) | Primary Engineering Purpose |
|---|---|---|---|---|---|---|
| **T1** | Low Demand | $900\text{ s}$ | 5 seeds (101–105) | Steady low inflow: $\boldsymbol{\lambda} = [0.05, 0.03, 0.02]\text{ veh/s}$ | N/A (Steady state, no event) | Undersaturated steady-state baseline ($v/c < 0.25$) |
| **T2** | Moderate Demand | $900\text{ s}$ | 5 seeds (101–105) | Steady moderate inflow: $\boldsymbol{\lambda} = [0.10, 0.07, 0.05]\text{ veh/s}$ | N/A (Steady state, no event) | Normal daytime traffic condition ($v/c \approx 0.50$) |
| **T3** | High Demand | $900\text{ s}$ | 5 seeds (101–105) | Steady high inflow: $\boldsymbol{\lambda} = [0.20, 0.12, 0.08]\text{ veh/s}$ | N/A (Steady state, no event) | Heavy peak-hour flow approaching capacity ($v/c \approx 0.85$) |
| **T4** | Oversaturated | $900\text{ s}$ | 5 seeds (101–105) | Oversaturated inflow: $\boldsymbol{\lambda} = [0.35, 0.20, 0.15]\text{ veh/s}$ | N/A (Steady state, no event) | Extreme bottleneck demand exceeding total junction capacity |
| **T5** | Step Demand | $900\text{ s}$ | 5 seeds (101–105) | Low for $t < 300\text{ s}$, high step ($0.25\text{ veh/s}$) for $300\le t < 600\text{ s}$, moderate for $t \ge 600\text{ s}$ | Moderate demand for $t \ge 300\text{ s}$ (high step removed) | Step-down recovery after temporary 5-minute overload |
| **T6** | Part 8 Surge (Deterministic) | $600\text{ s}$ | Seed 0 (Deterministic) | Base $\boldsymbol{\lambda} = [0.10, 0.07, 0.05]$; B1 surge to $0.30\text{ veh/s}$ during $t \in [200, 400]\text{ s}$ | Constant base demand ($0.10\text{ veh/s}$) for full $600\text{ s}$ | Exact reproduction of frozen Part 8 reference surge |
| **T7** | Part 8 Surge (Poisson) | $600\text{ s}$ | 5 seeds (101–105) | Identical to T6, but with stochastic Poisson vehicle arrivals | Identical Poisson arrivals without the B1 surge | Statistical surge clearance under stochastic arrivals |
| **T8** | Congested Start | $900\text{ s}$ | 5 seeds (101–105) | Moderate arrivals with initial queue backlog: $\mathbf{q}_0 = [25, 15, 10, 0]\text{ veh}$ | Moderate arrivals with zero initial queue ($\mathbf{q}_0 = \mathbf{0}$) | Large-scale initial backlog dissipation capability |
| **T9** | Incident on Branch 1 | $900\text{ s}$ | 5 seeds (101–105) | Moderate arrivals; B1 capacity dropped by $50\%$ ($C_1 = 0.325\text{ veh/s}$) for $t \in [200, 400]\text{ s}$ | Moderate arrivals with constant normal capacity ($C_1 = 0.65$) | Recovery from temporary lane closure / stop-line breakdown |
| **T10** | Downstream Blockage (Spill-Back) | $900\text{ s}$ | 5 seeds (101–105) | Moderate arrivals; B4 exit capacity dropped by $50\%$ ($C_4 = 0.225$), B4 clamp at $q_4 \ge 15\text{ veh}$ | Moderate arrivals with normal B4 capacity ($C_4 = 0.45$) | Response to downstream link gridlock and spill-back clamp |
| **T11** | Platoon Arrivals on Branch 2 | $900\text{ s}$ | 5 seeds (101–105) | Moderate arrivals; B2 receives arrival pulse train ($3\text{ veh}$ every $15\text{ s}$) for $t \in [200, 400]\text{ s}$ | Moderate arrivals without the B2 arrival pulse train | Adaptation to coordinated upstream green wave vehicle bursts |
| **T12** | Sensor Stuck on Branch 1 | $900\text{ s}$ | 5 seeds (101–105) | Moderate arrivals; B1 detector frozen at its $t=200\text{ s}$ reading for all $t \ge 200\text{ s}$ | Moderate arrivals with true uncorrupted detector readings | Controller vulnerability to frozen / failed queue detectors |
| **T13** | Gaussian Sensor Noise (All Branches) | $900\text{ s}$ | 5 seeds (101–105) | Moderate arrivals; zero-mean Gaussian noise ($\sigma = 2.0\text{ veh}$) added to $q_{\text{seen}, 1}..q_{\text{seen}, 3}$ | Moderate arrivals with true uncorrupted detector readings | Robustness to noisy optical cameras or loop detector errors |
| **T14** | Signal Head Stuck-Off on Branch 3 | $900\text{ s}$ | 5 seeds (101–105) | Moderate arrivals; Branch 3 gate drive forced low ($g_3 = 0$) for $t \in [200, 400]\text{ s}$ | Moderate arrivals with fully functional gate actuation | Fail-safe handling of driver MOSFET channel burn-out |

---

## 8.5 Simulation Settings and Reproduction Protocols
All simulations were executed within the following software and computing environment:
- **Environment:** 64-bit Windows 11 Enterprise, MATLAB Version 24.2 (R2024b), Simulink Version 24.2, Simscape Version 24.2, Simscape Electrical Version 24.2.
- **Microprocessor Platform:** Intel Core i7-13700H CPU @ 2.40 GHz (14 cores, 20 threads), 32 GB DDR5 RAM, 1 TB NVMe SSD storage.
- **Numerical Solver Parameters:**
  - Traffic Baseline Model (`bl_simulate.m`): Forward Euler fixed-step integration, step size $\Delta t = 1.0\text{ s}$.
  - Simscape Physical Circuit (`SITRA_S5_Physical.slx`): Variable-step differential algebraic equation solver `daessc` (with `ode23t` fallback), $\text{RelTol} = 1.0\times 10^{-6}$, $\text{AbsTol} = 1.0\times 10^{-9}$, $\text{MaxStep} = 0.05\text{ s}$.
  - Power Path Subsystem Local Solver: Backward Euler discrete solver, local sample time $T_{s, \text{local}} = 2.0\,\mu\text{s}$.
  - Dead-Time Testbench (`SITRA_Deadtime_Testbench.slx`): Fixed-step discrete solver, step size $\Delta t_{\text{sim}} = 1.0\,\mu\text{s}$.
- **Reproduction Protocol:** The entire simulation, benchmarking, and figure generation suite is reproduced by executing `run_master_all.m` from the root repository directory. Track 1 executes in $4.2\text{ s}$, Track 2 executes in $78.4\text{ s}$, and Track 3 executes in $38.6\text{ s}$ (total wall-clock runtime $\approx 121.2\text{ s}$).
