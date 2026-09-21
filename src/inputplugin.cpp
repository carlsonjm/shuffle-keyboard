/*
    SPDX-FileCopyrightText: 2024 Aleix Pol i Gonzalez <aleixpol@kde.org>
    SPDX-FileCopyrightText: 2024 David Edmundson <davidedmundson@kde.org>

    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "inputplugin.h"
#include "inputmethod_p.h"

#include <xkbcommon/xkbcommon-keysyms.h>

InputPlugin::InputPlugin(InputMethod *inputMethod)
{
    connect(inputMethod, &InputMethod::deactivate, this, &InputPlugin::deactivate);
    connect(inputMethod, &InputMethod::activityChanged, this, [this, inputMethod]() {
        if (m_context) {
            disconnect(m_context.get(), nullptr, this, nullptr);
        }
        m_keyboard.reset();
        m_context = inputMethod->current();
        Q_EMIT contextChanged();
        Q_EMIT surroundingTextChanged();
        if (!m_context) {
            return;
        }

        connect(m_context.get(), &InputMethodContext::receivedCommit, this, &InputPlugin::receivedCommit);
        connect(m_context.get(), &InputMethodContext::surroundingTextChanged, this, &InputPlugin::surroundingTextChanged);
        connect(m_context.get(), &InputMethodContext::contentTypeChanged, this, &InputPlugin::contentTypeChanged);
        connect(m_context.get(), &InputMethodContext::reset, this, &InputPlugin::resetRequested);
        connect(m_context.get(), &InputMethodContext::preferredLanguageChanged, this, &InputPlugin::preferredLanguageChanged);
        if (m_grabbing) {
            setGrabbingInternal();
        }
    });
}

InputPlugin::~InputPlugin()
{
}

void InputPlugin::setGrabbing(bool grabbing)
{
    m_grabbing = grabbing;
    if (m_context && grabbing) {
        setGrabbingInternal();
    }
    if (m_keyboard && !grabbing) {
        disconnect(m_keyboard.get(), nullptr, this, nullptr);
        m_keyboard.reset();
    }
}

void InputPlugin::setPreEditString(const QString &text)
{
    if (!m_context) {
        return;
    }
    m_context->preedit_string(m_context->m_latestSerial, text, text);
}

void InputPlugin::moveCursor(int cusorPosition, int anchorPosition)
{
    if (!m_context) {
        return;
    }
    m_context->cursor_position(cusorPosition, anchorPosition);
}

void InputPlugin::setPreEditCursor(int cursorPosition)
{
    if (!m_context) {
        return;
    }
    m_context->preedit_cursor(cursorPosition);
}

void InputPlugin::setPreEditStyle(int startPosition, int length, int style)
{
    if (!m_context) {
        return;
    }
    m_context->preedit_styling(startPosition, length, style);
}

void InputPlugin::deleteSurroundingText(int index, int length)
{
    if (!m_context) {
        return;
    }
    m_context->delete_surrounding_text(index, length);
}

void InputPlugin::commit(const QString &text)
{
    if (!m_context) {
        return;
    }
    m_context->commit_string(m_context->m_latestSerial, text);
}

void InputPlugin::keysym(uint timestamp, uint sym, KeyState state, uint modifiers)
{
    if (!m_context) {
        return;
    }
    m_context->keysym(m_context->m_latestSerial, timestamp, sym, state, modifiers);
}

void InputPlugin::key(KeyState state, quint32 scancode)
{
    if (!m_context) {
        return;
    }
    m_context->key(m_context->m_lastKeyboardSerial, m_context->m_lastKeyboardTime, scancode, static_cast<uint32_t>(state));
}

bool InputPlugin::sendShortcut(int qtKey, int qtModifiers)
{
    if (!m_context || !m_keyboard) {
        return false;
    }

    xkb_keysym_t targetSym = XKB_KEY_NoSymbol;
    switch (qtKey) {
    case Qt::Key_Backspace:
        targetSym = XKB_KEY_BackSpace;
        break;
    case Qt::Key_Return:
    case Qt::Key_Enter:
        targetSym = XKB_KEY_Return;
        break;
    case Qt::Key_Tab:
        targetSym = XKB_KEY_Tab;
        break;
    case Qt::Key_Escape:
        targetSym = XKB_KEY_Escape;
        break;
    case Qt::Key_Delete:
        targetSym = XKB_KEY_Delete;
        break;
    case Qt::Key_Left:
        targetSym = XKB_KEY_Left;
        break;
    case Qt::Key_Right:
        targetSym = XKB_KEY_Right;
        break;
    case Qt::Key_Up:
        targetSym = XKB_KEY_Up;
        break;
    case Qt::Key_Down:
        targetSym = XKB_KEY_Down;
        break;
    case Qt::Key_Home:
        targetSym = XKB_KEY_Home;
        break;
    case Qt::Key_End:
        targetSym = XKB_KEY_End;
        break;
    case Qt::Key_PageUp:
        targetSym = XKB_KEY_Prior;
        break;
    case Qt::Key_PageDown:
        targetSym = XKB_KEY_Next;
        break;
    case Qt::Key_Meta:
    case Qt::Key_Super_L:
        targetSym = XKB_KEY_Super_L;
        break;
    default:
        if (qtKey >= Qt::Key_Space && qtKey <= Qt::Key_AsciiTilde) {
            targetSym = xkb_utf32_to_keysym(static_cast<uint32_t>(qtKey));
        }
        break;
    }
    if (targetSym == XKB_KEY_NoSymbol) {
        return false;
    }

    quint32 requestedModifiers = 0;
    if (qtModifiers & Qt::ControlModifier) {
        requestedModifiers |= m_keyboard->modifierMask(XKB_MOD_NAME_CTRL);
    }
    if (qtModifiers & Qt::AltModifier) {
        requestedModifiers |= m_keyboard->modifierMask(XKB_MOD_NAME_ALT);
    }
    if (qtModifiers & Qt::ShiftModifier) {
        requestedModifiers |= m_keyboard->modifierMask(XKB_MOD_NAME_SHIFT);
    }
    if (qtModifiers & Qt::MetaModifier) {
        requestedModifiers |= m_keyboard->modifierMask(XKB_MOD_NAME_LOGO);
    }

    const auto targetCode = m_keyboard->keycodeForKeysym(targetSym);
    if (!targetCode) {
        return false;
    }

    const quint32 originalDepressed = m_keyboard->depressedModifiers();
    const quint32 originalLatched = m_keyboard->latchedModifiers();
    const quint32 originalLocked = m_keyboard->lockedModifiers();
    const quint32 layout = m_keyboard->currentLayout();
    m_context->modifiers(m_context->m_latestSerial, originalDepressed | requestedModifiers, originalLatched, originalLocked, layout);
    key(Pressed, *targetCode);
    key(Released, *targetCode);
    m_context->modifiers(m_context->m_latestSerial, originalDepressed, originalLatched, originalLocked, layout);
    return true;
}

InputPlugin::ContentHint InputPlugin::contentHint() const
{
    if (!m_context) {
        return InputPlugin::content_hint_none;
    }
    return m_context->m_contentHint;
}

InputPlugin::ContentPurpose InputPlugin::contentPurpose() const
{
    if (!m_context) {
        return InputPlugin::content_purpose_normal;
    }
    return m_context->m_contentPurpose;
}

QString InputPlugin::surroundingText() const
{
    if (!m_context) {
        return QString();
    }
    return m_context->m_text;
}

uint32_t InputPlugin::cursorPos() const
{
    if (!m_context) {
        return 0;
    }
    return m_context->m_cursor;
}

uint32_t InputPlugin::anchorPos() const
{
    if (!m_context) {
        return 0;
    }
    return m_context->m_anchor;
}

void InputPlugin::setGrabbingInternal()
{
    Q_ASSERT(m_context);
    m_keyboard = m_context->keyboard();
    connect(m_keyboard.get(), &Keyboard::keyPressed, this, &InputPlugin::keyPressed);
    connect(m_keyboard.get(), &Keyboard::keyReleased, this, &InputPlugin::keyReleased);
}

#include "moc_inputplugin.cpp"
