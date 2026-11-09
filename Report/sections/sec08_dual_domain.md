# 7. Dual-Domain Operation: Electrical Circuit Mechanics vs. Real-Time Traffic Engineering

This section bridges theoretical modeling and physical implementation by contrasting how each signal controller operates in the real-world traffic domain versus how it functions in the electrical circuit domain.

## 7.1 Side-by-Side Dual-Domain Operational Comparison

### 7.1.1 SITRA Model Predictive Control (MPC)

Table 7.1: SITRA MPC Dual-Domain Operational Comparison. Source: `FLAT/mpcSignalModel.m`, `FLAT/baselines/bl_simulate.m`.

| Operational Aspect | Real-Time Traffic Domain (Engineer / Driver View) | Electrical Circuit Domain (Circuit Operation) |
|---|---|---|
| **Inputs & Sensing** | Upstream vehicle queue lengths $q_1..q_4$ measured via camera/radar or loop count integration. | Capacitor terminal voltages $v_{C1}..v_{C4}$ measured via high-impedance voltage sensors into ADC. |
| **Decision Rule & Rate** | Re-computes optimal green splits every cycle ($63\text{ s}$) over a 3-cycle ($189\text{ s}$) rolling horizon using quadratic programming. | Dispatches gate pulse widths to MOSFET switches based on optimal multi-step branch discharge trajectories. |
| **Light Traffic Response** | Allocates minimum green ($12.0\text{ s}$) to each approach, cycling evenly with low queue accumulation ($< 3\text{ veh}$). | Low capacitor charge accumulation ($< 3\text{ V}$); gate switching charges dissipate quickly through linear sinks. |
| **Surge Traffic Response** | Expands Branch 1 green to maximum limit ($30.0\text{ s}$), borrowing time from lightly loaded side streets. | Sustains B1 MOSFET gate drive at $10\text{ V}$ for maximum duration, discharging surge capacitor charge at $0.65\text{ A}$. |
| **Behavior Under Incident (T9)** | Detects persistent queue rise on B1; dynamically allocates maximum green, clearing residual queue in $174.6\text{ s}$. | B1 discharge current sink is clamped to $0.325\text{ A}$; controller sustains gate on to maximize charge drainage. |
| **Behavior Under Blockage (T10)** | Senses downstream queue $q_4$ approaching $15\text{ veh}$; pauses upstream green to prevent intersection spill-back. | $V_{B4}$ approaches $15.0\text{ V}$; physical comparator clamps upstream discharge sinks to zero current. |
| **Behavior Under Platoon (T11)** | Anticipates cyclical arrival bursts, shaping green intervals to match arrival pulses across rolling horizon. | Smooths current pulses entering $C_{B2}$, clearing platoon-induced charge in $223.0\text{ s}$. |
| **Behavior Under Sensor Noise (T13)** | Horizon cost summation acts as a low-pass filter; zero-mean noise cancels out, limiting queue error to $+0.31\text{ veh}$. | Multi-step integration filters high-frequency voltage sensor noise, preventing erratic gate switching chatter. |
| **Behavior Under Stuck Signal (T14)** | Recognizes lack of clearance on B3; reallocates green to B1 and B2, clearing queue in $219.2\text{ s}$. | B3 MOSFET gate driver is stuck low; controller redistributes conduction duty cycles to B1 and B2 channels. |
| **Field Hardware Needs** | Microcontroller cabinet (ARM Cortex / x86), video detection cameras, NEMA TS2 interface unit. | Analog voltage conditioning, ADC, high-side MOSFET gate drivers (IR2110), 24 V DC power bus. |
| **Primary Failure Mode** | Horizon misprediction under sudden unmodeled incidents outside the prediction model. | Voltage sensor drift causing systematic bias in queue charge estimation. |

---

### 7.1.2 Webster Fixed-Time Controller

Table 7.2: Webster Controller Dual-Domain Operational Comparison. Source: `FLAT/baselines/bl_ctrl_webster.m`.

