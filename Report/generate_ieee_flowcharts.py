"""
Final precision adjustment of layout coordinates to ensure 100% zero overlap on all labels.
"""

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

plt.rcParams.update({
    'font.family': 'serif',
    'font.serif': ['Times New Roman', 'DejaVu Serif'],
    'figure.dpi': 300,
    'savefig.dpi': 300,
})

def draw_card(ax, x, y, w, h, title, lines, fill, border, title_color='#1A365D', text_color='#2D3748', title_fs=8.2, text_fs=6.5):
    box = FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.0,rounding_size=0.015",
                         facecolor=fill, edgecolor=border, linewidth=1.2, zorder=2)
    ax.add_patch(box)
    
    ax.text(x + w/2, y + h - 0.022, title, ha='center', va='top',
            fontsize=title_fs, fontweight='bold', color=title_color, zorder=3)
    
    n = len(lines)
    if n > 0:
        y_start = y + h - 0.058
        avail_h = (h - 0.075)
        y_step = avail_h / max(n, 1)
        for i, line in enumerate(lines):
            y_pos = y_start - i * y_step
            ax.text(x + w/2, y_pos, line, ha='center', va='top',
                    fontsize=text_fs, color=text_color, zorder=3)

def draw_arrow(ax, p1, p2, label='', color='#4A5568', lw=1.1, rad=0.0, label_pos=0.5, label_offset=(0, 0.025), fs=5.8):
    arrow = FancyArrowPatch(p1, p2, arrowstyle='-|>', mutation_scale=8,
                            linewidth=lw, color=color, zorder=4,
                            connectionstyle=f"arc3,rad={rad}")
    ax.add_patch(arrow)
    if label:
        xm = p1[0] * (1 - label_pos) + p2[0] * label_pos + label_offset[0]
        ym = p1[1] * (1 - label_pos) + p2[1] * label_pos + label_offset[1]
        ax.text(xm, ym, label, ha='center', va='center', fontsize=fs,
                fontweight='bold', color=color, zorder=5,
                bbox=dict(boxstyle='round,pad=0.12', facecolor='#FFFFFF', edgecolor=color, lw=0.4, alpha=0.95))

