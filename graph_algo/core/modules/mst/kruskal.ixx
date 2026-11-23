module;

// Kruskal's minimum spanning tree / forest.
//
// Considers every (undirected) edge in ascending weight order and accepts it
// (tree_edge) when its endpoints are in different components, else rejects it
// (skip_edge — it would close a cycle). Uses a union-find with path-halving and
// union-by-rank. Returns the total weight of the accepted edges (a spanning
// FOREST when the graph is disconnected). Emits trace steps so a visualizer can
// animate the sort-and-merge.
export module ga.mst.kruskal;

import std;
import ga.graph;
import ga.trace;

export namespace ga {
  template <graph_like G>
  weight_t<G> kruskal(const G& g, const tracer& trace = ignore) {
    using W = weight_t<G>;
    const std::size_t n = g.order();

    // One copy of each undirected edge (the graph stores both opposing halves).
    // Use the graph's OWN edge type (edge_t<G>), not ga::edge<W>, so any graph_like
    // representation works — not just ga::graph.
    std::vector<edge_t<G>> edges;
    for(vertex u = 0; u < n; ++u)
      for(const auto& e : g.out(u))
        if(g.directed() || e.from <= e.to)
          edges.push_back(e);
    std::sort(edges.begin(), edges.end(),
      [](const edge_t<G>& a, const edge_t<G>& b) { return a.weight < b.weight; });

    // Union-find over the n vertices.
    std::vector<vertex> parent(n);
    std::iota(parent.begin(), parent.end(), vertex{0});
    std::vector<std::size_t> rnk(n, 0);
    auto find = [&](vertex x) {
      while(parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }
      return x;
    };

    W total{};
    for(const auto& e : edges) {
      trace({evt::examine_edge, e.from, e.to});
      const vertex ra = find(e.from), rb = find(e.to);
      if(ra == rb) {
        trace({evt::skip_edge, e.from, e.to});          // same component -> would cycle
        continue;
      }
      if(rnk[ra] < rnk[rb]) parent[ra] = rb;
      else if(rnk[rb] < rnk[ra]) parent[rb] = ra;
      else { parent[rb] = ra; ++rnk[ra]; }
      total += e.weight;
      trace({evt::tree_edge, e.from, e.to, static_cast<double>(e.weight)});
    }
    return total;
  }
}  // namespace ga
