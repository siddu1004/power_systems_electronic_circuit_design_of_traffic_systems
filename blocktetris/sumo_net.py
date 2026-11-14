"""Build a SUMO network from the same OpenStreetMap extract the e-twin uses.

Same roads (same highway classes), same speeds (CLASS_SPEED), left-hand
traffic, and traffic signals at exactly the junctions CityNet marks as
signalised (OSM-tagged + the "major" inference), so the SUMO validation runs
on the same signal layout as the electrical twin.

    python -m blocktetris.sumo_net --osm data/osm/coimbatore_peelamedu.json --out sumo/peelamedu
"""
import argparse
import json
import os
import subprocess
from xml.sax.saxutils import quoteattr

from .city import CLASS_SPEED, CityNet


def sumo_bin(name):
    import sumo
    return os.path.join(sumo.SUMO_HOME, "bin", name)


def write_osm_xml(osm_json, out_xml, signal_nodes):
    d = json.load(open(osm_json))
    nodes = [e for e in d["elements"] if e["type"] == "node" and "lat" in e]
    ways = [e for e in d["elements"] if e["type"] == "way" and e.get("tags", {}).get("highway") in CLASS_SPEED]
    used = {n for w in ways for n in w["nodes"]}
    with open(out_xml, "w") as f:
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n<osm version="0.6" generator="blocktetris">\n')
        for n in nodes:
            if n["id"] not in used:
                continue
            f.write(f'  <node id="{n["id"]}" lat="{n["lat"]:.7f}" lon="{n["lon"]:.7f}" version="1"')
            if n["id"] in signal_nodes:
                f.write('>\n    <tag k="highway" v="traffic_signals"/>\n  </node>\n')
            else:
                f.write('/>\n')
        for w in ways:
            f.write(f'  <way id="{w["id"]}" version="1">\n')
            for n in w["nodes"]:
                f.write(f'    <nd ref="{n}"/>\n')
            tags = dict(w["tags"])
            tags["maxspeed"] = str(round(CLASS_SPEED[tags["highway"]] * 3.6))
            for k, v in tags.items():
                f.write(f'    <tag k={quoteattr(k)} v={quoteattr(str(v))}/>\n')
            f.write('  </way>\n')
        f.write('</osm>\n')


def build(osm_json, out_dir, tls_type="static"):
    os.makedirs(out_dir, exist_ok=True)
    net = CityNet.from_osm(osm_json)
    sig = {i for j in range(net.J) if net.signalised[j] for i in net.cluster_ids[j]}
    xml = os.path.join(out_dir, "map.osm.xml")
    write_osm_xml(osm_json, xml, sig)
    net_file = os.path.join(out_dir, "net.net.xml")
    cmd = [sumo_bin("netconvert"), "--osm-files", xml, "-o", net_file,
           "--lefthand", "true",
           "--geometry.remove", "--roundabouts.guess", "--ramps.guess",
           "--junctions.join", "--junctions.join-dist", "25",
           "--tls.join", "--tls.join-dist", "30",
           "--tls.guess", "false", "--tls.guess-signals", "false",
           "--tls.default-type", tls_type,
           "--tls.green.time", "40", "--tls.yellow.time", "3", "--tls.allred.time", "2",
           "--osm.speedlimit-none", "8.3",
           "--keep-edges.by-type", ",".join(f"highway.{c}" for c in CLASS_SPEED),
           "--remove-edges.isolated", "--keep-edges.components", "1",
           "--no-turnarounds", "false", "--no-warnings", "true", "--no-internal-links", "false"]
    subprocess.run(cmd, check=True)
    return net_file, net


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--osm", default="data/osm/coimbatore_peelamedu.json")
    ap.add_argument("--out", default="sumo/peelamedu")
    a = ap.parse_args()
    nf, net = build(a.osm, a.out)
    import sumolib
    sn = sumolib.net.readNet(nf)
    print(f"e-twin: {net.J} junctions, {int(net.signalised.sum())} signalised | "
          f"SUMO: {len(sn.getNodes())} nodes, {len(sn.getEdges())} edges, {len(sn.getTrafficLights())} TLS")


if __name__ == "__main__":
    main()
