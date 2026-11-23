module;

// ga::graph — a generic, index-based graph.
//
// Vertices are integers 0..order()-1 (cheap to use as array indices, which is
// what graph algorithms want). Presentation data — labels, positions, colours —
// deliberately lives OUTSIDE the core, in the visualizer, so the core stays a
// pure, allocation-light computation layer. Edges carry a weight of type W
// (default double); unweighted graphs just use weight 1.
//
// The graph can be directed or undirected; an undirected edge is stored as the
// pair of opposing directed edges so adjacency queries stay uniform.
//
// The algorithms (bfs/dfs/dijkstra/bellman_ford/kruskal/prim) are written against
// the `graph_like` concept defined below — NOT ga::graph directly — so any type
// exposing the same order()/directed()/vertices()/out() interface, with edges
// carrying from/to/weight, satisfies them and can be traversed unchanged.
export module ga.graph;
import std;

export namespace ga {
  using vertex = std::size_t;
  inline constexpr vertex nil = static_cast<vertex>(-1);   // "no vertex"

  template <typename W = double>
  struct edge {
    vertex from{};
    vertex to{};
    W weight{1};
  };

  template <typename W = double>
  class graph {
  public:
    using weight_type = W;

    graph() = default;
    explicit graph(std::size_t n, bool directed = false)
      : adj_(n), directed_(directed) {}

    // Add an isolated vertex; returns its id.
    vertex add_vertex() {
      adj_.emplace_back();
      return adj_.size() - 1;
    }

    // Add an edge u->v (and v->u when undirected). Grows the vertex set if
    // needed so edges can be added before all vertices are declared.
    void add_edge(vertex u, vertex v, W w = W{1}) {
      const vertex hi = (u > v ? u : v);
      if(hi >= adj_.size()) adj_.resize(hi + 1);
      adj_[u].push_back(edge<W>{u, v, w});
      ++edge_count_;
      if(!directed_ && u != v) adj_[v].push_back(edge<W>{v, u, w});
    }

    std::size_t order() const noexcept { return adj_.size(); }   // |V|
    std::size_t size()  const noexcept { return edge_count_; }   // |E| (as added)
    bool directed()     const noexcept { return directed_; }

    // Out-edges of u (for undirected graphs, all incident edges).
    const std::vector<edge<W>>& out(vertex u) const { return adj_[u]; }

    std::size_t degree(vertex u) const { return adj_[u].size(); }

    // A range over all vertex ids: `for (auto v : g.vertices())`.
    auto vertices() const {
      return std::views::iota(vertex{0}, order());
    }

  private:
    std::vector<std::vector<edge<W>>> adj_;
    std::size_t edge_count_ = 0;
    bool directed_ = false;
  };

  // ------------------------------------------------------------------------
  // graph_like — the C++20 concept the algorithms are generic over, so any type
  // exposing the same interface as ga::graph<W> (not just ga::graph itself) can be
  // traversed. It captures EXACTLY what bfs/dfs/dijkstra/bellman_ford/kruskal/prim
  // use: a vertex count order(), a directed() flag, a vertices() range, and for each
  // vertex a sized, RANDOM-ACCESS range of edges (dfs indexes out(u)[i] and reads
  // out(u).size()); every edge exposes integer endpoints .from / .to (kruskal needs
  // .from) and a .weight (the shortest-path / MST algorithms sum it).
  template <typename G>
  concept graph_like = requires(const G& g, vertex u) {
    { g.order() }    -> std::convertible_to<std::size_t>;
    { g.directed() } -> std::convertible_to<bool>;
    { g.vertices() } -> std::ranges::input_range;
    { g.out(u) }     -> std::ranges::random_access_range;
    { g.out(u) }     -> std::ranges::sized_range;
    requires requires(std::ranges::range_value_t<std::remove_cvref_t<decltype(g.out(u))>> e) {
      { e.from } -> std::convertible_to<vertex>;
      { e.to }   -> std::convertible_to<vertex>;
      e.weight;
    };
  };

  // The edge type a graph_like G yields from out(), and its weight type — so an
  // algorithm can name them (e.g. std::vector<weight_t<G>> dist) instead of
  // hard-coding a template parameter W. For ga::graph<W>: edge_t = edge<W>, weight_t = W.
  template <graph_like G>
  using edge_t =
    std::ranges::range_value_t<std::remove_cvref_t<decltype(std::declval<const G&>().out(vertex{}))>>;
  template <graph_like G>
  using weight_t = std::remove_cvref_t<decltype(std::declval<edge_t<G>>().weight)>;

}  // namespace ga
