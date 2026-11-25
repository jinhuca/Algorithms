#include <QApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

// Numerics Algorithm Studio (skeleton) — standalone entry point. The Algorithms umbrella
// app hosts the same NumericsRoot content in its own window.
int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("numerics_algo"));
    QCoreApplication::setApplicationName(QStringLiteral("numerics_algo"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0"));
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/NumericsStudio/nu_logo.svg")));
    QQuickStyle::setStyle(QStringLiteral("Fusion"));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        [] { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("NumericsStudio", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;
    return app.exec();
}
