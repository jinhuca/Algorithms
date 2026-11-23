// Dependency-free tests for the benchmark foundation: ga::gen (synthetic graph
// generators) and ga::bench (timing harness + op-counters). No test framework,
// so it builds anywhere; exits non-zero if any check fails.

#include <algorithm>
#include <cstdio>
#include <tuple>
#include <vector>

#include <ga/basic_algo/bfs.hpp>
#include <ga/bench/bench.hpp>
#include <ga/gen/gen.hpp>
#include <ga/graph/graph.hpp>
#include <ga/short_paths/dijkstra.hpp>

static int failures = 0;
#define CHECK(cond)                                                       \
    do {                                                                  \
        if (!(cond)) {                                                    \
            std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);   \
            ++failures;                                                   \
        }                                                                 \
    } while (0)

// Canonical dump of every out-edge as (u, v, weight), sorted — for comparing two
// graphs for exact equality (topology + weights).
template <typename W>
static std::vector<std::tuple<ga::vertex, ga::vertex, W>> dump(const ga::graph<W>& g) {
    std::vector<std::tuple<ga::vertex, ga::vertex, W>> es;
    for (auto u : g.vertices())
        for (const auto& e : g.out(u)) es.emplace_back(e.from, e.to, e.weight);
    std::sort(es.begin(), es.end());
    return es;
}

int main() {
    using namespace ga;

    // ---- complete(n) ----
    {
        auto g = gen::complete<double>(6);                 // undirected K6
        CHECK(g.order() == 6);
        CHECK(g.size() == 6 * 5 / 2);                      // n(n-1)/2
        auto gd = gen::complete<double>(6, /*directed=*/true);
        CHECK(gd.size() == 6 * 5);                         // n(n-1)
    }

    // ---- grid(rows, cols) ----
    {
        auto g = gen::grid<double>(3, 4);                  // 3x4 lattice
        CHECK(g.order() == 12);
        CHECK(g.size() == 3 * (4 - 1) + (3 - 1) * 4);      // right + down edges
    }

    // ---- random_gnm(n, m): exact edge count, clamping, determinism ----
    {
        auto g = gen::random_gnm<double>(100, 300, /*directed=*/false, /*seed=*/7);
        CHECK(g.order() == 100);
        CHECK(g.size() == 300);                            // m distinct edges, no dupes

        // Too many edges requested -> clamped to the max possible.
        auto full = gen::random_gnm<double>(5, 1000, false, 1);
        CHECK(full.size() == 5 * 4 / 2);

        // Same seed -> identical graph; different seed -> (almost surely) not.
        auto a = gen::random_gnm<double>(50, 120, false, 42, 1.0, 9.0);
        auto b = gen::random_gnm<double>(50, 120, false, 42, 1.0, 9.0);
        auto c = gen::random_gnm<double>(50, 120, false, 43, 1.0, 9.0);
        CHECK(dump(a) == dump(b));                          // reproducible
        CHECK(dump(a) != dump(c));                          // seed actually matters

        // Weighted range respected.
        bool in_range = true;
        for (auto u : a.vertices())
            for (const auto& e : a.out(u))
                if (e.weight < 1.0 || e.weight > 9.0) in_range = false;
        CHECK(in_range);
    }

    // ---- scale_free(n, m): exact edge count = seed clique + m per new vertex ----
    {
        const std::size_t n = 200, m = 3;
        auto g = gen::scale_free<double>(n, m, /*seed=*/11);
        CHECK(g.order() == n);
        CHECK(g.size() == m * (m - 1) / 2 + m * (n - m));
        auto g2 = gen::scale_free<double>(n, m, 11);
        CHECK(dump(g) == dump(g2));                         // reproducible
    }

    // ---- generated graphs run through the real algorithms ----
    {
        auto g = gen::random_gnm<double>(80, 240, false, 5, 1.0, 10.0);
        auto parent = ga::bfs(g, 0);
        CHECK(parent.size() == 80);
        CHECK(parent[0] == 0);
        std::vector<ga::vertex> dpar;
        auto dist = ga::dijkstra(g, 0, &dpar);
        CHECK(dist.size() == 80);
        CHECK(dist[0] == 0.0);
    }

    // ---- bench::time_it reports sane stats ----
    {
        auto g = gen::grid<double>(40, 40);                 // 1600 vertices
        auto r = bench::time_it([&] {
            auto p = ga::bfs(g, 0);
            bench::do_not_optimize(p);
        }, /*runs=*/4, /*warmup=*/1);
        CHECK(r.runs == 4);
        CHECK(r.min_ms >= 0.0);
        CHECK(r.min_ms <= r.mean_ms + 1e-9);                // min is the smallest
        CHECK(r.stddev_ms >= 0.0);
    }

    // ---- bench::count_into tallies steps on a separate (untimed) run ----
    {
        auto g = gen::complete<double>(10);
        bench::counters c;
        ga::bfs(g, 0, bench::count_into(c));
        CHECK(c.visit_vertex == 10);                        // each vertex visited once
        CHECK(c.discover_vertex == 10);                     // each discovered once
        CHECK(c.total > 0);
    }

    if (failures == 0) std::printf("OK: all gen+bench checks passed\n");
    return failures == 0 ? 0 : 1;
}
