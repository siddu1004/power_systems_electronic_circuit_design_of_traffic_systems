# 11. Final Evaluation: Objectives Achieved and Algorithmic Analysis

This section synthesizes the empirical evidence, evaluates performance against pre-defined project objectives, provides the headline answer to the research question, and details the underlying algorithmic mechanisms.

## 11.1 Project Objectives Achievement Matrix
Table 11.1 systematically evaluates each core technical objective of the SITRA research initiative.

Table 11.1: Project Objectives Achievement Matrix. Source: Project synthesis from Sections 8, 9, and 10.

| # | Technical Objective | Quantitative Success Criterion | Supporting Evidence | Achieved? | Technical Justification | Current Implementation Status |
|---|---|---|---|---|---|---|
| **1** | Realize traffic network as physical circuit | Pure Simscape model with $C=1\text{ F}$, controlled sources, 0 code blocks | `test_SITRA_S5_Physical.m`, Fig. 8.2, Fig. 8.3 | **Yes** | Simscape electrical circuit constructed and verified with zero software blocks | Fully completed in `SITRA_S5_Physical.slx` |
| **2** | Circuit matches discrete queue model | Max voltage tracking error $< 1.0\text{ mV}$ ($10^{-3}\text{ V}$) | Table 10.5, Fig. 10.8, Fig. 10.9 | **Yes** | Measured maximum error is $1.30\,\mu\text{V}$ (three orders of magnitude tighter than criterion) | Fully verified ($1.300\times 10^{-6}\text{ V}$) |
| **3** | Run controllers on physical circuit | Execute 4 controllers through circuit, verify gate tracking | Table 10.6, Fig. 10.10 | **Partly** | Controllers run via **open-loop replay** of pre-computed gate signals; closed loop not built | Replay verified across 32 runs; ADC closed-loop deferred |
| **4** | Measure clearance time on physical circuit | Circuit clearance matches model clearance within $\le 1.0\text{ s}$ | Table 10.6, Fig. 10.10 | **Yes** | Measured discrepancy is **$0.0\text{ s}$** across all 32 physical runs | Fully verified ($|t_{\text{circ}} - t_{\text{model}}| = 0.0\text{ s}$) |
| **5** | Benchmark SITRA MPC against baselines | Multi-scenario benchmark across delay, queue, and clearance | Table 10.3, Table 10.4, Table 10.6 | **Yes** | Evaluated against Webster, Actuated, and MaxPressure across 14 scenarios | Fully completed in baseline harness |
| **6** | Regulate 24 V power distribution bus | Bus voltage maintained within $24.0\text{ V} \pm 10\%$ ($21.6\text{–}26.4\text{ V}$) | Table 10.7, Fig. 10.11 | **Yes** | Measured bus voltage envelope is $22.06\text{–}25.63\text{ V}$ during active switching | Fully verified in Simscape power path |
| **7** | Enforce electrical & traffic safety | Max simultaneous gates $\le 1$, dead-time $\ge 5.0\,\mu\text{s}$, OC/UV trip | Table 10.7, Table 10.8 | **Yes** | Zero cross-conduction, $5.00\,\mu\text{s}$ dead-time confirmed, OC/UV protection active | Fully verified in Track 1 and Track 2 |
| **8** | Closed-loop control from circuit sensors | Controller reads analog $v_C$ through ADC in real-time | Section 4.5, Section 12.1 | **No** | Currently open-loop replay; hardware ADC feedback loop is not built | Explicitly identified as main limitation |
| **9** | Fault cases on physical circuit | Hardware lane closures, spill-back clamps, stuck gates | Table 10.6, Table 10.12 | **Partly** | B4 spill-back clamp and stuck gates verified on circuit; noise evaluated via replay | Physical clamp verified; sensor noise via replay |
| **10** | Validate real hardware ratings | Commercial component part numbers validated in circuit | Table 8.2, `S5_physical_params.m` | **No** | Component parameters are simulation placeholders (S12) | Real candidate parts identified; sizing in S12 |
| **11** | Robust to disturbances & sensor faults | Quantified degradation under incidents, noise, and freeze | Table 10.9, Table 10.12, Fig. 10.14 | **Yes** | SITRA MPC proves superior noise resilience ($p < 0.001$) and detector freeze resilience | Fully verified across Scenarios T9–T14 |

---

## 11.2 Headline Answer to the Research Question

The central empirical finding answering the research question is:
1. **On Short Severe Demand Surges (Scenario T6):**
   - **Actuated control clears fastest:** Clears in **$63.0\text{ s}$**, generating cumulative excess delay of $E_{\text{veh}} = 181.43\text{ veh}\cdot\text{s}$.
   - **SITRA MPC clears second:** Clears in **$106.0\text{ s}$** ($43.0\text{ s}$ or $68.3\%$ slower than Actuated), with $E_{\text{veh}} = 305.59\text{ veh}\cdot\text{s}$.
   - **Webster fixed-time fails completely:** Does not clear before simulation end (**Clearance = NaN**), accumulating massive excess delay $E_{\text{veh}} = 1867.21\text{ veh}\cdot\text{s}$ ($511\%$ higher than SITRA).
   - **Max-Pressure fails to clear:** Exhibits residual cyclic ripple, failing the strict 60 s hold window (**Clearance = NaN**), with $E_{\text{veh}} = 411.96\text{ veh}\cdot\text{s}$.
