---
title: "Clearing Congestion in Circuit Time: A Simscape Electrical Equivalent of a Signalized Junction and a Twin-Run Clearance Benchmark of Four Controllers"
author:
  - "Author One [name placeholder], Author Two [name placeholder]"
---

::: {custom-style="IEEE Affiliation"}
Department of Electrical and Electronics Engineering, [affiliation placeholder], Coimbatore, Tamil Nadu, India
:::

::: {custom-style="IEEE Abstract"}
***Abstract*—After a queue builds up at a signalized junction, how many seconds does each controller need to bring it back to normal? We study this question on a three-approach junction (SITRA, Avinashi Road, Coimbatore) that we map one-to-one onto an electrical circuit: one vehicle is one coulomb, one vehicle per second is one ampere, and each approach queue is a 1 F capacitor whose voltage in volts equals the queue in vehicles. Four controllers (a model-predictive controller, Webster fixed-time, vehicle-actuated and max-pressure) are tested on fourteen scenarios that include demand surges, a congested start, an incident, a downstream blockage, a platoon, a frozen detector, detector noise and a stuck-off signal head. Clearance time is defined against a no-congestion twin run of the same controller and seed, which removes the signal-cycle ripple and the arbitrary baseline of earlier definitions. A Simscape network built only from standard electrical blocks (no embedded code) reproduces the queue trajectories to within 8 µV and matches every model clearance time exactly across 32 replayed runs. On the 200 s surge scenario the model-predictive controller clears in 106 s, the actuated controller in 63 s, and Webster and max-pressure do not clear within the 600 s run. The actuated controller also has lower mean delay than the predictive controller in most nominal scenarios, whereas under detector noise (σ = 2 veh) its delay is 5.46 s/veh higher (p = 0.0009). Gate commands are replayed into the circuit open loop, and all component ratings are placeholders.*
:::

::: {custom-style="IEEE Keywords"}
***Index Terms*—Congestion clearance time, electrical analogy, model predictive control, Simscape, traffic signal control, twin-run evaluation.**
:::

@@SECBREAK@@

# I. Introduction

A signal controller is usually judged by average delay. Operators, however, ask a different question once a school event, an incident or a downstream jam has loaded the junction: how long until the queue is back to what it would have been anyway? Average delay answers this poorly, because it blends the congested period with the normal one. This paper measures clearance time directly and compares four standard controllers on it.

The setting is the SITRA junction in Coimbatore, where three approaches (B1–B3) discharge into one exit link (B4). Queues obey a conservation law, and so does charge on a capacitor. We exploit this to build a physical electrical twin of the junction in Simscape and to check, in circuit simulation, that the queue numbers produced by the traffic model are the same numbers a capacitor would hold. The analogy between road networks and electrical circuits is not new [12], [13]. What we add is a benchmark in which the controller decisions are applied to a circuit and the clearance time is read from capacitor voltages.

Our contributions are the following.

1. A clearance-time metric defined against a no-congestion twin run (same controller, same seed), together with a general congestion injector covering demand, capacity, downstream and sensor/signal faults.
2. A Simscape circuit, `SITRA_S5_Physical.slx`, containing a 230 V mains source, rectifier, closed-loop 24 V buck converter, MOSFET signal-head channels and four queue capacitors, with no MATLAB Function, S-Function or interpreted blocks.
3. A comparison of SITRA MPC, Webster, actuated and max-pressure control across scenarios T1–T14, including paired statistics over five seeds and replay of 32 runs in the circuit.
4. An account of where each controller wins. The actuated controller is faster in most nominal cases; the predictive controller is more tolerant of noisy detectors.

Section II reviews related work, Section III gives the model and metric, Section IV describes the circuit, Section V the experiments, Section VI the results, and Sections VII–VIII discuss limits and conclude.

# II. Related Work

*Fixed-time and actuated control.* Webster's equisaturation formula sets cycle length and green splits from design flows [1]. Adaptive systems such as SCATS [2] and SCOOT [3] adjust those splits online from detector data. Vehicle-actuated control extends or terminates green according to gaps between vehicles and is the common field baseline.

*Queue models.* The cell transmission model [4] and the store-and-forward model used for urban networks [5] describe queues by conservation of vehicles, which is the property we use for the circuit analogy. We keep the plant as a plain discrete queue so that capacitor and queue can be compared sample by sample.

