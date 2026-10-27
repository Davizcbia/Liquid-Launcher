#pragma once

#include <QObject>
#include <QtGlobal>
#include <QString>
#include <functional>
#include <utility>

class MacWindowMetrics final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(qreal windowCornerRadius READ windowCornerRadius NOTIFY windowCornerRadiusChanged)
    Q_PROPERTY(bool nativeGlassDock READ nativeGlassDock NOTIFY nativeGlassDockChanged)

public:
    explicit MacWindowMetrics(QObject *parent = nullptr) : QObject(parent) {}
    qreal windowCornerRadius() const { return m_windowCornerRadius; }
    bool nativeGlassDock() const { return m_nativeGlassDock; }
    void setWindowCornerRadius(qreal radius)
    {
        if (qFuzzyCompare(m_windowCornerRadius, radius)) return;
        m_windowCornerRadius = radius;
        emit windowCornerRadiusChanged();
    }

    void setNativeGlassDock(bool enabled)
    {
        if (m_nativeGlassDock == enabled) return;
        m_nativeGlassDock = enabled;
        emit nativeGlassDockChanged();
    }

    Q_INVOKABLE void setDockInfo(const QString &title, const QString &version)
    {
        m_dockTitle = title;
        m_dockVersion = version;
        if (m_dockInfoUpdater) m_dockInfoUpdater(m_dockTitle, m_dockVersion,
                                                 m_dockX, m_dockY, m_dockWidth,
                                                 m_dockHeight, m_dockRadius);
    }

    Q_INVOKABLE void setDockGeometry(qreal x, qreal y, qreal width, qreal height, qreal radius)
    {
        m_dockX = x;
        m_dockY = y;
        m_dockWidth = width;
        m_dockHeight = height;
        m_dockRadius = radius;
        if (m_dockInfoUpdater) m_dockInfoUpdater(m_dockTitle, m_dockVersion,
                                                 m_dockX, m_dockY, m_dockWidth,
                                                 m_dockHeight, m_dockRadius);
    }

    Q_INVOKABLE void requestInstancePicker() { emit instancePickerRequested(); }
    Q_INVOKABLE void requestLaunch() { emit launchRequested(); }

    void setDockInfoUpdater(std::function<void(const QString &, const QString &, qreal, qreal, qreal, qreal, qreal)> updater)
    {
        m_dockInfoUpdater = std::move(updater);
        if (m_dockInfoUpdater) m_dockInfoUpdater(m_dockTitle, m_dockVersion,
                                                 m_dockX, m_dockY, m_dockWidth,
                                                 m_dockHeight, m_dockRadius);
    }

signals:
    void windowCornerRadiusChanged();
    void nativeGlassDockChanged();
    void instancePickerRequested();
    void launchRequested();

private:
    qreal m_windowCornerRadius = 20.0;
    bool m_nativeGlassDock = false;
    QString m_dockTitle = QStringLiteral("The Rebirth");
    QString m_dockVersion = QStringLiteral("Fabric 1.21.5");
    qreal m_dockX = 0.0;
    qreal m_dockY = 0.0;
    qreal m_dockWidth = 560.0;
    qreal m_dockHeight = 68.0;
    qreal m_dockRadius = 34.0;
    std::function<void(const QString &, const QString &, qreal, qreal, qreal, qreal, qreal)> m_dockInfoUpdater;
};
