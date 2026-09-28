/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "textinputhold.h"

#include <QDateTime>
#include <QGuiApplication>

namespace
{
// What an isolated session reads to see the order things happen in.
void probe(const char *what)
{
    static const bool enabled = qEnvironmentVariableIntValue("SHUFFLE_PROBE_HOLD") != 0;
    if (enabled) {
        qWarning("textinput %s at %lld", what, static_cast<long long>(QDateTime::currentMSecsSinceEpoch() % 100000));
    }
}
}

class TextInputHoldInput : public QtWayland::zwp_text_input_v3
{
public:
    TextInputHoldInput(TextInputHold *owner, struct ::zwp_text_input_v3 *input)
        : QtWayland::zwp_text_input_v3(input)
        , m_owner(owner)
    {
    }

    ~TextInputHoldInput() override
    {
        destroy();
    }

    bool entered = false;
    bool enabled = false;

protected:
    // The compositor says which of this process's surfaces has the focus. An
    // enable is only meaningful while one does.
    void zwp_text_input_v3_enter(struct ::wl_surface *surface) override
    {
        Q_UNUSED(surface)
        probe("enter");
        entered = true;
        m_owner->apply();
    }

    void zwp_text_input_v3_leave(struct ::wl_surface *surface) override
    {
        Q_UNUSED(surface)
        probe("leave");
        entered = false;
        // Leaving disables the input on the compositor's side already.
        enabled = false;
        m_owner->apply();
    }

private:
    TextInputHold *m_owner;
};

TextInputHold::TextInputHold()
    : QWaylandClientExtensionTemplate<TextInputHold>(1)
{
    connect(this, &QWaylandClientExtension::activeChanged, this, [this] {
        ensureInput();
        apply();
    });
}

TextInputHold::~TextInputHold() = default;

bool TextInputHold::held() const
{
    return m_held;
}

void TextInputHold::hold()
{
    m_wanted = true;
    ensureInput();
    apply();
}

void TextInputHold::release()
{
    m_wanted = false;
    apply();
}

void TextInputHold::ensureInput()
{
    if (m_input || !isActive()) {
        return;
    }
    auto *wayland = qGuiApp->nativeInterface<QNativeInterface::QWaylandApplication>();
    if (!wayland || !wayland->seat()) {
        return;
    }
    m_input = std::make_unique<TextInputHoldInput>(this, get_text_input(wayland->seat()));
}

void TextInputHold::apply()
{
    if (m_input) {
        const bool want = m_wanted && m_input->entered;
        if (want && !m_input->enabled) {
            m_input->enable();
            m_input->set_content_type(QtWayland::zwp_text_input_v3::content_hint_none, QtWayland::zwp_text_input_v3::content_purpose_normal);
            m_input->commit();
            m_input->enabled = true;
            probe("enabled");
        } else if (!want && m_input->enabled) {
            m_input->disable();
            m_input->commit();
            m_input->enabled = false;
            probe("disabled");
        }
    }

    const bool held = m_input && m_input->enabled;
    if (held != m_held) {
        m_held = held;
        Q_EMIT heldChanged();
    }
}