*Predictive and pressure-based control.* Model-predictive formulations for signals are surveyed in [8] and include linear-quadratic designs for networks [9]. Max-pressure control selects the phase with the largest upstream-minus-downstream queue difference and is provably throughput-optimal under its assumptions [7]. Learning-based pressure controllers have followed [10], and a survey of signal control methods is given in [11].

*Electrical analogies.* Evacuation dynamics have been controlled through equivalent-circuit models [12], and road networks have been modeled by resistor networks [13]. These works use the analogy to analyze or optimize; we use it to run the controllers against a physical-domain model and to measure clearance there.

*Gap addressed.* To our knowledge none of the cited works reports, for several controllers on one junction, the seconds needed to return to the no-congestion queue, measured from circuit quantities. Our results also show that the ranking depends on the disturbance, which a single average-delay figure hides.

# III. Model and Metric

## A. Queue plant

Time advances in steps of $\Delta t = 1$ s. For approaches $b\in\{1,2,3\}$ the queue is

$$q_b(k+1)=\max\!\big(0,\;q_b(k)+\lambda_b(k)\Delta t-\mu_b(k)\Delta t\big),$$

and the departure rate is

$$\mu_b(k)=\begin{cases}0,& q_4(k)\ge q_{4,\max}\\ g_b(k)\,\min\!\big(C_b,\;q_b(k)/\Delta t+\lambda_b(k)\big),& \text{otherwise,}\end{cases}$$

where $\lambda_b$ is the arrival rate, $g_b\in\{0,1\}$ the green indication and $C_b$ the discharge capacity. The exit link B4 accumulates $\sum_b \mu_b$ and drains at $C_4$. The capacities $0.65$, $0.35$, $0.25$ and $0.45$ veh/s for B1–B4 are assumed values, not field measurements.

## B. Circuit equivalent

Fig. 1 shows the mapping. Each approach is a capacitor $C_{Bb}=1$ F charged by a current source $i_b=\lambda_b$ and discharged by a controlled sink $i_{dep}$ that a MOSFET gate enables. Kirchhoff's current law at the capacitor node gives $C_{Bb}\,dv_C/dt=i_b-i_{dep}$, so $v_C$ in volts equals $q_b$ in vehicles. Incidents, blockages and signal faults map to a lower sink limit, a clamp driven by the B4 capacitor voltage, and a gate held off.

![Fig. 1. Traffic-to-circuit mapping used throughout the paper. Horizontal arrows pair a traffic quantity with its electrical equivalent; the bottom box states how clearance time is read in either domain.](figs/f1_mapping.png){width=3.4in}

## C. Controllers

All four controllers use the same plant and a 3 s yellow interval. *SITRA MPC* optimizes the green split of the next three 63 s cycles (12–30 s per green) by minimizing a weighted sum of predicted total queue, an extra weight on B1 and a penalty on change of the split; the weights are 1, 0.5 and 0.02. *Webster* uses the equisaturation formula with a design flow of 4 veh/s, which gives a 54 s cycle for this junction. *Actuated* control allows 10–40 s of green and ends it when the 3 s passage gap is exceeded. *Max-pressure* re-selects the phase every 10 s from the pressure of each approach [7].

## D. Congestion injector

Events are a list of (type, branch, start, end, magnitude) records. Types are surge, platoon, incident (capacity multiplied by $1-m$), blockage (B4 exit capacity reduced and B1–B3 discharge blocked while $q_4\ge q_{4,\max}$), stuck or noisy detector, and signal stuck off. With an empty list the injector has no effect, so scenario T6 still reproduces the frozen reference trajectory exactly.

## E. Twin-run clearance time

For each scenario, controller and seed we run the plant twice: with the congestion event and with the event removed (a *twin* with the same arrivals and seed). Let $Q$ and $Q_{tw}$ be the total approach queue $q_1+q_2+q_3$ of the two runs, and $\bar Q$ and $\bar Q_{tw}$ their 120 s centered moving means, which removes the ripple of the 63 s cycle. The difference is $d(t)=\bar Q(t)-\bar Q_{tw}(t)$. With event end $t_e$, tolerance $\delta=1$ veh and hold time $H=60$ s,

$$t_{clear}=\min\{\,t-t_e:\;t\ge t_e,\;|d(\tau)|\le\delta\;\;\forall\,\tau\in[t,t+H]\,\},$$

and $t_{clear}$ is undefined (reported *n/c*, not cleared) when no such $t$ exists before the run ends. The excess delay is

