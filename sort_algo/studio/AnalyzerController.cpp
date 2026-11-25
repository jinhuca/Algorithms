#include "AnalyzerController.h"

#include <QFile>
#include <QMetaObject>
#include <QTextStream>

#include <chrono>

#if defined(_WIN32)
#  ifndef NOMINMAX
#    define NOMINMAX
#  endif
#  ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#  endif
#  include <windows.h>
#endif

#include <sa/bench/bench.hpp>
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

AnalyzerController::AnalyzerController(QObject* parent) : QObject(parent) {
    // Coalesce resultsChanged (which drives the chart) to a few times a second so a
    // burst of fast cells can't flood the GUI with chart re-reads.
    m_flush.setInterval(200);
    connect(&m_flush, &QTimer::timeout, this, [this] {
        if (m_resultsDirty) { m_resultsDirty = false; emit resultsChanged(); }
    });
    m_flush.start();
}

AnalyzerController::~AnalyzerController() {
    m_cancel = true;
    if (m_worker.joinable()) m_worker.join();
}

std::vector<double> AnalyzerController::buildArray(const QString& dist, int n, quint64 seed) {
    const std::size_t sz = static_cast<std::size_t>(n);
    if (dist == QStringLiteral("Sorted"))        return sa::gen::sorted(sz);
    if (dist == QStringLiteral("Reversed"))      return sa::gen::reversed(sz);
    if (dist == QStringLiteral("Nearly sorted")) return sa::gen::nearly_sorted(sz, 0, seed);
    if (dist == QStringLiteral("Few unique"))    return sa::gen::few_unique(sz, 5, seed);
    if (dist == QStringLiteral("Gaussian"))      return sa::gen::gaussian(sz, seed);
    return sa::gen::random(sz, seed);
}

void AnalyzerController::runAlgo(const QString& algo, std::vector<double> data) {
    if (algo == QStringLiteral("Selection"))      sa::selection_sort(data);
    else if (algo == QStringLiteral("Insertion")) sa::insertion_sort(data);
    else if (algo == QStringLiteral("Cocktail"))  sa::cocktail_sort(data);
    else if (algo == QStringLiteral("Cycle"))     sa::cycle_sort(data);
    else if (algo == QStringLiteral("Merge"))     sa::merge_sort(data);
    else if (algo == QStringLiteral("Quick"))     sa::quick_sort(data);
    else if (algo == QStringLiteral("Heap"))      sa::heap_sort(data);
    else if (algo == QStringLiteral("Shell"))     sa::shell_sort(data);
    else if (algo == QStringLiteral("Radix"))     sa::radix_sort(data);
    else if (algo == QStringLiteral("Counting"))  sa::counting_sort(data);
    else if (algo == QStringLiteral("Bucket"))    sa::bucket_sort(data);
    else                                          sa::bubble_sort(data);
    sa::bench::do_not_optimize(data);
}

void AnalyzerController::countAlgo(const QString& algo, std::vector<double> data,
                                   std::size_t& compares, std::size_t& swaps,
                                   std::size_t& writes) {
    sa::bench::counters c;
    auto tr = sa::bench::count_into(c);
    if (algo == QStringLiteral("Selection"))      sa::selection_sort(data, sa::less{}, tr);
    else if (algo == QStringLiteral("Insertion")) sa::insertion_sort(data, sa::less{}, tr);
    else if (algo == QStringLiteral("Cocktail"))  sa::cocktail_sort(data, sa::less{}, tr);
    else if (algo == QStringLiteral("Cycle"))     sa::cycle_sort(data, sa::less{}, tr);
    else if (algo == QStringLiteral("Merge"))     sa::merge_sort(data, sa::less{}, tr);
    else if (algo == QStringLiteral("Quick"))     sa::quick_sort(data, sa::less{}, tr);
    else if (algo == QStringLiteral("Heap"))      sa::heap_sort(data, sa::less{}, tr);
    else if (algo == QStringLiteral("Shell"))     sa::shell_sort(data, sa::less{}, tr);
    else if (algo == QStringLiteral("Radix"))     sa::radix_sort(data, tr);
    else if (algo == QStringLiteral("Counting"))  sa::counting_sort(data, tr);
    else if (algo == QStringLiteral("Bucket"))    sa::bucket_sort(data, tr);
    else                                          sa::bubble_sort(data, sa::less{}, tr);
    compares = c.compare; swaps = c.swap; writes = c.writes();
}

