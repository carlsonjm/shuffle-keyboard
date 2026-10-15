/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "precisioncontroller.h"
#include "keysrequest.h"

#include <KConfigGroup>
#include <KSharedConfig>

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusServiceWatcher>
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
// Long enough for a person to read and answer the consent prompt.
constexpr int AnswerTimeoutMs = 120000;
}

PrecisionController::PrecisionController(QObject *parent)
    : QObject(parent)
{
    const KConfigGroup group(KSharedConfig::openConfig(QStringLiteral("plasmakeyboardrc")), QStringLiteral("General"));
    m_restoreToken = group.readEntry(QStringLiteral("precisionRestoreToken"), QString());

    // A portal that restarts takes every session and request with it, and
    // says nothing on their objects. Whatever was asked or granted is gone.
    m_portalWatcher =
        new QDBusServiceWatcher(QString::fromLatin1(PortalService), QDBusConnection::sessionBus(), QDBusServiceWatcher::WatchForUnregistration, this);
    connect(m_portalWatcher, &QDBusServiceWatcher::serviceUnregistered, this, [this] {
        if (m_state == Connecting || m_state == Ready) {
            endSession(QStringLiteral("The pointer portal stopped. Touch to ask again"));
        }
    });

    // A consent prompt can stay open as long as the person likes, but a
    // request nobody ever answers must not leave the surface asking forever.
    m_answerTimeout.setSingleShot(true);
    m_answerTimeout.setInterval(AnswerTimeoutMs);
    connect(&m_answerTimeout, &QTimer::timeout, this, [this] {
        qWarning("The pointer portal did not answer its request; the precision surface will ask again");
        endSession(QStringLiteral("The system did not answer. Touch to ask again"), Failed);
    });
}

PrecisionController::~PrecisionController()
{
    if (m_primaryPressed) {
        primaryUp();
    }
    if (!m_sessionPath.isEmpty()) {
        QDBusConnection::sessionBus().send(
            QDBusMessage::createMethodCall(QString::fromLatin1(PortalService), m_sessionPath, QString::fromLatin1(SessionInterface), QStringLiteral("Close")));
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

void PrecisionController::setState(State state, const QString &message)
{
    if (m_state == state && m_message == message) {
        return;
    }
    m_state = state;
    m_message = message;
    Q_EMIT stateChanged();
}

void PrecisionController::stopListening()
{
    m_answerTimeout.stop();
    for (const QString &path : std::as_const(m_requestPaths)) {
        QDBusConnection::sessionBus().disconnect(QString::fromLatin1(PortalService),
                                                 path,
                                                 QString::fromLatin1(RequestInterface),
                                                 QStringLiteral("Response"),
                                                 this,
                                                 SLOT(handleResponse(uint, QVariantMap)));
    }
    m_requestPaths.clear();
    m_step = Step::None;
}

void PrecisionController::endSession(const QString &message, State state)
{
    stopListening();
    if (!m_sessionPath.isEmpty()) {
        QDBusConnection::sessionBus().disconnect(QString::fromLatin1(PortalService),
                                                 m_sessionPath,
                                                 QString::fromLatin1(SessionInterface),
                                                 QStringLiteral("Closed"),
                                                 this,
                                                 SLOT(handleSessionClosed(QVariantMap)));
    }
    m_sessionPath.clear();
    m_primaryPressed = false;
    // Idle or Failed, so the next touch asks for a session again.
    setState(state, message);
}

void PrecisionController::ask(Step step, const QString &method, QList<QVariant> arguments, QVariantMap options)
{
    stopListening();
    m_step = step;

    // The portal names the request object
    // /org/freedesktop/portal/desktop/request/SENDER/TOKEN, SENDER being this
    // connection's unique name without its colon and with dots as
    // underscores. With a restore token there is no prompt, and the answer
    // can follow the call at once.
    const QString token = QStringLiteral("shuffle_") + QUuid::createUuid().toString(QUuid::Id128);
    options.insert(QStringLiteral("handle_token"), token);
    QString sender = QDBusConnection::sessionBus().baseService();
    sender.remove(0, sender.startsWith(QLatin1Char(':')) ? 1 : 0).replace(QLatin1Char('.'), QLatin1Char('_'));
    const QString predicted = QStringLiteral("/org/freedesktop/portal/desktop/request/%1/%2").arg(sender, token);
    if (!QDBusConnection::sessionBus().connect(QString::fromLatin1(PortalService),
                                               predicted,
                                               QString::fromLatin1(RequestInterface),
                                               QStringLiteral("Response"),
                                               this,
                                               SLOT(handleResponse(uint, QVariantMap)))) {
        setState(Failed, QStringLiteral("Could not listen for the pointer permission request"));
        return;
    }
    m_requestPaths.append(predicted);
    m_answerTimeout.start();

    QDBusMessage message = QDBusMessage::createMethodCall(QString::fromLatin1(PortalService),
                                                          QString::fromLatin1(PortalPath),
                                                          QString::fromLatin1(RemoteDesktopInterface),
                                                          method);
    arguments.append(options);
    message.setArguments(arguments);
    auto watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, step](QDBusPendingCallWatcher *call) {
        call->deleteLater();
        // Answered already, or overtaken by a later ask.
        if (m_step != step) {
            return;
        }
        const QDBusPendingReply<QDBusObjectPath> reply = *call;
        if (reply.isError()) {
            stopListening();
            setState(Failed, reply.error().message());
            return;
        }
        // A portal older than the handle_token convention names the request
        // itself; its answer is listened for there as well.
        const QString path = reply.value().path();
        if (!m_requestPaths.contains(path)
            && QDBusConnection::sessionBus().connect(QString::fromLatin1(PortalService),
                                                     path,
                                                     QString::fromLatin1(RequestInterface),
                                                     QStringLiteral("Response"),
                                                     this,
                                                     SLOT(handleResponse(uint, QVariantMap)))) {
            m_requestPaths.append(path);
        }
    });
}

