"""Control layer: sensors, the network pressure bus, and four controllers.

* FixedTime     – plain 40 s split phasing (the baseline to beat)
* MaxPressure   – Varaiya-style back-pressure, a strong published benchmark
* BlockTetris   – the Block-Tetris algorithm. With params.V1 it is the spec as
                  literally written; with params.V2 every hole found is fixed.

Electrical reading:
  bottle level V (sum of block weights) ......... capacitor voltage
  green phase ................................... MOSFET gate ON
  amber + all-red ............................... dead-time / break-before-make
  link loading = occupancy / capacity ........... line thermal loading
  pressure alarm with per-hop attenuation ....... protective relay + under-voltage load shedding
  ramped recovery ............................... soft-start / slew-rate limiter
  alarm hysteresis (v2) ......................... Schmitt trigger
  sanity filter ................................. surge arrester / plausibility check
  fixed-time fallback ........................... backup supply (UPS)
  max-wait guard (v2) ........................... watchdog timer
  exit room check ............................... interlock: never close onto a dead line
"""
import math
from collections import deque

import numpy as np

from . import params as P
from .geometry import PHASES, SPLIT_PHASES, TURNS, MOVES

# ─────────────────────────────────────────────────────────────────────────────
# Sensors
# ─────────────────────────────────────────────────────────────────────────────


class Sensor:
    """Camera per junction. Modes: ok | noisy (phantom spikes) | dead."""

    def __init__(self, junction, rng):
        self.j = junction
        self.rng = rng
        self.mode = "ok"
        self.phantom = [0.0] * 16   # remaining seconds of a ghost detection
        self.phantom_m = [0.0] * 16

    def tick(self):
        if self.mode != "noisy":
            self.phantom = [0.0] * 16
            return
        for i in range(16):
            if self.phantom[i] > 0:
                self.phantom[i] -= 1
            elif self.rng.random() < 0.01:
                self.phantom[i] = float(self.rng.integers(1, 11))
                self.phantom_m[i] = float(self.rng.uniform(120, 300))

    def _entry_owner(self, i):
        """Vehicles in the shared entry section are physically stuck behind the
        head vehicle, so they all wait on the head vehicle's movement."""
        e = self.j.entry[MOVES[i][0]]
        return bool(e) and e[0].turn == i % 4

    def length(self, i, hol=False):
        """Aggregate queue length in metres for movement i (None if dead).
        hol=False: by turn intent (spec). hol=True: by what actually blocks."""
        if self.mode == "dead":
            return None
        j = self.j
        if hol:
            arm = MOVES[i][0]
            val = j.moves[i].q_len_m + (sum(j.entry_len[arm * 4:arm * 4 + 4]) if self._entry_owner(i) else 0.0)
        else:
            val = j.moves[i].q_len_m + j.entry_len[i]
        if self.phantom[i] > 0:
            val += self.phantom_m[i]
        return val

    def vehicles(self, i, t, hol=False):
        """Full per-vehicle view: (cls, w, length, t_join, prio) list, head first."""
        if self.mode == "dead":
            return None
        j = self.j
        out = [(v.cls, v.w, v.length, v.t_join, v.prio) for v in j.moves[i].queue]
        arm = MOVES[i][0]
        if hol:
            if self._entry_owner(i):
                out += [(v.cls, v.w, v.length, v.t_join, v.prio) for v in j.entry[arm]]
        else:
            out += [(v.cls, v.w, v.length, v.t_join, v.prio) for v in j.entry[arm]
                    if v.turn == i % 4]
        if self.phantom[i] > 0:
            n = int(self.phantom_m[i] / 5.5)
            out += [(P.CAR, 0.4, 5.5, t, 0)] * n
        return out


# ─────────────────────────────────────────────────────────────────────────────
# Network layer: pressure alarms between junction agents
# ─────────────────────────────────────────────────────────────────────────────


