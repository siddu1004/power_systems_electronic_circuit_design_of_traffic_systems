# 13. Future Scope and Real-Time Hardware Deployment Roadmap

This section establishes a concrete engineering roadmap for transitioning the SITRA framework from simulation and open-loop replay into a live, field-operational signal controller deployed at the SITRA intersection.

## 13.1 Field Sensing and Current Mapping Architecture
In field deployment, physical capacitor charging current ($i_{\text{in}}$) must be derived from roadside traffic sensors:
1. **Sensor Technologies:** Upstream approaches will be instrumented with overhead thermal/optical AI edge cameras (e.g., Nvidia Jetson Orin modules running YOLOv8 tracking) or advance inductive loop detector pairs installed $100\text{ m}$ upstream of the stop line.
2. **Current Mapping Formulation:** Vehicular passage counts $\Delta N_b(t)$ measured over discrete sampling interval $\Delta t = 1.0\text{ s}$ map directly to digital current injection words:
   $$I_{\text{in}, b}(k) = \frac{\Delta N_b(k)}{\Delta t} \quad [\text{A} \longleftrightarrow \text{veh/s}] \tag{56}$$
3. **Queue Estimation Filter:** A discrete Kalman filter will fuse advance arrival counts, stop-line departure counts, and optical stop-line queue length measurements, updating virtual capacitor state estimates $\hat{v}_{Cb}(k)$ in real time.

---

## 13.2 Signal Controller Cabinet and Power Supply Unit (Stage S12)
The physical power path modeled in Section 4 (Fig. 4.2) serves as the exact design blueprint for the field controller cabinet power supply unit (PSU):
- **Utility Ingress:** $230\text{ V}_{\text{rms}}$, $50\text{ Hz}$ utility feed equipped with Class II surge protection devices (SPD) compliant with IEC 61643-11 to arrest lightning transients common during the monsoon season in Coimbatore.
- **Power Supply Sizing (Stage S12):** Sized for a continuous load of $150\text{ W}$, incorporating a $230\text{V} / 36\text{V}_{\text{rms}}$ magnetic transformer, a Vishay 2W10G full-wave bridge rectifier, a $2200\,\mu\text{F} / 63\text{V}$ low-ESR electrolytic capacitor bank (Nichicon UVY1J222MHD), and an industrial $24\text{ V}$, $5\text{ A}$ synchronous buck converter module.
- **Battery Energy Storage System (BESS):** A $24\text{ V}$, $40\text{ Ah}$ lithium iron phosphate ($\text{LiFePO}_4$) battery backup buffer integrated across the DC distribution bus, providing up to four hours of continuous intersection operation during municipal grid load-shedding events.

---

## 13.3 Transition from Replay to Closed-Loop Hardware Control
The critical next step is closing the physical feedback control loop:
1. **Phase 1 (Hardware-in-the-Loop Testbed):** The physical Simscape circuit will be deployed onto an FPGA-based real-time digital simulator (e.g., OPAL-RT OP4510). An embedded industrial microcontroller (STM32H7 dual-core ARM Cortex-M7/M4 running at $480\text{ MHz}$) will read analog capacitor voltages via on-chip 16-bit successive approximation ADCs ($0\text{–}3.3\text{ V}$ scaled from $0\text{–}15\text{ V}$ via precision operational amplifiers).
2. **Phase 2 (On-Chip QP Solver Execution):** The microcontroller will solve the SITRA MPC quadratic program using an embedded C-generated operator-splitting quadratic program (OSQP) solver, computing optimal green splits within $0.5\text{ ms}$ and outputting $10\text{ V}$ gate pulses to physical opto-isolated MOSFET gate driver ICs (e.g., TI UCC21520).
3. **Phase 3 (Live Sensor Feeding):** Analog capacitor inputs will be replaced by live optical camera queue tracking data streamed over industrial Modbus TCP / Ethernet IP interfaces.

---

## 13.4 Applicable Standards and Regulatory Compliance
Field deployment will adhere strictly to relevant national and international engineering standards:
- **Traffic Signal Engineering:**
  - *IRC:93-1985 (Reaffirmed 2019):* Guidelines on Design and Installation of Road Traffic Signals, Indian Roads Congress, New Delhi [9].
  - *IRC:SP:41-1994:* Guidelines on the Design of At-Grade Intersections in Rural & Urban Areas.
  - *NEMA TS2-2016:* Traffic Controller Assemblies with NTCIP Requirements, National Electrical Manufacturers Association.
- **Electrical and Power Safety:**
  - *IEEE 519-2022:* Standard for Harmonic Control in Electric Power Systems (governing total harmonic distortion on AC utility grid).
  - *IEC 61508 / ISO 26262:* Functional Safety Standards for Electrical/Electronic Programmable Safety-Related Systems (governing hardware mutual-exclusion interlocks and dead-time enforcement).

---

## 13.5 Step-by-Step Pilot Deployment Plan
Table 13.1 outlines the phased pilot deployment plan targeting the SITRA intersection on Avinashi Road.

Table 13.1: Five-Stage Pilot Deployment Roadmap.

| Milestone | Phase Name | Target Duration | Key Engineering Deliverables | Success Criteria |
|---|---|---|---|---|
| **M1** | Hardware Sizing & Component Procurement (Stage S12) | Months 1–3 | Bill of materials finalization, procurement of commercial candidates (Nichicon caps, Vishay MOSFETs, STM32H7 board), PCB schematic design | Completed hardware design package and lab component validation |
| **M2** | Hardware-in-the-Loop (HIL) Lab Emulation | Months 4–6 | Real-time execution of `SITRA_S5_Physical.slx` on OPAL-RT; STM32H7 microcontroller closed-loop ADC tracking and OSQP execution | Real-time execution with closed-loop voltage error $< 1.0\text{ mV}$ |
| **M3** | Field Sensor Instrumentation & Baseline Data Collection | Months 7–8 | Installation of edge AI video cameras on B1, B2, B3, and B4; 60 days of continuous traffic flow, turning movement, and queue length data collection | Calibrated empirical saturation capacities ($C_1..C_4$) and arrival profiles |
| **M4** | Shadow-Mode Field Controller Validation | Months 9–10 | Deployment of SITRA cabinet running in parallel "shadow mode" (processing live camera data and generating timings without actuating signals) | Verified zero algorithmic lockups, valid green split timing under live traffic |
| **M5** | Live Signal Commissioning & Clearance Verification | Months 11–12 | Full physical cutover to SITRA controller; live empirical measurement of congestion clearance times during peak airport and commuter hours | Measured arterial queue reduction $\ge 15\%$ without safety violations |
