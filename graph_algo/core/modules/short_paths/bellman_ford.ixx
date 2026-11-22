module;

// Bellman–Ford single-source shortest paths. Unlike Dijkstra it allows negative
// edge weights and detects a reachable negative cycle. It relaxes every edge for
// up to |V|-1 rounds (stopping early when a round changes nothing).
//
// Returns the distance to every vertex (unreachable == infinity); `parent` gives
// the shortest-path tree, and `ok` is set false if a negative cycle is reachable
// (the distances are then not well-defined). Emits a `message` per round plus
// examine / relax / skip edge steps, so a visualizer can show the relaxation.

#include <limits>
#include <string>
#include <vector>

export module ga.short_paths.bellman_ford;

import ga.graph;
import ga.trace;

export namespace ga {

template <class W>
std::vector<W> bellman_ford(const graph<W>& g, vertex src,
                            std::vector<vertex>* parent = nullptr, bool* ok = nullptr,
                            const tracer& trace = ignore) {
    constexpr W inf = std::numeric_limits<W>::max();
    std::vector<W> dist(g.order(), inf);
    std::vector<vertex> par(g.order(), nil);

    dist[src] = W{0};
    par[src] = src;
    trace({evt::discover_vertex, src, nil, 0.0});

    bool changed = true;
    for (std::size_t round = 0; round + 1 < g.order() && changed; ++round) {
        changed = false;
        trace(step{evt::message, nil, nil, static_cast<double>(round + 1),
                   "round " + std::to_string(round + 1)});
        for (vertex u : g.vertices()) {
            if (dist[u] == inf) continue;
            for (const auto& e : g.out(u)) {
                trace({evt::examine_edge, u, e.to});
                if (dist[u] + e.weight < dist[e.to]) {
                    const bool first = (dist[e.to] == inf);
                    dist[e.to] = dist[u] + e.weight;
                    par[e.to] = u;
                    changed = true;
                    if (first) trace({evt::discover_vertex, e.to});
                    trace({evt::relax_edge, u, e.to, static_cast<double>(dist[e.to])});
                } else {
                    trace({evt::skip_edge, u, e.to});
                }
            }
        }
    }

    bool negative = false;
    for (vertex u : g.vertices())
        if (dist[u] != inf)
            for (const auto& e : g.out(u))
                if (dist[u] + e.weight < dist[e.to]) negative = true;

    for (vertex u : g.vertices())
        if (dist[u] != inf) trace({evt::finish_vertex, u, nil, static_cast<double>(dist[u])});

    if (parent) *parent = std::move(par);
    if (ok) *ok = !negative;
    return dist;
}

}  // namespace ga
