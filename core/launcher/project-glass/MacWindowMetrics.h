#pragma once

#include <QObject>
#include <QGuiApplication>
#include <QImage>
#include <QColor>
#include <QClipboard>
#include <QSaveFile>
#include <QFile>
#include <QDir>
#include <QDesktopServices>
#include <QStandardPaths>
#include <QUrl>
#include <QtGlobal>
#include <QString>
#include <QVariantList>
#include <QVariantMap>
#include <functional>
#include <utility>
#if defined(Q_OS_MACOS)
#include <sys/sysctl.h>
#include <mach/mach.h>
#elif defined(Q_OS_WIN)
#include <windows.h>
#endif

class MacWindowMetrics final : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int symbolRevision READ symbolRevision NOTIFY symbolRevisionChanged)
    Q_PROPERTY(bool nativeAccountGlass READ nativeAccountGlass NOTIFY nativeAccountGlassChanged)
    Q_PROPERTY(QString defaultAccountAvatar READ defaultAccountAvatar NOTIFY defaultAccountAvatarChanged)
    Q_PROPERTY(qreal windowCornerRadius READ windowCornerRadius NOTIFY windowCornerRadiusChanged)
    Q_PROPERTY(qreal sidebarAnimationProgress READ sidebarAnimationProgress NOTIFY sidebarAnimationProgressChanged)
    Q_PROPERTY(bool nativeSidebar READ nativeSidebar NOTIFY nativeSidebarChanged)
    Q_PROPERTY(bool nativeGlassDock READ nativeGlassDock NOTIFY nativeGlassDockChanged)

