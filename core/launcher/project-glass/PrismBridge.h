// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <QObject>
#include <QTimer>
#include <QVariantList>
#include <QDesktopServices>
#include <QUrl>
#include <QUrlQuery>
#include <QFileInfo>
#include <QDir>
#include <QRegularExpression>
#include <QMessageBox>
#include <QInputDialog>
#include <QSettings>
#include "minecraft/auth/AccountList.h"
#include "minecraft/auth/MinecraftAccount.h"
#include "Application.h"
#include "ui/dialogs/MSALoginDialog.h"
#include "minecraft/VanillaInstanceCreationTask.h"
#include "meta/Version.h"
#include "ModrinthInstallTask.h"
#include "InstanceEditorFiles.h"
#include "minecraft/mod/Resource.h"
#include <QFileSystemWatcher>
#include <QProcess>
#include <QApplication>
#include <QClipboard>
#include <QBuffer>
#include <QHash>
#include <QPainter>
#include <qrencode.h>
#include "minecraft/mod/tasks/LocalModParseTask.h"
#include "InstanceImportTask.h"
#include "modplatform/modrinth/ModrinthPackIndex.h"
#include <QJsonObject>
#include <QJsonDocument>
#include <QJsonArray>
#include <QFile>
#include <QPointer>
#include "settings/SettingsObject.h"
#include "InstanceList.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"

// Compatibility context name for the accepted QML frontend. No external process.
class PrismBridge final : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap editorDetails READ editorDetails NOTIFY editorDetailsChanged)
    Q_PROPERTY(QString editorInstanceKey READ editorInstanceKey NOTIFY editorDetailsChanged)
    Q_PROPERTY(bool installing READ installing NOTIFY changed)
    Q_PROPERTY(double installProgress READ installProgress NOTIFY changed)
    Q_PROPERTY(QVariantList savedAccounts READ savedAccounts NOTIFY changed)
    Q_PROPERTY(QString currentAccountName READ currentAccountName NOTIFY changed)
    Q_PROPERTY(bool signingIn READ signingIn NOTIFY changed)
    Q_PROPERTY(QString loginQr READ loginQr NOTIFY changed)
    Q_PROPERTY(QString loginCode READ loginCode NOTIFY changed)
    Q_PROPERTY(QString loginUrl READ loginUrl NOTIFY changed)
    Q_PROPERTY(bool offlineMode READ offlineMode NOTIFY changed)
    Q_PROPERTY(QString offlineName READ offlineName NOTIFY changed)
    Q_PROPERTY(QString executable READ executable NOTIFY changed)
    Q_PROPERTY(QString dataRoot READ dataRoot NOTIFY changed)
    Q_PROPERTY(QString status READ status NOTIFY changed)
    Q_PROPERTY(QVariantList instances READ instances NOTIFY instancesChanged)
