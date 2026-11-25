#pragma once

#include <QObject>
#include <QPair>
#include <QString>
#include <QStringList>
#include <QUrl>
#include <QVariantList>
#include <QtQmlIntegration>

#include <utility>
#include <vector>

#include <ga/graph/graph.hpp>

// QML-facing controller: owns the display graph (vertices with labels/positions
// + weighted edges), runs a ga::core algorithm with a recording tracer, folds
// the emitted ga::step stream into one visual snapshot per step, and exposes a
// playback cursor the QML canvas binds to. See ../ARCHITECTURE.md.
namespace ga::studio {

class VisualizerController : public QObject {
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString appVersion READ appVersion CONSTANT)   // full Major.Minor.Patch.Build (version.h)

    // --- graph model ---
    Q_PROPERTY(QVariantList nodes READ nodes NOTIFY graphChanged)        // [{id,label,x,y}]
    // JSON-string forms of the node/edge lists. Iterating a QVariantList element
    // by element from JS is O(n^2) (the sequence wrapper reconverts per access),
    // which froze large-graph loads/edits; QML JSON.parse()s these into native
    // arrays (O(n), O(1) access) for its hot loops instead. See GraphView2D.qml.
    Q_PROPERTY(QString nodesJson READ nodesJson NOTIFY graphChanged)
    Q_PROPERTY(QString edgesJson READ edgesJson NOTIFY graphChanged)
    Q_PROPERTY(int nodeCount READ nodeCount NOTIFY graphChanged)         // stable Repeater model
    Q_PROPERTY(int edgeCount READ edgeCount NOTIFY graphChanged)
    Q_PROPERTY(QVariantList edges READ edges NOTIFY graphChanged)        // [{from,to,weight}]
    Q_PROPERTY(bool directed READ directed WRITE setDirected NOTIFY graphChanged)
    Q_PROPERTY(QStringList algorithms READ algorithms CONSTANT)
    Q_PROPERTY(bool canUndo READ canUndo NOTIFY historyChanged)
    Q_PROPERTY(bool canRedo READ canRedo NOTIFY historyChanged)
    Q_PROPERTY(bool loading READ loading NOTIFY loadingChanged)          // async file load in flight
    // Opaque view/UI configuration (a JSON object string) that QML owns (2D/3D
    // toggles, style, colours). The controller just carries it through save/load
    // so a saved document and the restored session keep the user's view settings.
    Q_PROPERTY(QString viewConfig READ viewConfig WRITE setViewConfig NOTIFY viewConfigChanged)

    // --- run / playback ---
    Q_PROPERTY(bool hasRun READ hasRun NOTIFY timelineChanged)
    Q_PROPERTY(int stepCount READ stepCount NOTIFY timelineChanged)
    Q_PROPERTY(double runMs READ runMs NOTIFY timelineChanged)           // wall-clock time of the last run
    Q_PROPERTY(int cursor READ cursor NOTIFY cursorChanged)
    Q_PROPERTY(QString stepNote READ stepNote NOTIFY cursorChanged)

    // --- current visual snapshot (at `cursor`) ---
    Q_PROPERTY(QVariantList vertexStates READ vertexStates NOTIFY cursorChanged)  // int per vertex
    Q_PROPERTY(QVariantList vertexDists READ vertexDists NOTIFY cursorChanged)    // string per vertex
    Q_PROPERTY(QVariantList treeEdges READ treeEdges NOTIFY cursorChanged)        // [{from,to}]
    Q_PROPERTY(int activeFrom READ activeFrom NOTIFY cursorChanged)
    Q_PROPERTY(int activeTo READ activeTo NOTIFY cursorChanged)

