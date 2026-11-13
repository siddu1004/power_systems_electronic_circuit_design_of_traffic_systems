"""ICTM-Tetris explainer video (for presenting the algorithm).

Renders an MP4 (and key-frame PNGs) that walks through the algorithm with live
toy simulations, not static slides:

  1. title
  2. vehicles become weighted blocks that stack on a lane (capacitor charging)
  3. a 4-arm junction: blocks arrive, the green tap drains a stack, the rolling
     re-placement rule picks the next phase (scores shown live)
  4. the network layer: an exit road fills (Zener clamp), the relay latches and
     pressure propagates upstream, back-pressure shrinks scores, the gate meters
  5. pressure rerouting: part of the traffic headed into a hot road takes the
     other route
  6. sensing: 60 m camera, noise, outliers, a dead camera; the robust estimator
  7. failsafes: dark signal -> officer, green-but-not-moving alert, signal off
  8. results (SUMO, full Coimbatore city)
  9. what is integrated

    python -m blocktetris.explainer_video            # full video
    python -m blocktetris.explainer_video --quick    # 8 fps draft
"""
import argparse
import os

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from matplotlib import patches
from matplotlib.animation import FFMpegWriter

OUT_DIR = "Results/BlockTetris/BUNDLE/video"
W, H = 12.8, 7.2
BG = "#f7f7f4"
INK = "#1b1b1b"
GREY = "#8a8a8a"
CLS = {"bike": (0.2, "#3aa3d9"), "auto": (0.3, "#e6b422"), "car": (0.4, "#6b7a99"), "bus": (0.9, "#b3382c")}
GREEN, AMBER, RED = "#2ca25f", "#f0a202", "#d7301f"
TAU = 4.62                      # s per weight unit per lane

SCENES = [("title", 5), ("blocks", 13), ("junction", 24), ("network", 20), ("reroute", 16),
          ("sensing", 16), ("failsafe", 16), ("results", 13), ("credits", 7)]


# ───────────────────────────── helpers ─────────────────────────────
def caption(fig, title, lines):
    fig.text(0.03, 0.955, title, fontsize=19, fontweight="bold", color=INK, va="top")
    y = 0.115
    for ln in lines[::-1]:
        fig.text(0.03, y, ln, fontsize=12.5, color=INK, va="bottom")
        y += 0.038
    fig.text(0.985, 0.02, "ICTM-Tetris", fontsize=10, color=GREY, ha="right")


def ease(x):
    x = min(max(x, 0.0), 1.0)
    return x * x * (3 - 2 * x)


class Stack:
    """a lane stack of blocks: arrivals fall in, the green tap pops from the bottom"""

    def __init__(self, rng):
        self.rng = rng
        self.blocks = []        # dicts: w, color, y (current), born
        self.acc = 0.0

    @property
    def V(self):
        return sum(b["w"] for b in self.blocks)

    def arrive(self, t, cls=None):
        if cls is None:
            cls = self.rng.choice(list(CLS), p=[0.45, 0.15, 0.30, 0.10])
        w, c = CLS[cls]
        self.blocks.append(dict(w=w, color=c, y=None, born=t, cls=cls))

    def discharge(self, dt, rate=1.0 / TAU):
        self.acc += rate * dt
        while self.blocks and self.acc >= self.blocks[0]["w"]:
            self.acc -= self.blocks.pop(0)["w"]
        if not self.blocks:
            self.acc = 0.0

    def layout(self, t, fall_from, dt):
        """target rest heights; blocks fall from fall_from and slide down smoothly"""
        h = 0.0
        for b in self.blocks:
            target = h
            if b["y"] is None:
                b["y"] = fall_from
            b["y"] += (target - b["y"]) * min(1.0, 12.0 * dt)
            h += b["w"]
        return h


def draw_stack_vertical(ax, st, x, y0, width, scale, t, dt, up=True):
    st.layout(t, 5.0, dt)
    for b in st.blocks:
        y = y0 + (b["y"] if up else -b["y"] - b["w"]) * scale
        ax.add_patch(patches.Rectangle((x, y), width, b["w"] * scale * 0.96, fc=b["color"], ec="white", lw=0.6))


def draw_stack_horizontal(ax, st, x0, y, height, scale, t, dt, right=True):
    st.layout(t, 5.0, dt)
    for b in st.blocks:
        x = x0 + (b["y"] if right else -b["y"] - b["w"]) * scale
        ax.add_patch(patches.Rectangle((x, y), b["w"] * scale * 0.96, height, fc=b["color"], ec="white", lw=0.6))


def signal_head(ax, x, y, state, r=0.16):
    col = {"G": GREEN, "Y": AMBER, "R": RED, "off": "#444444"}[state]
    ax.add_patch(patches.Circle((x, y), r * 1.5, fc="#222222", ec="none"))
    ax.add_patch(patches.Circle((x, y), r, fc=col, ec="none"))


