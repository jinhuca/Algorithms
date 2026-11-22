// VisualizerController — algorithm run, step playback, trace/path state. Part of
// the VisualizerController class (declared in VisualizerController.h); see also
// VisualizerController.cpp and VisualizerController_io.cpp.
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
#include <ga/mst/kruskal.hpp>
#include <ga/mst/prim.hpp>
#include <ga/short_paths/bellman_ford.hpp>
#include <ga/short_paths/dijkstra.hpp>

// ---- algorithm + playback ------------------------------------------------

ga::graph<double> VisualizerController::buildGraph(bool directed) const {
    ga::graph<double> g(m_nodes.size(), directed);
    for (const Edge& e : m_edges)
        g.add_edge(static_cast<ga::vertex>(e.from), static_cast<ga::vertex>(e.to), e.w);
    return g;
}

void VisualizerController::resetRun() {
    m_snaps.clear();
    m_cursor = 0;
    m_runMs = 0;
    m_runSrc = -1;
    m_pathTarget = -1;
    m_pathEdges.clear();
    m_pathSummary.clear();
    emit timelineChanged();
    emit cursorChanged();
    emit pathChanged();
}

void VisualizerController::run(const QString& algo, int src) {
    const int n = static_cast<int>(m_nodes.size());
    if (n == 0 || src < 0 || src >= n) return;

    // Shortest-path algorithms carry distances; traversals don't. MST (Kruskal /
    // Prim) is weight-aware but not a distance algorithm, and is undefined on a
    // digraph — so it always runs on an undirected build of the graph.
    const bool dist_algo = (algo == QStringLiteral("Dijkstra") || algo == QStringLiteral("Bellman-Ford"));
    const bool mst_algo = (algo == QStringLiteral("Kruskal") || algo == QStringLiteral("Prim"));

    QElapsedTimer timer;
    timer.start();                       // wall-clock time of the computation
    const ga::graph<double> g = buildGraph(mst_algo ? false : m_directed);

    // Fold the step stream into one snapshot per step.
    std::vector<Snap> snaps;
    Snap cur;
    cur.vstate.assign(n, Idle);
    cur.dist.assign(n, std::numeric_limits<double>::quiet_NaN());
    cur.parent.assign(n, ga::nil);
    cur.note = QStringLiteral("start at %1").arg(m_nodes[src].label);
    if (dist_algo) cur.dist[src] = 0;   // the source is distance 0 from the outset
    snaps.push_back(cur);

    auto emitStep = [&](const ga::step& s) {
        cur.au = cur.av = -1;
        switch (s.kind) {
            case ga::evt::discover_vertex:
                if (s.u < static_cast<ga::vertex>(n)) cur.vstate[s.u] = Frontier;
                cur.note = QStringLiteral("discover %1").arg(m_nodes[s.u].label);
                break;
            case ga::evt::visit_vertex:
                if (s.u < static_cast<ga::vertex>(n)) {
                    cur.vstate[s.u] = Current;
                    if (dist_algo) cur.dist[s.u] = s.value;
                }
                cur.note = QStringLiteral("visit %1").arg(m_nodes[s.u].label);
                break;
            case ga::evt::finish_vertex:
                if (s.u < static_cast<ga::vertex>(n)) cur.vstate[s.u] = Settled;
                cur.note = QStringLiteral("finish %1").arg(m_nodes[s.u].label);
                break;
            case ga::evt::examine_edge:
                cur.au = static_cast<int>(s.u); cur.av = static_cast<int>(s.v);
                cur.note = QStringLiteral("examine %1 → %2").arg(m_nodes[s.u].label, m_nodes[s.v].label);
                break;
            case ga::evt::tree_edge:
                cur.au = static_cast<int>(s.u); cur.av = static_cast<int>(s.v);
                if (s.v < static_cast<ga::vertex>(n)) cur.parent[s.v] = s.u;
                // Also record the accepted edge explicitly — Kruskal's forest
                // can't be reconstructed from parent[] alone (see Snap::treeAccum).
                cur.treeAccum.push_back({static_cast<int>(s.u), static_cast<int>(s.v)});
                cur.note = QStringLiteral("tree edge %1 — %2").arg(m_nodes[s.u].label, m_nodes[s.v].label);
                break;
            case ga::evt::relax_edge:
                cur.au = static_cast<int>(s.u); cur.av = static_cast<int>(s.v);
                if (s.v < static_cast<ga::vertex>(n)) { cur.parent[s.v] = s.u; cur.dist[s.v] = s.value; }
                cur.note = QStringLiteral("relax %1 → %2 = %3")
                               .arg(m_nodes[s.u].label, m_nodes[s.v].label).arg(s.value);
                break;
            case ga::evt::skip_edge:
                cur.au = static_cast<int>(s.u); cur.av = static_cast<int>(s.v);
                cur.note = QStringLiteral("skip %1 → %2").arg(m_nodes[s.u].label, m_nodes[s.v].label);
                break;
            default:
                if (!s.note.empty()) cur.note = QString::fromStdString(s.note);
                break;
        }
        snaps.push_back(cur);
    };

    if (algo == QStringLiteral("Dijkstra")) {
        std::vector<ga::vertex> parent;
        ga::dijkstra(g, static_cast<ga::vertex>(src), &parent, emitStep);
    } else if (algo == QStringLiteral("Bellman-Ford")) {
        std::vector<ga::vertex> parent;
        bool okFlag = true;
        ga::bellman_ford(g, static_cast<ga::vertex>(src), &parent, &okFlag, emitStep);
    } else if (algo == QStringLiteral("Kruskal") || algo == QStringLiteral("Prim")) {
        const double w = (algo == QStringLiteral("Prim"))
                             ? ga::prim(g, static_cast<ga::vertex>(src), emitStep)
                             : ga::kruskal(g, emitStep);
        // Final summary step: the completed MST, its total weight and edge count.
        const int k = static_cast<int>(cur.treeAccum.size());
        const bool forest = (k < n - 1);        // disconnected graph -> spanning forest
        cur.au = cur.av = -1;
        cur.note = QStringLiteral("%1 complete  ·  weight %2  ·  %3 %4")
                       .arg(forest ? QStringLiteral("spanning forest") : QStringLiteral("MST"))
                       .arg(QString::number(w, 'g', 4))
                       .arg(k).arg(k == 1 ? QStringLiteral("edge") : QStringLiteral("edges"));
        snaps.push_back(cur);
    } else if (algo == QStringLiteral("DFS")) {
        ga::dfs(g, static_cast<ga::vertex>(src), emitStep);
    } else {
        ga::bfs(g, static_cast<ga::vertex>(src), emitStep);
    }
    m_runMs = timer.nsecsElapsed() / 1.0e6;   // build + algorithm + fold

    m_snaps = std::move(snaps);
    // Land on the final step so the completed result (settled states, result
    // tree, distances) is shown right away for inspection; Play replays from
    // the start (it seeks to 0 first when the cursor is already at the end).
    m_cursor = static_cast<int>(m_snaps.size()) - 1;
    m_runSrc = src;
    m_runAlgo = algo;
    m_pathTarget = -1;               // a fresh run clears any prior path highlight
    m_pathEdges.clear();
    m_pathSummary.clear();
    emit timelineChanged();
    emit cursorChanged();
    emit pathChanged();
}

