/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "bottomsurfacecoordinator.h"

#include <QDBusConnection>
#include <QDBusInterface>
#include <QDBusReply>
#include <QJsonDocument>
#include <QTimer>

BottomSurfaceCoordinator::BottomSurfaceCoordinator(QObject *parent)
    : QObject(parent)
{
    QDBusConnection::sessionBus().connect(QStringLiteral("org.kde.KWin"),
                                          QStringLiteral("/VirtualKeyboard"),
                                          QStringLiteral("org.kde.kwin.VirtualKeyboard"),
                                          QStringLiteral("visibleChanged"),
                                          this,
                                          SLOT(syncKeyboardVisibility()));
    QTimer::singleShot(0, this, &BottomSurfaceCoordinator::syncKeyboardVisibility);
}

void BottomSurfaceCoordinator::syncKeyboardVisibility()
{
    QDBusInterface keyboard(QStringLiteral("org.kde.KWin"),
                            QStringLiteral("/VirtualKeyboard"),
                            QStringLiteral("org.kde.kwin.VirtualKeyboard"),
                            QDBusConnection::sessionBus());
    setKeyboardVisible(keyboard.isValid() && keyboard.property("visible").toBool());
}

BottomSurfaceCoordinator::~BottomSurfaceCoordinator()
{
    restoreBottomPanels();
}

bool BottomSurfaceCoordinator::keyboardVisible() const
{
    return m_keyboardVisible;
}

bool BottomSurfaceCoordinator::requestedVisible() const
{
    return m_requestedVisible;
}

void BottomSurfaceCoordinator::setRequestedVisible(bool visible)
{
    if (m_requestedVisible == visible) {
        return;
    }
    m_requestedVisible = visible;
    Q_EMIT requestedVisibleChanged();

    if (!visible) {
        restoreBottomPanels();
        return;
    }

    QDBusInterface keyboard(QStringLiteral("org.kde.KWin"),
                            QStringLiteral("/VirtualKeyboard"),
                            QStringLiteral("org.kde.kwin.VirtualKeyboard"),
                            QDBusConnection::sessionBus());
    const QDBusReply<bool> willShow = keyboard.call(QStringLiteral("willShowOnActive"));
    if (m_keyboardVisible || (willShow.isValid() && willShow.value())) {
        yieldBottomPanels();
    }
}

void BottomSurfaceCoordinator::setKeyboardVisible(bool visible)
{
    if (m_keyboardVisible == visible) {
        return;
    }
    m_keyboardVisible = visible;
    Q_EMIT keyboardVisibleChanged();

    if (visible) {
        yieldBottomPanels();
    } else if (!m_requestedVisible) {
        restoreBottomPanels();
    }
}

QString BottomSurfaceCoordinator::error() const
{
    return m_error;
}

QString BottomSurfaceCoordinator::evaluate(const QString &script)
{
    QDBusInterface shell(QStringLiteral("org.kde.plasmashell"),
                         QStringLiteral("/PlasmaShell"),
                         QStringLiteral("org.kde.PlasmaShell"),
                         QDBusConnection::sessionBus());
    if (!shell.isValid()) {
        setError(QStringLiteral("Plasma Shell is not available"));
        return {};
    }

    const QDBusReply<QString> reply = shell.call(QStringLiteral("evaluateScript"), script);
    if (!reply.isValid()) {
        setError(reply.error().message());
        return {};
    }
    setError({});
    return reply.value();
}

void BottomSurfaceCoordinator::yieldBottomPanels()
{
    if (!m_savedPanels.isEmpty()) {
        return;
    }

    const QString script = QStringLiteral(R"JS(
        const saved = [];
        panels().forEach(panel => {
            if (panel.location === "bottom") {
                saved.push({ id: panel.id, hiding: panel.hiding });
                panel.hiding = "autohide";
            }
        });
        print(JSON.stringify(saved));
    )JS");
    m_savedPanels = evaluate(script);
    Q_EMIT reservationRefreshRequested();
}

void BottomSurfaceCoordinator::restoreBottomPanels()
{
    if (m_savedPanels.isEmpty()) {
        return;
    }

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(m_savedPanels.toUtf8(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isArray()) {
        setError(QStringLiteral("Could not restore bottom panel state"));
        m_savedPanels.clear();
        return;
    }

    const QString serialized = QString::fromUtf8(document.toJson(QJsonDocument::Compact));
    const QString script = QStringLiteral(R"JS(
        const saved = %1;
        saved.forEach(entry => {
            const panel = panelById(entry.id);
            if (panel && panel.location === "bottom" && panel.hiding === "autohide") {
                panel.hiding = entry.hiding;
            }
        });
    )JS")
                               .arg(serialized);
    evaluate(script);
    m_savedPanels.clear();
}

void BottomSurfaceCoordinator::setError(const QString &error)
{
    if (m_error == error) {
        return;
    }
    m_error = error;
    Q_EMIT errorChanged();
}
