/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QQuickWindow>
#include <QRect>
#include <qqmlintegration.h>

/**
 * The window the drag handle lives in.
 *
 * It cannot be part of the keyboard's own window. That window is an input
 * panel, and the compositor unmaps it the moment text input goes away --- which
 * is exactly when the handle has to be on screen. So the handle is a surface of
 * its own, placed by the compositor against the bottom edge.
 *
 * It claims only the bar. The surface is placed against the Bottom Surface's
 * band and reserves exactly the bar's height while the bar is shown, so the
 * work area stops above it and whatever keeps a gutter above the work area
 * keeps it above the bar as well. The rest of the surface overlays that gutter,
 * which is empty by design.
 *
 * The surface spans the output and only the handle inside it takes touches.
 * The alternative --- a surface the width of the handle --- has to be resized
 * every time the application row grows, and a layer surface resizes by asking
 * the compositor and waiting, so the window is briefly the wrong size and
 * sometimes stays there. A fixed surface with a moving interactive region has
 * no such moment.
 */
class HandleWindow : public QQuickWindow
{
    Q_OBJECT
    QML_ELEMENT

    /// Whether this window was given a layer surface at all. With no layer
    /// shell there is nowhere for the handle to be, and it stays away rather
    /// than appearing somewhere wrong.
    Q_PROPERTY(bool placed READ placed CONSTANT)

    /// The only part of this window that takes input. Everything outside it
    /// passes through to whatever is beneath, which is most of the screen's
    /// width.
    Q_PROPERTY(QRect interactiveRegion READ interactiveRegion WRITE setInteractiveRegion NOTIFY interactiveRegionChanged)
    /// How much of the bottom edge this surface reserves from the work area.
    Q_PROPERTY(int reservation READ reservation WRITE setReservation NOTIFY reservationChanged)
    /// The output this window belongs on. It is rebuilt there whenever that
    /// changes or a display comes or goes, because a layer surface is tied to
    /// one output and is not remade when that output leaves.
    Q_PROPERTY(QString home READ home WRITE setHome NOTIFY homeChanged)
    /// The output the window is on now.
    Q_PROPERTY(QString screenName READ screenName NOTIFY screenNameChanged)

public:
    explicit HandleWindow(QWindow *parent = nullptr);

    bool placed() const;

    QRect interactiveRegion() const;
    void setInteractiveRegion(QRect interactiveRegion);
    int reservation() const;
    void setReservation(int reservation);

    /// Applied again after the surface has been created, because hiding the
    /// window destroys it and a region set against the old one is gone.
    Q_INVOKABLE void refreshInteractiveRegion();

    QString home() const;
    void setHome(const QString &home);
    QString screenName() const;

Q_SIGNALS:
    void interactiveRegionChanged();
    void reservationChanged();
    void homeChanged();
    void screenNameChanged();

private:
    void rehome(bool screenLost);
    QString m_home;
    bool m_placed = false;
    int m_reservation = 0;
    QRect m_interactiveRegion;
};