# ───────────────────────────── scene 2: blocks ─────────────────────────────
class BlocksScene:
    def __init__(self, rng):
        self.st = Stack(rng)
        self.order = ["car", "bike", "bus", "auto", "car", "bike", "bike", "car", "auto", "bus", "car", "bike"]
        self.next_t = 1.0
        self.k = 0
        self.last = 0.0

    def draw(self, fig, t):
        dt = t - self.last
        self.last = t
        if t >= self.next_t and self.k < len(self.order):
            self.st.arrive(t, self.order[self.k])
            self.k += 1
            self.next_t = t + 0.75
        ax = fig.add_axes([0.08, 0.2, 0.84, 0.68])
        ax.set_xlim(0, 10)
        ax.set_ylim(0, 6)
        ax.axis("off")
        for i, (cls, (w, c)) in enumerate(CLS.items()):
            y = 5.2 - i * 1.15
            ax.add_patch(patches.Rectangle((0.3, y), 1.4, 0.7 * max(w, 0.35) / 0.9 + 0.25, fc=c, ec="white"))
            ax.text(1.95, y + 0.25, f"{cls}: w = {w}", fontsize=14, va="center", color=INK)
        ax.text(0.3, 0.25, "one block = 7.5 m of lane", fontsize=11, color=GREY)
        ax.add_patch(patches.Rectangle((5.6, 0.4), 1.4, 5.3, fc="#e3e3df", ec="none"))
        ax.plot([5.6, 7.0], [0.4, 0.4], color=INK, lw=3)
        ax.text(6.3, 0.1, "stop line", ha="center", fontsize=10, color=GREY)
        draw_stack_vertical(ax, self.st, 5.65, 0.42, 1.3, 1.0, t, dt)
        V = self.st.V
        ax.add_patch(patches.Rectangle((7.9, 0.4), 0.6, 5.0, fc="white", ec=INK, lw=1.2))
        ax.add_patch(patches.Rectangle((7.9, 0.4), 0.6, min(5.0, V), fc="#f58518", ec="none"))
        ax.text(8.2, 5.6, f"V = {V:.1f} W", ha="center", fontsize=15, fontweight="bold", color=INK)
        ax.text(8.2, 0.05, "charge", ha="center", fontsize=10, color=GREY)
        ax.annotate("", xy=(7.85, 2.5), xytext=(7.1, 2.5), arrowprops=dict(arrowstyle="->", lw=2, color=INK))
        caption(fig, "1. Vehicles become blocks",
                ["Every vehicle is a block with a weight: bike 0.2, auto 0.3, car 0.4, bus or truck 0.9.",
                 "Blocks fall onto the lane and stack at the stop line. The stack weight V is the queue.",
                 "Electrically the stack is a capacitor: dV/dt = current in − current out."])


