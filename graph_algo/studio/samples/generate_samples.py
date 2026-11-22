#!/usr/bin/env python3
"""Generate sample graphs for the graph_algo visualizer.

Each file is a document in the app's save format
(``{"directed", "nodes":[{label,x,y}], "edges":[{from,to,weight}]}``) that can
be opened with **Load…**.

Layout: the main component is a lightly-jittered grid whose edges connect
spatially-near vertices (short edges that are easy to trace on the canvas); a
small, clearly-separated cluster off to the right is left disconnected from it,
so those vertices are **unreachable** from the default source (vertex 0, which
is always in the main component). Edge weights are distance-based so the
shortest-path algorithms behave the way the picture suggests.
"""

import json
import math
import random

SPACING = 80.0          # grid cell size (world px)
JITTER = 20.0           # +/- positional noise so it doesn't look rigid
GAP = 320.0             # clear gap between main component and the stray cluster
WEIGHT_SCALE = 25.0     # weight = max(1, round(distance / WEIGHT_SCALE))


def build(n_total, n_edges, n_unreach, seed):
    random.seed(seed)
    m = n_total - n_unreach               # main-component vertex count
    nodes = []                            # (label, x, y)

    # --- main component: a near-square jittered grid --------------------
    cols = max(1, round(math.sqrt(m)))
    rows = math.ceil(m / cols)
    for i in range(m):
        r, c = divmod(i, cols)
        x = c * SPACING + random.uniform(-JITTER, JITTER)
        y = r * SPACING + random.uniform(-JITTER, JITTER)
        nodes.append((str(i), x, y))
    main_w = cols * SPACING

    # --- unreachable cluster: its own little grid, pushed to the side ---
    ucols = max(1, round(math.sqrt(n_unreach)))
    urows = math.ceil(n_unreach / ucols)
    base_x = main_w + GAP
    base_y = (rows * SPACING) / 2 - (urows * SPACING) / 2
    for i in range(n_unreach):
        r, c = divmod(i, ucols)
        x = base_x + c * SPACING + random.uniform(-JITTER, JITTER)
        y = base_y + r * SPACING + random.uniform(-JITTER, JITTER)
        nodes.append(("x" + str(i), x, y))

    pos = [(nd[1], nd[2]) for nd in nodes]
    edges = []
    used = set()

    def dist(a, b):
        return math.hypot(pos[a][0] - pos[b][0], pos[a][1] - pos[b][1])

    def add(a, b):
        if a == b:
            return False
        key = (a, b) if a < b else (b, a)
        if key in used:
            return False
        used.add(key)
        w = max(1, round(dist(a, b) / WEIGHT_SCALE))
        edges.append((a, b, w))
        return True

    # Spanning structure so each component is fully connected.
    #   main: link each vertex to its left neighbour, or the first column's
    #         vertex above it (a connected "comb" of m-1 edges).
    for i in range(m):
        r, c = divmod(i, cols)
        if c > 0:
            add(i, i - 1)
        elif r > 0:
            add(i, (r - 1) * cols)
    #   cluster: a simple chain of u-1 edges.
    for i in range(1, n_unreach):
        add(m + i, m + i - 1)

    remaining = n_edges - len(edges)
    if remaining < 0:
        raise ValueError(f"target {n_edges} < spanning edges {len(edges)}")

    # Split the extra (cycle-forming) edges between the two components.
    cluster_extra = min(max(n_unreach // 3, 2), remaining,
                        n_unreach * (n_unreach - 1) // 2 - (n_unreach - 1))
    main_extra = remaining - cluster_extra

    def short_pairs(lo, hi, radius):
        """Unused (i<j) pairs within `radius`, in random order."""
        pairs = []
        idxs = list(range(lo, hi))
        for ai, a in enumerate(idxs):
            for b in idxs[ai + 1:]:
                if (a, b) not in used and dist(a, b) <= radius:
                    pairs.append((a, b))
        random.shuffle(pairs)
        return pairs

    def add_extra(lo, hi, count):
        added = 0
        radius = SPACING * 2.3                       # neighbours + diagonals
        while added < count:
            for a, b in short_pairs(lo, hi, radius):
                if add(a, b):
                    added += 1
                    if added >= count:
                        break
            else:
                radius += SPACING                    # widen if we ran dry
                if radius > SPACING * 12:
                    break
        # last resort: any remaining pair (keeps the count exact)
        while added < count:
            a, b = random.randrange(lo, hi), random.randrange(lo, hi)
            if add(a, b):
                added += 1
        return added

    add_extra(0, m, main_extra)
    if n_unreach > 1:
        add_extra(m, n_total, cluster_extra)

    return nodes, edges


def to_document(nodes, edges):
    return {
        "directed": False,
        "nodes": [{"label": lb, "x": round(x, 1), "y": round(y, 1)} for lb, x, y in nodes],
        "edges": [{"from": a, "to": b, "weight": w} for a, b, w in edges],
    }


SPECS = [
    # (filename, vertices, edges, unreachable, seed)
    ("sample_100.json",  100,  200,  8, 1),
    ("sample_200.json",  200,  400, 12, 2),
    ("sample_500.json",  500,  800, 20, 3),
    ("sample_1000.json", 1000, 1200, 30, 4),
]


def main():
    import os
    here = os.path.dirname(os.path.abspath(__file__))
    for name, n, e, u, seed in SPECS:
        nodes, edges = build(n, e, u, seed)
        assert len(nodes) == n, (name, len(nodes))
        assert len(edges) == e, (name, len(edges))
        doc = to_document(nodes, edges)
        path = os.path.join(here, name)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(doc, f, indent=2)
        print(f"{name}: {len(nodes)} vertices, {len(edges)} edges "
              f"({u} unreachable from vertex 0)")


if __name__ == "__main__":
    main()
