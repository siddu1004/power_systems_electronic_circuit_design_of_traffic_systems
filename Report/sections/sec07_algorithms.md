# 6. Algorithms and Mathematical Formulations

This section provides an exhaustive technical specification for every algorithm, plant model, controller, and electrical compensator in the codebase using a standardized 10-item template.

---

## 6.1 Discrete Queue Plant Dynamics
1. **Name and Layer:** Discrete Traffic Queue Plant (`FLAT/baselines/bl_plant_step.m`, `FLAT/signalModel.m`, Layer L1).
2. **Plain Description:** Updates the vehicular queue state vector across all four approaches at each 1-second discrete step by integrating arrivals and gate-controlled departures under capacity and spill-back limits.
3. **Step-by-Step Procedure:**
   1. Receive current queue $\mathbf{q}(k)$, gate vector $\mathbf{g}(k)$, external arrivals $\boldsymbol{\lambda}(k)$, and network capacities $\mathbf{C}(k)$.
   2. Check downstream link B4 queue against spill-back threshold: if $q_4(k) \ge q_{4\max} - 10^{-4}\text{ veh}$, clamp upstream departures $\mu_1.. \mu_3 = 0$.
   3. For each active upstream approach $b \in \{1, 2, 3\}$, calculate departure flow $\mu_b(k) = g_b(k) \cdot \min(C_b(k), q_b(k)/\Delta t + \lambda_b(k))$.
   4. Calculate downstream arrival $A_4(k) = \sum_{b=1}^{3} \mu_b(k)$ and exit departure $\mu_4(k) = \min(C_4(k), q_4(k)/\Delta t + A_4(k))$.
   5. Update state: $q_b(k+1) = \max(0, q_b(k) + (\lambda_b(k) - \mu_b(k))\Delta t)$ for all $b \in \{1..4\}$.
4. **Mathematical Formulas:**
   $$q_b(k+1) = \max\left(0, \; q_b(k) + \left[\lambda_b(k) - g_b(k)\min\left(C_b(k), \frac{q_b(k)}{\Delta t} + \lambda_b(k)\right)\right]\Delta t\right) \tag{26}$$
   $$q_4(k+1) = \max\left(0, \; q_4(k) + \left[\sum_{b=1}^{3}\mu_b(k) - \min\left(C_4(k), \frac{q_4(k)}{\Delta t} + \sum_{b=1}^{3}\mu_b(k)\right)\right]\Delta t\right) \tag{27}$$
5. **Analogy Role:** Corresponds to Kirchhoff's Current Law at four electrical capacitor nodes, where departure currents discharge $1\text{ F}$ capacitors via controlled current sinks.
6. **Importance:** Removing this plant breaks the fundamental physical state integration of the entire simulation.
7. **Parameters:** $\Delta t = 1.0\text{ s}$, $q_{4\max} = 15.0\text{ veh}$ (`bl_config.m`, `createNetwork.m`).
8. **Why This Algorithm:** Alternatives include microscopic car-following models (e.g., Wiedemann 74) or Cell Transmission Model (CTM). Microscopic models cannot be solved inside fast convex QPs, and CTM introduces spatial non-linearities unnecessary for isolated stop-line control.
9. **Theoretical Properties:** Exactly satisfies mass conservation ($\sum \text{in} - \sum \text{out} = \Delta \text{queue}$), verified to residual error $< 10^{-15}$ [6].
10. **Computational Cost:** $0.004\text{ ms}$ per step ($2.4\text{ ms}$ total for 600 steps).

---

## 6.2 Traffic Network Definition
1. **Name and Layer:** Junction Network Architecture (`FLAT/createNetwork.m`, Layer L1).
2. **Plain Description:** Instantiates the structural graph, baseline capacities, branch lengths, and free-flow velocity vectors for the SITRA junction.
3. **Step-by-Step Procedure:**
   1. Initialize node table: Node 1 (Hope College), Node 2 (Kalapatti), Node 3 (Airport), Node 4 (SITRA Center), Node 5 (Goldwins).
   2. Assign branch capacities: $\mathbf{C} = [0.65, 0.35, 0.25, 0.45]\text{ veh/s}$.
   3. Assign nominal approach lengths: $L = [300, 250, 200, 400]\text{ m}$ and free-flow velocity $v_{\text{ff}} = 13.89\text{ m/s}$ ($50\text{ km/h}$).
   4. Return network parameter structure `net`.
4. **Mathematical Formulas:**
   $$\mathbf{C}_{\text{nominal}} = [0.65, \; 0.35, \; 0.25, \; 0.45]^T \quad [\text{veh/s}] \tag{28}$$
5. **Analogy Role:** Defines the static electrical branch conductance limits and current sink saturation thresholds.
6. **Importance:** Provides baseline ground truth; corrupting this invalidates all baseline comparisons.
7. **Parameters:** Set in `createNetwork.m`.
8. **Why This Algorithm:** Fixed parameter instantiation ensures complete determinism across all twelve comparison scenarios.
9. **Theoretical Properties:** Static parameter mapping.
10. **Computational Cost:** $< 0.1\text{ ms}$ execution on startup.

---

