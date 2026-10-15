/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

// The Keyboard's side of the bottom of the screen, against stand-ins for KWin,
// the Bottom Surface and Plasma's shell on a private session bus. Each
// stand-in lives on this test's own thread, so a Keyboard that waited on one
// would wait until its call timed out: every check that a stand-in heard an
// ask is also a check that nothing waited for its answer.

#include "bottomsurfacecoordinator.h"

#include <QDBusConnection>
#include <QDBusContext>
#include <QDBusMessage>
#include <QDir>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QSignalSpy>
#include <QStandardPaths>
#include <QTest>
#include <QTimer>

#include <algorithm>
#include <memory>

namespace
{
const QString kFakesConnection = QStringLiteral("bottom-surface-fakes");

QDBusConnection fakes()
{
    return QDBusConnection(kFakesConnection);
}
}

/// KWin's virtual keyboard: whether the keys are on screen.
class FakeKWin : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.kwin.VirtualKeyboard")
    Q_PROPERTY(bool visible READ visible)

public:
    bool visible() const
    {
        return m_visible;
    }

    void setVisible(bool visible)
    {
        m_visible = visible;
        fakes().send(
            QDBusMessage::createSignal(QStringLiteral("/VirtualKeyboard"), QStringLiteral("org.kde.kwin.VirtualKeyboard"), QStringLiteral("visibleChanged")));
    }

private:
    bool m_visible = false;
};

/// A Bottom Surface that grants, refuses, or holds its answer to a yield.
class FakeSurface : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "co.goodinput.BottomSurface")

public:
    enum class Answer {
        Grant,
        Refuse,
        Hold,
    };
    Answer answer = Answer::Grant;
    int yields = 0;
    int releases = 0;
    QList<QDBusMessage> held;

public Q_SLOTS:
    Q_SCRIPTABLE bool yieldRegion()
    {
        ++yields;
        if (answer == Answer::Hold) {
            setDelayedReply(true);
            held.append(message());
            return false;
        }
        return answer == Answer::Grant;
    }

    Q_SCRIPTABLE bool releaseRegion()
    {
        ++releases;
        return true;
    }

    Q_SCRIPTABLE QString dockExtent(const QString &outputName)
    {
        Q_UNUSED(outputName)
        return QStringLiteral("{}");
    }
};

/// Plasma's shell: records every script, answers a read with its panels,
/// and can hold its answer to either kind of script.
class FakeShell : public QObject, protected QDBusContext
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.PlasmaShell")

public:
    struct Script {
        QString text;
        bool stateOnDisk = false;
    };

    QString panels = QStringLiteral("[]");
    bool holdReads = false;
    bool holdRestores = false;
    QList<Script> scripts;
    QList<QDBusMessage> held;

    static bool isRead(const QString &script)
    {
        return script.contains(QLatin1String("print(JSON.stringify(saved))"));
    }
    static bool isHide(const QString &script)
    {
        return script.contains(QLatin1String("panel.hiding = \"autohide\""));
    }
    static bool isRestore(const QString &script)
    {
        return script.contains(QLatin1String("panel.hiding = entry.hiding"));
    }

    int count(bool (*kind)(const QString &)) const
    {
        return std::count_if(scripts.cbegin(), scripts.cend(), [kind](const Script &script) {
            return kind(script.text);
        });
    }

public Q_SLOTS:
    Q_SCRIPTABLE QString evaluateScript(const QString &script)
    {
        scripts.append({script, QFile::exists(BottomSurfaceCoordinator::panelStatePath())});
        if ((isRead(script) && holdReads) || (isRestore(script) && holdRestores)) {
            setDelayedReply(true);
            held.append(message());
            return {};
        }
        return isRead(script) ? panels : QString();
    }
};

class BottomSurfaceCoordinatorTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void initTestCase();
    void init();
    void cleanup();

    void noSurfaceFallsBackToPanels();
    void refusingSurfaceLeavesPanelsAlone();
    void slowSurfaceLeavesPanelsAloneAndKeysKeepRunning();
    void busyShellDoesNotHoldTheKeys();
    void panelsLeftByAnEarlierRunGoBackOnStart();
    void panelsLeftByAnEarlierRunGoBackOnceTheShellArrives();
    void unrestoredModesSurviveTheNextYield();

private:
    void registerSurface();
    void startCoordinator();
    void watchTheEventLoop();
    static void writeState(const QJsonArray &saved);
    static QJsonArray readState();

    std::unique_ptr<FakeKWin> m_kwin;
    std::unique_ptr<FakeSurface> m_surface;
    std::unique_ptr<FakeShell> m_shell;
    std::unique_ptr<BottomSurfaceCoordinator> m_coordinator;
    QTimer m_heartbeat;
    QElapsedTimer m_sinceBeat;
    qint64 m_longestGap = 0;
};

void BottomSurfaceCoordinatorTest::initTestCase()
{
    QStandardPaths::setTestModeEnabled(true);
    QVERIFY2(QDBusConnection::sessionBus().isConnected(), "This test runs on its own session bus, under dbus-run-session.");
    QVERIFY(QDBusConnection::connectToBus(QDBusConnection::SessionBus, kFakesConnection).isConnected());
    m_heartbeat.setInterval(10);
    connect(&m_heartbeat, &QTimer::timeout, this, [this] {
        m_longestGap = std::max(m_longestGap, m_sinceBeat.restart());
    });
}

void BottomSurfaceCoordinatorTest::init()
{
    QFile::remove(BottomSurfaceCoordinator::panelStatePath());
    m_kwin = std::make_unique<FakeKWin>();
    m_shell = std::make_unique<FakeShell>();
    QVERIFY(fakes().registerObject(QStringLiteral("/VirtualKeyboard"), m_kwin.get(), QDBusConnection::ExportAllProperties));
    QVERIFY(fakes().registerService(QStringLiteral("org.kde.KWin")));
    QVERIFY(fakes().registerObject(QStringLiteral("/PlasmaShell"), m_shell.get(), QDBusConnection::ExportScriptableSlots));
    QVERIFY(fakes().registerService(QStringLiteral("org.kde.plasmashell")));
    m_longestGap = 0;
}

void BottomSurfaceCoordinatorTest::cleanup()
{
    m_heartbeat.stop();
    m_coordinator.reset();
    for (const QDBusMessage &message : std::as_const(m_shell->held)) {
        fakes().send(message.createErrorReply(QDBusError::Failed, QStringLiteral("test over")));
    }
    if (m_surface) {
        for (const QDBusMessage &message : std::as_const(m_surface->held)) {
            fakes().send(message.createErrorReply(QDBusError::Failed, QStringLiteral("test over")));
        }
    }
    fakes().unregisterService(QStringLiteral("co.goodinput.BottomSurface"));
    fakes().unregisterService(QStringLiteral("org.kde.plasmashell"));
    fakes().unregisterService(QStringLiteral("org.kde.KWin"));
    fakes().unregisterObject(QStringLiteral("/BottomSurface"));
    fakes().unregisterObject(QStringLiteral("/PlasmaShell"));
    fakes().unregisterObject(QStringLiteral("/VirtualKeyboard"));
    m_surface.reset();
    m_shell.reset();
    m_kwin.reset();
    QFile::remove(BottomSurfaceCoordinator::panelStatePath());
}

void BottomSurfaceCoordinatorTest::registerSurface()
{
    m_surface = std::make_unique<FakeSurface>();
    QVERIFY(fakes().registerObject(QStringLiteral("/BottomSurface"), m_surface.get(), QDBusConnection::ExportScriptableSlots));
    QVERIFY(fakes().registerService(QStringLiteral("co.goodinput.BottomSurface")));
}

void BottomSurfaceCoordinatorTest::startCoordinator()
{
    m_coordinator = std::make_unique<BottomSurfaceCoordinator>();
    // Its first reads of KWin and the surface are answered before a test
    // moves the keys.
    QTest::qWait(100);
}

