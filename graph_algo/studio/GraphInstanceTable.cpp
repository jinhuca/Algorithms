#include "GraphInstanceTable.h"

#include <QColor>
#include <QQuaternion>
#include <QVector3D>

void GraphInstanceTable::setEntries(const QList<double>& flat) {
    constexpr int stride = 14;   // px,py,pz, sx,sy,sz, qw,qx,qy,qz, r,g,b,a
    const int n = flat.size() / stride;
    m_buffer.clear();
    m_buffer.reserve(n * static_cast<int>(sizeof(InstanceTableEntry)));
    const double* e = flat.constData();
    for (int i = 0; i < n; ++i, e += stride) {
        const QVector3D pos(static_cast<float>(e[0]), static_cast<float>(e[1]), static_cast<float>(e[2]));
        const QVector3D scale(static_cast<float>(e[3]), static_cast<float>(e[4]), static_cast<float>(e[5]));
        const QQuaternion quat(static_cast<float>(e[6]), static_cast<float>(e[7]),
                               static_cast<float>(e[8]), static_cast<float>(e[9]));   // (w, x, y, z)
        const QColor color = QColor::fromRgbF(static_cast<float>(e[10]), static_cast<float>(e[11]),
                                              static_cast<float>(e[12]), static_cast<float>(e[13]));
        const InstanceTableEntry entry =
            calculateTableEntryFromQuaternion(pos, scale, quat, color);
        m_buffer.append(reinterpret_cast<const char*>(&entry), sizeof(entry));
    }
    m_count = n;
    markDirty();
}

QByteArray GraphInstanceTable::getInstanceBuffer(int* instanceCount) {
    if (instanceCount)
        *instanceCount = m_count;
    return m_buffer;
}
