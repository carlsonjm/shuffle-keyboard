/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QObject>

/**
 * Kadunce, the compositor effect, when it is running. An isolated test names a
 * stand-in of its own in its place, since only the compositor can own this
 * name.
 */
inline QString kadunceService()
{
    const QString probe = qEnvironmentVariable("SHUFFLE_PROBE_KADUNCE_SERVICE");
    return probe.isEmpty() ? QStringLiteral("org.kde.KWin") : probe;
}

/**
 * Asks for the keys on the person's behalf.
 *
 * Kadunce, when it is running, keeps down any keys nobody asked for, and a
 * request made straight to the compositor looks to it like an application
 * focusing its own field. So the request goes through Kadunce first, which
 * marks it as asked and raises the keys itself. With no Kadunce the compositor
 * is asked directly, exactly as before Kadunce had a say.
 */
inline void requestKeys(QObject *context)
{
    const auto direct = [] {
        QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"),
                                                                               QStringLiteral("/VirtualKeyboard"),
                                                                               QStringLiteral("org.kde.kwin.VirtualKeyboard"),
                                                                               QStringLiteral("forceActivate")));
    };
    const QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(kadunceService(),
                                                                                                         QStringLiteral("/Kadunce"),
                                                                                                         QStringLiteral("studio.warbler.Kadunce"),
                                                                                                         QStringLiteral("raiseKeyboard")));
    auto *watcher = new QDBusPendingCallWatcher(call, context);
    QObject::connect(watcher, &QDBusPendingCallWatcher::finished, context, [direct](QDBusPendingCallWatcher *finished) {
        if (finished->isError()) {
            direct();
        }
        finished->deleteLater();
    });
}

/**
 * Tells Kadunce where the keys are going: they come to rest `height` pixels
 * tall above their screen's bottom edge, 0 when they leave, in `durationMs`.
 *
 * Kadunce draws the card above the keys following them on every frame and
 * asks its application for a new size once a motion rather than once a frame,
 * so it needs to know the destination before the keys arrive. With no
 * Kadunce, or one that does not listen, nothing answers and nothing needs to.
 */
inline void announceKeys(double height, int durationMs)
{
    QDBusMessage message = QDBusMessage::createMethodCall(kadunceService(),
                                                          QStringLiteral("/Kadunce"),
                                                          QStringLiteral("studio.warbler.Kadunce"),
                                                          QStringLiteral("keyboardHeading"));
    message << height << durationMs;
    message.setAutoStartService(false);
    QDBusConnection::sessionBus().send(message);
}
