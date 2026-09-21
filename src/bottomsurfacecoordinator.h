/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QObject>
#include <qqmlintegration.h>

class BottomSurfaceCoordinator : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(bool keyboardVisible READ keyboardVisible NOTIFY keyboardVisibleChanged)
    Q_PROPERTY(bool requestedVisible READ requestedVisible WRITE setRequestedVisible NOTIFY requestedVisibleChanged)
    Q_PROPERTY(QString error READ error NOTIFY errorChanged)

public:
    explicit BottomSurfaceCoordinator(QObject *parent = nullptr);
    ~BottomSurfaceCoordinator() override;

    bool keyboardVisible() const;
    bool requestedVisible() const;
    void setRequestedVisible(bool visible);
    QString error() const;

Q_SIGNALS:
    void keyboardVisibleChanged();
    void requestedVisibleChanged();
    void errorChanged();
    void reservationRefreshRequested();

private:
    void setKeyboardVisible(bool visible);
    QString evaluate(const QString &script);
    void yieldBottomPanels();
    void restoreBottomPanels();
    void setError(const QString &error);

private Q_SLOTS:
    void syncKeyboardVisibility();

private:
    bool m_keyboardVisible = false;
    bool m_requestedVisible = false;
    QString m_savedPanels;
    QString m_error;
};
