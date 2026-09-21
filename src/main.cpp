/*
    SPDX-FileCopyrightText: 2024 Aleix Pol i Gonzalez <aleixpol@kde.org>
    SPDX-FileCopyrightText: 2025 Kristen McWilliam <kristen@kde.org>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "config-plasma-keyboard.h"
#include "inputpanelintegration.h"
#include "layoutpathhelper.h"
#include "logging.h"
#include "plasmakeyboardsettings.h"
#include <plasma_keyboard_version.h>

#include <KAboutData>
#include <KConfigWatcher>
#include <KCrash>
#include <KLocalizedQmlContext>
#include <KLocalizedString>

#include <QCommandLineParser>
#include <QDir>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QTimer>
#include <QWindow>
#include <qpa/qwindowsysteminterface.h>

int main(int argc, char **argv)
{
    qputenv("QT_IM_MODULE", QByteArray("qtvirtualkeyboard"));

    initLayoutsPath();

    QGuiApplication application(argc, argv);
    const bool baselineMode = qEnvironmentVariable("SHUFFLE_KEYBOARD_LAYOUT") == QLatin1String("ipad");

    KLocalizedString::setApplicationDomain("plasma-keyboard");

    KAboutData aboutData(baselineMode ? QStringLiteral("shuffle-ipad-baseline") : QStringLiteral("shuffle-keyboard"),
                         baselineMode ? i18n("iPad Layout Baseline") : i18n("Shuffle Keyboard"),
                         QStringLiteral(PLASMA_KEYBOARD_VERSION_STRING),
                         baselineMode ? i18n("Four-row iPad keyboard geometry baseline for Plasma") : i18n("Touch keyboard and precision surface for Plasma"),
                         KAboutLicense::GPL,
                         i18n("Copyright 2024 Plasma Keyboard contributors; 2026 Shuffle Project"));

    aboutData.addAuthor(i18n("Aleix Pol Gonzalez"), i18n("Author"), QStringLiteral("aleixpol@kde.org"));
    aboutData.setOrganizationDomain("kde.org");
    aboutData.setDesktopFileName(baselineMode ? QStringLiteral("org.shuffle.IPadBaseline") : QStringLiteral("org.shuffle.Keyboard"));
    application.setWindowIcon(QIcon::fromTheme(QStringLiteral("input-keyboard-virtual")));
    aboutData.setProgramLogo(application.windowIcon());

    KAboutData::setApplicationData(aboutData);

    KCrash::initialize();

    {
        QCommandLineParser parser;
        aboutData.setupCommandLine(&parser);
        parser.process(application);
        aboutData.processCommandLine(&parser);
    }

    if (!PLASMA_KEYBOARD_SOUND_ENABLED) {
        PlasmaKeyboardSettings::self()->setSoundEnabled(false);
    }

    if (!PLASMA_KEYBOARD_VIBRATION_ENABLED) {
        PlasmaKeyboardSettings::self()->setVibrationEnabled(false);
    }

    // Listen to config updates from kcm, and reparse
    auto watcher = KConfigWatcher::create(PlasmaKeyboardSettings::self()->sharedConfig());
    // clang-format off
    QObject::connect(watcher.get(),
        &KConfigWatcher::configChanged,
        &application,
        [](const KConfigGroup &, const QByteArrayList &) {
            PlasmaKeyboardSettings::self()->sharedConfig()->reparseConfiguration();
            PlasmaKeyboardSettings::self()->load();
        });
    // clang-format on

    QQmlApplicationEngine view;
    KLocalization::setupLocalizedContext(&view);
    const bool previewMode = qEnvironmentVariableIntValue("SHUFFLE_PREVIEW_MODE") != 0;
    const QString previewScreenshot = qEnvironmentVariable("SHUFFLE_PREVIEW_SCREENSHOT");
    // The probe is inert unless explicitly enabled in an isolated test
    // session. It exercises the same Qt Virtual Keyboard delivery call used
    // by touch keys without requiring synthetic pointer input.
    view.rootContext()->setContextProperty(QStringLiteral("shuffleProbeText"), qEnvironmentVariable("SHUFFLE_PROBE_TEXT"));
    view.rootContext()->setContextProperty(QStringLiteral("shuffleProbeInterval"), qEnvironmentVariableIntValue("SHUFFLE_PROBE_INTERVAL"));
    view.rootContext()->setContextProperty(QStringLiteral("shuffleProbeRepeat"), qEnvironmentVariableIntValue("SHUFFLE_PROBE_REPEAT"));
    view.rootContext()->setContextProperty(QStringLiteral("shuffleProbeDelay"), qEnvironmentVariableIntValue("SHUFFLE_PROBE_DELAY"));
    view.rootContext()->setContextProperty(QStringLiteral("shuffleProbeShortcuts"), qEnvironmentVariableIntValue("SHUFFLE_PROBE_SHORTCUTS") != 0);
    view.rootContext()->setContextProperty(QStringLiteral("shufflePreviewMode"), previewMode);
    view.rootContext()->setContextProperty(QStringLiteral("shuffleProbeHeight"), qEnvironmentVariableIntValue("SHUFFLE_PROBE_HEIGHT"));
    view.rootContext()->setContextProperty(QStringLiteral("shuffleProbePrecision"), qEnvironmentVariableIntValue("SHUFFLE_PROBE_PRECISION"));
    view.rootContext()->setContextProperty(QStringLiteral("shuffleProbeDismiss"), qEnvironmentVariableIntValue("SHUFFLE_PROBE_DISMISS") != 0);
    view.rootContext()->setContextProperty(QStringLiteral("shuffleProbeLayer"), qEnvironmentVariableIntValue("SHUFFLE_PROBE_LAYER"));

    QObject::connect(&view, &QQmlApplicationEngine::objectCreated, &application, [previewMode, previewScreenshot](QObject *object) {
        auto window = qobject_cast<QQuickWindow *>(object);
        if (!window) {
            qCCritical(PlasmaKeyboard) << "Shuffle Keyboard failed to create its input-panel window.";
            QCoreApplication::exit(1);
            return;
        }
        const bool initSuccessful = previewMode || initInputPanelIntegration(window, InputPanelRole::Keyboard);

        if (!initSuccessful) {
            qCCritical(PlasmaKeyboard) << "Cannot run Shuffle Keyboard standalone. Enable it on Plasma's Virtual Keyboard settings page.";
            exit(1);
        }

        window->requestActivate();
        window->setVisible(true);

        if (previewMode && !previewScreenshot.isEmpty()) {
            QTimer::singleShot(500, window, [window, previewScreenshot] {
                window->grabWindow().save(previewScreenshot);
                QCoreApplication::quit();
            });
        }
    });
    view.load(QUrl(baselineMode ? QStringLiteral("qrc:/qt/qml/org/kde/plasma/keyboard/IPadBaseline.qml")
                                : QStringLiteral("qrc:/qt/qml/org/kde/plasma/keyboard/main.qml")));

    if (view.rootObjects().isEmpty()) {
        return 1;
    }

    qCDebug(PlasmaKeyboard) << (baselineMode ? "Starting iPad Layout Baseline" : "Starting Shuffle Keyboard");

    return application.exec();
}
