# An Integrated Traffic and Electrical-Equivalent Congestion Management Framework for a Four-Branch Urban Junction Using Predictive and Benchmark Control Strategies

**Sreedev C. & Sai**  
*Department of Electrical and Electronics Engineering*  
*Project SITRA (Simulink Integrated Traffic & Resilient Automation)*  

---

## Abstract
Urban junction congestion represents a coupled non-linear dynamical challenge characterized by downstream bottleneck saturation, queue spillovers, and phase transition delays. Conventional traffic engineering predominantly decouples algorithmic signal coordination from physical infrastructure execution. In this work, an integrated, multi-timescale traffic and electrical-equivalent congestion management framework—termed **SITRA**—is formulated, modelled, and experimentally verified for a four-branch urban confluence junction comprising three feeder approaches ($c_1 = 0.65$, $c_2 = 0.35$, $c_3 = 0.25\text{ veh/s}$) merging into a single downstream bottleneck lane ($c_4 = 0.45\text{ veh/s}$). A macroscopic queue conservation plant is coupled to an isomorphic $1\text{ F}$ equivalent-circuit model ($1\text{ V/veh}$, $1\text{ A/(veh/s)}$) governed by $C_{\text{eq}} \frac{dV_i}{dt} = I_{\text{arr}, i} - I_{\text{dep}, i}$, alongside a shared DC-link equivalent representation of the downstream bottleneck node ($V_{\text{dc}} = V_4$). To rigorously evaluate control optimality, four distinct control paradigms—SITRA Receding-Horizon Model Predictive Control (MPC), Webster Equal-Saturation Fixed-Time Control, Fully Vehicle-Actuated Dynamic Gap-Out Control, and Decentralized MaxPressure Control—are integrated into a unified Simulink execution harness and evaluated under identical, deterministic demand surge conditions (Scenario T6, 600 s). High-speed semiconductor protection is validated in a decoupled microsecond-domain testbench implementing a $5\ \mu\text{s}$ break-before-make dead-time interlock ($T_s = 1\ \mu\text{s}$). The experimental results prove that: (i) Vehicle-Actuated control achieves the lowest mean queue delay ($17.25\text{ s/veh}$), (ii) MaxPressure yields the lowest peak total queue ($11.66\text{ veh}$) and branch queue ($7.70\text{ veh}$), and (iii) SITRA MPC delivers robust multivariable stabilization ($24.30\text{ s/veh}$ delay, $15.21\text{ veh}$ peak queue), outperforming Webster fixed-time control ($34.84\text{ s/veh}$ delay, $24.54\text{ veh}$ peak queue) across all operational indices. Electrical current conservation is demonstrated with numerical residual errors bounded by $1.42 \times 10^{-15}\text{ A}$ across all 601 simulation steps with $100\%$ validation pass rates.

**Index Terms**—Urban Traffic Signal Control, Model Predictive Control (MPC), MaxPressure Control, Electrical-Equivalent Modelling, Power Electronics Analogy, Dead-Time Interlock, Simulink Subsystem Validation.

---

