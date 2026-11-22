// Property / fuzz test: every sort, over many random inputs (varied sizes, ranges,
// duplicates, negatives and fractions), must match std::sort exactly — which checks
// both "is sorted" and "is a permutation of the input" in one comparison (two vectors
// sorted ascending are byte-equal iff they're the same multiset). Comparison sorts are
// also fuzzed with std::greater; radix is ascending-only. No framework; exits non-zero
// on the first failure, printing the seed + input so it reproduces.

#include <algorithm>
#include <cstdio>
#include <functional>
#include <random>
#include <string>
#include <vector>

#include <sa/simple_sorts/bubble.hpp>
#include <sa/simple_sorts/cocktail.hpp>
#include <sa/simple_sorts/cycle.hpp>
#include <sa/simple_sorts/insertion.hpp>
#include <sa/simple_sorts/selection.hpp>
#include <sa/efficient_sorts/heap.hpp>
#include <sa/efficient_sorts/merge.hpp>
#include <sa/efficient_sorts/quick.hpp>
#include <sa/advanced_sorts/bucket.hpp>
#include <sa/advanced_sorts/counting.hpp>
#include <sa/advanced_sorts/radix.hpp>
#include <sa/advanced_sorts/shell.hpp>

static int failures = 0;

// A random input array: size in [0, maxN], values an integer-or-fractional mix in a
// range that forces lots of duplicates at small `spread`.
static std::vector<double> make_input(std::mt19937_64& rng, std::size_t maxN) {
    std::uniform_int_distribution<std::size_t> sz(0, maxN);
    const std::size_t n = sz(rng);
    const int spread = static_cast<int>(1 + (rng() % 50));     // small -> many dups
    const bool frac = (rng() & 1);
    std::vector<double> v(n);
    for (auto& x : v) {
        double d = static_cast<double>(static_cast<long long>(rng() % (2u * spread)) - spread);
        if (frac) d += static_cast<double>(rng() % 4) * 0.25;   // fractional values too
        x = d;
    }
    return v;
}

static void dump(const char* algo, const char* order, const std::vector<double>& in) {
    std::printf("FAIL %s (%s) on n=%zu: [", algo, order, in.size());
    for (std::size_t i = 0; i < in.size() && i < 32; ++i) std::printf("%g ", in[i]);
    std::printf("%s]\n", in.size() > 32 ? "..." : "");
    ++failures;
}

int main() {
    using V = std::vector<double>;
    struct Named { const char* name; std::function<void(V&)> asc; };

    // Ascending (default comparator) — all ten algorithms.
    const std::vector<Named> algos = {
        {"bubble",    [](V& a) { sa::bubble_sort(a); }},
        {"selection", [](V& a) { sa::selection_sort(a); }},
        {"insertion", [](V& a) { sa::insertion_sort(a); }},
        {"cocktail",  [](V& a) { sa::cocktail_sort(a); }},
        {"cycle",     [](V& a) { sa::cycle_sort(a); }},
        {"merge",     [](V& a) { sa::merge_sort(a); }},
        {"quick",     [](V& a) { sa::quick_sort(a); }},
        {"heap",      [](V& a) { sa::heap_sort(a); }},
        {"shell",     [](V& a) { sa::shell_sort(a); }},
        {"radix",     [](V& a) { sa::radix_sort(a); }},
        {"counting",  [](V& a) { sa::counting_sort(a); }},
        {"bucket",    [](V& a) { sa::bucket_sort(a); }},
    };
    // Descending (std::greater) — comparison sorts only (radix is ascending-only).
    struct NamedG { const char* name; std::function<void(V&)> desc; };
    const std::vector<NamedG> algosDesc = {
        {"bubble",    [](V& a) { sa::bubble_sort(a, std::greater<double>{}); }},
        {"selection", [](V& a) { sa::selection_sort(a, std::greater<double>{}); }},
        {"insertion", [](V& a) { sa::insertion_sort(a, std::greater<double>{}); }},
        {"cocktail",  [](V& a) { sa::cocktail_sort(a, std::greater<double>{}); }},
        {"cycle",     [](V& a) { sa::cycle_sort(a, std::greater<double>{}); }},
        {"merge",     [](V& a) { sa::merge_sort(a, std::greater<double>{}); }},
        {"quick",     [](V& a) { sa::quick_sort(a, std::greater<double>{}); }},
        {"heap",      [](V& a) { sa::heap_sort(a, std::greater<double>{}); }},
        {"shell",     [](V& a) { sa::shell_sort(a, std::greater<double>{}); }},
    };

    constexpr int kTrials = 400;
    const std::size_t kMaxN = 260;

    for (int trial = 0; trial < kTrials; ++trial) {
        std::mt19937_64 rng(0x5a17u + static_cast<unsigned>(trial));
        const V in = make_input(rng, kMaxN);

        V asc = in;  std::sort(asc.begin(), asc.end());
        for (const auto& a : algos) {
            V b = in;
            a.asc(b);
            if (b != asc) dump(a.name, "asc", in);
        }

        V desc = in;  std::sort(desc.begin(), desc.end(), std::greater<double>{});
        for (const auto& a : algosDesc) {
            V b = in;
            a.desc(b);
            if (b != desc) dump(a.name, "desc", in);
        }

        if (failures > 0) break;   // stop at the first failing trial (input already printed)
    }

    if (failures == 0) std::printf("OK: fuzz — all sorts match std::sort over %d random inputs\n", kTrials);
    return failures == 0 ? 0 : 1;
}
