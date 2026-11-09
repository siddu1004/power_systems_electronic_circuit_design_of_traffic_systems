# 5. Problem Formulation and Explicit Model Assumptions

This section provides the formal mathematical problem formulation governing traffic queue dynamics, control optimization objectives, and operational constraints, followed by an explicit, numbered enumeration of all modeling assumptions.

## 5.1 State-Space Formulation
We consider a discrete-time dynamic model of the signalized intersection with sampling interval $\Delta t = 1.0\text{ s}$. The state vector at time step $k \in \{0, 1, \dots, N-1\}$ is defined as:
$$\mathbf{x}(k) = \begin{bmatrix} q_1(k) \\ q_2(k) \\ q_3(k) \\ q_4(k) \end{bmatrix} \in \mathbb{R}_{\ge 0}^4 \tag{10}$$
where $q_1(k)$, $q_2(k)$, and $q_3(k)$ denote the vehicular queues on upstream approaches B1, B2, and B3, and $q_4(k)$ denotes the vehicular accumulation on downstream bottleneck link B4.

The control input vector is the binary gate indication:
$$\mathbf{g}(k) = \begin{bmatrix} g_1(k) \\ g_2(k) \\ g_3(k) \end{bmatrix} \in \{0, 1\}^3 \tag{11}$$
where $g_b(k) = 1$ indicates that approach $b$ receives a green signal indication, and $g_b(k) = 0$ indicates a red indication.

The disturbance vector comprises exogenous arrival demands:
$$\mathbf{d}(k) = \begin{bmatrix} \lambda_1(k) \\ \lambda_2(k) \\ \lambda_3(k) \end{bmatrix} \in \mathbb{R}_{\ge 0}^3 \tag{12}$$
where $\lambda_b(k)$ is the volume of vehicles arriving on approach $b$ during interval $[k\Delta t, (k+1)\Delta t)$.

The system state evolves according to the discrete-time non-linear conservation equation:
$$q_b(k+1) = \max\left(0, \; q_b(k) + \lambda_b(k)\Delta t - \mu_b(k)\Delta t\right), \quad \forall b \in \{1, 2, 3\} \tag{13}$$
where the instantaneous departure rate $\mu_b(k)$ is governed by approach capacity $C_b(k)$, gate state $g_b(k)$, and downstream spill-back condition:
$$\mu_b(k) = \begin{cases} 
0, & \text{if } q_4(k) \ge q_{4\max} \\
g_b(k) \cdot \min\left(C_b(k), \; \frac{q_b(k)}{\Delta t} + \lambda_b(k)\right), & \text{if } q_4(k) < q_{4\max}
\end{cases} \tag{14}$$

For downstream link B4, vehicular accumulation evolves as:
$$q_4(k+1) = \max\left(0, \; q_4(k) + \sum_{b=1}^{3} \mu_b(k)\Delta t - \mu_4(k)\Delta t\right) \tag{15}$$
where downstream exit discharge is limited by exit capacity $C_4$:
$$\mu_4(k) = \min\left(C_4(k), \; \frac{q_4(k)}{\Delta t} + \sum_{b=1}^{3}\mu_b(k)\right) \tag{16}$$

In Layer L1, the observed output vector is the full state under measurement noise $\mathbf{v}(k)$:
$$\mathbf{y}(k) = \mathbf{x}(k) + \mathbf{v}(k) \tag{17}$$

