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
  2. Select universal AC-DC converter (85–264 VAC input, 24 VDC / 5 A output, 120 W, e.g., Mean Well SDR-120-24).
  3. Margin: $120\text{ W} / 24\text{ W} = 5.0\times$ headroom for cold inrush and auxiliary electronics.

---

## 2. DC-Link Decoupling Capacitor ($C_{dc,link} = 1000\,\mu\text{F}$)
- **Status in S5**: PLACEHOLDER (`1000 uF, 35 V, ESR = 0.02 Ohm`)
- **Governing Simulation Quantities**:
  - Step load current change during phase commutation: $\Delta I_{load} = 1.0\text{ A}$.
  - Switch commutation transient duration: $\Delta t_{comm} = 50\,\mu\text{s}$.
  - Allowable DC bus ripple voltage: $\Delta V_{ripple,max} \le 2\% \cdot 24\text{ V} = 0.48\text{ V}$.
- **S12 Selection Procedure**:
  1. Calculate minimum capacitance:
     $$C_{min} = \frac{\Delta I_{load} \cdot \Delta t_{comm}}{\Delta V_{ripple,max}} = \frac{1.0\text{ A} \cdot 50\times 10^{-6}\text{ s}}{0.48\text{ V}} \approx 104\,\mu\text{F}$$
  2. Apply safety margin of $5\times$ for electrochemical aging and low-temperature capacitance derating ($-20^\circ\text{C}$):
     $$C_{selected} \ge 500\,\mu\text{F} \implies \text{Use } 1000\,\mu\text{F}, 50\text{ V, Low-ESR aluminum electrolytic}$$
  3. Ensure RMS ripple current rating exceeds $I_{rms,ripple} = \sqrt{D(1-D)} I_{load} \approx 0.5\text{ A}_{rms}$.

---

## 3. Power Semiconductor Switches ($S_1, S_2, S_3$)
- **Status in S5**: PLACEHOLDER (`R_on = 0.025 Ohm, V_gs = 10 V`)
- **Governing Simulation Quantities**:
  - Continuous on-state current: $I_{D} = 1.0\text{ A}$ (fault peak: $5.0\text{ A}$).
  - Off-state blocking voltage: $V_{DS,max} \ge 1.5 \cdot V_{dc} = 36\text{ V}$.
  - Maximum allowable conduction dissipation: $P_{loss} \le 0.1\text{ W}$ (to eliminate external heatsink).
- **S12 Selection Procedure**:
  1. Select N-channel logic-level Power MOSFET in TO-220 or D2PAK (e.g., Vishay IRF540N or STMicroelectronics STP36NF06L, $60\text{ V}, 30\text{ A}, R_{DS(on)} < 0.03\,\Omega$).
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
  1. Implement hardware-level cross-conduction interlock logic using hardware NAND/NOR gates (e.g. 74HC08 / 74HC02) in series with micro-controller GPIOs.
  2. In the event of a micro-controller crash, software bug, or memory fault commanding two greens simultaneously, the physical hardware logic forces all gates LOW in $< 15\text{ ns}$, preventing physical collision phases.

---

## 5. Overcurrent Protection & Electronic Fuse ($I_{trip} = 2.0\text{ A}$)
- **Status in S5**: PLACEHOLDER (`2.0 A threshold`)
- **Governing Simulation Quantities**:
  - Normal full-load current: $1.0\text{ A}$.
  - Inrush current: $1.5\text{ A}$ for 10 ms.
  - Short-circuit current: $> 4.0\text{ A}$.
- **S12 Selection Procedure**:
  1. Select resettable PTC fuse or high-side smart power switch with integrated current sensing (e.g., TI TPS1H100-Q1 or Infineon PROFET).
  2. Set trip current to $2.0\text{ A}$ with 50 ms deglitch filter to ignore cold LED inrush while tripping on sustained cable shorts within $< 100\,\mu\text{s}$.
