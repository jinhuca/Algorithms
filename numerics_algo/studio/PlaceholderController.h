#pragma once

#include <QObject>
#include <QString>
#include <QtQmlIntegration>

#include <nu/placeholder.hpp>

namespace nu::studio {

// Minimal placeholder controller for the Numerics studio skeleton — exposes the studio
// name from nu::core so the QML can show the core is wired in.
class PlaceholderController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString studioName READ studioName CONSTANT)
public:
    explicit PlaceholderController(QObject* parent = nullptr) : QObject(parent) {}
    QString studioName() const {
        return QString::fromUtf8(nu::studio_name.data(),
                                 static_cast<int>(nu::studio_name.size()));
    }
};

}  // namespace nu::studio
