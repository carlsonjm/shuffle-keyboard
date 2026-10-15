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
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTimer>

#include <algorithm>

namespace
{
// The Bottom Surface, when one is installed. Discovered at run time and never
// required: with the name unowned this component behaves exactly as it did
// before the surface existed.
constexpr auto kSurfaceService = "co.goodinput.BottomSurface";
constexpr auto kSurfacePath = "/BottomSurface";
constexpr auto kSurfaceInterface = "co.goodinput.BottomSurface";
// KWin stops the keyboard with SIGTERM and then waits for it to exit, up to
// 30 seconds, without serving anything else. A surface or shell that needs
// the compositor to answer cannot answer until the keyboard is gone, so on the
// way out the region is handed back without waiting long for a reply. The
// request still arrives and is acted on once the compositor moves again.
constexpr int kLeavingTimeoutMs = 1000;
// Every other ask of the surface or the shell is answered on the event loop,
// never waited on, so the keys keep typing however long the shell takes. The
// limit only decides when an unanswered ask is given up on.
constexpr int kAnswerTimeoutMs = 5000;
constexpr int kSupportedMajor = 1;

QDBusMessage surfaceCall(const QString &method)
{
    QDBusMessage message =
        QDBusMessage::createMethodCall(QString::fromLatin1(kSurfaceService), QString::fromLatin1(kSurfacePath), QString::fromLatin1(kSurfaceInterface), method);
    // A surface is running or it is not; asking never starts one.
    message.setAutoStartService(false);
    return message;
}

QDBusMessage shellScript(const QString &script)
{
    QDBusMessage message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.plasmashell"),
                                                          QStringLiteral("/PlasmaShell"),
                                                          QStringLiteral("org.kde.PlasmaShell"),
                                                          QStringLiteral("evaluateScript"));
    message.setArguments({script});
    return message;
}

/// Whether an error means nobody owns the surface's name, as opposed to a
/// surface that is there and did not answer in time or answered wrongly.
bool nobodyAnswers(const QDBusError &error)
{
    return error.name() == QLatin1String("org.freedesktop.DBus.Error.ServiceUnknown")
        || error.name() == QLatin1String("org.freedesktop.DBus.Error.NameHasNoOwner");
}

QJsonArray readPanelState()
{
    QFile file(BottomSurfaceCoordinator::panelStatePath());
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    return QJsonDocument::fromJson(file.readAll()).array();
}

bool writePanelState(const QJsonArray &saved)
{
    const QString path = BottomSurfaceCoordinator::panelStatePath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly)) {
        return false;
    }
    file.write(QJsonDocument(saved).toJson(QJsonDocument::Compact));
    return file.commit();
}
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
    // Panels a previous run set to autohide and did not put back, because it
    // crashed or was killed, go back first: the shell answers in order, so
    // this lands before anything this run asks of it.
    QTimer::singleShot(0, this, &BottomSurfaceCoordinator::restoreLastRunPanels);
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
    // Asked without waiting, like everything else asked of the shell. With no
    // surface on the bus the answer is an error, read as nothing presenting.
    QDBusMessage message = surfaceCall(QStringLiteral("dockExtent"));
    message.setArguments({QString()});
    const quint64 request = ++m_extentRequest;
    auto watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message, kAnswerTimeoutMs), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, request](QDBusPendingCallWatcher *call) {
        call->deleteLater();
        // Only the latest read counts; an earlier one answering late is older news.
        if (request != m_extentRequest) {
            return;
        }
        const QDBusPendingReply<QString> reply = *call;

        int bandHeight = 0;
        int dockLeft = 0;
        int dockWidth = 0;
        bool reserving = true;
        bool usable = false;

        if (!reply.isError()) {
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

        // The compositor seats this window on the bottom of the work area and
        // does not move it when the work area grows. The surface gives its
        // reservation up only after its presentation has left, well after
        // this window was seated, so the moment it says the reservation has
        // gone is the moment to be placed again. Asking any earlier seats it
        // on a band that is leaving.
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
    });
}

