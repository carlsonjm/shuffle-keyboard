/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QDBusAbstractAdaptor>
#include <QDBusObjectPath>
#include <QObject>

class QDBusServiceWatcher;

/**
 * The keys' entry in the system tray, so they can be called when no text field
 * asks for them.
 *
 * It speaks the StatusNotifierItem protocol itself, because KDE's ready-made
 * item needs the widget toolkit, which this process does not load. It has no
 * menu: a tap is its one action.
 */
class KeysTrayEntry : public QObject
{
    Q_OBJECT

public:
    explicit KeysTrayEntry(QObject *parent = nullptr);

    QString serviceName() const;

Q_SIGNALS:
    /// The entry was tapped or clicked.
    void activated();

private:
    void registerWithTray();

    QString m_serviceName;
    QDBusServiceWatcher *m_trayWatcher = nullptr;
};

class KeysTrayAdaptor : public QDBusAbstractAdaptor
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.kde.StatusNotifierItem")
    Q_PROPERTY(QString Category READ category)
    Q_PROPERTY(QString Id READ id)
    Q_PROPERTY(QString Title READ title)
    Q_PROPERTY(QString Status READ status)
    Q_PROPERTY(int WindowId READ windowId)
    Q_PROPERTY(QString IconThemePath READ none)
    Q_PROPERTY(QString IconName READ iconName)
    Q_PROPERTY(QString OverlayIconName READ none)
    Q_PROPERTY(QString AttentionIconName READ none)
    Q_PROPERTY(QString AttentionMovieName READ none)
    Q_PROPERTY(bool ItemIsMenu READ itemIsMenu)
    Q_PROPERTY(QDBusObjectPath Menu READ menu)

public:
    explicit KeysTrayAdaptor(KeysTrayEntry *entry);

    QString category() const;
    QString id() const;
    QString title() const;
    QString status() const;
    int windowId() const;
    QString none() const;
    QString iconName() const;
    bool itemIsMenu() const;
    QDBusObjectPath menu() const;

public Q_SLOTS:
    void Activate(int x, int y);
    void SecondaryActivate(int x, int y);
    void ContextMenu(int x, int y);
    void Scroll(int delta, const QString &orientation);

Q_SIGNALS:
    void NewTitle();
    void NewIcon();
    void NewAttentionIcon();
    void NewOverlayIcon();
    void NewToolTip();
    void NewStatus(const QString &status);

private:
    KeysTrayEntry *m_entry;
};
