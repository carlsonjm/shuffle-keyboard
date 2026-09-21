/*
    SPDX-FileCopyrightText: 2025 Devin Lin <devin@kde.org>
    SPDX-FileCopyrightText: 2026 Kristen McWilliam <kristen@kde.org>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "inputpanelwindow.h"

#include "inputpanelintegration.h"
#include "plasmakeyboardsettings.h"

#include <KSandbox>
#include <QDesktopServices>
#include <QProcess>
#include <qnamespace.h>

InputPanelWindow::InputPanelWindow(QWindow *parent)
    : QQuickWindow{parent}
{
    setFlag(Qt::FramelessWindowHint);
}

QRect InputPanelWindow::interactiveRegion() const
{
    return m_interactiveRegion;
}

void InputPanelWindow::setInteractiveRegion(QRect interactiveRegion)
{
    if (interactiveRegion == m_interactiveRegion) {
        return;
    }
    m_interactiveRegion = interactiveRegion;
    Q_EMIT interactiveRegionChanged();

    // Set only a part of the window to be interactive
    setMask(QRegion(m_interactiveRegion));
}

void InputPanelWindow::showSettings()
{
    if (KSandbox::isInside()) {
        QProcess::startDetached(QStringLiteral("kcmshell6"), {QStringLiteral("kcm_plasmakeyboard")});
    } else {
        QDesktopServices::openUrl(QUrl(QStringLiteral("systemsettings:kcm_plasmakeyboard")));
    }
}

bool InputPanelWindow::initInputPanel(InputPanelRole::Role role)
{
    return initInputPanelIntegration(this, role);
}

void InputPanelWindow::refreshInteractiveRegion()
{
    const QRect region = m_interactiveRegion;
    setMask(QRegion());
    setMask(QRegion(region));
}

void InputPanelWindow::persistKeyboardHeight(int height)
{
    PlasmaKeyboardSettings::self()->setKeyboardHeight(height);
    PlasmaKeyboardSettings::self()->save();
}

void InputPanelWindow::persistKeyboardWidthPercent(int widthPercent)
{
    PlasmaKeyboardSettings::self()->setKeyboardWidthPercent(widthPercent);
    PlasmaKeyboardSettings::self()->save();
}

#include "moc_inputpanelwindow.cpp"
