#include "StabilityController.h"

#include <QVariantMap>

#include <random>
#include <vector>

#include <sa/simple_sorts/bubble.hpp>
#include <sa/simple_sorts/cocktail.hpp>
#include <sa/simple_sorts/cycle.hpp>
#include <sa/simple_sorts/insertion.hpp>
#include <sa/simple_sorts/selection.hpp>
#include <sa/efficient_sorts/heap.hpp>
#include <sa/efficient_sorts/merge.hpp>
#include <sa/efficient_sorts/quick.hpp>
#include <sa/advanced_sorts/shell.hpp>

namespace sa::studio {

namespace {
    // One element: the key we sort by + its original position (0-based). A key-only
    // comparator means equal keys are "ties", so the algorithm's stability decides
    // whether `origin` order survives.
    struct Item {
        double key;
        int origin;
    };
    struct ByKey {
        bool operator()(const Item& a, const Item& b) const { return a.key < b.key; }
    };

    void sortWith(const QString& algo, std::vector<Item>& v) {
        ByKey cmp;
        if (algo == QStringLiteral("Selection"))      sa::selection_sort(v, cmp);
        else if (algo == QStringLiteral("Insertion")) sa::insertion_sort(v, cmp);
        else if (algo == QStringLiteral("Cocktail"))  sa::cocktail_sort(v, cmp);
        else if (algo == QStringLiteral("Cycle"))     sa::cycle_sort(v, cmp);
        else if (algo == QStringLiteral("Merge"))     sa::merge_sort(v, cmp);
        else if (algo == QStringLiteral("Quick"))     sa::quick_sort(v, cmp);
        else if (algo == QStringLiteral("Heap"))      sa::heap_sort(v, cmp);
        else if (algo == QStringLiteral("Shell"))     sa::shell_sort(v, cmp);
        else                                          sa::bubble_sort(v, cmp);
    }
}  // namespace

StabilityController::StabilityController(QObject* parent) : QObject(parent) {
    run(32, 4, 1);   // a demo on launch
}

void StabilityController::setAlgorithm(const QString& a) {
    if (a == m_algorithm) return;
    m_algorithm = a;
    emit algorithmChanged();
    recompute();     // re-sort the same input with the new algorithm
}

void StabilityController::run(int n, int levels, int seed) {
    m_n = qBound(2, n, 120);
    m_levels = qBound(2, levels, 12);
    m_seed = seed;
    recompute();
}

void StabilityController::recompute() {
    std::mt19937 rng(static_cast<unsigned>(m_seed ? m_seed : 1));
    std::uniform_int_distribution<int> lvl(1, m_levels);

    std::vector<Item> items(static_cast<std::size_t>(m_n));
    for (int i = 0; i < m_n; ++i) items[static_cast<std::size_t>(i)] = Item{double(lvl(rng)), i};

    std::vector<Item> sorted = items;
    sortWith(m_algorithm, sorted);

    // Stable iff, within every equal-key run, origins stay ascending (they start as
    // 0..n-1 in input order, so ascending == original order preserved).
    m_stable = true;
    for (std::size_t i = 1; i < sorted.size(); ++i)
        if (sorted[i].key == sorted[i - 1].key && sorted[i].origin < sorted[i - 1].origin) {
            m_stable = false;
            break;
        }

    auto toList = [](const std::vector<Item>& v) {
        QVariantList out;
        out.reserve(static_cast<int>(v.size()));
        for (const Item& it : v) {
            QVariantMap m;
            m[QStringLiteral("key")] = it.key;
            m[QStringLiteral("origin")] = it.origin;
            out.push_back(m);
        }
        return out;
    };
    m_before = toList(items);
    m_after = toList(sorted);
    m_count = m_n;
    m_keyLevels = m_levels;
    emit resultChanged();
}

}  // namespace sa::studio