class PressureBus:
    """Per-link pressure in [0,1]. Local alarm from loading, plus an attenuated
    copy of the downstream junction's worst outgoing pressure (one hop per step).
    Recovery is slew-limited (ramp) so taps reopen gradually."""

    def __init__(self, net, prm):
        self.net = net
        self.prm = prm
        self.p = [0.0] * len(net.links)
        self.latched = [False] * len(net.links)
        self.alarms = 0

    def update(self):
        prm = self.prm
        prev = self.p
        new = [0.0] * len(prev)
        for lk in self.net.links:
            L = lk.loading
            i = lk.lid
            if L >= prm.alarm_on and not self.latched[i]:
                self.latched[i] = True
                self.alarms += 1
            elif L < prm.alarm_off:
                self.latched[i] = False
            local = 0.0
            if self.latched[i]:
                lo = prm.alarm_off if prm.hysteresis else prm.alarm_on
                local = min(1.0, max(0.15 if prm.hysteresis else 0.0, (L - lo) / (1.0 - lo)))
            prop = 0.0
            if lk.dst[0] == "J":
                jd = self.net.junctions[lk.dst[1]]
                back_arm = lk.dst[2]
                prop = prm.attenuation * max(
                    prev[o.lid] for a, o in enumerate(jd.out_links) if a != back_arm)
            target = max(local, prop)
            new[i] = target if target >= prev[i] else max(target, prev[i] - prm.ramp)
        self.p = new


# ─────────────────────────────────────────────────────────────────────────────
# Controllers
# ─────────────────────────────────────────────────────────────────────────────


class Controller:
    name = "base"

    def __init__(self, junction, sensor=None, bus=None):
        self.j = junction
        self.sensor = sensor
        self.bus = bus

    def observe(self, t):
        pass

    def first_phase(self, t):
        return SPLIT_PHASES[0]

    def on_green(self, t, phase):
        pass

    def wants_end(self, t, elapsed):
        return False

    def choose(self, t, current, forced):
        raise NotImplementedError


class FixedTime(Controller):
    name = "Fixed-40"

    def __init__(self, junction, sensor=None, bus=None, green=40.0):
        super().__init__(junction, sensor, bus)
        self.green = green
        self.k = 0

    def first_phase(self, t):
        self.k = 0
        return SPLIT_PHASES[0]

    def wants_end(self, t, elapsed):
        return elapsed >= self.green

    def choose(self, t, current, forced):
        self.k = (self.k + 1) % 4
        return SPLIT_PHASES[self.k]


class MaxPressure(Controller):
    """w_m = (q_m - 0.25 * occupancy(exit)) * lanes ; pick the phase with the
    largest summed pressure, re-evaluated every second after minimum green."""

    name = "MaxPressure"

    def __init__(self, junction, sensor, bus=None):
        super().__init__(junction, sensor, bus)
        self.fallback = FixedTime(junction)
        self.dead_s = 0

    def observe(self, t):
        self.dead_s = self.dead_s + 1 if self.sensor.length(0) is None else 0

    def _scores(self):
        w = []
        for m in self.j.moves:
            q = self.sensor.length(m.idx, hol=True)
            if q is None:  # blind for < 3 s: hold, fallback takes over after
                return [0.0] * 16
            w.append(max(0.0, (q - 0.25 * m.exit_link.occ / m.exit_link.lanes)) * m.lanes
                     if m.exit_link.room(5.5) else 0.0)
        return w

    def wants_end(self, t, elapsed):
        if self.dead_s >= 3:
            return self.fallback.wants_end(t, elapsed)
        if self.dead_s > 0:
            return self.fallback.wants_end(t, elapsed)
        w = self._scores()
        cur = sum(w[m] for m in self.j.green)
        best = max(sum(w[m] for m in ph) for ph in PHASES)
        return best > 1.1 * cur + 10.0

    def choose(self, t, current, forced):
        if self.dead_s >= 3:
            return self.fallback.choose(t, current, forced)
        w = self._scores()
        cands = [ph for ph in PHASES if not (forced and ph == current)]
        return max(cands, key=lambda ph: sum(w[m] for m in ph))


def block_class(counts, W):
    if counts[P.HEAVY]:
        return 2
    if W > 0 and (0.2 * counts[0] + 0.3 * counts[1]) / W >= 0.6:
        return 0
    return 1