## 6.3 SITRA Model Predictive Controller (MPC)
1. **Name and Layer:** SITRA Receding-Horizon MPC (`FLAT/mpcSignalModel.m`, Part 8, Layer L5).
2. **Plain Description:** Optimizes green time splits across a 3-cycle prediction horizon by solving a constrained quadratic program to minimize cumulative weighted queues and green-time deviation penalties.
3. **Step-by-Step Procedure:**
   1. At the start of each signal cycle $m$, measure current queue vector $\mathbf{q}(t)$.
   2. Predict arrival profiles across prediction horizon $N_p = 3\text{ cycles} = 189\text{ s}$.
   3. Formulate cost function:
      $$J = \sum_{j=1}^{N_p} \left[ \mathbf{q}(k+j)^T \mathbf{Q}_w \mathbf{q}(k+j) + \mathbf{g}_{\text{split}}(j)^T \mathbf{R}_w \mathbf{g}_{\text{split}}(j) \right] \tag{29}$$
   4. Enforce linear equality constraint $\sum_{b=1}^{3} g_b(j) = T_{\text{cycle}} - L_{\text{lost}} = 63.0\text{ s}$.
   5. Enforce box constraints: $12.0\text{ s} \le g_b(j) \le 30.0\text{ s}$ for all approaches $b \in \{1, 2, 3\}$.
   6. Solve QP using quadratic programming solver; apply the first cycle's optimal green split $\mathbf{g}^*(1)$ to hardware gate drivers.
4. **Mathematical Formulas:**
   $$\min_{\mathbf{g}} \quad \frac{1}{2} \mathbf{g}^T \mathbf{H}_{\text{qp}} \mathbf{g} + \mathbf{f}_{\text{qp}}^T \mathbf{g} \quad \text{s.t.} \quad \mathbf{A}_{\text{eq}} \mathbf{g} = \mathbf{b}_{\text{eq}}, \quad \mathbf{g}_{\min} \le \mathbf{g} \le \mathbf{g}_{\max} \tag{30}$$
5. **Analogy Role:** Corresponds to a multi-step optimal power flow (OPF) controller calculating optimal branch switch conduction intervals to minimize stored electrostatic energy.
6. **Importance:** The core proposed controller of the project; disabling it eliminates all Part 8 predictive benchmarks.
7. **Parameters:** $N_p = 3\text{ cycles}$, $T_{\text{cycle}} = 63.0\text{ s}$, $g_{\min} = 12.0\text{ s}$, $g_{\max} = 30.0\text{ s}$, $\mathbf{Q}_w = \text{diag}([1.5, 1.0, 0.8, 0.5])$ (`mpcSignalModel.m`).
8. **Why This Algorithm:** Alternatives: Deep Q-learning (RL) or non-linear MPC. RL lacks formal convergence proofs and predictable safety boundaries under unexpected physical faults [10], [12]; non-linear MPC cannot guarantee real-time convex execution within $1\text{ ms}$.
9. **Theoretical Properties:** Proven asymptotic stability and feasibility under convex quadratic constraints [11], [16], [18].
10. **Computational Cost:** Measured execution time: $0.126\text{ ms}$ per decision step ($0.075\text{ s}$ for 600 steps).

---

## 6.4 Webster Equisaturation Controller
1. **Name and Layer:** Webster Fixed-Time Optimum Split Controller (`FLAT/baselines/bl_ctrl_webster.m`, Layer L5).
2. **Plain Description:** Allocates fixed green times to each phase proportionally to its critical volume-to-saturation flow ratio (equisaturation principle).
3. **Step-by-Step Procedure:**
   1. Calculate average arrival rates $\bar{\lambda}_b$ over historical window.
   2. Compute approach saturation ratios $y_b = \bar{\lambda}_b / C_b$.
   3. Compute sum of critical ratios $Y = \sum_{b=1}^{3} y_b$.
   4. Allocate effective green time proportionally: $g_b = (y_b / Y) \cdot (T_{\text{cycle}} - L_{\text{lost}})$.
   5. Enforce minimum green clamping: $g_b = \max(g_{\min}, g_b)$ with sum re-normalization.
4. **Mathematical Formulas:**
   $$g_b = (T_{\text{cycle}} - L_{\text{lost}}) \cdot \frac{\lambda_b / C_b}{\sum_{j=1}^{3} (\lambda_j / C_j)} \tag{31}$$
5. **Analogy Role:** A static open-loop pulse generator driving MOSFET gates with fixed duty cycles derived from nominal load resistances.
6. **Importance:** Serves as the primary worldwide municipal standard benchmark for fixed-time signal timing.
7. **Parameters:** $T_{\text{cycle}} = 63.0\text{ s}$, $g_{\min} = 12.0\text{ s}$ (`bl_ctrl_webster.m`).
8. **Why This Algorithm:** Alternatives: Equal-split fixed timing. Webster is analytically optimal for steady, deterministic flows [1].
9. **Theoretical Properties:** Proven to minimize average delay under strictly steady-state Poisson arrivals with degree of saturation $X < 0.85$ [1].
10. **Computational Cost:** $0.027\text{ ms}$ per decision step ($0.016\text{ s}$ total).

