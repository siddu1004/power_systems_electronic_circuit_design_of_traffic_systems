"""Fetch a road network from the OpenStreetMap map API in polite tiles and save it
in the Overpass-JSON layout CityNet.from_osm reads (major roads + signal nodes).

    python -m blocktetris.osm_fetch --bbox 76.995,11.012,77.055,11.048 --out data/osm/coimbatore_peelamedu.json
"""
import argparse
import json
import subprocess
import time
import xml.etree.ElementTree as ET

KEEP = {"trunk", "primary", "secondary", "tertiary", "trunk_link", "primary_link", "secondary_link"}


def fetch_tile(w, s, e, n, tries=4):
    url = f"https://api.openstreetmap.org/api/0.6/map?bbox={w},{s},{e},{n}"
    for k in range(tries):
        r = subprocess.run(["curl", "-sS", "-m", "90", "-A", "blocktetris-research/1.0", url],
                           capture_output=True)
        if r.returncode == 0 and r.stdout.startswith(b"<?xml"):
            return r.stdout
        time.sleep(5 * (k + 1))
    raise RuntimeError(f"tile {w},{s},{e},{n} failed")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--bbox", default="76.995,11.012,77.055,11.048")
    ap.add_argument("--step", type=float, default=0.01)
    ap.add_argument("--out", default="data/osm/coimbatore_peelamedu.json")
    a = ap.parse_args()
    W, S, E, N = map(float, a.bbox.split(","))
    nodes, ways, signals = {}, {}, set()
    lon = W
    while lon < E - 1e-9:
        lat = S
        while lat < N - 1e-9:
            xml = fetch_tile(round(lon, 4), round(lat, 4), round(min(lon + a.step, E), 4), round(min(lat + a.step, N), 4))
            root = ET.fromstring(xml)
            for nd in root.iter("node"):
                i = int(nd.get("id"))
                nodes[i] = (float(nd.get("lat")), float(nd.get("lon")))
                for t in nd.iter("tag"):
                    if t.get("k") == "highway" and t.get("v") == "traffic_signals":
                        signals.add(i)
            for w in root.iter("way"):
                tags = {t.get("k"): t.get("v") for t in w.iter("tag")}
                if tags.get("highway") in KEEP:
                    ways[int(w.get("id"))] = dict(nodes=[int(x.get("ref")) for x in w.iter("nd")], tags=tags)
            print(f"tile {lon:.3f},{lat:.3f}: {len(ways)} roads so far", flush=True)
            time.sleep(1.0)
            lat += a.step
        lon += a.step
    used = {i for w in ways.values() for i in w["nodes"]}
    el = [{"type": "node", "id": i, "lat": nodes[i][0], "lon": nodes[i][1],
           **({"tags": {"highway": "traffic_signals"}} if i in signals else {})} for i in used if i in nodes]
    el += [{"type": "way", "id": k, "nodes": v["nodes"], "tags": v["tags"]} for k, v in ways.items()]
    json.dump({"source": "OpenStreetMap contributors (ODbL), api.openstreetmap.org", "bbox": a.bbox,
               "elements": el}, open(a.out, "w"))
    print(f"saved {len(ways)} roads, {len(used)} nodes, {len(signals & used)} signals -> {a.out}")


if __name__ == "__main__":
    main()