    // --- highlighted source→target path (after a completed run) ---
    Q_PROPERTY(int runSource READ runSource NOTIFY timelineChanged)
    Q_PROPERTY(int pathTarget READ pathTarget NOTIFY pathChanged)
    Q_PROPERTY(bool hasPath READ hasPath NOTIFY pathChanged)
    Q_PROPERTY(QVariantList pathEdges READ pathEdges NOTIFY pathChanged)          // [{from,to}]
    Q_PROPERTY(QString pathSummary READ pathSummary NOTIFY pathChanged)

public:
    explicit VisualizerController(QObject* parent = nullptr);

    QString appVersion() const;   // GA_APP_VERSION from the generated version.h

    // Vertex playback states (indices into the Theme state colours).
    enum State { Idle = 0, Frontier = 1, Current = 2, Settled = 3 };

    QVariantList nodes() const;
    QString nodesJson() const;
    QString edgesJson() const;
    int nodeCount() const { return static_cast<int>(m_nodes.size()); }
    int edgeCount() const { return static_cast<int>(m_edges.size()); }
    QVariantList edges() const;
    bool loading() const { return m_loading; }
    QString viewConfig() const { return m_viewConfig; }
    void setViewConfig(const QString& v);
    bool directed() const { return m_directed; }
    void setDirected(bool d);
    QStringList algorithms() const {
        return {QStringLiteral("BFS"), QStringLiteral("DFS"),
                QStringLiteral("Dijkstra"), QStringLiteral("Bellman-Ford"),
                QStringLiteral("Kruskal"), QStringLiteral("Prim")};
    }

    bool hasRun() const { return !m_snaps.empty(); }
    int stepCount() const { return static_cast<int>(m_snaps.size()); }
    double runMs() const { return m_runMs; }
    int cursor() const { return m_cursor; }
    QString stepNote() const;
    QVariantList vertexStates() const;
    QVariantList vertexDists() const;
    QVariantList treeEdges() const;
    // Per-edge highlight state in m_edges order (0 normal, 1 tree, 2 active, 3
    // path). A method (not a property): the dense edge layer snapshots it once
    // per step into a plain QML list the delegates read by index — far cheaper
    // than each delegate scanning the tree/path lists, and avoids the repeated
    // getter invocations a QVariantList property read provokes from QML.
    Q_INVOKABLE QVariantList edgeStates() const;
    int activeFrom() const;
    int activeTo() const;

    int runSource() const { return m_runSrc; }
    int pathTarget() const { return m_pathTarget; }
    bool hasPath() const { return m_pathTarget >= 0; }
    QVariantList pathEdges() const;
    QString pathSummary() const { return m_pathSummary; }

    // Highlight the source→target path through the completed run's tree. Walks
    // the final snapshot's parent chain; a no-op (clears) if there's no run.
    Q_INVOKABLE void highlightPathTo(int target);
    Q_INVOKABLE void clearPath();

    // --- build (minimal interactivity for the MVP) ---
    Q_INVOKABLE int addVertex(qreal x, qreal y, const QString& label = QString());
    Q_INVOKABLE void addVertices(int count);        // add N blank vertices at once
    Q_INVOKABLE void addEdge(int u, int v, double w = 1.0);
    Q_INVOKABLE void setEdgeWeight(int from, int to, double w);
    Q_INVOKABLE void removeEdge(int from, int to);
    Q_INVOKABLE void removeVertex(int id);          // + its incident edges (reindexes)
    Q_INVOKABLE void moveVertex(int id, qreal x, qreal y);
    Q_INVOKABLE void renameVertex(int id, const QString& label);
    Q_INVOKABLE void relayout();                    // force-directed auto-arrange
    Q_INVOKABLE void layoutCircular();              // vertices evenly on a circle
    // Stretch the current layout so its bounding box fills a w×h region (minus
    // margin), adapting to the region's aspect ratio. Used by "Fill canvas".
    Q_INVOKABLE void layoutToRegion(double w, double h, double margin);
    Q_INVOKABLE void clear();
    Q_INVOKABLE void loadSample();

