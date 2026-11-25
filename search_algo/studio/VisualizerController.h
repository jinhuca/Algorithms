#pragma once

#include <QAbstractListModel>
#include <QHash>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVector>
#include <QtQmlIntegration>

#include <vector>

#include <se/seq/trace.hpp>

// Per-bar model backing the Visualizer canvas: one row per array element, carrying its
// value (bar height) and its playback state (idle / in-window / probe / eliminated /
// found). The controller drives it as it replays a recorded search trace; QML binds a
// Repeater to it so only the changed bars repaint. Unlike the sort studio the values
// never change (a search only reads), so only the per-bar state moves.
namespace se::studio {

class BarModel : public QAbstractListModel {
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(double maxValue READ maxValue NOTIFY maxValueChanged)
public:
    // Kept in sync with the QML `BarState` enum in the view and Theme.barColor().
    enum State { Idle = 0, Window, Probe, Eliminated, Found };
    enum Roles { ValueRole = Qt::UserRole + 1, StateRole };
    using QAbstractListModel::QAbstractListModel;

    int rowCount(const QModelIndex& parent = {}) const override {
        return parent.isValid() ? 0 : static_cast<int>(m_values.size());
    }
    int count() const { return static_cast<int>(m_values.size()); }
    double maxValue() const { return m_max; }

    QVariant data(const QModelIndex& index, int role) const override {
        const int r = index.row();
        if (r < 0 || r >= m_values.size()) return {};
        if (role == ValueRole) return m_values[r];
        if (role == StateRole) return m_states[r];
        return {};
    }
    QHash<int, QByteArray> roleNames() const override {
        return { {ValueRole, "value"}, {StateRole, "barState"} };
    }

    void resetData(const QVector<double>& values) {
        beginResetModel();
        m_values = values;
        m_states.assign(values.size(), Idle);
        recomputeMax();
        endResetModel();
        emit countChanged();
        emit maxValueChanged();
    }
    // Push updated per-bar states for the same array (one coalesced change).
    void updateStates(const QVector<int>& states) {
        if (states.size() != m_states.size()) return;
        m_states = states;
        if (m_values.isEmpty()) return;
        emit dataChanged(index(0), index(m_values.size() - 1), {StateRole});
    }

signals:
    void countChanged();
    void maxValueChanged();

private:
    void recomputeMax() {
        m_max = 1.0;
        for (double v : m_values) if (v > m_max) m_max = v;
    }
    QVector<double> m_values;
    QVector<int> m_states;
    double m_max = 1.0;
};

// QML-facing controller for the Search Visualizer. Generates a sorted array (via
// se::gen), picks a target, records the chosen search's trace (a std::vector<se::step>)
// by running the real se::core algorithm with a recording tracer, and replays that
// timeline — forward, backward, seek — mapping each step to per-bar visual state and a
// sliding lo/hi window. Running = replaying a precomputed trace, so stepping backward
// is trivial.
class VisualizerController : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)   // full Major.Minor.Patch.Build (version.h)
    Q_PROPERTY(QObject* bars READ bars CONSTANT)
    Q_PROPERTY(QStringList categories READ categories CONSTANT)
    Q_PROPERTY(QStringList distributions READ distributions CONSTANT)
    Q_PROPERTY(QStringList targetModes READ targetModes CONSTANT)
    Q_PROPERTY(QString algorithm READ algorithm WRITE setAlgorithm NOTIFY algorithmChanged)
    Q_PROPERTY(QString distribution READ distribution WRITE setDistribution NOTIFY distributionChanged)
    Q_PROPERTY(QString targetMode READ targetMode WRITE setTargetMode NOTIFY targetModeChanged)
    Q_PROPERTY(double target READ target NOTIFY targetChanged)
    Q_PROPERTY(int size READ size NOTIFY arrayChanged)
    Q_PROPERTY(int cursor READ cursor NOTIFY cursorChanged)
    Q_PROPERTY(int stepCount READ stepCount NOTIFY timelineChanged)
    Q_PROPERTY(bool atEnd READ atEnd NOTIFY cursorChanged)
    Q_PROPERTY(int probes READ probes NOTIFY cursorChanged)
    Q_PROPERTY(int remaining READ remaining NOTIFY cursorChanged)
    Q_PROPERTY(int foundIndex READ foundIndex NOTIFY cursorChanged)
    Q_PROPERTY(bool finished READ finished NOTIFY cursorChanged)
    Q_PROPERTY(QString result READ result NOTIFY cursorChanged)
    Q_PROPERTY(QString note READ note NOTIFY cursorChanged)
    Q_PROPERTY(QString stepKind READ stepKind NOTIFY cursorChanged)
    Q_PROPERTY(int stepLine READ stepLine NOTIFY cursorChanged)