2. **On Large-Scale Initial Congestion Backlogs (Scenario T8, $50\text{ veh}$ Backlog):**
   - **Actuated control is fastest:** Mean clearance time is **$484.4\pm 117.3\text{ s}$** (clearing 5/5 seeds), with $E_{\text{veh}} = 7816.6\text{ veh}\cdot\text{s}$.
   - **Webster clears in:** **$522.5\pm 195.9\text{ s}$** (clearing only 2/5 seeds), but accumulates $E_{\text{veh}} = 12951.1\text{ veh}\cdot\text{s}$.
   - **SITRA MPC clears in:** **$643.8\pm 205.1\text{ s}$** (clearing 4/5 seeds), with $E_{\text{veh}} = 10971.9\text{ veh}\cdot\text{s}$.
   - **Max-Pressure is slowest:** Mean clearance time is **$736.0\pm 125.9\text{ s}$** (clearing 2/5 seeds), with $E_{\text{veh}} = 11233.1\text{ veh}\cdot\text{s}$.
3. **Under Severe Detector Noise (Scenario T13, $\sigma = 2.0\text{ veh}$ Gaussian Noise):**
   - **SITRA MPC is dramatically superior:** Achieves average delay of **$21.55\text{ s/veh}$** and excess delay of only **$93.97\text{ veh}\cdot\text{s}$**, limiting queue inflation to **$+0.31\text{ veh}$**.
   - **Actuated control degrades catastrophically:** Delay surges to $27.01\text{ s/veh}$ ($+5.46\text{ s}$ inflation, $p = 0.0009$), clearance time blows out to **$424.25\text{ s}$**, and excess delay reaches **$2190.21\text{ veh}\cdot\text{s}$** (twenty-three times higher than SITRA).
   - **Max-Pressure degrades severely:** Average delay rises to $29.91\text{ s/veh}$ and excess delay reaches **$1262.41\text{ veh}\cdot\text{s}$** ($p = 0.0235$).
   - **Webster fixed-time:** Exhibits complete statistical immunity ($0.00\%$ change) because it utilizes zero real-time sensor feedback.

---

## 11.3 In-Depth Algorithmic Explanation: Why the Results Come Out This Way

### Why Actuated Control Beats SITRA MPC on Nominal Surges
In clean, uncorrupted traffic scenarios (T1–T8), the vehicle-actuated controller consistently clears congestion faster and achieves lower average vehicular delay than SITRA MPC. This outcome is not an anomaly; it stems directly from the structural constraints of the respective algorithms:
1. **Zero Phase Commitment Latency:** Actuated control operates on a 1-second decision cadence with instantaneous gap-out detection ($\epsilon_{\text{gap}} = 0.1\text{ veh}$). As soon as the queue discharging on green drains to zero, Actuated terminates the green phase immediately, switching to the next approach. In contrast, SITRA MPC operates within a rigid $63.0\text{ s}$ cycle structure. Once SITRA MPC optimizes and commits to a green split at the cycle start, that green duration must run to completion before the next phase can be served.
2. **Minimum Green Bound Inelasticity:** SITRA MPC enforces an explicit minimum green bound of $g_{\min} = 12.0\text{ s}$ per approach. Even if an approach empties in $4\text{ s}$, SITRA MPC must hold green for the remaining $8\text{ s}$, resulting in wasted green time during transient recovery phases. Actuated control also enforces $g_{\min} = 12\text{ s}$, but because it lacks a fixed cycle duration, it immediately cycles through subsequent phases without waiting for a fixed $63\text{ s}$ period.
3. **Horizon Prediction Inaccuracy on Sudden Drop-Offs:** Receding-horizon MPC plans optimal splits based on predicted arrival trajectories across three cycles ($189\text{ s}$). When a sudden surge abruptly terminates at $t = 400\text{ s}$, the MPC cost function still holds residual weights from the high-queue state, leading to a conservative, multi-cycle unwinding of green allocations.

### Why SITRA MPC Is Vastly Superior Under Sensor Noise and Disturbances
The relative ranking inverts dramatically when realistic physical sensing imperfections are introduced (T12 and T13):
1. **Low-Pass Horizon Filtering:** SITRA MPC minimizes an integral quadratic cost function $\sum_{j=1}^{N_p} \mathbf{q}(k+j)^T \mathbf{Q} \mathbf{q}(k+j)$ over a multi-cycle horizon ($189\text{ s}$). High-frequency zero-mean Gaussian detector noise ($\sigma = 2.0\text{ veh}$) sums to approximately zero across future time steps. Consequently, the optimal green split computed by the quadratic program remains remarkably stable, exhibiting almost zero jitter ($+0.31\text{ veh}$ queue perturbation).
2. **Vulnerability of Instantaneous Memoryless Feedback:** Both Actuated and MaxPressure controllers rely strictly on instantaneous, single-point sensor observations:
   - In Actuated control, positive noise spikes ($+2\text{–}4\text{ veh}$) prevent the gap-out detector from recognizing queue clearance, causing false green extensions up to the maximum limit ($g_{\max} = 30\text{ s}$). Empty approaches are held green while cross streets with real traffic are starved of service, causing average delay to surge by $+5.46\text{ s/veh}$ ($p < 0.001$).
   - In Max-Pressure control, noise differential spikes between upstream and downstream links corrupt the pressure gradient calculation $P_b = q_b - q_4$, triggering erratic, suboptimal phase selections that increase excess delay to $1262.4\text{ veh}\cdot\text{s}$.
3. **The Fixed-Time Paradox:** Webster control demonstrates perfect immunity to sensor noise ($0.00\%$ change) because its control law reads zero real-time sensors. However, this same lack of sensing causes catastrophic failure during demand surges and lane-closure incidents (T6, T9), where it lacks the feedback necessary to expand green times.

*Summary:* Actuated control is the optimal policy for clean, undersaturated traffic with perfect sensors. SITRA MPC is the optimal, robust policy for complex, high-noise urban environments where sensor reliability is imperfect and predictive multi-approach coordination is essential.
