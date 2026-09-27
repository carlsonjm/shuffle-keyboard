/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QObject>
#include <qqmlintegration.h>

/**
 * The Keyboard's whole relationship with the Bottom Surface.
 *
 * One instance, because there is one region and one holder of it. The keyboard
 * window and the handle window are separate surfaces in the same process and
 * both need this; two of these would mean two clients each believing they hold
 * the region, which is the state the contract exists to prevent.
 */
class BottomSurfaceCoordinator : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool keyboardVisible READ keyboardVisible NOTIFY keyboardVisibleChanged)
    Q_PROPERTY(bool requestedVisible READ requestedVisible WRITE setRequestedVisible NOTIFY requestedVisibleChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

    // What the Bottom Surface is doing, for the handle that sits above it.
    // All of it is absent-safe: with no surface on the bus these stay false
    // and zero, and the handle simply does not appear.
    Q_PROPERTY(bool surfacePresent READ surfacePresent NOTIFY extentChanged)
    Q_PROPERTY(int bandHeight READ bandHeight NOTIFY extentChanged)
    Q_PROPERTY(int dockLeft READ dockLeft NOTIFY extentChanged)
    Q_PROPERTY(int dockWidth READ dockWidth NOTIFY extentChanged)
    Q_PROPERTY(bool regionObscured READ regionObscured NOTIFY extentChanged)
    /// Whether the surface still holds its reservation. The keys arrive only
    /// once it has gone, so they rise from the screen's edge rather than from
    /// a band that is leaving.
    Q_PROPERTY(bool regionReserving READ regionReserving NOTIFY regionReservingChanged)
    /// The output the dock is on, as the surface publishes it.
    Q_PROPERTY(QString dockOutput READ dockOutput NOTIFY extentChanged)
    /// The output the handle belongs on: the one Kadunce holds cards on when
    /// it is running, since that is the touch display, and otherwise the
    /// dock's.
    Q_PROPERTY(QString handleHome READ handleHome NOTIFY extentChanged)

public:
    explicit BottomSurfaceCoordinator(QObject *parent = nullptr);
    ~BottomSurfaceCoordinator() override;

    bool keyboardVisible() const;
    bool surfacePresent() const;
    int bandHeight() const;
    int dockLeft() const;
    int dockWidth() const;
    bool regionObscured() const;
    QString dockOutput() const;
    QString handleHome() const;
    bool requestedVisible() const;
    void setRequestedVisible(bool visible);
    QString error() const;

    /**
     * Ask the compositor to show the keyboard when nothing asked for text.
     *
     * This is what the handle is for. Everywhere else the keyboard appears
     * because a text field was touched; here the user is reaching for it
     * directly, so the request goes to the compositor rather than pretending
     * an input focus exists.
     */
    Q_INVOKABLE void raiseKeyboard();

    /// Where the keys are going: they rest `height` pixels tall above the
    /// screen's bottom edge, 0 when leaving, in `durationMs`.
    Q_INVOKABLE void announceHeading(double height, int durationMs);

    /// Ask the keyboard's own window to become Qt's focus window again, after
    /// another of this process's surfaces has held the compositor's focus.
    Q_INVOKABLE void reclaimKeyboardFocus();

    /**
     * A pull on the handle: the finger's height above the output's bottom
     * edge in logical pixels, while it is down and once when it lifts with
     * its upward speed. The dock's pulls arrive the same way over the bus, so
     * the keys follow a finger wherever the pull began.
     */
    Q_INVOKABLE void reportPull(double travel, bool active, double velocity);

    bool regionReserving() const;

Q_SIGNALS:
    void keyboardVisibleChanged();
    void requestedVisibleChanged();
    void errorChanged();
    void extentChanged();
    void reservationRefreshRequested();
    void keyboardFocusReclaimRequested();
    void regionReservingChanged();
    void keyboardPulled(double travel, bool active, double velocity);
    /// Someone reached for the keyboard from the dock rather than the handle.
    void keyboardRequested();

private:
    void setKeyboardVisible(bool visible);
    QString evaluate(const QString &script);
    void yieldBottomPanels();
    void restoreBottomPanels();

    /// Ask the Bottom Surface for the region. False means there is no surface
    /// to ask, not that it refused --- the caller then falls back to the panel
    /// behaviour this component has always had.
    bool askSurface(bool yield);
    void readExtent();
    void setError(const QString &error);

private Q_SLOTS:
    void syncKeyboardVisibility();
    void onSurfacePull(double travel, bool active, double velocity);
    void onExtentChanged(const QString &outputName);

private:
    bool m_keyboardVisible = false;
    bool m_requestedVisible = false;
    QString m_savedPanels;

    /// True while the surface is the one that yielded, so the release goes
    /// back the same way it was taken.
    bool m_surfaceYielded = false;
    bool m_surfacePresent = false;
    int m_bandHeight = 0;
    int m_dockLeft = 0;
    int m_dockWidth = 0;
    QString m_dockOutput;
    QString m_handleHome;
    bool m_regionObscured = false;

    /// Whether the surface still holds its reservation. A surface that does not
    /// publish it is taken to hold it, which is what every surface did before
    /// the field existed.
    bool m_regionReserving = true;
    QString m_error;
};
