"""Generate print-ready, IEEE single-column (3.45 in) figures for the SITRA paper.
All numbers come from the repo: T6 time series from the MAT export, other values from
the result tables listed in Report/sections/sec11_results.md."""
import numpy as np, scipy.io as sio
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch
from PIL import Image

OUT = "Report/ieee/figs/"
MAT = "SITRA_Project/SITRA_PROJECT_BUILD_FLAT_COMPLETE/Results/T6_Simulink_Exports/SITRA_T6_All_Controllers.mat"
COL = {"SITRA": "#1b5fb0", "Webster": "#d9731a", "Actuated": "#2e9a4f", "MaxPressure": "#8a3fa6"}
INK, GRID = "#222222", "#d0d0d0"
W = 3.45

plt.rcParams.update({
    "font.family": "serif", "font.serif": ["Times New Roman", "DejaVu Serif"],
    "font.size": 7, "axes.labelsize": 7, "axes.titlesize": 7, "legend.fontsize": 6,
    "xtick.labelsize": 6.5, "ytick.labelsize": 6.5, "axes.linewidth": 0.6,
    "axes.edgecolor": INK, "axes.labelcolor": INK, "xtick.color": INK, "ytick.color": INK,
    "mathtext.fontset": "stix", "savefig.dpi": 300, "figure.dpi": 150,
})


def box(ax, x, y, w, h, text, fc="#eef3fb", ec="#1b5fb0", fs=6.2, bold=False):
    ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.0,rounding_size=0.025",
                                fc=fc, ec=ec, lw=0.8))
    ax.text(x + w / 2, y + h / 2, text, ha="center", va="center", fontsize=fs, color=INK,
            fontweight="bold" if bold else "normal", linespacing=1.15)


def arrow(ax, p, q, style="-|>", ls="-", color=INK, lw=0.8, rad=0.0):
    ax.add_patch(FancyArrowPatch(p, q, arrowstyle=style, mutation_scale=7, lw=lw, color=color,
                                 linestyle=ls, shrinkA=0, shrinkB=0,
                                 connectionstyle=f"arc3,rad={rad}"))


# ---------------------------------------------------------------- Fig 1: dual-domain map
def fig_mapping():
    fig, ax = plt.subplots(figsize=(W, 4.1))
    ax.set_xlim(0, 1); ax.set_ylim(0, 1); ax.axis("off")
    ax.text(0.20, 0.975, "Traffic domain", ha="center", fontsize=7.5, fontweight="bold", color="#8a3f00")
    ax.text(0.80, 0.975, "Electrical domain", ha="center", fontsize=7.5, fontweight="bold", color="#1b5fb0")
    rows = [
        ("Arrivals  $\\lambda_b(t)$\n[veh/s]", "Current source  $i_b$\n[A]"),
        ("Queue  $q_b$\n[veh]", "Capacitor $C_{Bb}$ = 1 F\nvoltage $v_C$ [V]"),
        ("Green  $g_b\\in\\{0,1\\}$\n(controller output)", "MOSFET gate drive\n5 $\\mu$s dead-time"),
        ("Departures  $\\mu_b\\leq C_b$\n[veh/s]", "Controlled sink  $i_{dep}$\n[A]"),
    ]
    ys = [0.755, 0.55, 0.345, 0.14]
    bw, bh = 0.36, 0.13
    for (l, r), y in zip(rows, ys):
        box(ax, 0.02, y, bw, bh, l, fc="#fdf1e4", ec="#c8661a")
        box(ax, 0.62, y, bw, bh, r, fc="#eaf1fb", ec="#1b5fb0")
        arrow(ax, (0.02 + bw + 0.005, y + bh / 2), (0.62 - 0.005, y + bh / 2), style="<|-|>", color="#555555")
    for x in (0.02 + bw / 2, 0.62 + bw / 2):
        for y0, y1 in zip(ys[:-1], ys[1:]):
            arrow(ax, (x, y0 - 0.005), (x, y1 + bh + 0.005))
    ax.text(0.5, ys[0] + bh / 2 + 0.035, "1 veh = 1 C", ha="center", fontsize=6, style="italic")
    ax.text(0.5, ys[1] + bh / 2 + 0.035, "1 veh = 1 V", ha="center", fontsize=6, style="italic")
    ax.text(0.5, ys[2] + bh / 2 + 0.035, "gate on = green", ha="center", fontsize=6, style="italic")
    ax.text(0.5, ys[3] + bh / 2 + 0.035, "1 veh/s = 1 A", ha="center", fontsize=6, style="italic")
    box(ax, 0.02, 0.005, 0.96, 0.085,
        "Clearance time = first $t\\geq t_{event}$ at which the congested queue\n"
        "(or capacitor voltage) matches its no-congestion twin run",
        fc="#eef6ee", ec="#2e9a4f", fs=6.2)
    arrow(ax, (0.5, ys[3] - 0.005), (0.5, 0.095), color="#2e9a4f")
    fig.savefig(OUT + "f1_mapping.png", bbox_inches="tight", pad_inches=0.03)
    plt.close(fig)