$$E_{veh}=\sum_{t_k\ge t_e}\max\big(0,\,Q(t_k)-Q_{tw}(t_k)\big)\Delta t\quad[\mathrm{veh\cdot s}].$$

Event ends are 600 s for the demand step (T5), 400 s for the surges (T6, T7) and 0 s for the congested start (T8). An earlier version compared the raw queue with a fixed baseline; it reported "not cleared" for almost every case because the raw queue swings by several vehicles each cycle, and the twin definition replaces it.

# IV. Physical Implementation

## A. Study site

Fig. 2 places the junction on the map. Branches B1–B3 approach the junction and B4 is the exit link used for the blockage model.

![Fig. 2. SITRA junction on Avinashi Road, Coimbatore (about 11.03° N, 77.03° E), with the model branches B1–B4 overlaid. Map data from OpenStreetMap contributors.](figs/f0_site.jpg){width=3.0in}

## B. Simscape network

The circuit is built from Simscape Foundation Electrical blocks only (sources, capacitors, resistors, switches, MOSFETs and converters) plus Simulink sources that carry the replayed gate and arrival signals. Fig. 3 gives the power path. A 230 V, 50 Hz source feeds a transformer and bridge rectifier; the DC link averages 47.31 V; a closed-loop buck converter holds the bus at 24 V; three MOSFET channels drive 1 A signal heads. Gate signals pass an interlock that enforces a 5 µs dead time and at most one gate on at a time. Under-voltage, over-current and spill-back clamps protect the bus, the channels and the B1–B3 sinks.

![Fig. 3. Electrical power path of `SITRA_S5_Physical.slx` with measured bus voltage and the three protection functions.](figs/f2_power.png){width=3.4in}

All electrical values (capacitances, resistances, MOSFET parameters and the converter gains) are placeholders chosen for simulation. We list no manufacturer parts; rating selection is left to the hardware stage of the project.

## C. Replay mode

The controllers run in the traffic model and their gate commands are *replayed* into the circuit as gate signals. The circuit therefore does not yet close the loop through its own sensors. This limits what the circuit can show: it verifies that a physical network conserves charge and reproduces the queues and clearance times, but it cannot yet test sensor delay or converter interaction with control.

# V. Experiments

*Scenarios.* T1–T4 are constant demand (low, moderate, high, oversaturated). T5 raises demand to high at 300 s and returns it to moderate at 600 s. T6 and T7 add a surge on B1 from 200 s to 400 s (deterministic and Poisson). T8 starts from a congested state. T9 halves B1 capacity, T10 blocks B4 once $q_4\ge15$ veh, T11 injects a platoon on B2, T12 freezes a detector, T13 adds Gaussian detector noise with $\sigma=2$ veh, and T14 holds the B3 gate off. T5–T8 use five seeds where demand is stochastic; T6 is deterministic.

*Metrics.* Average delay $d_{avg}$ with HCM level of service [15], queue statistics, throughput, $t_{clear}$ and $E_{veh}$. Paired $t$-tests over five seeds use the difference baseline minus SITRA, so a positive value means SITRA has lower delay.

*Circuit checks.* Maximum $|v_C-q|$, nodal current residual, minimum inter-gate dead time, and the difference between model and circuit clearance time for 32 replayed runs (8 scenarios, 4 controllers, one seed).

*Code and data.* All results come from the repository on branch `sai_dev`; the discrete runs take well under a second per controller per scenario.

# VI. Results

## A. Circuit fidelity

Table I summarizes the circuit checks. The capacitor voltages track the model queues within 8 µV across all 32 replayed runs (1.30 µV on T6), the nodal current residual stays near $10^{-16}$ A, and the interlock never turns on two gates. Circuit clearance times equal the model values in every run, either both finite and identical or both not cleared. These checks confirm that the circuit and the model describe the same dynamics; they say nothing about field accuracy.

::: {custom-style="IEEE Table Source"}
Source: `Results/` verification files from `run_master_all.m`.
:::

| Check | Measured | Limit |
|:--|:--|:--|
| Max voltage–queue error, 32 circuit runs | $\le 8.00$ µV | 1 mV |
| Max nodal KCL error | $7.2\times10^{-16}$ A | $10^{-8}$ A |
| Max B4 nodal error | $3.9\times10^{-16}$ A | $10^{-8}$ A |
| Min inter-gate dead time | 5.00 µs | $\ge$ 5.00 µs |
| Max simultaneous gates | 1 | $\le$ 1 |
| Gate samples valid, 4 controllers | 601/601 each | 100 % |
| Bus voltage (envelope) | 23.98 V (22.06–25.63 V) | ±10 % |

