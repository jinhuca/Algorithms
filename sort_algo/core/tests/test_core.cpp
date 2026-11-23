// Minimal dependency-free tests for the sort core (no test framework so it builds
// anywhere). Exits non-zero on the first failed check.

#include <algorithm>
#include <cstdio>
#include <functional>
#include <string>
#include <vector>

#include <sa/seq/seq.hpp>
#include <sa/seq/trace.hpp>
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
#define CHECK(cond)                                                       \
    do {                                                                  \
        if (!(cond)) {                                                    \
            std::printf("FAIL %s:%d  %s\n", __FILE__, __LINE__, #cond);   \
            ++failures;                                                   \
        }                                                                 \
    } while (0)

// Is `v` a non-decreasing permutation of `original`?
template <typename T>
static bool is_sorted_perm(std::vector<T> v, std::vector<T> original) {
    const bool ordered = std::is_sorted(v.begin(), v.end());
    std::sort(v.begin(), v.end());
    std::sort(original.begin(), original.end());
    return ordered && v == original;
}

// Every algorithm, under one name, so each test case runs across all five.
using SortFn = std::function<void(std::vector<double>&, std::less<double>, const sa::tracer&)>;

struct NamedSort { const char* name; SortFn fn; bool comparison; };

static std::vector<NamedSort> all_sorts() {
    return {
        {"bubble",    [](auto& a, auto c, auto& t) { sa::bubble_sort(a, c, t); }, true},
        {"selection", [](auto& a, auto c, auto& t) { sa::selection_sort(a, c, t); }, true},
        {"insertion", [](auto& a, auto c, auto& t) { sa::insertion_sort(a, c, t); }, true},
        {"cocktail",  [](auto& a, auto c, auto& t) { sa::cocktail_sort(a, c, t); }, true},
        {"cycle",     [](auto& a, auto c, auto& t) { sa::cycle_sort(a, c, t); }, true},
        {"merge",     [](auto& a, auto c, auto& t) { sa::merge_sort(a, c, t); }, true},
        {"quick",     [](auto& a, auto c, auto& t) { sa::quick_sort(a, c, t); }, true},
        {"heap",      [](auto& a, auto c, auto& t) { sa::heap_sort(a, c, t); }, true},
        {"shell",     [](auto& a, auto c, auto& t) { sa::shell_sort(a, c, t); }, true},
        {"radix",     [](auto& a, auto, auto& t) { sa::radix_sort(a, t); }, false},     // non-comparison
        {"counting",  [](auto& a, auto, auto& t) { sa::counting_sort(a, t); }, false},  // non-comparison
        {"bucket",    [](auto& a, auto, auto& t) { sa::bucket_sort(a, t); }, false},    // distribution
    };
}

int main() {
    using namespace sa;

    // Inputs exercising the tricky cases: reversed, duplicates, single, empty,
    // already sorted, negatives.
    const std::vector<std::vector<double>> inputs = {
        {5, 3, 8, 1, 9, 2, 7, 4, 6, 0},
        {9, 8, 7, 6, 5, 4, 3, 2, 1},           // reversed (worst case)
        {1, 2, 3, 4, 5},                        // already sorted (best case)
        {4, 4, 2, 2, 4, 1, 2, 4},               // many duplicates
        {-3, 10, -7, 0, 2, -1},                 // negatives
        {42},                                   // single element
        {},                                     // empty
    };

    for (auto& s : all_sorts()) {
        for (const auto& in : inputs) {
            std::vector<double> a = in;
            int compares = 0, steps = 0;
            auto tr = tracer([&](const step& st) { ++steps; if (st.kind == evt::compare) ++compares; });
            s.fn(a, std::less<double>{}, tr);
            if (!is_sorted_perm(a, in))
                std::printf("FAIL %s did not sort/permute an input of size %zu\n",
                            s.name, in.size());
            CHECK(is_sorted_perm(a, in));
            if (in.size() > 1) {
                CHECK(steps > 0);                                 // the tracer fired
                if (s.comparison) CHECK(compares > 0);            // comparison sorts compare
                else CHECK(compares == 0);                        // radix does zero comparisons
            }
        }
    }

    // --- custom comparator: std::greater sorts descending ---
    {
        std::vector<double> a = {3, 1, 4, 1, 5, 9, 2, 6};
        sa::bubble_sort(a, std::greater<double>{});
        CHECK(std::is_sorted(a.begin(), a.end(), std::greater<double>{}));

        std::vector<double> b = {3, 1, 4, 1, 5, 9, 2, 6};
        sa::insertion_sort(b, std::greater<double>{});
        CHECK(std::is_sorted(b.begin(), b.end(), std::greater<double>{}));

        std::vector<double> c = {3, 1, 4, 1, 5, 9, 2, 6};
        sa::cycle_sort(c, std::greater<double>{});
        CHECK(std::is_sorted(c.begin(), c.end(), std::greater<double>{}));

        std::vector<double> d = {3, 1, 4, 1, 5, 9, 2, 6};
        sa::merge_sort(d, std::greater<double>{});
        CHECK(std::is_sorted(d.begin(), d.end(), std::greater<double>{}));

        std::vector<double> e = {3, 1, 4, 1, 5, 9, 2, 6};
        sa::quick_sort(e, std::greater<double>{});
        CHECK(std::is_sorted(e.begin(), e.end(), std::greater<double>{}));

        std::vector<double> f = {3, 1, 4, 1, 5, 9, 2, 6};
        sa::heap_sort(f, std::greater<double>{});
        CHECK(std::is_sorted(f.begin(), f.end(), std::greater<double>{}));

        std::vector<double> g = {3, 1, 4, 1, 5, 9, 2, 6};
        sa::shell_sort(g, std::greater<double>{});
        CHECK(std::is_sorted(g.begin(), g.end(), std::greater<double>{}));
    }

    // --- radix sort on fractional + negative doubles (bit-key transform) ---
    {
        std::vector<double> a = {3.5, -2.1, 3.4, 0.0, -2.2, 10.0, 3.45};
        const std::vector<double> want = {-2.2, -2.1, 0.0, 3.4, 3.45, 3.5, 10.0};
        sa::radix_sort(a);
        CHECK(a == want);
    }

    // --- generic over an arbitrary orderable T (concept): sort strings ---
    {
        std::vector<std::string> words = {"pear", "apple", "fig", "banana", "kiwi"};
        const std::vector<std::string> want = {"apple", "banana", "fig", "kiwi", "pear"};
        sa::selection_sort(words);
        CHECK(words == want);

        std::vector<std::string> w2 = {"pear", "apple", "fig", "banana", "kiwi"};
        sa::insertion_sort(w2);
        CHECK(w2 == want);
    }

    // --- concept checks: a (mutable) vector is sortable; a const vector is NOT (sorts
    //     permute in place); counting/arithmetic concepts; orderable accepts int/string ---
    static_assert(sa::sortable<std::vector<int>> && !sa::sortable<const std::vector<int>>);
    static_assert(sa::counting_sortable<std::vector<std::string>> &&
                  sa::arithmetically_sortable<std::vector<double>>);
    static_assert(sa::orderable<int> && sa::orderable<std::string>);

    if (failures == 0) std::printf("OK: all sort core checks passed\n");
    return failures == 0 ? 0 : 1;
}
