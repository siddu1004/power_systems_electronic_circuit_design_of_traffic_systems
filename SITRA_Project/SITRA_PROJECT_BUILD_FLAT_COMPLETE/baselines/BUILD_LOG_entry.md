
---
## BASELINE COMPARISON — Webster / Actuated / Max-pressure vs SITRA (T1–T7)
Date: 2026-11-09
Status: IMPLEMENTED — run in GNU Octave 8.4 (integration PASS). MATLAB run + figure inspection PENDING.

Files added (new folder MATLAB/baselines/, no frozen file edited):
bl_config, bl_scenarios, bl_make_arrivals, bl_plant_step, bl_gates, bl_paths,
bl_ctrl_sitra, bl_ctrl_webster, bl_ctrl_actuated, bl_ctrl_maxpressure,
bl_simulate, bl_metrics, bl_hcm_los, bl_export_for_simulink,
test_bl_integration, run_baseline_comparison, README_BASELINES.md

Integration evidence (Octave): SITRA through the harness on T6 vs frozen Part 8:
max|q - qHist| = 0, activeHist identical, gates valid, residual 7.2e-16 -> PASS.

Fairness: one arrival sequence per (scenario, seed) shared by all controllers;
same capacities (ASSUMED), q0 = 0, dt = 1 s, durations, seeds 101-105.

Scenarios are T1–T7 (not S-numbers): low / moderate / high / oversaturated /
step / Part 8 surge deterministic / Part 8 surge Poisson.

Next action: run test_bl_integration and run_baseline_comparison in MATLAB,
inspect Results/baselines/fig1..fig6, record the table here.
