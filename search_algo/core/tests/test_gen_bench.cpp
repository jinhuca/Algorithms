// Dependency-free tests for the benchmark foundation: se::gen (synthetic array
// generators + target pickers) and se::bench (timing harness + op-counters). No test
// framework, so it builds anywhere; exits non-zero if any check fails.

#include <algorithm>
#include <cstdio>
#include <set>
#include <vector>

#include <se/bench/bench.hpp>
#include <se/gen/gen.hpp>
#include <se/sorted_searches/binary.hpp>
#include <se/sequential_searches/linear.hpp>

static int failures = 0;
#define CHECK(cond)                                                       \
    do {                                                                  \
        if (!(cond)) {                                                    \
            std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);   \
            ++failures;                                                   \
        }                                                                 \
    } while (0)

int main() {
    using namespace se;

    // ---- sorted: ascending, evenly spaced ----
    {
        auto s = gen::sorted(100);
        CHECK(s.size() == 100);
        CHECK(std::is_sorted(s.begin(), s.end()));
    }

    // ---- random_sorted: reproducible for a fixed seed, differs across seeds, sorted ----
    {
        auto a = gen::random_sorted(200, /*seed=*/42);
        auto b = gen::random_sorted(200, /*seed=*/42);
        auto c = gen::random_sorted(200, /*seed=*/43);
        CHECK(a.size() == 200);
        CHECK(std::is_sorted(a.begin(), a.end()));
        CHECK(a == b);                       // same seed -> identical
        CHECK(a != c);                       // seed actually matters
    }

    // ---- few_unique_sorted: at most k distinct values, still sorted ----
    {
        auto v = gen::few_unique_sorted(500, /*k=*/4, /*seed=*/7);
        std::set<double> distinct(v.begin(), v.end());
        CHECK(v.size() == 500);
        CHECK(distinct.size() <= 4);
        CHECK(std::is_sorted(v.begin(), v.end()));
    }

    // ---- gaussian_sorted: reproducible + sorted ----
    {
        auto v = gen::gaussian_sorted(300, /*seed=*/1);
        auto w = gen::gaussian_sorted(300, 1);
        CHECK(v == w);
        CHECK(std::is_sorted(v.begin(), v.end()));
    }

    // ---- unsorted_random: reproducible ----
    {
        auto v = gen::unsorted_random(100, 5);
        auto w = gen::unsorted_random(100, 5);
        CHECK(v == w);
        CHECK(v.size() == 100);
    }

    // ---- present_target is in the array and binary finds it at every fraction ----
    {
        auto v = gen::sorted(257);
        for (double f : {0.0, 0.25, 0.5, 0.75, 1.0}) {
            const double t = gen::present_target(v, f);
            CHECK(std::binary_search(v.begin(), v.end(), t));
            const index r = binary_search(v, t);
            CHECK(r != nil && v[r] == t);
        }
    }

    // ---- missing_target is absent; binary returns nil ----
    {
        auto v = gen::sorted(128);
        const double m = gen::missing_target(v);
        CHECK(!std::binary_search(v.begin(), v.end(), m));
        CHECK(binary_search(v, m) == nil);
    }

    // ---- bench::time_it reports sane stats ----
    {
        auto base = gen::random_sorted(4000, 9);
        const double t = gen::present_target(base, 0.5);
        auto r = bench::time_it([&] {
            const index idx = binary_search(base, t);
            bench::do_not_optimize(idx);
        }, /*runs=*/4, /*warmup=*/1);
        CHECK(r.runs == 4);
        CHECK(r.min_ms >= 0.0);
        CHECK(r.min_ms <= r.mean_ms + 1e-9);    // min is the smallest
        CHECK(r.stddev_ms >= 0.0);
    }

    // ---- count_into: linear search probes every element on an absent target ----
    {
        auto v = gen::sorted(50);
        bench::counters c;
        linear_search(v, gen::missing_target(v), se::less{}, bench::count_into(c));
        CHECK(c.probe == 50);
        CHECK(c.not_found == 1);
        CHECK(c.total > 0);
        CHECK(c.probes() == c.probe);
    }

    // ---- count_into: binary search probes O(log n), far fewer than n ----
    {
        auto v = gen::sorted(1024);
        bench::counters c;
        const double t = gen::present_target(v, 0.5);
        binary_search(v, t, se::less{}, bench::count_into(c));
        CHECK(c.probe >= 1);
        CHECK(c.probe <= 11);                   // ceil(log2(1024)) = 10, + a little slack
        CHECK(c.found == 1);
    }

    if (failures == 0) std::printf("OK: all gen+bench checks passed\n");
    return failures == 0 ? 0 : 1;
}