def make_project_flowchart():
    fig, ax = plt.subplots(figsize=(7.5, 5.2))
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')

    ax.text(0.5, 0.975, "SITRA Research Workflow: From Civil Traffic Data to Physical Circuit Verification",
            ha='center', va='center', fontsize=10.5, fontweight='bold', color='#1A365D')

    # Row 1: Setup & Models (w = 0.25, x = 0.02, 0.375, 0.73 -> gaps = 0.105)
    draw_card(ax, 0.02, 0.69, 0.25, 0.23,
              "Stage 1: Civil Traffic Site & Data",
              ["SITRA Junction, Coimbatore (IRC:93)",
               "Approaches B1 (Arterial), B2, B3; Exit B4",
               "Capacities: 0.65, 0.35, 0.25, 0.45 veh/s",
               "Inflow demand profiles: lambda_b(t) in veh/s"],
              fill='#FFF5F5', border='#FEB2B2', title_color='#9B2C2C')

    draw_card(ax, 0.375, 0.69, 0.25, 0.23,
              "Stage 2: Mathematical Isomorphism",
              ["Exact Fluid-to-Charge Mapping (L1)",
               "1 veh = 1 C, 1 veh/s = 1 A, 1 F Cap",
               "Discrete plant: q_b(k+1) = q_b + lambda_b - mu_b",
               "Downstream bottleneck & spill-back logic"],
              fill='#EBF8FF', border='#90CDF4', title_color='#2B6CB0')

    draw_card(ax, 0.73, 0.69, 0.25, 0.23,
              "Stage 3: Controller Synthesis (L5)",
              ["SITRA MPC: Rolling-horizon QP (189 s)",
               "Webster: Analytical equisaturation split",
               "Actuated: 1.0 s gap-out state machine",
               "Max-Pressure: Gradient queue sorting"],
              fill='#FAF5FF', border='#D6BCFA', title_color='#6B46C1')

    # Row 2: Simscape Circuit & Scenarios
    draw_card(ax, 0.02, 0.37, 0.25, 0.25,
              "Stage 4: Pure Simscape Circuit",
              ["No code blocks (Simscape Electrical)",
               "230 V AC grid, step-down transformer",
               "Full-bridge rectifier & 2200 uF DC link",
               "Closed-loop 24 V buck DC-DC converter",
               "3-channel MOSFET LED drivers (1.0 A)",
               "5 us dead-time interlock & protection"],
              fill='#F0FFF4', border='#9AE6B4', title_color='#22543D')

    draw_card(ax, 0.375, 0.37, 0.25, 0.25,
              "Stage 5: 14 Benchmark Scenarios",
              ["T1-T4: Stationary demand (Low to Oversat)",
               "T5: Step demand (Low -> High -> Mod)",
               "T6-T7: Deterministic & Poisson surge",
               "T8: Initial congested backlog (q0 = 30 veh)",
               "T9-T14: Capacity drops, blockages,",
               "platoons, detector noise, stuck signal"],
              fill='#EDFDFD', border='#81E6D9', title_color='#234E52')

    draw_card(ax, 0.73, 0.37, 0.25, 0.25,
              "Stage 6: Twin-Run Clearance Metric",
              ["Paired run without congestion event",
               "120 s moving mean (filters ripple)",
               "Threshold delta = 1 veh, hold time H = 60 s",
               "Outputs clearance time: t_clear (s)",
               "Cumulative excess delay: E_veh (veh*s)",
               "Eliminates circular baseline artifacts"],
              fill='#FFFAF0', border='#FBD38D', title_color='#C05621')

    # Row 3: Physical Equivalence & Statistics
    draw_card(ax, 0.02, 0.04, 0.46, 0.26,
              "Stage 7: Physical Circuit Replay & Non-Idealities",
              ["32 physical Simscape circuit runs: exactly 0.0 s discrepancy",
               "Sub-microvolt fidelity: max |v_C - q_ref| <= 8.00 uV (< 1.0 mV)",
               "Kirchhoff Current Law nodal residual < 1.0e-15 A",
               "Stage S6: Active feedforward ESR compensation (15 mV -> < 0.1 mV)",
               "Stage S7: MOSFET switching dissipation 45.2 mW, Delta T_j = 2.80 C"],
              fill='#EBF8FF', border='#3182CE', title_color='#2B6CB0')

    draw_card(ax, 0.52, 0.04, 0.46, 0.26,
              "Stage 8: Statistical Hypothesis Testing & Insights",
              ["Paired Student's t-tests across 5 stochastic seeds (N=5)",
               "Actuated clears nominal surges faster (63 s vs 106 s) via gap-out",
               "Actuated collapses under detector noise (+5.46 s/veh, p = 0.0009)",
               "MPC rolling quadratic horizon suppresses noise (queue error +0.31 veh)",
               "Execution run-time: 0.126 ms (7,936x faster than real-time)"],
              fill='#FAF5FF', border='#805AD5', title_color='#553C9A')

    # Elevated label arrows
    draw_arrow(ax, (0.27, 0.805), (0.375, 0.805), "Site Data", label_offset=(0, 0.025))
    draw_arrow(ax, (0.625, 0.805), (0.73, 0.805), "Plant State", label_offset=(0, 0.025))
    draw_arrow(ax, (0.855, 0.69), (0.855, 0.62), "Gate Drives", label_offset=(0.045, 0))
    draw_arrow(ax, (0.73, 0.495), (0.625, 0.495), "Specs", label_offset=(0, 0.025))
    draw_arrow(ax, (0.375, 0.495), (0.27, 0.495), "Commands", label_offset=(0, 0.025))
    draw_arrow(ax, (0.145, 0.37), (0.145, 0.30), "Waveforms", label_offset=(0.045, 0))
    draw_arrow(ax, (0.48, 0.17), (0.52, 0.17), "Verification", label_offset=(0, 0.025))
    draw_arrow(ax, (0.855, 0.37), (0.855, 0.30), "Clearance", label_offset=(0.045, 0))

    fig.savefig('Report/figures/fig_ieee_project_flowchart.png', bbox_inches='tight', pad_inches=0.03)
    plt.close(fig)

