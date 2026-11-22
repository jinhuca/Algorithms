#include "VisualizerController.h"

#include <QVector>

#include <algorithm>

#include <se/gen/gen.hpp>
#include <se/seq/seq.hpp>
#include <se/sequential_searches/linear.hpp>
#include <se/sequential_searches/sentinel.hpp>
#include <se/sorted_searches/binary.hpp>
#include <se/sorted_searches/ternary.hpp>
#include <se/sorted_searches/jump.hpp>
#include <se/sorted_searches/exponential.hpp>
#include <se/sorted_searches/interpolation.hpp>
#include <se/sorted_searches/fibonacci.hpp>

VisualizerController::VisualizerController(QObject* parent) : QObject(parent) {
    generate(32, 1);   // a small demo array so the canvas isn't empty on launch
}

void VisualizerController::setAlgorithm(const QString& a) {
    if (a == m_algorithm) return;
    m_algorithm = a;
    emit algorithmChanged();
    record();
}

void VisualizerController::setDistribution(const QString& d) {
    if (d == m_distribution) return;
    m_distribution = d;
    emit distributionChanged();
    // caller triggers generate() to rebuild with the new shape
}

void VisualizerController::setTargetMode(const QString& m) {
    if (m == m_targetMode) return;
    m_targetMode = m;
    m_customTarget = false;
    emit targetModeChanged();
    recomputeTarget();
    record();
}

std::vector<double> VisualizerController::buildArray(int n, quint64 seed) const {
    if (n < 1) n = 1;
    const std::size_t sz = static_cast<std::size_t>(n);
    if (m_distribution == QStringLiteral("Random"))     return se::gen::random_sorted(sz, seed);
    if (m_distribution == QStringLiteral("Few unique")) return se::gen::few_unique_sorted(sz, 5, seed);
    if (m_distribution == QStringLiteral("Gaussian"))   return se::gen::gaussian_sorted(sz, seed);
    return se::gen::sorted(sz);
}

void VisualizerController::recomputeTarget() {
    if (m_customTarget) { emit targetChanged(); return; }
    if (m_targetMode == QStringLiteral("Present: first"))  m_target = se::gen::present_target(m_array, 0.0);
    else if (m_targetMode == QStringLiteral("Present: last")) m_target = se::gen::present_target(m_array, 1.0);
    else if (m_targetMode == QStringLiteral("Absent"))     m_target = se::gen::missing_target(m_array);
    else                                                   m_target = se::gen::present_target(m_array, 0.5);
    emit targetChanged();
}

void VisualizerController::generate(int n, int seed) {
    if (seed != 0) m_seed = static_cast<quint64>(seed);
    m_array = buildArray(n, m_seed);
    QVector<double> values(static_cast<int>(m_array.size()));
    for (int i = 0; i < values.size(); ++i) values[i] = m_array[static_cast<std::size_t>(i)];
    m_bars.resetData(values);
    emit arrayChanged();
    m_customTarget = false;
    recomputeTarget();
    record();
}

void VisualizerController::setCustomTarget(double value) {
    m_customTarget = true;
    m_target = value;
    emit targetChanged();
    record();
}

void VisualizerController::rebuild() { record(); }

// Run the selected search on the array with a recording tracer, so m_steps becomes the
// exact timeline the UI will replay. Ascending order (the array is sorted ascending).
void VisualizerController::record() {
    m_steps.clear();
    auto rec = se::tracer([this](const se::step& s) { m_steps.push_back(s); });
    const double t = m_target;

    if (m_algorithm == QStringLiteral("Linear"))             se::linear_search(m_array, t, se::less{}, rec);
    else if (m_algorithm == QStringLiteral("Sentinel"))      se::sentinel_search(m_array, t, se::less{}, rec);
    else if (m_algorithm == QStringLiteral("Ternary"))       se::ternary_search(m_array, t, se::less{}, rec);
    else if (m_algorithm == QStringLiteral("Jump"))          se::jump_search(m_array, t, se::less{}, rec);
    else if (m_algorithm == QStringLiteral("Exponential"))   se::exponential_search(m_array, t, se::less{}, rec);
    else if (m_algorithm == QStringLiteral("Interpolation")) se::interpolation_search(m_array, t, se::less{}, rec);
    else if (m_algorithm == QStringLiteral("Fibonacci"))     se::fibonacci_search(m_array, t, se::less{}, rec);
    else                                                     se::binary_search(m_array, t, se::less{}, rec);

    emit timelineChanged();
    seek(-1);
}

