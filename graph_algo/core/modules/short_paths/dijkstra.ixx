module;

// Dijkstra's single-source shortest paths over non-negative edge weights.
//
// Returns the distance from src to every vertex (unreachable == infinity) and,
// via the out-parameter `parent`, the shortest-path tree. Emits trace steps —
// visit_vertex when a vertex is settled, relax_edge (with the new distance in
// step.value) when a shorter path is found — so a visualizer can animate it.
export module ga.short_paths.dijkstra;

import std;
import ga.graph;
import ga.trace;

export namespace ga {
  template <graph_like G>
  std::vector<weight_t<G>> dijkstra(const G& g, vertex src,
    std::vector<vertex>* parent = nullptr,
    const tracer& trace = ignore) {
    using W = weight_t<G>;
    constexpr W inf = std::numeric_limits<W>::max();
    std::vector<W> dist(g.order(), inf);
    std::vector<char> settled(g.order(), 0);
    std::vector<vertex> par(g.order(), nil);

    using node = std::pair<W, vertex>;              // (distance, vertex)
    std::priority_queue<node, std::vector<node>, std::greater<node>> pq;

    dist[src] = W{0};
    par[src] = src;
    pq.push({W{0}, src});
    trace({evt::discover_vertex, src, nil, 0.0});

    while(!pq.empty()) {
      const auto [d, u] = pq.top();
      pq.pop();
      if(settled[u]) continue;                   // stale heap entry
      settled[u] = 1;
      trace({evt::visit_vertex, u, nil, static_cast<double>(d)});

      for(const auto& e : g.out(u)) {
        trace({evt::examine_edge, u, e.to});
        if(!settled[e.to] && dist[u] != inf && dist[u] + e.weight < dist[e.to]) {
          dist[e.to] = dist[u] + e.weight;
          par[e.to] = u;
          pq.push({dist[e.to], e.to});
          trace({evt::relax_edge, u, e.to, static_cast<double>(dist[e.to])});
        }
        else {
          trace({evt::skip_edge, u, e.to});
        }
      }
      trace({evt::finish_vertex, u, nil, static_cast<double>(d)});
    }

    if(parent) *parent = std::move(par);
    return dist;
  }
}  // namespace ga