# ---------------------------------------------------------------- Fig 2: power path
def fig_power():
    fig, ax = plt.subplots(figsize=(W, 2.35))
    ax.set_xlim(0, 1); ax.set_ylim(0, 1); ax.axis("off")
    bw, bh = 0.285, 0.21
    top = [(0.01, "230 V rms\n50 Hz mains"), (0.357, "Transformer +\nbridge rectifier"), (0.705, "DC link\n47.31 V mean")]
    bot = [(0.705, "24 V buck\n(closed loop)"), (0.357, "Bus  23.98 V\n(22.06-25.63 V)"), (0.01, "3 MOSFET\nchannels, 1 A")]
    y1, y2 = 0.70, 0.30
    for x, t in top: box(ax, x, y1, bw, bh, t, fc="#eaf1fb")
    for x, t in bot: box(ax, x, y2, bw, bh, t, fc="#eef6ee", ec="#2e9a4f")
    for i in range(2):
        arrow(ax, (top[i][0] + bw, y1 + bh / 2), (top[i + 1][0], y1 + bh / 2))
        arrow(ax, (bot[i][0], y2 + bh / 2), (bot[i + 1][0] + bw, y2 + bh / 2))
    arrow(ax, (top[2][0] + bw / 2, y1), (bot[0][0] + bw / 2, y2 + bh))
    box(ax, 0.01, 0.02, 0.98, 0.14,
        "Protection: under-voltage trip,\nover-current latch, spill-back clamp",
        fc="#fbeeee", ec="#b03030", fs=5.8)
    arrow(ax, (bot[2][0] + bw / 2, y2), (bot[2][0] + bw / 2, 0.165), ls=":", color="#b03030")
    fig.savefig(OUT + "f2_power.png", bbox_inches="tight", pad_inches=0.03)
    plt.close(fig)


# ---------------------------------------------------------------- Fig 3: T6 queues
def fig_t6():
    d = sio.loadmat(MAT, simplify_cells=True)
    fig, axs = plt.subplots(2, 1, figsize=(W, 3.6), sharex=True)
    for name in COL:
        R = d["T6"][name]["R"]
        t = np.asarray(R["tVec"]); Q = np.asarray(R["qHist"])[:, :3].sum(axis=1)
        mm = np.convolve(Q, np.ones(120) / 120, mode="same")
        mm[:60] = np.nan; mm[-60:] = np.nan
        axs[0].plot(t, Q, color=COL[name], lw=0.6, label=name)
        axs[1].plot(t, mm, color=COL[name], lw=1.0, label=name)
    for a in axs:
        a.axvspan(200, 400, color="#999999", alpha=0.18, lw=0)
        a.grid(True, color=GRID, lw=0.4); a.set_xlim(0, 600)
    axs[0].set_ylabel("Total queue B1+B2+B3 [veh]")
    axs[1].set_ylabel("120 s moving mean [veh]")
    axs[1].set_xlabel("Time [s]")
    axs[0].text(300, axs[0].get_ylim()[1] * 0.93, "surge 200-400 s", ha="center", fontsize=6)
    axs[0].legend(ncol=4, loc="lower center", bbox_to_anchor=(0.5, 1.0), frameon=False, handlelength=1.4, columnspacing=1.0)
    axs[0].text(0.01, 0.9, "(a)", transform=axs[0].transAxes, fontsize=7, fontweight="bold")
    axs[1].text(0.01, 0.9, "(b)", transform=axs[1].transAxes, fontsize=7, fontweight="bold")
    fig.tight_layout(h_pad=0.4)
    fig.savefig(OUT + "f3_t6.png", bbox_inches="tight", pad_inches=0.03)
    plt.close(fig)


