/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "keystrayentry.h"

#include <KLocalizedString>

#include <QCoreApplication>
#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCall>
#include <QDBusServiceWatcher>

namespace
{
constexpr auto TrayService = "org.kde.StatusNotifierWatcher";
constexpr auto TrayPath = "/StatusNotifierWatcher";
constexpr auto EntryPath = "/StatusNotifierItem";
}

KeysTrayEntry::KeysTrayEntry(QObject *parent)
    : QObject(parent)
    , m_serviceName(QStringLiteral("org.kde.StatusNotifierItem-%1-1").arg(QCoreApplication::applicationPid()))
{
    new KeysTrayAdaptor(this);
    auto bus = QDBusConnection::sessionBus();
    bus.registerObject(QString::fromLatin1(EntryPath), this);
    bus.registerService(m_serviceName);
    // The tray can start after the Keyboard, or start again; each time it
    // comes it is told about the entry.
    m_trayWatcher = new QDBusServiceWatcher(QString::fromLatin1(TrayService), bus, QDBusServiceWatcher::WatchForRegistration, this);
    connect(m_trayWatcher, &QDBusServiceWatcher::serviceRegistered, this, &KeysTrayEntry::registerWithTray);
    registerWithTray();
}

QString KeysTrayEntry::serviceName() const
{
    return m_serviceName;
}

void KeysTrayEntry::registerWithTray()
{
    QDBusMessage request = QDBusMessage::createMethodCall(QString::fromLatin1(TrayService),
                                                          QString::fromLatin1(TrayPath),
                                                          QString::fromLatin1(TrayService),
                                                          QStringLiteral("RegisterStatusNotifierItem"));
    request << m_serviceName;
    request.setAutoStartService(false);
    QDBusConnection::sessionBus().asyncCall(request);
}

KeysTrayAdaptor::KeysTrayAdaptor(KeysTrayEntry *entry)
    : QDBusAbstractAdaptor(entry)
    , m_entry(entry)
{
}

QString KeysTrayAdaptor::category() const
{
    return QStringLiteral("Hardware");
}

QString KeysTrayAdaptor::id() const
{
    return QStringLiteral("shuffle-keyboard");
}

QString KeysTrayAdaptor::title() const
{
    return i18nc("@title the on-screen keys' entry in the system tray", "Keyboard");
}

QString KeysTrayAdaptor::status() const
{
    return QStringLiteral("Active");
}

int KeysTrayAdaptor::windowId() const
{
    return 0;
}

QString KeysTrayAdaptor::none() const
{
    return {};
}

QString KeysTrayAdaptor::iconName() const
{
    return QStringLiteral("input-keyboard-virtual");
}

bool KeysTrayAdaptor::itemIsMenu() const
{
    return false;
}

QDBusObjectPath KeysTrayAdaptor::menu() const
{
    return QDBusObjectPath(QStringLiteral("/NO_DBUSMENU"));
}

void KeysTrayAdaptor::Activate(int, int)
{
    Q_EMIT m_entry->activated();
}

void KeysTrayAdaptor::SecondaryActivate(int, int)
{
}

void KeysTrayAdaptor::ContextMenu(int, int)
{
}

void KeysTrayAdaptor::Scroll(int, const QString &)
{
}
