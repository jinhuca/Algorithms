// VisualizerController — serialization & file I/O. Part of the VisualizerController
// class (declared in VisualizerController.h); see also VisualizerController.cpp and
// VisualizerController_run.cpp.
#include "VisualizerController.h"

#include <QElapsedTimer>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QVariantMap>
#include <algorithm>
#include <cmath>
#include <limits>
#include <map>
#include <set>
#include <thread>
#include <unordered_set>

#include <ga/basic_algo/bfs.hpp>
#include <ga/basic_algo/dfs.hpp>
#include <ga/short_paths/bellman_ford.hpp>
#include <ga/short_paths/dijkstra.hpp>

namespace ga::studio {

QString VisualizerController::toJson() const {
    QJsonObject root;
    root[QStringLiteral("directed")] = m_directed;
    QJsonArray jn;
    for (const Node& n : m_nodes) {
        QJsonObject o;
        o[QStringLiteral("label")] = n.label;
        o[QStringLiteral("x")] = n.x;
        o[QStringLiteral("y")] = n.y;
        jn.append(o);
    }
    root[QStringLiteral("nodes")] = jn;
    QJsonArray je;
    for (const Edge& e : m_edges) {
        QJsonObject o;
        o[QStringLiteral("from")] = e.from;
        o[QStringLiteral("to")] = e.to;
        o[QStringLiteral("weight")] = e.w;
        je.append(o);
    }
    root[QStringLiteral("edges")] = je;
    // Carry the QML-owned view/UI config (2D/3D toggles, style, colours) so a
    // saved document round-trips the user's view settings.
    if (!m_viewConfig.isEmpty()) {
        const QJsonDocument vd = QJsonDocument::fromJson(m_viewConfig.toUtf8());
        if (vd.isObject()) root[QStringLiteral("view")] = vd.object();
    }
    return QString::fromUtf8(QJsonDocument(root).toJson(QJsonDocument::Indented));
}

void VisualizerController::setViewConfig(const QString& v) {
    if (m_viewConfig == v) return;
    m_viewConfig = v;
    emit viewConfigChanged();
}

// Pure parse — no member access beyond the nested structs, so it is safe to
// run on a worker thread. Returns ok=false on malformed JSON.
VisualizerController::ParsedDoc VisualizerController::parseDoc(const QByteArray& bytes) {
    ParsedDoc out;
    QJsonParseError err{};
    const QJsonDocument doc = QJsonDocument::fromJson(bytes, &err);
    if (err.error != QJsonParseError::NoError || !doc.isObject()) return out;   // ok=false
    const QJsonObject root = doc.object();

    std::vector<Node> nodes;
    const QJsonArray jn = root[QStringLiteral("nodes")].toArray();
    for (const QJsonValue& v : jn) {
        const QJsonObject o = v.toObject();
        nodes.push_back({o[QStringLiteral("label")].toString(),
                         o[QStringLiteral("x")].toDouble(), o[QStringLiteral("y")].toDouble()});
    }
    const int n = static_cast<int>(nodes.size());
    std::vector<Edge> edges;
    const QJsonArray je = root[QStringLiteral("edges")].toArray();
    for (const QJsonValue& v : je) {
        const QJsonObject o = v.toObject();
        const int f = o[QStringLiteral("from")].toInt(-1), t = o[QStringLiteral("to")].toInt(-1);
        if (f < 0 || t < 0 || f >= n || t >= n) continue;
        edges.push_back({f, t, o[QStringLiteral("weight")].toDouble(1.0)});
    }
    // Guarantee unique labels even if the file (hand-edited) has duplicates.
    std::set<QString> used;
    for (Node& nd : nodes) {
        QString base = nd.label.isEmpty() ? QStringLiteral("v") : nd.label;
        QString l = base;
        for (int k = 2; used.count(l); ++k) l = base + QStringLiteral("_") + QString::number(k);
        nd.label = l;
        used.insert(l);
    }

    out.nodes = std::move(nodes);
    out.edges = std::move(edges);
    out.directed = root[QStringLiteral("directed")].toBool();
    if (root[QStringLiteral("view")].isObject())
        out.view = QString::fromUtf8(
            QJsonDocument(root[QStringLiteral("view")].toObject()).toJson(QJsonDocument::Compact));
    out.ok = true;
    return out;
}

void VisualizerController::applyDoc(ParsedDoc doc) {
    pushUndo();
    m_nodes = std::move(doc.nodes);
    m_edges = std::move(doc.edges);
    m_directed = doc.directed;
    m_viewConfig = doc.view;            // carried view config (empty for old/simple docs)
    resetRun();
    emit graphChanged();
    emit viewConfigChanged();
}

bool VisualizerController::loadJson(const QString& text) {
    ParsedDoc d = parseDoc(text.toUtf8());
    if (!d.ok) return false;
    applyDoc(std::move(d));
    return true;
}

bool VisualizerController::saveToFile(const QUrl& url) const {
    const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
    QFile f(path);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Text)) return false;
    f.write(toJson().toUtf8());
    return true;
}

bool VisualizerController::loadFromFile(const QUrl& url) {
    const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
    QFile f(path);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return false;
    return loadJson(QString::fromUtf8(f.readAll()));
}

void VisualizerController::loadFromFileAsync(const QUrl& url) {
    if (m_loading) return;
    const QString path = url.isLocalFile() ? url.toLocalFile() : url.toString();
    m_loading = true;
    emit loadingChanged();
    // Read + parse off the GUI thread; marshal the result back for applying.
    std::thread([this, path]() {
        ParsedDoc doc;
        QFile f(path);
        if (f.open(QIODevice::ReadOnly | QIODevice::Text))
            doc = parseDoc(f.readAll());
        QMetaObject::invokeMethod(this, [this, d = std::move(doc)]() mutable {
            finishAsyncLoad(std::move(d));
        }, Qt::QueuedConnection);
    }).detach();
}

void VisualizerController::finishAsyncLoad(ParsedDoc doc) {
    if (doc.ok) applyDoc(std::move(doc));
    m_loading = false;
    emit loadingChanged();
}

}  // namespace ga::studio

