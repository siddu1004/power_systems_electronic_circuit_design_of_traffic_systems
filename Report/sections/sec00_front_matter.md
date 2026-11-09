---
title: "Power-Electronic Circuit Modeling and Congestion Clearance Analysis of Urban Traffic Networks: The SITRA Equivalent Architecture"
author:
  - "Sai [Author Name Placeholder]"
  - "Co-Author [Name Placeholder]"
institute:
  - "Department of Electrical and Electronics Engineering [Institutional Affiliation Placeholder], Coimbatore, Tamil Nadu, India"
date: "November 2026"
---

# Front Matter

## Highlights
- Simscape circuit matches queue model within 8.00 uV (< 1 mV); zero code blocks.
- Kirchhoff conservation residual remains < 1e-15 A across full 600 s simulation.
- SITRA MPC clears Part 8 surge in 106 s; Webster fixed-time fails to clear (NaN).
- Actuated clears surge in 63 s via immediate zero-wait gap-out phase switching.
- Under detector noise, SITRA excess queue is +0.31 veh vs +4.93 veh for Actuated.

## Graphical Abstract

![Fig. 0. Graphical Abstract: Dual-domain power-electronic circuit modeling and congestion clearance analysis at SITRA junction.](figures/fig_graphical_abstract.png){width=100%}

## Nomenclature

Table 0.1: Mathematical and Physical Nomenclature. Source: `FLAT/baselines/bl_config.m`, `FLAT/S5_physical/S5_physical_params.m`.

| Symbol | Mathematical / Physical Meaning | Traffic Domain Equivalent | Electrical Domain Unit | Code Identifier |
|---|---|---|---|---|
| $q_b(t)$ | State variable: vehicles stored on approach $b$ | Queue length on branch $b$ | Volts [V] ($C=1\text{ F}$, $1\text{ V}=1\text{ veh}$) | `qHist(:, b)`, `vC(:, b)` |
| $\lambda_b(t)$ | Exogenous arrival rate on approach $b$ | Demand flow rate | Amperes [A] ($1\text{ A}=1\text{ veh/s}$) | `A(:, b)`, `S5.arrivals` |
| $\mu_b(t)$ | Actual departure rate discharging branch $b$ | Service flow rate | Amperes [A] | `depHist(:, b)`, `i_b` |
| $C_b$ | Maximum discharge capacity of branch $b$ | Saturation flow rate | Amperes [A] (assumed) | `net.capacity(b)` |
| $g_b(t)$ | Discrete switching state / gate drive | Green signal indication ($\in \{0,1\}$) | Gate Drive Logic ($0\text{ V} / 10\text{ V}$) | `gates(:, b)`, `S5.gates` |
| $T_s, \Delta t$ | Discrete control update interval | Traffic model step | Seconds [s] ($\Delta t = 1.0\text{ s}$) | `p.dt`, `S5.dt` |
| $T_{\text{cycle}}$ | Full signal cycle duration | Total cycle length | Seconds [s] ($T_{\text{cycle}} = 63.0\text{ s}$) | `p.cycle` |
| $u(k)$ | Active green phase index | Active approach phase | Phase state index ($\in \{1, 2, 3\}$) | `active` |
| $t_{\text{clear}}$ | Congestion clearance duration | Clearance time after event | Seconds [s] | `C.tClear` |
| $E_{\text{veh}}$ | Cumulative excess vehicle delay | Excess queue integral | Vehicle-seconds [$\text{veh}\cdot\text{s}$] | `C.excessVehS` |
| $V_{\text{AC}}$ | AC mains supply root-mean-square voltage | Electrical grid source | Volts RMS [$\text{V}_{\text{rms}}$] ($230\text{ V}$) | `S5.par.Vac_rms` |
| $f_{\text{grid}}$ | AC grid supply frequency | Electrical grid frequency | Hertz [Hz] ($50\text{ Hz}$) | `S5.par.f_ac` |
| $V_{\text{DC}}$ | Rectified DC-link intermediate voltage | Filtered DC-link potential | Volts DC [V] ($47.31\text{ V}$ mean) | `S5_vDC` |
| $V_{\text{bus}}$ | Regulated signal-head distribution bus | Regulated power bus | Volts DC [V] ($24.0\text{ V}$ target) | `S5_vBus` |
| $I_{\text{ch}}$ | Signal-head driver channel current | Head illumination current | Amperes [A] ($1.0\text{ A}$ nominal) | `S5_iCh` |
| $C_{\text{dc}}$ | Bulk DC-link filter capacitance | Energy buffer capacitor | Farads [F] ($2200\,\mu\text{F}$) | `S5.par.C_dc` |
| $L_{\text{buck}}$ | Buck DC-DC power inductor | Buck energy storage choke | Henries [H] ($2.0\text{ mH}$) | `S5.par.L_buck` |
| $C_{\text{out}}$ | Buck DC-DC output filter capacitor | Bus smoothing capacitor | Farads [F] ($3300\,\mu\text{F}$) | `S5.par.C_out` |
| $t_d$ | Semiconductor dead-time interlock | Clearance red interval | Microseconds [$\mu\text{s}$] ($5.0\,\mu\text{s}$) | `deadtime_us` |
| $\sigma_{\text{noise}}$ | Detector additive noise standard deviation | Sensor measurement error | Vehicles [veh] ($\sigma = 2.0\text{ veh}$) | `ev.mag` |
| $q_{4\max}$ | Downstream bottleneck spill-back limit | B4 storage threshold | Vehicles [veh] ($q_{4\max} = 15.0\text{ veh}$) | `net.q4max`, `S5.q4max` |

---