quint64 AnalyzerController::threadCpuTimeNs() {
#if defined(_WIN32)
    FILETIME creation, exit, kernel, user;
    if (GetThreadTimes(GetCurrentThread(), &creation, &exit, &kernel, &user)) {
        const auto ticks = [](const FILETIME& f) {
            return (static_cast<quint64>(f.dwHighDateTime) << 32) | f.dwLowDateTime;
        };
        return (ticks(kernel) + ticks(user)) * 100ull;   // 100-ns ticks -> ns
    }
#endif
    return 0;
}

QString AnalyzerController::complexityOf(const QString& algo) const {
    if (algo == QStringLiteral("Selection")) return QStringLiteral("O(n²) · Θ(n²)");
    if (algo == QStringLiteral("Cycle"))     return QStringLiteral("O(n²) · min writes");
    if (algo == QStringLiteral("Merge"))     return QStringLiteral("O(n log n) · stable · O(n) space");
    if (algo == QStringLiteral("Quick"))     return QStringLiteral("O(n log n) avg · O(n²) worst");
    if (algo == QStringLiteral("Heap"))      return QStringLiteral("O(n log n) · in-place");
    if (algo == QStringLiteral("Shell"))     return QStringLiteral("O(n log²n) · in-place");
    if (algo == QStringLiteral("Radix"))     return QStringLiteral("O(n·k) · non-comparison");
    if (algo == QStringLiteral("Counting"))  return QStringLiteral("O(n + k) · non-comparison · stable");
    if (algo == QStringLiteral("Bucket"))    return QStringLiteral("O(n + k) avg · O(n²) worst");
    // Bubble / Insertion / Cocktail are adaptive: linear on already-sorted input.
    return QStringLiteral("O(n²) · O(n) best");
}

void AnalyzerController::run(const QVariantMap& config) {
    if (m_running) return;
    if (m_worker.joinable()) m_worker.join();

    const QStringList algos = config.value(QStringLiteral("algorithms")).toStringList();
    const QString dist = config.value(QStringLiteral("distribution"),
                                      QStringLiteral("Random")).toString();
    QList<int> sizes;
    for (const QVariant& v : config.value(QStringLiteral("sizes")).toList()) {
        const int n = v.toInt();
        if (n > 0 && n <= kMaxN) sizes.push_back(n);
    }
    const int reps = qMax(1, config.value(QStringLiteral("reps"), 5).toInt());
    const int warmup = qMax(0, config.value(QStringLiteral("warmup"), 1).toInt());
    const quint64 seed = static_cast<quint64>(config.value(QStringLiteral("seed"), 1).toInt());
    const bool countOps = config.value(QStringLiteral("countOps"), true).toBool();

    if (algos.isEmpty() || sizes.isEmpty()) {
        m_status = QStringLiteral("Pick at least one algorithm and one size.");
        emit statusChanged();
        return;
    }

    clearResults();
    m_cancel = false;
    m_running = true;
    emit runningChanged();
    m_progress = 0.0; emit progressChanged();
    m_status = QStringLiteral("Running…"); emit statusChanged();

    const int totalCells = sizes.size() * algos.size();

    m_worker = std::thread([this, algos, dist, sizes, reps, warmup, seed, countOps, totalCells] {
        int done = 0;
        for (int n : sizes) {
            if (m_cancel) break;
            for (const QString& algo : algos) {
                if (m_cancel) break;

                std::vector<double> base = buildArray(dist, n, seed);

                // Timed window, with CPU time measured around it (no extra timed runs).
                // cpuMs = average CPU time per iteration; cpuPct = CPU/wall. GetThreadTimes
                // has ~10–16 ms granularity, so cpuMs can read 0 for fast cells.
                const quint64 cpu0 = threadCpuTimeNs();
                const auto wall0 = std::chrono::steady_clock::now();
                auto r = sa::bench::time_it([&] { runAlgo(algo, base); }, reps, warmup);
                const auto wall1 = std::chrono::steady_clock::now();
                const quint64 cpu1 = threadCpuTimeNs();
                const quint64 cpuNs = cpu1 >= cpu0 ? cpu1 - cpu0 : 0;
                const double wallNs = std::chrono::duration<double, std::nano>(wall1 - wall0).count();
                const int iters = warmup + reps;
                const double cpuMs = iters > 0 ? (static_cast<double>(cpuNs) / 1.0e6) / iters : -1.0;
                const double cpuPct = wallNs > 0 ? static_cast<double>(cpuNs) / wallNs * 100.0 : -1.0;

                std::size_t compares = 0, swaps = 0, writes = 0;
                if (countOps) countAlgo(algo, base, compares, swaps, writes);

                // Peak heap bytes: one dedicated untimed, tracer-free run with the
                // allocation tracker on (kept separate so it skews neither timings nor
                // op counts). Zero unless mem_tracker.cpp is linked.
                sa::bench::mem::start();
                runAlgo(algo, base);
                sa::bench::mem::stop();
                const qulonglong peakBytes = static_cast<qulonglong>(sa::bench::mem::peak_bytes());

                QVariantMap row;
                row[QStringLiteral("algorithm")]  = algo;
                row[QStringLiteral("distribution")] = dist;
                row[QStringLiteral("n")]          = n;
                row[QStringLiteral("minMs")]      = r.min_ms;
                row[QStringLiteral("medianMs")]   = r.median_ms;
                row[QStringLiteral("meanMs")]     = r.mean_ms;
                row[QStringLiteral("stddevMs")]   = r.stddev_ms;
                row[QStringLiteral("compares")]   = static_cast<double>(compares);
                row[QStringLiteral("swaps")]      = static_cast<double>(swaps);
                row[QStringLiteral("writes")]     = static_cast<double>(writes);
                row[QStringLiteral("cpuMs")]      = cpuMs;
                row[QStringLiteral("cpuPct")]     = cpuPct;
                row[QStringLiteral("memBytes")]   = static_cast<double>(peakBytes);
                row[QStringLiteral("complexity")] = complexityOf(algo);

                ++done;
                const double prog = totalCells ? double(done) / double(totalCells) : 1.0;
                // Hand the finished row back to the GUI thread.
                QMetaObject::invokeMethod(this, [this, row, prog] {
                    m_model.appendRow(row);
                    m_results.push_back(row);
                    m_resultsDirty = true;
                    m_progress = prog; emit progressChanged();
                }, Qt::QueuedConnection);
            }
        }
        QMetaObject::invokeMethod(this, [this] {
            m_running = false; emit runningChanged();
            m_resultsDirty = true;                 // final chart refresh
            m_status = m_cancel ? QStringLiteral("Cancelled.") : QStringLiteral("Done.");
            emit statusChanged();
        }, Qt::QueuedConnection);
    });
}

