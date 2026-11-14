# HANDOFF (for continuing after context reset)

Branch pushed: local `bt-results` -> remote `ccr-27f50ecb-k5rs69` (push with
`git push origin bt-results:ccr-27f50ecb-k5rs69`). Draft PR #3. Do NOT write the paper (user wants to do it together).

## State
- Algorithm versions: blocktetris/circuit.py VERSIONS (v2, v3, v4, v5, v6, v7, v7+police, v7-final = best).
- Controllers in circuit: fixed, actuated, scats, scoot, maxp, bt (+ police option), sitra (being added).
- City model: blocktetris/city.py (CityNet.from_osm), fetch: blocktetris/osm_fetch.py (OSM map API; env allows api.openstreetmap.org).
- Corridor data: data/osm/coimbatore_peelamedu.json (36 junctions). Results bundle: Results/BlockTetris/BUNDLE (README, THEORY, figures).
- Real-time study: blocktetris/realtime_experiments.py (8-11 controllers x 7 events).

## Current task (user request)
1. Add SITRA-MPC (repo's mpcSignalModel generalised) as circuit controller "sitra".
2. Full-city e-twin: fetch whole Coimbatore major-road network -> data/osm/coimbatore_city.json.
3. Run all algorithms (Fixed, SCOOT-like, SCATS-like, Actuated, MaxPressure, SITRA-MPC, BT v3, v6, v7-final, Fixed+police)
   x congestion events on the full city; save figures/results to Results/BlockTetris/city_full; add to BUNDLE; report to user crisply.

## Update: full-city run done
- **Map:** `data/osm/coimbatore_city.json` (521 junctions, 759 km).
- **Results:** `Results/BlockTetris/city_full/` and the BUNDLE README section "FULL CITY".
- **Main finding:** BT beats all controllers in all 7 events. v7-final is 12–19 % better than Actuated, 26–31 % better than SITRA-MPC and 40–45 % better than Fixed.
- **Delay breakdown:** BT's gain is mostly in spillback (−37 %); at the signals it is −14 %; the give-way and gate floor is about 75 s.
- **Open items:**
  - v7-final's worst wait (146–161 s) is above Actuated's and SITRA-MPC's (~90–100 s);
  - the police pool has not been sized for the city;
  - demand is uniform.
- The paper is still NOT to be written.

## Update: SUMO validation (13 Nov)
- **Code:** `blocktetris/sumo_net.py` (map conversion), `sumo_experiments.py` (runner, all controllers, BT v7-final to v12), `sumo_estimator.py` (robust estimator), `sumo_tune.py` (tuning on seeds 1–6).
- **Final version:** v12 (realistic cameras + estimator).
- **Results on test seeds 11–13:** −5 % vs MaxPressure, −5 to −8 % vs Actuated (significant).
- **Where to find it:** BUNDLE README section "SUMO VALIDATION".
- **Next:** full-city SUMO (`sumo/city`, 333 TLS), police-alert rate limiting, rain and surge.
- The paper is still NOT to be written.

## FINAL version: v13-final (13 Nov)
- **Code:** `BT_V13F` in `blocktetris/sumo_experiments.py`; it integrates v1–v13 together with v3 HOL.
- **Results on test seeds 11–13:**
  - −13 % vs MaxPressure and −16 % vs Actuated at demand 0.07;
  - −11 % vs both at demand 0.10;
  - all p < 0.001.
- **Where to find it:** BUNDLE README section "FINAL VERSION".
- **Next:** a full-city SUMO check. The paper is to be written together with the owner; do not draft it alone.
