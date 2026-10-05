/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "bottomsurfacecoordinator.h"
#include "keysrequest.h"
#include "keystrayentry.h"

#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusInterface>
#include <QDBusMessage>
#include <QDBusReply>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QTimer>

namespace
{
// The Bottom Surface, when one is installed. Discovered at run time and never
// required: with the name unowned this component behaves exactly as it did
// before the surface existed.
constexpr auto kSurfaceService = "studio.warbler.BottomSurface";
constexpr auto kSurfacePath = "/BottomSurface";
constexpr auto kSurfaceInterface = "studio.warbler.BottomSurface";
// KWin stops the keyboard with SIGTERM and then waits for it to exit, up to
// 30 seconds, without serving anything else. A surface or shell that needs
// the compositor to answer cannot answer until the keyboard is gone, so on the
// way out the region is handed back without waiting long for a reply. The
// request still arrives and is acted on once the compositor moves again.
constexpr int kLeavingTimeoutMs = 1000;
constexpr int kSupportedMajor = 1;
}

BottomSurfaceCoordinator::BottomSurfaceCoordinator(QObject *parent)
    : QObject(parent)
{
    QDBusConnection::sessionBus().connect(QStringLiteral("org.kde.KWin"),
                                          QStringLiteral("/VirtualKeyboard"),
                                          QStringLiteral("org.kde.kwin.VirtualKeyboard"),
                                          QStringLiteral("visibleChanged"),
                                          this,
                                          SLOT(syncKeyboardVisibility()));
    QDBusConnection::sessionBus().connect(QString::fromLatin1(kSurfaceService),
                                          QString::fromLatin1(kSurfacePath),
                                          QString::fromLatin1(kSurfaceInterface),
                                          QStringLiteral("dockExtentChanged"),
                                          this,
                                          SLOT(onExtentChanged(QString)));
    m_trayEntry = new KeysTrayEntry(this);
    connect(m_trayEntry, &KeysTrayEntry::activated, this, &BottomSurfaceCoordinator::toggleKeysFromTray);
    QTimer::singleShot(0, this, &BottomSurfaceCoordinator::syncKeyboardVisibility);
    QTimer::singleShot(0, this, &BottomSurfaceCoordinator::readExtent);
    // A display coming or going can move the dock. The surface answers a
    // moment after the output changes, so it is read again then.
    const auto rereadSoon = [this] {
        QTimer::singleShot(500, this, &BottomSurfaceCoordinator::readExtent);
    };
    connect(qGuiApp, &QGuiApplication::screenAdded, this, rereadSoon);
    connect(qGuiApp, &QGuiApplication::screenRemoved, this, rereadSoon);
}

bool BottomSurfaceCoordinator::surfacePresent() const
{
    return m_surfacePresent;
}

int BottomSurfaceCoordinator::bandHeight() const
{
    return m_bandHeight;
}

int BottomSurfaceCoordinator::dockLeft() const
{
    return m_dockLeft;
}

int BottomSurfaceCoordinator::dockWidth() const
{
    return m_dockWidth;
}

void BottomSurfaceCoordinator::onExtentChanged(const QString &outputName)
{
    Q_UNUSED(outputName)
    readExtent();
}

