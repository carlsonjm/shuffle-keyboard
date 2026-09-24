/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "precisioncontroller.h"
#include "keysrequest.h"

#include <KConfigGroup>
#include <KSharedConfig>

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusObjectPath>
#include <QDBusReply>
#include <QTimer>
#include <QUuid>

namespace
{
constexpr auto PortalService = "org.freedesktop.portal.Desktop";
constexpr auto PortalPath = "/org/freedesktop/portal/desktop";
constexpr auto RemoteDesktopInterface = "org.freedesktop.portal.RemoteDesktop";
constexpr auto RequestInterface = "org.freedesktop.portal.Request";
constexpr auto SessionInterface = "org.freedesktop.portal.Session";
constexpr uint PointerDevice = 2;
constexpr int LeftButton = 0x110;
constexpr int RightButton = 0x111;
}

PrecisionController::PrecisionController(QObject *parent)
    : QObject(parent)
{
    const KConfigGroup group(KSharedConfig::openConfig(QStringLiteral("plasmakeyboardrc")), QStringLiteral("General"));
    m_restoreToken = group.readEntry(QStringLiteral("precisionRestoreToken"), QString());
}

PrecisionController::~PrecisionController()
{
    if (m_primaryPressed) {
        primaryUp();
    }
    if (!m_sessionPath.isEmpty()) {
        QDBusInterface session(QString::fromLatin1(PortalService), m_sessionPath, QString::fromLatin1(SessionInterface), QDBusConnection::sessionBus());
        session.asyncCall(QStringLiteral("Close"));
    }
}

PrecisionController::State PrecisionController::state() const
{
    return m_state;
}

bool PrecisionController::ready() const
{
    return m_state == Ready;
}

QString PrecisionController::message() const
{
    return m_message;
}

QString PrecisionController::token(const QString &prefix) const
{
    QString uuid = QUuid::createUuid().toString(QUuid::Id128);
    return prefix + uuid;
}

bool PrecisionController::watchRequest(const QString &path, const char *slot)
{
    return QDBusConnection::sessionBus()
        .connect(QString::fromLatin1(PortalService), path, QString::fromLatin1(RequestInterface), QStringLiteral("Response"), this, slot);
}

void PrecisionController::setState(State state, const QString &message)
{
    if (m_state == state && m_message == message) {
        return;
    }
    m_state = state;
    m_message = message;
    Q_EMIT stateChanged();
}

void PrecisionController::ensureSession()
{
    if (m_state == Connecting || m_state == Ready) {
        return;
    }

    setState(Connecting, QStringLiteral("Requesting system pointer access"));
    QVariantMap options;
    options.insert(QStringLiteral("handle_token"), token(QStringLiteral("shuffle_create_")));
    options.insert(QStringLiteral("session_handle_token"), token(QStringLiteral("shuffle_session_")));

    QDBusInterface portal(QString::fromLatin1(PortalService),
                          QString::fromLatin1(PortalPath),
                          QString::fromLatin1(RemoteDesktopInterface),
                          QDBusConnection::sessionBus());
    const QDBusReply<QDBusObjectPath> reply = portal.call(QStringLiteral("CreateSession"), options);
    if (!reply.isValid() || !watchRequest(reply.value().path(), SLOT(handleCreateResponse(uint, QVariantMap)))) {
        setState(Failed, reply.isValid() ? QStringLiteral("Could not monitor the pointer permission request") : reply.error().message());
    }
}

void PrecisionController::warmIfGranted()
{
    if (!m_restoreToken.isEmpty()) {
        ensureSession();
    }
}

void PrecisionController::handleCreateResponse(uint response, const QVariantMap &results)
{
    if (response != 0) {
        setState(Denied, QStringLiteral("Pointer access was not granted"));
        return;
    }
    const QVariant handle = results.value(QStringLiteral("session_handle"));
    m_sessionPath = handle.canConvert<QDBusObjectPath>() ? qvariant_cast<QDBusObjectPath>(handle).path() : handle.toString();
    if (m_sessionPath.isEmpty()) {
        setState(Failed, QStringLiteral("The portal did not return a session"));
        return;
    }
    selectDevices();
}

void PrecisionController::selectDevices()
{
    QVariantMap options;
    options.insert(QStringLiteral("handle_token"), token(QStringLiteral("shuffle_select_")));
    options.insert(QStringLiteral("types"), PointerDevice);
    options.insert(QStringLiteral("persist_mode"), uint(2));
    if (!m_restoreToken.isEmpty()) {
        options.insert(QStringLiteral("restore_token"), m_restoreToken);
    }

    QDBusInterface portal(QString::fromLatin1(PortalService),
                          QString::fromLatin1(PortalPath),
                          QString::fromLatin1(RemoteDesktopInterface),
                          QDBusConnection::sessionBus());
    const QDBusReply<QDBusObjectPath> reply = portal.call(QStringLiteral("SelectDevices"), QDBusObjectPath(m_sessionPath), options);
    if (!reply.isValid() || !watchRequest(reply.value().path(), SLOT(handleSelectResponse(uint, QVariantMap)))) {
        setState(Failed, reply.isValid() ? QStringLiteral("Could not monitor device selection") : reply.error().message());
    }
}