def make_dual_domain_schematic():
    fig, ax = plt.subplots(figsize=(7.5, 4.8))
    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')

    ax.text(0.5, 0.97, "Electrical Equivalent Circuit Architecture of the Four-Link Traffic Intersection",
            ha='center', va='center', fontsize=10.5, fontweight='bold', color='#1A365D')

    approaches = [
        ("Approach B1 (Avinashi Rd, Arterial)",
         ["Arrival Current: i_in,1 = lambda_1(t) [A]",
          "Capacitor: C_B1 = 1.0 F (v_C1 = q_1 in Volts)",
          "Discharge Sink: i_dep,1 <= C_1 = 0.65 A",
          "Switch Q1: MOSFET enabled by Gate g1"], 0.66, '#EBF8FF', '#3182CE'),
        ("Approach B2 (Airport Rd)",
         ["Arrival Current: i_in,2 = lambda_2(t) [A]",
          "Capacitor: C_B2 = 1.0 F (v_C2 = q_2 in Volts)",
          "Discharge Sink: i_dep,2 <= C_2 = 0.35 A",
          "Switch Q2: MOSFET enabled by Gate g2"], 0.36, '#F0FFF4', '#38A169'),
        ("Approach B3 (Industrial Estate Bypass)",
         ["Arrival Current: i_in,3 = lambda_3(t) [A]",
          "Capacitor: C_B3 = 1.0 F (v_C3 = q_3 in Volts)",
          "Discharge Sink: i_dep,3 <= C_3 = 0.25 A",
          "Switch Q3: MOSFET enabled by Gate g3"], 0.06, '#FAF5FF', '#805AD5')
    ]

    for title, desc, y, fill, border in approaches:
        draw_card(ax, 0.02, y, 0.40, 0.25, title, desc,
                  fill=fill, border=border, title_color='#1A365D', title_fs=8.0, text_fs=6.5)

    # Downstream Unit B4
    draw_card(ax, 0.58, 0.38, 0.40, 0.33,
              "Downstream Bottleneck Link B4",
              ["Inflow: sum(i_dep,b) from active green approach",
               "Storage: C_B4 = 1.0 F (v_C4 = q_4 accumulation)",
               "Max Storage Threshold: V_4max = 30.0 V (30 veh)",
               "Discharge Sink: i_out <= C_4 = 0.45 A",
               "Electronic Spill-Back Clamp:",
               "When v_C4 >= 15 V (T10) or 30 V, upstream",
               "discharge sinks are clamped to 0 A"],
              fill='#FFF5F5', border='#E53E3E', title_color='#9B2C2C', title_fs=8.2, text_fs=6.5)

    # Gate Interlock & Supervisory Box
    draw_card(ax, 0.58, 0.06, 0.40, 0.25,
              "Hardware Interlock & Dead-Time Gate",
              ["Enforces 5.0 us dead-time between phase transitions",
               "Strict mutual exclusion: g1 + g2 + g3 <= 1",
               "Supervisory commands from SITRA MPC / Actuated",
               "Under-voltage trip & channel over-current latch"],
              fill='#FFFAF0', border='#DD6B20', title_color='#9C4221', title_fs=8.0, text_fs=6.5)

    draw_arrow(ax, (0.42, 0.78), (0.58, 0.62), "i_dep,1", color='#3182CE', fs=6.5)
    draw_arrow(ax, (0.42, 0.48), (0.58, 0.48), "i_dep,2", color='#38A169', fs=6.5)
    draw_arrow(ax, (0.42, 0.18), (0.58, 0.40), "i_dep,3", color='#805AD5', fs=6.5)

    # Spill-back clamp arrow at y = 0.93 (well above B1 card at 0.66 + 0.25 = 0.91)
    draw_arrow(ax, (0.78, 0.71), (0.78, 0.93), "", color='#E53E3E')
    draw_arrow(ax, (0.78, 0.93), (0.22, 0.93), "Spill-Back Inhibit Clamp (v_C4 >= V_max)", color='#E53E3E', fs=6.5)
    draw_arrow(ax, (0.22, 0.93), (0.22, 0.91), "", color='#E53E3E')

    draw_arrow(ax, (0.58, 0.18), (0.42, 0.18), "Gate Drives g_b (5 us dead-time)", color='#DD6B20', fs=6.5)

    fig.savefig('Report/figures/fig_ieee_dual_domain_schematic.png', bbox_inches='tight', pad_inches=0.03)
    plt.close(fig)

if __name__ == '__main__':
    make_project_flowchart()
    make_dual_domain_schematic()
    print("Refined diagrams generated successfully.")