# ───────────────────────────── scene 3: junction ─────────────────────────────
class JunctionScene:
    ARMS = ["N", "E", "S", "W"]
    MOVES = ["L", "S", "R"]
    PHASES = [[("N", "L"), ("N", "S"), ("S", "L"), ("S", "S")], [("N", "R"), ("S", "R")],
              [("E", "L"), ("E", "S"), ("W", "L"), ("W", "S")], [("E", "R"), ("W", "R")]]
    PNAME = ["N–S through", "N–S right", "E–W through", "E–W right"]

    def __init__(self, rng, speed=5.0):
        self.rng = rng
        self.speed = speed
        self.st = {(a, m): Stack(rng) for a in self.ARMS for m in self.MOVES}
        self.lam = {"N": 0.30, "S": 0.27, "E": 0.16, "W": 0.13}
        self.phase, self.mode, self.g0, self.m0, self.nxt = 0, "G", 0.0, 0.0, 0
        self.sim_t = 0.0
        self.last = 0.0
        self.last_served = {k: 0.0 for k in self.st}
        self.switch_reason = ""
        self.exit_fill = {"N": 0.2, "E": 0.3, "S": 0.25, "W": 0.85}   # road leaving towards arm X
        self.exit_of = {("N", "S"): "S", ("N", "L"): "E", ("N", "R"): "W", ("S", "S"): "N", ("S", "L"): "W",
                        ("S", "R"): "E", ("E", "S"): "W", ("E", "L"): "S", ("E", "R"): "N", ("W", "S"): "E",
                        ("W", "L"): "N", ("W", "R"): "S"}
        for _ in range(26):                       # a warm start
            k = (self.rng.choice(self.ARMS, p=[0.35, 0.15, 0.35, 0.15]), self.rng.choice(self.MOVES, p=[0.25, 0.55, 0.2]))
            self.st[k].arrive(0.0)

    def rate(self, k):
        V = self.st[k].V
        bp = max(0.0, 1 - self.exit_fill[self.exit_of[k]] ** 2)
        return (1.0 / TAU) * min(1.0, V / 0.4) * bp

    def score(self, p, ts):
        s = 0.0
        for k in self.PHASES[p]:
            V = self.st[k].V
            age = ts - self.last_served[k] if V > 0.05 else 0.0
            s += (V + 0.01 * (V / 0.55) * age) * max(0.0, 1 - self.exit_fill[self.exit_of[k]] ** 2)
        return s

    def step(self, dts):
        ts = self.sim_t
        for a in self.ARMS:
            if self.rng.random() < self.lam[a] * dts:
                self.st[(a, self.rng.choice(self.MOVES, p=[0.25, 0.55, 0.2]))].arrive(ts)
        if self.mode == "G":
            for k in self.PHASES[self.phase]:
                self.st[k].discharge(dts, self.rate(k))
                self.last_served[k] = ts
            el = ts - self.g0
            cur_rate = sum(self.rate(k) for k in self.PHASES[self.phase])
            best_p = max(range(4), key=lambda p: sum(self.rate(k) for k in self.PHASES[p]))
            best_rate = sum(self.rate(k) for k in self.PHASES[best_p])
            Vph = sum(self.st[k].V for k in self.PHASES[self.phase])
            reason = None
            if el >= 15.0 and Vph < 0.5:
                reason = "stack empty"
            elif el >= 15.0 and best_rate > 2.0 * cur_rate + 0.05:
                reason = "another phase would pass 2× the current"
            elif el >= 70.0:
                reason = "max green 70 s"
            if reason:
                sc = [self.score(p, ts) for p in range(4)]
                sc[self.phase] = -1
                self.nxt = int(np.argmax(sc))
                self.mode, self.m0 = "Y", ts
                self.switch_reason = reason
        else:
            if ts - self.m0 >= 5.0:
                self.mode, self.phase, self.g0 = "G", self.nxt, ts
        self.sim_t += dts

    def draw(self, fig, t):
        dt = t - self.last
        self.last = t
        n = max(1, int(round(dt * self.speed / 0.25)))
        for _ in range(n):
            self.step(dt * self.speed / n)
        ts = self.sim_t
        ax = fig.add_axes([0.0, 0.21, 0.62, 0.70])
        ax.set_xlim(-6.2, 6.2)
        ax.set_ylim(-5.6, 5.6)
        ax.set_aspect("equal")
        ax.axis("off")
        ax.add_patch(patches.Rectangle((-1.8, -5.6), 3.6, 11.2, fc="#e3e3df", ec="none"))
        ax.add_patch(patches.Rectangle((-6.2, -1.8), 12.4, 3.6, fc="#e3e3df", ec="none"))
        ax.add_patch(patches.Rectangle((-1.8, -1.8), 3.6, 3.6, fc="#d6d6d0", ec="none"))
        served = set(self.PHASES[self.phase]) if self.mode == "G" else set()
        sc = 0.75
        wdt = 0.5
        cols = {"N": [(-1.7, 1.85, "v", True), (-1.1, 1.85, "v", True), (-0.5, 1.85, "v", True)],
                "S": [(1.7 - wdt, -1.85, "v", False), (1.1 - wdt, -1.85, "v", False), (0.5 - wdt, -1.85, "v", False)],
                "E": [(1.85, 1.7 - wdt, "h", True), (1.85, 1.1 - wdt, "h", True), (1.85, 0.5 - wdt, "h", True)],
                "W": [(-1.85, -1.7, "h", False), (-1.85, -1.1, "h", False), (-1.85, -0.5, "h", False)]}
        for a in self.ARMS:
            for m, (x, y, o, pos) in zip(self.MOVES, cols[a]):
                k = (a, m)
                if k in served:
                    if o == "v":
                        gy = y - 0.04 if pos else y - 3.7 + 0.04
                        ax.add_patch(patches.Rectangle((x - 0.04, gy), wdt + 0.08, 3.7, fc="#c7efd3", ec="none"))
                    else:
                        gx = x - 0.04 if pos else x - 3.7 + 0.04
                        ax.add_patch(patches.Rectangle((gx, y - 0.04), 3.7, wdt + 0.08, fc="#c7efd3", ec="none"))
                if o == "v":
                    draw_stack_vertical(ax, self.st[k], x, y, wdt, sc, t, dt, up=pos)
                else:
                    draw_stack_horizontal(ax, self.st[k], x, y, wdt, sc, t, dt, right=pos)
                lx, ly = (x + wdt / 2, y + (-0.25 if pos else 0.25)) if o == "v" else (x + (-0.25 if pos else 0.25), y + wdt / 2)
                ax.text(lx, ly, m, ha="center", va="center", fontsize=8, color="#555")
        state = "G" if self.mode == "G" else ("Y" if ts - self.m0 < 3 else "R")
        active_arms = {k[0] for k in self.PHASES[self.phase]}
        for a, (x, y) in {"N": (-2.25, 2.15), "S": (2.25, -2.15), "E": (2.15, 2.25), "W": (-2.15, -2.25)}.items():
            signal_head(ax, x, y, state if a in active_arms else "R", r=0.2)
        for a, (x, y, o) in {"N": (0.9, 4.4, "v"), "S": (-1.2, -5.4, "v"), "E": (4.9, -1.4, "h"), "W": (-5.9, 1.1, "h")}.items():
            f = self.exit_fill[a]
            if o == "v":
                ax.add_patch(patches.Rectangle((x, y), 0.3, 1.0, fc="white", ec=INK, lw=0.8))
                ax.add_patch(patches.Rectangle((x, y), 0.3, f, fc=RED if f > 0.8 else "#f58518", ec="none"))
            else:
                ax.add_patch(patches.Rectangle((x, y), 1.0, 0.3, fc="white", ec=INK, lw=0.8))
                ax.add_patch(patches.Rectangle((x, y), f, 0.3, fc=RED if f > 0.8 else "#f58518", ec="none"))
        ax.text(-5.9, 1.5, "exit road 85 % full", fontsize=8.5, color=RED)
        bx = fig.add_axes([0.66, 0.42, 0.31, 0.46])
        bx.set_xlim(0, 1)
        bx.set_ylim(-0.6, 3.95)
        bx.axis("off")
        scs = [self.score(p, ts) for p in range(4)]
        mx = max(max(scs), 1e-6)
        rates = [sum(self.rate(k) for k in self.PHASES[p]) for p in range(4)]
        for p in range(4):
            y = 3 - p
            cur = p == self.phase
            bx.add_patch(patches.Rectangle((0, y - 0.3), 0.98 * scs[p] / mx, 0.6, fc=GREEN if cur else "#9ecae1", ec="none"))
            bx.text(0.01, y + 0.33, self.PNAME[p] + ("   ◀ green" if cur and self.mode == "G" else ""),
                    fontsize=10.5, color=INK, fontweight="bold" if cur else "normal")
            bx.text(0.97, y, f"score {scs[p]:.1f}   rate {rates[p]:.2f} W/s", ha="right", va="center", fontsize=9, color=INK)
        bx.text(0.0, 3.75, "phase placement (which piece fits best)", fontsize=11, color=GREY)
        el = ts - (self.g0 if self.mode == "G" else self.m0)
        txt = f"green {el:4.0f} s" if self.mode == "G" else f"amber + all-red  {el:3.0f} / 5 s"
        bx.text(0.0, -0.5, txt + f"      sim time {ts:4.0f} s", fontsize=10.5, color=INK)
        if self.switch_reason:
            fig.text(0.66, 0.33, "last switch: " + self.switch_reason, fontsize=10.5, color="#b3382c")
        caption(fig, "2. The junction places pieces",
                ["Each arm has stacks for left, straight and right. A green is a tap draining its stacks at 1/τ W/s.",
                 "Rule: keep the green until the stack empties, or another phase could pass 2× the current, or 70 s.",
                 "A full exit road shrinks a stack's score by (1 − fill²): no block is pushed where it cannot land."])