: Table I. Circuit verification results.

## B. Nominal delay

Table II lists average delay and, in brackets, maximum queue. The actuated controller has the lowest delay in every constant-demand and surge scenario. Against SITRA MPC the paired differences are significant in T1–T5, T7 and T8 (for example $-7.74$ s/veh in T2, 95 % CI $[-11.44,-4.04]$, $p=0.0044$; $-22.37$ s/veh in T8, $p=0.0015$). SITRA is statistically indistinguishable from Webster and max-pressure in most constant-demand cases, and is better than Webster on T8 by 9.95 s/veh ($p=0.0325$). Max-pressure gives the smallest maximum queue in T2, T6 and T7.

| Scn. | SITRA | Webster | Actuated | MaxPress. |
|:--|:--:|:--:|:--:|:--:|
| T2 moderate | 25.6 (10.7) | 26.8 (10.6) | **17.9** (9.8) | 25.4 (**7.8**) |
| T3 high | 60.7 (20.7) | 62.2 (20.9) | **40.3** (**17.5**) | 64.9 (21.6) |
| T4 oversat. | 137.0 (51.8) | 128.4 (60.1) | **107.5** (**46.3**) | 130.9 (61.0) |
| T6 surge, det. | 24.3 (12.3) | 34.8 (22.5) | **17.2** (12.0) | 20.0 (**7.7**) |
| T7 surge, Poisson | 28.8 (15.8) | 37.4 (20.0) | **20.4** (13.2) | 25.1 (**9.9**) |

: Table II. Average delay [s/veh] and maximum queue [veh] in brackets. Source: `Results/baselines/baseline_comparison.csv`.

## C. Clearance after an overload

Fig. 4 shows the T6 queues of the four controllers. During the surge Webster's queue rises to about 20 vehicles (120 s mean), against 9–11 for the other three, and it has not returned to the twin level by 600 s. Table III and Fig. 5 give clearance times and excess delay.

![Fig. 4. Deterministic surge T6, seed 0: (a) raw total approach queue and (b) its 120 s moving mean. The shaded band is the surge (200–400 s). Source: `Results/T6_Simulink_Exports/SITRA_T6_All_Controllers.mat`.](figs/f3_t6.png){width=3.4in}

On T6 the actuated controller clears 43 s earlier than SITRA (63.0 s against 106.0 s) and accumulates 181 veh·s of excess delay, against 306 veh·s. Webster and max-pressure do not clear within the run, with 1867 and 412 veh·s. On T8, the congested start, the actuated controller clears in 484.4 s (5 of 5 seeds), SITRA in 643.8 s (4 of 5) and max-pressure in 736.0 s (2 of 5). Averages of clearance time use only the seeds that cleared, so a short mean with few cleared seeds (Webster on T7, 50 s from 1 of 5 seeds) should not be read as a good result; $E_{veh}$ includes every seed and is the safer comparison.

| Scn. | SITRA | Webster | Actuated | MaxPress. |
|:--|:--:|:--:|:--:|:--:|
| T5 step | 76.0 (1/5), 2662 | n/c (0/5), 2927 | 131.7 (3/5), **1333** | 117.0 (1/5), 3177 |
| T6 surge | 106.0 (1/1), 306 | n/c (0/1), 1867 | **63.0** (1/1), **181** | n/c (0/1), 412 |
| T7 surge, P. | 113.5 (2/5), 948 | 50.0 (1/5), 1757 | 82.5 (4/5), **406** | n/c (0/5), 765 |
| T8 backlog | 643.8 (4/5), 10972 | 522.5 (2/5), 12951 | **484.4** (5/5), **7817** | 736.0 (2/5), 11233 |

: Table III. Clearance time [s] (cleared seeds) and excess delay $E_{veh}$ [veh·s]; n/c means not cleared. Source: `Results/baselines/baseline_comparison.csv`.

![Fig. 5. Mean clearance time with one standard deviation over seeds that cleared. Bars marked n/c did not clear in any seed.](figs/f4_clear.png){width=3.3in}

## D. Faults and disturbances

Table IV gives the incident (T9), the blockage (T10) and the noisy-detector case (T13). With B1 capacity halved (T9) the actuated controller again clears first (80.0 s against 174.6 s for SITRA). With B4 blocked (T10) SITRA is the slowest to clear (247.8 s against 141.4 s for the actuated controller), although its maximum excess queue is not the largest. In the circuit replay (single seed) T14, where the B3 head is stuck off, is the one case in which Webster clears fastest (57 s, against 159 s for the actuated controller and 288 s for SITRA).