| Operational Aspect | Real-Time Traffic Domain (Engineer / Driver View) | Electrical Circuit Domain (Circuit Operation) |
|---|---|---|
| **Inputs & Sensing** | Historical average demand flows $\bar{\lambda}_1..\bar{\lambda}_3$; no real-time detector sensors required. | Static duty-cycle lookup table; zero feedback from capacitor voltage sensors. |
| **Decision Rule & Rate** | Static equisaturation formula allocating fixed green splits ($g_1=26\text{s}, g_2=18\text{s}, g_3=19\text{s}$) updated once per day. | Open-loop square wave generator switching MOSFETs with fixed duty cycles at $1/63\text{ Hz}$. |
| **Light Traffic Response** | Green lights display to completely empty approaches, forcing cross-street traffic to wait unnecessarily. | MOSFET switches conduct with zero current flow, needlessly keeping empty channel circuits energized. |
| **Surge Traffic Response** | Incapable of allocating additional green to B1; queues build up exponentially, failing to clear (Clearance = NaN). | Inflow current exceeds discharge capacity during fixed gate window; capacitor voltage ramps up to breakdown. |
| **Behavior Under Disturbances (T9–T11)** | Complete inability to adapt; fixed timings cause severe queue backlog ($E_{\text{veh}} = 4095.6\text{ veh}\cdot\text{s}$ on T11). | Open-loop switching cannot compensate for branch conductance drops, causing runaway capacitor charging. |
| **Behavior Under Sensor Noise (T12, T13)** | **Perfect immunity:** Because it reads zero sensors, detector noise or freezing has exactly $0.00\%$ impact. | Disconnected sensor leads do not perturb open-loop gate timing; zero degradation under ADC faults. |
| **Field Hardware Needs** | Simple electromechanical or solid-state timer unit; zero detection loops or cameras required. | Fixed oscillator circuit, gate driver, and 24 V DC power supply. |
| **Primary Failure Mode** | Total traffic gridlock during unexpected demand surges or road construction lane closures. | Complete inability to protect capacitor banks from over-voltage during current surges. |

---

### 7.1.3 Vehicle-Actuated Controller

Table 7.3: Vehicle-Actuated Controller Dual-Domain Operational Comparison. Source: `FLAT/baselines/bl_ctrl_actuated.m`.

