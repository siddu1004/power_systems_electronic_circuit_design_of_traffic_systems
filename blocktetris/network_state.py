"""Network state estimation and look-ahead transfer capability (Block-Tetris v4).

1. STATE ESTIMATOR (per-road Kalman filter, power-system style)
   State z_l = stored weight on road l (moving + queued). Charge conservation
   gives the process model directly from stop-line loop counts:

       z_l(k+1) = z_l(k) + c_in,l(k) - c_out,l(k) + w_l,   w ~ N(0, Q_l)
       Q_l = (eps_c^2)(c_in + c_out) + q_drift

   Cameras (only on part of the roads, noisy, some faulty) give
       y_l = z_l + v_l,  v ~ N(0, R)
   Update: nu = y - z^-, S = P^- + R, K = P^-/S. Bad-data test (chi-square, 1 dof):
   nu^2/S > 9 -> reading rejected (stuck / phantom camera). If a road rejects
   60 readings in a row, the filter re-initialises from the camera with
   inflated variance (count-drift recovery).

2. LOOK-AHEAD TRANSFER CAPABILITY (ATC, depth D levels, horizon H)
   mu_l      learned service current of road l (EMA of measured outflow while queued)
   f_{u,k}   predicted flow of road u into its exit e_k = r_k * min(mu_u, lam_u + z_u/H)
   F_e       sum of predicted flows into road e
   A_e^(0)   = mu_e + max(0, 0.9 C_e - z_e)/H                      acceptance rate
   C_u^(d)   = min( mu_u , min_k  (f_{u,k}/F_{e_k}) A_{e_k}^(d-1) / r_k )
               (fixed turn proportions => head-of-line coupling => min over exits)
   A_u^(d)   = C_u^(d) + max(0, 0.9 C_u - z_u)/H
   phi_e     = clip(A_e^(D) / F_e, phi_min, 1)                       inflow throttle
   Time to spill-back  tau_e = (0.95 C_e - z_e)/(F_e - C_e^(D))  if F_e > C_e^(D)
   Early warning when tau_e < H_warn.

   Because A^(D) looks D roads downstream, a restriction 2-3 hops away slows
   the inflow here before the queue reaches this road (inflow checking).
"""
import numpy as np

from .geometry import MOVES


