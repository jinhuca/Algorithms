// Dependency-free tests for the benchmark foundation: sa::gen (synthetic array
// generators) and sa::bench (timing harness + op-counters). No test framework, so
// it builds anywhere; exits non-zero if any check fails.

#include <algorithm>
#include <cstdio>
#include <set>
#include <vector>

#include <sa/bench/bench.hpp>
#include <sa/gen/gen.hpp>
#include <sa/simple_sorts/bubble.hpp>
#include <sa/simple_sorts/insertion.hpp>

static int failures = 0;
#define CHECK(cond)                                                       \
    do {                                                                  \
        if (!(cond)) {                                                    \
            std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);   \
            ++failures;                                                   \
        }                                                                 \
    } while (0)

int main() {
    using namespace sa;

    // ---- sorted / reversed shapes ----
    {
        auto s = gen::sorted(100);
        CHECK(s.size() == 100);
        CHECK(std::is_sorted(s.begin(), s.end()));

        auto r = gen::reversed(100);
        CHECK(r.size() == 100);
        CHECK(std::is_sorted(r.begin(), r.end(), std::greater<double>{}));
    }

    // ---- random: reproducible for a fixed seed, differs across seeds ----
    {
        auto a = gen::random(200, /*seed=*/42);
        auto b = gen::random(200, /*seed=*/42);
        auto c = gen::random(200, /*seed=*/43);
        CHECK(a.size() == 200);
        CHECK(a == b);                       // same seed -> identical
        CHECK(a != c);                       // seed actually matters
    }

    // ---- few_unique: at most k distinct values ----
    {
        auto v = gen::few_unique(500, /*k=*/4, /*seed=*/7);
        std::set<double> distinct(v.begin(), v.end());
        CHECK(v.size() == 500);
        CHECK(distinct.size() <= 4);
    }

    // ---- nearly_sorted: a bounded number of inversions, reproducible ----
    {
        auto v = gen::nearly_sorted(300, /*swaps=*/5, /*seed=*/1);
        auto w = gen::nearly_sorted(300, 5, 1);
        CHECK(v == w);                       // reproducible
        CHECK(v.size() == 300);
    }

    // ---- generated arrays run through the real sorts ----
    {
        auto v = gen::random(120, 5);
        bubble_sort(v);
        CHECK(std::is_sorted(v.begin(), v.end()));
    }

    // ---- bench::time_it reports sane stats ----
    {
        auto base = gen::random(400, 9);
        auto r = bench::time_it([&] {
            auto v = base;
            insertion_sort(v);
            bench::do_not_optimize(v);
        }, /*runs=*/4, /*warmup=*/1);
        CHECK(r.runs == 4);
        CHECK(r.min_ms >= 0.0);
        CHECK(r.min_ms <= r.mean_ms + 1e-9);    // min is the smallest
        CHECK(r.stddev_ms >= 0.0);
    }

    // ---- bench::count_into tallies steps on a separate (untimed) run ----
    {
        auto v = gen::reversed(16);             // worst case -> lots of compares/swaps
        bench::counters c;
        bubble_sort(v, sa::less{}, bench::count_into(c));
        CHECK(c.compare > 0);
        CHECK(c.swap > 0);
        CHECK(c.writes() == c.swap * 2);        // bubble only swaps, no overwrites
        CHECK(c.total > 0);
    }

    if (failures == 0) std::printf("OK: all gen+bench checks passed\n");
    return failures == 0 ? 0 : 1;
}