void BottomSurfaceCoordinator::readExtent()
{
    const bool present = QDBusConnection::sessionBus().interface()
        && QDBusConnection::sessionBus().interface()->isServiceRegistered(QString::fromLatin1(kSurfaceService)).value();

    int bandHeight = 0;
    int dockLeft = 0;
    int dockWidth = 0;
    bool reserving = true;
    bool usable = false;

    if (present) {
        QDBusInterface surface(QString::fromLatin1(kSurfaceService),
                               QString::fromLatin1(kSurfacePath),
                               QString::fromLatin1(kSurfaceInterface),
                               QDBusConnection::sessionBus());
        const QDBusReply<QString> reply = surface.call(QStringLiteral("dockExtent"), QString());
        if (reply.isValid()) {
            const QJsonObject payload = QJsonDocument::fromJson(reply.value().toUtf8()).object();
            // An unknown major version is refused rather than guessed at.
            if (payload.value(QStringLiteral("version")).toInt() == kSupportedMajor) {
                usable = payload.value(QStringLiteral("presenting")).toBool();
                bandHeight = payload.value(QStringLiteral("band")).toObject().value(QStringLiteral("height")).toInt();
                const QJsonObject dock = payload.value(QStringLiteral("dock")).toObject();
                dockLeft = dock.value(QStringLiteral("left")).toInt();
                dockWidth = dock.value(QStringLiteral("right")).toInt() - dockLeft;
                reserving = payload.value(QStringLiteral("reserving")).toBool(true);
            }
        }
    }

    // The compositor seats this window on the bottom of the work area and does
    // not move it when the work area grows. The surface gives its reservation
    // up only after its presentation has left, well after this window was
    // seated, so the moment it says the reservation has gone is the moment to
    // be placed again. Asking any earlier seats it on a band that is leaving.
    if (m_regionReserving != reserving) {
        m_regionReserving = reserving;
        Q_EMIT reservationRefreshRequested();
        Q_EMIT regionReservingChanged();
    }

    if (m_surfacePresent == usable && m_bandHeight == bandHeight && m_dockLeft == dockLeft && m_dockWidth == dockWidth) {
        return;
    }
    m_surfacePresent = usable;
    m_bandHeight = bandHeight;
    m_dockLeft = dockLeft;
    m_dockWidth = dockWidth;
    Q_EMIT extentChanged();
}

bool BottomSurfaceCoordinator::askSurface(bool yield)
{
    if (!QDBusConnection::sessionBus().interface()
        || !QDBusConnection::sessionBus().interface()->isServiceRegistered(QString::fromLatin1(kSurfaceService)).value()) {
        return false;
    }

    const QDBusMessage message = QDBusMessage::createMethodCall(QString::fromLatin1(kSurfaceService),
                                                                QString::fromLatin1(kSurfacePath),
                                                                QString::fromLatin1(kSurfaceInterface),
                                                                yield ? QStringLiteral("yieldRegion") : QStringLiteral("releaseRegion"));
    if (!yield && !m_leaving) {
        // Nothing waits on the hand-back, and it must not wait itself: a
        // compositor that is shutting down hides the keys and then waits on
        // the Keyboard, and a surface behind that compositor cannot reply.
        QDBusConnection::sessionBus().send(message);
        return true;
    }
    const QDBusMessage reply = QDBusConnection::sessionBus().call(message, QDBus::Block, m_leaving ? kLeavingTimeoutMs : -1);
    return reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty() && reply.arguments().constFirst().toBool();
}

void BottomSurfaceCoordinator::syncKeyboardVisibility()
{
    QDBusInterface keyboard(QStringLiteral("org.kde.KWin"),
                            QStringLiteral("/VirtualKeyboard"),
                            QStringLiteral("org.kde.kwin.VirtualKeyboard"),
                            QDBusConnection::sessionBus());
    const bool visible = keyboard.isValid() && keyboard.property("visible").toBool();
    setKeyboardVisible(visible);
    // A compositor offering no keyboard interface cannot say, so the keys
    // take themselves as shown.
    Q_EMIT compositorVisibilityChecked(visible || !keyboard.isValid());
}

BottomSurfaceCoordinator::~BottomSurfaceCoordinator()
{
    m_leaving = true;
    restoreBottomPanels();
}

bool BottomSurfaceCoordinator::keyboardVisible() const
{
    return m_keyboardVisible;
}

bool BottomSurfaceCoordinator::requestedVisible() const
{
    return m_requestedVisible;
}

void BottomSurfaceCoordinator::setRequestedVisible(bool visible)
{
    if (m_requestedVisible == visible) {
        return;
    }
    m_requestedVisible = visible;
    Q_EMIT requestedVisibleChanged();
}

void BottomSurfaceCoordinator::raiseKeyboard()
{
    QDBusInterface keyboard(QStringLiteral("org.kde.KWin"),
                            QStringLiteral("/VirtualKeyboard"),
                            QStringLiteral("org.kde.kwin.VirtualKeyboard"),
                            QDBusConnection::sessionBus());
    if (!keyboard.isValid()) {
        setError(QStringLiteral("The compositor is not offering a virtual keyboard"));
        return;
    }
    requestKeys(this);
    setError({});
}

void BottomSurfaceCoordinator::toggleKeysFromTray()
{
    if (m_keyboardVisible) {
        Q_EMIT putAwayRequested();
        return;
    }
    raiseKeyboard();
    Q_EMIT keysRequested();
}

