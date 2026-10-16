/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include "directpointer.h"

#include <QtWaylandClient/QWaylandClientExtensionTemplate>

#include <qwayland-fake-input.h>

/// KWin's fake-input protocol, which KWin offers only to a program whose
/// desktop entry asks for it by X-KDE-Wayland-Interfaces. It moves the pointer
/// as the Keyboard's own, with no portal session, consent prompt or Plasma's
/// remote-control notice: the Keyboard is already the compositor's input
/// method, trusted with every key it types.
class FakeInputPointer : public QWaylandClientExtensionTemplate<FakeInputPointer>, public QtWayland::org_kde_kwin_fake_input, public DirectPointer
{
    Q_OBJECT

public:
    FakeInputPointer();
    ~FakeInputPointer() override;

    bool isAvailable() const override;
    void pointerMotion(qreal dx, qreal dy) override;
    void pointerButton(int button, bool pressed) override;
    void pointerAxis(qreal dx, qreal dy) override;
};
