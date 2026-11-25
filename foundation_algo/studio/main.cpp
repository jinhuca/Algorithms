#include <QApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

// Foundation Algorithm Studio (skeleton) — standalone entry point. The Algorithms umbrella
// app hosts the same FoundationRoot content in its own window.
int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("foundation_algo"));
    QCoreApplication::setApplicationName(QStringLiteral("foundation_algo"));
    QCoreApplication::setApplicationVersion(QStringLiteral("0.1.0"));
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/FoundationStudio/fo_logo.svg")));
    QQuickStyle::setStyle(QStringLiteral("Fusion"));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        [] { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("FoundationStudio", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;
    return app.exec();
}