## 5.2 Control Objectives and Cost Metrics
The primary optimization objectives evaluated across the control architectures include:
1. **Congestion Clearance Time ($t_{\text{clear}}$):** The elapsed time in seconds from the termination of an overload event ($t_{\text{event}}$) until the smoothed approach queue matches the no-congestion twin run queue within tolerance $\delta = 1.0\text{ veh}$ and sustains that bound for hold window $H = 60\text{ s}$:
   $$t_{\text{clear}} = \min \left\{ t \ge t_{\text{event}} \;:\; \left| \bar{Q}(t') - \bar{Q}_{\text{twin}}(t') \right| \le \delta, \; \forall t' \in [t, t + H] \right\} - t_{\text{event}} \tag{18}$$
   where $\bar{Q}(t) = \frac{1}{W} \int_{t - W/2}^{t + W/2} \sum_{b=1}^{3} q_b(\tau) d\tau$ with moving-average window $W = 120.0\text{ s}$.
2. **Cumulative Excess Vehicle Delay ($E_{\text{veh}}$):** The integral of net excess queue accumulation caused by the congestion disturbance:
   $$E_{\text{veh}} = \int_{t_{\text{event}}}^{T} \max\left(0, \; \sum_{b=1}^{3} q_b(\tau) - \sum_{b=1}^{3} q_{b, \text{twin}}(\tau)\right) d\tau \quad [\text{veh}\cdot\text{s}] \tag{19}$$
3. **Average Control Delay per Vehicle ($d_{\text{avg}}$):** Total vehicular waiting time normalized by total throughput over duration $T$:
   $$d_{\text{avg}} = \frac{\sum_{k=0}^{N-1} \sum_{b=1}^{3} q_b(k) \Delta t}{\sum_{k=0}^{N-1} \mu_4(k) \Delta t} \quad [\text{s/veh}] \tag{20}$$
4. **Network Intersection Delay ($D_{\text{net}}$):** Total delay including vehicles stored on downstream link B4:
   $$D_{\text{net}} = \frac{\sum_{k=0}^{N-1} \sum_{b=1}^{4} q_b(k) \Delta t}{\sum_{k=0}^{N-1} \mu_4(k) \Delta t} \quad [\text{s/veh}] \tag{21}$$

## 5.3 Operational and Physical Constraints
Every controller and circuit component must strictly satisfy five operational constraints:
1. **Mutual Exclusion Constraint:** At most one approach phase may receive a green indication at any time:
   $$\sum_{b=1}^{3} g_b(k) \le 1, \quad \forall k \tag{22}$$
2. **Phase Duration Bounds:** For cycle-based controllers, green intervals must satisfy minimum and maximum bounds:
   $$g_{\min} \le g_b \le g_{\max}, \quad \forall b \in \{1, 2, 3\} \tag{23}$$
   where $g_{\min} = 12.0\text{ s}$ and $g_{\max} = 30.0\text{ s}$ for a total cycle of $T_{\text{cycle}} = 63.0\text{ s}$.
3. **Semiconductor Dead-Time / Interlock:** An absolute non-overlapping dead-time $t_d = 5.0\,\mu\text{s}$ must separate conduction states between conflicting MOSFET driver channels to prevent phase cross-conduction.
4. **Non-Negativity Constraint:** Queues and capacitor charges cannot take negative values:
   $$q_b(k) \ge 0, \quad v_{Cb}(t) \ge 0, \quad \forall b, k, t \tag{24}$$
5. **Bus Voltage Regulation Boundary:** The power-electronic distribution bus must maintain regulation within $\pm 10\%$ of nominal $24.0\text{ V}$ during channel switching:
   $$21.6\text{ V} \le V_{\text{bus}}(t) \le 26.4\text{ V}, \quad \forall t \ge t_{\text{blank}} \tag{25}$$

## 5.4 Numbered Enumeration of Modeling Assumptions
To maintain absolute scientific transparency, we explicitly enumerate all assumptions embedded in this research, detailing their physical justification and their direct impact on the reported results:

1. **Assumption 1 (Continuous Fluid Queue Formulation):** Traffic is modeled as a continuous fluid volume rather than discrete individual motor vehicles.
   - *Justification:* Necessary to establish exact mathematical duality with continuous electrostatic charge accumulation ($dq/dt = i_{\text{in}} - i_{\text{dep}}$).
   - *Effect on Results:* Eliminates micro-stochastic vehicle headway variations within a second, producing smooth queue trajectories that allow precise $1\,\mu\text{V}$-level circuit tracking.
2. **Assumption 2 (Point-Queue Representation):** Queues accumulate vertically at the stop line without spatial link length or physical backward-propagating shockwaves.
   - *Justification:* Enables state-space linear modeling for multi-cycle MPC without non-linear spatial grid discretizations.
   - *Effect on Results:* Link travel times between upstream entry points and the stop line are zero. While valid for compact intersection approaches, spatial shockwave delay is omitted.
3. **Assumption 3 (Assumed Approach Capacities):** Stop-line discharge capacities are assumed to be fixed constants ($C_1 = 0.65$, $C_2 = 0.35$, $C_3 = 0.25$, $C_4 = 0.45\text{ veh/s}$) in baseline runs.
   - *Justification:* Established as standard frozen benchmark values in `createNetwork.m`.
   - *Effect on Results:* Real-world capacities fluctuate with weather, vehicle mix, and driver aggressiveness. The absolute delay numbers depend directly on these assumed values.
4. **Assumption 4 (Synthetic Inflow Demand Profiles):** Demand arrival matrices are generated synthetically using deterministic steps, Poisson distributions, and pseudo-random pulse trains rather than recorded loop-detector traces.
   - *Justification:* Enables reproducible, controlled comparative testing across identical statistical seeds (101–105).
   - *Effect on Results:* Allows exact twin-run isolation of congestion events, though empirical Coimbatore driver arrival distributions may exhibit greater diurnal variance.
5. **Assumption 5 (Isolated Intersection Boundary):** The SITRA junction is treated as an isolated intersection without coordinated arterial progression from upstream signals (e.g., Hope College or Airport signals).
   - *Justification:* Establishes an uncorrupted benchmark for comparing intrinsic controller clearing capabilities before addressing corridor-level offset coordination.
   - *Effect on Results:* Coordination benefits (such as green waves) are not evaluated; arrivals on B1 are modeled as exogenous inputs rather than coordinated platoons (except in T11).
6. **Assumption 6 (Perfect Full-State Feedback in Nominal Scenarios):** In scenarios T1–T11 and T14, controllers observe true queue states without estimation error ($q_{\text{seen}} = q$).
   - *Justification:* Separates algorithmic clearing capability from sensor estimation noise.
   - *Effect on Results:* Represents idealized detector operation. Scenarios T12 (stuck sensor) and T13 (Gaussian noise) explicitly relax this assumption to evaluate robustness.
7. **Assumption 7 (Open-Loop Replay into Simscape Physical Model):** The Simscape physical circuit executes gate switching commands pre-computed by the discrete simulation harness rather than closing the control loop from analog voltage sensors.
   - *Justification:* Verifies that the physical power-electronic circuit tracks discrete mathematical trajectories without numerical solver divergence before deploying embedded microcontrollers.
   - *Effect on Results:* Demonstrates physical plant tracking fidelity ($< 8\,\mu\text{V}$ error), but does not test real-time digital controller feedback latency.
8. **Assumption 8 (Placeholder Power Component Ratings):** Component values in Layer L2 and L3 ($C_{\text{dc}} = 2200\,\mu\text{F}$, $L_{\text{buck}} = 2.0\text{ mH}$) represent functional engineering placeholders for simulation verification, to be finalized in hardware procurement stage S12.
   - *Justification:* Allows verification of power-flow architecture and protection topologies prior to board-level hardware prototyping.
   - *Effect on Results:* Absolute efficiency and thermal loss numbers reflect idealized component models rather than specific commercial semiconductor part numbers.

## 5.5 System Boundary Definition
Fig. 5.1 delineates the operational system boundary.

- **Inside the System Boundary:** Vehicular queues on branches B1, B2, B3, and B4; signal phase selection logic; minimum/maximum green bounds; $5\,\mu\text{s}$ hardware dead-time; 230 V AC to 24 V DC power conversion; DC-link energy storage; over-current and under-voltage protection; and MOSFET signal-head driver channels.
- **Outside the System Boundary:** Pedestrian crossing phases; right/left turning lane exclusive pockets; upstream intersection coordination; individual vehicle fuel consumption; and driver psychophysical car-following mechanics.
