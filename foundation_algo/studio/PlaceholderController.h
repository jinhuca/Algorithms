#pragma once

#include <QObject>
#include <QString>
#include <QtQmlIntegration>

#include <fo/placeholder.hpp>

namespace fo::studio {

// Minimal placeholder controller for the Foundation studio skeleton — exposes the studio
// name from fo::core so the QML can show the core is wired in.
class PlaceholderController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString studioName READ studioName CONSTANT)
public:
    explicit PlaceholderController(QObject* parent = nullptr) : QObject(parent) {}
    QString studioName() const {
        return QString::fromUtf8(fo::studio_name.data(),
                                 static_cast<int>(fo::studio_name.size()));
    }
};

}  // namespace fo::studio
