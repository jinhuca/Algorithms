#include <QApplication>
#include <QIcon>
#include <QQmlApplicationEngine>
#include <QQuickStyle>

// Algorithms — the umbrella app. One process, one window: a home page of cards that
// navigate into the individual algorithm studios (Search / Sort / Graph, plus the
// upcoming Foundation / Combinatorics / Numerics), each studio's content hosted in
// the same window. All studios share one QQmlApplicationEngine, one theme, and the
// shared UiKit design system. See qml/Main.qml.
int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("Algorithms"));
    QCoreApplication::setApplicationName(QStringLiteral("Algorithms"));
    QCoreApplication::setApplicationVersion(QStringLiteral("1.0.0"));
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/Algorithms/Algorithm_Icon.svg")));
    QQuickStyle::setStyle(QStringLiteral("Fusion"));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        [] { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("Algorithms", "Main");
    if (engine.rootObjects().isEmpty())
        return -1;

    return app.exec();
}