def make_blocks(vehicles, block_len):
    """Group a head-first vehicle list into road blocks.
    Returns list of [W, length, cls, oldest_t_join, prio_sum]."""
    blocks = []
    W = ln = pr = 0.0
    counts = [0, 0, 0, 0]
    tmin = math.inf
    for cls, w, length, tj, prio in vehicles:
        W += w
        ln += length
        pr += prio
        counts[cls] += 1
        tmin = min(tmin, tj)
        if ln >= block_len:
            blocks.append([W, ln, block_class(counts, W), tmin, pr])
            W = ln = pr = 0.0
            counts = [0, 0, 0, 0]
            tmin = math.inf
    if ln > 0:
        blocks.append([W, ln, block_class(counts, W), tmin, pr])
    return blocks


class Learner:
    """Learns tau (s per weight unit), start-up loss L and per-class sigma from
    stop-line crossings, block by block, with EMA smoothing and a sliding window."""

    def __init__(self, prm):
        self.prm = prm
        self.tau = [prm.tau0] * 3
        self.fturn = {k: 1.0 for k in TURNS}
        self.L = prm.L0
        self.resid = [deque(maxlen=prm.window) for _ in range(3)]
        self.n = 0
        self.acc = {}  # move -> [W, len, counts, t_ref, first, tainted]

    def tau_of(self, c, turn):
        if self.prm.tau_per_class:
            return self.tau[c] * self.fturn[turn]
        return self.tau[0]

    def sigma(self, c):
        r = self.resid[c if self.prm.tau_per_class else 0]
        if len(r) < 5:
            return 1.0
        return max(0.3, float(np.std(r)))

    def green_start(self, t, moves):
        for m in moves:
            self.acc[m] = [0.0, 0.0, [0, 0, 0, 0], t, True, False]

    def crossing(self, tc, m, v, lanes, turn, starved, blocked):
        a = self.acc.get(m)
        if a is None:
            return
        a[0] += v.w
        a[1] += v.length
        a[2][v.cls] += 1
        if self.prm.clean_samples and (starved or blocked):
            a[5] = True
        if a[1] < self.prm.block_len:
            return
        W, _, counts, t_ref, first, tainted = a
        self.acc[m] = [0.0, 0.0, [0, 0, 0, 0], tc, False, False]
        if tainted:
            return
        d = tc - t_ref
        c = block_class(counts, W)
        k = c if self.prm.tau_per_class else 0
        e = self.prm.ema
        pred = W * self.tau_of(c, turn)
        if first:
            Ls = d - pred / lanes
            if 0.0 <= Ls <= 8.0:
                self.L += e * (Ls - self.L)
            return
        meas = d * lanes
        if meas <= 0 or meas > 60:
            return
        self.resid[k].append(meas - pred)
        if self.prm.tau_per_class:
            if turn == "S":
                self.tau[c] += e * (meas / (W * self.fturn[turn]) - self.tau[c])
            else:
                self.fturn[turn] += 0.5 * e * (meas / (W * self.tau[c]) - self.fturn[turn])
        else:
            self.tau[0] += e * (meas / W - self.tau[0])
        self.n += 1


