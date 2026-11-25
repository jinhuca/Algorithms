#pragma once

#include <QAbstractListModel>
#include <QHash>
#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include <QtQmlIntegration>

#include <atomic>
#include <thread>

#include <ga/graph/graph.hpp>
#include <ga/graph/trace.hpp>

// Incremental model backing the Analyzer's results table: rows are appended one at a
// time (begin/endInsertRows) so the ListView only creates the new row's delegates
// instead of rebuilding every row on each streamed result. Exposes the whole row map
// (RowData) and a precomputed size-group boundary flag (GroupStart, O(1)).
namespace ga::studio {

class AnalyzerResultsModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
public:
    enum Roles { RowDataRole = Qt::UserRole + 1, GroupStartRole };
    using QAbstractListModel::QAbstractListModel;

    int rowCount(const QModelIndex& parent = {}) const override {
        return parent.isValid() ? 0 : static_cast<int>(m_rows.size());
    }
    int count() const { return static_cast<int>(m_rows.size()); }

    QVariant data(const QModelIndex& index, int role) const override {
        const int r = index.row();
        if (r < 0 || r >= m_rows.size()) return {};
        if (role == RowDataRole) return m_rows[r];
        if (role == GroupStartRole)                    // true on the first row of a new N block
            return r > 0 && m_rows[r - 1].value(QStringLiteral("n")) != m_rows[r].value(QStringLiteral("n"));
        return {};
    }
    QHash<int, QByteArray> roleNames() const override {
        return { {RowDataRole, "rowData"}, {GroupStartRole, "groupStart"} };
    }

    void appendRow(const QVariantMap& row) {
        beginInsertRows({}, static_cast<int>(m_rows.size()), static_cast<int>(m_rows.size()));
        m_rows.push_back(row);
        endInsertRows();
        emit countChanged();
    }
    void resetRows() {
        if (m_rows.isEmpty()) return;
        beginResetModel();
        m_rows.clear();
        endResetModel();
        emit countChanged();
    }

signals:
    void countChanged();

private:
    QList<QVariantMap> m_rows;
};

// QML-facing controller for the headless benchmark workspace (the Analyzer). It
// generates synthetic graphs with ga::gen, runs the ga::core algorithms WITHOUT
// a tracer (pure computation), times them with ga::bench on a worker thread, and
// publishes the rows for a QML table. No rendering — but the graph itself still
// lives in memory, so a cell is SKIPPED when its adjacency would exceed a memory
// budget (notably the Θ(n²) "complete" family at large n, which would otherwise
// try to allocate many GB and crash the process). Sibling to VisualizerController;
// see ../AddAnalyser.md.
class AnalyzerController : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)   // 0..1
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QVariantList results READ results NOTIFY resultsChanged)  // [{algorithm,family,n,m,...}] — feeds the chart / CSV
    Q_PROPERTY(QObject* resultsModel READ resultsModel CONSTANT)         // incremental model — feeds the table
    Q_PROPERTY(QStringList algorithms READ algorithms CONSTANT)
    Q_PROPERTY(QStringList families READ families CONSTANT)

