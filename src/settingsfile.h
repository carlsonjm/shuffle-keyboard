/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#pragma once

#include <QFile>
#include <QStandardPaths>

/**
 * Brings the settings over from plasmakeyboardrc, the file this fork kept
 * them in while it shared Plasma's own keyboard's names, the first time the
 * Keyboard or its settings page runs without a shufflekeyboardrc. The old file
 * is copied, not moved: Plasma's keyboard may still be installed and read it.
 *
 * Called by both the Keyboard and the KCM, before either reads a setting.
 */
inline void adoptEarlierSettings()
{
    const QString folder = QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation);
    const QString ours = folder + QStringLiteral("/shufflekeyboardrc");
    const QString earlier = folder + QStringLiteral("/plasmakeyboardrc");
    if (!QFile::exists(ours) && QFile::exists(earlier)) {
        QFile::copy(earlier, ours);
    }
}