# ───────────────────────────── scene 4: network ─────────────────────────────
class NetworkScene:
    def draw(self, fig, t):
        ax = fig.add_axes([0.03, 0.2, 0.94, 0.66])
        ax.set_xlim(0, 20)
        ax.set_ylim(0, 6)
        ax.axis("off")
        fill3 = min(0.95, 0.35 + 0.045 * t)
        latched = fill3 >= 0.8
        p3 = max(0.0, (fill3 - 0.6) / 0.4) if latched else 0.0
        hops = [p3, 0.5 * p3 * ease((t - 11) / 2), 0.25 * p3 * ease((t - 13) / 2)]
        xs = [2.5, 8.0, 13.5]
        roads = [(0.3, 2.5), (3.5, 8.0), (9.0, 13.5), (14.5, 19.5)]
        pres = [hops[2] * 0.5, hops[2], hops[1], hops[0]]
        fills = [0.3, 0.45 + 0.01 * t, 0.55 + 0.015 * t, fill3]
        for (x0, x1), p, f in zip(roads, pres, fills):
            ax.add_patch(patches.Rectangle((x0, 2.4), x1 - x0, 1.2, fc=(1, 1 - 0.75 * p, 1 - 0.8 * p), ec="#bbb"))
            ax.add_patch(patches.Rectangle((x0 + 0.1, 2.5), (x1 - x0 - 0.2) * min(1, f), 0.3, fc="#f58518" if f < 0.8 else RED, ec="none"))
            ax.text((x0 + x1) / 2, 3.75, f"fill {f:.2f}   p = {p:.2f}", ha="center", fontsize=10, color=INK)
        for i, x in enumerate(xs):
            ax.add_patch(patches.Rectangle((x, 2.0), 1.0, 2.0, fc="#d6d6d0", ec="none"))
            ax.text(x + 0.5, 4.3, f"J{i + 1}", ha="center", fontsize=12, fontweight="bold")
            m = 1 - pres[i + 1]
            ax.add_patch(patches.Rectangle((x, 1.2), 1.0, 0.35, fc="white", ec=INK, lw=0.8))
            ax.add_patch(patches.Rectangle((x, 1.2), m, 0.35, fc=GREEN, ec="none"))
            ax.text(x + 0.5, 0.75, f"eastbound score × {m:.2f}", ha="center", fontsize=9.5, color=INK)
        meter = 1 - 0.5 * ease((t - 14) / 2) if latched else 1.0
        ax.add_patch(patches.Rectangle((0.3, 4.6), 2.2, 0.9, fc="white", ec=INK, lw=0.8))
        ax.text(1.4, 5.05, f"gate meter {meter:.2f}", ha="center", va="center", fontsize=10, color=INK)
        k = 1.0 / meter
        for j in range(60):
            xd = (0.6 + ((j * 0.9 * k + t * 1.3) % 19.0))
            if 2.5 < xd < 3.5 or 8 < xd < 9 or 13.5 < xd < 14.5:
                continue
            ax.add_patch(patches.Circle((xd, 3.2), 0.1, fc="#6b7a99", ec="none"))
        if fill3 >= 0.95:
            ax.text(17.0, 1.6, "Zener clamp: no more current enters a full road", fontsize=10, color=RED, ha="center")
        if latched:
            ax.text(17.0, 5.2, "relay latched (fill ≥ 0.8, releases < 0.6)", fontsize=10.5, color=RED, ha="center", fontweight="bold")
        ax.annotate("", xy=(14.6, 4.9), xytext=(19.0, 4.9), arrowprops=dict(arrowstyle="->", lw=2.5, color=RED, alpha=min(1, p3 + 0.1)))
        ax.text(16.8, 4.55, "pressure travels upstream, halved per hop, soft-start recovery", fontsize=9.5, ha="center", color=INK)
        caption(fig, "3. The network: roads are delay lines with a hard capacity",
                ["When a road reaches 80 % it trips a relay. Its pressure p spreads upstream, × 0.5 per junction.",
                 "Upstream junctions multiply the scores of movements feeding that road by (1 − p): less is sent in.",
                 "At the city boundary the gate meters inflow. Charge is conserved everywhere (KCL)."])


