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

// Incremental model backing the Analyzer's results table: rows are appended one at a
// time so the ListView only creates the new row's delegates. Exposes the row map plus
// a size-group boundary flag.
namespace se::studio {

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
// generates sorted arrays with se::gen, counts probes with a se::bench tracer
// (deterministic), and times a batch of searches without a tracer (pure computation)
// with se::bench on a worker thread, streaming rows for a QML table + scaling chart.
class AnalyzerController : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(double progress READ progress NOTIFY progressChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)
    Q_PROPERTY(QVariantList results READ results NOTIFY resultsChanged)
    Q_PROPERTY(QObject* resultsModel READ resultsModel CONSTANT)
    Q_PROPERTY(QStringList algorithms READ algorithms CONSTANT)
    Q_PROPERTY(QStringList categories READ categories CONSTANT)
    Q_PROPERTY(QStringList distributions READ distributions CONSTANT)
    Q_PROPERTY(QStringList targetModes READ targetModes CONSTANT)

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
        return {QStringLiteral("Sequential"), QStringLiteral("Sorted")};
    }
    Q_INVOKABLE QStringList algorithmsIn(const QString& category) const {
        static const QStringList sequential = {QStringLiteral("Linear"), QStringLiteral("Sentinel")};
        static const QStringList sorted = {QStringLiteral("Binary"), QStringLiteral("Ternary"),
                                           QStringLiteral("Jump"), QStringLiteral("Exponential"),
                                           QStringLiteral("Interpolation"), QStringLiteral("Fibonacci")};
        if (category == QStringLiteral("Sequential")) return sequential;
        if (category == QStringLiteral("Sorted")) return sorted;
        return sequential + sorted;
    }
    QStringList distributions() const {
        return {QStringLiteral("Uniform"), QStringLiteral("Random"),
                QStringLiteral("Few unique"), QStringLiteral("Gaussian")};
    }
    QStringList targetModes() const {
        return {QStringLiteral("Present: middle"), QStringLiteral("Present: random"),
                QStringLiteral("Absent")};
    }

    // Start a benchmark sweep. `config` keys: algorithms [String], distribution String,
    // target String (one of targetModes), sizes [int], reps int, seed int. Runs on a
    // worker thread; rows stream in with progress/status updates.
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
    // Run the named search once on `data` for `target`; returns the found index or nil.
    static std::size_t runSearch(const QString& algo, const std::vector<double>& data, double target);
    // Count probes for one representative search (separate untimed run).
    static std::size_t countProbes(const QString& algo, const std::vector<double>& data, double target);

    static constexpr int kMaxN = 300000;

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

}  // namespace se::studio