---

## 6.5 Vehicle-Actuated Controller
1. **Name and Layer:** Vehicle-Actuated Green Extension Controller (`FLAT/baselines/bl_ctrl_actuated.m`, Layer L5).
2. **Plain Description:** Extends the active phase green indication upon detecting arriving vehicles until a gap-out threshold occurs or maximum green is reached.
3. **Step-by-Step Procedure:**
   1. Maintain active phase $u$ for at least minimum green duration $g_{\min} = 12.0\text{ s}$.
   2. At each step $t > g_{\min}$, check observed approach queue $q_{\text{seen}, u}(t)$ and vehicle arrivals $\lambda_u(t)$.
   3. If $q_{\text{seen}, u}(t) < 0.1\text{ veh}$ and $\lambda_u(t) < 0.05\text{ veh/s}$ (gap-out condition), terminate green immediately ($g_u \to 0$).
   4. If green duration reaches maximum green $g_{\max} = 30.0\text{ s}$, force phase termination (max-out).
   5. Switch to the next approach phase in cyclic sequence $(1 \to 2 \to 3 \to 1)$.
4. **Mathematical Formulas:**
   $$\text{Switch Phase if: } \left( t_{\text{phase}} \ge g_{\min} \land q_{\text{seen}, u} \le \epsilon_{\text{gap}} \right) \lor \left( t_{\text{phase}} \ge g_{\max} \right) \tag{32}$$
5. **Analogy Role:** A hysteretic current-mode comparator terminating gate drive when inductor/capacitor discharge current drops below a lower threshold.
6. **Importance:** Represents the standard traffic-responsive controller deployed in modern actuated municipal intersections [8].
7. **Parameters:** $g_{\min} = 12.0\text{ s}$, $g_{\max} = 30.0\text{ s}$, $\epsilon_{\text{gap}} = 0.1\text{ veh}$ (`bl_ctrl_actuated.m`).
8. **Why This Algorithm:** Standard NEMA TS2 actuated logic. Chosen because it provides a reactive benchmark without predictive horizon modeling.
9. **Theoretical Properties:** Prevents green allocation to empty approaches; bounds maximum waiting time on red approaches to $2 \times g_{\max}$ [5], [8].
10. **Computational Cost:** $0.039\text{ ms}$ per decision step ($0.024\text{ s}$ total).

---

## 6.6 Varaiya Max-Pressure Controller
1. **Name and Layer:** Max-Pressure Feedback Controller (`FLAT/baselines/bl_ctrl_maxpressure.m`, Layer L5).
2. **Plain Description:** Selects the phase that maximizes the spatial pressure differential between upstream queues and the downstream bottleneck link.
3. **Step-by-Step Procedure:**
   1. Compute spatial pressure gradient for each approach: $P_b(t) = q_{\text{seen}, b}(t) - q_{\text{seen}, 4}(t)$ for $b \in \{1, 2, 3\}$.
   2. Scale pressure by approach discharge capacity: $W_b(t) = P_b(t) \cdot C_b$.
   3. If current phase duration $t_{\text{phase}} < g_{\min}$, maintain current phase.
   4. Once $t_{\text{phase}} \ge g_{\min}$, select phase with highest weighted pressure: $u^*(t) = \arg\max_{b} W_b(t)$.
   5. If $u^*(t) \ne u(t)$ or $t_{\text{phase}} \ge g_{\max}$, switch phase and reset phase timer.
4. **Mathematical Formulas:**
   $$u^*(t) = \arg\max_{b \in \{1, 2, 3\}} \left\{ C_b \cdot \left[ q_b(t) - q_4(t) \right] \right\} \tag{33}$$
5. **Analogy Role:** Autonomous potential-difference routing, where current is steered into the branch with the highest trans-conductance potential drop.
6. **Importance:** State-of-the-art decentralized feedback policy proven to maximize network throughput [7].
7. **Parameters:** $g_{\min} = 12.0\text{ s}$, $g_{\max} = 30.0\text{ s}$ (`bl_ctrl_maxpressure.m`).
8. **Why This Algorithm:** Proved by Varaiya [7] to guarantee maximum network stability region without requiring arrival demand knowledge.
9. **Theoretical Properties:** Throughput-optimal: stabilizes network queues for any demand within the interior of the capacity region [7], [13].
10. **Computational Cost:** $0.028\text{ ms}$ per decision step ($0.017\text{ s}$ total).

---

## 6.7 Hardware Gate Interlock and Dead-Time Model
1. **Name and Layer:** Semiconductor Dead-Time and Mutual Exclusion Interlock (`FLAT/baselines/bl_gates.m`, `run_part_c.m`, `SITRA_Deadtime_Testbench.slx`, Layer L3, L4).
2. **Plain Description:** Converts discrete phase index $u(k)$ into one-hot binary gate drives and inserts an absolute $5.0\,\mu\text{s}$ semiconductor dead-time during phase transitions.
3. **Step-by-Step Procedure:**
   1. Map active phase index $u \in \{0, 1, 2, 3\}$ to binary gates: $u=1 \implies [1,0,0]$, $u=2 \implies [0,1,0]$, $u=3 \implies [0,0,1]$, $u=0 \implies [0,0,0]$.
   2. Verify mutual exclusion: $\sum g_b \le 1$. If violated, force all gates to zero (fail-safe).
   3. During phase switching in high-speed testbench, delay the turn-on of the incoming MOSFET channel by $t_d = 5.0\,\mu\text{s}$ after the outgoing MOSFET channel is commanded off.
