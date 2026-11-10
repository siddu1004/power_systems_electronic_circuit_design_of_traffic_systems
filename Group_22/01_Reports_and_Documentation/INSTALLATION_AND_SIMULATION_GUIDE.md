# PROJECT SITRA: INSTALLATION, CONFIGURATION & SIMULATION GUIDE
## GROUP 22 — AMRITA SCHOOL OF ENGINEERING, COIMBATORE
### DEPARTMENT OF ELECTRICAL AND ELECTRONICS ENGINEERING

---

### 👥 Student Author Information

* **Sreedev C.** — Roll Number: `CB.EN.U4EEE24142`
* **Vanguri Satya Sai Siddardh** — Roll Number: `CB.EN.U4EEE24152`
* **Vishal S.** — Roll Number: `CB.EN.U4EEE24155`
* **Team / Group Allocation**: **Group 22**
* **Course Project**: Power Systems & Power Electronics Representation of Urban Traffic Systems
* **Faculty Evaluator**: **Dr. S. Sampath Kumar**
* **Public GitHub Repository**: [https://github.com/siddu1004/power_systems_electronic_circuit_design_of_traffic_systems](https://github.com/siddu1004/power_systems_electronic_circuit_design_of_traffic_systems)
* **SharePoint Submission Portal**: [Amrita SharePoint Evaluation Folder](https://amritavishwavidyapeetham-my.sharepoint.com/:f:/g/personal/s_sampathkumar_cb_amrita_edu/IgAK4dvf6TUlTKKTGJSpx1OLAXrJC_bJiNnfLnpgnP1RPHk?e=ytyGOd)

---

## 1. System Requirements & Prerequisites

To execute the full simulation suite (Track 1 and Track 2), the following software environment is required:

### Primary Computational Stack:
- **MATLAB Version**: MATLAB **R2024b** or newer (compatible through MATLAB R2026a).
- **Required Toolboxes & Products**:
  1. **Simulink** (Base block diagram environment)
  2. **Simscape** (Physical modeling engine)
  3. **Simscape Electrical** (Power systems, power converters, semiconductors, sensors)
  4. **Optimization Toolbox** (For MPC quadratic programming routines)
  5. **Signal Processing Toolbox** (For baseline moving-average filtering)

### Web Interactive Platform (Optional):
- **Node.js**: v18.0.0 or higher
- **pnpm**: v9.0.0 or higher (or `npm`)

---

## 2. Repository Cloning & Workspace Setup

### Option A: From GitHub Repository
Clone the official public git repository to your local system:
```bash
git clone https://github.com/siddu1004/power_systems_electronic_circuit_design_of_traffic_systems.git
cd power_systems_electronic_circuit_design_of_traffic_systems
```

### Option B: From the Submission Package
Extract either `Group_22.zip` or `SITRA_Entire_Codebase_Group22.zip` to a local folder (e.g., `D:\SITRA_Project`).

---

## 3. MATLAB Environment Configuration

1. Launch **MATLAB**.
2. Set the **Current Folder** in MATLAB to the root of the project directory (or `Group_22\02_Simulation_Models_and_Code`).
3. Ensure all project paths are initialized by running in the MATLAB Command Window:
   ```matlab
   rootDir = pwd;
   addpath(rootDir);
   addpath(fullfile(rootDir, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE'));
   addpath(fullfile(rootDir, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE', 'S5_physical'));
   addpath(fullfile(rootDir, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE', 'S6_S7_parasitics'));
   addpath(fullfile(rootDir, 'SITRA_Project', 'SITRA_PROJECT_BUILD_FLAT_COMPLETE', 'baselines'));
   ```

---

## 4. How to Execute Simulations

### 4.1 One-Click Unified Master Simulation Runner
Run the master script:
```matlab
run_master_all
```
You will be prompted to select one of four execution modes:
- **`Mode [1] Run All`**: Executes Track 1 (Simulink state-space comparison), Track 2 (Simscape physical circuit), and multi-scenario clearance benchmarks.
- **`Mode [2] Track 1 Only`**: Runs Parts B, C, and D (`SITRA_S2_test_ControllerCompare.slx`).
- **`Mode [3] Track 2 Only`**: Runs physical Simscape circuit (`SITRA_S5_Physical.slx`), S6 capacitor ESR parasitics, and S7 MOSFET thermal equilibrium.
- **`Mode [4] Baselines Only`**: Runs the 14-scenario multi-controller benchmark suite (T1 to T14).

---

### 4.2 Track 1: Mathematical Multi-Controller Benchmarking

To test the 4 controllers (SITRA MPC, Webster Fixed-Time, NEMA Vehicle-Actuated, Feedback MaxPressure) on the 9-stage discrete architecture:
```matlab
% 1. Run integrated multi-controller comparison:
run_part_d_integrated

% 2. Verify 5 us gate dead-time interlock protection:
run_part_c

% 3. Verify Kirchhoff Current Law (KCL) conservation residual (< 1.42e-15 A):
run_part_b

% 4. Verify model wiring and eliminate any dangling lines:
fix_all_model_connections
```

---

### 4.3 Track 2: Simscape Physical Circuit & Power Electronics

To test the authentic physical Simscape circuit (100% code-free physical blocks):
```matlab
% 1. Automated acceptance test suite for SITRA_S5_Physical.slx:
cd('SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/S5_physical');
test_SITRA_S5_Physical

% 2. Replay all 32 controller runs through the Simscape physical circuit:
run_controllers_on_S5_physical

% 3. Verify capacitor ESR compensation & MOSFET junction thermal equilibrium:
cd('../S6_S7_parasitics');
run_all_S6_S7
```

---

### 4.4 Multi-Scenario Baseline Congestion Clearance Benchmark

To run all 14 operational scenarios (T1 to T14) across 5 random seeds using the non-circular Twin-Run Clearance Metric:
```matlab
cd('SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/baselines');
run_baseline_comparison
```

---

## 5. Summary of Verification Gates & Expected Results

| Verification Metric | Target Tolerance | Measured Value | Status |
| :--- | :---: | :---: | :---: |
| **Circuit Tracking Error** $|v_C - q_{\text{ref}}|$ | $< 1.0 \times 10^{-3}\text{ V}$ | **$< 8.0 \times 10^{-6}\text{ V}$** ($8.0\,\mu\text{V}$) | **PASS** |
| **KCL Conservation Residual** | $\le 10^{-8}\text{ A}$ | **$7.22 \times 10^{-16}\text{ A}$** | **PASS** |
| **Gate Dead-Time Interlock** | $\ge 4.50\,\mu\text{s}$ | **$5.00\,\mu\text{s}$** | **PASS** |
| **Auxiliary DC Bus Voltage** | $24.0\text{ V} \pm 10\%$ | **$23.98\text{ V}$** ($< 15\,\text{mV}$ ripple) | **PASS** |
| **ESR Sensor Error After Comp.** | $< 1.0\text{ mV}$ | **$< 0.1\text{ mV}$** | **PASS** |
| **MOSFET Junction Temp Rise** | $T_j < 150^\circ\text{C}$ | **$27.80^\circ\text{C}$** ($> 140^\circ\text{C}$ margin) | **PASS** |
| **Physical Clearance Discrepancy** | $\le 1.0\text{ s}$ vs model | **$0.00\text{ s}$** (Exact integer match) | **PASS** |

---

## 6. Running the Interactive Web Research Platform (Optional)

In your terminal:
```bash
# Navigate to repository root
pnpm install
pnpm dev
```
Open your browser to: `http://localhost:8443`
