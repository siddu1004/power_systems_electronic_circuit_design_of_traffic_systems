# 9. Evaluation Methodology and Validation Criteria

This section formalizes the mathematical definitions of all performance metrics, details the statistical testing protocol, justifies the choice of baseline algorithms, and states the pre-defined numerical pass/fail acceptance criteria.

## 9.1 Evaluation Metrics and Mathematical Formulas
Every metric reported in this research is computed directly from simulation histories according to the following formulas:

1. **Average Vehicular Delay ($d_{\text{avg}}$) [s/veh]:**
   $$d_{\text{avg}} = \frac{\sum_{k=0}^{N-1} \sum_{b=1}^{3} q_b(k) \Delta t}{\sum_{k=0}^{N-1} \mu_4(k) \Delta t} \tag{47}$$
   - *Source File:* `FLAT/baselines/bl_metrics.m` (`m.avgDelay`).
2. **Network Intersection Delay ($D_{\text{net}}$) [s/veh]:** Total system delay including vehicles accumulated on downstream bottleneck link B4:
   $$D_{\text{net}} = \frac{\sum_{k=0}^{N-1} \sum_{b=1}^{4} q_b(k) \Delta t}{\sum_{k=0}^{N-1} \mu_4(k) \Delta t} \tag{48}$$
   - *Source File:* `FLAT/baselines/bl_metrics.m` (`m.netDelay`).
3. **Average Approach Queue ($\bar{Q}$) [veh]:**
   $$\bar{Q} = \frac{1}{N} \sum_{k=0}^{N-1} \sum_{b=1}^{3} q_b(k) \tag{49}$$
   - *Source File:* `FLAT/baselines/bl_metrics.m` (`m.avgQueue`).
4. **Maximum Approach Queue ($Q_{\max}$) [veh]:**
   $$Q_{\max} = \max_{k \in \{0..N-1\}} \sum_{b=1}^{3} q_b(k) \tag{50}$$
   - *Source File:* `FLAT/baselines/bl_metrics.m` (`m.maxQueue`).
5. **Maximum Downstream Link Queue ($Q_{4\max}$) [veh]:**
   $$Q_{4\max} = \max_{k \in \{0..N-1\}} q_4(k) \tag{51}$$
   - *Source File:* `FLAT/baselines/bl_metrics.m` (`m.maxQueueB4`).
6. **Total Vehicular Throughput ($T_{\text{veh}}$ [veh] and $T_{\text{vph}}$ [veh/h]):**
   $$T_{\text{veh}} = \sum_{k=0}^{N-1} \mu_4(k) \Delta t, \quad T_{\text{vph}} = T_{\text{veh}} \cdot \left(\frac{3600}{T_{\text{sim}}}\right) \tag{52}$$
   - *Source File:* `FLAT/baselines/bl_metrics.m` (`m.throughput`, `m.throughput_vph`).
7. **Number of Vehicular Stops ($N_{\text{stops}}$):** In macroscopic fluid queue formulations, individual vehicle accelerations and decelerations are not tracked; vehicular stops are not directly observable and are therefore explicitly reported as **not measured** (fluid continuum limitation).
8. **Highway Capacity Manual Level of Service (HCM LOS):** Categorical threshold mapping of average delay $d_{\text{avg}}$ into discrete grades A through F:
   $$\text{LOS} = \begin{cases}
   \text{A}, & d_{\text{avg}} \le 10.0\text{ s/veh} \\
   \text{B}, & 10.0 < d_{\text{avg}} \le 20.0\text{ s/veh} \\
   \text{C}, & 20.0 < d_{\text{avg}} \le 35.0\text{ s/veh} \\
   \text{D}, & 35.0 < d_{\text{avg}} \le 55.0\text{ s/veh} \\
   \text{E}, & 55.0 < d_{\text{avg}} \le 80.0\text{ s/veh} \\
   \text{F}, & d_{\text{avg}} > 80.0\text{ s/veh}
   \end{cases} \tag{53}$$
   - *Source File:* `FLAT/baselines/bl_hcm_los.m`.
9. **Congestion Clearance Time ($t_{\text{clear}}$) [s]:** Elapsed time from disturbance end $t_{\text{event}}$ until moving-average approach queue matches twin run queue within $\pm 1.0\text{ veh}$ for a continuous $60\text{ s}$ hold window (Equation 18).
   - *Source File:* `FLAT/baselines/bl_clearance.m` (`C.tClear`).
10. **Cumulative Excess Vehicle-Delay ($E_{\text{veh}}$) [$\text{veh}\cdot\text{s}$]:** Integral of net excess approach queue above the twin run baseline (Equation 19).
    - *Source File:* `FLAT/baselines/bl_clearance.m` (`C.excessVehS`).
11. **Peak Excess Queue ($Q_{\text{excess, peak}}$) [veh]:**
    $$Q_{\text{excess, peak}} = \max_{t \ge t_{\text{event}}} \left[ \bar{Q}(t) - \bar{Q}_{\text{twin}}(t) \right] \tag{54}$$
    - *Source File:* `FLAT/baselines/bl_clearance.m` (`C.peakExcess`).

---

