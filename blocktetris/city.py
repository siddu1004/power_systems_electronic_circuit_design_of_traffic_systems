"""City-scale electrical equivalent built from OpenStreetMap.

Turns real roads into the same circuit the grid e-twin uses, with nothing
idealised away:
  * every junction where >= 3 road segments meet becomes a 4-slot junction
    (arms binned by compass bearing; T-junctions get an empty slot, which is
    wired to a dead "dummy" line so no current can flow there)
  * nodes closer than `merge_m` (dual-carriageway crossings) are one junction
  * every road segment between junctions becomes one delay line per direction
    with its real length (travel delay = length / class speed), real lanes and
    storage capacity length x lanes x weight-per-metre; one-way roads get one line
  * roads leaving the study area become gates (current sources) and exits
  * left / straight / right / U-turn in both directions, turn shares renormalised
    when a turn is physically impossible (missing arm or one-way)
  * junctions with an OSM traffic_signals node are signal-controlled; the others
    are priority (give-way) junctions, modelled as a short fixed alternation

    from blocktetris.city import CityNet
    net = CityNet.from_osm("data/osm/coimbatore_peelamedu.json")
"""
import json
import math
from collections import defaultdict

import numpy as np

from .geometry import MOVES
from .circuit import W_PER_M, RATIO, LANES, POCKET

CLASS_SPEED = {"trunk": 11.1, "primary": 9.7, "secondary": 8.3, "tertiary": 6.9,
               "trunk_link": 8.3, "primary_link": 8.3, "secondary_link": 6.9}
CLASS_LANES = {"trunk": 3, "primary": 2, "secondary": 2, "tertiary": 1,
               "trunk_link": 1, "primary_link": 1, "secondary_link": 1}
CLASS_RANK = {"trunk": 5, "primary": 4, "secondary": 3, "tertiary": 2,
              "trunk_link": 1, "primary_link": 1, "secondary_link": 1}


def haversine(a, b):
    R = 6371000.0
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    h = math.sin((la2 - la1) / 2) ** 2 + math.cos(la1) * math.cos(la2) * math.sin((lo2 - lo1) / 2) ** 2
    return 2 * R * math.asin(math.sqrt(h))


def bearing(a, b):
    la1, lo1, la2, lo2 = map(math.radians, (a[0], a[1], b[0], b[1]))
    x = math.sin(lo2 - lo1) * math.cos(la2)
    y = math.cos(la1) * math.sin(la2) - math.sin(la1) * math.cos(la2) * math.cos(lo2 - lo1)
    return (math.degrees(math.atan2(x, y)) + 360) % 360


