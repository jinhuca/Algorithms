#include "AnalyzerController.h"

#include <QFile>
#include <QMetaObject>
#include <QTextStream>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstddef>
#include <thread>
#include <vector>

#include <ga/basic_algo/bfs.hpp>
#include <ga/basic_algo/dfs.hpp>
#include <ga/bench/bench.hpp>
#include <ga/gen/gen.hpp>
#include <ga/mst/kruskal.hpp>
#include <ga/mst/prim.hpp>
#include <ga/short_paths/bellman_ford.hpp>
#include <ga/short_paths/dijkstra.hpp>

#if defined(_WIN32)
#  ifndef NOMINMAX
#    define NOMINMAX              // keep std::min/std::max usable
#  endif
#  ifndef WIN32_LEAN_AND_MEAN
#    define WIN32_LEAN_AND_MEAN
#  endif
#  include <windows.h>
#endif

namespace ga::studio {

AnalyzerController::AnalyzerController(QObject* parent) : QObject(parent) {
    // Coalesce chart updates: a dirty flag armed per cell is flushed at most ~8×/sec.
    m_flush.setInterval(120);
    m_flush.setSingleShot(true);
    connect(&m_flush, &QTimer::timeout, this, [this]() {
        if (m_resultsDirty) { m_resultsDirty = false; emit resultsChanged(); }
    });
}

void AnalyzerController::physicalMemory(quint64& total, quint64& avail) {
    total = 0;
    avail = 0;
#if defined(_WIN32)
    MEMORYSTATUSEX s;
    s.dwLength = sizeof(s);
    if (GlobalMemoryStatusEx(&s)) { total = s.ullTotalPhys; avail = s.ullAvailPhys; }
#endif
}

quint64 AnalyzerController::threadCpuTimeNs() {
#if defined(_WIN32)
    FILETIME creation, exit, kernel, user;
    if (GetThreadTimes(GetCurrentThread(), &creation, &exit, &kernel, &user)) {
        // kernel/user are in 100-ns ticks; combine and convert to ns.
        const auto ticks = [](const FILETIME& f) {
            return (static_cast<quint64>(f.dwHighDateTime) << 32) | f.dwLowDateTime;
        };
        return (ticks(kernel) + ticks(user)) * 100ull;
    }
#endif
    return 0;
}

AnalyzerController::~AnalyzerController() {
    // Signal the worker to stop, then WAIT for it. The worker reads m_cancel and
    // posts results back via invokeMethod(this, …); if we let it run past our
    // destruction it would touch freed memory (an intermittent shutdown crash).
    // Joining blocks at most until the current cell finishes (cancel is checked at
    // each (size, algorithm) boundary).
    m_cancel = true;
    if (m_worker.joinable()) m_worker.join();
}

ga::graph<double> AnalyzerController::buildGraph(const QString& family, int n, bool directed,
                                                 bool weighted, int avgDegree, quint64 seed,
                                                 int& nOut, int& mOut) {
    const double wlo = 1.0, whi = weighted ? 10.0 : 1.0;
    const std::size_t N = n > 0 ? static_cast<std::size_t>(n) : 0;
    ga::graph<double> g;
    if (family == QStringLiteral("grid")) {
        const std::size_t side = std::max<std::size_t>(1, static_cast<std::size_t>(std::lround(std::sqrt(static_cast<double>(N)))));
        g = ga::gen::grid<double>(side, side, wlo, whi, seed);
    } else if (family == QStringLiteral("complete")) {
        g = ga::gen::complete<double>(N, directed, wlo, whi, seed);
    } else if (family == QStringLiteral("scale-free")) {
        const std::size_t m = std::max(1, avgDegree / 2);
        g = ga::gen::scale_free<double>(N, m, seed, wlo, whi);
    } else {  // "random" (Erdős–Rényi)
        const std::size_t m = static_cast<std::size_t>(static_cast<long long>(N) * avgDegree / 2);
        g = ga::gen::random_gnm<double>(N, m, directed, seed, wlo, whi);
    }
    nOut = static_cast<int>(g.order());
    mOut = static_cast<int>(g.size());
    return g;
}

double AnalyzerController::estimatedGraphBytes(const QString& family, int n,
                                               bool directed, int avgDegree) {
    if (n <= 0) return 0.0;
    const double N = static_cast<double>(n);
    const double deg = static_cast<double>(std::max(1, avgDegree));
    double entries;   // number of stored directed-edge entries (both dirs if undirected)
    if (family == QStringLiteral("complete")) {
        entries = N * (N - 1.0);                                  // Θ(n²) — the stress case
    } else if (family == QStringLiteral("grid")) {
        const double side = std::max(1.0, std::round(std::sqrt(N)));
        entries = 4.0 * side * (side - 1.0);                     // ~4N, both directions
    } else if (family == QStringLiteral("scale-free")) {
        entries = 2.0 * N * std::max(1.0, std::floor(deg / 2.0));  // ~n·deg
    } else {  // "random" (Erdős–Rényi): m = n·deg/2, clamped to the max possible
        const double maxE = directed ? N * (N - 1.0) : N * (N - 1.0) / 2.0;
        const double m = std::min(N * deg / 2.0, maxE);
        entries = (directed ? 1.0 : 2.0) * m;
    }
    return entries * static_cast<double>(sizeof(ga::edge<double>));
}

static QString humanBytes(double n) {
    if (n < 1024.0) return QStringLiteral("%1 B").arg(static_cast<qulonglong>(n));
    if (n < 1024.0 * 1024.0) return QStringLiteral("%1 KB").arg(n / 1024.0, 0, 'f', 1);
    if (n < 1024.0 * 1024.0 * 1024.0) return QStringLiteral("%1 MB").arg(n / (1024.0 * 1024.0), 0, 'f', 1);
    return QStringLiteral("%1 GB").arg(n / (1024.0 * 1024.0 * 1024.0), 0, 'f', 1);
}

void AnalyzerController::runAlgo(const QString& algo, const ga::graph<double>& g,
                                 ga::vertex src, const ga::tracer& tr) {
    if (g.order() == 0) return;
    if (algo == QStringLiteral("Dijkstra")) {
        std::vector<ga::vertex> parent;
        auto d = ga::dijkstra(g, src, &parent, tr);
        ga::bench::do_not_optimize(d);
    } else if (algo == QStringLiteral("Bellman-Ford")) {
        std::vector<ga::vertex> parent;
        bool ok = true;
        auto d = ga::bellman_ford(g, src, &parent, &ok, tr);
        ga::bench::do_not_optimize(d);
    } else if (algo == QStringLiteral("Kruskal")) {
        auto w = ga::kruskal(g, tr);
        ga::bench::do_not_optimize(w);
    } else if (algo == QStringLiteral("Prim")) {
        auto w = ga::prim(g, src, tr);
        ga::bench::do_not_optimize(w);
    } else if (algo == QStringLiteral("DFS")) {
        auto p = ga::dfs(g, src, tr);
        ga::bench::do_not_optimize(p);
    } else {  // BFS
        auto p = ga::bfs(g, src, tr);
        ga::bench::do_not_optimize(p);
    }
}

ga::vertex AnalyzerController::pickSource(const ga::graph<double>& g) {
    const std::size_t n = g.order();
    if (n == 0) return 0;

    // Union-find over every edge (each directed edge u→v unions u and v), which
    // yields weakly-connected components for both directed and undirected graphs.
    std::vector<std::size_t> parent(n), sz(n, 1);
    for (std::size_t i = 0; i < n; ++i) parent[i] = i;
    auto find = [&](std::size_t x) {
        while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x]; }
        return x;
    };
    for (std::size_t u = 0; u < n; ++u)
        for (const auto& e : g.out(static_cast<ga::vertex>(u))) {
            std::size_t a = find(u), b = find(e.to);
            if (a == b) continue;
            if (sz[a] < sz[b]) std::swap(a, b);
            parent[b] = a;
            sz[a] += sz[b];
        }

    // Return a vertex (the root) of the largest component.
    std::size_t best = 0, bestSz = 0;
    for (std::size_t i = 0; i < n; ++i) {
        const std::size_t r = find(i);
        if (sz[r] > bestSz) { bestSz = sz[r]; best = r; }
    }
    return static_cast<ga::vertex>(best);
}

