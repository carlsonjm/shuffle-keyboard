/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QtGlobal>

/// A pointer the precision surface can move without asking the desktop
/// portal: one the compositor already trusts the Keyboard with. Where none is
/// available, the surface asks the portal instead.
class DirectPointer
{
public:
    virtual ~DirectPointer() = default;

    virtual bool isAvailable() const = 0;
    virtual void pointerMotion(qreal dx, qreal dy) = 0;
    virtual void pointerButton(int button, bool pressed) = 0;
    virtual void pointerAxis(qreal dx, qreal dy) = 0;
};