public:
    explicit PrismBridge(Application *app):QObject(app),m_app(app){
        app->setProperty("projectGlassAuthBridge",QVariant::fromValue(static_cast<QObject *>(this)));
        connect(app,&Application::projectGlassLaunchFailed,this,[this](const QString &reason){
            m_status="Launch failed · "+reason;emit changed();
        });
        connect(app,&Application::projectGlassLaunchStatus,this,[this](const QString &status){
            m_status=status;emit changed();
        });
        m_editorWatcher=new QFileSystemWatcher(this);
        m_editorReload=new QTimer(this);m_editorReload->setInterval(120);m_editorReload->setSingleShot(true);
        connect(m_editorReload,&QTimer::timeout,this,&PrismBridge::refreshEditor);
        connect(m_editorWatcher,&QFileSystemWatcher::directoryChanged,this,[this]{m_editorReload->start();});
        connect(m_editorWatcher,&QFileSystemWatcher::fileChanged,this,[this]{m_editorReload->start();});
        m_refreshSoon=new QTimer(this);m_refreshSoon->setSingleShot(true);m_refreshSoon->setInterval(0);
        connect(m_refreshSoon,&QTimer::timeout,this,&PrismBridge::refresh);
        auto *timer=new QTimer(this);timer->setInterval(1500);
        connect(timer,&QTimer::timeout,this,&PrismBridge::refresh);timer->start();refresh();
    }
    bool offlineMode()const{QSettings prefs("ProjectGlass","CoreAccount");return prefs.value("offlineMode",false).toBool();}
    QString offlineName()const{QSettings prefs("ProjectGlass","CoreAccount");return prefs.value("offlineName","Player").toString();}
    Q_INVOKABLE void setOfflineMode(bool enabled){
        QSettings prefs("ProjectGlass","CoreAccount");prefs.setValue("offlineMode",enabled);
        m_status=enabled?"Offline profile selected · "+offlineName():"Microsoft account mode selected";emit changed();
    }
    Q_INVOKABLE bool renameOffline(const QString &value){
        const auto name=value.trimmed();
        if(!QRegularExpression("^[A-Za-z0-9_]{3,16}$").match(name).hasMatch()){
            m_status="Name must contain 3–16 letters, digits or underscores";emit changed();return false;
        }
        QSettings prefs("ProjectGlass","CoreAccount");prefs.setValue("offlineName",name);emit changed();return true;
    }
    Q_INVOKABLE void configureOffline(){
        bool ok=false;const auto name=QInputDialog::getText(nullptr,"Offline profile","Player name (3–16 letters, digits or underscores):",QLineEdit::Normal,offlineName(),&ok).trimmed();
        if(!ok)return;
        if(!QRegularExpression("^[A-Za-z0-9_]{3,16}$").match(name).hasMatch()){QMessageBox::information(nullptr,"Invalid name","Use 3–16 letters, digits or underscores.");return;}
        QSettings prefs("ProjectGlass","CoreAccount");prefs.setValue("offlineName",name);prefs.setValue("offlineMode",true);
        m_status="Offline profile selected · "+name;emit changed();
    }
    Q_INVOKABLE void useMicrosoft(){signIn();}
    QString executable()const{return QStringLiteral("Built-in Prism core");}
    QString dataRoot()const{return m_app->dataRoot();}
    QString status()const{return m_status;}
    QVariantList instances()const{return m_instances;}
    Q_INVOKABLE void configure(QString,QString root){
        if(QDir::cleanPath(root)!=QDir::cleanPath(dataRoot())){m_status="Data folder is fixed for this session. Restart with --dir <folder> to change it.";emit changed();return;}
        refresh();
    }
    Q_INVOKABLE void refresh(){
        if(m_app->status()!=Application::Initialized || !m_app->instances())return;
        if(m_observedAccounts!=m_app->accounts()) {
            m_observedAccounts=m_app->accounts();
            connect(m_observedAccounts.data(),&AccountList::listChanged,this,&PrismBridge::changed);
            connect(m_observedAccounts.data(),&AccountList::defaultAccountChanged,this,&PrismBridge::changed);
        }
        if(m_observedInstances!=m_app->instances()) {
            m_observedInstances=m_app->instances();
            auto queueRefresh=[this]{m_refreshSoon->start();};
            connect(m_observedInstances.data(),&QAbstractItemModel::rowsInserted,this,queueRefresh);
            connect(m_observedInstances.data(),&QAbstractItemModel::rowsRemoved,this,queueRefresh);
            connect(m_observedInstances.data(),&QAbstractItemModel::modelReset,this,queueRefresh);
            connect(m_observedInstances.data(),&QAbstractItemModel::dataChanged,this,queueRefresh);
            connect(m_observedInstances.data(),&InstanceList::instanceSelectRequest,this,[this](const QString &id){
                m_pendingInstance="prism:"+id;m_refreshSoon->start();
            });
        }
        QVariantList rows;
        for(int i=0;i<m_app->instances()->count();++i){
            auto *instance=m_app->instances()->at(i);auto *profile=instance->getPackProfile();
            QMap<QString,QString> manifestVersions;
            // A newly committed instance may not have resolved its profile yet.
            // Read display versions from its already-written local manifest;
            // never start a metadata download just to pick the card artwork.
            if(!profile || profile->rowCount()==0 || profile->getComponentVersion("net.minecraft").isEmpty()) {
                QFile file(QDir(instance->instanceRoot()).filePath("mmc-pack.json"));
                if(file.open(QIODevice::ReadOnly)) {
                    const auto components=QJsonDocument::fromJson(file.readAll()).object().value("components").toArray();
                    for(const auto &value:components) {
                        const auto component=value.toObject();manifestVersions.insert(component.value("uid").toString(),component.value("version").toString());
                    }
                }
            }
            auto componentVersion=[profile,&manifestVersions](const QString &uid){
                const auto resolved=profile?profile->getComponentVersion(uid):QString();
                return resolved.isEmpty()?manifestVersions.value(uid):resolved;
            };
            QString game=componentVersion("net.minecraft"),loader="Minecraft";
            for(const auto &pair: {qMakePair(QString("net.fabricmc.fabric-loader"),QString("Fabric")),qMakePair(QString("net.minecraftforge"),QString("Forge")),qMakePair(QString("net.neoforged"),QString("NeoForge")),qMakePair(QString("org.quiltmc.quilt-loader"),QString("Quilt"))})
                if(!componentVersion(pair.first).isEmpty())loader=pair.second;
            rows.append(QVariantMap{{"key","prism:"+instance->id()},{"coverKey",loader=="Minecraft"?QString("vanilla"):loader.toLower()},{"label",instance->name()},{"version",loader+" "+game},{"hours",instance->totalTimePlayed()/3600.0},{"launches",0},{"installed",true},{"lastPlayed",false},{"running",instance->isRunning()}});
        }
        const bool changedRows=rows!=m_instances;m_instances=rows;
        if(m_status.isEmpty())m_status=QString("Built-in core ready · %1 instances").arg(rows.size());
        auto account=m_app->accounts()->defaultAccount();
        if(account && !account->accountData()->msaClientID.isEmpty() && account->accountData()->msaClientID!=m_app->getMSAClientID()
           && (m_status.startsWith("Built-in core ready") || m_status=="Microsoft account mode selected"))
            m_status="Microsoft account needs sign-in again: launcher client ID changed. Open Accounts and add the account again.";
        if(changedRows){emit instancesChanged();emit changed();}
        if(!m_pendingInstance.isEmpty()) {
            for(const auto &row:rows)if(row.toMap().value("key").toString()==m_pendingInstance) {
                const auto key=m_pendingInstance;m_pendingInstance.clear();emit instanceReady(key);break;
            }
        }
    }
    Q_INVOKABLE bool launch(const QString &key){
        if(installing() && key==m_installInstance){m_status="Wait for this instance’s installation to finish.";emit changed();return false;}
        if(offlineMode())return launchOffline(key,offlineName());
        auto *instance=lookup(key);if(!instance){m_status="Instance unavailable. Refresh the list.";emit changed();return false;}
        if(instance->isRunning() || !instance->canLaunch()){m_status="Instance is running or busy.";emit changed();return false;}
        const bool accepted=m_app->launch(instance);
        m_status=accepted?"Built-in core is preparing the game. Authentication or download dialogs may appear.":"Core rejected the launch request.";
        emit changed();return accepted;
    }
    Q_INVOKABLE void openInstance(const QString &key){auto *instance=lookup(key);if(instance)QDesktopServices::openUrl(QUrl::fromLocalFile(instance->instanceRoot()));}
    Q_INVOKABLE void promptOffline(const QString &key){bool ok=false;auto name=QInputDialog::getText(nullptr,"Play offline","Player name (3–16 letters, digits or underscores):",QLineEdit::Normal,"Player",&ok);if(ok)launchOffline(key,name);}
    Q_INVOKABLE bool launchOffline(const QString &key,const QString &name){
        if(installing() && key==m_installInstance){m_status="Wait for this instance’s installation to finish.";emit changed();return false;}
        auto *instance=lookup(key);const QString player=name.trimmed();
        if(!instance || !instance->canLaunch() || instance->isRunning()){m_status="Instance unavailable or busy.";emit changed();return false;}
        if(!QRegularExpression("^[A-Za-z0-9_]{3,16}$").match(player).hasMatch()){m_status="Use a player name with 3–16 letters, digits or underscores.";emit changed();return false;}
        auto account=MinecraftAccount::createOffline(player);
        if(!account){m_status="Could not create offline profile.";emit changed();return false;}
        m_status="Preparing offline play · "+player;emit changed();
        const bool accepted=m_app->launch(instance,LaunchMode::Offline,nullptr,account,player);
        if(!accepted){m_status="Offline launch was not accepted.";emit changed();}return accepted;
    }
    Q_INVOKABLE QString microsoftClientId()const{return m_app->getMSAClientID();}
    Q_INVOKABLE void setMicrosoftClientId(const QString &id){if(!QRegularExpression("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$").match(id.trimmed()).hasMatch()){m_status="Invalid Microsoft application client ID";emit changed();return;}m_app->settings()->set("MSAClientIDOverride",id.trimmed());m_status="Microsoft client ID saved";emit changed();}
    bool installing()const{return !m_installTask.isNull();}
    double installProgress()const{return m_installProgress;}
    Q_INVOKABLE bool installGame(const QString &gameVersion,const QString &loader,const QString &loaderVersion){
        if(installing())return false;
        const QRegularExpression safeVersion(QStringLiteral("^[A-Za-z0-9][A-Za-z0-9._+\\-]*$"));
        const QMap<QString,QString> loaders{{"Fabric","net.fabricmc.fabric-loader"},{"Forge","net.minecraftforge"},
                                          {"NeoForge","net.neoforged"},{"Quilt","org.quiltmc.quilt-loader"}};
        if(!safeVersion.match(gameVersion).hasMatch() ||
           (loader!="Vanilla" && (!loaders.contains(loader) || !safeVersion.match(loaderVersion).hasMatch()))) {
            m_status="Choose a Minecraft version and a compatible loader release.";emit changed();return false;
        }
        auto game=std::make_shared<Meta::Version>(QStringLiteral("net.minecraft"),gameVersion);
        VanillaCreationTask *creation=loader=="Vanilla" ? new VanillaCreationTask(game) :
            new VanillaCreationTask(game,loaders.value(loader),std::make_shared<Meta::Version>(loaders.value(loader),loaderVersion));
        creation->setName(loader=="Vanilla"?QString("Minecraft %1").arg(gameVersion):QString("%1 %2").arg(loader,gameVersion));
        creation->setIcon(loader=="Vanilla"?QStringLiteral("default"):loader.toLower());
        creation->setRequireGameFiles(true);
        return runInstall(m_app->instances()->wrapInstanceTask(creation));
    }
    Q_INVOKABLE bool installModrinth(const QString &key,const QString &category,const QString &projectId,
                                    const QString &name,const QVariantMap &release){
        if(installing())return false;
        auto reject=[this](const QString &reason){m_status=reason;emit changed();return false;};
        const auto raw=QJsonObject::fromVariantMap(release);
        if(projectId.isEmpty() || raw.value("project_id").toString()!=projectId)
            return reject("The selected release does not belong to this project.");
        auto parsed=Modrinth::loadIndexedPackVersion(raw);
        if(!parsed || !ModrinthInstallTask::validFile(*parsed))
            return reject("The selected release has invalid download metadata or no checksum.");
        auto version=*parsed;
        if(category=="Modpacks") {
            if(!version.fileName.endsWith(".mrpack",Qt::CaseInsensitive))return reject("Select a Modrinth .mrpack release.");
            QMap<QString,QString> info{{"pack_id",projectId},{"pack_version_id",version.fileId.toString()}};
            auto *creation=new InstanceImportTask(QUrl(version.downloadUrl),true,nullptr,info);
            creation->setName(name);creation->setIcon("default");creation->setRequireGameFiles(true);
            creation->setArchiveChecksum(version.hashType,version.hash);
            return runInstall(m_app->instances()->wrapInstanceTask(creation));
        }
        auto *instance=lookup(key);
        if(!instance || instance->isRunning() || !instance->canLaunch())return reject("Select a stopped, installed instance first.");
        auto *profile=instance->getPackProfile();
        if(!profile || !version.mcVersion.contains(profile->getComponentVersion("net.minecraft")))
            return reject("This release does not support the selected Minecraft version.");
        ResourceFolderModel *folder=nullptr;
        ModPlatform::ResourceType type=ModPlatform::ResourceType::Unknown;
        if(category=="Mods") {
            const auto loaders=profile->getSupportedModLoaders().value_or(ModPlatform::ModLoaderTypes(0));
            if(!loaders || !version.loaders || !version.loaders.testAnyFlags(loaders))
                return reject("This mod does not support the selected instance’s loader.");
            folder=instance->loaderModList();type=ModPlatform::ResourceType::Mod;
        }
        else if(category=="Resource packs") {folder=instance->resourcePackList();type=ModPlatform::ResourceType::ResourcePack;}
        else if(category=="Shaders") {folder=instance->shaderPackList();type=ModPlatform::ResourceType::ShaderPack;}
        else return reject("Unsupported Modrinth project category.");
        auto pack=std::make_shared<ModPlatform::IndexedPack>();
        pack->addonId=projectId;pack->name=name;pack->provider=ModPlatform::ResourceProvider::MODRINTH;pack->resourceType=type;
        m_installInstance=key;
        return runInstall(new ModrinthInstallTask(instance,folder,pack,version));
    }
    QVariantMap editorDetails()const{return m_editorDetails;}
    QString editorInstanceKey()const{return m_editorKey;}
    Q_INVOKABLE QVariantMap instanceDetails(const QString &key)const {
        auto *instance=lookup(key);if(!instance)return {{"key",key},{"error","Instance unavailable"}};
        auto data=InstanceEditorFiles::snapshot(instance->instanceRoot(),editorFolders(instance));
        auto mods=data.value("mods").toList();
        for(auto &entry:mods){auto row=entry.toMap();QFileInfo file(QUrl(row.value("source").toString()).toLocalFile());
            const auto cacheKey=file.absoluteFilePath()+":"+QString::number(file.size())+":"+QString::number(file.lastModified().toMSecsSinceEpoch());
            if(!m_modDisplayCache.contains(cacheKey)) {
                QVariantMap info;Mod mod(file);
                if(ModUtils::process(mod)){info.insert("name",mod.name());info.insert("version",mod.version());auto icon=mod.icon(QSize(64,64),Qt::KeepAspectRatio);if(!icon.isNull()){QByteArray bytes;QBuffer out(&bytes);out.open(QIODevice::WriteOnly);icon.save(&out,"PNG");info.insert("icon","data:image/png;base64,"+QString::fromLatin1(bytes.toBase64()));}}
                m_modDisplayCache.insert(cacheKey,info);
            }
            const auto info=m_modDisplayCache.value(cacheKey);for(auto it=info.begin();it!=info.end();++it)if(!it.value().toString().isEmpty())row.insert(it.key(),it.value());entry=row;
        }data.insert("mods",mods);
        auto *settings=instance->settings();
        data.insert("key",key);data.insert("name",instance->name());data.insert("notes",instance->notes());
        data.insert("javaPath",settings->get("JavaPath").toString());data.insert("javaArgs",settings->get("JvmArgs").toString());
        data.insert("useDefaultMemory",!settings->get("OverrideMemory").toBool());data.insert("memoryMiB",settings->get("MaxMemAlloc").toInt());
        data.insert("running",instance->isRunning());return data;
    }
    Q_INVOKABLE void watchInstance(const QString &key) {m_editorKey=key;refreshEditor();}
    Q_INVOKABLE void refreshEditor() {
        const auto old=m_editorDetails;
        if(m_editorKey.isEmpty())m_editorDetails.clear();else m_editorDetails=instanceDetails(m_editorKey);
        const auto watched=m_editorWatcher->directories()+m_editorWatcher->files();if(!watched.isEmpty())m_editorWatcher->removePaths(watched);
        if(auto *instance=lookup(m_editorKey)) {
            QStringList paths{instance->instanceRoot()};
            for(const auto &path:editorFolders(instance))if(QFileInfo(path).exists())paths.append(path);
            const QDir game(instance->gameRoot());
            for(const auto &path:{QDir(instance->instanceRoot()).filePath("instance.cfg"),QDir(instance->instanceRoot()).filePath("mmc-pack.json"),game.filePath("servers.dat"),game.filePath("logs"),game.filePath("logs/latest.log"),game.filePath("crash-reports")})if(QFileInfo(path).exists())paths.append(path);
            paths.removeDuplicates();m_editorWatcher->addPaths(paths);
        }
        if(old!=m_editorDetails)emit editorDetailsChanged();
    }
    Q_INVOKABLE bool saveEditorSettings(const QString &key,const QVariantMap &patch) {
        auto *instance=lookup(key);if(!instance)return editorError("Instance unavailable");
        if(patch.contains("name") && patch.value("name").toString().trimmed().isEmpty())return editorError("Enter an instance name");
        if(patch.contains("memoryMiB") && (patch.value("memoryMiB").toInt()<128 || patch.value("memoryMiB").toInt()>1048576))return editorError("Invalid memory allocation");
        auto *settings=instance->settings();
        {
            SettingsObject::Lock lock(settings);
            if(patch.contains("name"))instance->setName(patch.value("name").toString().trimmed());
            if(patch.contains("notes"))instance->setNotes(patch.value("notes").toString());
            if(patch.contains("useDefaultMemory"))settings->set("OverrideMemory",!patch.value("useDefaultMemory").toBool());
            if(patch.contains("memoryMiB")) {
                const int memory=patch.value("memoryMiB").toInt();settings->set("OverrideMemory",true);settings->set("MaxMemAlloc",memory);
                if(settings->get("MinMemAlloc").toInt()>memory)settings->set("MinMemAlloc",memory);
            }
            if(patch.contains("javaPath")) {
                const auto value=patch.value("javaPath").toString().trimmed();settings->set("OverrideJavaLocation",!value.isEmpty());
                if(!value.isEmpty())settings->set("JavaPath",value);
            }
            if(patch.contains("javaArgs")) {
                const auto value=patch.value("javaArgs").toString();settings->set("OverrideJavaArgs",!value.isEmpty());
                if(!value.isEmpty())settings->set("JvmArgs",value);
            }
        }
        m_status="Instance settings saved";refresh();refreshEditor();emit changed();return true;
    }
    Q_INVOKABLE bool importEditorAsset(const QString &key,const QString &bucket,const QUrl &source) {
        auto *instance=editableInstance(key);if(!instance)return false;
        auto *model=editorResourceModel(instance,bucket);if(!model || !source.isLocalFile())return editorError("Choose a local mod or pack file");
        const QFileInfo file(source.toLocalFile());const auto name=file.fileName();
        if(!file.isFile() || file.isSymLink() || !file.isReadable())return editorError("Cannot read the selected file");
        if(QFileInfo::exists(model->dir().filePath(name)) || QFileInfo::exists(model->dir().filePath(name+".disabled")))return editorError("A file with this name is already installed");
        if(!QDir().mkpath(model->dir().absolutePath()) || !model->installResource(file.absoluteFilePath()))return editorError("Could not import "+name);
        model->startWatching();refreshEditor();m_status="Imported "+name;emit changed();return true;
    }
    Q_INVOKABLE bool setEditorAssetEnabled(const QString &key,const QString &bucket,const QString &fileName,bool enabled) {
        auto *instance=editableInstance(key);if(!instance)return false;
        if(!editorResourceModel(instance,bucket))return editorError("This entry cannot be enabled or disabled");
        const auto path=editorAssetPath(instance,bucket,fileName);if(path.isEmpty())return editorError("File is unavailable; refresh the list");
        Resource resource{QFileInfo(path)};
        if(resource.enabled()!=enabled && !resource.enable(enabled?EnableAction::ENABLE:EnableAction::DISABLE))return editorError("Could not change "+fileName);
        refreshEditor();return true;
    }
    Q_INVOKABLE bool removeEditorAsset(const QString &key,const QString &bucket,const QString &fileName) {
        auto *instance=editableInstance(key);if(!instance)return false;
        const auto path=editorAssetPath(instance,bucket,fileName);if(path.isEmpty())return editorError("File is unavailable; refresh the list");
        if(!QFile::moveToTrash(path))return editorError("Could not move this entry to Trash");
        refreshEditor();m_status="Moved to Trash";emit changed();return true;
    }
    Q_INVOKABLE void openEditorFolder(const QString &key,const QString &bucket) {
        auto *instance=lookup(key);if(!instance)return;
        const auto path=editorFolders(instance).value(bucket);if(path.isEmpty())return;
        if(QDir().mkpath(path))QDesktopServices::openUrl(QUrl::fromLocalFile(path));
    }
    Q_INVOKABLE void revealEditorAsset(const QString &key,const QString &bucket,const QString &fileName) {
        auto *instance=lookup(key);if(!instance)return;const auto path=editorAssetPath(instance,bucket,fileName);if(path.isEmpty())return;
#ifdef Q_OS_MACOS
        QProcess::startDetached(QStringLiteral("open"),QStringList{QStringLiteral("-R"),path});
#else
        QDesktopServices::openUrl(QUrl::fromLocalFile(QFileInfo(path).isDir()?path:QFileInfo(path).absolutePath()));
#endif
    }
    Q_INVOKABLE bool editServer(const QString &key,const QString &address,int removeIndex) {
        auto *instance=editableInstance(key);if(!instance)return false;QString error;
        if(!QDir().mkpath(instance->gameRoot()))return editorError("Could not open the game directory");
        if(!InstanceEditorFiles::changeServer(QDir(instance->gameRoot()).filePath("servers.dat"),address,removeIndex,error))return editorError(error);
        refreshEditor();return true;
    }
    Q_INVOKABLE void signIn(){
        if(m_app->getMSAClientID().trimmed().isEmpty()){m_status="Microsoft sign-in needs a registered client ID. Open Settings to configure it.";emit changed();return;}
        if(m_loginTask)return;
        m_loginAccount=MinecraftAccount::createBlankMSA();
        auto *task=new AuthFlow(m_loginAccount->accountData(),AuthFlow::Action::DeviceCode);m_loginTask=task;
        m_loginCode.clear();m_loginUrl.clear();m_status="Preparing Microsoft sign-in";emit changed();
        connect(task,&AuthFlow::authorizeWithBrowserWithExtra,this,[this](QString url,QString code,int){m_loginUrl=url;m_loginCode=code;emit changed();});
        connect(task,&Task::status,this,[this](const QString &status){m_status=status;emit changed();});
        connect(task,&Task::succeeded,this,[this,task]{
            auto *accounts=m_app->accounts();int existing=-1;
            for(int i=0;i<accounts->count();++i)if(accounts->at(i)->profileId()==m_loginAccount->profileId())existing=i;
            if(existing>=0)accounts->removeAccount(accounts->index(existing,0));
            accounts->addAccount(m_loginAccount);accounts->setDefaultAccount(m_loginAccount);
            m_loginTask=nullptr;task->deleteLater();setOfflineMode(false);m_status="Microsoft account added";emit changed();
        });
        connect(task,&Task::failed,this,[this,task](const QString &reason){m_status="Sign-in failed: "+reason;m_loginTask=nullptr;task->deleteLater();emit changed();});
        connect(task,&Task::aborted,this,[this,task]{m_status="Sign-in cancelled";m_loginTask=nullptr;task->deleteLater();emit changed();});
        task->start();
    }
    bool signingIn()const{return !m_loginTask.isNull();}
    Q_INVOKABLE void copyLoginCode(){QApplication::clipboard()->setText(m_loginCode);}
    QString loginQr()const {
        if(m_loginUrl.isEmpty())return {};
        QUrl url(m_loginUrl);if(!m_loginCode.isEmpty()){QUrlQuery query(url);query.addQueryItem("otc",m_loginCode);url.setQuery(query);}
        auto *qr=QRcode_encodeString(url.toString().toUtf8().constData(),0,QR_ECLEVEL_M,QR_MODE_8,1);if(!qr)return {};
        const int n=qr->width;QImage image((n+8)*4,(n+8)*4,QImage::Format_RGB32);image.fill(Qt::white);
        QPainter painter(&image);painter.setPen(Qt::NoPen);painter.setBrush(Qt::black);
        for(int y=0;y<n;++y)for(int x=0;x<n;++x)if(qr->data[y*n+x]&1)painter.drawRect((x+4)*4,(y+4)*4,4,4);
        painter.end();QRcode_free(qr);QByteArray png;QBuffer buffer(&png);buffer.open(QIODevice::WriteOnly);image.save(&buffer,"PNG");return "data:image/png;base64,"+QString::fromLatin1(png.toBase64());
    }
    QString loginCode()const{return m_loginCode;}
    QString loginUrl()const{return m_loginUrl;}
    Q_INVOKABLE void cancelSignIn(){if(m_loginTask)m_loginTask->abort();}
    QString currentAccountName()const{auto a=m_app->accounts()->defaultAccount();return a?a->profileName():QString();}
    QVariantList savedAccounts()const {
        QVariantList rows;auto *accounts=m_app->accounts();
        for(int i=0;i<accounts->count();++i){auto a=accounts->at(i);rows.append(QVariantMap{{"id",a->internalId()},{"name",a->profileName()},{"selected",a==accounts->defaultAccount()},{"type",a->typeString()}});}return rows;
    }
    Q_INVOKABLE void selectSavedAccount(const QString &id){auto *accounts=m_app->accounts();for(int i=0;i<accounts->count();++i)if(accounts->at(i)->internalId()==id){accounts->setDefaultAccount(accounts->at(i));setOfflineMode(false);emit changed();return;}}
    Q_INVOKABLE void removeSavedAccount(const QString &id){auto *accounts=m_app->accounts();for(int i=0;i<accounts->count();++i)if(accounts->at(i)->internalId()==id){accounts->removeAccount(accounts->index(i,0));if(!accounts->defaultAccount() && accounts->count())accounts->setDefaultAccount(accounts->at(0));if(!accounts->count())setOfflineMode(true);emit changed();return;}}
    Q_INVOKABLE void openAccounts(){m_app->ShowGlobalSettings(nullptr,"accounts");}
    Q_INVOKABLE void openCoreSettings(){m_app->ShowGlobalSettings(nullptr);}
    Q_INVOKABLE void openLogs(){QDesktopServices::openUrl(QUrl::fromLocalFile(dataRoot()+"/logs"));}
