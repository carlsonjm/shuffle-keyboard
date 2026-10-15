/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QJsonArray>
#include <QObject>
#include <qqmlintegration.h>

class KeysTrayEntry;
class QDBusServiceWatcher;

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

    // What the Bottom Surface is doing, read as the keys arrive. All of it
    // is absent-safe: with no surface on the bus these stay false and zero.
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

    /**
     * Where the bottom panels' own hiding modes are kept while the Keyboard
     * has set them to autohide. It is written before any panel is changed and
     * removed once the shell has put them back, so a Keyboard that ended
     * without putting them back finds it on its next start and does it then.
     */
    static QString panelStatePath();

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
    /// The keys' tray entry was tapped while they were up: they go, as Hide
    /// puts them.
    void putAwayRequested();
    /// Every report of whether the compositor shows the keys, changed or not.
    /// Two reports can arrive for keys shown and hidden again at once, and
    /// the value read for both is the one at the time of reading.
    void compositorVisibilityChecked(bool visible);

private:
    void setKeyboardVisible(bool visible);
    void toggleKeysFromTray();
    void yieldBottomPanels();
    void restoreBottomPanels();

    /// Ask the Bottom Surface for the region, without waiting for its answer.
    /// Only a bus name nobody owns sends the Keyboard to Plasma's panels: a
    /// surface that refuses, or is too slow to answer, still owns the region,
    /// and the Keyboard then leaves every panel alone.
    void askSurface();
    void releaseSurface();

    /// The fallback where no Bottom Surface is installed: read the bottom
    /// panels' hiding modes, keep them on disk, then set the panels to
    /// autohide. Each step waits on the shell without holding the keys.
    void yieldPanels();
    void restorePanels(const QJsonArray &saved, bool fromLastRun);
    void restoreLastRunPanels();
    void restoreLastRunPanelsOnceShellArrives();

    void readExtent();
    void setError(const QString &error);

private Q_SLOTS:
    void syncKeyboardVisibility();
    void onExtentChanged(const QString &outputName);

private:
    KeysTrayEntry *m_trayEntry = nullptr;
    bool m_keyboardVisible = false;
    bool m_requestedVisible = false;

    /// True from asking the surface for the region until it is given back, so
    /// the hand-back is sent even for an ask that has not been answered yet.
    bool m_surfaceAsked = false;
    /// True once the surface has said yes, so the release goes back the same
    /// way it was taken.
    bool m_surfaceYielded = false;
    /// Counts asks of the surface and of the shell, so an answer that comes
    /// after the keys have gone again is recognised as stale and dropped.
    quint64 m_surfaceRequest = 0;
    quint64 m_panelRequest = 0;
    quint64 m_extentRequest = 0;

    enum class PanelState {
        Untouched,
        Reading,
        Yielded,
    };
    PanelState m_panelState = PanelState::Untouched;
    QJsonArray m_savedPanels;
    QDBusServiceWatcher *m_shellWatcher = nullptr;
    bool m_leaving = false;
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
