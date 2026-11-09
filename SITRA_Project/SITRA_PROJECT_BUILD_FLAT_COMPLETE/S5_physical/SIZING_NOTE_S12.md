# S12 Hardware Sizing Specifications & Engineering Procedures

This document provides the sizing rationale and exact design procedures for Stage S12 to select real, commercially available hardware components based on the simulation quantities recorded in Stage S5.

---

## 1. DC Bus Voltage ($V_{dc,nominal} = 24.0\text{ V}$)
- **Status in S5**: PLACEHOLDER (`24.0 V`)
- **Governing Simulation Quantities**:
  - Maximum branch load current: $I_{load,max} = 1.0\text{ A}$ per signal head.
  - Total simultaneous power draw: $P_{peak} = 24.0\text{ W}$.
  - Cable drop across 50 m roadside conduit: $\Delta V_{cable} = 2 \cdot L \cdot R_{wire} \cdot I = 2 \cdot 50 \cdot (0.013\,\Omega/\text{m}) \cdot 1.0\text{ A} \approx 1.3\text{ V}$.
- **S12 Selection Procedure**:
  1. Standardize on 24 VDC industrial DIN-rail power supplies (compliant with EN 50556 / NEMA TS 2 traffic standards).
  2. Select universal AC-DC converter (85–264 VAC input, 24 VDC / 5 A output, >= 120 W industrial DIN-rail power supply).
  3. Margin: $120\text{ W} / 24\text{ W} = 5.0\times$ headroom for cold inrush and auxiliary electronics.

---

## 2. DC-Link and Output Filter Capacitors

### A. DC-Link Decoupling Capacitor ($C_{dc} = 2200\,\mu\text{F}$)
- **Status in S5**: PLACEHOLDER (`2200 uF, 63 V, ESR = 0.05 Ohm`)
- **Governing Simulation Quantities**:
  - Full-wave rectified 100 Hz ripple from 50 Hz mains.
  - Step load current change during phase commutation: $\Delta I_{load} = 1.0\text{ A}$.
  - Peak DC-link voltage: $V_{dc,peak} \approx \sqrt{2} \cdot 36\text{ V} \approx 50.9\text{ V}$.
  - Allowable DC bus ripple voltage: $\Delta V_{ripple,max} \le 5\% \cdot 48\text{ V} \approx 2.4\text{ V}$.
- **S12 Selection Procedure**:
  1. Calculate minimum holdup capacitance:
     $$C_{min} = \frac{I_{load}}{2 f_{ac} \cdot \Delta V_{ripple}} = \frac{1.0\text{ A}}{100\text{ Hz} \cdot 2.4\text{ V}} \approx 416\,\mu\text{F}$$
  2. Apply a safety factor of $\approx 5\times$ for electrochemical aging, low-temperature derating ($-20^\circ\text{C}$), and converter inrush:
     $$C_{selected} \ge 2000\,\mu\text{F} \implies \text{Use } 2200\,\mu\text{F}, 63\text{ V or 100 V, Low-ESR aluminum electrolytic}$$
  3. Ensure RMS ripple current rating exceeds $I_{rms,ripple} \ge 1.2\text{ A}_{rms}$.

### B. Regulated Signal-Head Bus Capacitor ($C_{out} = 3300\,\mu\text{F}$)
- **Status in S5**: PLACEHOLDER (`3300 uF, 35 V, with RC damper C_damp = 4.7 mF, R_damp = 1 Ohm`)
- **Governing Simulation Quantities**:
  - Buck converter switching frequency: $f_{sw} = 10\text{ kHz}$.
  - Load-step current droop suppression: $\Delta I_{load} = 1.0\text{ A}$ step during green phase switch.
  - Dynamic regulation requirement: $V_{bus}$ maintained within $24.0\text{ V} \pm 10\%$ ($21.6\text{ V} - 26.4\text{ V}$) under 1 A step loads.
- **S12 Selection Procedure**:
  1. Size $C_{out} = 3300\,\mu\text{F}$ to keep maximum transient droop below $1.94\text{ V}$ ($8.1\%$, passing the $10\%$ specification).
  2. Implement parallel RC damper ($R_{damp} = 1\,\Omega$, $C_{damp} = 4700\,\mu\text{F}$) to suppress LC filter resonance with $L_{buck} = 2\text{ mH}$.

---

## 3. Power Semiconductor Switches ($S_1, S_2, S_3$)
- **Status in S5**: PLACEHOLDER (`R_on = 0.025 Ohm, V_gs = 10 V`)
- **Governing Simulation Quantities**:
  - Continuous on-state current: $I_{D} = 1.0\text{ A}$ (fault peak: $5.0\text{ A}$).
  - Off-state blocking voltage: $V_{DS,max} \ge 1.5 \cdot V_{dc} = 36\text{ V}$.
  - Maximum allowable conduction dissipation: $P_{loss} \le 0.1\text{ W}$ (to eliminate external heatsink).
- **S12 Selection Procedure**:
  1. Select N-channel logic-level Power MOSFET in standard power package (minimum ratings: V_DS >= 60 V, continuous I_D >= 20 A, R_DS(on) <= 30 mOhm at V_GS = 10 V).
  2. Conduction dissipation at 1 A:
     $$P_{cond} = I_D^2 \cdot R_{DS(on)} = (1.0)^2 \cdot 0.025 = 25\text{ mW}$$
     Junction temperature rise above ambient ($T_A = 50^\circ\text{C}$):
     $$\Delta T_J = P_{cond} \cdot R_{\theta JA} = 0.025\text{ W} \cdot 62^\circ\text{C/W} \approx 1.55^\circ\text{C} \quad (\text{Safe natural convection})$$
  3. Add gate protection Zener diode (15 V) and $10\text{ k}\Omega$ pulldown resistor for fail-safe gate turn-off.

---

## 4. Hardware Dead-Time & Interlock Unit
- **Status in S5**: FACTUAL ($3.0\text{ s}$ traffic clearance, $< 1\text{ ms}$ gate interlock)
- **Governing Simulation Quantities**:
  - Mutual exclusion rule: $\sum g_b \le 1$.
  - All-red clearance: 3 seconds during which all gates are zero.
- **S12 Selection Procedure**:
  1. Implement hardware-level cross-conduction interlock logic using standard fast discrete digital logic gates in series with microcontroller GPIOs.
  2. In the event of a microcontroller crash, software bug, or memory fault commanding two greens simultaneously, the physical hardware logic forces all gates LOW in < 25 ns, preventing physical collision phases.

---

## 5. Overcurrent Protection & Electronic Current Limiter ($I_{trip} = 2.0\text{ A}$)
- **Status in S5**: PLACEHOLDER (`2.0 A threshold`)
- **Governing Simulation Quantities**:
  - Normal full-load current: $1.0\text{ A}$.
  - Inrush current: $1.5\text{ A}$ for 10 ms.
  - Short-circuit current: $> 4.0\text{ A}$.
- **S12 Selection Procedure**:
  1. Select a high-side smart power switch with integrated current sensing and thermal shutdown, or an electronic current-limiting circuit.
  2. Set trip current to $2.0\text{ A}$ with 50 ms deglitch filter to ignore cold LED inrush while tripping on sustained cable shorts within $< 100\,\mu\text{s}$.
