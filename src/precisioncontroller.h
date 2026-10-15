/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QObject>
#include <QStringList>
#include <QTimer>
#include <QVariantMap>
#include <qqmlintegration.h>

class QDBusPendingCallWatcher;
class QDBusServiceWatcher;

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
    void handleResponse(uint response, const QVariantMap &results);
    void handleSessionClosed(const QVariantMap &details);

private:
    enum class Step {
        None,
        Create,
        Select,
        Start,
    };

    /// Asks the portal for one step of the session. The answer arrives as a
    /// Response signal on a request object the portal names after the
    /// handle_token, and it can arrive before the call itself returns, so the
    /// answer is listened for on that predicted path before the call goes out.
    void ask(Step step, const QString &method, QList<QVariant> arguments, QVariantMap options);
    void stopListening();
    void endSession(const QString &message, State state = Idle);
    void setState(State state, const QString &message = {});
    void selectDevices();
    void startSession();
    void notify(const QString &method, const QList<QVariant> &arguments);
    void notifyButton(int button, uint state);

    State m_state = Idle;
    QString m_message;
    QString m_sessionPath;
    QString m_restoreToken;
    Step m_step = Step::None;
    QStringList m_requestPaths;
    QDBusServiceWatcher *m_portalWatcher = nullptr;
    QTimer m_answerTimeout;
    bool m_primaryPressed = false;
};