# ───────────────────────────── scene 5: reroute ─────────────────────────────
class RerouteScene:
    def __init__(self, rng):
        self.rng = rng
        self.cars = []
        self.next = 0.0
        self.paths = {"mid": [(0, 3), (3, 3), (6, 3), (9, 3), (12, 3)],
                      "top": [(0, 3), (3, 3), (3, 5.5), (9, 5.5), (9, 3), (12, 3)]}
        self.last = 0.0
        self.n_rr = 0

    def draw(self, fig, t):
        dt = t - self.last
        self.last = t
        hot = t > 4.0
        if t >= self.next:
            path = "top" if (hot and self.rng.random() < 0.5) else "mid"
            if path == "top":
                self.n_rr += 1
            self.cars.append(dict(path=self.paths[path], s=0.0, speed=2.2 if path == "top" else (0.9 if hot else 2.2),
                                  color="#2b7bba" if path == "top" else "#6b7a99"))
            self.next = t + 0.45
        ax = fig.add_axes([0.03, 0.17, 0.62, 0.72])
        ax.set_xlim(-0.5, 12.5)
        ax.set_ylim(0.5, 7)
        ax.set_aspect("equal")
        ax.axis("off")
        for y in (3, 5.5):
            ax.plot([0, 12], [y, y], color="#d9d9d4", lw=14, solid_capstyle="butt")
        for x in (3, 9):
            ax.plot([x, x], [3, 5.5], color="#d9d9d4", lw=14, solid_capstyle="butt")
        if hot:
            ax.plot([3.4, 8.6], [3, 3], color=(1, 0.45, 0.35), lw=14, solid_capstyle="butt")
            ax.text(6, 2.2, "hot road: queue / leave-rate = 140 s, fill 0.86", ha="center", fontsize=10.5, color=RED)
        for x, y in [(3, 3), (9, 3), (3, 5.5), (9, 5.5)]:
            ax.add_patch(patches.Rectangle((x - 0.3, y - 0.3), 0.6, 0.6, fc="#bdbdb6", ec="none", zorder=4))
        keep = []
        for c in self.cars:
            c["s"] += c["speed"] * dt
            pts = c["path"]
            d = 0.0
            pos = None
            for (x0, y0), (x1, y1) in zip(pts, pts[1:]):
                L = abs(x1 - x0) + abs(y1 - y0)
                if c["s"] <= d + L:
                    f = (c["s"] - d) / L
                    pos = (x0 + (x1 - x0) * f, y0 + (y1 - y0) * f)
                    break
                d += L
            if pos is None:
                continue
            keep.append(c)
            ax.add_patch(patches.Circle(pos, 0.17, fc=c["color"], ec="white", lw=0.5, zorder=6))
        self.cars = keep
        ax.text(0, 6.5, "navigation-app style: a share of drivers headed into a hot road take the other way", fontsize=10.5, color=INK)
        bx = fig.add_axes([0.68, 0.3, 0.3, 0.55])
        bx.axis("off")
        bx.text(0, 0.95, "road cost every 60 s", fontsize=13, fontweight="bold", va="top")
        bx.text(0, 0.80, "cost = free travel time\n      + queue ÷ measured leave rate\n      + penalty when fill ≥ 0.8\n      + navigation-app travel time",
                fontsize=11.5, va="top", linespacing=1.6)
        bx.text(0, 0.32, f"re-routed so far: {self.n_rr}", fontsize=12.5, color="#2b7bba", va="top")
        bx.text(0, 0.2, "compliance 50 %, re-check ≥ 120 s apart", fontsize=10, color=GREY, va="top")
        caption(fig, "4. Pressure rerouting: traffic flows from high pressure to low",
                ["Every road is priced by its queue, how fast its signal is actually clearing it, and its capacity.",
                 "Vehicles whose next roads are hot are offered a route that rejoins later.",
                 "The map is a grid where every junction talks to its neighbours."])