class NetState:
    def __init__(self, sim, mode="kf", coverage=0.5, sigma=3.0, count_noise=0.05,
                 stuck=2, phantom_p=0.002, seed=99, H=120.0, depth=3, phi_min=0.1,
                 warn_H=180.0):
        n = sim.n
        self.sim, self.n, self.mode = sim, n, mode
        rng = np.random.default_rng(seed)
        self.rng = rng
        self.cover = rng.random(n.L) < coverage
        self.cover[n.gates] = True                          # gate roads always watched
        cand = np.where(self.cover & (n.kind == "inner"))[0]
        self.stuck_lines = list(rng.choice(cand, size=min(stuck, len(cand)), replace=False)) if len(cand) else []
        self.stuck_val = {}
        self.sigma, self.cn, self.php = sigma, count_noise, phantom_p
        self.z = np.zeros(n.L)
        self.P = np.full(n.L, 1.0)
        self.R = sigma ** 2
        self.reject_run = np.zeros(n.L, int)
        self.rejects = 0
        self.H, self.D, self.phi_min, self.warn_H = H, depth, phi_min, warn_H
        self.mu = np.full(n.L, 0.3)
        self.mu[n.sinks] = 0.5
        self.lam = np.zeros(n.L)
        self.phi = np.ones(n.L)
        self.tau = np.full(n.L, np.inf)
        self.warn = np.zeros(n.L, bool)
        self.Cd = np.zeros(n.L)
        self.A = np.ones(n.L)
        self.load_pred = np.zeros(n.L)
        self.exits = -np.ones((n.L, 4), int)
        for l in range(n.L):
            j, a = n.dst[l]
            if j >= 0:
                for k in range(4):
                    self.exits[l, k] = n.out_line[j, MOVES[a * 4 + k][2]]
        self.has = np.where(self.exits[:, 0] >= 0)[0]

    # ── 1. estimator ─────────────────────────────────────────────────────────
    def update(self, t, occ_true, c_in, c_out):
        n, rng, sim = self.n, self.rng, self.sim
        ci = np.maximum(0.0, c_in * (1 + self.cn * rng.normal(size=n.L)))
        co = np.maximum(0.0, c_out * (1 + self.cn * rng.normal(size=n.L)))
        queued = np.zeros(n.L, bool)
        hm = n.line_moves[:, 0] >= 0
        queued[hm] = sim.V[n.line_moves[hm]].sum(1) + sim.entry[hm] > 1.0
        queued[n.sinks] = sim.entry[n.sinks] > 0.5
        self.mu = np.where(queued, self.mu + 0.01 * (co - self.mu), self.mu)
        self.lam += 0.01 * (ci - self.lam)
        y = occ_true + self.sigma * rng.normal(size=n.L)
        for l in self.stuck_lines:                          # camera freezes at t = 600 s
            if t >= 600:
                self.stuck_val.setdefault(l, y[l])
                y[l] = self.stuck_val[l]
        y[rng.random(n.L) < self.php] += 25.0               # phantom ghost queues
        y = np.clip(y, 0, None)
        if self.mode == "oracle":
            self.z = occ_true.copy()
            return self.z
        if self.mode == "raw":
            self.z = np.where(self.cover, y, np.clip(self.z + ci - co, 0, n.cap0))
            return self.z
        zp = self.z + ci - co
        Pp = self.P + (self.cn ** 2) * (ci + co) + 0.01
        nu = y - zp
        S = Pp + self.R
        ok = self.cover & (nu ** 2 / S <= 9.0)
        rej = self.cover & ~ok
        self.rejects += int(rej.sum())
        self.reject_run = np.where(rej, self.reject_run + 1, 0)
        reset = self.reject_run >= 60
        K = np.where(ok, Pp / S, 0.0)
        z = zp + K * nu
        P = (1 - K) * Pp
        z = np.where(reset, y, z)
        P = np.where(reset, 4 * self.R, P)
        self.reject_run[reset] = 0
        self.z = np.clip(z, 0, n.cap0)
        self.P = P
        return self.z

    # ── 2. look-ahead transfer capability ────────────────────────────────────
    def atc(self, ratio, gate_q):
        n, H = self.n, self.H
        z, mu = self.z, self.mu
        head = np.maximum(0.0, 0.9 * n.cap0 - z) / H
        dem = np.minimum(np.maximum(mu, 0.05), self.lam + (z + gate_q) / H)
        f = ratio * dem[:, None]
        F = np.zeros(n.L)
        ex = self.exits[self.has]
        np.add.at(F, ex.ravel(), f[self.has].ravel())
        A = mu + head
        C = mu.copy()
        rr = ratio[self.has]
        fr = f[self.has]
        for _ in range(self.D):
            Fe = F[ex]
            share = np.where(Fe > 1e-9, fr / np.maximum(Fe, 1e-9), 1.0)
            lim = np.where(rr > 1e-9, share * A[ex] / np.maximum(rr, 1e-9), np.inf)
            C[self.has] = np.minimum(mu[self.has], lim.min(1))
            A = A.copy()
            A[self.has] = C[self.has] + head[self.has]
        self.Cd = C
        self.A = A
        self.phi = np.where(F > 1e-6, np.clip(A / np.maximum(F, 1e-9), self.phi_min, 1.0), 1.0)
        self.F = F
        # predicted load H seconds ahead (charge conservation with predicted in/out currents)
        self.load_pred = np.clip((z + H * (F - C)) / n.cap0, 0.0, 1.5)
        grow = F - C
        self.tau = np.where(grow > 1e-4, np.maximum(0.0, 0.95 * n.cap0 - z) / np.maximum(grow, 1e-9), np.inf)
        self.warn = self.tau < self.warn_H
        return self.phi


