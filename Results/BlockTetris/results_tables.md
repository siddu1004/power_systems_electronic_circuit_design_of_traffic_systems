# Block-Tetris results (8 seeds per cell, mean ± standard error)


## S0: Normal day (no incident)

| Controller | Avg delay (s) | 95th pct delay (s) | Max approach queue (blocks) | Spillbacks | Served vehicles | Clearance after incident (s) | Cleared runs | Excess queue (block·h) |
|---|---|---|---|---|---|---|---|---|
| Fixed-40 | 205 ± 4 | 471 ± 11 | 75.8 ± 4.8 | 2.2 ± 1.1 | 12142 ± 33 | – | – | – |
| MaxPressure | 164 ± 6 | 422 ± 18 | 57.7 ± 3.0 | 0.8 ± 0.7 | 12259 ± 42 | – | – | – |
| BT-v1 (spec) | 640 ± 157 | 2088 ± 339 | 306.5 ± 45.4 | 16.5 ± 0.3 | 7344 ± 798 | – | – | – |
| BT-v2 (fixed) | 110 ± 2 | 268 ± 4 | 39.8 ± 1.6 | 0.0 ± 0.0 | 12417 ± 28 | – | – | – |

## S1: Peak surge: north corridor demand x1.8 for 20 min

| Controller | Avg delay (s) | 95th pct delay (s) | Max approach queue (blocks) | Spillbacks | Served vehicles | Clearance after incident (s) | Cleared runs | Excess queue (block·h) |
|---|---|---|---|---|---|---|---|---|
| Fixed-40 | 276 ± 5 | 893 ± 27 | 157.2 ± 8.5 | 5.2 ± 1.4 | 12489 ± 36 | 2995 ± 0 | 0% | 185.7 ± 8.0 |
| MaxPressure | 319 ± 61 | 964 ± 237 | 153.4 ± 37.1 | 19.1 ± 4.6 | 11896 ± 651 | 2995 ± 0 | 0% | 368.3 ± 141.9 |
| BT-v1 (spec) | 1284 ± 74 | 3462 ± 89 | 560.6 ± 19.0 | 16.6 ± 0.4 | 4555 ± 284 | 2621 ± 374 | 12% | 1570.6 ± 372.8 |
| BT-v2 (fixed) | 171 ± 8 | 495 ± 25 | 91.3 ± 4.0 | 6.8 ± 0.9 | 12957 ± 21 | 2660 ± 154 | 50% | 156.1 ± 19.1 |

## S2: Downstream blockage: east neighbour exits accept 5% for 15 min

| Controller | Avg delay (s) | 95th pct delay (s) | Max approach queue (blocks) | Spillbacks | Served vehicles | Clearance after incident (s) | Cleared runs | Excess queue (block·h) |
|---|---|---|---|---|---|---|---|---|
| Fixed-40 | 214 ± 4 | 505 ± 10 | 76.5 ± 4.6 | 2.9 ± 1.0 | 12123 ± 27 | 191 ± 66 | 100% | 22.3 ± 3.3 |
| MaxPressure | 170 ± 5 | 440 ± 14 | 56.2 ± 3.8 | 0.6 ± 0.3 | 12251 ± 38 | 1256 ± 500 | 75% | 38.8 ± 13.2 |
| BT-v1 (spec) | 658 ± 157 | 2041 ± 402 | 305.6 ± 56.8 | 14.4 ± 2.2 | 7586 ± 1021 | 171 ± 83 | 100% | 221.3 ± 154.2 |
| BT-v2 (fixed) | 119 ± 3 | 298 ± 9 | 38.8 ± 1.4 | 0.8 ± 0.2 | 12420 ± 18 | 784 ± 292 | 100% | 31.5 ± 2.9 |

## S3: Breakdown at chowrasta south approach (headways x2.2) for 15 min

| Controller | Avg delay (s) | 95th pct delay (s) | Max approach queue (blocks) | Spillbacks | Served vehicles | Clearance after incident (s) | Cleared runs | Excess queue (block·h) |
|---|---|---|---|---|---|---|---|---|
| Fixed-40 | 219 ± 4 | 536 ± 19 | 83.6 ± 4.4 | 5.0 ± 0.5 | 12102 ± 28 | 1839 ± 505 | 62% | 39.8 ± 7.7 |
| MaxPressure | 203 ± 6 | 541 ± 22 | 76.5 ± 1.4 | 10.8 ± 3.3 | 12119 ± 36 | 2779 ± 344 | 25% | 91.8 ± 18.9 |
| BT-v1 (spec) | 1030 ± 187 | 2789 ± 444 | 383.0 ± 56.3 | 14.9 ± 1.4 | 5700 ± 1106 | 2471 ± 539 | 25% | 1241.4 ± 374.3 |
| BT-v2 (fixed) | 122 ± 3 | 311 ± 7 | 53.3 ± 1.9 | 0.0 ± 0.0 | 12444 ± 23 | 1502 ± 338 | 88% | 36.8 ± 5.2 |