## 9.2 Scenario Design Rationale
The fourteen scenarios (T1–T14) were designed to systematically span the operational envelope:
- **T1–T4 (Demand Intensity Spectrum):** Step-wise increase in volume-to-capacity ratios ($X \approx 0.20, 0.50, 0.85, 1.30$) under stationary stochastic arrivals, establishing baseline delay curves and saturation limits.
- **T5 (Step Demand Transient):** Evaluates non-stationary step-up and step-down transitions across different steady-state demand levels.
- **T6 & T7 (Peak-Hour Demand Surge):** Replicates sudden temporary localized surges (e.g., event traffic or school dismissals) where B1 demand triples for 200 s, tested under deterministic (T6) and Poisson (T7) arrivals.
- **T8 (Oversaturated Initial Backlog):** Tests recovery from severe pre-existing queues ($50\text{ veh}$ initial total backlog) under moderate background arrivals, isolating queue draining speed.
- **T9–T14 (Dual-Domain Disturbance Injection):** Directly challenges controller resilience under non-demand disruptions: physical lane closures (T9), downstream exit blockages (T10), periodic upstream platoons (T11), sensor freezing (T12), Gaussian sensor noise (T13), and hardware signal stuck-off failures (T14).

---

## 9.3 Baseline Controller Selection Rationale
The three baseline algorithms were chosen to represent the core operational paradigms:
1. **Webster Fixed-Time [1]:** Represents open-loop, non-responsive municipal signal timing. Essential comparator for proving the value of dynamic feedback.
2. **Vehicle-Actuated [8]:** Represents modern responsive local traffic control widely deployed worldwide. Provides a purely reactive local benchmark with zero prediction horizon.
3. **Varaiya Max-Pressure [7]:** Represents state-of-the-art decentralized feedback control with proven global throughput-optimality. Essential comparator for testing whether predictive multi-cycle MPC provides measurable benefits over instantaneous pressure balancing.

**Why SCOOT, SCATS, and RL Were Excluded:**
- *SCOOT [3] and SCATS [2]* require multi-intersection arterial networks to realize offset optimization benefits; evaluating them on an isolated single junction degrades them to empirical split adjusters.
- *Deep Reinforcement Learning (RL)* [19]–[23] requires extensive offline neural network pre-training. Given that RL agents cannot provide formal worst-case safety bounds or guaranteed adherence to minimum green constraints during rare hardware faults, they were excluded in favor of mathematically verifiable control policies.

---

## 9.4 Statistical Testing Protocol
For all stochastic scenarios (T1–T5, T7–T14), simulations were repeated across five distinct pseudo-random seeds ($S = \{101, 102, 103, 104, 105\}$). We compute the sample mean $\bar{x}$, sample standard deviation $s$, and 95% confidence intervals based on Student's $t$-distribution with $N - 1 = 4$ degrees of freedom ($t_{\text{crit}} = 2.776$):
$$\text{CI}_{95\%} = \left[ \bar{x} - t_{\text{crit}}\frac{s}{\sqrt{N}}, \quad \bar{x} + t_{\text{crit}}\frac{s}{\sqrt{N}} \right] \tag{55}$$

To evaluate whether performance differences between SITRA MPC and each baseline are statistically significant, we execute paired two-tailed Student's $t$-tests across the seed batches. Differences are considered statistically significant at the $\alpha = 0.05$ level ($p < 0.05$). 

*Statistical Power Caveat:* With $N = 5$ random seeds, the statistical test possesses moderate power ($\approx 0.60$ for medium effect sizes). While adequate for detecting large performance differentials (e.g., in T8 and T13), subtle differentials in lightly loaded scenarios (T1, T2) exhibit wider confidence intervals, which is explicitly noted in Section 10.

---

## 9.5 Pre-Defined Numerical Acceptance Criteria
To eliminate subjective evaluation, six rigorous engineering pass/fail acceptance criteria were established prior to simulation execution:

Table 9.1: Pre-Defined Engineering Acceptance Criteria.

| Validation Domain | Metric / Parameter | Mathematical Acceptance Threshold | Verification Test Script |
|---|---|---|---|
| **Physical Circuit Equivalence** | Maximum Voltage Tracking Error | $\max_{t, b} |v_{Cb}(t) - q_{\text{ref}, b}(t)| < 1.0\times 10^{-3}\text{ V}$ ($1.0\text{ mV}$) | `test_SITRA_S5_Physical.m`, `run_controllers_on_S5_physical.m` |
| **Circuit Clearance Fidelity** | Clearance Time Discrepancy | $|t_{\text{clear, circuit}} - t_{\text{clear, model}}| \le 1.0\text{ s}$ | `run_controllers_on_S5_physical.m` |
| **Kirchhoff Conservation** | Maximum KCL Nodal Residual | $\max_t |\sum I_{\text{in}}(t) - \sum I_{\text{out}}(t) - C\frac{dv}{dt}| < 1.0\times 10^{-8}\text{ A}$ | `run_part_b.m`, `test_power_electronic_circuit.m` |
| **Bus Voltage Regulation** | Regulated DC Bus Voltage Range | $21.6\text{ V} \le V_{\text{bus}}(t) \le 26.4\text{ V}$ ($\pm 10\%$ of $24.0\text{ V}$) for $t \ge t_{\text{blank}}$ | `test_SITRA_S5_Physical.m` |
| **Semiconductor Protection** | Minimum Dead-Time Interlock | $\min t_{\text{dead}} \ge 5.0\,\mu\text{s}$ and $\max(\sum g_b) \le 1$ | `run_part_c.m`, `SITRA_Deadtime_Testbench.slx` |
| **Model Code Hygiene** | Embedded Interpreter Blocks | Exactly **0** code blocks (MATLAB Function / S-Function) inside physical subsystems | `test_SITRA_S5_Physical.m` (Inventory Audit) |