4. **Mathematical Formulas:**
   $$g_b(t) = \begin{cases} 1, & \text{if } u(t) = b \text{ and } t - t_{\text{switch}} \ge t_d \\ 0, & \text{otherwise} \end{cases} \tag{34}$$
5. **Analogy Role:** Replicates the all-red traffic clearance interval at the microsecond semiconductor switching layer, preventing shoot-through bridge cross-conduction.
6. **Importance:** Without dead-time, complementary MOSFET switching causes simultaneous conduction, resulting in severe supply short-circuits.
7. **Parameters:** $t_d = 5.0\,\mu\text{s}$, simulation resolution $\Delta t_{\text{sim}} = 1.0\,\mu\text{s}$ (`SITRA_Deadtime_Testbench.slx`).
8. **Why This Algorithm:** Standard gate-driver interlock logic used in industrial half-bridge and three-phase motor drives.
9. **Theoretical Properties:** Strictly guarantees $\max(\sum g_b) \le 1.0$ and measured minimum dead-time $\ge 5.0\,\mu\text{s}$ across all switching events.
10. **Computational Cost:** Continuous Simscape simulation executed in $0.42\text{ s}$ for a 600-second timeline.

---

## 6.8 Arrival Generation and Stochastic Sampling
1. **Name and Layer:** Multi-Seed Arrival Generation Engine (`FLAT/baselines/bl_make_arrivals.m`, Layer L1).
2. **Plain Description:** Computes arrival matrices across simulation time steps using either deterministic profiles or stochastic Poisson random generators initialized by explicit seed values.
3. **Step-by-Step Procedure:**
   1. Receive scenario duration $T$, demand function `demandFcn`, and integer `seed`.
   2. If `seed == 0` (deterministic), evaluate continuous demand curve $\lambda_b(t)$ directly.
   3. If `seed > 0` (stochastic), initialize random number generator with `rng(seed)`.
   4. For each time step $t$, draw Poisson arrival count $A_b(t) \sim \text{Poisson}(\lambda_b(t) \Delta t)$.
   5. Return arrival matrix $\mathbf{A} \in \mathbb{R}^{N \times 4}$.
4. **Mathematical Formulas:**
   $$P(A_b(t) = k) = \frac{(\lambda_b(t)\Delta t)^k e^{-\lambda_b(t)\Delta t}}{k!}, \quad k \in \{0, 1, 2, \dots\} \tag{35}$$
5. **Analogy Role:** Acts as an exogenous non-ideal current source injecting stochastic current pulses into the capacitor network.
6. **Importance:** Enables repeatable statistical benchmarking across identical arrival realizations (Seeds 101–105).
7. **Parameters:** Seeds $101, 102, 103, 104, 105$ (`bl_scenarios.m`).
8. **Why This Algorithm:** Standard Poisson arrival process widely verified in empirical transportation engineering [1], [8].
9. **Theoretical Properties:** Memoryless Poisson counting process with variance equal to mean ($\text{Var}(A) = \text{E}(A)$).
10. **Computational Cost:** $0.8\text{ ms}$ per 900-second trajectory generation.

---

## 6.9 Non-Circular Twin-Run Clearance Metric
1. **Name and Layer:** Moving-Average Twin-Run Clearance Metric (`FLAT/baselines/bl_clearance.m`, Layer L5).
2. **Plain Description:** Quantifies congestion recovery time by measuring when the moving-average queue of an event run converges back to the queue of a paired no-congestion twin run.
3. **Step-by-Step Procedure:**
   1. Receive event queue $Q(t)$, twin queue $Q_{\text{twin}}(t)$, event termination time $t_{\text{event}}$, and options ($W = 120\text{ s}$, $\delta = 1.0\text{ veh}$, $H = 60\text{ s}$).
   2. Compute 120-second centered moving averages: $\bar{Q}(t) = \text{movmean}(Q, W/\Delta t)$ and $\bar{Q}_{\text{twin}}(t) = \text{movmean}(Q_{\text{twin}}, W/\Delta t)$.
   3. Compute divergence differential: $d(t) = \bar{Q}(t) - \bar{Q}_{\text{twin}}(t)$.
   4. Find first index $t^* \ge t_{\text{event}}$ such that $|d(t)| \le \delta$ for all $t \in [t^*, t^* + H]$.
   5. If condition is met, $t_{\text{clear}} = t^* - t_{\text{event}}$ and $\text{cleared} = \text{true}$; if condition holds at $t_{\text{event}}$, $t_{\text{clear}} = 0\text{ s}$; if never satisfied, $t_{\text{clear}} = \text{NaN}$.
   6. Compute cumulative excess vehicle-delay: $E_{\text{veh}} = \int_{t_{\text{event}}}^{T} \max(0, Q(t) - Q_{\text{twin}}(t)) dt$.
