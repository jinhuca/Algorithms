#pragma once

#include <QByteArray>
#include <QList>
#include <QtQmlIntegration>
#include <QtQuick3D/QQuick3DInstancing>

// GPU instance table fed from QML: one draw call renders N spheres / cylinders /
// cones, so the 3D view scales to large graphs without a Model (delegate) per
// node/edge. QML computes a flat float array (14 per instance) and hands it over;
// adding/removing/clearing is just a cheap buffer rebuild — no delegate churn.
class GraphInstanceTable : public QQuick3DInstancing {
    Q_OBJECT
    QML_ELEMENT
public:
    explicit GraphInstanceTable(QQuick3DObject* parent = nullptr) : QQuick3DInstancing(parent) {}

    // flat layout per instance (14 numbers):
    //   px,py,pz · sx,sy,sz · qw,qx,qy,qz · r,g,b,a
    // QList<double> (= QList<qreal>) is a QML-registered sequence, so a plain JS
    // number array marshals across in one O(n) pass.
    Q_INVOKABLE void setEntries(const QList<double>& flat);

    QByteArray getInstanceBuffer(int* instanceCount) override;

private:
    QByteArray m_buffer;
    int m_count = 0;
};