void PrecisionController::ensureSession()
{
    if (m_state == Connecting || m_state == Ready) {
        return;
    }
    // A session refused part way, at device selection or start, is let go,
    // so that its closing later cannot end the one asked for now.
    if (!m_sessionPath.isEmpty()) {
        endSession(m_message, m_state);
    }

    setState(Connecting, QStringLiteral("Requesting system pointer access"));
    QVariantMap options;
    options.insert(QStringLiteral("session_handle_token"), QStringLiteral("shuffle_session_") + QUuid::createUuid().toString(QUuid::Id128));
    ask(Step::Create, QStringLiteral("CreateSession"), {}, options);
}

void PrecisionController::warmIfGranted()
{
    if (!m_restoreToken.isEmpty()) {
        ensureSession();
    }
}

void PrecisionController::handleResponse(uint response, const QVariantMap &results)
{
    const Step step = m_step;
    stopListening();

    switch (step) {
    case Step::None:
        return;
    case Step::Create: {
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
        // A revoked grant, or the portal ending the session for its own
        // reasons, arrives here; without it the surface would stay ready and
        // every touch would go nowhere.
        QDBusConnection::sessionBus().connect(QString::fromLatin1(PortalService),
                                              m_sessionPath,
                                              QString::fromLatin1(SessionInterface),
                                              QStringLiteral("Closed"),
                                              this,
                                              SLOT(handleSessionClosed(QVariantMap)));
        selectDevices();
        return;
    }
    case Step::Select:
        if (response != 0) {
            setState(Denied, QStringLiteral("Pointer access was not selected"));
            return;
        }
        startSession();
        return;
    case Step::Start:
        break;
    }

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

void PrecisionController::handleSessionClosed(const QVariantMap &details)
{
    Q_UNUSED(details)
    qWarning("The pointer portal closed the precision surface's session");
    endSession(QStringLiteral("Pointer access ended. Touch to ask again"));
}

void PrecisionController::selectDevices()
{
    QVariantMap options;
    options.insert(QStringLiteral("types"), PointerDevice);
    options.insert(QStringLiteral("persist_mode"), uint(2));
    if (!m_restoreToken.isEmpty()) {
        options.insert(QStringLiteral("restore_token"), m_restoreToken);
    }
    ask(Step::Select, QStringLiteral("SelectDevices"), {QVariant::fromValue(QDBusObjectPath(m_sessionPath))}, options);
}

void PrecisionController::startSession()
{
    ask(Step::Start, QStringLiteral("Start"), {QVariant::fromValue(QDBusObjectPath(m_sessionPath)), QString()}, {});
}

void PrecisionController::keepKeyboardVisible()
{
    requestKeys(this);
}

void PrecisionController::notify(const QString &method, const QList<QVariant> &arguments)
{
    if (!ready()) {
        ensureSession();
        return;
    }
    QDBusMessage message = QDBusMessage::createMethodCall(QString::fromLatin1(PortalService),
                                                          QString::fromLatin1(PortalPath),
                                                          QString::fromLatin1(RemoteDesktopInterface),
                                                          method);
    message.setArguments(QList<QVariant>{QVariant::fromValue(QDBusObjectPath(m_sessionPath))} + arguments);
    const QString session = m_sessionPath;
    auto watcher = new QDBusPendingCallWatcher(QDBusConnection::sessionBus().asyncCall(message), this);
    connect(watcher, &QDBusPendingCallWatcher::finished, this, [this, session](QDBusPendingCallWatcher *call) {
        call->deleteLater();
        // A refused event means the session the surface holds is no longer
        // one the portal honours. Only the first refusal for it counts.
        if (!call->isError() || session != m_sessionPath || m_state != Ready) {
            return;
        }
        qWarning("The pointer portal refused an event: %s", qPrintable(call->error().message()));
        endSession(QStringLiteral("Pointer access was lost. Touch to ask again"));
    });
}

void PrecisionController::move(qreal dx, qreal dy)
{
    notify(QStringLiteral("NotifyPointerMotion"), {QVariantMap(), dx, dy});
}

void PrecisionController::scroll(qreal dx, qreal dy, bool finished)
{
    QVariantMap options;
    options.insert(QStringLiteral("finish"), finished);
    notify(QStringLiteral("NotifyPointerAxis"), {options, dx, dy});
}

void PrecisionController::notifyButton(int button, uint state)
{
    notify(QStringLiteral("NotifyPointerButton"), {QVariantMap(), button, state});
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
