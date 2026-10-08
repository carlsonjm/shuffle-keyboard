/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QColor>

#include <algorithm>
#include <cmath>

/**
 * When the keys are drawn light, kept apart from the theme so it can be tested
 * without one.
 */
namespace KeysThemeRule
{
/// Contrast between two colours as WCAG measures it, from 1 to 21.
inline double contrast(const QColor &a, const QColor &b)
{
    const auto luminance = [](const QColor &colour) {
        const auto linear = [](double value) {
            return value <= 0.04045 ? value / 12.92 : std::pow((value + 0.055) / 1.055, 2.4);
        };
        return 0.2126 * linear(colour.redF()) + 0.7152 * linear(colour.greenF()) + 0.0722 * linear(colour.blueF());
    };
    const double lighter = std::max(luminance(a), luminance(b));
    const double darker = std::min(luminance(a), luminance(b));
    return (lighter + 0.05) / (darker + 0.05);
}

/// What body text needs to be read, by WCAG's AA.
constexpr double readable = 4.5;

/**
 * Light keys only on a light ground whose ink reads on it, and never at the
 * sign-in screen, where nobody has chosen a look and the keys must be the ones
 * the person knows. Anything else is the dark keys, which always read.
 */
inline bool wantsLight(const QColor &ground, const QColor &ink, bool greeter)
{
    return !greeter && ground.isValid() && ink.isValid() && ground.lightnessF() > 0.5 && contrast(ground, ink) >= readable;
}

/// The accents' pop-up stands on a view's ground where its ink reads there,
/// and on the keys' own ground where it does not.
inline QColor raised(const QColor &view, const QColor &ground, const QColor &ink)
{
    return view.isValid() && contrast(view, ink) >= readable ? view : ground;
}
}
