/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "handlewindow.h"

#include <LayerShellQt/Window>

#include <QGuiApplication>

HandleWindow::HandleWindow(QWindow *parent)
    : QQuickWindow(parent)
{
    setColor(Qt::transparent);
    setFlag(Qt::FramelessWindowHint);

    if (!QGuiApplication::platformName().startsWith(QLatin1String("wayland"))) {
        return;
    }

    // Attached before the window is ever shown, because this is what decides
    // which shell protocol the surface is created with. A window that has been
    // mapped once is already the wrong kind.
    auto *layer = LayerShellQt::Window::get(this);
    if (!layer) {
        return;
    }
    m_placed = true;

    // Anchored to three edges, so the compositor gives it the output's width
    // and the client only ever chooses its height.
    layer->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorBottom) | LayerShellQt::Window::AnchorLeft | LayerShellQt::Window::AnchorRight);
    // The layer below the dock's. KWin gives reserved space layer by layer,
    // top before bottom, and only then in the order surfaces were created; the
    // Keyboard starts before the shell, so on the same layer the bar would take
    // the very edge and the dock's band would sit on top of it. One layer down,
    // it is always placed on the band. Windows draw over this layer, and none
    // reaches it, because the bar reserves its own height.
    layer->setLayer(LayerShellQt::Window::LayerBottom);

    // Zero until the bar is shown: it asks to be placed inside what is left
    // after every other exclusive zone and to claim none itself. The bar's own
    // height is reserved only while it is drawn.
    layer->setExclusiveZone(0);

    layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
    layer->setActivateOnShow(false);
    layer->setScope(QStringLiteral("shuffle-keyboard-handle"));

    // An output going away must not take the handle with it. The window is
    // reused on whichever output remains.
    layer->setCloseOnDismissed(false);
}

bool HandleWindow::placed() const
{
    return m_placed;
}

int HandleWindow::reservation() const
{
    return m_reservation;
}

void HandleWindow::setReservation(int reservation)
{
    if (reservation == m_reservation) {
        return;
    }
    m_reservation = reservation;
    Q_EMIT reservationChanged();

    if (!m_placed) {
        return;
    }
    if (auto *layer = LayerShellQt::Window::get(this)) {
        layer->setExclusiveZone(m_reservation);
    }
}

QRect HandleWindow::interactiveRegion() const
{
    return m_interactiveRegion;
}

void HandleWindow::setInteractiveRegion(QRect interactiveRegion)
{
    if (interactiveRegion == m_interactiveRegion) {
        return;
    }
    m_interactiveRegion = interactiveRegion;
    Q_EMIT interactiveRegionChanged();

    setMask(QRegion(m_interactiveRegion));
}

void HandleWindow::refreshInteractiveRegion()
{
    const QRect region = m_interactiveRegion;
    setMask(QRegion());
    setMask(QRegion(region));
}
