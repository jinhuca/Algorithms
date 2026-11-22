# Sample graphs

Pre-built graphs for quickly exercising the algorithms at different scales.
Open one with **Load…** in the app, then pick an algorithm and **Run**.

| File | Vertices | Edges | Unreachable from vertex 0 |
|------|---------:|------:|--------------------------:|
| `sample_100.json`  |  100 |  200 |  8 |
| `sample_200.json`  |  200 |  400 | 12 |
| `sample_500.json`  |  500 |  800 | 20 |
| `sample_1000.json` | 1000 | 1200 | 30 |

## Layout & structure

- The **main component** is a lightly-jittered grid whose edges mostly connect
  spatially-near vertices, so the graph is easy to follow on the canvas (use
  **Fit** to frame it). Vertex `0` — the default **Source** — is in this
  component, and every vertex in it is reachable from `0`.
- A small **unreachable cluster** (labels `x0`, `x1`, …) sits off to the right
  with a clear gap and has no edge to the main component, so those vertices stay
  idle on any run from vertex `0`. This is handy for seeing how BFS/DFS/Dijkstra
  leave unreachable vertices uncoloured and for testing the **Path to** highlight
  (an unreachable target reports "unreachable from 0").
- Edges are **undirected** with positive, distance-based integer weights, so the
  weighted shortest-path algorithms (Dijkstra, Bellman–Ford) follow the picture.

## Regenerating

These files are produced deterministically (fixed seeds) by
[`generate_samples.py`](generate_samples.py):

```
py generate_samples.py
```
