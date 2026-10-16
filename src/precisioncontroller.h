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

class DirectPointer;
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

    /// The pointer the compositor trusts the Keyboard with, used in place of
    /// the portal whenever it is available. It outlives every controller.
    static void setDirectPointer(DirectPointer *pointer);

    Q_INVOKABLE void ensureSession();
    /// Closes the session once the surface is no longer in use. Plasma shows
    /// pointer control for as long as a session is open, so it is open only
    /// while the precision surface is latched.
    Q_INVOKABLE void release();
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
    void closeSession();
    void setState(State state, const QString &message = {});
    void selectDevices();
    void startSession();
    void notify(const QString &method, const QList<QVariant> &arguments);
    void notifyButton(int button, uint state);
    bool direct() const;

    State m_state = Idle;
    QString m_message;
    QString m_sessionPath;
    QString m_restoreToken;
    Step m_step = Step::None;
    QStringList m_requestPaths;
    QDBusServiceWatcher *m_portalWatcher = nullptr;
    QTimer m_answerTimeout;
    bool m_primaryPressed = false;
    bool m_wanted = false;
};
