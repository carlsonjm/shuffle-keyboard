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
    const QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"),
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