class BlockTetris(Controller):
    name = "BlockTetris"

    def __init__(self, junction, sensor, bus, prm):
        super().__init__(junction, sensor, bus)
        self.prm = prm
        self.learn = Learner(prm)
        self.fallback = FixedTime(junction)
        self.in_fallback = False
        self.dead_s = 0
        self.planned = prm.g_base
        self.cross_t = deque(maxlen=12)
        self.g_start = 0.0
        self.lam = [0.0] * 16           # EMA arrival weight rate per movement
        self.share = [[0.25] * 4 for _ in range(4)]
        # sanity filter state
        self.good = [0.0] * 16
        self.last_raw = [0.0] * 16
        self.t_good = [0.0] * 16
        self.persist = [0] * 16
        self.rejected = 0
        self.blocked_run = 0
        self.decisions = 0

    # ── sensing ────────────────────────────────────────────────────────────
    def observe(self, t):
        j = self.j
        if self.sensor.length(0) is None:
            self.dead_s += 1
            if self.dead_s >= 3:
                self.in_fallback = True
        else:
            self.dead_s = 0
            self.in_fallback = False
            self._sanity(t)
        # learning from stop-line events
        for tc, m, v, starved, blocked in j.events:
            mv = j.moves[m]
            self.learn.crossing(tc, m, v, mv.lanes, mv.turn, starved, blocked)
            self.cross_t.append(tc)
        j.events.clear()
        # arrivals: rates and turn shares (EMA)
        inc = [0.0] * 16
        for _, m, v in j.joins:
            inc[m] += v.w
            a, ti = m // 4, m % 4
            sh = self.share[a]
            for k in range(4):
                sh[k] += 0.01 * ((1.0 if k == ti else 0.0) - sh[k])
        j.joins.clear()
        for m in range(16):
            self.lam[m] += 0.01 * (inc[m] - self.lam[m])
        # exit blocked tracking for the current phase
        if any(j.moves[m].was_blocked or not j.moves[m].exit_link.room(5.5)
               for m in j.green if j.moves[m].queue):
            self.blocked_run += 1
        else:
            self.blocked_run = 0

    def _sanity(self, t):
        """Plausibility check on each lane's physical reading (by intent)."""
        for i in range(16):
            raw = self.sensor.length(i)
            if self.prm.sanity_persist:
                ref, dt = self.good[i], t - self.t_good[i]
            else:
                ref, dt = self.last_raw[i], 1.0
            ok = -40.0 - 15.0 * dt <= raw - ref <= 25.0 + 10.0 * dt
            if not ok and self.prm.sanity_persist:
                if abs(raw - self.last_raw[i]) <= 25.0:
                    self.persist[i] += 1
                else:
                    self.persist[i] = 0
                if self.persist[i] >= 4:
                    ok = True
            if ok:
                self.good[i] = raw
                self.t_good[i] = t
                self.persist[i] = 0
            else:
                self.rejected += 1
            self.last_raw[i] = raw

    def _trusted_vehicles(self, i, t):
        """Vehicle list consistent with the last *accepted* reading. If the
        current reading was rejected, fall back to the last good estimate by
        trimming the implausible excess from the tail."""
        veh = self.sensor.vehicles(i, t, hol=self.prm.hol_aware)
        if veh is None:
            return []
        excess = self.last_raw[i] - self.good[i]
        while veh and excess > 1.0:
            excess -= veh[-1][2]
            veh = veh[:-1]
        return veh

    # ── estimation ─────────────────────────────────────────────────────────
    def _pressure(self, m):
        return self.bus.p[self.j.moves[m].exit_link.lid] if self.bus else 0.0

    def _movement_eval(self, t):
        """Per movement: (score, T_discharge, eligible, oldest_age)."""
        prm = self.prm
        out = []
        for mv in self.j.moves:
            veh = self._trusted_vehicles(mv.idx, t)
            if not veh:
                out.append((0.0, 0.0, False, 0.0))
                continue
            blocks = make_blocks(veh, prm.block_len)
            room = mv.exit_link.cap - mv.exit_link.occ
            q_len = sum(b[1] for b in blocks)
            if prm.partial_exit:
                eligible = room >= blocks[0][1]
            else:
                eligible = room >= q_len  # spec literal: room for all it would release
            score = sum(b[0] + prm.a_age * (t - b[3]) + prm.b_prio * b[4] for b in blocks)
            p = self._pressure(mv.idx)
            score *= (1.0 - p)
            # discharge time estimate
            if self.learn.n < 8:
                T = prm.g_base
            else:
                total = var = ln = 0.0
                for b in blocks:
                    if prm.partial_exit and ln + b[1] > room:
                        break
                    ln += b[1]
                    total += b[0] * self.learn.tau_of(b[2], mv.turn)
                    var += self.learn.sigma(b[2]) ** 2
                drain = (total + prm.k_sigma * math.sqrt(var)) / mv.lanes
                if prm.arrivals_in_green:
                    rho = self.lam[mv.idx] * self.learn.tau_of(1, mv.turn) / mv.lanes
                    drain /= (1.0 - min(rho, 0.8))
                T = self.learn.L + drain
            T *= (1.0 - 0.5 * p)
            age = t - min(b[3] for b in blocks)
            out.append((score if eligible else 0.0, T, eligible, age))
        return out

    def _plan(self, ev, phase):
        Ts = [ev[m][1] for m in phase if ev[m][2]]
        T = max(Ts) if Ts else self.prm.g_min
        return min(self.prm.g_max, max(self.prm.g_min, T))

    # ── decisions ──────────────────────────────────────────────────────────
    def first_phase(self, t):
        return SPLIT_PHASES[0]

    def on_green(self, t, phase):
        self.g_start = t
        self.cross_t.clear()
        self.learn.green_start(t, phase)
        self.blocked_run = 0
        if self.in_fallback:
            self.planned = self.fallback.green
        else:
            self.planned = self._plan(self._movement_eval(t), phase)

    def _platoon(self, t):
        """Weight arriving within the next 6 s at the current phase's movements."""
        w = 0.0
        for m in self.j.green:
            a, ti = m // 4, m % 4
            lk = self.j.in_links[a]
            for ta, v in lk.transit:
                if ta > t + 6:
                    break
                w += v.w * self.share[a][ti]
        return w

    def wants_end(self, t, elapsed):
        if self.in_fallback:
            return self.fallback.wants_end(t, elapsed)
        prm = self.prm
        j = self.j
        q_w = sum(j.moves[m].q_w + j.entry_w[m] for m in j.green)
        low = q_w <= prm.low_mark_w * max(1, len(j.green)) / 2
        # gap / headway-deviation spike
        gaps = [b - a for a, b in zip(self.cross_t, list(self.cross_t)[1:])]
        since = t - (self.cross_t[-1] if self.cross_t else self.g_start)
        mean_gap = np.mean(gaps) if gaps else 2.0
        spike = since > max(3.0 * mean_gap, 4.0) or (len(gaps) >= 5 and np.std(gaps) > 2.0 * mean_gap)
        platoon = self._platoon(t)
        if prm.smart_early_end:
            if low and platoon < 0.8:
                return True
            if spike and q_w < 1.5 and platoon < 0.8:
                return True
            if self.blocked_run >= 3:
                return True
        else:
            if spike:
                return True
            if low and platoon < 0.8:
                return True
        if prm.rolling and int(elapsed) % int(prm.rolling) == 0:
            # rolling re-placement: is another Tetris piece now clearly better?
            ev = self._movement_eval(t)
            cur = sum(ev[m][0] for m in j.green)
            best = max(sum(ev[m][0] for m in ph) for ph in PHASES)
            if best > 1.3 * cur + 1.0 and platoon < 0.8:
                return True
        if elapsed >= self.planned:
            if platoon >= 0.8 and elapsed + 2 <= prm.g_max:
                self.planned = elapsed + 2  # platoon hold: swallow it
                return False
            return True
        return False

    def choose(self, t, current, forced):
        self.decisions += 1
        if self.in_fallback:
            return self.fallback.choose(t, current, forced)
        prm = self.prm
        ev = self._movement_eval(t)
        cands = [ph for ph in PHASES if not (forced and ph == current)]

        def score(ph):
            return sum(ev[m][0] for m in ph)

        if prm.max_wait_guard > 0:
            starving = [m for m in range(16) if ev[m][2] and ev[m][3] > prm.max_wait_guard]
            if starving:
                worst = max(starving, key=lambda m: ev[m][3])
                pool = [ph for ph in cands if worst in ph]
                if pool:
                    best = max(pool, key=score)
                    self._replan(t, ev, best, current)
                    return best
        best = max(cands, key=score)
        if prm.switch_cost and not forced and current in cands:
            if score(current) >= 0.85 * score(best) and score(current) > 0:
                best = current
        self._replan(t, ev, best, current)
        return best

    def _replan(self, t, ev, best, current):
        if best == current:
            # continuation: new planned end measured from the original green start
            self.planned = min(self.prm.g_max, (t - self.g_start) + self._plan(ev, best) * 0.5)