## S4: Stadium release: west corridor demand x2.6 for 10 min

| Controller | Avg delay (s) | 95th pct delay (s) | Max approach queue (blocks) | Spillbacks | Served vehicles | Clearance after incident (s) | Cleared runs | Excess queue (block·h) |
|---|---|---|---|---|---|---|---|---|
| Fixed-40 | 294 ± 11 | 988 ± 64 | 179.7 ± 10.1 | 6.6 ± 1.4 | 12471 ± 49 | 3595 ± 0 | 0% | 226.1 ± 26.8 |
| MaxPressure | 290 ± 9 | 856 ± 25 | 143.7 ± 6.3 | 25.5 ± 3.7 | 12496 ± 50 | 3595 ± 0 | 0% | 306.0 ± 30.1 |
| BT-v1 (spec) | 1370 ± 35 | 3706 ± 26 | 607.9 ± 10.1 | 16.1 ± 0.2 | 4230 ± 128 | 3162 ± 433 | 12% | 1754.0 ± 364.5 |
| BT-v2 (fixed) | 181 ± 7 | 555 ± 24 | 116.3 ± 5.6 | 9.2 ± 1.4 | 13018 ± 20 | 3181 ± 234 | 38% | 180.5 ± 15.2 |

## S5: Heavy-vehicle day: 25% buses/trucks all day

| Controller | Avg delay (s) | 95th pct delay (s) | Max approach queue (blocks) | Spillbacks | Served vehicles | Clearance after incident (s) | Cleared runs | Excess queue (block·h) |
|---|---|---|---|---|---|---|---|---|
| Fixed-40 | 331 ± 17 | 855 ± 73 | 169.6 ± 22.5 | 33.8 ± 2.5 | 10288 ± 137 | – | – | – |
| MaxPressure | 337 ± 35 | 976 ± 142 | 137.4 ± 31.4 | 40.6 ± 4.1 | 9861 ± 367 | – | – | – |
| BT-v1 (spec) | 1621 ± 96 | 3864 ± 134 | 636.7 ± 23.5 | 16.6 ± 0.4 | 2755 ± 283 | – | – | – |
| BT-v2 (fixed) | 208 ± 11 | 529 ± 33 | 77.3 ± 2.5 | 18.6 ± 5.8 | 10816 ± 53 | – | – | – |

## S6: Sensor faults at chowrasta: phantom spikes 10 min, then dead 5 min

| Controller | Avg delay (s) | 95th pct delay (s) | Max approach queue (blocks) | Spillbacks | Served vehicles | Clearance after incident (s) | Cleared runs | Excess queue (block·h) |
|---|---|---|---|---|---|---|---|---|
| Fixed-40 | 205 ± 4 | 471 ± 11 | 75.8 ± 4.8 | 2.2 ± 1.1 | 12142 ± 33 | 0 ± 0 | 100% | 0.0 ± 0.0 |
| MaxPressure | 148 ± 4 | 375 ± 10 | 54.8 ± 3.0 | 0.0 ± 0.0 | 12307 ± 24 | 361 ± 307 | 100% | 7.7 ± 3.8 |
| BT-v1 (spec) | 439 ± 92 | 1566 ± 302 | 229.7 ± 37.9 | 15.1 ± 2.2 | 8696 ± 769 | 185 ± 92 | 100% | 227.7 ± 173.6 |
| BT-v2 (fixed) | 112 ± 1 | 273 ± 3 | 46.9 ± 2.6 | 0.0 ± 0.0 | 12438 ± 30 | 922 ± 329 | 100% | 15.9 ± 1.7 |

## S7: Compound: north surge + east blockage together

| Controller | Avg delay (s) | 95th pct delay (s) | Max approach queue (blocks) | Spillbacks | Served vehicles | Clearance after incident (s) | Cleared runs | Excess queue (block·h) |
|---|---|---|---|---|---|---|---|---|
| Fixed-40 | 263 ± 5 | 736 ± 29 | 132.5 ± 9.3 | 10.0 ± 2.1 | 12425 ± 38 | 3211 ± 84 | 12% | 150.4 ± 8.0 |
| MaxPressure | 241 ± 6 | 651 ± 20 | 95.2 ± 7.1 | 13.4 ± 3.0 | 12461 ± 37 | 3054 ± 241 | 12% | 189.7 ± 16.7 |
| BT-v1 (spec) | 1282 ± 69 | 3462 ± 90 | 534.0 ± 19.5 | 17.5 ± 0.5 | 4518 ± 266 | 2883 ± 412 | 12% | 1544.0 ± 365.1 |
| BT-v2 (fixed) | 158 ± 5 | 448 ± 17 | 75.3 ± 4.1 | 3.4 ± 0.8 | 12855 ± 28 | 2444 ± 235 | 75% | 127.4 ± 11.7 |
