pragma ComponentBehavior: Bound
import QtQuick

// Curated reference content for the Knowledge base — one entry per sort (plus a note
// on input distributions). Pure data; KnowledgePage renders it. `algo` links a topic
// to the Visualizer / Analyzer deep-link buttons; `source` names the real .ixx.
QtObject {
    readonly property var topics: [
        {
            id: "bubble", title: "Bubble Sort", category: "Simple sorts", algo: "Bubble",
            summary: "Swap adjacent out-of-order pairs; the largest bubbles to the end each pass.",
            stable: "Stable", inPlace: "In-place", best: "O(n)", avg: "O(n²)", worst: "O(n²)",
            space: "O(1)", source: "core/modules/simple_sorts/bubble.ixx",
            body: "Bubble sort repeatedly walks the array comparing each adjacent pair and "
                + "swapping them when they are out of order, so on every pass the largest "
                + "remaining element 'bubbles up' to its final place at the end. A pass that "
                + "makes no swaps means the array is already ordered, so the early-exit gives "
                + "an O(n) best case on sorted input. It is stable and needs only O(1) extra "
                + "space, but its O(n²) average cost makes it a teaching sort, not a production one."
        },
        {
            id: "selection", title: "Selection Sort", category: "Simple sorts", algo: "Selection",
            summary: "Each pass selects the minimum of the unsorted tail and puts it next.",
            stable: "Not stable", inPlace: "In-place", best: "O(n²)", avg: "O(n²)", worst: "O(n²)",
            space: "O(1)", source: "core/modules/simple_sorts/selection.ixx",
            body: "Selection sort grows a sorted prefix: each pass scans the unsorted tail for "
                + "its smallest element and swaps it into the next prefix slot. It always does "
                + "Θ(n²) comparisons regardless of the input, but at most n-1 swaps — the fewest "
                + "writes of the comparison-based simple sorts after cycle sort — which makes it "
                + "attractive when writes are far more expensive than reads. It is not stable."
        },
        {
            id: "insertion", title: "Insertion Sort", category: "Simple sorts", algo: "Insertion",
            summary: "Insert each element into its place in the growing sorted prefix.",
            stable: "Stable", inPlace: "In-place", best: "O(n)", avg: "O(n²)", worst: "O(n²)",
            space: "O(1)", source: "core/modules/simple_sorts/insertion.ixx",
            body: "Insertion sort takes each element as a 'key' and shifts the larger elements "
                + "of the sorted prefix one slot right until the key's place opens up, then drops "
                + "it in. It is stable, in-place, and adaptive: nearly-sorted input costs ~O(n), "
                + "which (with its tiny constant factors) makes it the method of choice for small "
                + "or almost-ordered arrays and the base case inside faster divide-and-conquer sorts."
        },
        {
            id: "cocktail", title: "Cocktail Shaker Sort", category: "Simple sorts", algo: "Cocktail",
            summary: "Bidirectional bubble sort — bubble up, then bubble down, each round.",
            stable: "Stable", inPlace: "In-place", best: "O(n)", avg: "O(n²)", worst: "O(n²)",
            space: "O(1)", source: "core/modules/simple_sorts/cocktail.ixx",
            body: "Cocktail shaker sort is bubble sort that alternates direction: one pass "
                + "bubbles the largest element to the right end, the next bubbles the smallest to "
                + "the left end, so the sorted region grows from both sides. This fixes bubble "
                + "sort's 'turtles' — small values near the end that otherwise crawl left one "
                + "step per pass — so it is typically a constant factor faster, though still O(n²)."
        },
        {
            id: "cycle", title: "Cycle Sort", category: "Simple sorts", algo: "Cycle",
            summary: "Write-optimal: each element is written to its final slot exactly once.",
            stable: "Not stable", inPlace: "In-place", best: "O(n²)", avg: "O(n²)", worst: "O(n²)",
            space: "O(1)", source: "core/modules/simple_sorts/cycle.ixx",
            body: "Cycle sort is the theoretically write-optimal sort: for each start position it "
                + "counts how many elements are smaller to find where the held item belongs, places "
                + "it there, and follows the resulting cycle of displacements until it closes. Every "
                + "element is written exactly once, so the number of writes is the minimum possible — "
                + "invaluable when writes dominate (flash/EEPROM wear). It pays for this with Θ(n²) "
                + "comparisons and is not stable."
        },
        {
            id: "merge", title: "Merge Sort", category: "Efficient sorts", algo: "Merge",
            summary: "Stable divide-and-conquer: split in half, sort each, merge the runs.",
            stable: "Stable", inPlace: "Not in-place", best: "O(n log n)", avg: "O(n log n)", worst: "O(n log n)",
            space: "O(n)", source: "core/modules/efficient_sorts/merge.ixx",
            body: "Merge sort recursively splits the array into halves until each piece is "
                + "trivially sorted, then merges adjacent sorted runs by repeatedly taking the "
                + "smaller head element. It guarantees Θ(n log n) comparisons in every case — "
                + "best, average and worst — and is stable, which makes it the go-to for "
                + "linked lists and external (on-disk) sorting. The cost is O(n) auxiliary "
                + "space for the merge buffer; taking the left element on ties preserves stability."
        },
        {
            id: "quick", title: "Quick Sort", category: "Efficient sorts", algo: "Quick",
            summary: "In-place divide-and-conquer: partition about a pivot, recurse on each side.",
            stable: "Not stable", inPlace: "In-place", best: "O(n log n)", avg: "O(n log n)", worst: "O(n²)",
            space: "O(log n)", source: "core/modules/efficient_sorts/quick.ixx",
            body: "Quick sort partitions the range about a chosen pivot so that smaller elements "
                + "move left and larger ones right, leaving the pivot in its final position, then "
                + "recurses on the two sides. With good pivots it runs in O(n log n) with very "
                + "small constants — usually the fastest general-purpose sort in practice — but a "
                + "poor pivot (this implementation uses the last element) degrades to O(n²) on "
                + "already-sorted input. It sorts in place and is not stable. Production sorts "
                + "mitigate the worst case with median-of-three or randomized pivots and introsort."
        },
        {
            id: "heap", title: "Heap Sort", category: "Efficient sorts", algo: "Heap",
            summary: "Build a max-heap, then repeatedly move the max to the end.",
            stable: "Not stable", inPlace: "In-place", best: "O(n log n)", avg: "O(n log n)", worst: "O(n log n)",
            space: "O(1)", source: "core/modules/efficient_sorts/heap.ixx",
            body: "Heap sort treats the array as a binary max-heap: it first heapifies the whole "
                + "array bottom-up, then repeatedly swaps the root (the maximum) to the end of the "
                + "unsorted region and sifts the new root down to restore the heap, growing a sorted "
                + "suffix. It achieves guaranteed Θ(n log n) time with only O(1) extra space — the "
                + "best worst-case guarantee of the in-place sorts — though its cache behaviour makes "
                + "it typically slower than quick sort in practice. It is not stable."
        },
        {
            id: "shell", title: "Shell Sort", category: "Advanced sorts", algo: "Shell",
            summary: "Gapped insertion sort: compare-and-shift elements far apart, shrinking the gap to 1.",
            stable: "Not stable", inPlace: "In-place", best: "O(n log n)", avg: "O(n^1.3)", worst: "O(n log²n)",
            space: "O(1)", source: "core/modules/advanced_sorts/shell.ixx",
            body: "Shell sort generalises insertion sort: it h-sorts the array for a decreasing sequence "
                + "of gaps h (here Knuth's 1, 4, 13, 40, …), so elements leap most of the way to their place "
                + "on the early wide-gap passes and the final gap-1 pass is a near-sorted insertion sort. "
                + "Those big early moves eliminate the 'turtles' that make insertion sort O(n²), bringing the "
                + "practical cost down to roughly O(n log²n) with a tiny, in-place implementation. It is not "
                + "stable, and its exact complexity depends on the gap sequence."
        },
        {
            id: "radix", title: "Radix Sort (LSD)", category: "Advanced sorts", algo: "Radix",
            summary: "Non-comparison: distribute into buckets by one key byte at a time, least-significant first.",
            stable: "Stable", inPlace: "Not in-place", best: "O(n·k)", avg: "O(n·k)", worst: "O(n·k)",
            space: "O(n + base)", source: "core/modules/advanced_sorts/radix.ixx",
            body: "Radix sort doesn't compare elements at all. It makes k passes — one per key 'digit', here a "
                + "byte (base 256), least-significant first — and in each pass stably distributes the elements "
                + "into 256 buckets by that byte, then concatenates them. After the most-significant byte the "
                + "array is fully ordered. It runs in O(n·k), i.e. linear in n for fixed-width keys, beating the "
                + "O(n log n) comparison lower bound — the trade-offs are O(n) extra space and that keys must map "
                + "to integers (this implementation uses an order-preserving bit transform so it also handles "
                + "negative and floating-point values). In the Analyzer its comparison count is zero."
        },
        {
            id: "counting", title: "Counting Sort", category: "Advanced sorts", algo: "Counting",
            summary: "Tally each key's occurrences, then write keys back in order by their counts.",
            stable: "Stable", inPlace: "Not in-place", best: "O(n + k)", avg: "O(n + k)", worst: "O(n + k)",
            space: "O(k)", source: "core/modules/advanced_sorts/counting.ixx",
            body: "Counting sort does no key comparisons at all. It counts how many times each key "
                + "value occurs, then walks the keys in order and writes each one back as many times as "
                + "it was counted. For a small integer key range [0, k] the tally is a flat array and the "
                + "whole thing is O(n + k) — linear when k = O(n). It is stable and is the building block "
                + "inside radix sort. The trade-off is O(k) space, so it's only practical when the key "
                + "range is modest; it excels on the 'few unique' workload. (This implementation tallies "
                + "distinct keys so it stays correct for any comparable value.)"
        },
        {
            id: "bucket", title: "Bucket Sort", category: "Advanced sorts", algo: "Bucket",
            summary: "Scatter values into range-based buckets, sort each, then concatenate.",
            stable: "Stable", inPlace: "Not in-place", best: "O(n + k)", avg: "O(n + k)", worst: "O(n²)",
            space: "O(n + k)", source: "core/modules/advanced_sorts/bucket.ixx",
            body: "Bucket sort spreads the n values into buckets by where they fall in the [min, max] "
                + "range, sorts each bucket (here with insertion sort), and concatenates the buckets in "
                + "order. When the data is roughly uniform the buckets stay tiny and it runs in O(n) "
                + "average time; if everything piles into one bucket it degrades to that bucket sort's "
                + "O(n²). It is stable, needs O(n) extra space, and applies to values that map to a "
                + "numeric range. It pairs naturally with uniformly-distributed input."
        },
        {
            id: "distributions", title: "Input Distributions", category: "Concepts", algo: "",
            summary: "Why the shape of the input — not just its size — decides a sort's speed.",
            stable: "", inPlace: "", best: "", avg: "", worst: "",
            space: "", source: "core/modules/gen/gen.ixx",
            body: "A simple sort's running time depends heavily on the input's order, not only its "
                + "length. Already-sorted input is the best case for the adaptive sorts (bubble, "
                + "cocktail, insertion) — they finish in ~O(n). Reversed input is their worst case. "
                + "'Nearly sorted' rewards adaptivity, while 'few unique' stresses duplicate-key "
                + "handling. The Analyzer lets you sweep each distribution so these differences "
                + "show up directly in the timing curves; the generators live in sa::gen."
        }
    ]
}
