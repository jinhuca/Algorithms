#include <QApplication>
#include <QFont>
#include <QIcon>
#include <QPainter>
#include <QPixmap>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QScreen>
#include <QSettings>
#include <QSplashScreen>
#include <QTimer>

#include "version.h"   // GA_APP_VERSION — generated from version.h.in at configure time

// Build the splash image: a rounded brand-navy panel with the app logo, name,
// version and a "Starting…" line. Painted at the screen's device-pixel ratio so
// it stays crisp on HiDPI displays.
static QPixmap makeSplashPixmap(qreal dpr) {
    const int W = 460, H = 260;
    QPixmap pm(int(W * dpr), int(H * dpr));
    pm.setDevicePixelRatio(dpr);
    pm.fill(QColor("#132541"));                          // brand navy (dark theme surface)

    QPainter p(&pm);
    p.setRenderHint(QPainter::Antialiasing, true);
    p.setRenderHint(QPainter::SmoothPixmapTransform, true);
    p.setPen(QPen(QColor("#264066"), 1));
    p.drawRect(QRectF(0.5, 0.5, W - 1.0, H - 1.0));      // thin border

    QPixmap logo(QStringLiteral(":/qt/qml/GraphVis/ga_logo.png"));
    if (!logo.isNull()) {
        const int L = 84;
        QPixmap s = logo.scaled(int(L * dpr), int(L * dpr), Qt::KeepAspectRatio,
                                Qt::SmoothTransformation);
        s.setDevicePixelRatio(dpr);
        p.drawPixmap((W - L) / 2, 34, s);
    }

    p.setPen(QColor("#f8fafc"));
    QFont f = p.font();
    f.setPointSizeF(15);
    f.setBold(true);
    p.setFont(f);
    p.drawText(QRectF(0, 136, W, 28), Qt::AlignHCenter, QStringLiteral("Graph Algorithm Studio"));

    p.setPen(QColor("#94a3b8"));
    QFont fv = p.font();
    fv.setPointSizeF(10);
    fv.setBold(false);
    p.setFont(fv);
    p.drawText(QRectF(0, 168, W, 20), Qt::AlignHCenter,
               QStringLiteral("v") + QStringLiteral(GA_APP_VERSION));

    p.setPen(QColor("#64748b"));
    p.drawText(QRectF(0, H - 40, W, 20), Qt::AlignHCenter, QStringLiteral("Starting…"));

    p.end();
    return pm;
}

int main(int argc, char* argv[]) {
    // QApplication (not QGuiApplication) so we can use QSplashScreen from QtWidgets.
    QApplication app(argc, argv);
    QCoreApplication::setOrganizationName(QStringLiteral("graph_algo"));
    QCoreApplication::setApplicationName(QStringLiteral("graph_visualizer"));
    // Published so QML can show it (Qt.application.version) on the title bar.
    QCoreApplication::setApplicationVersion(QStringLiteral(GA_APP_VERSION));
    // Window / taskbar icon (the Windows .exe icon is embedded via appicon.rc).
    app.setWindowIcon(QIcon(QStringLiteral(":/qt/qml/GraphVis/ga_logo.png")));
    QQuickStyle::setStyle(QStringLiteral("Fusion"));

    // Splash — shown BEFORE the engine load + session restore, which run on and
    // block the GUI thread (a big last-session graph, or a slow machine, can take a
    // while). The OS keeps the splash on screen through that blocking work; we close
    // it when the main window presents its first frame, so there's no blank gap.
    // Place the splash on the monitor where the window will restore, so it never
    // appears on a different screen than the app. Use the saved window geometry's
    // CENTRE (not its top-left) to pick the screen — robust when the saved rect
    // straddles two monitors or sits near an edge. Defaults match Main.qml's window
    // defaults, so first run agrees too. If the saved spot is on no connected screen
    // (e.g. a monitor was unplugged), fall back to screens[0] — exactly where QML's
    // ensureOnScreen() rescues the window, so the two still land together.
    QSettings settings;
    const QRect savedRect(settings.value(QStringLiteral("winX"), 120).toInt(),
                          settings.value(QStringLiteral("winY"), 80).toInt(),
                          settings.value(QStringLiteral("winWidth"), 1680).toInt(),
                          settings.value(QStringLiteral("winHeight"), 900).toInt());
    QScreen* scr = QGuiApplication::screenAt(savedRect.center());
    if (!scr) {
        const QList<QScreen*> screens = app.screens();
        scr = screens.isEmpty() ? app.primaryScreen() : screens.constFirst();
    }
    const qreal dpr = scr ? scr->devicePixelRatio() : 1.0;

    QSplashScreen splash(makeSplashPixmap(dpr));
    if (scr)
        splash.move(scr->geometry().center().x() - splash.width() / 2,
                    scr->geometry().center().y() - splash.height() / 2);
    splash.show();
    splash.repaint();      // force the splash to paint before the (blocking) engine load
    app.processEvents();

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine, &QQmlApplicationEngine::objectCreationFailed, &app,
        [] { QCoreApplication::exit(-1); }, Qt::QueuedConnection);
    engine.loadFromModule("GraphVis", "Main");
    if (engine.rootObjects().isEmpty()) return -1;

    // Dismiss the splash on the main window's first rendered frame (no blank gap),
    // with a safety timeout in case that signal never arrives.
    if (auto* win = qobject_cast<QQuickWindow*>(engine.rootObjects().constFirst())) {
        QObject::connect(
            win, &QQuickWindow::frameSwapped, &splash,
            [&splash] { splash.close(); }, Qt::SingleShotConnection);
    } else {
        splash.close();
    }
    QTimer::singleShot(8000, &splash, [&splash] { splash.close(); });

    return app.exec();
}