void VisualizerController::seek(int c) {
    if (m_snaps.empty()) return;
    c = qBound(0, c, static_cast<int>(m_snaps.size()) - 1);
    if (c == m_cursor) return;
    m_cursor = c;
    emit cursorChanged();
}

void VisualizerController::stepForward() { seek(m_cursor + 1); }
void VisualizerController::stepBack() { seek(m_cursor - 1); }

// ---- current snapshot accessors -----------------------------------------

QString VisualizerController::stepNote() const {
    return m_snaps.empty() ? QString() : m_snaps[m_cursor].note;
}

QVariantList VisualizerController::vertexStates() const {
    QVariantList out;
    if (m_snaps.empty()) { for (std::size_t i = 0; i < m_nodes.size(); ++i) out.push_back(int(Idle)); return out; }
    for (int s : m_snaps[m_cursor].vstate) out.push_back(s);
    return out;
}

QVariantList VisualizerController::vertexDists() const {
    QVariantList out;
    if (m_snaps.empty()) { for (std::size_t i = 0; i < m_nodes.size(); ++i) out.push_back(QString()); return out; }
    for (double d : m_snaps[m_cursor].dist)
        out.push_back(std::isnan(d) ? QString() : QString::number(d, 'g', 4));
    return out;
}

QVariantList VisualizerController::treeEdges() const {
    QVariantList out;
    if (m_snaps.empty()) return out;
    const Snap& s = m_snaps[m_cursor];
    for (int v = 0; v < static_cast<int>(s.parent.size()); ++v) {
        const ga::vertex p = s.parent[v];
        if (p != ga::nil && p != static_cast<ga::vertex>(v)) {
            QVariantMap m;
            m[QStringLiteral("from")] = static_cast<int>(p);
            m[QStringLiteral("to")] = v;
            out.push_back(m);
        }
    }
    for (const auto& e : s.treeAccum) {      // MST forest edges (see Snap::treeAccum)
        QVariantMap m;
        m[QStringLiteral("from")] = e.first;
        m[QStringLiteral("to")] = e.second;
        out.push_back(m);
    }
    return out;
}