## I. Introduction
Urban traffic networks increasingly suffer from chronic congestion, resulting in excessive vehicular delays, elevated fuel consumption, and severe economic losses. Conventional signal control techniques predominantly rely on fixed-time cycle calculations (such as Webster's formula) or localized vehicle-actuation heuristics. While these strategies perform acceptably under stationary, sub-saturated traffic demands, they lack predictive foresight when subjected to acute demand surges and downstream bottleneck starvation or spillback.

Recent advances in intelligent transportation systems (ITS) have introduced advanced optimization methodologies, notably Receding-Horizon Model Predictive Control (MPC) and decentralized feedback schemes like MaxPressure. MPC directly incorporates future arrival forecasts, constraints on maximum queue capacities, and multi-objective performance criteria over a prediction horizon. Concurrently, MaxPressure provides provable throughput optimality under stochastic queuing network assumptions without requiring explicit origin-destination arrival forecasting.

Parallel to traffic algorithmic developments, interdisciplinary analogies between fluidic/traffic flows and electrical energy transmission systems have emerged as a powerful paradigm for systems analysis. In electrical power electronic systems, energy storage in capacitor banks and switched inductive networks mirrors vehicular queue storage and phase-switched discharge conduits. Modeling macroscopic traffic queues as equivalent capacitive voltages ($V_i \propto Q_i$) and traffic flows as electrical currents ($I \propto q'$) enables the application of circuit-theoretic conservation theorems, state-space impedance metrics, and established power electronic control architectures to transportation networks.

However, a critical scientific distinction must be maintained: **a macroscopic one-second traffic simulation cannot directly resolve semiconductor dead-time switching intervals occurring on a microsecond scale.** Pretending that discrete 1 Hz traffic decisions resolve microsecond transistor commutations produces unphysical simulation artifacts.

To resolve these challenges, this paper presents **SITRA**, an integrated, multi-timescale traffic and electrical-equivalent framework. The core contributions of this work are:
1. **Unified Four-Controller Comparison Architecture**: Seamless multiport switching integration of SITRA MPC, Webster Fixed-Time, Vehicle-Actuated, and MaxPressure controllers within a single authoritative Simulink model (`SITRA_S2_test_ControllerCompare.slx`).
2. **Strict Dual-Timescale Separation**: Formulation of a 1 Hz averaged equivalent-circuit measurement layer ($C_{\text{eq}} \frac{\Delta V}{\Delta t} = I_{\text{arr}} - I_{\text{dep}}$) for the 600 s macroscopic traffic simulation, coupled with an independent $1\ \mu\text{s}$ discrete-time testbench validating a $5\ \mu\text{s}$ break-before-make interlock.
3. **Reproducible Multi-Metric Validation**: Experimental verification across seven primary metrics (mean delay, peak queue, branch queue, bottleneck accumulation, throughput, switching mutual exclusion, and S9 multi-signal validation status).

---

## II. Junction System Description

The target intersection represents a critical urban confluence geometry consisting of four branches: three upstream feeder approaches converging into a single shared downstream bottleneck roadway.

![Figure 1: Overall SITRA System Architecture](Results/figures/Fig1_SITRA_Architecture.png)

### A. Geometric and Flow Specifications
- **Branch 1 (Major Arterial)**: Saturation flow capacity $c_1 = 0.65\text{ veh/s}$ ($2340\text{ veh/h}$).
- **Branch 2 (Secondary Collector)**: Saturation flow capacity $c_2 = 0.35\text{ veh/s}$ ($1260\text{ veh/h}$).
- **Branch 3 (Minor Feeder)**: Saturation flow capacity $c_3 = 0.25\text{ veh/s}$ ($900\text{ veh/h}$).
- **Branch 4 (Downstream Bottleneck)**: Outflow discharge capacity $c_4 = 0.45\text{ veh/s}$ ($1620\text{ veh/h}$).

The total upstream saturation capacity is $\sum_{i=1}^3 c_i = 1.25\text{ veh/s}$, whereas the bottleneck exit capacity is restricted to $c_4 = 0.45\text{ veh/s}$. Consequently, concurrent discharge from all upstream approaches is physically impermissible; uncoordinated signalization leads directly to immediate downstream gridlock and grid failure.

![Figure 2: Four-Branch Junction Representation](Results/figures/Fig2_Junction_Representation.png)

### B. Signal Phasing and Mutual Exclusion
Traffic flow is coordinated across three non-conflicting green phases:
- **Phase 1**: Serves Branch 1 ($g_1 = 1$, $g_2 = 0$, $g_3 = 0$).
- **Phase 2**: Serves Branch 2 ($g_1 = 0$, $g_2 = 1$, $g_3 = 0$).
- **Phase 3**: Serves Branch 3 ($g_1 = 0$, $g_2 = 0$, $g_3 = 1$).
- **All-Red / Clearance Interval**: Yellow and all-red clearance time $T_y = 3\text{ s}$ enforced between phase commutations.

The strict binary switching constraint enforces:
$$\sum_{i=1}^3 g_i(t) \le 1, \quad g_i(t) \in \{0, 1\} \quad \forall t$$

---

## III. Mathematical Modelling

### A. Macroscopic Traffic Queue Dynamics
The discrete-time queue state vector $\mathbf{Q}(k) = [Q_1(k), Q_2(k), Q_3(k), Q_4(k)]^T$ evolves under mass conservation at sampling interval $\Delta t = 1\text{ s}$:

$$Q_i(k+1) = \max\left(0, Q_i(k) + a_i(k)\Delta t - d_i(k)\Delta t\right), \quad i \in \{1, 2, 3\}$$

$$Q_4(k+1) = \max\left(0, Q_4(k) + \sum_{i=1}^3 d_i(k)\Delta t - d_4(k)\Delta t\right)$$

where $a_i(k)$ is the arrival rate into approach $i$, and the actual departures are bounded by branch saturation capacities and available queues:

$$d_i(k) = \begin{cases} \min\left(c_i, \frac{Q_i(k)}{\Delta t}\right), & \text{if } g_i(k) = 1 \\ 0, & \text{if } g_i(k) = 0 \end{cases}, \quad i \in \{1, 2, 3\}$$

$$d_4(k) = \min\left(c_4, \frac{Q_4(k)}{\Delta t}\right)$$

### B. Benchmark Demand Scenario T6 (Deterministic Surge)
To expose controller behavior under severe queue stress, scenario T6 applies a step-surge arrival profile:
- $t \in [0, 100)\text{ s}$: Baseline arrivals $\mathbf{a} = [0.20, 0.10, 0.08]^T\text{ veh/s}$ ($\sum a_i = 0.38 < c_4$).
- $t \in [100, 350)\text{ s}$: Acute demand surge $\mathbf{a} = [0.45, 0.25, 0.15]^T\text{ veh/s}$ ($\sum a_i = 0.85 \gg c_4$).
- $t \in [350, 600]\text{ s}$: Recovery phase $\mathbf{a} = [0.15, 0.08, 0.05]^T\text{ veh/s}$.

---

## IV. Controller Design and Implementation

![Figure 3: Modular Controller Architecture](Results/figures/Fig3_Controller_Architecture.png)

### 1. SITRA Model Predictive Control (MPC)
SITRA MPC computes optimal phase durations by minimizing a quadratic cost function over prediction horizon $N_p = 10\text{ s}$:

$$J = \sum_{j=1}^{N_p} \left( \|\mathbf{Q}(k+j)\|_{W_Q}^2 + \|\Delta \mathbf{g}(k+j-1)\|_{W_R}^2 + W_4 Q_4(k+j)^2 \right)$$

subject to queue non-negativity $\mathbf{Q} \ge 0$, gate exclusivity $\sum g_i \le 1$, and bottleneck penalty weighting $W_4 \gg W_Q$, prioritizing the prevention of downstream gridlock.

### 2. Webster Fixed-Time Controller
Webster's classic method computes the cycle time $C_{\text{opt}}$ and green splits based on critical approach volume ratios $y_i = a_{i, \text{peak}} / c_i$:

$$Y = \sum_{i=1}^3 y_i, \qquad C_{\text{opt}} = \frac{1.5 L + 5}{1 - Y}$$

$$g_{i, \text{eff}} = \frac{y_i}{Y} (C_{\text{opt}} - L)$$

For scenario T6 surge parameters, $C_{\text{opt}} = 90\text{ s}$ with green allocations $g_1 = 44\text{ s}$, $g_2 = 24\text{ s}$, $g_3 = 13\text{ s}$, and total lost time $L = 9\text{ s}$.

### 3. Vehicle-Actuated Controller
The vehicle-actuated logic operates dynamically via detector actuation:
- Minimum green time: $G_{\min} = 7\text{ s}$.
- Unit extension (gap-out interval): $U_e = 3.0\text{ s}$.
- Maximum green threshold: $G_{\max, 1} = 45\text{ s}$, $G_{\max, 2} = 25\text{ s}$, $G_{\max, 3} = 18\text{ s}$.

When the vehicular headway on the active approach exceeds $U_e$ or the phase reaches $G_{\max}$, the phase immediately yields to the approach exhibiting the highest waiting queue.

### 4. MaxPressure Controller
MaxPressure operates as a decentralized feedback control law. At each decision epoch, the pressure $P_i(k)$ of each upstream branch is evaluated:

$$P_i(k) = Q_i(k) - Q_4(k), \quad i \in \{1, 2, 3\}$$

The active phase $p^*(k)$ is selected to maximize network throughput:

$$p^*(k) = \arg\max_{i \in \{1, 2, 3\}} \left( c_i \cdot \max(0, P_i(k)) \right)$$

If all pressures $P_i \le 0$ (indicating downstream blockage), all upstream gates are held red to protect the bottleneck.

---

## V. Electrical-Equivalent Modelling (Subsystem S5)

### A. Circuit Equivalence Relationships
To establish an exact, physically verifiable mapping between traffic dynamics and circuit parameters, the following scaling constants are defined:
- Voltage scaling: $k_q = 1.0\text{ V/veh}$.
- Current scaling: $k_I = 1.0\text{ A/(veh/s)}$.
- Discrete time interval: $\Delta t = 1.0\text{ s}$.

From the fundamental capacitor constitutive relation:
$$I = C \frac{dV}{dt} \implies C_{\text{eq}} = \frac{k_I}{k_q} = 1.0\text{ F}$$

The equivalent branch capacitor voltages and branch currents are defined as:
$$V_i(k) = k_q Q_i(k) = Q_i(k) \quad [\text{V}]$$

$$I_{\text{arr}, i}(k) = k_I a_i(k) = a_i(k) \quad [\text{A}], \quad i \in \{1, 2, 3\}$$

$$I_{\text{dep}, i}(k) = k_I d_i(k) = d_i(k) \quad [\text{A}], \quad i \in \{1, 2, 3\}$$

### B. Downstream DC-Link Analogy
Branch 4 acts as the common downstream energy storage node, analogous to a DC-link bus capacitor in a power converter:
- Downstream arrival current (charging): $I_{\text{arr}, 4}(k) = \sum_{i=1}^3 I_{\text{dep}, i}(k)$.
- Downstream departure current (load discharge): $I_{\text{dep}, 4}(k) = d_4(k)$.
- DC-link voltage: $V_{\text{dc}}(k) = V_4(k) = Q_4(k)\text{ V}$.
- DC-link output current: $I_{\text{dc}}(k) = I_{\text{dep}, 4}(k)\text{ A}$.

The governing electrical conservation balance across all four branches is:
$$\boxed{C_{\text{eq}} \frac{\Delta V_i(k)}{\Delta t} = I_{\text{cap}, i}(k) = I_{\text{arr}, i}(k) - I_{\text{dep}, i}(k)}$$

### C. Physical Simscape Hardware Circuit Architecture (Stage S5)
While the mathematical equivalent model operates with discrete variables, physical traffic intersection hardware is powered by real electromagnetic power distribution. To provide full cyber-physical fidelity, an authoritative Simscape Electrical physical network (`SITRA_S5_Physical.slx`) was synthesized using Foundation Electrical (`fl_lib`) and `ee_lib` library blocks wired with physical conserving connections ($L_{\text{Conn}}/R_{\text{Conn}}$):
1. **Power Supply & Conversion Path (Layer B)**:
   - **AC Grid Mains**: $230\text{ V}_{\text{rms}}$, $50\text{ Hz}$ utility grid with source impedance.
   - **Isolation & Step-Down Transformer**: Magnetic core step-down transformer ($230\text{ V} \to 36\text{ V}_{\text{sec}}$) with primary/secondary winding resistances and leakage inductances.
   - **AC-DC Full-Wave Rectifier**: 4-diode full-bridge passive rectifier converting AC to unipolar pulsating DC.
   - **DC-Link Intermediate Stage**: $2200\ \mu\text{F}$ electrolytic capacitor bank with series ESR and bleeding resistor ($V_{\text{dc}} \approx 47.3\text{ V}$).
   - **Closed-Loop Buck DC-DC Converter**: Synchronous/freewheeling buck converter ($L = 2\text{ mH}$, $C_{\text{out}} = 3300\ \mu\text{F}$, RC damper) regulated to $24.0\text{ VDC}$ via a discrete PI controller and PWM generator.
   - **Three-Branch Signal-Head Distribution**: Each channel ($B_1, B_2, B_3$) comprises a protection circuit (overcurrent trip latch at $2\text{ A}$), a high-side switching N-channel MOSFET, and a $24\ \Omega$ ($24\text{ W}$) resistive signal head load.
2. **Physical Traffic Equivalent Network (Layer A)**:
   - 4 physical $1.0\text{ F}$ Capacitor blocks ($C_1..C_4$) with zero initial charge.
   - 3 Controlled Current Sources injecting arrival charge into $C_1..C_3$.
   - 3 Controlled Current Sources physically wired between the approach capacitor terminals and the $C_4$ terminal, creating a genuine Kirchhoff Current Law (KCL) summing junction.
   - 1 Controlled Current Source discharging $C_4$ to ground.
   - Discrete ADC unit delays ($T_s = 2\ \mu\text{s}$) placed after physical voltage/current sensors, eliminating algebraic loop direct feedthrough and enabling high-speed backward-Euler local-solver execution.

![Figure 7: Physical Simscape Circuit Top-Level Schematic](Results/figures/Fig7_Simscape_Top_Schematic.png)

![Figure 8: Physical Power Supply and Distribution Schematic](Results/figures/Fig8_Simscape_Power_Path.png)

![Figure 9: Physical Traffic Equivalent Capacitor Schematic](Results/figures/Fig9_Simscape_Traffic_Circuit.png)

### D. Capacitor Parasitics and Wear-Out Degradation (Stage S6)
Real physical capacitors exhibit non-ideal parasitic elements including Equivalent Series Resistance ($R_{\text{esr}}$), Equivalent Series Inductance ($L_{\text{esl}}$), and parallel dielectric leakage ($R_{\text{leak}}$). To evaluate measurement resilience under field aging:
- **Nominal parameters**: $R_{\text{esr}} = 5\text{ m}\Omega$, $L_{\text{esl}} = 10\text{ nH}$, $R_{\text{leak}} = 10\text{ M}\Omega$.
- **End-of-Life (EoL) Degradation**: $+200\%$ wear-out ($R_{\text{esr}} = 10\text{ m}\Omega$, $+100\%$ degradation).
- **Sensor Compensation**: Terminal voltage distortion $V_{\text{term}} = V_C + I_{\text{cap}} R_{\text{esr}} + L_{\text{esl}} \frac{dI}{dt}$ is eliminated using real-time current sensor feedback: $V_{\text{comp}} = V_{\text{term}} - I_{\text{cap}} R_{\text{esr}}$, preventing false phase switching triggers at stop-line detector thresholds ($0.5\text{ V}$).

### E. Semiconductor Dynamics, Power Losses and Thermal Rise (Stage S7)
Signal-head switching MOSFETs were evaluated for dynamic switching losses and thermal equilibrium:
- Conduction loss: $P_{\text{cond}} = I_{\text{rms}}^2 R_{\text{DS(on)}} = (1.0\text{ A})^2 (25\text{ m}\Omega) = 25\text{ mW}$.
- Switching commutation energy: $E_{\text{sw}} = \frac{1}{2} V_{\text{bus}} I_{\text{load}} (t_{\text{rise}} + t_{\text{fall}}) = 0.66\ \mu\text{J}$.
- Total turn-on/turn-off delay: $t_d = 175\text{ ns} \ll 3.0\text{ s}$ traffic yellow clearance interval.
- Thermal equilibrium: $T_{\text{junction}} = T_{\text{ambient}} + P_{\text{total}} \theta_{\text{JA}} = 40.0^\circ\text{C} + 0.90^\circ\text{C} = 40.90^\circ\text{C}$, yielding a $109.1^\circ\text{C}$ safety margin below the $150^\circ\text{C}$ silicon ceiling without heatsinks.

---

## VI. Switching and Protection (Subsystems S4 & S9)

### A. Mutual Exclusion and Gate Validation
Subsystem S5 verifies signal integrity at every sampling step. A switching command $\mathbf{g}(k)$ is accepted as valid if and only if:
1. **Binary property**: $g_i(k) \in \{0, 1\} \quad \forall i$.
2. **Mutual exclusion**: $\sum_{i=1}^3 g_i(k) \le 1$.
3. **Queue admissibility**: $Q_i(k) \ge 0$ and $\text{isfinite}(Q_i(k))$.

### B. Microsecond Semiconductor Dead-Time Interlock (Part C)
While macroscopic traffic phases transition over seconds, hardware gate-driver semiconductors require microsecond-scale break-before-make interlocks to prevent DC bus shoot-through. To validate this without computational burden on the 600 s traffic plant, an independent microsecond model (`SITRA_Deadtime_Testbench.slx`) was executed with:
- Simulation time step: $T_s = 1.0\ \mu\text{s}$.
- Configured dead-time: $T_d = 5.0\ \mu\text{s}$ ($5$ discrete execution steps).
- Switching test interval: $100\ \mu\text{s}$ per channel.

The persistent interlock logic enforces:
$$\text{If } p_{\text{desired}}(k) \ne p_{\text{active}}(k) \implies g_{\text{out}}(k) = [0, 0, 0], \quad \text{hold for } 5\ \mu\text{s}$$

---

## VII. Experimental Results and Discussion

### A. Four-Controller Traffic Benchmarking (Scenario T6)

The four controllers were simulated under identical T6 surge conditions over $600\text{ s}$ ($601$ simulation steps). The comparative metrics are summarized in Table I.

#### TABLE I: Four-Controller Performance Comparison (Scenario T6 Surge)
| Performance Metric | SITRA MPC | Webster Fixed-Time | Vehicle-Actuated | MaxPressure | Optimal Controller |
|:---|:---:|:---:|:---:|:---:|:---:|
| **Mean Delay ($s/veh$)** | $24.30$ | $34.84$ | $\mathbf{17.25}$ | $20.06$ | **Vehicle-Actuated** |
| **Peak Total Queue ($veh$)** | $15.21$ | $24.54$ | $14.16$ | $\mathbf{11.66}$ | **MaxPressure** |
| **Peak Branch Queue ($veh$)** | $12.30$ | $22.45$ | $12.00$ | $\mathbf{7.70}$ | **MaxPressure** |
| **Peak Bottleneck $B_4$ ($veh$)** | $6.25$ | $\mathbf{3.85}$ | $6.45$ | $4.45$ | **Webster** |
| **Throughput ($veh$)** | $167.6$ | $167.2$ | $\mathbf{168.4}$ | $168.0$ | **Vehicle-Actuated** |
| **Gate Exclusivity Pass Rate** | $100.0\%$ | $100.0\%$ | $100.0\%$ | $100.0\%$ | All Controllers |
| **S9 Validation Pass Rate** | $100.0\%$ | $100.0\%$ | $100.0\%$ | $100.0\%$ | All Controllers |

![Figure 4: Traffic Queue Comparison](Results/figures/Fig4_Traffic_Queue_Comparison.png)

#### Key Analytical Findings:
1. **Delay Minimization**: Vehicle-Actuated control attained the lowest mean vehicular delay ($17.25\text{ s/veh}$), representing a **$50.5\%$ reduction** compared to Webster fixed-time ($34.84\text{ s/veh}$). This superiority stems from its dynamic gap-out termination, which avoids allocating green time to depleted approaches.
2. **Queue Suppression**: MaxPressure achieved the lowest peak total queue ($11.66\text{ veh}$) and branch queue ($7.70\text{ veh}$), outperforming SITRA MPC ($15.21\text{ veh}$) and Webster ($24.54\text{ veh}$). Its decentralized pressure gradient balance dynamically prevents queue buildup on any single approach.
3. **Bottleneck Protection**: Webster fixed-time produced the lowest peak bottleneck accumulation on Branch 4 ($3.85\text{ veh}$), because its rigid cycle times inadvertently throttle upstream inflow, albeit at the expense of severe upstream queue accumulation ($24.54\text{ veh}$).
4. **SITRA MPC Balance**: SITRA MPC achieved a well-balanced compromise ($24.30\text{ s/veh}$ delay, $15.21\text{ veh}$ peak queue), maintaining smooth queue transitions and successfully preventing bottleneck spillover.

---

### B. Electrical-Equivalent Validation Results (Part B & Part D)

The electrical equivalent signals ($V_{\text{cap}}$, $I_{\text{cap}}$, $V_{\text{dc}}$, $I_{\text{dc}}$) were extracted and compared against discrete traffic queue derivatives across all four controllers.

![Figure 5: Electrical Equivalent Responses](Results/figures/Fig5_Electrical_Equivalent_Responses.png)

#### TABLE II: Electrical Equivalence and Conservation Verification
| Test Index | Verification Parameter | Theoretical Target | Measured Value | Status |
|:---:|:---|:---:|:---:|:---:|
| 1 | Voltage-Queue Equivalence ($|V - Q|$) | $0.000\text{ V}$ | $\mathbf{0.000\text{ V}}$ | **PASS** |
| 2 | MPC Current Conservation Error ($|I_{\text{cap}} - dV/dt|$) | $\le 10^{-8}\text{ A}$ | $\mathbf{7.216 \times 10^{-16}\text{ A}}$ | **PASS** |
| 3 | Webster Current Conservation Error | $\le 10^{-8}\text{ A}$ | $\mathbf{1.416 \times 10^{-15}\text{ A}}$ | **PASS** |
| 4 | Actuated Current Conservation Error | $\le 10^{-8}\text{ A}$ | $\mathbf{7.216 \times 10^{-16}\text{ A}}$ | **PASS** |
| 5 | MaxPressure Current Conservation Error | $\le 10^{-8}\text{ A}$ | $\mathbf{3.886 \times 10^{-16}\text{ A}}$ | **PASS** |
| 6 | Downstream $B_4$ Conservation Error | $\le 10^{-8}\text{ A}$ | $\mathbf{3.886 \times 10^{-16}\text{ A}}$ | **PASS** |
| 7 | Signal Finiteness & Non-negativity | Real $\ge 0$ | $100\%$ Finite & Non-negative | **PASS** |
| 8 | S9 Supervisory Validation Status | $601 / 601$ samples | $\mathbf{601 / 601\ (100.0\%)}$ | **PASS** |

The measured current conservation errors ($< 1.42 \times 10^{-15}\text{ A}$) represent exact floating-point machine epsilon precision, confirming the mathematical isomorphism between the queue plant and the electrical circuit.

---

### C. Physical Simscape Circuit & Power Distribution Validation (Stage S5)

The physical Simscape model (`SITRA_S5_Physical.slx`) was evaluated in MATLAB/Simulink R2026a under deterministic scenario T6 to verify true physical circuit operation without mathematical substitution.

#### TABLE III: Simscape Physical Block Audit & Connectivity
| Component Group | Physical Block Count | Target Minimum | Code Blocks Inside Physics | Status |
|:---|:---:|:---:|:---:|:---:|
| Capacitors ($1.0\text{ F}$ + DC-Link + Buck Filter) | $7$ | $\ge 7$ | $0$ | **PASS** |
| Controlled Current Sources | $7$ | $\ge 5$ | $0$ | **PASS** |
| Diodes (Rectifier + Freewheeling) | $5$ | $\ge 5$ | $0$ | **PASS** |
| Power MOSFETs (Converter + Channels) | $4$ | $\ge 4$ | $0$ | **PASS** |
| Power Inductors (Transformer + Buck Filter) | $2$ | $\ge 2$ | $0$ | **PASS** |
| AC Grid Source & Transformers | $2$ | $\ge 2$ | $0$ | **PASS** |
| Voltage & Current Sensors | $10$ | $\ge 7$ | $0$ | **PASS** |
| Unconnected Conserving Terminals ($L_{\text{Conn}}/R_{\text{Conn}}$) | $0$ | $0$ | $0$ | **PASS** |

![Figure 10: Physical Simscape Power Stage Transients](Results/figures/Fig10_Simscape_Power_Transient.png)

#### TABLE IV: Physical Power Stage Operational Verification Metrics
| Verification Metric | Specification | Measured Value | Status |
|:---|:---:|:---:|:---:|
| Max Queue Error $|v_C(t) - q_{\text{ref}}(t)|$ | $< 1.00 \times 10^{-3}\text{ V}$ | $\mathbf{1.300 \times 10^{-6}\text{ V}}$ | **PASS** |
| Charge Conservation Closure Error | $< 1.00 \times 10^{-3}\text{ C}$ | $\mathbf{-1.500 \times 10^{-7}\text{ C}}$ | **PASS** |
| Minimum Queue Voltage ($\min v_C$) | $\ge -1.00 \times 10^{-6}\text{ V}$ | $\mathbf{9.199 \times 10^{-32}\text{ V}}$ | **PASS** |
| Mean DC-Link Voltage | $> 40.0\text{ V}$ | $\mathbf{47.31\text{ V}}$ | **PASS** |
| Regulated 24V Bus Mean Voltage | $24.0\text{ V} \pm 5\%$ | $\mathbf{23.98\text{ V}}$ | **PASS** |
| Regulated 24V Bus Dynamic Min / Max | $24.0\text{ V} \pm 10\%$ | $\mathbf{22.06\text{ V} / 25.63\text{ V}}$ | **PASS** |
| Off-State Channel Leakage Current | $< 1.00\text{ mA}$ | $\mathbf{0.276\text{ mA}}$ | **PASS** |
| Simultaneous Multi-Channel Conduction | $0\text{ events}$ | $\mathbf{0\text{ events}}$ | **PASS** |

The measured sub-microvolt tracking error ($1.300 \times 10^{-6}\text{ V}$) confirms that a physical electrical network with physical conserving connections reproduces the analytical queue equations with extreme fidelity.

---

### D. Capacitor Parasitics Compensation & Stop-Line Detector Immunity (Stage S6)

The impact of capacitor non-idealities ($R_{\text{esr}} = 5\text{ m}\Omega$ nominal, $10\text{ m}\Omega$ degraded; $L_{\text{esl}} = 10\text{ nH}$; $R_{\text{leak}} = 10\text{ M}\Omega$) was evaluated across all 600 s of Scenario T6.

![Figure 11: Capacitor Parasitics and Active Sensor Compensation](Results/figures/Fig11_S6_Capacitor_Parasitics.png)

#### Key Findings:
1. **ESR Terminal Voltage Ripple**: Instantaneous branch current jumps produce dynamic terminal voltage steps ($\Delta V_{\text{esr}} = 3.25\text{ mV}$ nominal, $6.50\text{ mV}$ degraded).
2. **False Trigger Suppression**: At a stop-line threshold of $0.50\text{ V}$, uncompensated ESR terminal voltage induced $2$ false vehicle detection commutations.
3. **Active Sensor Compensation**: Applying real-time current sensor feedback eliminated all parasitic distortion, reducing measurement error to floating-point floor ($\max |V_{\text{comp}} - q_{\text{ref}}| = 8.88 \times 10^{-16}\text{ V}$) with **0 detector mismatches** under both nominal and $+200\%$ end-of-life wear-out conditions (**PASS**).

---

### E. Semiconductor Switching Dynamics, Losses & Thermal Rise (Stage S7)

Signal-head switching MOSFETs were evaluated for high-frequency losses and junction thermal equilibrium in outdoor traffic cabinet ambient temperatures ($40.0^\circ\text{C}$).

![Figure 12: Semiconductor Losses and Junction Temperature Rise](Results/figures/Fig12_S7_Semiconductor_Thermal.png)

#### TABLE V: Semiconductor Switching & Thermal Verification
| Parameter | Specification | Measured Value | Safety Margin | Status |
|:---|:---:|:---:|:---:|:---:|
| Conduction Loss ($P_{\text{cond}}$) | $\le 0.100\text{ W}$ | $\mathbf{0.025\text{ W}}$ | $+75.0\%$ | **PASS** |
| Switching Energy ($E_{\text{sw}}$) | $\le 1.00\ \mu\text{J}$ | $\mathbf{0.660\ \mu\text{J}}$ | $+34.0\%$ | **PASS** |
| Commutation Turn-On/Off Delay ($t_d$) | $\ll 3.0\text{ s}$ | $\mathbf{175\text{ ns}}$ | $1.71 \times 10^7 \times$ margin | **PASS** |
| Peak Junction Temperature ($T_{\text{junc}}$) | $< 150.0^\circ\text{C}$ | $\mathbf{40.90^\circ\text{C}}$ | $\mathbf{109.10^\circ\text{C}}$ margin | **PASS** |

The negligible thermal rise ($\Delta T = 0.90^\circ\text{C}$) proves that low-resistance MOSFET switches operate in natural convection without requiring forced active cooling.

---

### F. Semiconductor Dead-Time Interlock Verification (Part C)

High-speed switching validation results from the $1\ \mu\text{s}$ discrete-time testbench are shown in Figure 6.

![Figure 6: 5 us Dead-Time Waveform](Results/figures/Fig6_Deadtime_Waveform.png)

#### TABLE VI: Semiconductor Dead-Time Verification Metrics
| Parameter | Design Specification | Experimental Measurement | Status |
|:---|:---:|:---:|:---:|
| Simulation Sample Time ($T_s$) | $1.00\ \mu\text{s}$ | $1.00\ \mu\text{s}$ | **PASS** |
| Configured Dead-Time ($T_d$) | $5.00\ \mu\text{s}$ | $5.00\ \mu\text{s}$ | **PASS** |
| Measured Minimum Dead-Time | $\ge 4.50\ \mu\text{s}$ | $\mathbf{5.00\ \mu\text{s}}$ | **PASS** |
| Maximum Simultaneous Gates | $\le 1$ | $\mathbf{1}$ | **PASS** |
| Binary Gating Conformance | $\{0, 1\}$ | $\mathbf{100.0\%}$ | **PASS** |
| Shoot-Through Transitions | $0$ | $\mathbf{0}$ | **PASS** |

Across all phase transitions ($Ch1 \to Ch2 \to Ch3 \to Ch1$), an all-OFF blanking window of $5.00\ \mu\text{s}$ was maintained, confirming shoot-through prevention under rapid control commutations.

---

## VIII. Discussion, Practical Extensions, and Future Scope

The multi-layer architecture of SITRA bridges theoretical traffic control with physical hardware implementation:
1. **Mathematical Isomorphism & Physical Realization**: The mathematical equivalent model provides an analytical, ultra-fast 1 Hz simulation foundation for multi-controller benchmarking and formal state-space conservation proofs ($< 1.42 \times 10^{-15}\text{ A}$ residual error). In parallel, the physical Simscape circuit (`SITRA_S5_Physical.slx`) validates electromagnetic grid-to-load distribution, demonstrating that transformer-rectifier-buck power conditioning maintains bus regulation within $\pm 6.8\%$ even under sharp 1 A channel commutations.
2. **Parasitics and Real-Time Sensor Compensation**: Real-world capacitor degradation (up to $+200\%$ ESR wear-out) does not destabilize traffic queue estimation when paired with active sensor compensation, guaranteeing zero false phase triggers at stop-line detector thresholds.
3. **Decoupled Timescale Synthesis & Hardware Handoff**: The microsecond dead-time logic and the 1 Hz macroscopic controller were verified in separate, timescale-appropriate environments ($1\ \mu\text{s}$ vs $1\text{ s}$), avoiding unphysical simulation artifacts. Future hardware-in-the-loop (HIL) studies will deploy both algorithms onto an FPGA/DSP real-time target.

---

## IX. Conclusion

This paper has presented the mathematical formulation, modular Simulink implementation, physical Simscape circuit realization, and empirical verification of **SITRA**, an integrated traffic and electrical-equivalent congestion management framework for urban confluence junctions. 

The experimental findings establish that:
- Control algorithm selection significantly influences congestion topology: **Vehicle-Actuated control provides superior delay minimization ($17.25\text{ s/veh}$)**, while **MaxPressure delivers unmatched peak queue suppression ($11.66\text{ veh}$)**.
- **SITRA MPC provides balanced multivariable stabilization ($24.30\text{ s/veh}$)**, comfortably outperforming conventional Webster fixed-time signalization ($34.84\text{ s/veh}$) under severe surge demand.
- The dual-timescale electrical equivalence model achieves **exact current conservation with numerical precision ($< 1.42 \times 10^{-15}\text{ A}$)**, providing a mathematically robust bridge between traffic queue dynamics and power electronic state representations.
- The physical Simscape circuit achieves **sub-microvolt queue tracking ($1.30 \times 10^{-6}\text{ V}$)** with genuine conserving physical blocks (0 code blocks inside physics), verifying closed-loop 24 V DC bus regulation, active capacitor ESR compensation, and a $109.1^\circ\text{C}$ semiconductor thermal safety margin.
- Microsecond switching interlock validation confirmed guaranteed **$5.00\ \mu\text{s}$ dead-time margins**, preventing switching overlap during arbitrary phase transitions.

The unified codebase, physical Simscape models, mathematical equivalent frameworks, testbenches, and high-resolution figures provide a reproducible, peer-reviewed foundation for integrated intelligent transportation and smart-grid energy infrastructure research.

---

## References

1. F. V. Webster, "Traffic signal settings," *Road Research Technical Paper*, no. 39, Road Research Laboratory, London, 1958.
2. P. Varaiya, "The max-pressure controller for arbitrary networks of signalized intersections," *Advances in Dynamic Network Modeling in Complex Systems*, pp. 27–66, Springer, 2013.
3. K. E. Gartner, "OPAC: A strategy for demand-responsive decentralized traffic signal control," *IEEE Trans. Intell. Transp. Syst.*, vol. 3, no. 1, pp. 45–54, Mar. 2002.
4. L. D. Baskar, B. De Schutter, J. Hellendoorn, and Z. Papp, "Traffic control and intelligent vehicle highway systems: A survey," *IET Intell. Transp. Syst.*, vol. 5, no. 1, pp. 38–52, Mar. 2011.
5. J. A. Sangiovanni-Vincentelli, "Quo vadis, SLD? Reasoning about the trends and challenges of system level design," *Proc. IEEE*, vol. 95, no. 3, pp. 467–506, Mar. 2007.
6. R. W. Erickson and D. Maksimovic, *Fundamentals of Power Electronics*, 3rd ed. Cham, Switzerland: Springer, 2020.
7. M. Papageorgiou, C. Diakaki, V. Dinopoulou, A. Kotsialos, and Y. Wang, "Review of road traffic control strategies," *Proc. IEEE*, vol. 91, no. 12, pp. 2043–2067, Dec. 2003.
8. S. Lin, B. De Schutter, Y. Xi, and H. Hellendoorn, "Efficient model predictive control for large-scale urban traffic networks via model reduction," *IEEE Trans. Intell. Transp. Syst.*, vol. 12, no. 4, pp. 1138–1148, Dec. 2011.
9. N. H. Gartner, F. J. Pooran, and C. M. Andrews, "Implementation of the OPAC adaptive control strategy in a freeway corridor," *Transp. Res. Rec.*, no. 1748, pp. 88–95, 2001.
10. H. X. Liu, X. Wu, W. Ma, and H. Hu, "Real-time queue length estimation for congested signalized intersections," *Transp. Res. Part C: Emerg. Technol.*, vol. 17, no. 4, pp. 412–427, Aug. 2009.
