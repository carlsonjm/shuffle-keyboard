/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "keystheme.h"

#include "keysthemerule.h"

#include <Plasma/Theme>

KeysTheme::KeysTheme(QObject *parent)
    : QObject(parent)
    , m_theme(std::make_unique<Plasma::Theme>())
    // The sign-in screen runs its session as a greeter, which logind names.
    , m_greeter(qEnvironmentVariable("XDG_SESSION_CLASS") == QLatin1String("greeter"))
{
    read();
    connect(m_theme.get(), &Plasma::Theme::themeChanged, this, [this]() {
        read();
        Q_EMIT changed();
    });
}

KeysTheme::~KeysTheme() = default;

void KeysTheme::read()
{
    m_ground = m_theme->color(Plasma::Theme::BackgroundColor);
    m_ink = m_theme->color(Plasma::Theme::TextColor);
    m_raised = KeysThemeRule::raised(m_theme->color(Plasma::Theme::BackgroundColor, Plasma::Theme::ViewColorGroup), m_ground, m_ink);
    m_light = KeysThemeRule::wantsLight(m_ground, m_ink, m_greeter);
}

bool KeysTheme::light() const
{
    return m_light;
}

QColor KeysTheme::ground() const
{
    return m_ground;
}

QColor KeysTheme::ink() const
{
    return m_ink;
}

QColor KeysTheme::raised() const
{
    return m_raised;
}

#include "moc_keystheme.cpp"