void AnalyzerController::cancel() {
    if (m_running) { m_cancel = true; m_status = QStringLiteral("Cancelling…"); emit statusChanged(); }
}

void AnalyzerController::clearResults() {
    m_results.clear();
    m_model.resetRows();
    emit resultsChanged();
}

bool AnalyzerController::exportCsv(const QUrl& url) const {
    QFile f(url.toLocalFile());
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) return false;
    QTextStream out(&f);
    out << "algorithm,distribution,n,min_ms,median_ms,mean_ms,stddev_ms,cpu_ms,cpu_pct,peak_bytes,compares,swaps,writes,complexity\n";
    for (const QVariant& v : m_results) {
        const QVariantMap r = v.toMap();
        const double cpuMs = r.value(QStringLiteral("cpuMs"), -1.0).toDouble();
        const double cpuPct = r.value(QStringLiteral("cpuPct"), -1.0).toDouble();
        out << r.value(QStringLiteral("algorithm")).toString() << ','
            << r.value(QStringLiteral("distribution")).toString() << ','
            << r.value(QStringLiteral("n")).toInt() << ','
            << r.value(QStringLiteral("minMs")).toDouble() << ','
            << r.value(QStringLiteral("medianMs")).toDouble() << ','
            << r.value(QStringLiteral("meanMs")).toDouble() << ','
            << r.value(QStringLiteral("stddevMs")).toDouble() << ','
            << (cpuMs < 0 ? QString() : QString::number(cpuMs, 'g', 6)) << ','
            << (cpuPct < 0 ? QString() : QString::number(cpuPct, 'g', 4)) << ','
            << r.value(QStringLiteral("memBytes")).toDouble() << ','
            << r.value(QStringLiteral("compares")).toDouble() << ','
            << r.value(QStringLiteral("swaps")).toDouble() << ','
            << r.value(QStringLiteral("writes")).toDouble() << ','
            << '"' << r.value(QStringLiteral("complexity")).toString() << "\"\n";
    }
    f.close();
    return true;
}

}  // namespace sa::studio