| Scn. | Controller | $t_{clear}$ [s] | $E_{veh}$ [veh·s] |
|:--|:--|:--:|:--:|
| T9 incident B1 | SITRA | 174.6 | 829.1 |
| | Webster | 148.0 | 1462.2 |
| | Actuated | **80.0** | **272.9** |
| | MaxPressure | 136.7 | 644.2 |
| T10 blockage B4 | SITRA | 247.8 | 1767.6 |
| | Webster | 153.0 | 1336.2 |
| | Actuated | **141.4** | **871.6** |
| | MaxPressure | 172.5 | 870.2 |
| T13 noise, $\sigma=2$ veh | SITRA | 56.6 | **94.0** |
| | Webster | **0.0** | **0.0** |
| | Actuated | 424.3 | 2190.2 |
| | MaxPressure | **0.0** | 1262.4 |

: Table IV. Faults and noise (T9, T10, T13). Source: `Results/baselines/baseline_comparison.csv` (seed means).

Detector noise reverses the nominal ranking against the actuated controller. With $\sigma=2$ veh (T13) the actuated controller's delay is 5.46 s/veh higher than SITRA's (95 % CI $[3.75,7.18]$, $p=0.0009$), its excess delay is 2096 veh·s higher ($p<0.001$) and its own $E_{veh}$ is 2190 veh·s, against 94 veh·s for SITRA; its clearance time reaches 424 s. Fig. 6 collects the delay differences for T7, T8 and T13.

![Fig. 6. Paired delay differences with 95 % confidence intervals over five seeds (baseline minus SITRA). Points to the right of zero favor SITRA.](figs/f5_forest.png){width=3.3in}

## E. Run time

One-second control steps take 0.126 ms for SITRA MPC and 0.027–0.039 ms for the other controllers, i.e. at least 7900 times faster than real time at $\Delta t=1$ s on the development computer. This is a statement about the discrete model; it does not cover the converter or embedded hardware.

# VII. Discussion

*Why the actuated controller is faster here.* It ends a green as soon as the gap exceeds 3 s and returns capacity to the approaches that still have queue, so after a surge ends it recovers within a few seconds. SITRA MPC commits to a split for each 63 s cycle, which delays its reaction, and its objective is a weighted queue cost rather than recovery time. We did not tune either controller for clearance time; a recovery-time term in the MPC cost is an obvious next experiment.

*Why noise reverses the order.* The predictive cost sums queue readings over three cycles, so zero-mean noise largely averages out (the T13 queue error is about 0.3 veh). The actuated gap detector reacts to individual readings, and noise spikes cause false extensions to the maximum green; both explain why its delay and excess delay rise.

*Where Webster and max-pressure stand.* Webster cannot adapt to the surge and fails to clear T5 and T6; max-pressure is competitive in delay and has the smallest maximum queue in several scenarios but does not clear T6 and T7 in the 600 s runs.

*Limitations.* (i) The circuit is driven in replay mode and not closed loop through its own sensors. (ii) The fault cases T9–T14 are injected in the traffic model and replayed; they are not built as separate faults in the Simscape model. (iii) Branch capacities are assumed. (iv) All electrical ratings are placeholders. (v) Five seeds give wide confidence intervals; several comparisons, such as T7 SITRA against Webster ($p=0.058$), are inconclusive. (vi) Averages of clearance time depend on how many seeds clear. (vii) The study covers one junction and fixed demand profiles.

# VIII. Conclusion

We defined clearance time against a no-congestion twin run and measured it for four controllers on a junction that we also built as a Simscape circuit. The circuit reproduces the queue model within 8 µV and the clearance times exactly, so queue, voltage and clearance time can be used interchangeably in this setting. On the 200 s surge, SITRA MPC clears in 106 s, the actuated controller in 63 s, and Webster and max-pressure do not clear in 600 s. The actuated controller is the faster recoverer in most nominal and fault scenarios, but under noisy detectors the predictive controller is clearly better. Closing the loop through the circuit's own sensors, building the fault cases in the physical model, and replacing placeholder ratings with selected hardware are the next steps.

# Acknowledgment {.unnumbered}

The authors thank the maintainers of OpenStreetMap for the map data used in Fig. 2.

# References {.unnumbered}

@@REFS@@
