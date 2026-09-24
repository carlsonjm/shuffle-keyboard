/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QObject>
#include <QVariantMap>
#include <qqmlintegration.h>

class PrecisionController : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    Q_PROPERTY(State state READ state NOTIFY stateChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY stateChanged)
    Q_PROPERTY(QString message READ message NOTIFY stateChanged)

public:
    enum State {
        Idle,
        Connecting,
        Ready,
        Denied,
        Failed,
    };
    Q_ENUM(State)

    explicit PrecisionController(QObject *parent = nullptr);
    ~PrecisionController() override;

    State state() const;
    bool ready() const;
    QString message() const;

    Q_INVOKABLE void ensureSession();
    /// Opens the session ahead of use, but only where access was granted
    /// before and restores without asking, so the first slide of the space
    /// bar is not spent waiting and no prompt interrupts typing.
    Q_INVOKABLE void warmIfGranted();
    Q_INVOKABLE void keepKeyboardVisible();
    Q_INVOKABLE void move(qreal dx, qreal dy);
    Q_INVOKABLE void scroll(qreal dx, qreal dy, bool finished = false);
    Q_INVOKABLE void primaryClick();
    Q_INVOKABLE void secondaryClick();
    Q_INVOKABLE void primaryDown();
    Q_INVOKABLE void primaryUp();

Q_SIGNALS:
    void stateChanged();

private Q_SLOTS:
    void handleCreateResponse(uint response, const QVariantMap &results);
    void handleSelectResponse(uint response, const QVariantMap &results);
    void handleStartResponse(uint response, const QVariantMap &results);

private:
    QString token(const QString &prefix) const;
    bool watchRequest(const QString &path, const char *slot);
    void setState(State state, const QString &message = {});
    void selectDevices();
    void startSession();
    void notifyButton(int button, uint state);

    State m_state = Idle;
    QString m_message;
    QString m_sessionPath;
    QString m_restoreToken;
    bool m_primaryPressed = false;
};
