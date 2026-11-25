// VisualizerController — core: model exposure, editing, undo, layout, samples.
// The serialization/IO lives in VisualizerController_io.cpp and the algorithm
// run + playback in VisualizerController_run.cpp (same class, split for size).
#include "VisualizerController.h"

#include "version.h"   // GA_APP_VERSION (generated)

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

QString VisualizerController::appVersion() const { return QStringLiteral(GA_APP_VERSION); }

VisualizerController::VisualizerController(QObject* parent) : QObject(parent) {
    loadSample();
}

// ---- model exposure ------------------------------------------------------

QVariantList VisualizerController::nodes() const {
    QVariantList out;
    for (int i = 0; i < static_cast<int>(m_nodes.size()); ++i) {
        QVariantMap m;
        m[QStringLiteral("id")] = i;
        m[QStringLiteral("label")] = m_nodes[i].label;
        m[QStringLiteral("x")] = m_nodes[i].x;
        m[QStringLiteral("y")] = m_nodes[i].y;
        out.push_back(m);
    }
    return out;
}

QString VisualizerController::nodesJson() const {
    QJsonArray arr;
    for (int i = 0; i < static_cast<int>(m_nodes.size()); ++i) {
        QJsonObject o;
        o[QStringLiteral("id")] = i;
        o[QStringLiteral("x")] = m_nodes[i].x;
        o[QStringLiteral("y")] = m_nodes[i].y;
        o[QStringLiteral("label")] = m_nodes[i].label;
        arr.append(o);
    }
    return QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

QString VisualizerController::edgesJson() const {
    QJsonArray arr;
    for (const Edge& e : m_edges) {
        QJsonObject o;
        o[QStringLiteral("from")] = e.from;
        o[QStringLiteral("to")] = e.to;
        o[QStringLiteral("weight")] = e.w;
        arr.append(o);
    }
    return QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

QVariantList VisualizerController::edges() const {
    QVariantList out;
    for (const Edge& e : m_edges) {
        QVariantMap m;
        m[QStringLiteral("from")] = e.from;
        m[QStringLiteral("to")] = e.to;
        m[QStringLiteral("weight")] = e.w;
        out.push_back(m);
    }
    return out;
}

void VisualizerController::setDirected(bool d) {
    if (d == m_directed) return;
    pushUndo();
    m_directed = d;
    resetRun();
    emit graphChanged();
}

// ---- build ---------------------------------------------------------------

bool VisualizerController::labelInUse(const QString& label, int exceptId) const {
    for (int i = 0; i < static_cast<int>(m_nodes.size()); ++i)
        if (i != exceptId && m_nodes[i].label == label) return true;
    return false;
}

// A label guaranteed not to clash with any vertex (other than exceptId).
// Empty `desired` → the smallest free integer; a taken name → name_2, name_3, …
QString VisualizerController::makeUniqueLabel(const QString& desired, int exceptId) const {
    if (desired.isEmpty()) {
        int n = 0;
        while (labelInUse(QString::number(n), exceptId)) ++n;
        return QString::number(n);
    }
    if (!labelInUse(desired, exceptId)) return desired;
    for (int k = 2; ; ++k) {
        const QString cand = desired + QStringLiteral("_") + QString::number(k);
        if (!labelInUse(cand, exceptId)) return cand;
    }
}

// ---- undo / redo ---------------------------------------------------------

void VisualizerController::pushUndo() {
    if (m_suppressUndo) return;
    m_undo.push_back({m_nodes, m_edges, m_directed});
    if (m_undo.size() > 100) m_undo.erase(m_undo.begin());
    m_redo.clear();
    emit historyChanged();
}

void VisualizerController::beginEdit() { pushUndo(); }

void VisualizerController::undo() {
    if (m_undo.empty()) return;
    m_redo.push_back({m_nodes, m_edges, m_directed});
    const GraphState s = m_undo.back();
    m_undo.pop_back();
    m_nodes = s.nodes; m_edges = s.edges; m_directed = s.directed;
    resetRun();
    emit graphChanged();
    emit historyChanged();
}

void VisualizerController::redo() {
    if (m_redo.empty()) return;
    m_undo.push_back({m_nodes, m_edges, m_directed});
    const GraphState s = m_redo.back();
    m_redo.pop_back();
    m_nodes = s.nodes; m_edges = s.edges; m_directed = s.directed;
    resetRun();
    emit graphChanged();
    emit historyChanged();
}

int VisualizerController::addVertex(qreal x, qreal y, const QString& label) {
    pushUndo();
    const int id = static_cast<int>(m_nodes.size());
    m_nodes.push_back({makeUniqueLabel(label), x, y});
    resetRun();
    emit graphChanged();
    return id;
}

// Add `count` blank vertices in a grid placed just right of the existing graph
// (so they don't overlap it), auto-labelled by index.
void VisualizerController::addVertices(int count) {
    if (count <= 0) return;
    pushUndo();
    double startX = 120, topY = 120;
    if (!m_nodes.empty()) {
        double maxX = -1e9, minY = 1e9;
        for (const Node& n : m_nodes) { if (n.x > maxX) maxX = n.x; if (n.y < minY) minY = n.y; }
        startX = maxX + 140;
        topY = minY;
    }
    const double gap = 80;
    const int perCol = 6;
    for (int i = 0; i < count; ++i)
        m_nodes.push_back({makeUniqueLabel(QString()),
                           startX + (i / perCol) * gap, topY + (i % perCol) * gap});
    resetRun();
    emit graphChanged();
}

void VisualizerController::addEdge(int u, int v, double w) {
    const int n = static_cast<int>(m_nodes.size());
    if (u < 0 || v < 0 || u >= n || v >= n || u == v) return;   // no out-of-range / self-loops
    // Skip a duplicate of an edge that already connects the pair (either
    // direction when undirected) — keeps the picture clean.
    for (const Edge& e : m_edges) {
        const bool same = (e.from == u && e.to == v);
        const bool rev = (!m_directed && e.from == v && e.to == u);
        if (same || rev) return;
    }
    pushUndo();
    m_edges.push_back({u, v, w});
    resetRun();
    emit graphChanged();
}

void VisualizerController::setEdgeWeight(int from, int to, double w) {
    for (Edge& e : m_edges) {
        const bool same = (e.from == from && e.to == to);
        const bool rev = (!m_directed && e.from == to && e.to == from);
        if (same || rev) {
            if (e.w == w) return;
            pushUndo();
            e.w = w;
            resetRun();                 // weights changed — any prior run is stale
            emit graphChanged();
            return;
        }
    }
}

void VisualizerController::removeEdge(int from, int to) {
    for (auto it = m_edges.begin(); it != m_edges.end(); ++it) {
        const bool same = (it->from == from && it->to == to);
        const bool rev = (!m_directed && it->from == to && it->to == from);
        if (same || rev) {
            pushUndo();
            m_edges.erase(it);
            resetRun();
            emit graphChanged();
            return;
        }
    }
}

void VisualizerController::removeVertex(int id) {
    if (id < 0 || id >= static_cast<int>(m_nodes.size())) return;
    pushUndo();
    m_nodes.erase(m_nodes.begin() + id);
    // Drop incident edges and renumber endpoints above the removed id.
    std::vector<Edge> kept;
    kept.reserve(m_edges.size());
    for (Edge e : m_edges) {
        if (e.from == id || e.to == id) continue;
        if (e.from > id) --e.from;
        if (e.to > id) --e.to;
        kept.push_back(e);
    }
    m_edges = std::move(kept);
    resetRun();
    emit graphChanged();
}

void VisualizerController::moveVertex(int id, qreal x, qreal y) {
    if (id < 0 || id >= static_cast<int>(m_nodes.size())) return;
    m_nodes[id].x = x;
    m_nodes[id].y = y;
    emit graphChanged();
}

void VisualizerController::renameVertex(int id, const QString& label) {
    if (id < 0 || id >= static_cast<int>(m_nodes.size())) return;
    const QString want = label.trimmed();
    if (want.isEmpty()) return;
    // Keep names unique — a taken name is disambiguated (e.g. "A" -> "A_2").
    const QString uniq = makeUniqueLabel(want, id);
    if (m_nodes[id].label == uniq) return;
    pushUndo();
    m_nodes[id].label = uniq;           // cosmetic — the run/topology is unaffected
    emit graphChanged();
}

// One Fruchterman–Reingold pass: all-pairs repulsion + edge-spring attraction +
// a centre gravity (keeps disconnected nodes bounded). `pinned` (>=0) is held
// fixed — used for live drag; pass -1 to move every node. `temp` caps the
// per-node displacement this pass.
void VisualizerController::fdIterate(int pinned, double temp) {
    const int n = static_cast<int>(m_nodes.size());
    const double cx = 430, cy = 320;
    const double k = 150;                 // ideal edge length (px)
    const double gravity = 0.30;          // centre pull
    std::vector<double> dx(n, 0), dy(n, 0);

    for (int i = 0; i < n; ++i)
        for (int j = i + 1; j < n; ++j) {
            double ex = m_nodes[i].x - m_nodes[j].x, ey = m_nodes[i].y - m_nodes[j].y;
            double d = std::hypot(ex, ey);
            if (d < 0.01) { d = 0.01; ex = 0.01; }
            const double f = k * k / d, ux = ex / d, uy = ey / d;
            dx[i] += ux * f; dy[i] += uy * f;
            dx[j] -= ux * f; dy[j] -= uy * f;
        }
    for (const Edge& e : m_edges) {
        if (e.from == e.to) continue;
        double ex = m_nodes[e.from].x - m_nodes[e.to].x, ey = m_nodes[e.from].y - m_nodes[e.to].y;
        double d = std::hypot(ex, ey);
        if (d < 0.01) d = 0.01;
        const double f = d * d / k, ux = ex / d, uy = ey / d;
        dx[e.from] -= ux * f; dy[e.from] -= uy * f;
        dx[e.to] += ux * f; dy[e.to] += uy * f;
    }
    for (int i = 0; i < n; ++i) {
        dx[i] += (cx - m_nodes[i].x) * gravity;
        dy[i] += (cy - m_nodes[i].y) * gravity;
    }
    for (int i = 0; i < n; ++i) {
        if (i == pinned) continue;        // the dragged node stays under the cursor
        const double d = std::hypot(dx[i], dy[i]);
        if (d < 0.01) continue;
        const double lim = std::min(d, temp);
        m_nodes[i].x += dx[i] / d * lim;
        m_nodes[i].y += dy[i] / d * lim;
    }
}

// Seed on a circle (deterministic from any starting mess), then relax with a
// cooling schedule.
void VisualizerController::relayout() {
    const int n = static_cast<int>(m_nodes.size());
    if (n == 0) return;
    pushUndo();
    const double cx = 430, cy = 320;
    if (n == 1) { m_nodes[0].x = cx; m_nodes[0].y = cy; emit graphChanged(); return; }

    const double R = 60 + 34.0 * n;
    for (int i = 0; i < n; ++i) {
        const double a = -M_PI / 2 + i * 2 * M_PI / n;
        m_nodes[i].x = cx + R * std::cos(a);
        m_nodes[i].y = cy + R * std::sin(a);
    }
    double temp = R / 2;
    for (int it = 0; it < 300; ++it) { fdIterate(-1, temp); temp *= 0.98; }
    emit graphChanged();
}

// Place every vertex evenly on a circle (no relaxation), in id order.
void VisualizerController::layoutCircular() {
    const int n = static_cast<int>(m_nodes.size());
    if (n == 0) return;
    pushUndo();
    const double cx = 430, cy = 320;
    if (n == 1) { m_nodes[0].x = cx; m_nodes[0].y = cy; emit graphChanged(); return; }
    const double R = 60 + 34.0 * n;
    for (int i = 0; i < n; ++i) {
        const double a = -M_PI / 2 + i * 2 * M_PI / n;
        m_nodes[i].x = cx + R * std::cos(a);
        m_nodes[i].y = cy + R * std::sin(a);
    }
    emit graphChanged();
}

// Remap every vertex so the current bounding box fills [margin, w-margin] ×
// [margin, h-margin] — a non-uniform stretch that adapts the layout to the
// region's shape (the "Fill canvas" action). Degenerate spans are centred.
void VisualizerController::layoutToRegion(double w, double h, double margin) {
    const int n = static_cast<int>(m_nodes.size());
    const double tw = w - 2 * margin, th = h - 2 * margin;
    if (n == 0 || tw <= 1 || th <= 1) return;
    double minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
    for (const Node& nd : m_nodes) {
        if (nd.x < minX) minX = nd.x; if (nd.x > maxX) maxX = nd.x;
        if (nd.y < minY) minY = nd.y; if (nd.y > maxY) maxY = nd.y;
    }
    const double bw = maxX - minX, bh = maxY - minY;
    pushUndo();
    for (Node& nd : m_nodes) {
        nd.x = (bw > 1e-6) ? margin + (nd.x - minX) / bw * tw : w / 2;
        nd.y = (bh > 1e-6) ? margin + (nd.y - minY) / bh * th : h / 2;
    }
    emit graphChanged();   // positions only — a loaded run stays valid
}

void VisualizerController::clear() {
    if (m_nodes.empty() && m_edges.empty()) return;
    pushUndo();
    m_nodes.clear();
    m_edges.clear();
    resetRun();
    emit graphChanged();
}

void VisualizerController::loadSample() {
    m_nodes.clear();
    m_edges.clear();
    m_directed = false;
    // A small weighted graph laid out on a ring + centre.
    const double cx = 430, cy = 320, r = 230;
    const char* labels[] = {"A", "B", "C", "D", "E", "F"};
    for (int i = 0; i < 6; ++i) {
        const double a = -M_PI / 2 + i * 2 * M_PI / 6;
        m_nodes.push_back({QString::fromLatin1(labels[i]), cx + r * std::cos(a), cy + r * std::sin(a)});
    }
    auto E = [&](int u, int v, double w) { m_edges.push_back({u, v, w}); };
    E(0, 1, 7); E(0, 2, 9); E(0, 5, 14);
    E(1, 2, 10); E(1, 3, 15);
    E(2, 3, 11); E(2, 5, 2);
    E(3, 4, 6); E(4, 5, 9);
    resetRun();
    emit graphChanged();
}

// ---- bulk input, sample library, save / load -----------------------------

// Build a graph from a text edge list: one edge per line, "from to [weight]"
// (whitespace- or comma-separated); a lone token adds an isolated vertex; '#'
// starts a comment. Vertices are created by label. Positions come from relayout.
void VisualizerController::loadEdgeList(const QString& text, bool directed, bool replace) {
    // No usable content → do nothing (so an empty Replace never wipes the graph).
    bool hasContent = false;
    for (QString line : text.split(QLatin1Char('\n'))) {
        const int hash = line.indexOf(QLatin1Char('#'));
        if (hash >= 0) line = line.left(hash);
        if (!line.trimmed().isEmpty()) { hasContent = true; break; }
    }
    if (!hasContent) return;
    pushUndo();

    if (replace) { m_nodes.clear(); m_edges.clear(); }
    m_directed = directed;

    std::map<QString, int> idx;
    for (int i = 0; i < static_cast<int>(m_nodes.size()); ++i) idx[m_nodes[i].label] = i;
    auto vertexFor = [&](const QString& label) -> int {
        auto it = idx.find(label);
        if (it != idx.end()) return it->second;
        const int id = static_cast<int>(m_nodes.size());
        m_nodes.push_back({label, 0, 0});
        idx[label] = id;
        return id;
    };
    auto addEdgeRaw = [&](int u, int v, double w) {
        if (u == v) return;
        for (const Edge& e : m_edges) {
            if (e.from == u && e.to == v) return;
            if (!m_directed && e.from == v && e.to == u) return;
        }
        m_edges.push_back({u, v, w});
    };

    static const QRegularExpression sep(QStringLiteral("[\\s,]+"));
    const QStringList lines = text.split(QLatin1Char('\n'));
    for (QString line : lines) {
        const int h = line.indexOf(QLatin1Char('#'));
        if (h >= 0) line = line.left(h);
        line = line.trimmed();
        if (line.isEmpty()) continue;
        const QStringList tok = line.split(sep, Qt::SkipEmptyParts);
        if (tok.isEmpty()) continue;
        if (tok.size() == 1) { vertexFor(tok[0]); continue; }   // isolated vertex
        const int u = vertexFor(tok[0]);
        const int v = vertexFor(tok[1]);
        double w = 1.0;
        if (tok.size() >= 3) { bool ok = false; const double p = tok[2].toDouble(&ok); if (ok) w = p; }
        addEdgeRaw(u, v, w);
    }
    resetRun();
    m_suppressUndo = true;       // the pushUndo above already covers this whole edit
    relayout();                  // positions the fresh vertices (emits graphChanged)
    m_suppressUndo = false;
    emit graphChanged();
}

QStringList VisualizerController::sampleNames() const {
    return {QStringLiteral("Weighted demo"), QStringLiteral("Grid 4×4"),
            QStringLiteral("Binary tree"), QStringLiteral("Complete K5"),
            QStringLiteral("Negative cycle")};
}

void VisualizerController::loadNamedSample(const QString& name) {
    pushUndo();
    if (name == QStringLiteral("Weighted demo")) { loadSample(); return; }

    m_nodes.clear();
    m_edges.clear();
    m_directed = false;
    auto E = [&](int u, int v, double w) { m_edges.push_back({u, v, w}); };

    if (name == QStringLiteral("Grid 4×4")) {
        const double x0 = 180, y0 = 120, gap = 150;
        for (int r = 0; r < 4; ++r)
            for (int c = 0; c < 4; ++c)
                m_nodes.push_back({QString::number(r * 4 + c), x0 + c * gap, y0 + r * gap});
        for (int r = 0; r < 4; ++r)
            for (int c = 0; c < 4; ++c) {
                const int id = r * 4 + c;
                if (c < 3) E(id, id + 1, 1);
                if (r < 3) E(id, id + 4, 1);
            }
    } else if (name == QStringLiteral("Binary tree")) {
        const double cx = 440;
        const char* lbl[] = {"1", "2", "3", "4", "5", "6", "7"};
        const double px[] = {cx, cx - 190, cx + 190, cx - 290, cx - 100, cx + 100, cx + 290};
        const double py[] = {110, 250, 250, 400, 400, 400, 400};
        for (int i = 0; i < 7; ++i) m_nodes.push_back({QString::fromLatin1(lbl[i]), px[i], py[i]});
        E(0, 1, 1); E(0, 2, 1); E(1, 3, 1); E(1, 4, 1); E(2, 5, 1); E(2, 6, 1);
    } else if (name == QStringLiteral("Complete K5")) {
        const double cx = 440, cy = 300, r = 210;
        const char* lbl[] = {"A", "B", "C", "D", "E"};
        for (int i = 0; i < 5; ++i) {
            const double a = -M_PI / 2 + i * 2 * M_PI / 5;
            m_nodes.push_back({QString::fromLatin1(lbl[i]), cx + r * std::cos(a), cy + r * std::sin(a)});
        }
        int w = 2;
        for (int i = 0; i < 5; ++i)
            for (int j = i + 1; j < 5; ++j) E(i, j, w++);   // distinct weights
    } else if (name == QStringLiteral("Negative cycle")) {
        m_directed = true;
        const char* lbl[] = {"S", "A", "B", "C"};
        const double px[] = {200, 450, 700, 450};
        const double py[] = {300, 160, 300, 440};
        for (int i = 0; i < 4; ++i) m_nodes.push_back({QString::fromLatin1(lbl[i]), px[i], py[i]});
        E(0, 1, 4); E(1, 2, 3); E(2, 3, 2); E(3, 1, -6);     // A→B→C→A sums to -1
    } else {
        loadSample();
        return;
    }
    resetRun();
    emit graphChanged();
}

}  // namespace ga::studio

