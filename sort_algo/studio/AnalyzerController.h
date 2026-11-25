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
#include <vector>

namespace sa::studio {

// Incremental model backing the Analyzer's results table: rows are appended one at a
// time so the ListView only creates the new row's delegates instead of rebuilding
// every row on each streamed result. Exposes the whole row map plus a precomputed
// size-group boundary flag. (Mirrors graph_algo's AnalyzerResultsModel.)
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
        if (role == GroupStartRole)
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
// generates arrays with sa::gen, runs the sa::core sorts WITHOUT a tracer (pure
// computation) timed with sa::bench on a worker thread, plus a separate untimed
// counted run for comparison/swap totals, and streams the rows for a QML table +
// scaling chart. Sibling to VisualizerController.
class AnalyzerController : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)      // 0..1
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QVariantList results READ results NOTIFY resultsChanged)   // feeds the chart / CSV
    Q_PROPERTY(QObject* resultsModel READ resultsModel CONSTANT)          // incremental model for the table
    Q_PROPERTY(QStringList algorithms READ algorithms CONSTANT)
    Q_PROPERTY(QStringList categories READ categories CONSTANT)
    Q_PROPERTY(QStringList distributions READ distributions CONSTANT)

public:
    explicit AnalyzerController(QObject* parent = nullptr);
    ~AnalyzerController() override;

    bool running() const { return m_running; }
    double progress() const { return m_progress; }
    QString status() const { return m_status; }
    QVariantList results() const { return m_results; }
    QObject* resultsModel() { return &m_model; }
    QStringList algorithms() const { return algorithmsIn({}); }
    QStringList categories() const {
        return {QStringLiteral("O(n²)"), QStringLiteral("O(n log n)"), QStringLiteral("Advanced")};
    }
    // Algorithms in a category; an empty/unknown category returns the full list.
    Q_INVOKABLE QStringList algorithmsIn(const QString& category) const {
        static const QStringList n2 = {QStringLiteral("Bubble"), QStringLiteral("Selection"),
                                       QStringLiteral("Insertion"), QStringLiteral("Cocktail"),
                                       QStringLiteral("Cycle")};
        static const QStringList nlogn = {QStringLiteral("Merge"), QStringLiteral("Quick"),
                                          QStringLiteral("Heap")};
        static const QStringList advanced = {QStringLiteral("Shell"), QStringLiteral("Radix"),
                                             QStringLiteral("Counting"), QStringLiteral("Bucket")};
        if (category == QStringLiteral("O(n²)")) return n2;
        if (category == QStringLiteral("O(n log n)")) return nlogn;
        if (category == QStringLiteral("Advanced")) return advanced;
        return n2 + nlogn + advanced;
    }
    QStringList distributions() const {
        return {QStringLiteral("Random"), QStringLiteral("Sorted"),
                QStringLiteral("Reversed"), QStringLiteral("Nearly sorted"),
                QStringLiteral("Few unique"), QStringLiteral("Gaussian")};
    }

    // Start a benchmark sweep. `config` keys:
    //   algorithms   : [String]  subset of algorithms()
    //   distribution : String    one of distributions() (default "Random")
    //   sizes        : [int]     element counts N to sweep
    //   reps         : int       timed repetitions per cell (default 5)
    //   warmup       : int       untimed warmup runs per cell (default 1)
    //   seed         : int       RNG seed for reproducibility (default 1)
    //   countOps     : bool      also do one untimed counted run for op totals (default true)
    // Runs on a worker thread; results stream in and progress/status update.
    Q_INVOKABLE void run(const QVariantMap& config);
    Q_INVOKABLE void cancel();
    Q_INVOKABLE void clearResults();
    Q_INVOKABLE bool exportCsv(const QUrl& url) const;
    Q_INVOKABLE QString complexityOf(const QString& algo) const;

signals:
    void runningChanged();
    void progressChanged();
    void statusChanged();
    void resultsChanged();

private:
    static std::vector<double> buildArray(const QString& distribution, int n, quint64 seed);
    // Sort a copy of `data` with the named algorithm; `countInto` (optional) receives
    // a counting tracer for a separate untimed run.
    static void runAlgo(const QString& algo, std::vector<double> data);
    static void countAlgo(const QString& algo, std::vector<double> data,
                          std::size_t& compares, std::size_t& swaps, std::size_t& writes);
    // This thread's consumed CPU time (user+kernel) in ns; 0 if unavailable.
    static quint64 threadCpuTimeNs();

    // Hard cap on N per cell: the O(n²) simple sorts get very slow beyond this, so a
    // stray large size is skipped rather than freezing the sweep. (Sorting is O(n)
    // memory, so unlike the graph studio there's no memory budget to track.)
    static constexpr int kMaxN = 200000;

    bool m_running = false;
    double m_progress = 0.0;
    QString m_status;
    QVariantList m_results;
    AnalyzerResultsModel m_model;
    std::atomic<bool> m_cancel{false};
    std::thread m_worker;

    QTimer m_flush;
    bool m_resultsDirty = false;
};

}  // namespace sa::studio
