"""Four-arm junction geometry, the conflict matrix and the compatible phase sets.

Arms are indexed clockwise: 0=N, 1=E, 2=S, 3=W. Traffic keeps LEFT (India),
so a left turn from arm a exits at arm a+1, straight at a+2, right at a+3 and a
U-turn returns to arm a.

Each movement is drawn as a chord on a circle around the junction box, from its
entry point to its exit point. Two movements conflict when their chords cross
(crossing conflict) or end at the same exit (merge conflict). Movements from
the same approach diverge and never conflict. A U-turn sweeps the same area as
a right turn, so it inherits the right turn's crossing conflicts and merges into
its own arm's outbound road.
"""
from itertools import combinations

TURNS = ("L", "S", "R", "U")
_OFFSET = {"L": 1, "S": 2, "R": 3, "U": 0}
_ANGLE = (90, 0, 270, 180)
_D = 10  # entry/exit offset in degrees; inbound sits clockwise under LHT

# MOVES[i] = (from_arm, turn, to_arm); index = arm*4 + turn index
MOVES = [(a, k, (a + _OFFSET[k]) % 4) for a in range(4) for k in TURNS]
N_MOVES = len(MOVES)


def _in_pt(a):
    return (_ANGLE[a] - _D) % 360


def _out_pt(b):
    return (_ANGLE[b] + _D) % 360


def _chord(m):
    a, k, b = m
    if k == "U":
        return (_in_pt(a), _out_pt((a + 3) % 4))
    return (_in_pt(a), _out_pt(b))


def _cross(c1, c2):
    p1, q1 = c1
    p2, q2 = c2
    if len({p1, q1, p2, q2}) < 4:
        return False  # shared endpoint: touching, not crossing

    def inside(x):
        return 0 < (x - p1) % 360 < (q1 - p1) % 360

    return inside(p2) != inside(q2)


def conflicts(i, j):
    if i == j:
        return False
    a1, _, b1 = MOVES[i]
    a2, _, b2 = MOVES[j]
    if b1 == b2:
        return True
    if a1 == a2:
        return False
    return _cross(_chord(MOVES[i]), _chord(MOVES[j]))


CONFLICT = [[conflicts(i, j) for j in range(N_MOVES)] for i in range(N_MOVES)]
_CMASK = [sum(1 << j for j in range(N_MOVES) if CONFLICT[i][j]) for i in range(N_MOVES)]


def is_compatible(moves):
    return not any(CONFLICT[i][j] for i, j in combinations(moves, 2))


def _maximal_sets():
    """All maximal conflict-free movement sets (the Tetris pieces)."""
    sets = []

    def grow(chosen, banned, start):
        extended = False
        for m in range(N_MOVES):
            if not (banned >> m) & 1 and not (chosen >> m) & 1:
                extended = True
                if m >= start:
                    grow(chosen | (1 << m), banned | _CMASK[m], m + 1)
        if not extended:
            sets.append(chosen)

    grow(0, 0, 0)
    uniq = sorted(set(sets))
    return [frozenset(m for m in range(N_MOVES) if (s >> m) & 1) for s in uniq]


PHASES = _maximal_sets()
# Classic Indian split phasing: one arm at a time, all its movements
SPLIT_PHASES = [frozenset(a * 4 + t for t in range(4)) for a in range(4)]


def move_name(i):
    a, k, b = MOVES[i]
    return f"{'NESW'[a]}{k}"