    // --- bulk input, sample library, and save/load ---
    Q_INVOKABLE void loadEdgeList(const QString& text, bool directed, bool replace);
    Q_INVOKABLE QStringList sampleNames() const;
    Q_INVOKABLE void loadNamedSample(const QString& name);
    Q_INVOKABLE QString toJson() const;
    Q_INVOKABLE bool loadJson(const QString& text);
    Q_INVOKABLE bool saveToFile(const QUrl& url) const;
    Q_INVOKABLE bool loadFromFile(const QUrl& url);
    // Read + parse the file on a worker thread (so a large file doesn't freeze
    // the UI), then apply the result on the GUI thread. `loading` is true while
    // in flight; loadingChanged fires at start and completion.
    Q_INVOKABLE void loadFromFileAsync(const QUrl& url);

    // --- algorithm + playback ---
    Q_INVOKABLE void run(const QString& algo, int src);
    Q_INVOKABLE void seek(int c);
    Q_INVOKABLE void stepForward();
    Q_INVOKABLE void stepBack();

    // --- undo / redo ---
    bool canUndo() const { return !m_undo.empty(); }
    bool canRedo() const { return !m_redo.empty(); }
    Q_INVOKABLE void undo();
    Q_INVOKABLE void redo();
    Q_INVOKABLE void beginEdit();        // snapshot once for a coalesced edit (e.g. a drag)

signals:
    void graphChanged();
    void timelineChanged();
    void cursorChanged();
    void historyChanged();
    void pathChanged();
    void loadingChanged();
    void viewConfigChanged();

private:
    struct Node { QString label; qreal x, y; };
    struct Edge { int from, to; double w; };
    struct GraphState { std::vector<Node> nodes; std::vector<Edge> edges; bool directed; };
    // Result of parsing a document (off-thread for the async loader).
    struct ParsedDoc { bool ok = false; std::vector<Node> nodes; std::vector<Edge> edges; bool directed = false; QString view; };
    struct Snap {
        std::vector<int> vstate;
        std::vector<double> dist;             // NaN = no distance shown
        std::vector<ga::vertex> parent;       // for the result-tree edges
        // Explicitly accumulated tree edges (from tree_edge events). MST (Kruskal)
        // accepts a FOREST that a single parent[] array can't always represent
        // (it merges two interior components), so the tree render unions this list
        // with the parent-derived tree. Empty for the parent-only algorithms.
        std::vector<std::pair<int, int>> treeAccum;
        int au = -1, av = -1;                 // active edge this step
        QString note;
    };

    // `directed` lets the caller force an undirected graph (MST is undefined on a
    // digraph, so Kruskal/Prim always build undirected regardless of m_directed).
    ga::graph<double> buildGraph(bool directed) const;
    void resetRun();
    void fdIterate(int pinned, double temp);        // one force-directed pass
    bool labelInUse(const QString& label, int exceptId) const;
    QString makeUniqueLabel(const QString& desired, int exceptId = -1) const;
    void pushUndo();                                // snapshot current state (call before a mutation)
    static ParsedDoc parseDoc(const QByteArray& bytes);   // pure parse (thread-safe)
    void applyDoc(ParsedDoc doc);                   // install a parsed doc (GUI thread)
    void finishAsyncLoad(ParsedDoc doc);            // apply + clear `loading` (GUI thread)

    std::vector<GraphState> m_undo, m_redo;
    bool m_suppressUndo = false;        // guard so nested mutations snapshot once
    std::vector<Node> m_nodes;
    std::vector<Edge> m_edges;
    bool m_directed = false;
    QString m_viewConfig;               // opaque JSON view/UI config carried through save/load
    std::vector<Snap> m_snaps;
    int m_cursor = 0;
    double m_runMs = 0;           // wall-clock ms of the last run's computation
    bool m_loading = false;

    // Run context + highlighted path (source→target through the result tree).
    int m_runSrc = -1;
    QString m_runAlgo;
    int m_pathTarget = -1;
    std::vector<QPair<int, int>> m_pathEdges;   // parent→child pairs on the path
    QString m_pathSummary;
};

}  // namespace ga::studio
