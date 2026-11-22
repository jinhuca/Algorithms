// Property / fuzz test: over many random arrays and random targets (present and
// absent, with duplicates, negatives and fractions), every sorted search must agree
// with a reference about presence (std::binary_search) and, when it reports a find,
// the element at the returned index must equal the target. The sequential searches are
// fuzzed on UNSORTED arrays against std::find. No framework; exits non-zero on the
// first failure, printing the trial seed + input shape so it reproduces.

#include <algorithm>
#include <cstdio>
#include <functional>
#include <random>
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

// A random array: size in [0, maxN], values an integer-or-fractional mix in a range
// that forces lots of duplicates at small `spread`.
static std::vector<double> make_array(std::mt19937_64& rng, std::size_t maxN) {
    std::uniform_int_distribution<std::size_t> sz(0, maxN);
    const std::size_t n = sz(rng);
    const int spread = static_cast<int>(1 + (rng() % 60));     // small -> many dups
    const bool frac = (rng() & 1);
    std::vector<double> v(n);
    for (auto& x : v) {
        double d = static_cast<double>(static_cast<long long>(rng() % (2u * spread)) - spread);
        if (frac) d += static_cast<double>(rng() % 4) * 0.25;
        x = d;
    }
    return v;
}

int main() {
    using V = std::vector<double>;
    struct Named { const char* name; std::function<se::index(const V&, double)> run; };

    const std::vector<Named> sorted_algos = {
        {"binary",        [](const V& a, double t) { return se::binary_search(a, t); }},
        {"ternary",       [](const V& a, double t) { return se::ternary_search(a, t); }},
        {"jump",          [](const V& a, double t) { return se::jump_search(a, t); }},
        {"exponential",   [](const V& a, double t) { return se::exponential_search(a, t); }},
        {"interpolation", [](const V& a, double t) { return se::interpolation_search(a, t); }},
        {"fibonacci",     [](const V& a, double t) { return se::fibonacci_search(a, t); }},
    };
    const std::vector<Named> seq_algos = {
        {"linear",   [](const V& a, double t) { return se::linear_search(a, t); }},
        {"sentinel", [](const V& a, double t) { return se::sentinel_search(a, t); }},
    };

    constexpr int kTrials = 500;
    const std::size_t kMaxN = 300;

    for (int trial = 0; trial < kTrials && failures == 0; ++trial) {
        std::mt19937_64 rng(0x5EA2Cu + static_cast<unsigned>(trial));
        const V arr = make_array(rng, kMaxN);

        // Targets: elements actually present + random values (often absent).
        std::vector<double> targets;
        if (!arr.empty()) {
            std::uniform_int_distribution<std::size_t> pick(0, arr.size() - 1);
            for (int k = 0; k < 4; ++k) targets.push_back(arr[pick(rng)]);
        }
        for (int k = 0; k < 4; ++k) {
            const int spread = 80;
            double d = static_cast<double>(static_cast<long long>(rng() % (2u * spread)) - spread);
            if (rng() & 1) d += static_cast<double>(rng() % 4) * 0.25;
            targets.push_back(d);
        }

        // Sorted searches against a sorted copy.
        V sorted_arr = arr;
        std::sort(sorted_arr.begin(), sorted_arr.end());
        for (double t : targets) {
            const bool ref = std::binary_search(sorted_arr.begin(), sorted_arr.end(), t);
            for (const auto& alg : sorted_algos) {
                const se::index r = alg.run(sorted_arr, t);
                const bool found = (r != se::nil);
                if (found != ref) {
                    std::printf("FAIL %s trial=%d n=%zu t=%g: found=%d ref=%d\n",
                                alg.name, trial, sorted_arr.size(), t, found, ref);
                    ++failures; break;
                }
                if (found && sorted_arr[r] != t) {
                    std::printf("FAIL %s trial=%d: a[%zu]=%g != target %g\n",
                                alg.name, trial, r, sorted_arr[r], t);
                    ++failures; break;
                }
            }
            if (failures) break;
        }
        if (failures) break;

        // Sequential searches against the unsorted array.
        for (double t : targets) {
            const bool ref = std::find(arr.begin(), arr.end(), t) != arr.end();
            for (const auto& alg : seq_algos) {
                const se::index r = alg.run(arr, t);
                const bool found = (r != se::nil);
                if (found != ref) {
                    std::printf("FAIL %s (unsorted) trial=%d n=%zu t=%g: found=%d ref=%d\n",
                                alg.name, trial, arr.size(), t, found, ref);
                    ++failures; break;
                }
                if (found && arr[r] != t) {
                    std::printf("FAIL %s (unsorted) trial=%d: a[%zu]=%g != target %g\n",
                                alg.name, trial, r, arr[r], t);
                    ++failures; break;
                }
            }
            if (failures) break;
        }
    }

    if (failures == 0)
        std::printf("OK: fuzz — all searches agree with the reference over %d trials\n", kTrials);
    return failures == 0 ? 0 : 1;
}