# ───────────────────────────── scene 6: sensing ─────────────────────────────
class SensingScene:
    def __init__(self, rng):
        T = 160
        tt = np.arange(T)
        truth = np.clip(2.5 + 2.5 * np.sin(tt / 14.0) + 1.6 * np.sin(tt / 5.3) + 0.6 * np.sin(tt / 2.1), 0, None)
        truth[60:110] += 2.0 * np.sin((tt[60:110] - 60) / 50 * np.pi)
        cam = np.minimum(truth, 4.5) * (1 + 0.08 * rng.standard_normal(T))
        out = rng.random(T) < 0.03
        cam[out] *= rng.uniform(0, 3, out.sum())
        cam = np.clip(cam, 0, None)
        dead = (tt >= 105) & (tt < 135)
        q, P, est, rej = 0.0, 1.0, [], []
        for i in range(T):
            dq = (truth[i] - truth[i - 1]) if i else truth[0]
            q = max(0.0, q + dq * (1 + 0.1 * rng.standard_normal()))
            P += 0.08
            if not dead[i]:
                z = cam[i]
                if truth[i] > 4.5 and z >= 4.3:
                    q = max(q, z)
                else:
                    R = (0.08 * z + 0.15) ** 2
                    S = P + R
                    nu = z - q
                    if nu * nu / S > 9:
                        rej.append(i)
                    else:
                        k = P / S
                        q += k * nu
                        P *= (1 - k)
            est.append(q)
        self.tt, self.truth, self.cam, self.est, self.dead, self.rej = tt, truth, cam, np.array(est), dead, rej

    def draw(self, fig, t):
        n = int(min(len(self.tt) - 1, t / 16 * 160))
        ax = fig.add_axes([0.07, 0.31, 0.9, 0.56])
        ax.set_xlim(0, 160)
        ax.set_ylim(0, 8)
        ax.set_xlabel("time (s)")
        ax.set_ylabel("lane queue (W)")
        ax.axhspan(4.5, 8, color="#eeeeea")
        ax.text(2, 7.4, "beyond the 60 m camera view: only a lower bound is seen", fontsize=10, color=GREY)
        ax.axvspan(105, 135, color="#fde0dd")
        ax.text(120, 0.4, "camera dead:\nrebuilt from\nneighbours' counts", ha="center", fontsize=9.5, color=RED)
        tt = self.tt[:n + 1]
        ax.plot(tt, self.truth[:n + 1], color=INK, lw=2.2, label="true queue")
        live = ~self.dead[:n + 1]
        ax.scatter(tt[live], self.cam[:n + 1][live], s=14, color="#9ecae1", label="camera reading (noise, occlusion, outliers)")
        rj = [i for i in self.rej if i <= n]
        ax.scatter(self.tt[rj], self.cam[rj], s=60, facecolors="none", edgecolors=RED, lw=1.5, label="rejected by χ² gate")
        ax.plot(tt, self.est[:n + 1], color="#f58518", lw=2.4, label="robust estimate")
        ax.legend(loc="upper right", fontsize=9.5, frameon=True, facecolor="white", framealpha=0.95, edgecolor="none")
        for s in ("top", "right"):
            ax.spines[s].set_visible(False)
        caption(fig, "5. Seeing the stacks: cameras + a robust estimator",
                ["Prediction: counts in and out of the lane (KCL). Update: the 60 m camera, gated and Huber-weighted.",
                 "A queue past the view is a lower bound. A frozen camera is detected. A dead camera falls back to counts.",
                 "In SUMO the estimate halves the camera's error (6.2 W vs 13.1 W at high demand)."])


