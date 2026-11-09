# End Matter and Declarations

## Data and Code Availability Statement
All source code, baseline simulation models, Simscape physical circuit files (`SITRA_S5_Physical.slx`), test scripts, and raw experimental data CSV/MAT files supporting the findings of this study are publicly available in the project GitHub repository:
- **Repository URL:** `https://github.com/siddu1004/power_systems_electronic_circuit_design_of_traffic_systems`
- **Git Branch:** `sai_dev`
- **Commit Hash:** `af5d84650ec60ca53e6b8d7c63a4122b862dc018`
- **Working Flat Scaffold:** `SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/`

The complete benchmark execution can be reproduced end-to-end in MATLAB/Simulink R2024b by executing `run_master_all.m`.

## Author Contributions (CRediT Statement)
- **Sai [Author 1]:** Conceptualization, Methodology, Software (SITRA MPC, Simscape Physical Circuit, Fault Injector), Formal Analysis, Investigation, Writing – Original Draft, Visualization, Project Administration.
- **[Author 2 Placeholder]:** Validation, Resources, Writing – Review & Editing, Supervision.

## Acknowledgments
The authors express their gratitude to the Department of Electrical and Electronics Engineering for providing computational laboratory facilities and MathWorks Simscape simulation licenses supporting this research.

## Declaration of Competing Interests
The authors declare that they have no known competing financial interests or personal relationships that could have appeared to influence the work reported in this paper.

## Declaration of Generative AI and AI-Assisted Technologies
During the preparation of this work, the author(s) utilized AI-assisted coding tools (specifically Google DeepMind Antigravity) for automated script formatting, figure compilation, and syntax verification within the local simulation workspace. After utilizing these tools, the author(s) reviewed and edited the content thoroughly and take full responsibility for the integrity and accuracy of the scientific publication.

---

# References

[1] F. V. Webster, "Traffic signal settings," Road Research Technical Paper No. 39, Road Research Laboratory, Her Majesty's Stationery Office (HMSO), London, UK, 1958.

[2] A. G. Sims and K. W. Dobinson, "The Sydney coordinated adaptive traffic (SCAT) system philosophy and benefits," *IEEE Transactions on Vehicular Technology*, vol. 29, no. 2, pp. 130–137, May 1980, doi: 10.1109/T-VT.1980.23833.

[3] P. B. Hunt, D. I. Robertson, R. D. Bretherton, and R. I. Winton, "SCOOT – a traffic responsive method of coordinating signals," Transport and Road Research Laboratory (TRRL) Report LR1014, Crowthorne, Berkshire, UK, 1981.

[4] C. F. Daganzo, "The cell transmission model: A dynamic representation of highway traffic consistent with the hydrodynamic theory," *Transportation Research Part B: Methodological*, vol. 28, no. 4, pp. 269–287, Aug. 1994, doi: 10.1016/0191-2615(94)90002-7.

[5] M. Papageorgiou, C. Diakaki, V. Dinopoulou, A. Kotsialos, and Y. Wang, "Review of road traffic control strategies," *Proceedings of the IEEE*, vol. 91, no. 12, pp. 2043–2067, Dec. 2003, doi: 10.1109/JPROC.2003.819610.

[6] K. Aboudolas, M. Papageorgiou, and E. Kosmatopoulos, "Store-and-forward based methods for the signal control problem in large-scale congested urban road networks," *Transportation Research Part C: Emerging Technologies*, vol. 17, no. 2, pp. 163–174, Apr. 2009, doi: 10.1016/j.trc.2008.10.002.

[7] P. Varaiya, "Max pressure control of a network of signalized intersections," *Transportation Research Part C: Emerging Technologies*, vol. 36, pp. 177–195, Nov. 2013, doi: 10.1016/j.trc.2013.08.014.

[8] Transportation Research Board, *Highway Capacity Manual: A Guide for Multimodal Mobility Analysis (HCM)*, 7th ed., Washington, DC: The National Academies Press, 2022.

[9] Indian Roads Congress, "Guidelines on Design and Installation of Road Traffic Signals," IRC:93-1985, New Delhi: Indian Roads Congress, 1985 (reaffirmed 2019).

[10] H. Wei, G. Zheng, V. Gayah, and Z. Li, "A survey on traffic signal control methods," *arXiv preprint arXiv:1904.08117*, Apr. 2019.

[11] B.-L. Ye, W. Wu, K. Mao, and L. Shen, "A survey of model predictive control methods for traffic signal control," *IEEE/CAA Journal of Automatica Sinica*, vol. 6, no. 3, pp. 623–640, May 2019, doi: 10.1109/JAS.2019.1911471.

[12] A. Haydari and Y. Yılmaz, "A critical review of traffic signal control and a novel unified view of reinforcement learning and model predictive control approaches for adaptive traffic signal control," *arXiv preprint arXiv:2211.14426*, Nov. 2022.

[13] H. Liu, V. V. Gayah, and M. W. Levin, "A max pressure algorithm for traffic signals considering pedestrian queues," *Transportation Research Part C: Emerging Technologies*, vol. 169, art. 104865, Dec. 2024, doi: 10.1016/j.trc.2024.104865.

