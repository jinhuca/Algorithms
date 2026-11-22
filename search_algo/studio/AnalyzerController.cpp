#include "AnalyzerController.h"

#include <QFile>
#include <QMetaObject>
#include <QTextStream>

#include <algorithm>

#include <se/bench/bench.hpp>
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

AnalyzerController::AnalyzerController(QObject* parent) : QObject(parent) {
    // Coalesce resultsChanged (which drives the chart) to a few times a second.
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
    if (dist == QStringLiteral("Random"))     return se::gen::random_sorted(sz, seed);
    if (dist == QStringLiteral("Few unique")) return se::gen::few_unique_sorted(sz, 5, seed);
    if (dist == QStringLiteral("Gaussian"))   return se::gen::gaussian_sorted(sz, seed);
    return se::gen::sorted(sz);
}

std::size_t AnalyzerController::runSearch(const QString& algo, const std::vector<double>& data,
                                          double target) {
    if (algo == QStringLiteral("Linear"))             return se::linear_search(data, target);
    if (algo == QStringLiteral("Sentinel"))           return se::sentinel_search(data, target);
    if (algo == QStringLiteral("Ternary"))            return se::ternary_search(data, target);
    if (algo == QStringLiteral("Jump"))               return se::jump_search(data, target);
    if (algo == QStringLiteral("Exponential"))        return se::exponential_search(data, target);
    if (algo == QStringLiteral("Interpolation"))      return se::interpolation_search(data, target);
    if (algo == QStringLiteral("Fibonacci"))          return se::fibonacci_search(data, target);
    return se::binary_search(data, target);
}

std::size_t AnalyzerController::countProbes(const QString& algo, const std::vector<double>& data,
                                            double target) {
    se::bench::counters c;
    auto tr = se::bench::count_into(c);
    if (algo == QStringLiteral("Linear"))             se::linear_search(data, target, se::less{}, tr);
    else if (algo == QStringLiteral("Sentinel"))      se::sentinel_search(data, target, se::less{}, tr);
    else if (algo == QStringLiteral("Ternary"))       se::ternary_search(data, target, se::less{}, tr);
    else if (algo == QStringLiteral("Jump"))          se::jump_search(data, target, se::less{}, tr);
    else if (algo == QStringLiteral("Exponential"))   se::exponential_search(data, target, se::less{}, tr);
    else if (algo == QStringLiteral("Interpolation")) se::interpolation_search(data, target, se::less{}, tr);
    else if (algo == QStringLiteral("Fibonacci"))     se::fibonacci_search(data, target, se::less{}, tr);
    else                                              se::binary_search(data, target, se::less{}, tr);
    return c.probe;
}

QString AnalyzerController::complexityOf(const QString& algo) const {
    if (algo == QStringLiteral("Linear"))        return QStringLiteral("O(n) · any order");
    if (algo == QStringLiteral("Sentinel"))      return QStringLiteral("O(n) · fewer checks");
    if (algo == QStringLiteral("Binary"))        return QStringLiteral("O(log n)");
    if (algo == QStringLiteral("Ternary"))       return QStringLiteral("O(log n) · ~2 cmp/step");
    if (algo == QStringLiteral("Jump"))          return QStringLiteral("O(√n)");
    if (algo == QStringLiteral("Exponential"))   return QStringLiteral("O(log i) · galloping");
    if (algo == QStringLiteral("Interpolation")) return QStringLiteral("O(log log n) avg · O(n) worst");
    if (algo == QStringLiteral("Fibonacci"))     return QStringLiteral("O(log n) · no division");
    return QStringLiteral("—");
}