void BottomSurfaceCoordinator::announceHeading(double height, int durationMs)
{
    announceKeys(height, durationMs);
}

void BottomSurfaceCoordinator::reclaimKeyboardFocus()
{
    Q_EMIT keyboardFocusReclaimRequested();
}

bool BottomSurfaceCoordinator::regionReserving() const
{
    return m_regionReserving;
}

void BottomSurfaceCoordinator::setKeyboardVisible(bool visible)
{
    if (m_keyboardVisible == visible) {
        return;
    }
    m_keyboardVisible = visible;
    Q_EMIT keyboardVisibleChanged();

    // The region follows the keys on screen and nothing else. A request for
    // keys is only a promise: the compositor can decline it, and does for a
    // field an application focused on its own, so the dock that stepped aside
    // for the promise fell out and came back with no keys ever shown. The
    // arrival motion is what hides the moment between keys and dock.
    if (visible) {
        yieldBottomPanels();
    } else {
        restoreBottomPanels();
    }
}

QString BottomSurfaceCoordinator::error() const
{
    return m_error;
}

QString BottomSurfaceCoordinator::evaluate(const QString &script)
{
    QDBusInterface shell(QStringLiteral("org.kde.plasmashell"),
                         QStringLiteral("/PlasmaShell"),
                         QStringLiteral("org.kde.PlasmaShell"),
                         QDBusConnection::sessionBus());
    if (!shell.isValid()) {
        setError(QStringLiteral("Plasma Shell is not available"));
        return {};
    }

    const QDBusReply<QString> reply = shell.call(QStringLiteral("evaluateScript"), script);
    if (!reply.isValid()) {
        setError(reply.error().message());
        return {};
    }
    setError({});
    return reply.value();
}

void BottomSurfaceCoordinator::yieldBottomPanels()
{
    // Ask the surface that owns the region before touching anything. Two
    // things independently commanding one panel is how a panel is left in the
    // wrong state, and the surface knows what giving up the region means ---
    // this component does not and should not.
    if (m_surfaceYielded) {
        return;
    }
    if (askSurface(true)) {
        m_surfaceYielded = true;
        Q_EMIT reservationRefreshRequested();
        return;
    }

    if (!m_savedPanels.isEmpty()) {
        return;
    }

    const QString script = QStringLiteral(R"JS(
        const saved = [];
        panels().forEach(panel => {
            if (panel.location === "bottom") {
                saved.push({ id: panel.id, hiding: panel.hiding });
                panel.hiding = "autohide";
            }
        });
        print(JSON.stringify(saved));
    )JS");
    m_savedPanels = evaluate(script);
    Q_EMIT reservationRefreshRequested();
}

void BottomSurfaceCoordinator::restoreBottomPanels()
{
    // Given back the same way it was taken.
    if (m_surfaceYielded) {
        askSurface(false);
        m_surfaceYielded = false;
        Q_EMIT reservationRefreshRequested();
        return;
    }

    if (m_savedPanels.isEmpty()) {
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(m_savedPanels.toUtf8(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isArray()) {
        setError(QStringLiteral("Could not restore bottom panel state"));
        m_savedPanels.clear();
        return;
    }

    const QString serialized = QString::fromUtf8(document.toJson(QJsonDocument::Compact));
    const QString script = QStringLiteral(R"JS(
        const saved = %1;
        saved.forEach(entry => {
            const panel = panelById(entry.id);
            if (panel && panel.location === "bottom" && panel.hiding === "autohide") {
                panel.hiding = entry.hiding;
            }
        });
    )JS")
                               .arg(serialized);
    // As with the surface: the shell may be waiting on the compositor.
    QDBusMessage message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.plasmashell"),
                                                          QStringLiteral("/PlasmaShell"),
                                                          QStringLiteral("org.kde.PlasmaShell"),
                                                          QStringLiteral("evaluateScript"));
    message.setArguments({script});
    if (m_leaving) {
        QDBusConnection::sessionBus().call(message, QDBus::Block, kLeavingTimeoutMs);
    } else {
        QDBusConnection::sessionBus().send(message);
    }
    m_savedPanels.clear();
}

void BottomSurfaceCoordinator::setError(const QString &error)
{
    if (m_error == error) {
        return;
    }
    m_error = error;
    Q_EMIT errorChanged();
}
