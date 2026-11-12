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

---

## FINAL: v7-final (v7 + police failsafe + 120 s service guarantee)

**Figures:** `realtime_FINAL__*.png`. **Raw data:** `realtime/results_3.json`. Same 7 events, 4 seeds, Coimbatore twin.

| Event | Fixed-40 | SCOOT-like | SCATS-like | Actuated | MaxPressure | Fixed + police | BT v3 | BT v7 | **BT v7-final** |
|---|---|---|---|---|---|---|---|---|---|
| Normal peak | 570 | 489 | 737 | 483 | 699 | 452 | 190 | 185 | 187 |
| Accident | 623 | 609 | 761 | 557 | 770 | 512 | 203 | 207 | **198** |
| Monsoon rain | 619 | 601 | 857 | 552 | 727 | 494 | 248 | 228 | 233 |
| Festival surge | 841 | 792 | 996 | 782 | 1027 | 688 | 352 | 367 | **343** |
| VIP closure | 741 | 739 | 776 | 623 | 873 | 662 | 233 | 202 | 205 |
| Signal power failure | 518 | 636 | 644 | 537 | 819 | 600 | 227 | 214 | **178** |
| CCTV failure | 570 | 489 | 737 | 483 | 699 | 452 | 197 | 194 | **192** |

- **v7-final** is best in 4 of 7 events and within 1–2 % of the best in the other 3.
- **Accident:** it clears in 25 min, the fastest of all controllers.
- **Police calls:** v7-final raises 0–3 alerts per event. Fixed + police raises 6.5–15 alerts per event and still has about 2.4× the delay.

### Police failsafe

A junction raises an alert in three cases:
- its signal goes dark (alert at once);
- it stays gridlocked for 60 s;
- it stays at 70 % or more of its stored capacity for 120 s.

Officers then work as follows:
- **Dispatch:** a limited pool (3 officers) goes to the worst junctions first and arrives after 5 minutes.
- **On duty:** an officer serves the longest queue first, waves vehicles past blocked turn pockets, and restores discharge at a dark signal.
- **Release:** after 300 s of calm.

### Final audit: weak points found and what was done

| Weak point | Evidence | Action | Result |
|---|---|---|---|
| A movement could wait too long (pedestrians, side roads) | Worst servable wait 200–370 s for BT vs about 100 s for cycle-based controllers | 120 s service guarantee: end the current green and serve the late movement | Worst wait 147–163 s (253 s with a dark signal); mean delay also fell, 223 → 220 s |
| v7 lost to v3 in the festival surge | 367 vs 352 s | Police failsafe and service guarantee | 343 s, now the best |
| v7 lost to v3 in the accident | 207 vs 203 s | Same | 198 s, now the best |
| Starving movements were only served when the current green ended | Waits reached the guard plus max green | Hard cap tested; superseded by the service guarantee | — |
| Special-mode overload trigger | Never fires at city demand | Kept; it is only an option | No effect |
| Clearance metric is relative to each controller's own normal day | BT's normal day is much lower | Use delay and peak queue as the headline measures | Documented |
| Dark-signal model | A 20 s give-way alternation flatters Fixed | Police restore dark junctions | Documented |
| Worst wait is still above the ~100 s of fixed cycles | 147–163 s | — | **Open:** a cyclic-order variant would trade a little delay for predictability |
