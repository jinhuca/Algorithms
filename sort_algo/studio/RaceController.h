#pragma once

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>
#include <QVector>
#include <QtQmlIntegration>

#include <vector>

#include <sa/seq/trace.hpp>

#include "VisualizerController.h"   // reuse BarModel

namespace sa::studio {

// One racing lane: an algorithm's recorded trace replayed on its own copy of the
// shared array, into its own BarModel. Lanes all step forward in lockstep (one trace
// step per tick); a lane with fewer steps finishes sooner, so the race is by
// operation count. Exposes name / bars / progress / done / rank to QML.
class RaceLane : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString name READ name CONSTANT)
    Q_PROPERTY(QObject* bars READ bars CONSTANT)
    Q_PROPERTY(double progress READ progress NOTIFY changed)   // 0..1
    Q_PROPERTY(int ops READ ops CONSTANT)                      // total trace steps
    Q_PROPERTY(bool done READ done NOTIFY changed)
    Q_PROPERTY(int rank READ rank NOTIFY changed)              // finishing place (1 = first), 0 until done

public:
    RaceLane(QString name, std::vector<double> initial, std::vector<sa::step> steps,
             QObject* parent = nullptr);

    QString name() const { return m_name; }
    QObject* bars() { return &m_bars; }
    double progress() const { return m_steps.empty() ? 1.0 : double(m_cursor + 1) / double(m_steps.size()); }
    int ops() const { return static_cast<int>(m_steps.size()); }
    bool done() const { return m_done; }
    int rank() const { return m_rank; }

    void reset();                 // rewind to the start, render the initial array
    bool advance();               // one step; returns true iff it just finished
    void setRank(int r) { m_rank = r; emit changed(); }
    double maxValue() const { return m_max; }

signals:
    void changed();

private:
    void render();

    QString m_name;
    BarModel m_bars;
    std::vector<double> m_initial, m_current;
    std::vector<sa::step> m_steps;
    QVector<int> m_sorted;        // 1 where a position is finalised
    double m_max = 1.0;
    int m_cursor = -1;
    bool m_done = false;
    int m_rank = 0;
};

// QML-facing controller for the Race workspace: builds one shared array and records
// each selected algorithm's trace into a lane, then steps all lanes together.
class RaceController : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QStringList algorithms READ algorithms CONSTANT)
    Q_PROPERTY(QStringList distributions READ distributions CONSTANT)
    Q_PROPERTY(QList<QObject*> lanes READ lanes NOTIFY lanesChanged)
    Q_PROPERTY(bool finished READ finished NOTIFY finishedChanged)
    Q_PROPERTY(int size READ size NOTIFY lanesChanged)

public:
    explicit RaceController(QObject* parent = nullptr);

    QStringList algorithms() const {
        return {QStringLiteral("Bubble"), QStringLiteral("Selection"), QStringLiteral("Insertion"),
                QStringLiteral("Cocktail"), QStringLiteral("Cycle"), QStringLiteral("Merge"),
                QStringLiteral("Quick"), QStringLiteral("Heap"), QStringLiteral("Shell"),
                QStringLiteral("Radix"), QStringLiteral("Counting"), QStringLiteral("Bucket")};
    }
    QStringList distributions() const {
        return {QStringLiteral("Random"), QStringLiteral("Sorted"), QStringLiteral("Reversed"),
                QStringLiteral("Nearly sorted"), QStringLiteral("Few unique"), QStringLiteral("Gaussian")};
    }
    QList<QObject*> lanes() const { return m_lanes; }
    bool finished() const { return !m_lanes.isEmpty() && m_finishedCount == m_lanes.size(); }
    int size() const { return m_size; }

    // Build a shared array (distribution + seed) and record each algorithm's trace.
    Q_INVOKABLE void start(const QStringList& algos, int n, const QString& distribution, int seed);
    // Advance every unfinished lane by one step (assigns ranks as lanes finish).
    Q_INVOKABLE void stepAll();
    // Rewind all lanes to the start (no re-recording).
    Q_INVOKABLE void resetAll();

signals:
    void lanesChanged();
    void finishedChanged();

private:
    void clearLanes();

    QList<QObject*> m_lanes;
    int m_finishedCount = 0;
    int m_size = 0;
};

}  // namespace sa::studio
