#include <QGuiApplication>
#include <QtQuickControls2/QQuickStyle>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QTimer>
#include <QUrl>
#include <QQmlContext>
#include "MacWindowMetrics.h"

#ifdef Q_OS_MACOS
void configureMacWindow(QQuickWindow *window, MacWindowMetrics *metrics);
#endif

int main(int argc, char *argv[])
{
    // Project Glass custom sliders and translucent controls require a non-native style.
    QQuickStyle::setStyle("Basic");
    QGuiApplication app(argc, argv);
    MacWindowMetrics macWindowMetrics;
    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("macWindowMetrics", &macWindowMetrics);

    QObject::connect(&engine, &QQmlApplicationEngine::objectCreated,
                     &app, [&macWindowMetrics](QObject *object, const QUrl &) {
        auto *window = qobject_cast<QQuickWindow *>(object);
        if (!window)
            return;
#ifdef Q_OS_MACOS
        QTimer::singleShot(0, window, [window, &macWindowMetrics]() {
            configureMacWindow(window, &macWindowMetrics);
        });
#endif
    });

    // Isolated glass compositor lab. The normal launcher is unchanged.
    const bool glassLab = app.arguments().contains(QStringLiteral("--glass-lab"));
    engine.loadFromModule("ProjectGlass", glassLab ? "GlassLab" : "Main");
    return app.exec();
}