void AnalyzerController::run(const QVariantMap& config) {
    if (m_running) return;

    // Parse config on the GUI thread into plain values the worker captures by copy.
    const QStringList algos = config.value(QStringLiteral("algorithms")).toStringList();
    const QString family = config.value(QStringLiteral("family"), QStringLiteral("random")).toString();
    std::vector<int> sizes;
    for (const QVariant& s : config.value(QStringLiteral("sizes")).toList()) {
        const int v = s.toInt();
        if (v > 0) sizes.push_back(v);
    }
    const bool directed = config.value(QStringLiteral("directed"), false).toBool();
    const bool weighted = config.value(QStringLiteral("weighted"), false).toBool();
    const int avgDegree = std::max(1, config.value(QStringLiteral("avgDegree"), 4).toInt());
    const int reps = std::max(1, config.value(QStringLiteral("reps"), 5).toInt());
    const int warmup = std::max(0, config.value(QStringLiteral("warmup"), 1).toInt());
    const quint64 seed = config.value(QStringLiteral("seed"), 1).toULongLong();
    const bool countOps = config.value(QStringLiteral("countOps"), true).toBool();

    if (algos.isEmpty() || sizes.empty()) {
        m_status = QStringLiteral("Nothing to run — pick at least one algorithm and size.");
        emit statusChanged();
        return;
    }

    // Per-cell memory budget: the smaller of an absolute ceiling and a fraction of
    // the machine's *free* RAM, so a sweep never drives the system into swap (the
    // disk thrashing that both slows the run and corrupts its timings). Cells over
    // budget are skipped and reported; the rest run.
    quint64 physTotal = 0, physAvail = 0;
    physicalMemory(physTotal, physAvail);
    const double budget = std::min(static_cast<double>(kMaxGraphBytes),
                                   physAvail > 0 ? kRamBudgetFraction * static_cast<double>(physAvail)
                                                 : static_cast<double>(kMaxGraphBytes));
    std::vector<int> runnable;
    QStringList skipped;
    for (int n : sizes) {
        const double bytes = estimatedGraphBytes(family, n, directed, avgDegree);
        if (bytes > budget)
            skipped << QStringLiteral("n=%1 (~%2)").arg(n).arg(humanBytes(bytes));
        else
            runnable.push_back(n);
    }
    if (runnable.empty()) {
        m_status = QStringLiteral("Too large for the %1 family: %2 would exceed the %3 memory budget. "
                                  "Reduce N or choose a sparser family.")
                       .arg(family, skipped.join(QStringLiteral(", ")), humanBytes(budget));
        emit statusChanged();
        return;
    }
    sizes = std::move(runnable);
    const QString skippedNote = skipped.isEmpty()
        ? QString()
        : QStringLiteral("  (skipped %1: over the %2 memory budget)")
              .arg(skipped.join(QStringLiteral(", ")), humanBytes(budget));

    m_cancel = false;
    // A fresh sweep replaces the previous results (so the chart shows one clean set
    // of series rather than accumulating duplicate (algorithm, N) points).
    if (!m_results.isEmpty()) {
        m_results.clear();
        m_model.resetRows();
        emit resultsChanged();
    }

    m_running = true;
    emit runningChanged();
    m_progress = 0.0;
    emit progressChanged();

    const int total = static_cast<int>(algos.size()) * static_cast<int>(sizes.size());

    // Reap the previous sweep's thread (it has finished — m_running gated reentry —
    // but may not be joined yet) before starting a new one.
    if (m_worker.joinable()) m_worker.join();

    m_worker = std::thread([this, algos, family, sizes, directed, weighted, avgDegree, reps, warmup, seed, countOps, total, skippedNote, physTotal, physAvail]() {
        int done = 0;
        for (int n : sizes) {
            if (m_cancel.load()) break;

            // Build the graph ONCE per size and reuse it across every algorithm (the
            // generator is deterministic and directedness is uniform) — far cheaper
            // than regenerating it per algorithm, which matters for large/dense N.
            QMetaObject::invokeMethod(this, [this, n]() {
                m_status = QStringLiteral("Generating graph n=%1…").arg(n);
                emit statusChanged();
            }, Qt::QueuedConnection);

            int nUsed = 0, mUsed = 0;
            const ga::graph<double> g = buildGraph(family, n, directed, weighted, avgDegree, seed, nUsed, mUsed);
            // Source in the largest connected component, so a single-source traversal
            // measures a representative portion when the graph is disconnected.
            const ga::vertex src = pickSource(g);

            // Graph adjacency footprint (exact, from the realized graph) — depends on
            // the graph only, so compute it once and reuse for every algorithm's row.
            std::size_t entries = 0;
            for (std::size_t v = 0; v < g.order(); ++v) entries += g.degree(v);
            const double graphBytes =
                static_cast<double>(entries) * static_cast<double>(sizeof(ga::edge<double>)) +
                static_cast<double>(g.order()) * static_cast<double>(sizeof(std::vector<ga::edge<double>>));

            for (const QString& algo : algos) {
                if (m_cancel.load()) break;

                const QString st = QStringLiteral("Running %1 on n=%2…").arg(algo).arg(n);
                QMetaObject::invokeMethod(this, [this, st]() {
                    m_status = st;
                    emit statusChanged();
                }, Qt::QueuedConnection);

                // CPU consumption, measured around the whole timed window (no extra
                // runs). cpuPct = CPU time / wall time; cpuMs = average CPU time per
                // run. NB: GetThreadTimes has ~10–16 ms granularity, so cpuMs can
                // quantise or read 0 for sub-millisecond algorithms; cpuPct still
                // reads true where it matters (a swapping run shows wall ≫ cpu).
                ga::bench::result r{};
                double cpuMs = -1.0, cpuPct = -1.0;
                if (g.order() > 0) {
                    const quint64 cpu0 = threadCpuTimeNs();
                    const auto wall0 = std::chrono::steady_clock::now();
                    r = ga::bench::time_it([&]() { runAlgo(algo, g, src); }, reps, warmup);
                    const auto wall1 = std::chrono::steady_clock::now();
                    const quint64 cpu1 = threadCpuTimeNs();
                    const quint64 cpuNs = cpu1 >= cpu0 ? cpu1 - cpu0 : 0;
                    const double wallNs =
                        std::chrono::duration<double, std::nano>(wall1 - wall0).count();
                    const int iters = warmup + reps;
                    if (iters > 0) cpuMs = (static_cast<double>(cpuNs) / 1.0e6) / iters;
                    cpuPct = wallNs > 0 ? static_cast<double>(cpuNs) / wallNs * 100.0 : -1.0;
                }

                qulonglong ops = 0;
                if (countOps && g.order() > 0) {
                    ga::bench::counters c;
                    runAlgo(algo, g, src, ga::bench::count_into(c));
                    ops = static_cast<qulonglong>(c.total);
                }

                // Peak heap bytes: one dedicated untimed, tracer-free run with the
                // allocation tracker on (kept separate so it skews neither the
                // timings nor the op counts).
                qulonglong peakBytes = 0;
                if (g.order() > 0) {
                    ga::bench::mem::start();
                    runAlgo(algo, g, src);
                    ga::bench::mem::stop();
                    peakBytes = static_cast<qulonglong>(ga::bench::mem::peak_bytes());
                }

                QVariantMap row;
                row[QStringLiteral("algorithm")] = algo;
                row[QStringLiteral("family")] = family;
                row[QStringLiteral("n")] = nUsed;
                row[QStringLiteral("m")] = mUsed;
                row[QStringLiteral("reps")] = static_cast<int>(r.runs);
                row[QStringLiteral("minMs")] = r.min_ms;
                row[QStringLiteral("medianMs")] = r.median_ms;
                row[QStringLiteral("meanMs")] = r.mean_ms;
                row[QStringLiteral("stddevMs")] = r.stddev_ms;
                row[QStringLiteral("ops")] = ops;
                row[QStringLiteral("memBytes")] = peakBytes;

                // Whole-cell resident footprint ≈ the graph's adjacency (precomputed
                // above, same for every algorithm) plus this algorithm's peak working
                // set. Expressed as a share of total RAM for display, and flagged when
                // it exceeds most of the *free* RAM — those runs likely paged to disk,
                // so their timings are not trustworthy.
                const double footprint = graphBytes + static_cast<double>(peakBytes);
                row[QStringLiteral("footBytes")] = footprint;
                row[QStringLiteral("memPct")] =
                    physTotal > 0 ? footprint / static_cast<double>(physTotal) : -1.0;
                row[QStringLiteral("swapRisk")] =
                    physAvail > 0 && footprint > kSwapWarnFraction * static_cast<double>(physAvail);
                row[QStringLiteral("cpuMs")] = cpuMs;
                row[QStringLiteral("cpuPct")] = cpuPct;

                ++done;
                const double prog = total > 0 ? static_cast<double>(done) / total : 1.0;
                QMetaObject::invokeMethod(this, [this, row, prog]() {
                    m_model.appendRow(row);       // table: incremental, no rebuild
                    m_results.push_back(row);     // chart / CSV: full list
                    // Chart update is coalesced (armed here, flushed by m_flush).
                    m_resultsDirty = true;
                    if (!m_flush.isActive()) m_flush.start();
                    m_progress = prog;
                    emit progressChanged();
                }, Qt::QueuedConnection);
            }
        }

        QMetaObject::invokeMethod(this, [this, skippedNote]() {
            m_running = false;
            emit runningChanged();
            m_status = (m_cancel.load() ? QStringLiteral("Cancelled") : QStringLiteral("Done")) + skippedNote;
            emit statusChanged();
            m_progress = 1.0;
            emit progressChanged();
            // Final flush so the chart shows the complete set immediately.
            m_flush.stop();
            m_resultsDirty = false;
            emit resultsChanged();
        }, Qt::QueuedConnection);
    });
}