4. **Mathematical Formulas:**
   $$d(t) = \frac{1}{W}\int_{t - W/2}^{t + W/2} Q(\tau) d\tau - \frac{1}{W}\int_{t - W/2}^{t + W/2} Q_{\text{twin}}(\tau) d\tau \tag{36}$$
   $$E_{\text{veh}} = \sum_{k: t_k \ge t_{\text{event}}} \max\left(0, \; Q(k) - Q_{\text{twin}}(k)\right) \Delta t \quad [\text{veh}\cdot\text{s}] \tag{37}$$
5. **Analogy Role:** Equivalent to measuring the recovery settling time of an electrical capacitor bank discharging back to its nominal steady-state load voltage following a transient current pulse.
6. **Importance:** Replaces circular baseline window definitions, resolving false "Not cleared" results by filtering cyclic signal ripple.
7. **Parameters:** $W = 120.0\text{ s}$, $\delta = 1.0\text{ veh}$, $H = 60.0\text{ s}$ (`bl_clearance.m`).
8. **Why This Algorithm:** Alternatives: Absolute threshold ($Q \le Q_{\text{base}} + 1$). Absolute thresholds fail because cyclic signal oscillations ($5\text{–}8\text{ veh}$) violate a 60-second hold window even in uncongested steady flow.
9. **Theoretical Properties:** Moving-average filter removes signal cycle harmonics ($f_{\text{cycle}} \approx 1/63\text{ Hz}$) while preserving low-frequency congestion dissipation dynamics.
10. **Computational Cost:** $< 0.05\text{ ms}$ per trajectory evaluation.

---

## 6.10 Closed-Loop Buck DC-DC Voltage Compensator
1. **Name and Layer:** Buck Converter PI Voltage Controller (`FLAT/S5_physical/build_SITRA_S5_Physical.m`, Layer L3).
2. **Plain Description:** Regulates the 24.0 V DC distribution bus by computing error between measured bus voltage and 24 V reference, adjusting PWM switching duty cycle via a PI law.
3. **Step-by-Step Procedure:**
   1. Measure instantaneous bus voltage $V_{\text{bus}}(t)$ via voltage sensor and PS-Simulink converter.
   2. Compute error: $e_v(t) = V_{\text{ref}} - V_{\text{bus}}(t)$, where $V_{\text{ref}} = 24.0\text{ V}$.
   3. Compute PI control effort: $u_{\text{pi}}(t) = K_p e_v(t) + K_i \int e_v(\tau) d\tau$.
   4. Clamp duty cycle to physical limits: $D(t) = \text{sat}(u_{\text{pi}}(t), 0, D_{\max})$.
   5. Modulate $10\text{ kHz}$ triangle carrier to generate binary gate pulse for buck MOSFET.
4. **Mathematical Formulas:**
   $$D(t) = \text{clip}\left( K_p [V_{\text{ref}} - V_{\text{bus}}(t)] + K_i \int_{0}^{t} [V_{\text{ref}} - V_{\text{bus}}(\tau)] d\tau, \; 0, \; D_{\max} \right) \tag{38}$$
5. **Analogy Role:** Core voltage regulation mechanism ensuring stable signal-head supply across sudden load changes (when a 1 A signal head turns on/off).
6. **Importance:** Without voltage control, bus voltage droops or spikes during switching, tripping under-voltage protection and extinguishing signal heads.
7. **Parameters:** $V_{\text{ref}} = 24.0\text{ V}$, $K_p = 0.03\text{ V}^{-1}$, $K_i = 25.0\,(\text{V}\cdot\text{s})^{-1}$, $D_{\max} = 0.95$, $f_{\text{sw}} = 10\text{ kHz}$ (`S5_physical_params.m`).
8. **Why This Algorithm:** Classical industrial PI voltage compensator. Chosen for zero steady-state error and robust phase margin ($> 55^\circ$).
9. **Theoretical Properties:** Proven zero steady-state error for step load disturbances under linear averaged model [29], [30].
10. **Computational Cost:** Solved continuously inside Simscape DAE engine; verified to execute in $34\text{ s}$ for 600 s simulation.

---

## 6.11 Bus Under-Voltage (UV) Protection Trip
1. **Name and Layer:** Distribution Bus Under-Voltage Supervisor (`FLAT/S5_physical/build_SITRA_S5_Physical.m`, Layer L3).
2. **Plain Description:** Latches all gate drives off if the 24 V distribution bus collapses below $18.0\text{ V}$ ($75\%$) after an initial $246\text{ ms}$ startup blanking period.
3. **Step-by-Step Procedure:**
   1. Monitor bus voltage $V_{\text{bus}}(t)$.
   2. Evaluate startup blanking condition: if $t \le t_{\text{blank}} = 0.246\text{ s}$, disable UV trip (allow capacitors to charge).
   3. For $t > t_{\text{blank}}$, compare $V_{\text{bus}}(t)$ against $V_{\text{UV}} = 0.75 \times 24.0\text{ V} = 18.0\text{ V}$.
   4. If $V_{\text{bus}}(t) < 18.0\text{ V}$, trip latch: set $\text{UV\_fault} = 1$ and clamp all MOSFET gates to $0\text{ V}$.