# ───────────────────────────── scene 7: failsafes ─────────────────────────────
class FailsafeScene:
    def draw(self, fig, t):
        ax = fig.add_axes([0.04, 0.5, 0.44, 0.38])
        ax.set_xlim(0, 10)
        ax.set_ylim(0, 4)
        ax.axis("off")
        ax.text(0, 3.6, "A. signal goes dark", fontsize=13, fontweight="bold")
        signal_head(ax, 1.0, 2.2, "off", r=0.3)
        ax.plot([2.2, 8.8], [2.2, 2.2], color="#ccc", lw=6)
        f = ease(t / 6)
        ax.add_patch(patches.Circle((2.2 + 6.6 * f, 2.2), 0.35, fc="#2b7bba", ec="white"))
        ax.text(2.2 + 6.6 * f, 2.9, "officer", ha="center", fontsize=10, color="#2b7bba")
        ax.text(2.2, 1.4, "0 s", fontsize=9, color=GREY)
        ax.text(8.8, 1.4, "300 s", fontsize=9, color=GREY, ha="right")
        if f >= 1:
            ax.text(5.5, 0.6, "officer on duty: longest queue first, hold until the arm clears (≤ 60 s)", ha="center", fontsize=10.5, color=INK)
        bx = fig.add_axes([0.52, 0.5, 0.45, 0.38])
        bx.set_xlim(0, 10)
        bx.set_ylim(0, 4)
        bx.axis("off")
        bx.text(0, 3.6, "B. green but nothing moves", fontsize=13, fontweight="bold")
        a = ease((t - 5) / 1.5)
        if a > 0:
            bx.add_patch(patches.FancyBboxPatch((0.2, 0.3), 9.4 * a, 2.8, boxstyle="round,pad=0.1", fc="#fff3e0", ec="#f0a202", lw=1.5))
            if a > 0.9:
                bx.text(0.5, 2.7, "ALERT  J-14  t = 1 842 s", fontsize=11.5, fontweight="bold", color="#b3382c")
                bx.text(0.5, 2.15, "stack 4.3 W under green for 30 s, exit lane not full → local blockage", fontsize=10)
                bx.text(0.5, 1.6, "decision: request officer; upstream signals throttle this feed", fontsize=10)
                bx.text(0.5, 1.05, "justification: discharge 0 W/s while exits move", fontsize=10)
                bx.text(0.5, 0.5, "rate-limited: one alert per junction per 10 min", fontsize=9.5, color=GREY)
        cx = fig.add_axes([0.04, 0.17, 0.44, 0.3])
        cx.set_xlim(0, 10)
        cx.set_ylim(0, 3)
        cx.axis("off")
        cx.text(0, 2.7, "C. very light traffic for 2 min → signal off (give-way rules)", fontsize=12, fontweight="bold")
        on = t < 10
        signal_head(cx, 1.0, 1.2, "G" if on else "off", r=0.3)
        cx.text(2.0, 1.2, "queues < 0.8 W on all arms" if on else "OFF — back on as soon as a stack builds", va="center", fontsize=11)
        dx = fig.add_axes([0.52, 0.17, 0.45, 0.3])
        dx.set_xlim(0, 10)
        dx.set_ylim(0, 3)
        dx.axis("off")
        dx.text(0, 2.7, "D. block area per road", fontsize=12, fontweight="bold")
        for i, (name, lim) in enumerate([("1 lane", 0.75), ("2 lanes", 0.85), ("3 lanes", 0.90), ("after 2 spill-backs", 0.65)]):
            y = 2.0 - i * 0.5
            dx.add_patch(patches.Rectangle((2.8, y - 0.17), 6.0, 0.34, fc="white", ec=INK, lw=0.8))
            dx.add_patch(patches.Rectangle((2.8, y - 0.17), 6.0 * lim, 0.34, fc="#f58518", ec="none"))
            dx.text(2.6, y, name, ha="right", va="center", fontsize=10)
            dx.text(9.0, y, f"{lim:.2f}", va="center", fontsize=10)
        caption(fig, "6. Failsafes",
                ["Officers (3, 5-min arrival) take over dark junctions and real local blockages, then hand back after 5 calm minutes.",
                 "Quiet junctions switch off. Narrow or incident-prone roads are allowed fewer blocks before they count as full."])


# ───────────────────────────── scene 8: results ─────────────────────────────
class ResultsScene:
    CITY = [("Fixed-40", 634), ("MaxPressure", 567), ("SITRA-MPC", 450), ("Actuated", 417), ("ICTM-Tetris", 283)]
    CORR = [("Fixed-40", 866), ("SITRA-MPC", 668), ("Actuated", 502), ("MaxPressure", 487), ("ICTM-Tetris", 423)]

    def draw(self, fig, t):
        for k, (data, title, sub) in enumerate([(self.CITY, "Full Coimbatore city (SUMO, 333 signals)", "7 events × 2 seeds; −32 % vs Actuated, all 14 runs"),
                                                 (self.CORR, "Peelamedu corridor (SUMO, 31 signals)", "test seeds 11–13; −13 % vs MaxPressure, −16 % vs Actuated")]):
            ax = fig.add_axes([0.1 + 0.48 * k, 0.3, 0.37, 0.52])
            f = ease((t - 0.5 - 4 * k) / 3)
            names = [d[0] for d in data]
            vals = [d[1] * f for d in data]
            cols = ["#bbbbbb"] * 4 + ["#111111"]
            ax.barh(range(5), vals, color=cols)
            ax.set_yticks(range(5))
            ax.set_yticklabels(names, fontsize=11)
            ax.invert_yaxis()
            ax.set_xlim(0, 950)
            ax.set_xlabel("mean delay per vehicle (s)")
            ax.set_title(title + "\n" + sub, fontsize=11.5, fontweight="bold", loc="left", pad=10)
            for i, v in enumerate(vals):
                if f > 0.95:
                    ax.text(v + 10, i, f"{data[i][1]}", va="center", fontsize=10.5)
            for s in ("top", "right"):
                ax.spines[s].set_visible(False)
        caption(fig, "7. Results on the microscopic simulator",
                ["Lowest delay in every event, both demand levels, both maps. Paired tests on seeds the tuning never saw.",
                 "One junction decision takes about 0.12 ms: real time on cheap hardware."])


