/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QDBusConnection>
#include <QDBusMessage>
#include <QDBusPendingCallWatcher>
#include <QDBusPendingReply>
#include <QDBusVariant>
#include <QObject>

#include <functional>

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
    const QDBusPendingCall call = QDBusConnection::sessionBus().asyncCall(
        QDBusMessage::createMethodCall(kadunceService(), QStringLiteral("/Kadunce"), QStringLiteral("co.goodinput.Kadunce"), QStringLiteral("raiseKeyboard")));
    auto *watcher = new QDBusPendingCallWatcher(call, context);
    QObject::connect(watcher, &QDBusPendingCallWatcher::finished, context, [direct](QDBusPendingCallWatcher *finished) {
        if (finished->isError()) {
            direct();
        }
        finished->deleteLater();
    });
}

/**
 * Shows the keys for a text field that has just taken the focus, when the
 * compositor would have shown them itself but threw the request away.
 *
 * KWin 6.8.1 drops an application's request for the keys that arrives before
 * its field counts as active, and Qt sends that request just ahead of the
 * field's first commit, so a tapped field is left with no keys. If the
 * compositor shows none and the last touch is one it would show them for, it
 * is asked directly. Directly, not through Kadunce: to Kadunce this is an
 * application focusing its own field, which it may keep the keys down for,
 * never a request made on the person's behalf. The caller stops wanting it
 * once the compositor has shown keys for the field, since keys it showed and
 * that went again were put away on purpose.
 */
inline void showKeysForField(QObject *context, const std::function<bool()> &stillWanted)
{
    const auto call = [](const QString &interface, const QString &method, const QVariantList &arguments = {}) {
        QDBusMessage message = QDBusMessage::createMethodCall(QStringLiteral("org.kde.KWin"), QStringLiteral("/VirtualKeyboard"), interface, method);
        message.setArguments(arguments);
        return QDBusConnection::sessionBus().asyncCall(message);
    };
    const QString keyboard = QStringLiteral("org.kde.kwin.VirtualKeyboard");
    auto *willShow = new QDBusPendingCallWatcher(call(keyboard, QStringLiteral("willShowOnActive")), context);
    QObject::connect(willShow, &QDBusPendingCallWatcher::finished, context, [=](QDBusPendingCallWatcher *finished) {
        finished->deleteLater();
        const QDBusPendingReply<bool> wanted = *finished;
        if (wanted.isError() || !wanted.value() || !stillWanted()) {
            return;
        }
        const QDBusPendingCall visibleCall =
            call(QStringLiteral("org.freedesktop.DBus.Properties"), QStringLiteral("Get"), {keyboard, QStringLiteral("visible")});
        auto *visible = new QDBusPendingCallWatcher(visibleCall, context);
        QObject::connect(visible, &QDBusPendingCallWatcher::finished, context, [=](QDBusPendingCallWatcher *shown) {
            shown->deleteLater();
            const QDBusPendingReply<QDBusVariant> reply = *shown;
            if (reply.isError() || reply.value().variant().toBool() || !stillWanted()) {
                return;
            }
            call(keyboard, QStringLiteral("forceActivate"));
        });
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
    QDBusMessage message =
        QDBusMessage::createMethodCall(kadunceService(), QStringLiteral("/Kadunce"), QStringLiteral("co.goodinput.Kadunce"), QStringLiteral("keyboardHeading"));
    message << height << durationMs;
    message.setAutoStartService(false);
    QDBusConnection::sessionBus().send(message);
}