void BottomSurfaceCoordinatorTest::watchTheEventLoop()
{
    m_longestGap = 0;
    m_sinceBeat.start();
    m_heartbeat.start();
}

void BottomSurfaceCoordinatorTest::writeState(const QJsonArray &saved)
{
    const QString path = BottomSurfaceCoordinator::panelStatePath();
    QDir().mkpath(QFileInfo(path).absolutePath());
    QSaveFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    file.write(QJsonDocument(saved).toJson(QJsonDocument::Compact));
    QVERIFY(file.commit());
}

QJsonArray BottomSurfaceCoordinatorTest::readState()
{
    QFile file(BottomSurfaceCoordinator::panelStatePath());
    if (!file.open(QIODevice::ReadOnly)) {
        return {};
    }
    return QJsonDocument::fromJson(file.readAll()).array();
}

// With no Bottom Surface on the bus, the keys hide Plasma's bottom panel, and
// the panel's own mode is on disk before the panel changes.
void BottomSurfaceCoordinatorTest::noSurfaceFallsBackToPanels()
{
    m_shell->panels = QStringLiteral(R"([{"id":3,"hiding":"none"}])");
    startCoordinator();

    m_kwin->setVisible(true);
    QTRY_COMPARE(m_shell->count(FakeShell::isHide), 1);
    const auto hide = std::find_if(m_shell->scripts.cbegin(), m_shell->scripts.cend(), [](const FakeShell::Script &script) {
        return FakeShell::isHide(script.text);
    });
    QVERIFY2(hide->stateOnDisk, "The panel was changed before its mode was kept.");
    QVERIFY(hide->text.contains(QLatin1String("[3]")));
    QCOMPARE(readState().first().toObject().value(QStringLiteral("hiding")).toString(), QStringLiteral("none"));

    m_kwin->setVisible(false);
    QTRY_COMPARE(m_shell->count(FakeShell::isRestore), 1);
    QVERIFY(m_shell->scripts.last().text.contains(QLatin1String(R"("hiding":"none")")));
    QTRY_VERIFY(!QFile::exists(BottomSurfaceCoordinator::panelStatePath()));
}

// A surface that says no still owns the region; the Keyboard must not command
// its panel as well.
void BottomSurfaceCoordinatorTest::refusingSurfaceLeavesPanelsAlone()
{
    registerSurface();
    m_surface->answer = FakeSurface::Answer::Refuse;
    startCoordinator();

    m_kwin->setVisible(true);
    QTRY_COMPARE(m_surface->yields, 1);
    QTest::qWait(300);
    QCOMPARE(m_shell->scripts.size(), 0);
    QVERIFY(!m_coordinator->error().isEmpty());

    m_kwin->setVisible(false);
    QTRY_COMPARE(m_surface->releases, 1);
    QTest::qWait(100);
    QCOMPARE(m_shell->scripts.size(), 0);
}

// A surface that is slow to answer neither holds the keys nor sends the
// Keyboard to the panels; its late yes is handed back when the keys go.
void BottomSurfaceCoordinatorTest::slowSurfaceLeavesPanelsAloneAndKeysKeepRunning()
{
    registerSurface();
    m_surface->answer = FakeSurface::Answer::Hold;
    startCoordinator();
    QSignalSpy refreshed(m_coordinator.get(), &BottomSurfaceCoordinator::reservationRefreshRequested);

    watchTheEventLoop();
    m_kwin->setVisible(true);
    QTRY_COMPARE(m_surface->yields, 1);
    QTest::qWait(300);
    QVERIFY2(m_longestGap < 1000, qPrintable(QStringLiteral("The event loop stood still for %1 ms").arg(m_longestGap)));
    QCOMPARE(m_shell->scripts.size(), 0);

    QDBusMessage held = m_surface->held.takeFirst();
    fakes().send(held.createReply(true));
    QTRY_COMPARE(refreshed.count(), 1);

    m_kwin->setVisible(false);
    QTRY_COMPARE(m_surface->releases, 1);
    QCOMPARE(m_shell->scripts.size(), 0);
}