class TitleScene:
    def draw(self, fig, t):
        a = ease(t / 1.2)
        fig.text(0.5, 0.58, "ICTM-Tetris", fontsize=56, fontweight="bold", ha="center", color=INK, alpha=a)
        fig.text(0.5, 0.47, "Intra-City Traffic Management with a Tetris core", fontsize=20, ha="center", color=INK, alpha=a)
        fig.text(0.5, 0.36, "vehicles are weighted blocks · queues are capacitors · greens are taps\n"
                            "roads are delay lines with a hard capacity · pressure flows from high to low",
                 fontsize=13, ha="center", color=GREY, alpha=ease((t - 1) / 1.2), linespacing=1.7)
        rng = np.random.default_rng(3)
        ax = fig.add_axes([0, 0, 1, 1])
        ax.set_xlim(0, 1)
        ax.set_ylim(0, 1)
        ax.axis("off")
        for i in range(14):
            x = 0.06 + 0.9 * rng.random()
            spd = 0.12 + 0.1 * rng.random()
            y = 1.05 - ((t * spd + rng.random()) % 1.2)
            w, c = list(CLS.values())[i % 4]
            ax.add_patch(patches.Rectangle((x, y), 0.03, 0.045 * w / 0.4, fc=c, ec="none", alpha=0.35))


class CreditsScene:
    def draw(self, fig, t):
        fig.text(0.5, 0.86, "What ICTM-Tetris integrates", fontsize=24, fontweight="bold", ha="center")
        rows = ["v1–v3  block weights · stacks · rolling re-placement · saturation green · back-pressure · relay · metering · head-of-line",
                "v4      predictive relay (acts on where the load is heading)",
                "v5–v6  robust estimator on 60 m cameras · navigation-app travel time in route costs",
                "v7      generic mode, special mode on degraded discharge, accumulation, camera failure or a dark signal",
                "v7-final  120 s service guarantee · police officers at dark junctions and local blockages",
                "v9      pressure rerouting · green-but-not-moving alert with decision and justification",
                "v10    signal off in light traffic · self-adjusting fixed green · block area per road",
                "v12–v13  online discharge-time learning · rate-limited alerts · realistic sensors throughout"]
        for i, r in enumerate(rows):
            a = ease((t - 0.3 * i) / 0.8)
            fig.text(0.07, 0.74 - 0.075 * i, r, fontsize=12.5, color=INK, alpha=a)
        fig.text(0.5, 0.08, "Validated in an electrical twin and in SUMO (Eclipse) on OpenStreetMap Coimbatore.", fontsize=12, ha="center", color=GREY)


# ───────────────────────────── render ─────────────────────────────
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--quick", action="store_true")
    ap.add_argument("--fps", type=int, default=0)
    ap.add_argument("--out", default=os.path.join(OUT_DIR, "ICTM_Tetris_explainer.mp4"))
    a = ap.parse_args()
    fps = a.fps or (8 if a.quick else 24)
    os.makedirs(OUT_DIR, exist_ok=True)
    rng = np.random.default_rng(7)
    scenes = {"title": TitleScene(), "blocks": BlocksScene(rng), "junction": JunctionScene(np.random.default_rng(11)),
              "network": NetworkScene(), "reroute": RerouteScene(np.random.default_rng(5)),
              "sensing": SensingScene(np.random.default_rng(2)), "failsafe": FailsafeScene(),
              "results": ResultsScene(), "credits": CreditsScene()}
    fig = plt.figure(figsize=(W, H), dpi=100)
    fig.patch.set_facecolor(BG)
    writer = FFMpegWriter(fps=fps, codec="libx264", extra_args=["-pix_fmt", "yuv420p", "-crf", "26", "-preset", "slow"])
    total = sum(d for _, d in SCENES)
    frame = 0
    with writer.saving(fig, a.out, dpi=100):
        for name, dur in SCENES:
            sc = scenes[name]
            nfr = int(dur * fps)
            for i in range(nfr):
                t = i / fps
                fig.clf()
                fig.patch.set_facecolor(BG)
                sc.draw(fig, t)
                fig.patches.append(patches.Rectangle((0, 0), frame / (total * fps), 0.006, transform=fig.transFigure, fc="#f58518", ec="none"))
                writer.grab_frame(facecolor=BG)
                if i == nfr // 2:
                    fig.savefig(os.path.join(OUT_DIR, f"frame_{name}.png"), dpi=100, facecolor=BG)
                frame += 1
            print(f"scene {name} done ({frame}/{total * fps} frames)", flush=True)
    print("saved", a.out)


if __name__ == "__main__":
    main()
