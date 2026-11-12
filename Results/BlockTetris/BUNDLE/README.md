# Block-Tetris: results bundle

Everything in one place for the team. This is not the paper.

- **Theory:** [`THEORY.md`](THEORY.md) covers the equations, versions v1–v7, the real-world controllers and the city model.
- **Figures:** all 18 PNGs are in [`figures/`](figures). Each name starts with the experiment folder it came from.
- **Detailed write-up:** `Report/BlockTetris_Results.md`, Parts 1–6. Raw numbers are in each `Results/BlockTetris/*/results.json`.

## Headline results

### A. Real Coimbatore network (OpenStreetMap, 36 junctions, 43.8 km)

This is the electrical twin. Morning-peak demand, 4 seeds, average delay per unit of traffic in seconds.

| Event | Fixed-40 | SCOOT-like | SCATS-like | Actuated | MaxPressure | **BT v3** | **BT v6** | **BT v7** |
|---|---|---|---|---|---|---|---|---|
| Normal peak | 570 | 489 | 737 | 483 | 699 | 190 | 186 | **185** |
| Accident (busiest road) | 623 | 609 | 761 | 557 | 770 | **203** | **203** | 207 |
| Monsoon rain | 619 | 601 | 857 | 552 | 727 | 248 | 230 | **228** |
| Festival surge | 841 | 792 | 996 | 782 | 1027 | **352** | 356 | 367 |
| VIP closure (3 roads) | 741 | 739 | 776 | 623 | 873 | 233 | 215 | **202** |
| Signal power failure | 518 | 636 | 644 | 537 | 819 | 227 | 221 | **214** |
| CCTV failure | 570 | 489 | 737 | 483 | 699 | 197 | **193** | 194 |

- **Every event:** the Block-Tetris versions have 2.3–3.7× less delay than every real-world controller.
- **v7** (v3 normally, v6 in special cases) is best in 4 of 7 events. In the other 3 it is within 3 % of the best in two (accident 207 vs 203 s, CCTV failure 194 vs 193 s) and about 4 % behind in the festival surge (367 vs 352 s).
- **v3 and v6 run on different sensing:** v3 uses perfect queue knowledge; v6 and v7 use realistic 60 m CCTV.

**Figures:** `realtime__rt1_delay_by_event.png`, `realtime__rt2_relative_heatmap.png`, `realtime__rt3_queue_timeseries.png`, `realtime__rt4_clearance.png`, `realtime__rt5_map_accident_*.png`, `city__city_map_*.png`.

### B. Published SITRA benchmark

Exact port, matching to 0.002 %; 30 paired seeds. Block-Tetris beats Actuated (the best existing controller) in 12 of 13 scenarios (p < 0.05). T12 (stuck sensor) is not significant.

**Figure:** `sitra__fig9_sitra_benchmark.png`.

### C. 4×4 grid electrical twin

- **N-1 sweep:** 88 single faults at three load levels (`circuit__fig8_n1_contingency.png`).
- **Capacity curve:** `circuit__fig7_capacity_curve.png`.
- **Held-out runs:** v3, v4 and v6 beat Fixed and MaxPressure in 10 of 10 runs (p = 0.002).

### D. Vehicle-level simulator (Part 1)

8 scenarios. Figures: `main__fig1`–`main__fig6`.

## Caveats to discuss before writing

- **Clearance metric:** it compares each controller with its own normal day. Block-Tetris's normal day is much lower, so its minutes-to-clear are not directly comparable. Use delay and peak queue as the main measures.
- **Camera failure for the baselines:** fixed time, SCOOT-like, SCATS-like, Actuated and MaxPressure are not affected in the model (they read loop detectors or nothing). That is why the CCTV-failure row equals the normal-peak row for them.
- **Signal power failure:** a dark junction runs a 20 s give-way alternation. That is shorter than Fixed-40's cycle, which is why Fixed looks slightly better there than on a normal day. It's a modelling artefact to refine.
- **SCATS-like and SCOOT-like** are simplified re-implementations of the published logic, not the commercial systems.
- **Still assumed:** demand, turn shares and vehicle weights. Signal locations are inferred (OSM tags only 3).