public:
    void clearNativeCallbacks() {
        m_editorGlassUpdater = {};
        m_accountGlassUpdater = {};
        m_pageUIUpdater = {};
        m_accountButtonUpdater = {};
        m_sidebarAnimationUpdater = {};
        m_instanceMenuUpdater = {};
        m_navigationUpdater = {};
        m_backgroundUpdater = {};
        m_sidebarButtonUpdater = {};
        m_sidebarControlsUpdater = {};
        m_searchButtonUpdater = {};
        m_searchPanelUpdater = {};
        m_glassStrengthUpdater = {};
        m_deleteConfirm = {};
        m_themeAccent = {};
        m_systemAccent = {};
        m_canvasCards = {};
        m_symbolIcon = {};
        m_dockInfoUpdater = {};
        m_dockArtworkUpdater = {};
        m_dockOverlayVisibilityUpdater = {};
    }
    explicit MacWindowMetrics(QObject *parent = nullptr) : QObject(parent) {}
    Q_INVOKABLE bool requestDeleteConfirmation() { if(!m_deleteConfirm)return false; m_deleteConfirm();return true; }
    void setDeleteConfirmationHandler(std::function<void()> handler) { m_deleteConfirm=std::move(handler); }
    Q_INVOKABLE QString artworkTint(const QUrl &source)const {
        QString path=source.isLocalFile()?source.toLocalFile():source.toString();
        if(path.startsWith("qrc:"))path=path.mid(3);
        const QImage image=path.isEmpty()?QImage():QImage(path);if(image.isNull())return QStringLiteral("#80466E41");
        const auto small=image.scaled(24,24,Qt::KeepAspectRatio,Qt::SmoothTransformation);
        double red=0,green=0,blue=0,weight=0;
        for(int y=0;y<small.height();y++)for(int x=0;x<small.width();x++) {
            const auto color=small.pixelColor(x,y);const double alpha=color.alphaF();
            red+=color.redF()*alpha;green+=color.greenF()*alpha;blue+=color.blueF()*alpha;weight+=alpha;
        }
        return weight>0?QColor::fromRgbF(red/weight,green/weight,blue/weight,0.5).name(QColor::HexArgb):QStringLiteral("#80466E41");
    }
    Q_INVOKABLE QString systemAccentColor() const { return m_systemAccent ? m_systemAccent() : QStringLiteral("#0A84FF"); }
    int symbolRevision() const { return m_symbolRevision; }
    Q_INVOKABLE void setCanvasCards(const QVariantList &rows) { if(m_canvasCards)m_canvasCards(rows); }
    void setCanvasCardsUpdater(std::function<void(const QVariantList &)> fn) { m_canvasCards=std::move(fn); }
    Q_INVOKABLE QString symbolIcon(const QString &name,const QString &color) const { return m_symbolIcon ? m_symbolIcon(name,color) : QString(); }
    Q_INVOKABLE void setThemeAccent(const QString &color) { if(m_themeAccent)m_themeAccent(color); }
    void setThemeAccentUpdater(std::function<void(const QString &)> updater) { m_themeAccent=std::move(updater); }
    void setSystemAccentReader(std::function<QString()> reader) { m_systemAccent=std::move(reader); }
    void setSymbolIconReader(std::function<QString(const QString &,const QString &)> reader) { m_symbolIcon=std::move(reader); ++m_symbolRevision; emit symbolRevisionChanged(); }
    Q_INVOKABLE QVariantMap systemMemory() const {
        quint64 total = 0, available = 0;
#if defined(Q_OS_MACOS)
        size_t size = sizeof(total);
        if (sysctlbyname("hw.memsize", &total, &size, nullptr, 0) != 0) return {};
        vm_statistics64_data_t stats{};
        mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
        vm_size_t page = 0;
        const mach_port_t host = mach_host_self();
        const bool ok = host_page_size(host, &page) == KERN_SUCCESS &&
            host_statistics64(host, HOST_VM_INFO64, reinterpret_cast<host_info64_t>(&stats), &count) == KERN_SUCCESS;
        mach_port_deallocate(mach_task_self(), host);
        if (!ok) return {};
        // App/active, wired and physical compressor pages count as used; cached inactive pages are reclaimable.
        const quint64 used = (quint64(stats.active_count) + stats.wire_count + stats.compressor_page_count) * page;
        available = total - qMin(total, used);
#elif defined(Q_OS_WIN)
        MEMORYSTATUSEX stats{}; stats.dwLength = sizeof(stats);
        if (!GlobalMemoryStatusEx(&stats)) return {};
        total = stats.ullTotalPhys; available = stats.ullAvailPhys;
#else
        QFile file(QStringLiteral("/proc/meminfo"));
        if (!file.open(QIODevice::ReadOnly)) return {};
        for (const QByteArray &line : file.readAll().split('\n')) {
            const auto parts = line.simplified().split(' ');
            if (parts.size() < 2) continue;
            if (parts[0] == "MemTotal:") total = parts[1].toULongLong() * 1024;
            if (parts[0] == "MemAvailable:") available = parts[1].toULongLong() * 1024;
        }
#endif
        if (!total) return {};
        return {{QStringLiteral("totalMiB"), double(total / 1048576)},
                {QStringLiteral("usedMiB"), double((total - qMin(total, available)) / 1048576)}};
    }
    Q_INVOKABLE void copyText(const QString &text) { QGuiApplication::clipboard()->setText(text); }
    Q_INVOKABLE bool writeTextFile(const QUrl &url,const QString &text) {
        if (!url.isLocalFile()) return false;
        QSaveFile file(url.toLocalFile());
        if (!file.open(QIODevice::WriteOnly)) return false;
        const QByteArray bytes=text.toUtf8();
        if (file.write(bytes)!=bytes.size()) { file.cancelWriting(); return false; }
        return file.commit();
    }
    Q_INVOKABLE bool openInstanceFolder(const QString &key,const QString &configuration) {
        QString safe;
        for (QChar c:key) if(c.isLetterOrNumber() || c==QLatin1Char('-') || c==QLatin1Char('_')) safe+=c;
        if(safe.isEmpty())return false;
        const QString path=QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)+QStringLiteral("/instances/")+safe;
        if(!QDir().mkpath(path))return false;
        if(!writeTextFile(QUrl::fromLocalFile(path+QStringLiteral("/instance.json")),configuration))return false;
        return QDesktopServices::openUrl(QUrl::fromLocalFile(path));
    }
    Q_INVOKABLE bool writeLaunchShortcut(const QUrl &url,const QString &key) {
        if(!url.isLocalFile() || key.isEmpty())return false;
        QString path=url.toLocalFile();
        if(!path.endsWith(QStringLiteral(".command")))path+=QStringLiteral(".command");
        auto quote=[](QString value) {
            value.replace(QChar(39),QString(QChar(39))+QChar(34)+QChar(39)+QChar(34)+QChar(39));
            return QString(QChar(39))+value+QChar(39);
        };
        const QString script=QStringLiteral("#!/bin/sh\nexec ")+quote(QCoreApplication::applicationFilePath())+
            QStringLiteral(" --launch-instance ")+quote(key)+QLatin1Char('\n');
        if(!writeTextFile(QUrl::fromLocalFile(path),script))return false;
        return QFile::setPermissions(path,QFileDevice::ReadOwner|QFileDevice::WriteOwner|QFileDevice::ExeOwner|
            QFileDevice::ReadGroup|QFileDevice::ExeGroup|QFileDevice::ReadOther|QFileDevice::ExeOther);
    }
    bool nativeAccountGlass() const { return m_nativeAccountGlass; }
    void setNativeAccountGlass(bool enabled) {
        if (m_nativeAccountGlass == enabled) return;
        m_nativeAccountGlass = enabled; emit nativeAccountGlassChanged();
    }
    Q_INVOKABLE void setAccountGlass(QObject *item, bool visible) {
        if (m_accountGlassUpdater) m_accountGlassUpdater(item, visible);
    }
    void setAccountGlassUpdater(std::function<void(QObject *, bool)> updater) { m_accountGlassUpdater = std::move(updater); }
    QString defaultAccountAvatar() const { return m_defaultAccountAvatar; }
    void setDefaultAccountAvatar(const QString &source) {
        if (source == m_defaultAccountAvatar) return;
        m_defaultAccountAvatar = source;
        emit defaultAccountAvatarChanged();
    }
    qreal windowCornerRadius() const { return m_windowCornerRadius; }
    qreal sidebarAnimationProgress() const { return m_sidebarAnimationProgress; }
    void updateSidebarAnimationProgress(qreal value) {
        value = qBound(0.0, value, 1.0);
        if (qFuzzyCompare(m_sidebarAnimationProgress, value)) return;
        m_sidebarAnimationProgress = value;
        emit sidebarAnimationProgressChanged();
    }
    Q_INVOKABLE void animateSidebar(bool open, bool immediate = false) {
        if (m_sidebarAnimationUpdater) m_sidebarAnimationUpdater(open, immediate);
    }
    void setSidebarAnimationUpdater(std::function<void(bool, bool)> updater) {
        m_sidebarAnimationUpdater = std::move(updater);
    }
    bool nativeSidebar() const { return m_nativeSidebar; }
    void setNativeSidebar(bool enabled) { m_nativeSidebar = enabled; emit nativeSidebarChanged(); }
    Q_INVOKABLE void setGlassStrength(qreal strength)
    { if (m_glassStrengthUpdater) m_glassStrengthUpdater(qBound(0.0, strength, 1.0)); }
    void setGlassStrengthUpdater(std::function<void(qreal)> updater)
    { m_glassStrengthUpdater = std::move(updater); }
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

    Q_INVOKABLE void setDockArtwork(const QString &source,bool defaultArtwork) {
        if(m_dockArtwork==source && m_dockDefaultArtwork==defaultArtwork)return;
        m_dockArtwork=source;m_dockDefaultArtwork=defaultArtwork;
        if(m_dockArtworkUpdater)m_dockArtworkUpdater(source,defaultArtwork);
    }
    void setDockArtworkUpdater(std::function<void(const QString &,bool)> updater) {
        m_dockArtworkUpdater=std::move(updater);
        if(m_dockArtworkUpdater)m_dockArtworkUpdater(m_dockArtwork,m_dockDefaultArtwork);
    }

    Q_INVOKABLE void setDockGeometry(qreal x, qreal y, qreal width, qreal height,
                                     qreal radius)
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

    Q_INVOKABLE void setNativeDockOverlayVisible(bool visible)
    {
        m_nativeDockOverlayVisible = visible;
        if (m_dockOverlayVisibilityUpdater)
            m_dockOverlayVisibilityUpdater(visible && m_nativeGlassDock);
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

    void setDockOverlayVisibilityUpdater(std::function<void(bool)> updater)
    {
        m_dockOverlayVisibilityUpdater = std::move(updater);
        if (m_dockOverlayVisibilityUpdater)
            m_dockOverlayVisibilityUpdater(m_nativeDockOverlayVisible && m_nativeGlassDock);
    }

    Q_INVOKABLE void setInstanceMenu(bool open, const QVariantList &rows, int selected)
    {
        if (m_instanceMenuUpdater) m_instanceMenuUpdater(open, rows, selected);
    }
    void setInstanceMenuUpdater(std::function<void(bool, const QVariantList &, int)> updater)
    { m_instanceMenuUpdater = std::move(updater); }
    void chooseInstance(int index) { emit instanceSelected(index); }

    Q_INVOKABLE void setNavigation(qreal progress, const QString &page, qreal contentHeight, qreal sidebarWidth)
    { if (m_navigationUpdater) m_navigationUpdater(progress, page, contentHeight, sidebarWidth); }
    void setNavigationUpdater(std::function<void(qreal, const QString &, qreal, qreal)> updater)
    { m_navigationUpdater = std::move(updater); }
    void navigate(int action) { emit navigationRequested(action); }

    Q_INVOKABLE void setBackground(const QString &mode, const QString &source, const QString &placement)
    { if (m_backgroundUpdater) m_backgroundUpdater(mode, source, placement); }
    void setBackgroundUpdater(std::function<void(const QString &, const QString &, const QString &)> updater)
    { m_backgroundUpdater = std::move(updater); }

    Q_INVOKABLE void setSidebarButton(qreal x, qreal y, qreal progress, qreal contentHeight)
    { if (m_sidebarButtonUpdater) m_sidebarButtonUpdater(x, y, progress, contentHeight); }
    void setSidebarButtonUpdater(std::function<void(qreal, qreal, qreal, qreal)> updater)
    { m_sidebarButtonUpdater = std::move(updater); }

    Q_INVOKABLE void setSidebarControls(const QVariantList &rows)
    { if (m_sidebarControlsUpdater) m_sidebarControlsUpdater(rows); }
    void setSidebarControlsUpdater(std::function<void(const QVariantList &)> updater)
    { m_sidebarControlsUpdater = std::move(updater); }

    Q_INVOKABLE void setSearchButton(qreal x, qreal y, qreal size, qreal opacity, bool visible, bool expanded)
    { if (m_searchButtonUpdater) m_searchButtonUpdater(x, y, size, opacity, visible, expanded); }
    void setSearchButtonUpdater(std::function<void(qreal, qreal, qreal, qreal, bool, bool)> updater)
    { m_searchButtonUpdater = std::move(updater); }

    Q_INVOKABLE void setSearchPanel(qreal x, qreal y, qreal width, qreal height, qreal opacity, bool visible,
                                    const QString &text, const QString &sort, qreal zoom)
    { if (m_searchPanelUpdater) m_searchPanelUpdater(x, y, width, height, opacity, visible, text, sort, zoom); }
    void setSearchPanelUpdater(std::function<void(qreal, qreal, qreal, qreal, qreal, bool, const QString &, const QString &, qreal)> updater)
    { m_searchPanelUpdater = std::move(updater); }
    void updateSearchState(const QString &text, const QString &sort, qreal zoom) { emit searchStateRequested(text, sort, zoom); }

    Q_INVOKABLE void setAccountButton(qreal x, qreal y, qreal opacity, bool visible, bool interactive) {
        if (m_accountButtonUpdater) m_accountButtonUpdater(x, y, opacity, visible, interactive);
    }
    void setAccountButtonUpdater(std::function<void(qreal, qreal, qreal, bool, bool)> updater) {
        m_accountButtonUpdater = std::move(updater);
    }
    Q_INVOKABLE void setEditorGlass(QObject *item, bool visible) {
        if (m_editorGlassUpdater) m_editorGlassUpdater(item,visible);
    }
    void setEditorGlassUpdater(std::function<void(QObject *,bool)> updater) { m_editorGlassUpdater=std::move(updater); }
    Q_INVOKABLE void setPageUI(const QVariantMap &state) {
        if (m_pageUIUpdater) m_pageUIUpdater(state);
    }
    void setPageUIUpdater(std::function<void(const QVariantMap &)> updater) { m_pageUIUpdater = std::move(updater); }
    void changePageControl(const QString &key, const QVariant &value) { emit pageControlChanged(key, value); }
    Q_INVOKABLE void requestCloseSearch() { emit searchCloseRequested(); }

signals:
    void symbolRevisionChanged();
    void deletionConfirmed();
    void nativeAccountGlassChanged();
    void pageControlChanged(const QString &key, const QVariant &value);
    void defaultAccountAvatarChanged();
    void sidebarAnimationProgressChanged();
    void searchCloseRequested();
    void searchStateRequested(const QString &text, const QString &sort, qreal zoom);
    void nativeSidebarChanged();
    void navigationRequested(int action);
    void instanceSelected(int index);
    void windowCornerRadiusChanged();
    void nativeGlassDockChanged();
    void instancePickerRequested();
    void launchRequested();

private:
    std::function<void(QObject *,bool)> m_editorGlassUpdater;
    bool m_nativeAccountGlass = false;
    std::function<void(QObject *, bool)> m_accountGlassUpdater;
    std::function<void(const QVariantMap &)> m_pageUIUpdater;
    QString m_defaultAccountAvatar = QStringLiteral("qrc:/qt/qml/ProjectGlass/assets/default-account.svg");
    std::function<void(qreal, qreal, qreal, bool, bool)> m_accountButtonUpdater;
    qreal m_sidebarAnimationProgress = 0;
    std::function<void(bool, bool)> m_sidebarAnimationUpdater;
    qreal m_windowCornerRadius = 20.0;
    std::function<void(bool, const QVariantList &, int)> m_instanceMenuUpdater;
    std::function<void(qreal, const QString &, qreal, qreal)> m_navigationUpdater;
    std::function<void(const QString &, const QString &, const QString &)> m_backgroundUpdater;
    std::function<void(qreal, qreal, qreal, qreal)> m_sidebarButtonUpdater;
    std::function<void(const QVariantList &)> m_sidebarControlsUpdater;
    std::function<void(qreal, qreal, qreal, qreal, bool, bool)> m_searchButtonUpdater;
    std::function<void(qreal, qreal, qreal, qreal, qreal, bool, const QString &, const QString &, qreal)> m_searchPanelUpdater;
    bool m_nativeSidebar = false;
    std::function<void(qreal)> m_glassStrengthUpdater;
    std::function<void()> m_deleteConfirm;
    std::function<void(const QString &)> m_themeAccent;
    std::function<QString()> m_systemAccent;
    std::function<void(const QVariantList &)> m_canvasCards;
    int m_symbolRevision=0;
    std::function<QString(const QString &,const QString &)> m_symbolIcon;
    bool m_nativeGlassDock = false;
    QString m_dockArtwork;
    bool m_dockDefaultArtwork=true;
    std::function<void(const QString &,bool)> m_dockArtworkUpdater;
    QString m_dockTitle = QStringLiteral("The Rebirth");
    QString m_dockVersion = QStringLiteral("Fabric 1.21.5");
    qreal m_dockX = 0.0;
    qreal m_dockY = 0.0;
    qreal m_dockWidth = 560.0;
    qreal m_dockHeight = 68.0;
    qreal m_dockRadius = 34.0;
    bool m_nativeDockOverlayVisible = true;
    std::function<void(const QString &, const QString &, qreal, qreal, qreal, qreal, qreal)> m_dockInfoUpdater;
    std::function<void(bool)> m_dockOverlayVisibilityUpdater;
};