# ---------------------------------------------------------------- Fig 4: clearance bars (R5)
def fig_clear():
    sc = ["T5", "T6", "T7", "T8"]
    mean = {"SITRA": [76.00, 106.00, 113.50, 643.75], "Webster": [np.nan, np.nan, 50.00, 522.50],
            "Actuated": [131.67, 63.00, 82.50, 484.40], "MaxPressure": [117.00, np.nan, np.nan, 736.00]}
    sd = {"SITRA": [0, 0, 20.51, 205.08], "Webster": [0, 0, 0, 195.87],
          "Actuated": [62.0, 0, 32.95, 117.29], "MaxPressure": [0, 0, 0, 125.87]}
    fig, ax = plt.subplots(figsize=(W, 2.5))
    x = np.arange(4); w = 0.2
    for i, n in enumerate(COL):
        xs = x + (i - 1.5) * w
        err = [e if not np.isnan(m) and e > 0 else np.nan for m, e in zip(mean[n], sd[n])]
        ax.bar(xs, np.nan_to_num(mean[n]), w, yerr=err, color=COL[n], label=n, lw=0, ecolor=INK,
               error_kw=dict(lw=0.5, capsize=1.2))
        for xx, m in zip(xs, mean[n]):
            if np.isnan(m):
                ax.text(xx, 12, "n/c", rotation=90, ha="center", va="bottom", fontsize=5.5, color="#b03030")
    ax.set_xticks(x); ax.set_xticklabels(sc)
    ax.set_ylabel("Clearance time [s]"); ax.set_xlabel("Scenario")
    ax.grid(True, axis="y", color=GRID, lw=0.4); ax.set_axisbelow(True)
    ax.legend(ncol=4, loc="lower center", bbox_to_anchor=(0.5, 1.0), frameon=False, handlelength=1.0, columnspacing=0.9)
    fig.tight_layout()
    fig.savefig(OUT + "f4_clear.png", bbox_inches="tight", pad_inches=0.03)
    plt.close(fig)


# ---------------------------------------------------------------- Fig 5: forest plot (R11)
def fig_forest():
    rows = [  # label, diff, lo, hi   (baseline minus SITRA delay; positive = SITRA better)
        ("T8  vs Webster", 9.95, 1.35, 18.55, "Webster"),
        ("T8  vs Actuated", -22.37, -30.37, -14.37, "Actuated"),
        ("T8  vs MaxPressure", 0.86, -6.82, 8.55, "MaxPressure"),
        ("T7  vs Webster", 8.57, -0.47, 17.60, "Webster"),
        ("T7  vs Actuated", -8.40, -15.97, -0.83, "Actuated"),
        ("T7  vs MaxPressure", -3.74, -9.29, 1.81, "MaxPressure"),
        ("T13 vs Webster", 5.23, 2.18, 8.28, "Webster"),
        ("T13 vs Actuated", 5.46, 3.75, 7.18, "Actuated"),
        ("T13 vs MaxPressure", 8.37, -0.23, 16.97, "MaxPressure"),
    ]
    fig, ax = plt.subplots(figsize=(W, 2.9))
    for i, (lab, m, lo, hi, c) in enumerate(rows):
        y = len(rows) - 1 - i
        ax.plot([lo, hi], [y, y], color=COL[c], lw=1.2)
        ax.plot(m, y, "o", color=COL[c], ms=3.5)
    ax.axvline(0, color=INK, lw=0.7)
    ax.set_yticks(range(len(rows))); ax.set_yticklabels([r[0] for r in rows][::-1])
    ax.set_xlabel("Delay difference, baseline minus SITRA [s/veh]")
    ax.grid(True, axis="x", color=GRID, lw=0.4)
    for yb in (5.5, 2.5): ax.axhline(yb, color=GRID, lw=0.5, ls="--")
    ax.set_xlim(-34, 22)
    ax.text(0.99, 1.02, "right of 0: SITRA has lower delay", transform=ax.transAxes, ha="right", va="bottom", fontsize=6, style="italic")
    fig.tight_layout()
    fig.savefig(OUT + "f5_forest.png", bbox_inches="tight", pad_inches=0.03)
    plt.close(fig)


def fig_map():
    im = Image.open("Report/figures/fig_site_map.png").convert("RGB")
    im.thumbnail((1100, 1100))
    im.save(OUT + "f0_site.jpg", quality=82, optimize=True)


if __name__ == "__main__":
    fig_mapping(); fig_power(); fig_t6(); fig_clear(); fig_forest(); fig_map()
    print("figures done")
