/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QObject>
#include <qqmlintegration.h>

class KeysTrayEntry;

/**
 * The Keyboard's whole relationship with the Bottom Surface.
 *
 * One instance, because there is one region and one holder of it; two of these
 * would mean two clients each believing they hold the region, which is the
 * state the contract exists to prevent.
 */
class BottomSurfaceCoordinator : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool keyboardVisible READ keyboardVisible NOTIFY keyboardVisibleChanged)
    Q_PROPERTY(bool requestedVisible READ requestedVisible WRITE setRequestedVisible NOTIFY requestedVisibleChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

    // What the Bottom Surface is doing, for the handle on the keys, which
    // takes the application row's place and width. All of it is absent-safe:
    // with no surface on the bus these stay false and zero, and the handle
    // keeps a width of its own.
    Q_PROPERTY(bool surfacePresent READ surfacePresent NOTIFY extentChanged)
    Q_PROPERTY(int bandHeight READ bandHeight NOTIFY extentChanged)
    Q_PROPERTY(int dockLeft READ dockLeft NOTIFY extentChanged)
    Q_PROPERTY(int dockWidth READ dockWidth NOTIFY extentChanged)
    /// Whether the surface still holds its reservation. The keys arrive only
    /// once it has gone, so they rise from the screen's edge rather than from
    /// a band that is leaving.
    Q_PROPERTY(bool regionReserving READ regionReserving NOTIFY regionReservingChanged)

public:
    explicit BottomSurfaceCoordinator(QObject *parent = nullptr);
    ~BottomSurfaceCoordinator() override;

    bool keyboardVisible() const;
    bool surfacePresent() const;
    int bandHeight() const;
    int dockLeft() const;
    int dockWidth() const;
    bool requestedVisible() const;
    void setRequestedVisible(bool visible);
    QString error() const;

    /**
     * Ask the compositor to show the keyboard when nothing asked for text.
     *
     * A raise Kadunce announced that has not shown the keys tries this while
     * it holds the focus, for a compositor that offers no text input to ask
     * with. It goes through Kadunce when Kadunce is running.
     */
    Q_INVOKABLE void raiseKeyboard();

    /// Where the keys are going: they rest `height` pixels tall above the
    /// screen's bottom edge, 0 when leaving, in `durationMs`.
    Q_INVOKABLE void announceHeading(double height, int durationMs);

    /// Ask the keyboard's own window to become Qt's focus window again, after
    /// another of this process's surfaces has held the compositor's focus.
    Q_INVOKABLE void reclaimKeyboardFocus();

    bool regionReserving() const;

Q_SIGNALS:
    void keyboardVisibleChanged();
    void requestedVisibleChanged();
    void errorChanged();
    void extentChanged();
    void reservationRefreshRequested();
    void keyboardFocusReclaimRequested();
    void regionReservingChanged();
    /// The keys' tray entry asked for them. The compositor has been asked
    /// already; this is for a cold start, where that ask alone shows nothing.
    void keysRequested();
    /// The keys' tray entry was tapped while they were up: they go, as the
    /// handle takes them.
    void putAwayRequested();
    /// Every report of whether the compositor shows the keys, changed or not.
    /// Two reports can arrive for keys shown and hidden again at once, and
    /// the value read for both is the one at the time of reading.
    void compositorVisibilityChecked(bool visible);

private:
    void setKeyboardVisible(bool visible);
    void toggleKeysFromTray();
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
    void onExtentChanged(const QString &outputName);

private:
    KeysTrayEntry *m_trayEntry = nullptr;
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

    /// Whether the surface still holds its reservation. A surface that does not
    /// publish it is taken to hold it, which is what every surface did before
    /// the field existed.
    bool m_regionReserving = true;
    QString m_error;
};