void AnalyzerController::run(const QVariantMap& config) {
    if (m_running) return;
    if (m_worker.joinable()) m_worker.join();

    const QStringList algos = config.value(QStringLiteral("algorithms")).toStringList();
    const QString dist = config.value(QStringLiteral("distribution"), QStringLiteral("Uniform")).toString();
    const QString targetMode = config.value(QStringLiteral("target"), QStringLiteral("Present: middle")).toString();
    QList<int> sizes;
    for (const QVariant& v : config.value(QStringLiteral("sizes")).toList()) {
        const int n = v.toInt();
        if (n > 0 && n <= kMaxN) sizes.push_back(n);
    }
    const int reps = qMax(1, config.value(QStringLiteral("reps"), 5).toInt());
    const quint64 seed = static_cast<quint64>(config.value(QStringLiteral("seed"), 1).toInt());

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

    m_worker = std::thread([this, algos, dist, targetMode, sizes, reps, seed, totalCells] {
        int done = 0;
        for (int n : sizes) {
            if (m_cancel) break;
            std::vector<double> base = buildArray(dist, n, seed);

            // A batch of targets to search in the timed loop: present elements at varied
            // positions, or the single absent value. Searching varied positions keeps the
            // measurement honest (no single branch-predicted path).
            std::vector<double> targets;
            if (targetMode == QStringLiteral("Absent")) {
                targets.push_back(se::gen::missing_target(base));
            } else {
                for (int k = 0; k < 16; ++k)
                    targets.push_back(se::gen::present_target(base, k / 15.0));
            }
            // Representative target for the deterministic probe count.
            const double repTarget = (targetMode == QStringLiteral("Absent"))
                ? se::gen::missing_target(base)
                : (targetMode == QStringLiteral("Present: random")
                       ? se::gen::present_target(base, 0.37)
                       : se::gen::present_target(base, 0.5));

            // Inner loop count: keep total element-touches per timed iteration roughly
            // constant across N so ns/search is stable (linear touches ~n, binary ~log n).
            const std::size_t loop = static_cast<std::size_t>(
                std::max<long long>(1, std::min<long long>(200000, (1LL << 20) / std::max(1, n))));

            for (const QString& algo : algos) {
                if (m_cancel) break;

                const std::size_t probes = countProbes(algo, base, repTarget);

                const std::size_t T = targets.size();
                auto r = se::bench::time_it([&] {
                    std::size_t acc = 0;
                    for (std::size_t k = 0; k < loop; ++k)
                        acc += runSearch(algo, base, targets[k % T]);
                    se::bench::do_not_optimize(acc);
                }, reps, 1);
                const double nsPerSearch = loop > 0 ? r.median_ms * 1.0e6 / static_cast<double>(loop) : -1.0;

                QVariantMap row;
                row[QStringLiteral("algorithm")]  = algo;
                row[QStringLiteral("distribution")] = dist;
                row[QStringLiteral("target")]     = targetMode;
                row[QStringLiteral("n")]          = n;
                row[QStringLiteral("probes")]     = static_cast<double>(probes);
                row[QStringLiteral("nsPerSearch")]= nsPerSearch;
                row[QStringLiteral("medianMs")]   = r.median_ms;
                row[QStringLiteral("complexity")] = complexityOf(algo);

                ++done;
                const double prog = totalCells ? double(done) / double(totalCells) : 1.0;
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
            m_resultsDirty = true;
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
    out << "algorithm,distribution,target,n,probes,ns_per_search,median_ms,complexity\n";
    for (const QVariant& v : m_results) {
        const QVariantMap r = v.toMap();
        const double ns = r.value(QStringLiteral("nsPerSearch"), -1.0).toDouble();
        out << r.value(QStringLiteral("algorithm")).toString() << ','
            << r.value(QStringLiteral("distribution")).toString() << ','
            << r.value(QStringLiteral("target")).toString() << ','
            << r.value(QStringLiteral("n")).toInt() << ','
            << r.value(QStringLiteral("probes")).toDouble() << ','
            << (ns < 0 ? QString() : QString::number(ns, 'g', 6)) << ','
            << r.value(QStringLiteral("medianMs")).toDouble() << ','
            << '"' << r.value(QStringLiteral("complexity")).toString() << "\"\n";
    }
    f.close();
    return true;
}
