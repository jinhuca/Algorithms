#pragma once

#include <QObject>
#include <QString>
#include <QtQmlIntegration>

#include <cb/placeholder.hpp>

namespace cb::studio {

// Minimal placeholder controller for the Combinatorics studio skeleton — exposes the studio
// name from cb::core so the QML can show the core is wired in.
class PlaceholderController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString studioName READ studioName CONSTANT)
public:
    explicit PlaceholderController(QObject* parent = nullptr) : QObject(parent) {}
    QString studioName() const {
        return QString::fromUtf8(cb::studio_name.data(),
                                 static_cast<int>(cb::studio_name.size()));
    }
};

}  // namespace cb::studio
