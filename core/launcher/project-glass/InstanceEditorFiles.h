// SPDX-License-Identifier: GPL-3.0-only
#pragma once
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QUrl>
#include <QVariantMap>
#include <memory>
#include <stdexcept>
#include <QMap>
#include <sstream>
#include <io/stream_reader.h>
#include <io/stream_writer.h>
#include <tag_compound.h>
#include <tag_list.h>
#include <tag_string.h>

namespace InstanceEditorFiles {
inline QVariantList entries(const QString &path,const QString &kind,QStringList &errors) {
    QVariantList result;QDir dir(path);
    if(!dir.exists())return result;
    if(!QFileInfo(path).isReadable()){errors.append("Cannot read "+path);return result;}
    for(const auto &file:dir.entryInfoList(QDir::Files|QDir::Dirs|QDir::NoDotAndDotDot,QDir::Name|QDir::IgnoreCase)) {
        QString name=file.fileName(),active=name;
        const bool enabled=!name.endsWith(".disabled",Qt::CaseInsensitive);
        if(!enabled)active.chop(9);
        const QString ext=QFileInfo(active).suffix().toLower();
        if(kind=="worlds" && (!file.isDir() || !QFile::exists(QDir(file.filePath()).filePath("level.dat"))))continue;
        if(kind=="screenshots" && (file.isDir() || !QStringList{"png","jpg","jpeg","webp","bmp"}.contains(ext)))continue;
        if(kind=="mods" && !file.isDir() && ext!="jar" && ext!="litemod")continue;
        if((kind=="resourcePacks" || kind=="shaderPacks") && !file.isDir() && ext!="zip")continue;
        result.append(QVariantMap{{"name",active},{"fileName",name},{"source",QUrl::fromLocalFile(file.absoluteFilePath()).toString()},
                                  {"enabled",enabled},{"size",file.size()},{"directory",file.isDir()}});
    }
    return result;
}
inline QString tail(const QString &path,qint64 limit,QStringList &errors) {
    QFile file(path);if(!file.exists())return {};
    if(!file.open(QIODevice::ReadOnly)){errors.append("Cannot read "+path+": "+file.errorString());return {};}
    const bool shortened=file.size()>limit;if(shortened)file.seek(file.size()-limit);
    return (shortened?QStringLiteral("[Showing the end of this log]\n"):QString())+QString::fromUtf8(file.read(limit));
}
inline QVariantList components(const QString &root,QStringList &errors) {
    QFile file(QDir(root).filePath("mmc-pack.json"));if(!file.exists())return {};
    if(!file.open(QIODevice::ReadOnly)){errors.append(file.errorString());return {};}
    QJsonParseError error;const auto doc=QJsonDocument::fromJson(file.readAll(),&error);
    if(error.error!=QJsonParseError::NoError){errors.append("Invalid mmc-pack.json: "+error.errorString());return {};}
    QVariantList result;
    for(const auto &value:doc.object().value("components").toArray()) {
        const auto component=value.toObject();
        result.append(QVariantMap{{"uid",component.value("uid").toString()},{"version",component.value("version").toString()},
                                  {"name",component.value("cachedName").toString(component.value("uid").toString())}});
    }
    return result;
}
inline std::unique_ptr<nbt::tag_compound> serverDocument(const QString &path) {
    QFile file(path);if(!file.exists())return std::make_unique<nbt::tag_compound>();
    if(!file.open(QIODevice::ReadOnly) || file.size()>64*1024*1024)throw std::runtime_error("Cannot read servers.dat");
    const auto bytes=file.readAll();std::istringstream stream(std::string(bytes.constData(),bytes.size()));
    auto document=nbt::io::read_compound(stream);
    if(!document.second)throw std::runtime_error("Invalid servers.dat");
    return std::move(document.second);
}
inline QVariantList servers(const QString &path,QStringList &errors) {
    QVariantList result;
    try {
        auto document=serverDocument(path);if(!document->has_key("servers"))return result;
        const auto &list=document->at("servers").as<nbt::tag_list>();
        int index=0;for(const auto &entry:list) {
            const auto &server=entry.as<nbt::tag_compound>();
            const std::string name(server.at("name")),address(server.at("ip"));
            result.append(QVariantMap{{"name",QString::fromUtf8(name.c_str())},{"address",QString::fromUtf8(address.c_str())},{"index",index++}});
        }
    } catch(const std::exception &error){errors.append("Cannot read servers.dat: "+QString::fromUtf8(error.what()));}
    return result;
}
inline bool changeServer(const QString &path,const QString &address,int removeIndex,QString &error) {
    try {
        auto document=serverDocument(path);nbt::tag_list list;
        if(document->has_key("servers")) {
            const auto &old=document->at("servers").as<nbt::tag_list>();
            if(removeIndex>=int(old.size()))throw std::runtime_error("Server no longer exists; refresh the list");
            int index=0;for(const auto &entry:old) {
                if(index++==removeIndex) {
                    const std::string oldAddress(entry.as<nbt::tag_compound>().at("ip"));
                    if(!address.isEmpty() && QString::fromUtf8(oldAddress.c_str())!=address)throw std::runtime_error("The server list changed; refresh it before removing an entry");
                    continue;
                }
                list.push_back(nbt::tag_compound(entry.as<nbt::tag_compound>()));
            }
        } else if(removeIndex>=0)throw std::runtime_error("Server no longer exists");
        if(removeIndex<0) {
            if(address.trimmed().isEmpty())throw std::runtime_error("Enter a server address");
            nbt::tag_compound server;const auto value=address.trimmed().toUtf8().toStdString();
            server.insert("name",std::string(value));server.insert("ip",std::string(value));list.push_back(std::move(server));
        }
        document->put("servers",nbt::value(std::move(list)));
        std::ostringstream stream;nbt::io::write_tag("",*document,stream);const auto data=stream.str();
        QSaveFile file(path);if(!file.open(QIODevice::WriteOnly) || file.write(data.data(),qint64(data.size()))!=qint64(data.size()) || !file.commit()) {
            error=file.errorString();return false;
        }
        return true;
    } catch(const std::exception &exception){error=QString::fromUtf8(exception.what());return false;}
}
inline QVariantMap snapshot(const QString &root,const QMap<QString,QString> &folders) {
    QVariantMap data;QStringList errors;
    for(auto it=folders.cbegin();it!=folders.cend();++it) {
        if(it.key()!="game")data.insert(it.key(),entries(it.value(),it.key(),errors));
        data.insert(it.key()+"Folder",QUrl::fromLocalFile(it.value()).toString());
    }
    const QString game=folders.value("game");data.remove("game");
    data.insert("components",components(root,errors));
    data.insert("minecraftLog",tail(QDir(game).filePath("logs/latest.log"),512*1024,errors));
    QString other;
    for(const auto &directory:{QDir(game).filePath("logs"),QDir(game).filePath("crash-reports")}) {
        for(const auto &file:QDir(directory).entryInfoList({"*.log","*.txt"},QDir::Files,QDir::Time).mid(0,6)) {
            if(file.fileName()=="latest.log")continue;
            other+="\n—— "+file.fileName()+" ——\n"+tail(file.filePath(),128*1024,errors);
        }
    }
    data.insert("otherLogs",other);data.insert("servers",servers(QDir(game).filePath("servers.dat"),errors));
    data.insert("error",errors.join('\n'));return data;
}
}