public:
    explicit AnalyzerController(QObject* parent = nullptr);
    ~AnalyzerController() override;

    bool running() const { return m_running; }
    double progress() const { return m_progress; }
    QString status() const { return m_status; }
    QVariantList results() const { return m_results; }
    QObject* resultsModel() { return &m_model; }
    QStringList algorithms() const {
        return {QStringLiteral("BFS"), QStringLiteral("DFS"),
                QStringLiteral("Dijkstra"), QStringLiteral("Bellman-Ford"),
                QStringLiteral("Kruskal"), QStringLiteral("Prim")};
    }
    QStringList families() const {
        return {QStringLiteral("random"), QStringLiteral("grid"),
                QStringLiteral("scale-free"), QStringLiteral("complete")};
    }

    // Start a benchmark sweep. `config` keys (all optional except algorithms/sizes):
    //   algorithms : [String]   subset of algorithms()
    //   family     : String     one of families()  (default "random")
    //   sizes      : [int]       vertex counts N to sweep
    //   directed   : bool        (default false)
    //   weighted   : bool        random weights in [1,10] when true (default false)
    //   avgDegree  : int         target avg degree for random/scale-free (default 4)
    //   reps       : int         timed repetitions per cell (default 5)
    //   warmup     : int         untimed warmup runs per cell (default 1)
    //   seed       : int         RNG seed for reproducibility (default 1)
    //   countOps   : bool        also do one untimed counted run for op totals (default true)
    // Runs on a worker thread; results stream in and `progress`/`status` update.
    Q_INVOKABLE void run(const QVariantMap& config);
    Q_INVOKABLE void cancel();                    // request the running sweep to stop
    Q_INVOKABLE void clearResults();
    Q_INVOKABLE bool exportCsv(const QUrl& url) const;
    // Write arbitrary text to a file (used to save the Sizes list). Returns success.
    Q_INVOKABLE bool saveTextFile(const QUrl& url, const QString& text) const;

signals:
    void runningChanged();
    void progressChanged();
    void statusChanged();
    void resultsChanged();

private:
    // Build one graph for (family, n). Writes the realized order/size (grid rounds
    // n to a square; random clamps m) into nOut/mOut. Static: touches no members.
    static ga::graph<double> buildGraph(const QString& family, int n, bool directed,
                                        bool weighted, int avgDegree, quint64 seed,
                                        int& nOut, int& mOut);
    // Run one algorithm on g from src. With the default (ga::ignore) tracer it's a
    // pure timed computation; pass a counting tracer for a separate untimed run.
    static void runAlgo(const QString& algo, const ga::graph<double>& g,
                        ga::vertex src, const ga::tracer& tr = ga::ignore);

    // A source vertex in the graph's largest (weakly) connected component, so a
    // single-source traversal (BFS/DFS/Dijkstra/Prim) measures a representative
    // chunk rather than a tiny component when the generated graph is disconnected.
    static ga::vertex pickSource(const ga::graph<double>& g);

    // Upper-bound estimate of the heap bytes the graph's adjacency will occupy for
    // (family, n): the number of stored directed-edge entries × sizeof(edge). Used
    // to refuse a cell before buildGraph() attempts an allocation large enough to
    // crash the process. Depends only on the graph shape, not the algorithm.
    static double estimatedGraphBytes(const QString& family, int n, bool directed,
                                      int avgDegree);
    // Current thread's consumed CPU time (user + kernel) in nanoseconds, 0 when the
    // platform query is unavailable. Snapshotted around the timed run to derive CPU
    // utilisation % and per-run CPU time.
    static quint64 threadCpuTimeNs();

    // Physical RAM in bytes (total installed + currently available); both 0 when the
    // platform query is unavailable. Lets the per-cell budget and the swap-risk flag
    // track the actual machine instead of only an absolute ceiling.
    static void physicalMemory(quint64& total, quint64& avail);

    // Absolute per-cell ceiling; the effective budget is min(this, fraction of free
    // RAM). Larger cells are skipped rather than driving the machine into swap.
    static constexpr double kMaxGraphBytes = 2.0 * 1024 * 1024 * 1024;   // 2 GiB
    static constexpr double kRamBudgetFraction = 0.6;   // skip a cell over 60% of free RAM
    static constexpr double kSwapWarnFraction = 0.8;    // flag a run over 80% of free RAM

    bool m_running = false;              // GUI thread only
    double m_progress = 0.0;
    QString m_status;
    QVariantList m_results;              // full list for the chart / CSV
    AnalyzerResultsModel m_model;        // incremental model for the table
    std::atomic<bool> m_cancel{false};   // set on GUI thread, read on the worker
    std::thread m_worker;                // the sweep thread; joined before reuse/destroy

    // Coalesce resultsChanged (which now drives only the chart) to a few times a second,
    // so a burst of fast cells can't flood the GUI with chart re-reads/repaints.
    QTimer m_flush;                      // GUI thread
    bool m_resultsDirty = false;
};

}  // namespace ga::studio
