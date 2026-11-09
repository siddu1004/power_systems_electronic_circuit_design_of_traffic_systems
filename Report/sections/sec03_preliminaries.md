# 2.1. Preliminaries and Term Definitions

To establish technical rigor across both transportation engineering and electrical systems domains, this section defines the core nomenclature and mathematical relationships utilized throughout this work.

### Phase ($u$)
A signal phase is a non-conflicting combination of vehicular traffic movements that receive simultaneous right-of-way (green indication). In the three-approach SITRA junction, three distinct phases are defined: Phase 1 serves Branch 1 (Hope College arterial flow), Phase 2 serves Branch 2 (Kalapatti Road), and Phase 3 serves Branch 3 (Airport Road). A discrete index $u(k) \in \{1, 2, 3\}$ denotes the active phase at time step $k$.

### Cycle Length ($C_{\text{cyc}}$ or $T_{\text{cycle}}$)
The total time required for one complete sequence of signal indications across all phases. In this study, the cycle length is fixed at:
$$T_{\text{cycle}} = \sum_{b=1}^{3} g_b + L_{\text{lost}} = 63.0\text{ s} \tag{1}$$
where $g_b$ represents the green interval allocated to approach $b$ and $L_{\text{lost}}$ represents total intersection lost time.

### Green Split ($\gamma_b$)
The proportion of the effective cycle time allocated to a specific approach phase $b$:
$$\gamma_b = \frac{g_b}{T_{\text{cycle}}} \tag{2}$$
Under mutual exclusion, the sum of green splits satisfies $\sum_{b=1}^{3} \gamma_b \le 1.0$.

### Offset ($\theta$)
The time difference in seconds between a defined system time reference point and the start of the green indication at a specific intersection. In isolated junction modeling (such as the single SITRA junction considered here), $\theta = 0\text{ s}$.

### Signal Intervals: Green, Amber, and All-Red
- **Green Interval ($g$):** The period during which vehicles on the approach are permitted to enter the intersection.
- **Amber / Change Interval ($y$):** The warning transition interval informing drivers that right-of-way is terminating.
- **All-Red Clearance Interval ($r_{\text{all}}$):** The safety interval where all approaches are displayed red to allow vehicles within the intersection conflict zone to clear before conflicting traffic is released. In the physical circuit, the all-red clearance is mapped directly to semiconductor dead-time ($t_d$).

### Saturation Flow Rate ($s_b$) and Capacity ($C_b$)
The saturation flow rate $s_b$ is the maximum continuous discharge rate across the stop line when an approach has an infinite queue and green indication. Capacity $C_b$ (expressed in vehicles per second, $\text{veh/s}$) represents the maximum average service flow rate:
$$C_b = s_b \cdot \frac{g_b}{T_{\text{cycle}}} \tag{3}$$
In this study, the maximum instantaneous stop-line saturation flow rates are assumed to be $C_1 = 0.65\text{ veh/s}$ ($2340\text{ veh/h}$), $C_2 = 0.35\text{ veh/s}$ ($1260\text{ veh/h}$), $C_3 = 0.25\text{ veh/s}$ ($900\text{ veh/h}$), and downstream exit capacity $C_4 = 0.45\text{ veh/s}$ ($1620\text{ veh/h}$).

### Degree of Saturation / Volume-to-Capacity Ratio ($X_b$ or $v/c$)
The ratio of arrival demand flow rate $\lambda_b$ to approach capacity $C_b$:
$$X_b = \frac{\lambda_b}{C_b} = \frac{\lambda_b \cdot T_{\text{cycle}}}{s_b \cdot g_b} \tag{4}$$
When $X_b < 0.85$, traffic operates in undersaturated conditions; when $X_b \ge 1.0$, the approach becomes oversaturated.

### Queue ($q_b$)
The number of queued vehicles on approach $b$ at time $t$, modeled as a continuous fluid volume:
$$q_b(t) = q_b(0) + \int_{0}^{t} \left[ \lambda_b(\tau) - \mu_b(\tau) \right] d\tau, \quad q_b(t) \ge 0 \tag{5}$$
where $\mu_b(\tau)$ represents the actual instantaneous vehicle departure rate.

### Vehicular Delay ($D$)
The total elapsed time experienced by a vehicle navigating the approach above the free-flow travel time. In discrete fluid-queue formulation, total cumulative delay over horizon $T$ is the integral of the queue:
$$D_{\text{total}} = \int_{0}^{T} q(t) dt \approx \sum_{k=1}^{N} q(k) \Delta t \quad [\text{veh}\cdot\text{s}] \tag{6}$$
Average vehicular delay per vehicle is calculated as:
$$d_{\text{avg}} = \frac{D_{\text{total}}}{\text{Total Departed Vehicles}} \quad [\text{s/veh}] \tag{7}$$

### Highway Capacity Manual Level of Service (HCM LOS)
The qualitative operational classification defined by the Transportation Research Board Highway Capacity Manual (HCM 7th Edition) based on average control delay per vehicle for signalized intersections:
- **LOS A:** $d_{\text{avg}} \le 10.0\text{ s/veh}$ (Free flow, negligible queue)
- **LOS B:** $10.0 < d_{\text{avg}} \le 20.0\text{ s/veh}$ (Stable flow, light delay)
- **LOS C:** $20.0 < d_{\text{avg}} \le 35.0\text{ s/veh}$ (Stable flow, acceptable delay)
- **LOS D:** $35.0 < d_{\text{avg}} \le 55.0\text{ s/veh}$ (Approaching unstable flow, noticeable queues)
- **LOS E:** $55.0 < d_{\text{avg}} \le 80.0\text{ s/veh}$ (Unstable flow, capacity limit, severe delay)
- **LOS F:** $d_{\text{avg}} > 80.0\text{ s/veh}$ (Oversaturated breakdown, queue spill-back)

### Oversaturation and Spill-Back
- **Oversaturation:** Condition where arrival demand exceeds intersection discharge capacity over multiple consecutive cycles ($\sum X_b > 1.0$), causing queues to propagate upstream monotonically.
- **Spill-Back:** Physical condition where queue accumulation on a downstream link (e.g., Branch 4) exceeds link physical storage capacity ($q_4 \ge q_{4\max}$), physically obstructing the intersection box and preventing upstream branches ($B1..B3$) from discharging even when displaying green.

### Intersection Pressure ($P_b$)
In network feedback control (specifically Varaiya's Max-Pressure algorithm), pressure represents the spatial differential between upstream queue accumulation and downstream queue backlog:
$$P_b(t) = q_b(t) - q_{\text{downstream}}(t) \tag{8}$$
For the SITRA junction with three upstream approaches discharging into common link B4:
$$P_b(t) = q_b(t) - q_4(t), \quad \forall b \in \{1, 2, 3\} \tag{9}$$
A positive pressure gradient indicates strong queue accumulation relative to downstream capacity, triggering phase activation.