void AnalyzerController::cancel() {
    if (m_running) {
        m_cancel = true;
        m_status = QStringLiteral("Cancelling…");
        emit statusChanged();
    }
}

void AnalyzerController::clearResults() {
    if (m_results.isEmpty()) return;
    m_results.clear();
    m_model.resetRows();
    emit resultsChanged();
}

bool AnalyzerController::saveTextFile(const QUrl& url, const QString& text) const {
    const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) return false;
    QTextStream(&f) << text;
    return true;
}

bool AnalyzerController::exportCsv(const QUrl& url) const {
    const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) return false;
    QTextStream out(&f);
    out << "algorithm,family,n,m,reps,min_ms,median_ms,mean_ms,stddev_ms,ops,peak_bytes,"
           "ram_bytes,ram_pct,swap_risk,cpu_pct,cpu_ms\n";
    for (const QVariant& v : m_results) {
        const QVariantMap r = v.toMap();
        // ram_pct: footprint as a percentage of installed RAM (blank when RAM is
        // unknown, i.e. memPct < 0). swap_risk: 1 if the run likely paged to disk.
        // cpu_pct / cpu_ms: blank when the CPU-time query was unavailable (< 0).
        const double memPct = r.value(QStringLiteral("memPct"), -1.0).toDouble();
        const QString ramPct = memPct < 0 ? QString()
                                           : QString::number(memPct * 100.0, 'f', 1);
        const double cpuPct = r.value(QStringLiteral("cpuPct"), -1.0).toDouble();
        const double cpuMs = r.value(QStringLiteral("cpuMs"), -1.0).toDouble();
        out << r.value(QStringLiteral("algorithm")).toString() << ','
            << r.value(QStringLiteral("family")).toString() << ','
            << r.value(QStringLiteral("n")).toInt() << ','
            << r.value(QStringLiteral("m")).toInt() << ','
            << r.value(QStringLiteral("reps")).toInt() << ','
            << QString::number(r.value(QStringLiteral("minMs")).toDouble(), 'g', 6) << ','
            << QString::number(r.value(QStringLiteral("medianMs")).toDouble(), 'g', 6) << ','
            << QString::number(r.value(QStringLiteral("meanMs")).toDouble(), 'g', 6) << ','
            << QString::number(r.value(QStringLiteral("stddevMs")).toDouble(), 'g', 6) << ','
            << r.value(QStringLiteral("ops")).toULongLong() << ','
            << r.value(QStringLiteral("memBytes")).toULongLong() << ','
            << QString::number(r.value(QStringLiteral("footBytes")).toDouble(), 'f', 0) << ','
            << ramPct << ','
            << (r.value(QStringLiteral("swapRisk")).toBool() ? 1 : 0) << ','
            << (cpuPct < 0 ? QString() : QString::number(cpuPct, 'f', 1)) << ','
            << (cpuMs < 0 ? QString() : QString::number(cpuMs, 'g', 6)) << '\n';
    }
    return true;
}

}  // namespace ga::studio