4. **Mathematical Formulas:**
   $$\text{Gate\_Enable}(t) = \begin{cases} 1, & \text{if } t \le t_{\text{blank}} \lor V_{\text{bus}}(t) \ge 0.75 V_{\text{ref}} \\ 0, & \text{if } t > t_{\text{blank}} \land V_{\text{bus}}(t) < 0.75 V_{\text{ref}} \end{cases} \tag{39}$$
5. **Analogy Role:** Emulates traffic signal hardware conflict monitors (flasher units) that de-energize green indications when power grid voltage browns out.
6. **Importance:** Prevents erratic LED signal head operation and MOSFET linear-region thermal runaway during power sags.
7. **Parameters:** $V_{\text{UV}} = 18.0\text{ V}$, $t_{\text{blank}} = 0.246\text{ s}$ (`S5_physical_params.m`).
8. **Why This Algorithm:** Mandated by municipal traffic signal electrical specifications (NEMA TS2 conflict monitor standards).
9. **Theoretical Properties:** Binary comparator supervisor with temporal blanking.
10. **Computational Cost:** Continuous Simscape comparator; negligible overhead.

---

## 6.12 Channel Over-Current (OC) Protection Latch
1. **Name and Layer:** Channel Over-Current Latch (`FLAT/S5_physical/build_SITRA_S5_Physical.m`, Layer L3).
2. **Plain Description:** Disables MOSFET gate drives if any signal-head channel current exceeds $2.0\text{ A}$ (twice nominal load).
3. **Step-by-Step Procedure:**
   1. Measure channel currents $I_{\text{ch}, 1}, I_{\text{ch}, 2}, I_{\text{ch}, 3}$ using physical current sensors.
   2. Evaluate maximum channel current: $I_{\max}(t) = \max_b |I_{\text{ch}, b}(t)|$.
   3. If $I_{\max}(t) \ge I_{\text{trip}} = 2.0\text{ A}$, assert over-current latch.
   4. De-assert gate drive signals to protect power semiconductors from short-circuit burn-out.
4. **Mathematical Formulas:**
   $$\text{OC\_Trip} = \begin{cases} 1, & \text{if } \exists b \in \{1, 2, 3\} : |I_{\text{ch}, b}| \ge I_{\text{trip}} \\ 0, & \text{otherwise} \end{cases} \tag{40}$$
5. **Analogy Role:** Protects physical driver hardware from short circuits in signal heads.
6. **Importance:** Mandatory hardware protection ensuring physical circuit survivability.
7. **Parameters:** $I_{\text{trip}} = 2.0\text{ A}$ (`S5_physical_params.m`).
8. **Why This Algorithm:** Standard fast-acting semiconductor overcurrent protection.
9. **Theoretical Properties:** Instantaneous threshold detection.
10. **Computational Cost:** Continuous Simscape block; negligible overhead.

---

## 6.13 Physical Spill-Back Voltage Clamp
1. **Name and Layer:** B4 Physical Spill-Back Comparator Clamp (`FLAT/S5_physical/build_SITRA_S5_Physical.m`, Layer L1, L3).
2. **Plain Description:** Uses a physical voltage sensor and comparator on capacitor $C_{B4}$ to inhibit upstream current sinks whenever downstream queue voltage reaches $15.0\text{ V}$.
3. **Step-by-Step Procedure:**
   1. Sample capacitor voltage $v_{C4}(t)$ through zero-order hold at $T_s = 1.0\text{ s}$.
   2. Compare against threshold: $\text{B4\_OK} = (v_{C4}(t) < q_{4\max} - 10^{-4}\text{ V})$.
   3. Feed $\text{B4\_OK}$ into input 3 of the Interlock product block.
   4. If $v_{C4} \ge 14.9999\text{ V}$, $\text{B4\_OK} = 0$, clamping upstream discharge current sinks to $0\text{ A}$ (zero code blocks inside physical subsystems).
4. **Mathematical Formulas:**
   $$i_{\text{dep}, b}(t) = g_b(t) \cdot \mathbb{I}\left(v_{C4}(t) < q_{4\max} - 10^{-4}\right) \cdot \min\left(C_b, \frac{v_{Cb}(t)}{\Delta t}\right), \quad \forall b \in \{1, 2, 3\} \tag{41}$$
5. **Analogy Role:** Operates as a DC-link over-voltage clamp shutting down upstream buck/boost converter stages during downstream over-voltage.
6. **Importance:** Faithfully enforces traffic spill-back physics inside pure Simscape electrical circuits.
7. **Parameters:** $q_{4\max} = 15.0\text{ V}$ (`S5_physical_params.m`, `bl_plant_step.m`).
8. **Why This Algorithm:** Formulated strictly with Simulink/Simscape relational operator blocks, avoiding MATLAB Function or S-Function code blocks.
9. **Theoretical Properties:** Eliminates algebraic loops by utilizing discrete zero-order hold sampling on continuous sensor outputs.
10. **Computational Cost:** Zero computational penalty; matches discrete plant step to $2.45\,\mu\text{V}$.

