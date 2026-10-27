// SPDX-License-Identifier: GPL-3.0-only
#pragma once

#include <QPointer>
#include <QUrl>
#include <QFileInfo>
#include <QRegularExpression>
#include "ResourceDownloadTask.h"
#include "minecraft/MinecraftInstance.h"
#include "minecraft/PackProfile.h"
#include "minecraft/mod/ResourcePackFolderModel.h"
#include "minecraft/mod/ShaderPackFolderModel.h"
#include "minecraft/mod/tasks/GetModDependenciesTask.h"

// The frontend uses the same dependency resolver, index and checksum-verified
// resource downloads as Prism's resource dialog, without a second selection UI.
class ModrinthInstallTask final : public Task {
public:
    ModrinthInstallTask(MinecraftInstance *instance, ResourceFolderModel *folder,
                       ModPlatform::IndexedPack::Ptr pack, ModPlatform::IndexedVersion version)
        : m_instance(instance),m_folder(folder),m_pack(std::move(pack)),m_version(std::move(version)) {}

    static bool validFile(const ModPlatform::IndexedVersion &version) {
        const QUrl url(version.downloadUrl);
        const int length=version.hashType=="sha512"?128:version.hashType=="sha1"?40:0;
        return url.isValid() && url.scheme()=="https" && !url.host().isEmpty() &&
            !version.fileName.isEmpty() && version.fileName!="." && version.fileName!=".." &&
            !version.fileName.contains('/') && !version.fileName.contains('\\') &&
            length>0 && version.hash.size()==length &&
            QRegularExpression(QStringLiteral("^[0-9a-fA-F]+$")).match(version.hash).hasMatch();
    }
    bool canAbort()const override {return m_current && m_current->canAbort();}
    bool abort()override {return m_current && m_current->abort();}

protected:
    void executeTask()override {
        if(!m_instance || !m_folder || m_instance->isRunning()) {
            emitFailed(tr("The target instance is unavailable or running."));return;
        }
        if(auto *mods=qobject_cast<ModFolderModel *>(m_folder.data())) {
            mods->startWatching();
            QList<std::shared_ptr<GetModDependenciesTask::PackDependency>> selected{
                std::make_shared<GetModDependenciesTask::PackDependency>(m_pack,m_version)};
            m_dependencies=makeShared<GetModDependenciesTask>(m_instance,mods,selected);
            connect(m_dependencies.get(),&Task::succeeded,this,[this]{
                if(!m_dependencies->warnings().isEmpty()) {
                    emitFailed(tr("Dependencies could not be fully resolved: %1").arg(m_dependencies->warnings().join('\n')));return;
                }
                startDownloads();
            });
            runSubtask(m_dependencies);
        } else startDownloads();
    }
private:
    void runSubtask(const Task::Ptr &task) {
        m_current=task;
        propagateFromOther(task.get());
        connect(task.get(),&Task::failed,this,&ModrinthInstallTask::emitFailed);
        connect(task.get(),&Task::aborted,this,&ModrinthInstallTask::emitAborted);
        task->start();
    }
    void startDownloads() {
        if(!m_instance || !m_folder || m_instance->isRunning()) {
            emitFailed(tr("The target instance is unavailable or running."));return;
        }
        QList<std::shared_ptr<GetModDependenciesTask::PackDependency>> resources;
        if(m_dependencies)resources=m_dependencies->getDependecies();
        resources.append(std::make_shared<GetModDependenciesTask::PackDependency>(m_pack,m_version));
        const auto game=m_instance->getPackProfile()->getComponentVersion("net.minecraft");
        const auto loaders=m_instance->getPackProfile()->getSupportedModLoaders().value_or(ModPlatform::ModLoaderTypes(0));
        for(const auto &resource:resources) {
            if(!resource->pack || !validFile(resource->version) || !resource->version.mcVersion.contains(game) ||
               (m_pack->resourceType==ModPlatform::ResourceType::Mod &&
                (!loaders || !resource->version.loaders || !resource->version.loaders.testAnyFlags(loaders)))) {
                emitFailed(tr("A selected resource or dependency is incompatible or has invalid download metadata."));return;
            }
        }
        m_downloads=makeShared<SequentialTask>(tr("Installing Modrinth resources"));
        for(const auto &resource:resources) {
            m_downloads->addTask(makeShared<ResourceDownloadTask>(resource->pack,resource->version,m_folder.data(),true,
                resource->pack->addonId==m_pack->addonId?QStringLiteral("standalone"):QStringLiteral("dependency"),
                resource->pack->addonId==m_pack->addonId?QString():m_pack->addonId.toString()));
        }
        connect(m_downloads.get(),&Task::succeeded,this,[this]{
            if(m_folder)m_folder->startWatching();
            emitSucceeded();
        });
        runSubtask(m_downloads);
    }
    QPointer<MinecraftInstance> m_instance;
    QPointer<ResourceFolderModel> m_folder;
    ModPlatform::IndexedPack::Ptr m_pack;
    ModPlatform::IndexedVersion m_version;
    GetModDependenciesTask::Ptr m_dependencies;
    Task::Ptr m_current;
    shared_qobject_ptr<SequentialTask> m_downloads;
};
