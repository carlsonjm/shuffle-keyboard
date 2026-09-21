/*
    SPDX-FileCopyrightText: 2026 Shuffle Project
    SPDX-License-Identifier: GPL-2.0-only OR GPL-3.0-only OR LicenseRef-KDE-Accepted-GPL
*/

#include <QApplication>
#include <QElapsedTimer>
#include <QFile>
#include <QLineEdit>
#include <QMainWindow>
#include <QResizeEvent>
#include <QTextStream>
#include <QTimer>

class GeometryWindow : public QMainWindow
{
public:
    explicit GeometryWindow(const QString &output)
        : m_output(output)
    {
        auto edit = new QLineEdit(this);
        setCentralWidget(edit);
        edit->setFocus();
        m_timer.start();
    }

protected:
    void resizeEvent(QResizeEvent *event) override
    {
        QMainWindow::resizeEvent(event);
        QFile file(m_output);
        if (file.open(QIODevice::WriteOnly | QIODevice::Append | QIODevice::Text)) {
            QTextStream(&file) << m_timer.elapsed() << "ms " << event->size().width() << 'x' << event->size().height() << '\n';
        }
    }

private:
    QString m_output;
    QElapsedTimer m_timer;
};

int main(int argc, char **argv)
{
    QApplication application(argc, argv);
    const QString output = qEnvironmentVariable("SHUFFLE_GEOMETRY_OUTPUT", QStringLiteral("/tmp/shuffle-geometry.txt"));
    QFile::remove(output);

    GeometryWindow window(output);
    window.showMaximized();
    window.activateWindow();
    QTimer::singleShot(6500, &application, &QApplication::quit);
    return application.exec();
}