---

## 6.14 General Congestion and Fault Injector
1. **Name and Layer:** Dual-Domain Congestion & Fault Injection Library (`FLAT/baselines/bl_inject.m`, Layer L1, L4, L5).
2. **Plain Description:** Dynamically modifies arrivals, plant capacities, sensor readings, and gate signals to simulate physical incidents, downstream blockages, sensor faults, and signal hardware failures.
3. **Step-by-Step Procedure:**
   1. Define event structs: `type`, `branch`, `tStart`, `tEnd`, `mag`.
   2. `apply_demand`: Scales arrival rates by $(1 + \text{mag})$ or injects periodic vehicle pulses.
   3. `apply_network`: Replaces static capacity vector with time-varying handle $\mathbf{C}(t) = \mathbf{C}_{\text{nominal}} \cdot (1 - \text{mag})$ during active window.
   4. `apply_sensor`: Freezes observed queue $q_{\text{seen}}(b) = q_b(t_{\text{start}})$ (`sensor_stuck`) or adds Gaussian noise $q_{\text{seen}}(b) = \max(0, q_b + \mathcal{N}(0, \sigma^2))$ via deterministic Box-Muller transformation without perturbing global RNG.
   5. `apply_gates`: Forces active gate signal $g_b(t) = 0$ during event window (`signal_stuck_off`).
4. **Mathematical Formulas:**
   $$\text{Box-Muller Noise: } z = \sqrt{-2\ln(u_1)} \cos(2\pi u_2), \quad q_{\text{seen}} = \max(0, \; q + \sigma_{\text{noise}} z) \tag{42}$$
5. **Analogy Role:** Models electrical faults (ADC noise, sensor freeze, open-circuit MOSFET gate failures, and transmission line capacity de-rating).
6. **Importance:** Powers the comprehensive disturbance benchmark across scenarios T9–T14.
7. **Parameters:** Incident de-rating $\text{mag} = 0.50$, noise $\sigma = 2.0\text{ veh}$, blockage $q_{4\max} = 15.0\text{ veh}$ (`bl_scenarios.m`).
8. **Why This Algorithm:** Modular architecture decoupling plant simulation from disturbance injection.
9. **Theoretical Properties:** Deterministic Box-Muller generator ensures exact statistical reproducibility across repeated runs.
10. **Computational Cost:** $< 0.01\text{ ms}$ per call.

---

## 6.15 Capacitor Parasitic Modeling and ESR Compensation (Stage S6)
1. **Name and Layer:** Capacitor Parasitic Model and Dynamic ESR Compensator (`FLAT/S6_S7_parasitics/run_all_S6_S7.m`, Layer L1).
2. **Plain Description:** Analyzes the distorting effects of equivalent series resistance (ESR), equivalent series inductance (ESL), and dielectric leakage on 1 F queue capacitors, synthesizing a feedforward voltage compensator.
3. **Step-by-Step Procedure:**
   1. Model non-ideal capacitor terminal voltage: $v_{\text{term}}(t) = v_C(t) + i_C(t) R_{\text{esr}} + L_{\text{esl}} \frac{di_C}{dt} + R_{\text{leak}} i_{\text{leak}}$.
   2. Simulate uncompensated terminal voltage under Part 8 surge current, observing voltage jumps $\Delta V = I_{\text{step}} R_{\text{esr}}$.
   3. Implement active compensation filter: $\hat{v}_C(t) = v_{\text{term}}(t) - i_{\text{meas}}(t) R_{\text{esr}} - L_{\text{esl}} \frac{di_{\text{meas}}}{dt}$.
   4. Verify compensated voltage tracking error returns to $< 1.0\times 10^{-4}\text{ V}$.
4. **Mathematical Formulas:**
   $$\hat{v}_C(t) = v_{\text{term}}(t) - R_{\text{esr}} i_C(t) \tag{43}$$
5. **Analogy Role:** Corrects sensor measurement distortion caused by physical capacitor non-idealities in real hardware implementation.
6. **Importance:** Prevents apparent queue inflation when large charging currents enter physical capacitors.
7. **Parameters:** $R_{\text{esr}} = 50\,\text{m}\Omega$, $L_{\text{esl}} = 10\,\text{nH}$, $R_{\text{leak}} = 1.0\,\text{M}\Omega$ (`run_all_S6_S7.m`).
8. **Why This Algorithm:** Standard real-time battery and supercapacitor state-of-charge (SoC) estimation technique.
9. **Theoretical Properties:** Linear feedforward inversion of ohmic voltage drops.
10. **Computational Cost:** Executed in $1.15\text{ s}$ total simulation time.

---