# ── v6: CCTV + Google Maps measurement model (added; `update` above is unchanged) ──
def update_v6(self, t, c_in, c_out, cctv_q, cctv_sat, has_cam, view_W, gm_T, D, gm_queue=False):
    """Kalman update with the inputs that exist on real Indian roads.

    Process (unchanged): z+ = z + c_in - c_out, counts from CCTV counting lines.
    Moving blocks on a road are estimated as transit = lam * D (falling blocks);
    the stack (landed blocks) is z - transit.

    Measurement 1, CCTV (junction camera, sees ~view_W of each approach):
        stack visible and short   ->  y = q_vis + transit,   R = (0.08 q + 0.5)^2 + (0.3 transit)^2
        stack runs out of view    ->  inequality  z >= view_W + 0.5 transit
    Measurement 2, Google Maps travel time T (lagged, every road):
        Little's law on the stack:  q_g = max(0, T - D) * (time-averaged discharge)
        y = q_g + transit,          R = (0.5 q_g + 3)^2 + (0.3 transit)^2
    Each scalar update passes the chi-square bad-data test (nu^2/S <= 9).
    """
    n, rng, sim = self.n, self.rng, self.sim
    ci = np.maximum(0.0, c_in * (1 + self.cn * rng.normal(size=n.L)))
    co = np.maximum(0.0, c_out * (1 + self.cn * rng.normal(size=n.L)))
    queued = np.zeros(n.L, bool)
    hm = n.line_moves[:, 0] >= 0
    queued[hm] = sim.Vo[n.line_moves[hm]].sum(1) + sim.Eo[hm] > 1.0
    queued[n.sinks] = sim.entry[n.sinks] > 0.5
    self.mu = np.where(queued, self.mu + 0.01 * (co - self.mu), self.mu)
    self.lam += 0.01 * (ci - self.lam)
    if not hasattr(self, "out_avg"):
        self.out_avg = np.full(n.L, 0.1)
    self.out_avg += (co - self.out_avg) / 60.0          # time-averaged discharge (Little's law)
    transit = np.clip(self.lam * D, 0, n.cap0)
    self.transit = transit
    z = self.z + ci - co
    P = self.P + (self.cn ** 2) * (ci + co) + 0.01

    def fuse(z, P, y, R, mask):
        nu = y - z
        S = P + R
        ok = mask & (nu ** 2 / S <= 9.0)
        self.rejects += int((mask & ~ok).sum())
        K = np.where(ok, P / S, 0.0)
        return z + K * nu, (1 - K) * P

    # CCTV
    m1 = has_cam & ~cctv_sat
    y1 = cctv_q + transit
    R1 = (0.08 * cctv_q + 0.5) ** 2 + (0.3 * transit) ** 2
    z, P = fuse(z, P, y1, R1, m1)
    # Google Maps as a quantity (Little's law). Tested: correlation with the true
    # stack only ~0.3 under signal cycling and 3-min lag -> made control worse.
    # Kept as an option (gm_queue=True); the default uses Google as a flag below.
    if gm_T is not None and gm_queue:
        qg = np.maximum(0.0, gm_T - D) * np.maximum(self.out_avg, 0.02)
        y2 = qg + transit
        R2 = (0.5 * qg + 3.0) ** 2 + (0.3 * transit) ** 2   # lagged, coarse
        z, P = fuse(z, P, y2, R2, np.ones(n.L, bool))
    # CCTV saturated: the stack is at least as long as the view
    lb = np.where(has_cam & cctv_sat, view_W + 0.5 * transit, 0.0)
    if gm_T is not None:
        # Google congestion flag: travel time > free-flow + 60 s means the stack
        # reaches beyond any camera's view (works on roads with no camera too)
        # applied only where no working camera watches the road: tested on all roads,
        # it over-holds traffic where CCTV already sees the stack
        flag = (gm_T > D + 60.0) & ~has_cam & (n.kind == "inner")
        lb = np.where(flag, np.maximum(lb, view_W + 0.5 * transit), lb)
    z = np.maximum(z, lb)
    self.z = np.clip(z, 0, n.cap0)
    self.P = P
    return self.z


NetState.update_v6 = update_v6
