#pragma once

#include <QObject>
#include <QString>
#include <QtQmlIntegration>

#include <tr/placeholder.hpp>

namespace tr::studio {

// Minimal placeholder controller for the Tree studio skeleton — exposes the studio
// name from tr::core so the QML can show the core is wired in.
class PlaceholderController : public QObject {
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(QString studioName READ studioName CONSTANT)
public:
    explicit PlaceholderController(QObject* parent = nullptr) : QObject(parent) {}
    QString studioName() const {
        return QString::fromUtf8(tr::studio_name.data(),
                                 static_cast<int>(tr::studio_name.size()));
    }
};

}  // namespace tr::studio
