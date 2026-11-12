# Ablation: v2 with ONE fix reverted to the spec (4 seeds, avg delay s)

| Variant | S0 | S7 | S6 |
|---|---|---|---|
| BT-v2 (fixed) | 108 ± 3 | 162 ± 8 | 111 ± 2 |
| v2 without hol_aware | 125 ± 8 | 648 ± 103 | 123 ± 5 |
| v2 without rolling | 243 ± 47 | 564 ± 82 | 364 ± 94 |
| v2 without partial_exit | 108 ± 3 | 226 ± 28 | 113 ± 3 |
| v2 without max_wait_guard | 104 ± 2 | 137 ± 5 | 104 ± 2 |
| v2 without clean_samples | 118 ± 3 | 160 ± 6 | 119 ± 1 |
| v2 without tau_per_class | 117 ± 5 | 185 ± 7 | 114 ± 1 |
| v2 without arrivals_in_green | 112 ± 4 | 158 ± 9 | 112 ± 3 |
| v2 without smart_early_end | 118 ± 2 | 170 ± 17 | 116 ± 3 |
| v2 without switch_cost | 108 ± 3 | 163 ± 8 | 111 ± 2 |
| v2 without hysteresis | 108 ± 3 | 164 ± 8 | 111 ± 2 |
| v2 without sanity_persist | 108 ± 3 | 162 ± 8 | 112 ± 2 |
| BT-v1 (spec) | 872 ± 252 | 1405 ± 68 | 475 ± 104 |
