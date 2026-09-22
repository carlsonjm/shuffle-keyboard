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
    // The compositor places an input panel again only when a committed input
    // region differs from the one before it, and a mask change reaches it only
    // with the next frame. Clearing the mask and restoring it at once therefore
    // arrives as no change at all. So one frame goes out with the region a
    // pixel shorter at the top, and the region is restored on the frame after:
    // two real changes, each of which places the panel against the work area
    // as it is now. Shortening rather than clearing keeps the panel's bottom
    // edge, which is all the placement reads, and never presents the whole
    // window as the panel for a frame.
    if (m_interactiveRegion.height() < 2 || m_refreshPending) {
        return;
    }
    m_refreshPending = true;
    setMask(QRegion(m_interactiveRegion.adjusted(0, 1, 0, 0)));
    connect(
        this,
        &QQuickWindow::frameSwapped,
        this,
        [this] {
            m_refreshPending = false;
            setMask(QRegion(m_interactiveRegion));
            update();
        },
        Qt::SingleShotConnection);
    update();
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