// Compute per-bar states + running stats for the current cursor and push them to the
// bar model in one coalesced update. Replays the window/eliminate events up to the
// cursor to rebuild the sliding [lo, hi] window and the discarded regions.
void VisualizerController::render() {
    const int n = size();
    const bool sequential = (categoryOf(m_algorithm) == QStringLiteral("Sequential"));

    QVector<int> states(n, BarModel::Idle);
    std::vector<char> eliminated(static_cast<std::size_t>(n), 0);
    int lo = 0, hi = n - 1;
    bool windowActive = false;
    m_foundIndex = -1;
    m_probes = 0;

    auto inRange = [n](int idx) { return idx >= 0 && idx < n; };

    for (int k = 0; k <= m_cursor && k < stepCount(); ++k) {
        const se::step& s = m_steps[static_cast<std::size_t>(k)];
        const int i = static_cast<int>(s.i), j = static_cast<int>(s.j);
        switch (s.kind) {
            case se::evt::probe:    ++m_probes; break;
            case se::evt::lo_bound: if (inRange(i)) { lo = i; windowActive = true; } break;
            case se::evt::hi_bound: if (inRange(i)) { hi = i; windowActive = true; } break;
            case se::evt::eliminate:
                for (int p = i; p <= j && inRange(p); ++p) eliminated[static_cast<std::size_t>(p)] = 1;
                break;
            case se::evt::found: if (inRange(i)) m_foundIndex = i; break;
            default: break;
        }
    }

    // Base layer: the active window (sorted searches) painted as candidates.
    if (windowActive)
        for (int k = lo; k <= hi; ++k) if (inRange(k)) states[k] = BarModel::Window;

    // Discarded regions.
    int elimCount = 0;
    for (int k = 0; k < n; ++k)
        if (eliminated[static_cast<std::size_t>(k)]) { states[k] = BarModel::Eliminated; ++elimCount; }

    // For the sequential searches (no lo/hi window) the scanned-and-rejected prefix is
    // the discarded region: mark every already-probed index as eliminated.
    if (sequential) {
        for (int k = 0; k < m_cursor && k < stepCount(); ++k) {
            const se::step& s = m_steps[static_cast<std::size_t>(k)];
            if (s.kind == se::evt::probe && inRange(static_cast<int>(s.i)))
                states[static_cast<int>(s.i)] = BarModel::Eliminated;
        }
    }

    m_remaining = n - elimCount;

    // Highlight the current step on top.
    m_note.clear();
    m_stepKind.clear();
    m_stepLine = -1;
    if (m_cursor >= 0 && m_cursor < stepCount()) {
        const se::step& s = m_steps[static_cast<std::size_t>(m_cursor)];
        const int i = static_cast<int>(s.i), j = static_cast<int>(s.j);
        m_stepLine = s.line;
        switch (s.kind) {
            case se::evt::probe:
                if (inRange(i)) states[i] = BarModel::Probe;
                m_stepKind = QStringLiteral("probe");
                m_note = QStringLiteral("Probe a[%1] = %2  (target %3)")
                             .arg(i).arg(s.value, 0, 'g', 4).arg(m_target, 0, 'g', 4);
                break;
            case se::evt::mid:
                if (inRange(i)) states[i] = BarModel::Probe;
                m_stepKind = QStringLiteral("mid");
                m_note = QStringLiteral("Midpoint a[%1] = %2").arg(i).arg(s.value, 0, 'g', 4);
                break;
            case se::evt::lo_bound:
                m_stepKind = QStringLiteral("lo_bound");
                m_note = QStringLiteral("Low bound → %1").arg(i); break;
            case se::evt::hi_bound:
                m_stepKind = QStringLiteral("hi_bound");
                m_note = QStringLiteral("High bound → %1").arg(i); break;
            case se::evt::eliminate:
                m_stepKind = QStringLiteral("eliminate");
                m_note = QStringLiteral("Discard a[%1 … %2]").arg(i).arg(j); break;
            case se::evt::found:
                if (inRange(i)) states[i] = BarModel::Found;
                m_stepKind = QStringLiteral("found");
                m_note = QStringLiteral("Found target at index %1").arg(i); break;
            case se::evt::not_found:
                m_stepKind = QStringLiteral("not_found");
                m_note = QStringLiteral("Target is not present"); break;
            default: break;
        }
    }
    if (inRange(m_foundIndex)) states[m_foundIndex] = BarModel::Found;

    // Final result string (shown when the run reaches the end).
    if (finished())
        m_result = (m_foundIndex >= 0)
                       ? QStringLiteral("Found at index %1 · %2 probes").arg(m_foundIndex).arg(m_probes)
                       : QStringLiteral("Not found · %1 probes").arg(m_probes);
    else
        m_result.clear();

    m_bars.updateStates(states);
    emit cursorChanged();
}

void VisualizerController::stepForward() {
    if (m_cursor + 1 >= stepCount()) return;
    ++m_cursor;
    render();
}

void VisualizerController::stepBack() {
    if (m_cursor < 0) return;
    --m_cursor;
    render();
}

void VisualizerController::seek(int target) {
    if (target < -1) target = -1;
    if (target > stepCount() - 1) target = stepCount() - 1;
    m_cursor = target;
    render();
}
