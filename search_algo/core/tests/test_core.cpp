// Minimal dependency-free tests for the search core (no test framework so it builds
// anywhere). Exits non-zero on the first failed check.

#include <algorithm>
#include <cstdio>
#include <functional>
#include <string>
#include <vector>

#include <se/seq/seq.hpp>
#include <se/seq/trace.hpp>
#include <se/sequential_searches/linear.hpp>
#include <se/sequential_searches/sentinel.hpp>
#include <se/sorted_searches/binary.hpp>
#include <se/sorted_searches/ternary.hpp>
#include <se/sorted_searches/jump.hpp>
#include <se/sorted_searches/exponential.hpp>
#include <se/sorted_searches/interpolation.hpp>
#include <se/sorted_searches/fibonacci.hpp>

static int failures = 0;
#define CHECK(cond)                                                       \
    do {                                                                  \
        if (!(cond)) {                                                    \
            std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);   \
            ++failures;                                                   \
        }                                                                 \
    } while (0)

// Every algorithm, under one name, so each case runs across all eight. `sequential`
// searches don't need sorted input; the rest assume the array is sorted by the cmp.
using SearchFn =
    std::function<se::index(const std::vector<double>&, const double&,
                            std::less<double>, const se::tracer&)>;
struct NamedSearch { const char* name; SearchFn fn; bool sequential; };

static std::vector<NamedSearch> all_searches() {
    return {
        {"linear",        [](auto& a, auto& t, auto c, auto& tr) { return se::linear_search(a, t, c, tr); },        true},
        {"sentinel",      [](auto& a, auto& t, auto c, auto& tr) { return se::sentinel_search(a, t, c, tr); },      true},
        {"binary",        [](auto& a, auto& t, auto c, auto& tr) { return se::binary_search(a, t, c, tr); },        false},
        {"ternary",       [](auto& a, auto& t, auto c, auto& tr) { return se::ternary_search(a, t, c, tr); },       false},
        {"jump",          [](auto& a, auto& t, auto c, auto& tr) { return se::jump_search(a, t, c, tr); },          false},
        {"exponential",   [](auto& a, auto& t, auto c, auto& tr) { return se::exponential_search(a, t, c, tr); },   false},
        {"interpolation", [](auto& a, auto& t, auto c, auto& tr) { return se::interpolation_search(a, t, c, tr); }, false},
        {"fibonacci",     [](auto& a, auto& t, auto c, auto& tr) { return se::fibonacci_search(a, t, c, tr); },     false},
    };
}

int main() {
    using namespace se;
    auto no_trace = tracer(ignore);

    // Sorted inputs exercising the tricky cases: duplicates, negatives, single, empty,
    // all-equal, fractional.
    const std::vector<std::vector<double>> inputs = {
        {1, 2, 3, 4, 5, 6, 7, 8, 9, 10},
        {-5, -3, -1, 0, 2, 4, 4, 4, 8, 15, 16, 23, 42},   // duplicates + negatives
        {2, 4, 6, 8, 10},
        {7},                                               // single
        {},                                                // empty
        {1, 1, 1, 1, 1},                                   // all equal
        {1.5, 2.25, 3.75, 10.0, 10.0, 99.9},               // fractional + a duplicate
    };

    for (auto& s : all_searches()) {
        for (const auto& a : inputs) {
            // present targets, at the front / middle / back
            if (!a.empty()) {
                for (double frac : {0.0, 0.5, 1.0}) {
                    const std::size_t idx =
                        static_cast<std::size_t>(frac * static_cast<double>(a.size() - 1) + 0.5);
                    const double target = a[idx];
                    const index r = s.fn(a, target, std::less<double>{}, no_trace);
                    if (r == nil || r >= a.size() || a[r] != target) {
                        std::printf("FAIL %s: present target %g in size %zu not found correctly\n",
                                    s.name, target, a.size());
                        ++failures;
                    }
                }
            }
            // absent targets, above max and below min
            const double above = a.empty() ? 1.0 : *std::max_element(a.begin(), a.end()) + 1.0;
            const double below = a.empty() ? -1.0 : *std::min_element(a.begin(), a.end()) - 1.0;
            CHECK(s.fn(a, above, std::less<double>{}, no_trace) == nil);
            CHECK(s.fn(a, below, std::less<double>{}, no_trace) == nil);
        }
    }

    // --- the tracer fires on a non-trivial search ---
    {
        std::vector<double> a = {1, 2, 3, 4, 5, 6, 7, 8};
        int probes = 0, steps = 0;
        auto tr = tracer([&](const step& st) { ++steps; if (st.kind == evt::probe) ++probes; });
        const index r = binary_search(a, 7.0, std::less<double>{}, tr);
        CHECK(r != nil && a[r] == 7.0);
        CHECK(steps > 0);
        CHECK(probes > 0);
    }

    // --- the sequential searches work on UNSORTED data ---
    {
        std::vector<double> u = {5, 3, 8, 1, 9, 2, 7, 4, 6, 0};
        CHECK(linear_search(u, 9.0) != nil);
        CHECK(sentinel_search(u, 9.0) != nil);
        CHECK(u[linear_search(u, 7.0)] == 7.0);
        CHECK(linear_search(u, 100.0) == nil);
        CHECK(sentinel_search(u, 100.0) == nil);
    }

    // --- custom comparator: a DESCENDING array searched with std::greater ---
    {
        std::vector<double> d = {42, 23, 16, 15, 8, 4, 2, 0, -1, -3, -5};
        CHECK(std::is_sorted(d.begin(), d.end(), std::greater<double>{}));
        CHECK(binary_search(d, 15.0, std::greater<double>{}) != nil);
        CHECK(d[binary_search(d, 15.0, std::greater<double>{})] == 15.0);
        CHECK(binary_search(d, 99.0, std::greater<double>{}) == nil);
        CHECK(jump_search(d, -3.0, std::greater<double>{}) != nil);
        CHECK(ternary_search(d, 42.0, std::greater<double>{}) != nil);
        CHECK(exponential_search(d, 0.0, std::greater<double>{}) != nil);
        CHECK(fibonacci_search(d, 2.0, std::greater<double>{}) != nil);
    }

    // --- generic over an arbitrary orderable T (concept): search sorted strings ---
    {
        std::vector<std::string> words = {"apple", "banana", "fig", "kiwi", "pear"};
        CHECK(linear_search(words, std::string("fig")) != nil);
        CHECK(binary_search(words, std::string("kiwi")) != nil);
        CHECK(binary_search(words, std::string("zebra")) == nil);
        CHECK(words[binary_search(words, std::string("pear"))] == "pear");
    }

    // --- the searchable concept accepts a vector, orderable accepts int/string ---
    static_assert(se::searchable<std::vector<int>>);
    static_assert(se::orderable<int> && se::orderable<std::string>);

    if (failures == 0) std::printf("OK: all search core checks passed\n");
    return failures == 0 ? 0 : 1;
}
