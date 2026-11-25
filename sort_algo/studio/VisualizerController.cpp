#include "VisualizerController.h"

#include "version.h"   // SA_APP_VERSION (generated)

#include <QRegularExpression>
#include <QStringList>
#include <QVector>

#include <algorithm>
#include <functional>

#include <sa/gen/gen.hpp>
#include <sa/seq/seq.hpp>
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

namespace sa::studio {

QString VisualizerController::appVersion() const { return QStringLiteral(SA_APP_VERSION); }

VisualizerController::VisualizerController(QObject* parent) : QObject(parent) {
    generate(40, 1);   // a small demo array so the canvas isn't empty on launch
}

void VisualizerController::setAlgorithm(const QString& a) {
    if (a == m_algorithm) return;
    m_algorithm = a;
    emit algorithmChanged();
    rebuild();          // re-record the trace for the same array with the new algo
}

void VisualizerController::setDistribution(const QString& d) {
    if (d == m_distribution) return;
    m_distribution = d;
    emit distributionChanged();
}

void VisualizerController::setDescending(bool d) {
    if (d == m_descending) return;
    m_descending = d;
    emit descendingChanged();
    record();          // re-record with the new order
}

std::vector<double> VisualizerController::buildArray(int n, quint64 seed) const {
    if (n < 1) n = 1;
    const std::size_t sz = static_cast<std::size_t>(n);
    if (m_distribution == QStringLiteral("Sorted"))        return sa::gen::sorted(sz);
    if (m_distribution == QStringLiteral("Reversed"))      return sa::gen::reversed(sz);
    if (m_distribution == QStringLiteral("Nearly sorted")) return sa::gen::nearly_sorted(sz, 0, seed);
    if (m_distribution == QStringLiteral("Few unique"))    return sa::gen::few_unique(sz, 5, seed);
    if (m_distribution == QStringLiteral("Gaussian"))      return sa::gen::gaussian(sz, seed);
    return sa::gen::random(sz, seed);
}

void VisualizerController::generate(int n, int seed) {
    if (seed != 0) m_seed = static_cast<quint64>(seed);
    m_initial = buildArray(n, m_seed);
    emit arrayChanged();
    record();
}

void VisualizerController::shuffle() {
    m_distribution = QStringLiteral("Random");
    emit distributionChanged();
    m_seed = m_seed * 6364136223846793005ull + 1442695040888963407ull;   // next seed
    m_initial = buildArray(size() ? size() : 40, m_seed);
    emit arrayChanged();
    record();
}

void VisualizerController::setValuesFromText(const QString& text) {
    // Split on anything that isn't part of a number; parse each token.
    static const QRegularExpression sep(QStringLiteral("[^0-9eE.+-]+"));
    std::vector<double> vals;
    for (const QString& tok : text.split(sep, Qt::SkipEmptyParts)) {
        bool ok = false;
        const double d = tok.toDouble(&ok);
        if (ok) vals.push_back(d);
        if (vals.size() >= 500) break;              // keep the canvas sane
    }
    if (vals.empty()) return;                        // nothing parseable -> leave as is
    m_initial = std::move(vals);
    emit arrayChanged();
    record();
}

void VisualizerController::rebuild() {
    record();
}

// Run the selected sort on a copy of the initial array with a recording tracer, so
// m_steps becomes the exact timeline the UI will replay.
void VisualizerController::record() {
    std::vector<double> v = m_initial;
    m_steps.clear();
    m_steps.reserve(v.size() * 4);
    auto rec = sa::tracer([this](const sa::step& s) { m_steps.push_back(s); });

    // Ascending or descending order for the comparison sorts (radix is ascending-only).
    const bool desc = m_descending;
    auto cmp = [desc](const double& a, const double& b) { return desc ? (b < a) : (a < b); };

    if (m_algorithm == QStringLiteral("Selection"))      sa::selection_sort(v, cmp, rec);
    else if (m_algorithm == QStringLiteral("Insertion")) sa::insertion_sort(v, cmp, rec);
    else if (m_algorithm == QStringLiteral("Cocktail"))  sa::cocktail_sort(v, cmp, rec);
    else if (m_algorithm == QStringLiteral("Cycle"))     sa::cycle_sort(v, cmp, rec);
    else if (m_algorithm == QStringLiteral("Merge"))     sa::merge_sort(v, cmp, rec);
    else if (m_algorithm == QStringLiteral("Quick"))     sa::quick_sort(v, cmp, rec);
    else if (m_algorithm == QStringLiteral("Heap"))      sa::heap_sort(v, cmp, rec);
    else if (m_algorithm == QStringLiteral("Shell"))     sa::shell_sort(v, cmp, rec);
    else if (m_algorithm == QStringLiteral("Radix"))     sa::radix_sort(v, rec);
    else if (m_algorithm == QStringLiteral("Counting"))  sa::counting_sort(v, rec);
    else if (m_algorithm == QStringLiteral("Bucket"))    sa::bucket_sort(v, rec);
    else                                                 sa::bubble_sort(v, cmp, rec);

    emit timelineChanged();
    seek(-1);            // rewind to the start and render the initial array
}

void VisualizerController::rebuildValues(int target) {
    m_current = m_initial;
    for (int k = 0; k <= target && k < stepCount(); ++k) {
        const sa::step& s = m_steps[static_cast<std::size_t>(k)];
        if (s.kind == sa::evt::swap && s.i < m_current.size() && s.j < m_current.size())
            std::swap(m_current[s.i], m_current[s.j]);
        else if (s.kind == sa::evt::overwrite && s.i < m_current.size())
            m_current[s.i] = s.value;
    }
}

// Compute per-bar states + running stats for the current cursor and push everything
// to the bar model in one coalesced update.
void VisualizerController::render() {
    const int n = size();
    QVector<double> values(n);
    for (int i = 0; i < n; ++i) values[i] = m_current[static_cast<std::size_t>(i)];

    QVector<int> states(n, BarModel::Idle);
    m_comparisons = m_swaps = m_writes = 0;
    for (int k = 0; k <= m_cursor && k < stepCount(); ++k) {
        const sa::step& s = m_steps[static_cast<std::size_t>(k)];
        switch (s.kind) {
            case sa::evt::compare:   ++m_comparisons; break;
            case sa::evt::swap:      ++m_swaps; m_writes += 2; break;
            case sa::evt::overwrite: ++m_writes; break;
            case sa::evt::mark_sorted:
                if (s.i < static_cast<sa::index>(n)) states[static_cast<int>(s.i)] = BarModel::Sorted;
                break;
            default: break;
        }
    }

    // Highlight the current step's operands on top of the accumulated sorted state,
    // and publish a human-readable narration + the step kind (drives the pseudocode
    // panel's highlighted line).
    m_note.clear();
    m_stepKind.clear();
    m_stepLine = -1;
    m_stepValue = 0.0;
    if (m_cursor >= 0 && m_cursor < stepCount()) {
        const sa::step& s = m_steps[static_cast<std::size_t>(m_cursor)];
        m_stepLine = s.line;
        auto mark = [&](sa::index idx, int st) {
            if (idx < static_cast<sa::index>(n)) states[static_cast<int>(idx)] = st;
        };
        const int i = static_cast<int>(s.i), j = static_cast<int>(s.j);

        // Normalised value of the current operand (for the sound pitch).
        if (s.i < static_cast<sa::index>(n)) {
            double lo = m_current[0], hi = m_current[0];
            for (double x : m_current) { if (x < lo) lo = x; if (x > hi) hi = x; }
            m_stepValue = (hi > lo) ? (m_current[s.i] - lo) / (hi - lo) : 0.5;
        }
        switch (s.kind) {
            case sa::evt::compare:   mark(s.i, BarModel::Comparing); mark(s.j, BarModel::Comparing);
                                     m_stepKind = QStringLiteral("compare");
                                     m_note = QStringLiteral("Compare a[%1] and a[%2]").arg(i).arg(j); break;
            case sa::evt::swap:      mark(s.i, BarModel::Swapping); mark(s.j, BarModel::Swapping);
                                     m_stepKind = QStringLiteral("swap");
                                     m_note = QStringLiteral("Swap a[%1] ↔ a[%2]").arg(i).arg(j); break;
            case sa::evt::overwrite: mark(s.i, BarModel::Swapping);
                                     m_stepKind = QStringLiteral("overwrite");
                                     m_note = QStringLiteral("Write %1 to a[%2]").arg(s.value, 0, 'g', 4).arg(i); break;
            case sa::evt::cursor:    mark(s.i, BarModel::Cursor);
                                     m_stepKind = QStringLiteral("cursor");
                                     m_note = QStringLiteral("Hold key a[%1] = %2").arg(i).arg(s.value, 0, 'g', 4); break;
            case sa::evt::read:      mark(s.i, BarModel::Cursor);
                                     m_stepKind = QStringLiteral("read");
                                     m_note = QStringLiteral("Read a[%1]").arg(i); break;
            case sa::evt::pass_boundary: m_stepKind = QStringLiteral("pass_boundary");
                                     m_note = QString::fromStdString(s.note); break;
            default: break;
        }
    }

    m_bars.update(values, states);
    emit cursorChanged();
}

void VisualizerController::stepForward() {
    if (m_cursor + 1 >= stepCount()) return;
    const sa::step& s = m_steps[static_cast<std::size_t>(m_cursor + 1)];
    if (s.kind == sa::evt::swap && s.i < m_current.size() && s.j < m_current.size())
        std::swap(m_current[s.i], m_current[s.j]);
    else if (s.kind == sa::evt::overwrite && s.i < m_current.size())
        m_current[s.i] = s.value;
    ++m_cursor;
    render();
}

void VisualizerController::stepBack() {
    if (m_cursor < 0) return;
    seek(m_cursor - 1);
}

void VisualizerController::seek(int target) {
    if (target < -1) target = -1;
    if (target > stepCount() - 1) target = stepCount() - 1;
    m_cursor = target;
    rebuildValues(target);
    render();
}

}  // namespace sa::studio