// One highlight state per edge (m_edges order): 0 normal, 1 tree, 2 active,
// 3 on the highlighted path. Classifying every edge here in O(E) — with a hash
// set of tree/path endpoints — keeps the dense edge layer's per-step cost flat:
// each delegate reads one int instead of scanning the tree/path lists itself.
QVariantList VisualizerController::edgeStates() const {
    const int ne = static_cast<int>(m_edges.size());
    QVariantList out;
    out.reserve(ne);
    if (m_snaps.empty()) { for (int i = 0; i < ne; ++i) out.push_back(0); return out; }

    auto key = [](int a, int b) { return (static_cast<qint64>(a) << 32) | static_cast<quint32>(b); };
    const Snap& s = m_snaps[m_cursor];

    // Tree edges (parent → child) and highlighted-path edges, both orientations
    // when undirected so a stored edge matches regardless of its direction.
    std::unordered_set<qint64> tree, path;
    for (int v = 0; v < static_cast<int>(s.parent.size()); ++v) {
        const ga::vertex p = s.parent[v];
        if (p != ga::nil && p != static_cast<ga::vertex>(v)) {
            tree.insert(key(static_cast<int>(p), v));
            if (!m_directed) tree.insert(key(v, static_cast<int>(p)));
        }
    }
    for (const auto& e : s.treeAccum) {      // MST forest edges (both orientations)
        tree.insert(key(e.first, e.second));
        tree.insert(key(e.second, e.first));
    }
    for (const auto& pr : m_pathEdges) {
        path.insert(key(pr.first, pr.second));
        if (!m_directed) path.insert(key(pr.second, pr.first));
    }
    const int af = s.au, at = s.av;

    for (const Edge& e : m_edges) {
        int st = 0;
        if (path.count(key(e.from, e.to))) st = 3;
        else if ((af == e.from && at == e.to) || (!m_directed && af == e.to && at == e.from)) st = 2;
        else if (tree.count(key(e.from, e.to))) st = 1;
        out.push_back(st);
    }
    return out;
}

int VisualizerController::activeFrom() const { return m_snaps.empty() ? -1 : m_snaps[m_cursor].au; }
int VisualizerController::activeTo() const { return m_snaps.empty() ? -1 : m_snaps[m_cursor].av; }

// ---- highlighted path -----------------------------------------------------

QVariantList VisualizerController::pathEdges() const {
    QVariantList out;
    for (const auto& pr : m_pathEdges) {
        QVariantMap m;
        m[QStringLiteral("from")] = pr.first;
        m[QStringLiteral("to")] = pr.second;
        out.push_back(m);
    }
    return out;
}

// Reconstruct the path from the run's source to `target` by walking the final
// snapshot's parent chain (the completed result tree). Sets the edge list and a
// one-line summary (with the shortest-path cost for the distance algorithms).
void VisualizerController::highlightPathTo(int target) {
    m_pathEdges.clear();
    m_pathSummary.clear();
    const int n = static_cast<int>(m_nodes.size());
    if (m_snaps.empty() || m_runSrc < 0 || target < 0 || target >= n) {
        m_pathTarget = -1;
        emit pathChanged();
        return;
    }
    m_pathTarget = target;
    const QString tlabel = m_nodes[target].label;
    const QString slabel = (m_runSrc < n) ? m_nodes[m_runSrc].label : QString();

    if (target == m_runSrc) {                 // the source itself — trivial path
        m_pathSummary = QStringLiteral("source %1").arg(slabel);
        emit pathChanged();
        return;
    }

    // Walk target → source through the parent pointers.
    const Snap& fin = m_snaps.back();
    std::vector<int> chain;                   // target … source (reversed)
    std::vector<bool> seen(n, false);
    bool reached = false;
    for (int v = target;;) {
        chain.push_back(v);
        if (v == m_runSrc) { reached = true; break; }
        if (seen[v]) break;                   // guard against a cycle in parents
        seen[v] = true;
        const ga::vertex p = fin.parent[v];
        if (p == ga::nil || p == static_cast<ga::vertex>(v)) break;
        v = static_cast<int>(p);
    }

    if (!reached) {
        m_pathSummary = QStringLiteral("%1 unreachable from %2").arg(tlabel, slabel);
        emit pathChanged();
        return;
    }

    std::reverse(chain.begin(), chain.end());  // now source … target
    QStringList names;
    for (int i = 0; i < static_cast<int>(chain.size()); ++i) {
        names << m_nodes[chain[i]].label;
        if (i > 0) m_pathEdges.push_back(qMakePair(chain[i - 1], chain[i]));
    }
    const int hops = static_cast<int>(m_pathEdges.size());
    QString s = QStringLiteral("path %1").arg(names.join(QStringLiteral(" → ")));
    const bool dist_algo =
        (m_runAlgo == QStringLiteral("Dijkstra") || m_runAlgo == QStringLiteral("Bellman-Ford"));
    if (dist_algo && !std::isnan(fin.dist[target]))
        s += QStringLiteral("  ·  cost %1").arg(QString::number(fin.dist[target], 'g', 4));
    s += QStringLiteral("  ·  %1 %2").arg(hops).arg(hops == 1 ? QStringLiteral("edge")
                                                              : QStringLiteral("edges"));
    m_pathSummary = s;
    emit pathChanged();
}

void VisualizerController::clearPath() {
    if (m_pathTarget < 0 && m_pathEdges.empty()) return;
    m_pathTarget = -1;
    m_pathEdges.clear();
    m_pathSummary.clear();
    emit pathChanged();
}