void PrecisionController::handleSelectResponse(uint response, const QVariantMap &results)
{
    Q_UNUSED(results)
    if (response != 0) {
        setState(Denied, QStringLiteral("Pointer access was not selected"));
        return;
    }
    startSession();
}

void PrecisionController::startSession()
{
    QVariantMap options;
    options.insert(QStringLiteral("handle_token"), token(QStringLiteral("shuffle_start_")));

    QDBusInterface portal(QString::fromLatin1(PortalService),
                          QString::fromLatin1(PortalPath),
                          QString::fromLatin1(RemoteDesktopInterface),
                          QDBusConnection::sessionBus());
    const QDBusReply<QDBusObjectPath> reply = portal.call(QStringLiteral("Start"), QDBusObjectPath(m_sessionPath), QString(), options);
    if (!reply.isValid() || !watchRequest(reply.value().path(), SLOT(handleStartResponse(uint, QVariantMap)))) {
        setState(Failed, reply.isValid() ? QStringLiteral("Could not monitor pointer activation") : reply.error().message());
    }
}

void PrecisionController::handleStartResponse(uint response, const QVariantMap &results)
{
    if (response != 0 || !(results.value(QStringLiteral("devices")).toUInt() & PointerDevice)) {
        setState(Denied, QStringLiteral("System pointer access was not granted"));
        return;
    }

    const QString restoreToken = results.value(QStringLiteral("restore_token")).toString();
    if (!restoreToken.isEmpty()) {
        m_restoreToken = restoreToken;
        KConfigGroup group(KSharedConfig::openConfig(QStringLiteral("plasmakeyboardrc")), QStringLiteral("General"));
        group.writeEntry(QStringLiteral("precisionRestoreToken"), m_restoreToken);
        group.sync();
    }
    setState(Ready, QStringLiteral("Precision pointer ready"));
}

void PrecisionController::keepKeyboardVisible()
{
    requestKeys(this);
}

void PrecisionController::move(qreal dx, qreal dy)
{
    if (!ready()) {
        ensureSession();
        return;
    }
    QDBusInterface portal(QString::fromLatin1(PortalService),
                          QString::fromLatin1(PortalPath),
                          QString::fromLatin1(RemoteDesktopInterface),
                          QDBusConnection::sessionBus());
    portal.asyncCall(QStringLiteral("NotifyPointerMotion"), QDBusObjectPath(m_sessionPath), QVariantMap(), dx, dy);
}

void PrecisionController::scroll(qreal dx, qreal dy, bool finished)
{
    if (!ready()) {
        ensureSession();
        return;
    }
    QVariantMap options;
    options.insert(QStringLiteral("finish"), finished);
    QDBusInterface portal(QString::fromLatin1(PortalService),
                          QString::fromLatin1(PortalPath),
                          QString::fromLatin1(RemoteDesktopInterface),
                          QDBusConnection::sessionBus());
    portal.asyncCall(QStringLiteral("NotifyPointerAxis"), QDBusObjectPath(m_sessionPath), options, dx, dy);
}

void PrecisionController::notifyButton(int button, uint state)
{
    if (!ready()) {
        ensureSession();
        return;
    }
    QDBusInterface portal(QString::fromLatin1(PortalService),
                          QString::fromLatin1(PortalPath),
                          QString::fromLatin1(RemoteDesktopInterface),
                          QDBusConnection::sessionBus());
    portal.asyncCall(QStringLiteral("NotifyPointerButton"), QDBusObjectPath(m_sessionPath), QVariantMap(), button, state);
}

void PrecisionController::primaryClick()
{
    // Keep press and release as distinct compositor events. Back-to-back
    // asynchronous portal calls can collapse into motion-only behavior on a
    // touch-driven session.
    primaryDown();
    QTimer::singleShot(36, this, [this] {
        primaryUp();
        keepKeyboardVisible();
    });
}

void PrecisionController::secondaryClick()
{
    notifyButton(RightButton, 1);
    QTimer::singleShot(36, this, [this] {
        notifyButton(RightButton, 0);
        keepKeyboardVisible();
    });
}

void PrecisionController::primaryDown()
{
    if (m_primaryPressed) {
        return;
    }
    m_primaryPressed = true;
    notifyButton(LeftButton, 1);
}

void PrecisionController::primaryUp()
{
    if (!m_primaryPressed) {
        return;
    }
    m_primaryPressed = false;
    notifyButton(LeftButton, 0);
    QTimer::singleShot(0, this, &PrecisionController::keepKeyboardVisible);
}