void BottomSurfaceCoordinator::askSurface()
{
    m_surfaceAsked = true;
    const quint64 request = ++m_surfaceRequest;
    auto watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(surfaceCall(QStringLiteral("yieldRegion")), kAnswerTimeoutMs), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, request](QDBusPendingCallWatcher *call) {
        call->deleteLater();
        // The keys went, and the region was handed back, before this answer.
        if (request != m_surfaceRequest) {
            return;
        }
        const QDBusPendingReply<bool> reply = *call;
        if (reply.isError() && nobodyAnswers(reply.error())) {
            // No Bottom Surface is installed: the panels are this
            // component's to move, as they always were.
            m_surfaceAsked = false;
            ++m_surfaceRequest;
            if (m_keyboardVisible) {
                yieldPanels();
            }
            return;
        }
        if (reply.isError() || !reply.value()) {
            // A surface that refuses, or does not answer in time, still owns
            // the region. Commanding its panel as well is the fight the
            // contract forbids, so the keys come up over the band as it is.
            // The hand-back still goes when the keys do, in case a late yes
            // arrives after this.
            const QString why = reply.isError() ? reply.error().message() : QStringLiteral("it is held by someone else");
            qWarning("The Bottom Surface did not yield the region: %s", qPrintable(why));
            setError(QStringLiteral("The Bottom Surface did not yield the region: %1").arg(why));
            return;
        }
        m_surfaceYielded = true;
        setError({});
        Q_EMIT reservationRefreshRequested();
    });
}

void BottomSurfaceCoordinator::releaseSurface()
{
    const bool wasYielded = m_surfaceYielded;
    m_surfaceAsked = false;
    m_surfaceYielded = false;
    ++m_surfaceRequest;
    const QDBusMessage message = surfaceCall(QStringLiteral("releaseRegion"));
    if (m_leaving) {
        // KWin is waiting on this process; the hand-back is waited on only
        // briefly, and arrives either way.
        QDBusConnection::sessionBus().call(message, QDBus::Block, kLeavingTimeoutMs);
    } else {
        // Nothing waits on the hand-back, and it must not wait itself: a
        // compositor that is shutting down hides the keys and then waits on
        // the Keyboard, and a surface behind that compositor cannot reply.
        QDBusConnection::sessionBus().send(message);
    }
    if (wasYielded) {
        Q_EMIT reservationRefreshRequested();
    }
}

void BottomSurfaceCoordinator::syncKeyboardVisibility()
{
    // Asked without waiting: KWin hides the keys as it begins to stop the
    // Keyboard, and then answers nothing until the Keyboard has gone.
    QDBusMessage message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"),
                                                          QStringLiteral("/VirtualKeyboard"),
                                                          QStringLiteral("org.freedesktop.DBus.Properties"),
                                                          QStringLiteral("Get"));
    message.setArguments({QStringLiteral("org.kde.kwin.VirtualKeyboard"), QStringLiteral("visible")});
    auto watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this](QDBusPendingCallWatcher *call) {
        call->deleteLater();
        const QDBusPendingReply<QDBusVariant> reply = *call;
        const bool offered = !reply.isError();
        const bool visible = offered && reply.value().variant().toBool();
        setKeyboardVisible(visible);
        // A compositor offering no keyboard interface cannot say, so the keys
        // take themselves as shown.
        Q_EMIT compositorVisibilityChecked(visible || !offered);
    });
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

QString BottomSurfaceCoordinator::panelStatePath()
{
    return QStandardPaths::writableLocation(QStandardPaths::StateLocation) + QStringLiteral("/bottom-panels.json");
}

void BottomSurfaceCoordinator::yieldBottomPanels()
{
    // Ask the surface that owns the region before touching anything. Two
    // things independently commanding one panel is how a panel is left in the
    // wrong state, and the surface knows what giving up the region means ---
    // this component does not and should not. Only once the bus says nobody
    // owns the surface's name does the Keyboard move a panel itself.
    if (m_surfaceAsked || m_panelState != PanelState::Untouched) {
        return;
    }
    askSurface();
}

