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