class CityNet:
    """Same interface as circuit.Net, built from a real road graph."""

    @staticmethod
    def from_osm(path, merge_m=30.0, boundary_m=300.0, min_seg_m=15.0):
        d = json.load(open(path))
        nodes = {e["id"]: (e["lat"], e["lon"]) for e in d["elements"] if e["type"] == "node" and "lat" in e}
        signals = {e["id"] for e in d["elements"] if e["type"] == "node"
                   and e.get("tags", {}).get("highway") == "traffic_signals"}
        ways = [e for e in d["elements"] if e["type"] == "way" and e.get("tags", {}).get("highway") in CLASS_SPEED]
        use = defaultdict(int)
        for w in ways:
            ns = w["nodes"]
            for i, nid in enumerate(ns):
                use[nid] += 1 if i in (0, len(ns) - 1) else 2
        cand = [nid for nid, c in use.items() if c >= 3 and nid in nodes]
        cl_of, clusters = {}, []
        for nid in cand:
            p = nodes[nid]
            for ci, c in enumerate(clusters):
                if haversine(p, c["pos"]) < merge_m:
                    c["ids"].append(nid)
                    k = len(c["ids"])
                    c["pos"] = ((c["pos"][0] * (k - 1) + p[0]) / k, (c["pos"][1] * (k - 1) + p[1]) / k)
                    cl_of[nid] = ci
                    break
            else:
                cl_of[nid] = len(clusters)
                clusters.append({"ids": [nid], "pos": p})
        segs = []
        for w in ways:
            t = w["tags"]
            cls = t["highway"]
            ow = t.get("oneway", "no")
            if t.get("junction") == "roundabout":
                ow = "yes"
            ns = [x for x in w["nodes"] if x in nodes]
            if ow == "-1":
                ns, ow = ns[::-1], "yes"
            try:
                lanes_total = max(1, int(str(t.get("lanes")).split(";")[0]))
            except ValueError:
                lanes_total = None
            start = 0
            for i in range(1, len(ns)):
                if ns[i] in cl_of or i == len(ns) - 1:
                    piece = ns[start:i + 1]
                    length = sum(haversine(nodes[piece[k]], nodes[piece[k + 1]]) for k in range(len(piece) - 1))
                    a, b = cl_of.get(piece[0]), cl_of.get(piece[-1])
                    if not (a is not None and a == b) and length >= min_seg_m and len(piece) >= 2:
                        segs.append(dict(a=a, b=b, pa=nodes[piece[0]], pa2=nodes[piece[1]],
                                         pb=nodes[piece[-1]], pb2=nodes[piece[-2]], length=length,
                                         cls=cls, oneway=(ow == "yes"), name=t.get("name", ""),
                                         lanes=lanes_total))
                    start = i
        net = CityNet()
        net.J = len(clusters)
        net.pos = [c["pos"] for c in clusters]
        net.signalised = np.array([any(i in signals for i in c["ids"]) for c in clusters])
        net._build(segs, boundary_m)
        return net

    def _build(self, segs, boundary_m):
        J = self.J
        arms = [dict() for _ in range(J)]
        dropped = 0

        def place(j, brg, info):
            nonlocal dropped
            pref = int(((brg + 45) % 360) // 90)       # 0=N,1=E,2=S,3=W
            order = sorted(range(4), key=lambda s: min((s * 90 - brg) % 360, (brg - s * 90) % 360))
            for s in [pref] + order:
                if s not in arms[j]:
                    arms[j][s] = info
                    return s
            weakest = min(arms[j], key=lambda s: CLASS_RANK[arms[j][s]["cls"]])
            dropped += 1
            if CLASS_RANK[info["cls"]] > CLASS_RANK[arms[j][weakest]["cls"]]:
                arms[j][weakest] = info
                return weakest
            return None

        ends = []
        for k, s in enumerate(segs):
            ea = place(s["a"], bearing(s["pa"], s["pa2"]), dict(seg=k, cls=s["cls"])) if s["a"] is not None else None
            eb = place(s["b"], bearing(s["pb"], s["pb2"]), dict(seg=k, cls=s["cls"])) if s["b"] is not None else None
            ends.append((ea, eb))
        # an arm slot may have been taken over by a stronger road: honour only the owner
        owner = {(j, sl): info["seg"] for j in range(J) for sl, info in arms[j].items()}
        cap0, src, dst, kind, Dl, names, lanes_l = [], [], [], [], [], [], []
        self.out_line = -np.ones((J, 4), int)
        self.in_line = -np.ones((J, 4), int)

        def add(c, sr, ds, k, D, nm, ln):
            cap0.append(c); src.append(sr); dst.append(ds); kind.append(k); Dl.append(D)
            names.append(nm); lanes_l.append(ln)
            return len(cap0) - 1

        for k, s in enumerate(segs):
            ea, eb = ends[k]
            okA = s["a"] is None or (ea is not None and owner.get((s["a"], ea)) == k)
            okB = s["b"] is None or (eb is not None and owner.get((s["b"], eb)) == k)
            if not (okA and okB):
                continue
            if s["lanes"]:
                per_dir = s["lanes"] if s["oneway"] else max(1, s["lanes"] // 2)
            else:
                per_dir = CLASS_LANES[s["cls"]]
            spd = CLASS_SPEED[s["cls"]]
            L_m = s["length"]
            dirs = ["ab"] if s["oneway"] else ["ab", "ba"]
            for dr in dirs:
                fa, fe = (s["a"], ea) if dr == "ab" else (s["b"], eb)
                ta, te = (s["b"], eb) if dr == "ab" else (s["a"], ea)
                if fa is None and ta is None:
                    continue
                if fa is None:
                    if self.in_line[ta, te] >= 0:
                        continue
                    l = add(boundary_m * per_dir * W_PER_M, (-1, -1), (ta, te), "gate",
                            max(2, round(boundary_m / spd)), s["name"], per_dir)
                    self.in_line[ta, te] = l
                elif ta is None:
                    if self.out_line[fa, fe] >= 0:
                        continue
                    l = add(boundary_m * per_dir * W_PER_M, (fa, fe), (-1, -1), "sink",
                            max(2, round(boundary_m / spd)), s["name"], per_dir)
                    self.out_line[fa, fe] = l
                else:
                    if self.out_line[fa, fe] >= 0 or self.in_line[ta, te] >= 0:
                        continue
                    l = add(max(L_m, 20.0) * per_dir * W_PER_M, (fa, fe), (ta, te), "inner",
                            max(2, round(L_m / spd)), s["name"], per_dir)
                    self.out_line[fa, fe] = l
                    self.in_line[ta, te] = l
        dummy = add(1e-6, (-1, -1), (-1, -1), "dummy", 2, "(no road)", 1)
        self.out_line[self.out_line < 0] = dummy
        self.in_line[self.in_line < 0] = dummy
        self.dummy = dummy
        self.L = len(cap0)
        self.cap0 = np.array(cap0, float)
        self.src, self.dst, self.kind = src, dst, np.array(kind)
        self.Dl = np.array(Dl, int)
        self.Dmax = int(self.Dl.max())
        self.D = self.Dmax
        self.names = names
        self.lanes_l = np.array(lanes_l)
        self.dropped_arms = dropped
        self.G = J * 16
        m_arm = np.array([MOVES[m][0] for m in range(16)])
        m_turn = np.array([m % 4 for m in range(16)])
        m_to = np.array([MOVES[m][2] for m in range(16)])
        self.g_j = np.repeat(np.arange(J), 16)
        self.g_turn = np.tile(m_turn, J)
        self.g_lanes = LANES[self.g_turn]
        self.g_pocket = POCKET[self.g_turn]
        self.g_exit = np.array([self.out_line[j, m_to[m]] for j in range(J) for m in range(16)])
        self.g_in = np.array([self.in_line[j, m_arm[m]] for j in range(J) for m in range(16)])
        self.line_moves = -np.ones((self.L, 4), int)
        self.base_ratio = np.zeros((self.L, 4))
        for l in range(self.L):
            j, a = self.dst[l]
            if j >= 0:
                self.line_moves[l] = j * 16 + a * 4 + np.arange(4)
                r = RATIO.copy()
                for k in range(4):
                    if self.out_line[j, MOVES[a * 4 + k][2]] == dummy:
                        r[k] = 0.0          # impossible turn (missing arm / one-way)
                self.base_ratio[l] = r / r.sum() if r.sum() > 0 else r
        self.gates = np.where(self.kind == "gate")[0]
        self.sinks = np.where(self.kind == "sink")[0]
        self.inner = np.where(self.kind == "inner")[0]
        self.down_out = []
        for l in range(self.L):
            j, a = self.dst[l]
            self.down_out.append([self.out_line[j, b] for b in range(4)
                                  if b != a and self.out_line[j, b] != dummy] if j >= 0 else [])
        self.arm_present = self.in_line != dummy
        self.priority = set(np.where(~self.signalised)[0].tolist())

    def line_name(self, l):
        return self.names[l] or f"road {l}"

    def summary(self):
        inner = self.inner
        km = float(sum(self.cap0[l] / (W_PER_M * self.lanes_l[l]) for l in inner) / 1000)
        return {"junctions": int(self.J), "signalised": int(self.signalised.sum()),
                "directed_roads": int(len(inner)), "gates": int(len(self.gates)),
                "exits": int(len(self.sinks)), "dropped_arms": int(self.dropped_arms),
                "directed_road_km": round(km, 1), "max_travel_delay_s": int(self.Dmax)}
