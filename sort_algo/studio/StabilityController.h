#pragma once

#include <QObject>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <QtQmlIntegration>

// QML-facing controller for the Stability workspace. A sort is *stable* if elements
// with equal keys keep their original relative order. We demonstrate this concretely:
// build n elements each carrying a key (one of a few distinct levels, so there are
// many ties) and its original position; sort a copy with the chosen algorithm using a
// KEY-ONLY comparator; then check whether, within each equal-key run of the result,
// the original positions stayed in ascending order. The QML colours each bar by its
// original position (a left→right rainbow on input), so stability is visible: stable
// sorts keep the rainbow locally ascending within each key group; unstable ones
// scramble it. Reuses the real sa::core sorts (generic over the element type) — no
// core changes; only the comparison sorts are offered (radix is non-comparison).
class StabilityController : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QStringList algorithms READ algorithms CONSTANT)
    Q_PROPERTY(QString algorithm READ algorithm WRITE setAlgorithm NOTIFY algorithmChanged)
    Q_PROPERTY(QVariantList before READ before NOTIFY resultChanged)  // [{key, origin}] input order
    Q_PROPERTY(QVariantList after READ after NOTIFY resultChanged)    // [{key, origin}] sorted order
    Q_PROPERTY(int count READ count NOTIFY resultChanged)
    Q_PROPERTY(int keyLevels READ keyLevels NOTIFY resultChanged)     // number of distinct keys
    Q_PROPERTY(bool stable READ stable NOTIFY resultChanged)          // verdict for this run
    Q_PROPERTY(bool hasResult READ hasResult NOTIFY resultChanged)

public:
    explicit StabilityController(QObject* parent = nullptr);

    QStringList algorithms() const {
        return {QStringLiteral("Bubble"), QStringLiteral("Selection"), QStringLiteral("Insertion"),
                QStringLiteral("Cocktail"), QStringLiteral("Cycle"), QStringLiteral("Merge"),
                QStringLiteral("Quick"), QStringLiteral("Heap"), QStringLiteral("Shell")};
    }
    QString algorithm() const { return m_algorithm; }
    void setAlgorithm(const QString& a);

    QVariantList before() const { return m_before; }
    QVariantList after() const { return m_after; }
    int count() const { return m_count; }
    int keyLevels() const { return m_keyLevels; }
    bool stable() const { return m_stable; }
    bool hasResult() const { return m_count > 0; }

    // Build n elements across `levels` distinct keys (seeded), sort a copy with the
    // current algorithm (key-only comparator), and recompute before/after + verdict.
    Q_INVOKABLE void run(int n, int levels, int seed);

signals:
    void algorithmChanged();
    void resultChanged();

private:
    void recompute();

    QString m_algorithm = QStringLiteral("Insertion");
    int m_n = 32, m_levels = 4, m_seed = 1;
    QVariantList m_before, m_after;
    int m_count = 0, m_keyLevels = 0;
    bool m_stable = true;
};