signals:
    void editorDetailsChanged();
    void instanceReady(const QString &key);
    void instancesChanged();
    void changed();
private:
    mutable QHash<QString,QVariantMap> m_modDisplayCache;
    QPointer<AccountList> m_observedAccounts;
    QPointer<AuthFlow> m_loginTask;
    MinecraftAccountPtr m_loginAccount;
    QString m_loginCode,m_loginUrl;
    bool editorError(const QString &message){m_status=message;emit changed();return false;}
    MinecraftInstance *editableInstance(const QString &key) {
        auto *instance=lookup(key);
        if(!instance || instance->isRunning() || (installing() && m_installInstance==key)){editorError("Stop the instance and finish its installation before changing files");return nullptr;}
        return instance;
    }
    static QMap<QString,QString> editorFolders(MinecraftInstance *instance) {
        return {{"game",instance->gameRoot()},{"mods",instance->modsRoot()},{"resourcePacks",instance->resourcePacksDir()},
                {"shaderPacks",instance->shaderPacksDir()},{"worlds",instance->worldDir()},{"screenshots",QDir(instance->gameRoot()).filePath("screenshots")}};
    }
    static ResourceFolderModel *editorResourceModel(MinecraftInstance *instance,const QString &bucket) {
        if(bucket=="mods")return instance->loaderModList();if(bucket=="resourcePacks")return instance->resourcePackList();
        if(bucket=="shaderPacks")return instance->shaderPackList();return nullptr;
    }
    static QString editorAssetPath(MinecraftInstance *instance,const QString &bucket,const QString &name) {
        if(name.isEmpty() || name=="." || name==".." || name.contains('/') || name.contains('\\'))return {};
        const auto directory=editorFolders(instance).value(bucket);if(directory.isEmpty() || bucket=="game")return {};
        const QFileInfo file(QDir(directory).filePath(name));if(!file.exists() || file.isSymLink())return {};
        return file.absoluteFilePath();
    }
    bool runInstall(Task *task){
        task->setParent(this);m_installTask=task;m_installProgress=0;
        connect(task,&Task::status,this,[this](const QString &status){m_status=status;emit changed();});
        connect(task,&Task::progress,this,[this](qint64 current,qint64 total){m_installProgress=total>0?qBound(0.0,double(current)/double(total),1.0):0;emit changed();});
        connect(task,&Task::succeeded,this,[this,task]{m_installTask=nullptr;m_installInstance.clear();m_installProgress=1;m_status="Installation complete";refresh();refreshEditor();emit changed();task->deleteLater();});
        connect(task,&Task::failed,this,[this,task](const QString &reason){m_installTask=nullptr;m_installInstance.clear();m_status="Installation failed · "+reason;emit changed();task->deleteLater();});
        connect(task,&Task::aborted,this,[this,task]{m_installTask=nullptr;m_installInstance.clear();m_status="Installation cancelled";emit changed();task->deleteLater();});
        m_status="Preparing installation…";emit changed();task->start();return true;
    }
    MinecraftInstance *lookup(const QString &key)const{return key.startsWith("prism:") && m_app->instances()?m_app->instances()->getInstanceById(key.mid(6)):nullptr;}
    QFileSystemWatcher *m_editorWatcher=nullptr;
    QTimer *m_editorReload=nullptr;
    QString m_editorKey;QVariantMap m_editorDetails;
    QTimer *m_refreshSoon=nullptr;
    QPointer<InstanceList> m_observedInstances;
    QString m_pendingInstance;
    QString m_installInstance;
    QPointer<Task> m_installTask;double m_installProgress=0;
    Application *m_app;QString m_status;QVariantList m_instances;
};
