pragma ComponentBehavior: Bound
import QtQuick

// The Knowledge base content: one article per search. Pure data (no UI), so the article
// text lives apart from the KnowledgePage layout. Each topic carries pre-conditions,
// best/avg/worst/space complexity, the real .ixx source path, and the `algo` name the
// Visualizer / Analyzer deep-link buttons use.
QtObject {
    readonly property var topics: [
        {
            id: "linear", title: "Linear Search", category: "Sequential", algo: "Linear",
            summary: "Walk the array front to back and return the first element equal to the target.",
            requires: "Any order", best: "O(1)", avg: "O(n)", worst: "O(n)", space: "O(1)",
            source: "core/modules/sequential_searches/linear.ixx",
            body: "The simplest search and the only one that needs no ordering: compare each element with the target in turn and stop at the first match. Best case is a hit at the front (one probe); worst and average are O(n). It is the right tool for small or unsorted data, where the cost of sorting first would not pay off. The Visualizer sweeps a probe cursor along the bars, dimming each rejected element."
        },
        {
            id: "sentinel", title: "Sentinel Linear Search", category: "Sequential", algo: "Sentinel",
            summary: "Linear search with the per-step bounds check removed by a guard element.",
            requires: "Any order", best: "O(1)", avg: "O(n)", worst: "O(n)", space: "O(1)",
            source: "core/modules/sequential_searches/sentinel.ixx",
            body: "A linear search that plants the target itself just past the data as a guard, so the scan loop only has to test for equality — the guard is guaranteed to stop it. Same O(n) comparisons as the plain linear search, but one fewer test per step, which can matter in a tight loop. This implementation keeps the input immutable by appending the guard to a local copy; a stop at a real index is a find, a stop on the guard means the target is absent."
        },
        {
            id: "binary", title: "Binary Search", category: "Sorted", algo: "Binary",
            summary: "Halve a sorted window at each step, keeping only the side that can contain the target.",
            requires: "Sorted", best: "O(1)", avg: "O(log n)", worst: "O(log n)", space: "O(1)",
            source: "core/modules/sorted_searches/binary.ixx",
            body: "The archetypal sorted-array search. Keep a window [lo, hi); probe the midpoint and discard the half that cannot contain the target. Each step halves the window, so it finishes in about log₂ n probes — 20 probes suffice for a million elements. The Visualizer shows the window markers sliding together and the discarded halves dimming. Requires the array sorted by the same comparator (pass std::greater for a descending array)."
        },
        {
            id: "ternary", title: "Ternary Search", category: "Sorted", algo: "Ternary",
            summary: "Split the sorted window into three parts with two probes per step.",
            requires: "Sorted", best: "O(1)", avg: "O(log n)", worst: "O(log n)", space: "O(1)",
            source: "core/modules/sorted_searches/ternary.ixx",
            body: "Like binary search but using two probes per iteration to cut the window to a third. Although it needs fewer iterations (log₃ n), it does up to two comparisons each, so in practice it performs MORE comparisons than binary search — a useful lesson that fewer iterations does not mean fewer operations. Included as a direct contrast to binary search on the Analyzer's probe-vs-N chart."
        },
        {
            id: "jump", title: "Jump Search", category: "Sorted", algo: "Jump",
            summary: "Step forward in blocks of ~√n, then linear-scan the block that must hold the target.",
            requires: "Sorted", best: "O(1)", avg: "O(√n)", worst: "O(√n)", space: "O(1)",
            source: "core/modules/sorted_searches/jump.ixx",
            body: "Advance in fixed blocks of about √n until the block whose last element is ≥ the target, then scan that block linearly. The result is O(√n) probes — between linear and binary — with a strictly forward, cache-friendly access pattern (it never jumps backward the way binary search does). A good fit when backward seeks are expensive, e.g. data on tape or a slow medium."
        },
        {
            id: "exponential", title: "Exponential Search", category: "Sorted", algo: "Exponential",
            summary: "Find a range by doubling an index, then binary-search inside it.",
            requires: "Sorted", best: "O(1)", avg: "O(log i)", worst: "O(log n)", space: "O(1)",
            source: "core/modules/sorted_searches/exponential.ixx",
            body: "Probe indices 1, 2, 4, 8, … until the value at the bound is ≥ the target, then binary-search the last doubled range. It runs in O(log i) where i is the target's position, so it beats plain binary search when the target is near the front — and it needs no size known up front, which suits unbounded or streamed input. The Visualizer shows the doubling probes galloping out, then the embedded binary search closing in."
        },
        {
            id: "interpolation", title: "Interpolation Search", category: "Sorted", algo: "Interpolation",
            summary: "Guess the probe position by linear interpolation between the window ends.",
            requires: "Sorted · numeric", best: "O(1)", avg: "O(log log n)", worst: "O(n)", space: "O(1)",
            source: "core/modules/sorted_searches/interpolation.ixx",
            body: "Instead of always probing the midpoint, estimate where the target should be by interpolating between the values at the window ends — like opening a phone book near where a name should be. On uniformly distributed numeric keys this reaches O(log log n), far fewer probes than binary search; but on skewed data (try the Gaussian distribution in the Analyzer) its guesses are poor and it degrades toward O(n). A vivid demonstration that the best algorithm depends on the data."
        },
        {
            id: "fibonacci", title: "Fibonacci Search", category: "Sorted", algo: "Fibonacci",
            summary: "Bisect a sorted array using Fibonacci numbers — only addition and subtraction.",
            requires: "Sorted", best: "O(1)", avg: "O(log n)", worst: "O(log n)", space: "O(1)",
            source: "core/modules/sorted_searches/fibonacci.ixx",
            body: "Narrow the window using consecutive Fibonacci numbers so every probe index is reached by addition and subtraction only — no division — which was historically valuable on hardware without a fast divide. It splits the window in the golden ratio rather than in half, favouring smaller forward jumps, and matches binary search's O(log n) asymptotics. The Visualizer shows the characteristic Fibonacci-sized steps of the probe index."
        }
    ]
}
