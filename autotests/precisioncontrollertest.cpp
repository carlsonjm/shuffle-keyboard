/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

// The precision surface's side of the RemoteDesktop portal, against a portal
// stand-in on a private session bus. The stand-in answers the way a portal
// does when access was granted before: at once, before its call has even
// returned, which is the answer a surface listening only afterwards misses.

#include "precisioncontroller.h"

#include <QDBusConnection>
#include <QDBusContext>
#include <QDBusMessage>
#include <QDBusObjectPath>
#include <QStandardPaths>
#include <QTest>

#include <memory>

namespace
{
const QString kFakesConnection = QStringLiteral("portal-fakes");
const QString kPortalService = QStringLiteral("org.freedesktop.portal.Desktop");
const QString kSessionPath = QStringLiteral("/org/freedesktop/portal/desktop/session/test/s1");

QDBusConnection fakes()
{
    return QDBusConnection(kFakesConnection);
}
}

class FakePortal : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.portal.RemoteDesktop")

public:
    bool refuseEvents = false;
    int motions = 0;
    int creates = 0;

public Q_SLOTS:
    Q_SCRIPTABLE QDBusObjectPath CreateSession(const QVariantMap &options)
    {
        ++creates;
        return answerFirst(options, {{QStringLiteral("session_handle"), QVariant::fromValue(QDBusObjectPath(kSessionPath))}});
    }

    Q_SCRIPTABLE QDBusObjectPath SelectDevices(const QDBusObjectPath &session, const QVariantMap &options)
    {
        Q_UNUSED(session)
        return answerFirst(options, {});
    }

    Q_SCRIPTABLE QDBusObjectPath Start(const QDBusObjectPath &session, const QString &parent, const QVariantMap &options)
    {
        Q_UNUSED(session)
        Q_UNUSED(parent)
        return answerFirst(options, {{QStringLiteral("devices"), uint(2)}});
    }

    Q_SCRIPTABLE void NotifyPointerMotion(const QDBusObjectPath &session, const QVariantMap &options, double dx, double dy)
    {
        Q_UNUSED(session)
        Q_UNUSED(options)
        Q_UNUSED(dx)
        Q_UNUSED(dy)
        ++motions;
        if (refuseEvents) {
            sendErrorReply(QDBusError::AccessDenied, QStringLiteral("no such session"));
        }
    }

private:
    // The Response goes out before the reply that names the request.
    QDBusObjectPath answerFirst(const QVariantMap &options, const QVariantMap &results)
    {
        QString sender = message().service();
        sender.remove(0, 1).replace(QLatin1Char('.'), QLatin1Char('_'));
        const QString path =
            QStringLiteral("/org/freedesktop/portal/desktop/request/%1/%2").arg(sender, options.value(QStringLiteral("handle_token")).toString());
        QDBusMessage response = QDBusMessage::createSignal(path, QStringLiteral("org.freedesktop.portal.Request"), QStringLiteral("Response"));
        response << uint(0) << results;
        fakes().send(response);
        return QDBusObjectPath(path);
    }
};

class PrecisionControllerTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void initTestCase();
    void init();
    void cleanup();

    void anAnswerBeforeTheReplyIsHeard();
    void aClosedSessionAsksAgain();
    void aRefusedEventAsksAgain();
    void aPortalThatStopsAsksAgain();

private:
    void becomeReady();

    std::unique_ptr<FakePortal> m_portal;
    std::unique_ptr<PrecisionController> m_controller;
};

void PrecisionControllerTest::initTestCase()
{
    QStandardPaths::setTestModeEnabled(true);
    QVERIFY2(QDBusConnection::sessionBus().isConnected(), "This test runs on its own session bus, under dbus-run-session.");
    QVERIFY(QDBusConnection::connectToBus(QDBusConnection::SessionBus, kFakesConnection).isConnected());
}

void PrecisionControllerTest::init()
{
    m_portal = std::make_unique<FakePortal>();
    QVERIFY(fakes().registerObject(QStringLiteral("/org/freedesktop/portal/desktop"), m_portal.get(), QDBusConnection::ExportScriptableSlots));
    QVERIFY(fakes().registerService(kPortalService));
    m_controller = std::make_unique<PrecisionController>();
}

void PrecisionControllerTest::cleanup()
{
    m_controller.reset();
    fakes().unregisterService(kPortalService);
    fakes().unregisterObject(QStringLiteral("/org/freedesktop/portal/desktop"));
    m_portal.reset();
}

void PrecisionControllerTest::becomeReady()
{
    m_controller->ensureSession();
    QTRY_COMPARE(m_controller->state(), PrecisionController::Ready);
}

// Access granted before answers without a prompt, and at once. The surface
// is ready rather than asking for access forever.
void PrecisionControllerTest::anAnswerBeforeTheReplyIsHeard()
{
    becomeReady();
    m_controller->move(1, 1);
    QTRY_COMPARE(m_portal->motions, 1);
}

// The portal ending the session leaves the surface asking again, not ready
// with nothing behind it.
void PrecisionControllerTest::aClosedSessionAsksAgain()
{
    becomeReady();
    QDBusMessage closed = QDBusMessage::createSignal(kSessionPath, QStringLiteral("org.freedesktop.portal.Session"), QStringLiteral("Closed"));
    closed << QVariantMap();
    fakes().send(closed);
    QTRY_COMPARE(m_controller->state(), PrecisionController::Idle);
    QVERIFY(!m_controller->message().isEmpty());

    m_controller->move(1, 1);
    QTRY_COMPARE(m_controller->state(), PrecisionController::Ready);
    QCOMPARE(m_portal->creates, 2);
}

// A portal that refuses the surface's events has dropped its session.
void PrecisionControllerTest::aRefusedEventAsksAgain()
{
    becomeReady();
    m_portal->refuseEvents = true;
    m_controller->move(1, 1);
    QTRY_COMPARE(m_controller->state(), PrecisionController::Idle);
}

// A portal that restarts has forgotten every session.
void PrecisionControllerTest::aPortalThatStopsAsksAgain()
{
    becomeReady();
    QVERIFY(fakes().unregisterService(kPortalService));
    QTRY_COMPARE(m_controller->state(), PrecisionController::Idle);
}

QTEST_GUILESS_MAIN(PrecisionControllerTest)

#include "precisioncontrollertest.moc"