void BottomSurfaceCoordinator::yieldPanels()
{
    m_panelState = PanelState::Reading;
    const quint64 request = ++m_panelRequest;
    // First only read: the modes are on disk before any panel changes, so a
    // Keyboard that ends without putting them back leaves them for the next.
    const QString read = QStringLiteral(R"JS(
        const saved = [];
        panels().forEach(panel => {
            if (panel.location === "bottom") {
                saved.push({ id: panel.id, hiding: panel.hiding });
            }
        });
        print(JSON.stringify(saved));
    )JS");
    auto watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(shellScript(read), kAnswerTimeoutMs), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, request](QDBusPendingCallWatcher *call) {
        call->deleteLater();
        // The keys went while the shell was answering; nothing was changed,
        // so nothing needs to go back.
        if (request != m_panelRequest) {
            return;
        }
        const QDBusPendingReply<QString> reply = *call;
        if (reply.isError()) {
            m_panelState = PanelState::Untouched;
            setError(reply.error().message());
            return;
        }
        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(reply.value().toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isArray()) {
            m_panelState = PanelState::Untouched;
            setError(QStringLiteral("Could not read bottom panel state"));
            return;
        }

        // A mode a previous run kept and never put back is the person's own;
        // what the shell says now may be that run's autohide.
        QJsonArray saved = readPanelState();
        QJsonArray ids;
        const QJsonArray current = document.array();
        for (const QJsonValue &entry : current) {
            const QJsonValue id = entry.toObject().value(QStringLiteral("id"));
            ids.append(id);
            const bool known = std::any_of(saved.cbegin(), saved.cend(), [&id](const QJsonValue &kept) {
                return kept.toObject().value(QStringLiteral("id")) == id;
            });
            if (!known) {
                saved.append(entry);
            }
        }
        m_savedPanels = saved;
        m_panelState = PanelState::Yielded;
        if (ids.isEmpty()) {
            return;
        }
        if (!writePanelState(saved)) {
            qWarning("Could not keep the bottom panels' hiding modes in %s", qPrintable(panelStatePath()));
        }

        const QString hide = QStringLiteral(R"JS(
            const ids = %1;
            ids.forEach(id => {
                const panel = panelById(id);
                if (panel && panel.location === "bottom") {
                    panel.hiding = "autohide";
                }
            });
        )JS")
                                 .arg(QString::fromUtf8(QJsonDocument(ids).toJson(QJsonDocument::Compact)));
        auto hidden = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(shellScript(hide), kAnswerTimeoutMs), this);
        connect(hidden, &QDBusPendingCallWatcher::finished, this, [this, request](QDBusPendingCallWatcher *call) {
            call->deleteLater();
            if (call->isError()) {
                setError(call->error().message());
                return;
            }
            setError({});
            if (request == m_panelRequest) {
                Q_EMIT reservationRefreshRequested();
            }
        });
    });
}

void BottomSurfaceCoordinator::restoreBottomPanels()
{
    // Given back the same way it was taken.
    if (m_surfaceAsked) {
        releaseSurface();
        return;
    }

    const PanelState state = m_panelState;
    m_panelState = PanelState::Untouched;
    ++m_panelRequest;
    if (state != PanelState::Yielded) {
        // Still reading, or never started: no panel has been changed.
        return;
    }
    const QJsonArray saved = m_savedPanels;
    m_savedPanels = {};
    if (!saved.isEmpty()) {
        restorePanels(saved, false);
    }
}

void BottomSurfaceCoordinator::restoreLastRunPanels()
{
    const QJsonArray saved = readPanelState();
    if (!saved.isEmpty()) {
        restorePanels(saved, true);
    } else if (QFile::exists(panelStatePath())) {
        QFile::remove(panelStatePath());
    }
}

void BottomSurfaceCoordinator::restoreLastRunPanelsOnceShellArrives()
{
    if (m_shellWatcher) {
        return;
    }
    m_shellWatcher =
        new QDBusServiceWatcher(QStringLiteral("org.kde.plasmashell"), QDBusConnection::sessionBus(), QDBusServiceWatcher::WatchForRegistration, this);
    connect(m_shellWatcher, &QDBusServiceWatcher::serviceRegistered, this, [this] {
        m_shellWatcher->deleteLater();
        m_shellWatcher = nullptr;
        restoreLastRunPanels();
    });
}

void BottomSurfaceCoordinator::restorePanels(const QJsonArray &saved, bool fromLastRun)
{
    const QString serialized = QString::fromUtf8(QJsonDocument(saved).toJson(QJsonDocument::Compact));
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
    const QDBusMessage message = shellScript(script);
    // The modes stay on disk until the shell has put the panels back, so a
    // restore that never lands is made again by the next start.
    if (m_leaving) {
        // As with the surface: the shell may be waiting on the compositor.
        const QDBusMessage reply = QDBusConnection::sessionBus().call(message, QDBus::Block, kLeavingTimeoutMs);
        if (reply.type() == QDBusMessage::ReplyMessage) {
            QFile::remove(panelStatePath());
        }
        return;
    }
    auto watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message, kAnswerTimeoutMs), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, fromLastRun](QDBusPendingCallWatcher *call) {
        call->deleteLater();
        if (call->isError()) {
            if (!fromLastRun) {
                setError(call->error().message());
            } else if (nobodyAnswers(call->error())) {
                // The Keyboard starts with the compositor, often before the
                // shell. The previous run's modes go back once it arrives.
                restoreLastRunPanelsOnceShellArrives();
            }
            return;
        }
        // Keys that came up again since have kept their own copy already.
        if (m_panelState != PanelState::Yielded) {
            QFile::remove(panelStatePath());
        }
    });
}

void BottomSurfaceCoordinator::setError(const QString &error)
{
    if (m_error == error) {
        return;
    }
    m_error = error;
    Q_EMIT errorChanged();
}
