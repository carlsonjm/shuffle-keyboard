/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QColor>
#include <QObject>
#include <qqmlintegration.h>

#include <memory>

namespace Plasma
{
class Theme;
}

/**
 * The colours the keys take from the Plasma style.
 *
 * The keys are a surface of the desktop, as the panels are, so they follow
 * the Plasma style rather than the colours programs use: a style that keeps
 * its panels dark under light programs keeps the keys dark too. The style's
 * colours are its own where it carries them, and the system's where it does
 * not, which Plasma decides.
 */
class KeysTheme : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_SINGLETON
    Q_PROPERTY(bool light READ light NOTIFY changed)
    Q_PROPERTY(QColor ground READ ground NOTIFY changed)
    Q_PROPERTY(QColor ink READ ink NOTIFY changed)
    Q_PROPERTY(QColor raised READ raised NOTIFY changed)

public:
    explicit KeysTheme(QObject *parent = nullptr);
    ~KeysTheme() override;

    bool light() const;
    QColor ground() const;
    QColor ink() const;
    QColor raised() const;

Q_SIGNALS:
    void changed();

private:
    void read();

    std::unique_ptr<Plasma::Theme> m_theme;
    const bool m_greeter;
    bool m_light = false;
    QColor m_ground;
    QColor m_ink;
    QColor m_raised;
};
