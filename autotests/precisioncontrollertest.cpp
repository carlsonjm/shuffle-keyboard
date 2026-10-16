/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

// The precision surface's side of the RemoteDesktop portal, against a portal
// stand-in on a private session bus. The stand-in answers the way a portal
// does when access was granted before: at once, before its call has even
// returned, which is the answer a surface listening only afterwards misses.

#include "precisioncontroller.h"
#include "directpointer.h"

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
    int selects = 0;

public Q_SLOTS:
    Q_SCRIPTABLE QDBusObjectPath CreateSession(const QVariantMap &options)
    {
        ++creates;
        return answerFirst(options, {{QStringLiteral("session_handle"), QVariant::fromValue(QDBusObjectPath(kSessionPath))}});
    }

    Q_SCRIPTABLE QDBusObjectPath SelectDevices(const QDBusObjectPath &session, const QVariantMap &options)
    {
        Q_UNUSED(session)
        ++selects;
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

class FakeSession : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.freedesktop.portal.Session")

public:
    int closes = 0;

public Q_SLOTS:
    Q_SCRIPTABLE void Close()
    {
        ++closes;
    }
};

// The pointer the compositor trusts the Keyboard with.
class FakeDirectPointer : public DirectPointer
{
public:
    bool available = true;
    int motions = 0;
    int buttons = 0;

    bool isAvailable() const override
    {
        return available;
    }
    void pointerMotion(qreal, qreal) override
    {
        ++motions;
    }
    void pointerButton(int, bool) override
    {
        ++buttons;
    }
    void pointerAxis(qreal, qreal) override
    {
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
    void nothingIsAskedUntilTheSurfaceIsUsed();
    void lettingGoClosesTheSession();
    void aSessionLetGoWhileCreatedIsClosed();
    void aTrustedPointerAsksNoPortal();
    void anUntrustedPointerAsksThePortal();

private:
    void becomeReady();

    std::unique_ptr<FakePortal> m_portal;
    std::unique_ptr<FakeSession> m_session;
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
    m_session = std::make_unique<FakeSession>();
    QVERIFY(fakes().registerObject(kSessionPath, m_session.get(), QDBusConnection::ExportScriptableSlots));
    QVERIFY(fakes().registerService(kPortalService));
    m_controller = std::make_unique<PrecisionController>();
}

void PrecisionControllerTest::cleanup()
{
    m_controller.reset();
    PrecisionController::setDirectPointer(nullptr);
    fakes().unregisterService(kPortalService);
    fakes().unregisterObject(QStringLiteral("/org/freedesktop/portal/desktop"));
    fakes().unregisterObject(kSessionPath);
    m_portal.reset();
    m_session.reset();
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

// Plasma shows pointer control for as long as a session is open, so a pointer
// event without the surface in use asks for nothing.
void PrecisionControllerTest::nothingIsAskedUntilTheSurfaceIsUsed()
{
    m_controller->move(1, 1);
    QTest::qWait(100);
    QCOMPARE(m_portal->creates, 0);
    QCOMPARE(m_controller->state(), PrecisionController::Idle);
}

// The latch ending closes the session, and the next latch opens a new one.
void PrecisionControllerTest::lettingGoClosesTheSession()
{
    becomeReady();
    m_controller->release();
    QTRY_COMPARE(m_session->closes, 1);
    QCOMPARE(m_controller->state(), PrecisionController::Idle);

    m_controller->move(1, 1);
    QTest::qWait(100);
    QCOMPARE(m_portal->creates, 1);

    becomeReady();
    QCOMPARE(m_portal->creates, 2);
}

// A session let go before the portal named it is closed once it is named, and
// goes no further.
void PrecisionControllerTest::aSessionLetGoWhileCreatedIsClosed()
{
    m_controller->ensureSession();
    m_controller->release();
    QTRY_COMPARE(m_session->closes, 1);
    QCOMPARE(m_portal->selects, 0);
    QCOMPARE(m_controller->state(), PrecisionController::Idle);
}

// Where the compositor trusts the Keyboard with the pointer, the surface
// moves it straight away and the portal, with its prompt and Plasma's
// remote-control notice, is never asked.
void PrecisionControllerTest::aTrustedPointerAsksNoPortal()
{
    FakeDirectPointer pointer;
    PrecisionController::setDirectPointer(&pointer);

    m_controller->move(1, 1);
    QCOMPARE(pointer.motions, 0);

    m_controller->ensureSession();
    QCOMPARE(m_controller->state(), PrecisionController::Ready);
    m_controller->move(1, 1);
    m_controller->primaryDown();
    QCOMPARE(pointer.motions, 1);
    QCOMPARE(pointer.buttons, 1);

    // Letting go lets go of the button too.
    m_controller->release();
    QCOMPARE(pointer.buttons, 2);
    QCOMPARE(m_controller->state(), PrecisionController::Idle);
    m_controller->move(1, 1);
    QCOMPARE(pointer.motions, 1);

    QTest::qWait(100);
    QCOMPARE(m_portal->creates, 0);
}

// Where it does not, the surface asks the portal as before.
void PrecisionControllerTest::anUntrustedPointerAsksThePortal()
{
    FakeDirectPointer pointer;
    pointer.available = false;
    PrecisionController::setDirectPointer(&pointer);

    becomeReady();
    QCOMPARE(m_portal->creates, 1);
    m_controller->move(1, 1);
    QTRY_COMPARE(m_portal->motions, 1);
    QCOMPARE(pointer.motions, 0);
}

QTEST_GUILESS_MAIN(PrecisionControllerTest)

#include "precisioncontrollertest.moc"
