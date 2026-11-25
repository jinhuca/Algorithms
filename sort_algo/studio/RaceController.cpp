#include "RaceController.h"

#include <algorithm>
#include <utility>

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

namespace {
    std::vector<double> buildArray(const QString& dist, int n, quint64 seed) {
        const std::size_t sz = static_cast<std::size_t>(n < 1 ? 1 : n);
        if (dist == QStringLiteral("Sorted"))        return sa::gen::sorted(sz);
        if (dist == QStringLiteral("Reversed"))      return sa::gen::reversed(sz);
        if (dist == QStringLiteral("Nearly sorted")) return sa::gen::nearly_sorted(sz, 0, seed);
        if (dist == QStringLiteral("Few unique"))    return sa::gen::few_unique(sz, 5, seed);
        if (dist == QStringLiteral("Gaussian"))      return sa::gen::gaussian(sz, seed);
        return sa::gen::random(sz, seed);
    }

    std::vector<sa::step> recordTrace(const QString& algo, const std::vector<double>& initial) {
        std::vector<double> v = initial;
        std::vector<sa::step> steps;
        steps.reserve(v.size() * 4);
        auto rec = sa::tracer([&steps](const sa::step& s) { steps.push_back(s); });
        if (algo == QStringLiteral("Selection"))      sa::selection_sort(v, sa::less{}, rec);
        else if (algo == QStringLiteral("Insertion")) sa::insertion_sort(v, sa::less{}, rec);
        else if (algo == QStringLiteral("Cocktail"))  sa::cocktail_sort(v, sa::less{}, rec);
        else if (algo == QStringLiteral("Cycle"))     sa::cycle_sort(v, sa::less{}, rec);
        else if (algo == QStringLiteral("Merge"))     sa::merge_sort(v, sa::less{}, rec);
        else if (algo == QStringLiteral("Quick"))     sa::quick_sort(v, sa::less{}, rec);
        else if (algo == QStringLiteral("Heap"))      sa::heap_sort(v, sa::less{}, rec);
        else if (algo == QStringLiteral("Shell"))     sa::shell_sort(v, sa::less{}, rec);
        else if (algo == QStringLiteral("Radix"))     sa::radix_sort(v, rec);
        else if (algo == QStringLiteral("Counting"))  sa::counting_sort(v, rec);
        else if (algo == QStringLiteral("Bucket"))    sa::bucket_sort(v, rec);
        else                                          sa::bubble_sort(v, sa::less{}, rec);
        return steps;
    }
}  // namespace

// ---- RaceLane --------------------------------------------------------------
RaceLane::RaceLane(QString name, std::vector<double> initial, std::vector<sa::step> steps,
                   QObject* parent)
    : QObject(parent), m_name(std::move(name)), m_initial(std::move(initial)),
      m_steps(std::move(steps)) {
    m_max = 1.0;
    for (double x : m_initial) if (x > m_max) m_max = x;
    reset();
}

void RaceLane::reset() {
    m_current = m_initial;
    m_sorted.assign(static_cast<int>(m_initial.size()), 0);
    m_cursor = -1;
    m_done = m_steps.empty();
    m_rank = 0;
    render();
    emit changed();
}

bool RaceLane::advance() {
    if (m_done || m_cursor + 1 >= static_cast<int>(m_steps.size())) return false;
    ++m_cursor;
    const sa::step& s = m_steps[static_cast<std::size_t>(m_cursor)];
    if (s.kind == sa::evt::swap && s.i < m_current.size() && s.j < m_current.size())
        std::swap(m_current[s.i], m_current[s.j]);
    else if (s.kind == sa::evt::overwrite && s.i < m_current.size())
        m_current[s.i] = s.value;
    else if (s.kind == sa::evt::mark_sorted && s.i < static_cast<sa::index>(m_sorted.size()))
        m_sorted[static_cast<int>(s.i)] = 1;
    render();
    const bool justFinished = (m_cursor + 1 >= static_cast<int>(m_steps.size()));
    if (justFinished) m_done = true;
    emit changed();
    return justFinished;
}

void RaceLane::render() {
    const int n = static_cast<int>(m_current.size());
    QVector<double> values(n);
    for (int i = 0; i < n; ++i) values[i] = m_current[static_cast<std::size_t>(i)];

    QVector<int> states(n, BarModel::Idle);
    for (int i = 0; i < n; ++i) if (m_sorted[i]) states[i] = BarModel::Sorted;

    if (m_cursor >= 0 && m_cursor < static_cast<int>(m_steps.size())) {
        const sa::step& s = m_steps[static_cast<std::size_t>(m_cursor)];
        auto mark = [&](sa::index idx, int st) {
            if (idx < static_cast<sa::index>(n)) states[static_cast<int>(idx)] = st;
        };
        switch (s.kind) {
            case sa::evt::compare:   mark(s.i, BarModel::Comparing); mark(s.j, BarModel::Comparing); break;
            case sa::evt::swap:      mark(s.i, BarModel::Swapping); mark(s.j, BarModel::Swapping); break;
            case sa::evt::overwrite: mark(s.i, BarModel::Swapping); break;
            case sa::evt::cursor:
            case sa::evt::read:      mark(s.i, BarModel::Cursor); break;
            default: break;
        }
    }
    m_bars.update(values, states);
}

// ---- RaceController --------------------------------------------------------
RaceController::RaceController(QObject* parent) : QObject(parent) {}

void RaceController::clearLanes() {
    qDeleteAll(m_lanes);
    m_lanes.clear();
    m_finishedCount = 0;
}

void RaceController::start(const QStringList& algos, int n, const QString& distribution, int seed) {
    clearLanes();
    m_size = (n < 2) ? 2 : (n > 400 ? 400 : n);
    const std::vector<double> initial = buildArray(distribution, m_size, static_cast<quint64>(seed));
    for (const QString& algo : algos)
        m_lanes.push_back(new RaceLane(algo, initial, recordTrace(algo, initial), this));
    emit lanesChanged();
    emit finishedChanged();
}

void RaceController::stepAll() {
    bool any = false;
    for (QObject* o : m_lanes) {
        auto* lane = static_cast<RaceLane*>(o);
        if (lane->done()) continue;
        any = true;
        if (lane->advance()) lane->setRank(++m_finishedCount);
    }
    if (any && finished()) emit finishedChanged();
}

void RaceController::resetAll() {
    m_finishedCount = 0;
    for (QObject* o : m_lanes) static_cast<RaceLane*>(o)->reset();
    emit finishedChanged();
}

}  // namespace sa::studio