public:
    explicit VisualizerController(QObject* parent = nullptr);

    QString appVersion() const;   // SE_APP_VERSION from the generated version.h

    QObject* bars() { return &m_bars; }
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
    Q_INVOKABLE QString categoryOf(const QString& algo) const {
        for (const QString& c : categories())
            if (algorithmsIn(c).contains(algo)) return c;
        return categories().constFirst();
    }
    QStringList distributions() const {
        return {QStringLiteral("Uniform"), QStringLiteral("Random"),
                QStringLiteral("Few unique"), QStringLiteral("Gaussian")};
    }
    QStringList targetModes() const {
        return {QStringLiteral("Present: first"), QStringLiteral("Present: middle"),
                QStringLiteral("Present: last"), QStringLiteral("Absent")};
    }

    QString algorithm() const { return m_algorithm; }
    void setAlgorithm(const QString& a);
    QString distribution() const { return m_distribution; }
    void setDistribution(const QString& d);
    QString targetMode() const { return m_targetMode; }
    void setTargetMode(const QString& m);
    double target() const { return m_target; }

    int size() const { return static_cast<int>(m_array.size()); }
    int cursor() const { return m_cursor; }
    int stepCount() const { return static_cast<int>(m_steps.size()); }
    bool atEnd() const { return m_cursor >= stepCount() - 1; }
    int probes() const { return m_probes; }
    int remaining() const { return m_remaining; }
    int foundIndex() const { return m_foundIndex; }
    bool finished() const { return atEnd() && stepCount() > 0; }
    QString result() const { return m_result; }
    QString note() const { return m_note; }
    QString stepKind() const { return m_stepKind; }
    int stepLine() const { return m_stepLine; }

    // Build a fresh sorted array of `n` elements with the current distribution + seed,
    // recompute the target, record the trace, and rewind to the start.
    Q_INVOKABLE void generate(int n, int seed = 0);
    // Use a custom numeric target (overrides the target mode) and re-record.
    Q_INVOKABLE void setCustomTarget(double value);
    // Re-record the trace for the current array + target + algorithm, rewind to start.
    Q_INVOKABLE void rebuild();

    Q_INVOKABLE void stepForward();
    Q_INVOKABLE void stepBack();
    Q_INVOKABLE void seek(int target);
    Q_INVOKABLE void toStart() { seek(-1); }
    Q_INVOKABLE void toEnd() { seek(stepCount() - 1); }

signals:
    void algorithmChanged();
    void distributionChanged();
    void targetModeChanged();
    void targetChanged();
    void arrayChanged();
    void cursorChanged();
    void timelineChanged();

private:
    std::vector<double> buildArray(int n, quint64 seed) const;
    void recomputeTarget();     // from m_targetMode (unless a custom target is set)
    void record();              // run the search -> m_steps
    void render();              // compute per-bar states + stats for the current cursor

    BarModel m_bars;
    QString m_algorithm = QStringLiteral("Binary");
    QString m_distribution = QStringLiteral("Uniform");
    QString m_targetMode = QStringLiteral("Present: middle");
    quint64 m_seed = 1;

    std::vector<double> m_array;      // the (sorted) array being searched
    double m_target = 0.0;
    bool m_customTarget = false;
    std::vector<se::step> m_steps;    // recorded timeline
    int m_cursor = -1;                // -1 = before the first step
    int m_probes = 0;
    int m_remaining = 0;
    int m_foundIndex = -1;
    QString m_result;
    QString m_note;
    QString m_stepKind;
    int m_stepLine = -1;
};

}  // namespace se::studio
