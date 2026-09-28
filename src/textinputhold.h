/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QObject>
#include <QtWaylandClient/QWaylandClientExtensionTemplate>
#include <qqmlintegration.h>

#include <memory>

#include <qwayland-text-input-unstable-v3.h>

class TextInputHoldInput;

/**
 * A text field the compositor can see, held by the Keyboard itself.
 *
 * Plasma lets a raised keyboard show only after a text field has asked for it
 * while touch was the last input, so a raise Kadunce asks for from the bottom
 * bezel does nothing until the user has touched some field. The Keyboard's own fields
 * cannot ask: this process runs Qt's virtual keyboard in-process, so Qt never
 * speaks text input to the compositor on its behalf. This speaks it directly,
 * enabling a text input on whichever of this process's surfaces holds the
 * focus, for as long as it is held.
 */
class TextInputHold : public QWaylandClientExtensionTemplate<TextInputHold>, public QtWayland::zwp_text_input_manager_v3
{
    Q_OBJECT
    QML_ELEMENT
    /// Whether the compositor currently sees an enabled text input from here.
    Q_PROPERTY(bool held READ held NOTIFY heldChanged)

public:
    TextInputHold();
    ~TextInputHold() override;

    bool held() const;

    /// Present a text field as soon as one of this process's surfaces has the
    /// focus, and keep presenting it until release().
    Q_INVOKABLE void hold();
    Q_INVOKABLE void release();

Q_SIGNALS:
    void heldChanged();

private:
    friend class TextInputHoldInput;

    void ensureInput();
    void apply();

    std::unique_ptr<TextInputHoldInput> m_input;
    bool m_wanted = false;
    bool m_held = false;
};