## 6.16 Semiconductor Thermal Losses and Equilibrium Model (Stage S7)
1. **Name and Layer:** MOSFET Conduction/Switching Loss & Thermal Model (`FLAT/S6_S7_parasitics/run_all_S6_S7.m`, Layer L4).
2. **Plain Description:** Calculates instantaneous conduction and switching energy dissipation across signal-head MOSFET channels, computing junction temperature rise under thermal equilibrium.
3. **Step-by-Step Procedure:**
   1. Compute instantaneous conduction loss: $P_{\text{cond}}(t) = I_{\text{ch}}(t)^2 R_{\text{ds(on)}}$.
   2. Compute turn-on and turn-off switching losses: $E_{\text{sw}} = \frac{1}{2} V_{\text{bus}} I_{\text{ch}} (t_{\text{on}} + t_{\text{off}})$.
   3. Integrate total electrical losses: $E_{\text{total}} = \int P_{\text{cond}} dt + \sum E_{\text{sw}}$.
   4. Model thermal equivalent network: junction-to-ambient thermal resistance $R_{\theta\text{ja}}$ and thermal capacitance $C_{\theta j}$.
   5. Compute thermal equilibrium temperature: $T_j = T_{\text{ambient}} + P_{\text{avg}} R_{\theta\text{ja}}$.
4. **Mathematical Formulas:**
   $$P_{\text{loss}} = I_{\text{ch}}^2 R_{\text{ds(on)}} + f_{\text{sw}} E_{\text{sw}} \tag{44}$$
   $$T_j(t) = T_{\text{amb}} + (T_{j0} - T_{\text{amb}}) e^{-t / \tau_{\text{th}}} + P_{\text{loss}} R_{\theta\text{ja}} \left(1 - e^{-t / \tau_{\text{th}}}\right) \tag{45}$$
5. **Analogy Role:** Sizing physical heat-sinking and power ratings for signal cabinet switching modules.
6. **Importance:** Ensures MOSFET junction temperatures remain safely below semiconductor damage thresholds ($T_j < 150^\circ\text{C}$).
7. **Parameters:** $R_{\text{ds(on)}} = 0.044\,\Omega$, $t_{\text{on}} = 50\,\text{ns}$, $t_{\text{off}} = 50\,\text{ns}$, $R_{\theta\text{ja}} = 62.0\,^\circ\text{C/W}$, $T_{\text{amb}} = 35.0\,^\circ\text{C}$ (`run_all_S6_S7.m`).
8. **Why This Algorithm:** Standard IEEE/JEDEC thermal modeling methodology for power semiconductor devices.
9. **Theoretical Properties:** First-order linear thermal diffusion differential equation.
10. **Computational Cost:** Executed in $1.22\text{ s}$ total simulation time; confirmed maximum $T_j = 37.8^\circ\text{C}$ ($2.8^\circ\text{C}$ rise above ambient).

---

## 6.17 Simscape Differential Algebraic Equation (DAE) Solver
1. **Name and Layer:** Simscape Variable-Step Numerical DAE Solver (`FLAT/S5_physical/build_SITRA_S5_Physical.m`, Layers L1, L2, L3).
2. **Plain Description:** Integrates the coupled multi-domain physical differential algebraic equations governing electrical circuit state evolution while enforcing Kirchhoff laws.
3. **Step-by-Step Procedure:**
   1. Initialize solver engine with `daessc` (Differential Algebraic Equation Simscape Solver) or fallback to `ode23t` (trapezoidal rule with free interpolation).
   2. Set integration error tolerances: Relative Tolerance $\text{RelTol} = 1.0\times 10^{-6}$, Absolute Tolerance $\text{AbsTol} = 1.0\times 10^{-9}$.
   3. Bound maximum integration step: $\text{MaxStep} = 0.05\text{ s}$ (`S5.maxStep`).
   4. Configure Power Path subsystem with Simscape Local Solver: Sample Time $T_{s, \text{local}} = 2.0\,\mu\text{s}$ using backward Euler solver.
   5. Configure diagnostic parameter `'AlgebraicLoopMsg'` to `'none'` to evaluate discrete-continuous zero-order hold boundaries cleanly.
4. **Mathematical Formulas:**
   $$\mathbf{F}\left(t, \mathbf{x}_{\text{circ}}, \dot{\mathbf{x}}_{\text{circ}}, \mathbf{y}_{\text{alg}}\right) = \mathbf{0} \tag{46}$$
5. **Analogy Role:** The numerical execution engine that physically drives the virtual electronic circuit.
6. **Importance:** Improper solver selection causes algebraic loop stagnation, numerical chattering, or false current spikes.
7. **Parameters:** $\text{RelTol} = 10^{-6}$, $\text{AbsTol} = 10^{-9}$, $\text{MaxStep} = 0.05\text{ s}$, $T_{s, \text{local}} = 2.0\,\mu\text{s}$ (`build_SITRA_S5_Physical.m`).
8. **Why This Algorithm:** Alternatives: Explicit Runge-Kutta (`ode45`) or stiff Euler (`ode15s`). Explicit solvers cannot solve differential algebraic equations with algebraic constraints (Kirchhoff loops); `daessc` and `ode23t` are designed specifically for physical electrical networks with non-dissipative capacitors and switching inductors.
9. **Theoretical Properties:** Second-order A-stable trapezoidal integration scheme preserving energy conservation without artificial numerical damping [29], [30].
10. **Computational Cost:** Simulates 600 seconds of physical circuit operation in $0.70\text{–}1.80\text{ s}$ wall-clock time.
