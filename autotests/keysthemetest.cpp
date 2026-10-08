/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include "keysthemerule.h"

#include <QTest>

// When the keys are drawn light: only where the Plasma style is light and its
// text reads on it, and never at the sign-in screen.
class KeysThemeTest : public QObject
{
    Q_OBJECT

private Q_SLOTS:
    void testLooks_data()
    {
        QTest::addColumn<QColor>("ground");
        QTest::addColumn<QColor>("ink");
        QTest::addColumn<bool>("greeter");
        QTest::addColumn<bool>("light");

        QTest::newRow("Shuffle dark") << QColor(28, 28, 28) << QColor(248, 248, 255) << false << false;
        QTest::newRow("Shuffle Light") << QColor(224, 224, 224) << QColor(16, 39, 41) << false << true;
        QTest::newRow("Breeze") << QColor(239, 240, 241) << QColor(35, 38, 41) << false << true;
        QTest::newRow("Breeze Dark") << QColor(32, 35, 38) << QColor(252, 252, 252) << false << false;
        QTest::newRow("light at the sign-in screen") << QColor(224, 224, 224) << QColor(16, 39, 41) << true << false;
        QTest::newRow("pale ink on a light ground") << QColor(224, 224, 224) << QColor(170, 170, 170) << false << false;
        QTest::newRow("no colours") << QColor() << QColor() << false << false;
    }

    void testLooks()
    {
        QFETCH(QColor, ground);
        QFETCH(QColor, ink);
        QFETCH(bool, greeter);
        QFETCH(bool, light);
        QCOMPARE(KeysThemeRule::wantsLight(ground, ink, greeter), light);
    }

    void testRaised()
    {
        const QColor ground(224, 224, 224);
        const QColor ink(16, 39, 41);
        QCOMPARE(KeysThemeRule::raised(QColor(255, 255, 255), ground, ink), QColor(255, 255, 255));
        QCOMPARE(KeysThemeRule::raised(QColor(40, 40, 40), ground, ink), ground);
        QCOMPARE(KeysThemeRule::raised(QColor(), ground, ink), ground);
    }

    void testContrast()
    {
        QCOMPARE(qRound(KeysThemeRule::contrast(Qt::black, Qt::white)), 21);
        QCOMPARE(KeysThemeRule::contrast(Qt::white, Qt::white), 1.0);
    }
};

QTEST_GUILESS_MAIN(KeysThemeTest)

#include "keysthemetest.moc"