| Operational Aspect | Real-Time Traffic Domain (Engineer / Driver View) | Electrical Circuit Domain (Circuit Operation) |
|---|---|---|
| **Inputs & Sensing** | Upstream presence loops / advance stop-line detectors sensing vehicle passage and gap times. | Voltage comparator monitoring rate of change of capacitor discharge current and voltage drop. |
| **Decision Rule & Rate** | Instantaneous 1-second gap-out detection: terminates green immediately when queue empties ($q < 0.1\text{ veh}$). | Immediate gate turn-off triggered when capacitor discharge current collapses below a threshold. |
| **Light Traffic Response** | **Superior performance:** Gaps out in $12\text{ s}$ per approach, cycling rapidly and cutting delay to $11.7\text{ s/veh}$ (LOS B). | Minimum pulse duration discharges small capacitor charges immediately, keeping average voltage at $1.70\text{ V}$. |
| **Surge Traffic Response** | Holds green on B1 up to maximum green ($30\text{ s}$); clears surge in $63.0\text{ s}$ (faster than SITRA's $106.0\text{ s}$). | Sustains maximum gate conduction pulse until queue voltage drops to zero, rapidly restoring base voltage. |
| **Behavior Under Incident (T9)** | Extends green to maximum, clearing incident backlog in $80.0\text{ s}$ with minimum excess delay ($272.8\text{ veh}\cdot\text{s}$). | Holds MOSFET conducting as long as reduced current sink flows, achieving efficient charge evacuation. |
| **Behavior Under Sensor Noise (T13)** | **Severe vulnerability:** Noise spikes prevent gap-out, causing false green extensions; delay spikes by $+5.46\text{ s}$ ($p < 0.001$). | Sensor noise voltage offsets falsely trigger extension comparator, keeping switches on and depleting bus energy. |
| **Behavior Under Stuck Sensor (T12)** | Detector frozen high causes permanent max-out ($30\text{ s}$) every cycle, inflating side-street delay by $+516.9\text{ veh}\cdot\text{s}$. | Comparator latch stuck high forces channel to conduct for maximum duration regardless of true capacitor state. |
| **Field Hardware Needs** | Fast-response stop-line and advance inductive loops, detector amplifier cards, NEMA TS2 controller. | High-speed analog voltage comparators, fast ADC channels, MOSFET driver stages. |
| **Primary Failure Mode** | Premature gap-out during sluggish heavy vehicle startup, or max-out lockup under faulty detector loops. | Noise-induced false switching chatter and gate-driver latchup. |

---

### 7.1.4 Varaiya Max-Pressure Controller

Table 7.4: Max-Pressure Controller Dual-Domain Operational Comparison. Source: `FLAT/baselines/bl_ctrl_maxpressure.m`.

| Operational Aspect | Real-Time Traffic Domain (Engineer / Driver View) | Electrical Circuit Domain (Circuit Operation) |
|---|---|---|
| **Inputs & Sensing** | Requires full queue sensing on both upstream approaches ($q_1..q_3$) and downstream exit link ($q_4$). | Senses differential voltage across upstream capacitors ($v_{C1}..v_{C3}$) relative to downstream capacitor $v_{C4}$. |
| **Decision Rule & Rate** | Evaluates weighted pressure differential $C_b(q_b - q_4)$ at every phase boundary, selecting the highest pressure. | Multiplexed comparator network routing gate drive to the channel with the largest trans-conductance potential drop. |
| **Light Traffic Response** | Stable cyclic rotation governed by minimum green ($12.0\text{ s}$); average delay $13.9\text{ s/veh}$ (LOS B). | Balanced capacitor potential equalization across all three input nodes. |
| **Surge Traffic Response** | Prioritizes B1 due to high positive pressure gradient ($q_1 - q_4$); maintains smooth throughput. | Channels discharge current into downstream node, balancing input and output capacitor charge levels. |
| **Behavior Under Downstream Blockage (T10)** | When B4 fills ($q_4 \ge 15\text{ veh}$), pressure differential drops, automatically throttling upstream green allocations. | Rising $V_{B4}$ potential reduces the forward voltage drop, autonomously throttling current sink drive. |
| **Behavior Under Sensor Noise (T13)** | Instantaneous decision rule is corrupted by noise differentials; excess delay rises by $+1168.4\text{ veh}\cdot\text{s}$ ($p = 0.023$). | Noise differentials cause improper phase selection, activating channels with lower true charge. |
| **Field Hardware Needs** | Comprehensive detector coverage on all intersection approaches plus downstream exit links. | Differential instrumentation amplifiers, high-resolution ADCs, and microcontroller. |
| **Primary Failure Mode** | Signal starvation of minor approaches when a heavily congested approach maintains high pressure. | Potential oscillation between approaches with closely matched capacitor voltages. |

---

## 7.2 Synchronized Dual-Domain Waveform Walkthroughs
To illustrate the physical-mathematical isomorphism, we analyze synchronized 4-panel waveforms generated by `plot_dual_domain.m` across two critical benchmark scenarios: Scenario T6 (Part 8 deterministic demand surge) and Scenario T9 (Branch 1 incident capacity reduction).

Each figure comprises four vertically synchronized panels sharing an identical horizontal time axis:
- **Panel (a) — Gates / MOSFET Gate Drive:** Displays discrete gate commands $g_1(t)$ (blue), $g_2(t)$ (orange), and $g_3(t)$ (green), indicating active right-of-way ($1 = 10\text{ V}$, $0 = 0\text{ V}$).
- **Panel (b) — Queues / Capacitor Voltages:** Displays instantaneous vehicular queues $q_1..q_4$ in vehicles, identical to physical capacitor voltages $v_{C1}..v_{C4}$ in Volts ($1\text{ V} = 1\text{ veh}$).
- **Panel (c) — Departures / Discharge Currents:** Displays actual stop-line departure rates in $\text{veh/s}$, corresponding to controlled sink currents $i_{\text{dep}, 1}..i_{\text{dep}, 3}$ and exit current $i_{\text{exit}, 4}$ in Amperes.
- **Panel (d) — True vs. Observed Approach Queue:** Compares total true plant approach queue $\sum_{b=1}^{3} q_b(t)$ (solid blue line) against the queue perceived by the controller $\sum_{b=1}^{3} q_{\text{seen}, b}(t)$ (dashed red line).

### 7.2.1 Waveform Analysis on Scenario T6 (Deterministic Surge)

![Fig. 7.1. Dual-Domain Waveforms: SITRA MPC on Scenario T6 (Part 8 Surge).](figures/fig31_dual_sitra_t6.png){width=100%}

In Fig. 7.1 (SITRA MPC on T6), prior to $t = 200\text{ s}$, traffic operates in steady state:
- **Cycle Progression (0–200 s):** SITRA MPC executes balanced cycle splits ($g_1 = 25\text{ s}$, $g_2 = 19\text{ s}$, $g_3 = 19\text{ s}$). In Panel (b), capacitor voltages oscillate between $1.0\text{ V}$ and $4.5\text{ V}$, representing normal cyclic red-phase charge accumulation and green-phase discharge.
- **Surge Onset (200–400 s):** At $t = 200\text{ s}$, arrival demand on B1 steps up from $0.10\text{ A}$ to $0.30\text{ A}$ ($0.30\text{ veh/s}$). Capacitor voltage $v_{C1}$ begins rising. Observing this trajectory across its 3-cycle horizon, SITRA MPC expands $g_1$ to its maximum bound of $30.0\text{ s}$ while compressing $g_2$ and $g_3$ to their minimum bounds of $12.0\text{ s}$. In Panel (c), B1 discharge current flows at maximum saturation capacity ($0.65\text{ A}$) for $30\text{ s}$ per cycle. Peak total queue reaches $14.79\text{ veh}$ ($14.79\text{ V}$).
- **Surge Termination and Clearance (400–506 s):** At $t = 400\text{ s}$, arrival demand returns to $0.10\text{ A}$. SITRA MPC sustains extended B1 green allocations for two subsequent cycles, steadily draining the accumulated charge on $C_{B1}$. At $t = 506.0\text{ s}$ ($106.0\text{ s}$ after surge end), the moving-average queue matches the no-congestion twin run within $1.0\text{ veh}$, establishing $t_{\text{clear}} = 106.0\text{ s}$ and cumulative excess delay $E_{\text{veh}} = 305.59\text{ veh}\cdot\text{s}$.

![Fig. 7.2. Dual-Domain Waveforms: Webster Fixed-Time on Scenario T6 (Part 8 Surge).](figures/fig32_dual_webster_t6.png){width=100%}

In Fig. 7.2 (Webster on T6), the limitation of open-loop fixed-time control is starkly demonstrated:
- Throughout the surge ($200\text{–}400\text{ s}$), Webster maintains rigid, unchanging green splits ($g_1 = 26\text{ s}$). Because $26\text{ s}$ is insufficient to discharge $0.30\text{ veh/s}$ inflow, capacitor $C_{B1}$ accumulates massive residual charge each cycle, peaking at $24.12\text{ V}$ ($24.12\text{ veh}$).
- Following surge termination at $t = 400\text{ s}$, Webster's fixed $26\text{ s}$ green cannot clear the accumulated backlog before simulation end ($600\text{ s}$). The queue remains elevated at $4.76\text{ veh}$, resulting in **Clearance = NaN (Not Cleared)** and a catastrophic excess delay of $E_{\text{veh}} = 1867.21\text{ veh}\cdot\text{s}$ (over six times greater than SITRA).

![Fig. 7.3. Dual-Domain Waveforms: Vehicle-Actuated Control on Scenario T6 (Part 8 Surge).](figures/fig33_dual_actuated_t6.png){width=100%}

In Fig. 7.3 (Actuated on T6), the reactive mechanism achieves rapid clearance:
- In Panel (a), during the surge, Actuated control extends B1 green to its maximum limit ($30\text{ s}$). As soon as the surge ends at $t = 400\text{ s}$, Actuated control senses when $q_1$ drops below $0.1\text{ veh}$ during green discharge, terminating the phase immediately without waiting for cycle boundaries.
- This immediate gap-out behavior eliminates wasted green time, achieving full clearance in $t_{\text{clear}} = 63.0\text{ s}$ and minimal excess delay $E_{\text{veh}} = 181.43\text{ veh}\cdot\text{s}$.

![Fig. 7.4. Dual-Domain Waveforms: Varaiya Max-Pressure Control on Scenario T6 (Part 8 Surge).](figures/fig34_dual_maxpressure_t6.png){width=100%}

In Fig. 7.4 (Max-Pressure on T6), pressure-driven routing is evident:
- High queue accumulation on B1 elevates upstream potential $v_{C1}$, maximizing the pressure gradient $P_1 = q_1 - q_4$. Max-pressure control repeatedly awards green to B1. Peak queue is held to $11.24\text{ veh}$, but secondary approach queues experience minor cycle ripple, resulting in $t_{\text{clear}} = \text{NaN}$ under the strict 60 s hold window and $E_{\text{veh}} = 411.96\text{ veh}\cdot\text{s}$.

---

### 7.2.2 Waveform Analysis on Scenario T9 (Branch 1 Incident)

Scenarios with physical incidents are illustrated in Figs. 7.5 through 7.8:

![Fig. 7.5. Dual-Domain Waveforms: SITRA MPC on Scenario T9 (B1 Incident).](figures/fig35_dual_sitra_t9.png){width=100%}

In Fig. 7.5 (SITRA MPC on T9):
- At $t = 200\text{ s}$, an incident reduces B1 stop-line capacity by $50\%$ (from $0.65\text{ A}$ to $0.325\text{ A}$) until $t = 400\text{ s}$. In Panel (c), the discharge current plateau on B1 drops from $0.65\text{ A}$ to $0.325\text{ A}$.
- Observing this bottleneck through its state equations, SITRA MPC expands B1 green time to compensate for reduced discharge throughput, preventing queue runaway. Following incident removal at $t = 400\text{ s}$, full clearance is achieved with $E_{\text{veh}} = 829.10\text{ veh}\cdot\text{s}$.

![Fig. 7.6. Dual-Domain Waveforms: Webster Controller on Scenario T9 (B1 Incident).](figures/fig36_dual_webster_t9.png){width=100%}

In Fig. 7.6 (Webster on T9), fixed-time control cannot adapt to reduced capacity:
- With discharge current clamped to $0.325\text{ A}$ and green fixed at $26\text{ s}$, B1 discharge drops below inflow, causing severe queue accumulation. Excess delay reaches $E_{\text{veh}} = 1462.16\text{ veh}\cdot\text{s}$ (76% higher than SITRA).

![Fig. 7.7. Dual-Domain Waveforms: Vehicle-Actuated Control on Scenario T9 (B1 Incident).](figures/fig37_dual_actuated_t9.png){width=100%}

In Fig. 7.7 (Actuated on T9):
- Actuated control holds green on B1 for maximum green ($30\text{ s}$) throughout the incident, then rapidly cycles side streets once the incident clears, achieving $E_{\text{veh}} = 272.85\text{ veh}\cdot\text{s}$ and $t_{\text{clear}} = 80.0\text{ s}$.

![Fig. 7.8. Dual-Domain Waveforms: Max-Pressure Control on Scenario T9 (B1 Incident).](figures/fig38_dual_maxpressure_t9.png){width=100%}

In Fig. 7.8 (Max-Pressure on T9):
- Max-pressure control dynamically allocates phases based on instantaneous differential potential, maintaining excess delay at $E_{\text{veh}} = 644.17\text{ veh}\cdot\text{s}$ and clearing the incident backlog in $136.67\text{ s}$.