// A shell that is slow to answer does not hold the keys, and keys that went
// before it answered change no panel.
void BottomSurfaceCoordinatorTest::busyShellDoesNotHoldTheKeys()
{
    m_shell->panels = QStringLiteral(R"([{"id":3,"hiding":"none"}])");
    m_shell->holdReads = true;
    startCoordinator();

    watchTheEventLoop();
    m_kwin->setVisible(true);
    QTRY_COMPARE(m_shell->count(FakeShell::isRead), 1);
    QTest::qWait(300);
    QVERIFY2(m_longestGap < 1000, qPrintable(QStringLiteral("The event loop stood still for %1 ms").arg(m_longestGap)));

    m_kwin->setVisible(false);
    QTest::qWait(100);
    QDBusMessage held = m_shell->held.takeFirst();
    fakes().send(held.createReply(m_shell->panels));
    QTest::qWait(300);
    QCOMPARE(m_shell->count(FakeShell::isHide), 0);
    QVERIFY(!QFile::exists(BottomSurfaceCoordinator::panelStatePath()));
}

// A run that crashed, was killed or ran out of time with the panel hidden
// left the panel's mode on disk; the next start puts it back.
void BottomSurfaceCoordinatorTest::panelsLeftByAnEarlierRunGoBackOnStart()
{
    writeState(QJsonArray{QJsonObject{{QStringLiteral("id"), 7}, {QStringLiteral("hiding"), QStringLiteral("dodgewindows")}}});
    startCoordinator();

    QTRY_COMPARE(m_shell->count(FakeShell::isRestore), 1);
    QVERIFY(m_shell->scripts.first().text.contains(QLatin1String(R"({"hiding":"dodgewindows","id":7})")));
    QTRY_VERIFY(!QFile::exists(BottomSurfaceCoordinator::panelStatePath()));
}

// The Keyboard can start before the shell does; the kept modes go back as
// soon as it arrives, without waiting for the keys to come up.
void BottomSurfaceCoordinatorTest::panelsLeftByAnEarlierRunGoBackOnceTheShellArrives()
{
    QVERIFY(fakes().unregisterService(QStringLiteral("org.kde.plasmashell")));
    writeState(QJsonArray{QJsonObject{{QStringLiteral("id"), 7}, {QStringLiteral("hiding"), QStringLiteral("dodgewindows")}}});
    startCoordinator();
    QTest::qWait(200);
    QCOMPARE(m_shell->scripts.size(), 0);
    QVERIFY(QFile::exists(BottomSurfaceCoordinator::panelStatePath()));

    QVERIFY(fakes().registerService(QStringLiteral("org.kde.plasmashell")));
    QTRY_COMPARE(m_shell->count(FakeShell::isRestore), 1);
    QTRY_VERIFY(!QFile::exists(BottomSurfaceCoordinator::panelStatePath()));
}

// While a kept mode has not been put back, the shell's autohide is the last
// run's, not the person's: the kept mode is what stays on disk.
void BottomSurfaceCoordinatorTest::unrestoredModesSurviveTheNextYield()
{
    writeState(QJsonArray{QJsonObject{{QStringLiteral("id"), 3}, {QStringLiteral("hiding"), QStringLiteral("none")}}});
    m_shell->holdRestores = true;
    m_shell->panels = QStringLiteral(R"([{"id":3,"hiding":"autohide"}])");
    startCoordinator();

    m_kwin->setVisible(true);
    QTRY_COMPARE(m_shell->count(FakeShell::isHide), 1);
    const QJsonArray kept = readState();
    QCOMPARE(kept.size(), 1);
    QCOMPARE(kept.first().toObject().value(QStringLiteral("hiding")).toString(), QStringLiteral("none"));
}

QTEST_MAIN(BottomSurfaceCoordinatorTest)

#include "bottomsurfacecoordinatortest.moc"
