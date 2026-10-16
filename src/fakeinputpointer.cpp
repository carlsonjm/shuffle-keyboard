/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "fakeinputpointer.h"

#include <wayland-client-protocol.h>

FakeInputPointer::FakeInputPointer()
    : QWaylandClientExtensionTemplate<FakeInputPointer>(4)
{
    // KWin drops every event from a fake-input client that has not said who
    // it is; the grant itself comes from the desktop entry.
    connect(this, &FakeInputPointer::activeChanged, this, [this] {
        if (isActive()) {
            authenticate(QStringLiteral("Shuffle Keyboard"), QStringLiteral("The precision surface moves the pointer"));
        }
    });
}

FakeInputPointer::~FakeInputPointer() = default;

bool FakeInputPointer::isAvailable() const
{
    return isActive();
}

void FakeInputPointer::pointerMotion(qreal dx, qreal dy)
{
    pointer_motion(wl_fixed_from_double(dx), wl_fixed_from_double(dy));
}

void FakeInputPointer::pointerButton(int button, bool pressed)
{
    org_kde_kwin_fake_input::button(button, pressed ? WL_POINTER_BUTTON_STATE_PRESSED : WL_POINTER_BUTTON_STATE_RELEASED);
}

void FakeInputPointer::pointerAxis(qreal dx, qreal dy)
{
    if (dy != 0) {
        axis(WL_POINTER_AXIS_VERTICAL_SCROLL, wl_fixed_from_double(dy));
    }
    if (dx != 0) {
        axis(WL_POINTER_AXIS_HORIZONTAL_SCROLL, wl_fixed_from_double(dx));
    }
}