[14] T. Xu, S. Barman, and M. W. Levin, "Smoothing-MP: A novel max-pressure signal control considering signal coordination to smooth traffic in urban networks," *Transportation Research Part C: Emerging Technologies*, vol. 166, art. 104760, Sep. 2024, doi: 10.1016/j.trc.2024.104760.

[15] F. Zhou, X. Zheng, and Y. Wang, "Distributed stochastic MPC traffic signal control for urban networks," *IEEE Transactions on Intelligent Transportation Systems*, vol. 24, no. 8, pp. 8079–8096, Aug. 2023, doi: 10.1109/TITS.2023.3262580.

[16] S. Di Cairano and M. E. R. Tseng, "Model predictive control for urban traffic signals with stability guarantees," in *Proceedings of the SIAM Conference on Control and Its Applications (CT23)*, Philadelphia, PA, 2023, pp. 64–71, doi: 10.1137/1.9781611977776.9.

[17] J. Park, T. Liu, C. Wang, H. Wang, Q. Wang, and Z. P. Jiang, "Traffic signal control for large-scale urban traffic networks: Real-world experiments using vision-based sensors," in *Proceedings of the 18th IEEE International Conference on Control & Automation (ICCA)*, Reykjavik, Iceland, 2024, pp. 282–287, doi: 10.1109/ICCA62789.2024.10591878.

[18] T. Le, H. L. Vu, Y. Nazarathy, B. Vo, and S. T. Hoogendoorn, "Linear-quadratic model-predictive control for urban traffic networks," *Transportation Research Part C: Emerging Technologies*, vol. 36, pp. 498–512, Nov. 2013, doi: 10.1016/j.trc.2013.07.009.

[19] H. Wei, C. Chen, G. Zheng, K. Wu, V. Gayah, K. Xu, and Z. Li, "PressLight: Learning max pressure control to coordinate traffic signals in arterial network," in *Proceedings of the 25th ACM SIGKDD International Conference on Knowledge Discovery & Data Mining (KDD '19)*, Anchorage, AK, 2019, pp. 1290–1298, doi: 10.1145/3292500.3330949.

[20] L. Zhang, Q. Yang, T. Zhang, and B. Du, "Expression might be enough: Representing pressure and demand for reinforcement learning based traffic signal control," in *Proceedings of the 39th International Conference on Machine Learning (ICML)*, PMLR vol. 162, 2022, pp. 26176–26189.

[21] Y. Liu, C. Chen, X. Zheng, and Z. Li, "GPLight: Grouped multi-agent reinforcement learning for large-scale traffic signal control," in *Proceedings of the 32nd International Joint Conference on Artificial Intelligence (IJCAI '23)*, Macau, 2023, pp. 199–207, doi: 10.24963/ijcai.2023/23.

[22] H. Wei, N. Xu, H. Zhang, G. Zheng, X. Zang, C. Chen, M. Zhang, W. Xiang, V. G. Gayah, and Z. Li, "CoLight: Learning network-level cooperation for traffic signal control," in *Proceedings of the 28th ACM International Conference on Information and Knowledge Management (CIKM '19)*, Beijing, China, 2019, pp. 1913–1922, doi: 10.1145/3357384.3357902.

[23] C. Chen, H. Wei, N. Xu, G. Zheng, M. Yang, Y. Xiong, K. Xu, and Z. Li, "Toward a thousand lights: Decentralized deep reinforcement learning for large-scale traffic signal control," in *Proceedings of the 34th AAAI Conference on Artificial Intelligence (AAAI '20)*, vol. 34, no. 04, 2020, pp. 3414–3421, doi: 10.1609/aaai.v34i04.5744.

[24] J. Moyalan, R. de Castro, S. Feng, X. Tang, X. Lin, and S. Moura, "Optimal control of emergency evacuations leveraging equivalent circuit models," *ASME Letters in Dynamic Systems and Control*, vol. 5, no. 1, art. 011002, Jan. 2025, doi: 10.1115/1.4067332.

[25] A. V. Tolmachev, E. V. Sinitsyn, and D. A. Brusyanin, "Transport system modelling based on analogies between road networks and electrical circuits," *R-Economy*, vol. 5, no. 2, pp. 92–104, Jun. 2019, doi: 10.15826/recon.2019.5.2.010.

[26] G. A. Mendes, L. R. da Silva, and H. J. Herrmann, "Traffic gridlock on complex networks," *Physica A: Statistical Mechanics and its Applications*, vol. 391, no. 1–2, pp. 362–370, Jan. 2012, doi: 10.1016/j.physa.2011.07.046.

[27] National Institute of Urban Affairs (NIUA), "Best practices for traffic signal operations in India," SmartNet Urban Infrastructure Manual, Ministry of Housing and Urban Affairs, Government of India, New Delhi, 2021.

[28] Indian Infrastructure, "Smart mobility: A case study of the Bengaluru Adaptive Traffic Control System (BATCS)," *Indian Infrastructure Magazine*, Tech. Rep. II-TR-2026-04, New Delhi, Apr. 2026.

[29] J. G. Kassakian, M. F. Schlecht, and G. C. Verghese, *Principles of Power Electronics*, Boston, MA: Addison-Wesley Publishing Company, 1991.

[30] R. W. Erickson and D. Maksimovic, *Fundamentals of Power Electronics*, 3rd ed., Cham, Switzerland: Springer Nature, 2020, doi: 10.1007/978-3-030-43881-4.
