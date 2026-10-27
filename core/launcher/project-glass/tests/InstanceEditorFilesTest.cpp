// SPDX-License-Identifier: GPL-3.0-only
// Standalone Qt Core + libnbt++ test of the actual editor filesystem reader.
#include "../InstanceEditorFiles.h"
#include <QCoreApplication>
#include <QTemporaryDir>
#include <cassert>
#include <iostream>
#include <tag_primitive.h>
static void write(const QString &path,const QByteArray &bytes) {
    QDir().mkpath(QFileInfo(path).absolutePath());QFile file(path);assert(file.open(QIODevice::WriteOnly));assert(file.write(bytes)==bytes.size());
}
int main(int argc,char **argv) {
    QCoreApplication app(argc,argv);QTemporaryDir temporary;assert(temporary.isValid());
    const QString root=temporary.path(),game=QDir(root).filePath("minecraft");
    QMap<QString,QString> folders{{"game",game},{"mods",game+"/mods"},{"resourcePacks",game+"/resourcepacks"},{"shaderPacks",game+"/shaderpacks"},{"worlds",game+"/saves"},{"screenshots",game+"/screenshots"}};
    write(game+"/mods/active.jar","active");write(game+"/mods/paused.jar.disabled","paused");write(game+"/mods/ignored.txt","not a mod");
    write(game+"/resourcepacks/pack.zip","pack");write(game+"/shaderpacks/shader.zip","shader");
    write(game+"/saves/My World/level.dat","world");QDir().mkpath(game+"/saves/Not a World");
    write(game+"/screenshots/image.png","image");write(game+"/screenshots/ignored.txt","ignored");
    write(game+"/logs/latest.log",QByteArray(600*1024,'x')+"\nLAST LOG LINE");write(game+"/crash-reports/crash.txt","actual crash report");
    write(root+"/mmc-pack.json",R"({"components":[{"uid":"net.minecraft","version":"1.20.1"},{"uid":"net.fabricmc.fabric-loader","version":"0.16.14"}]})");
    QString error;assert(InstanceEditorFiles::changeServer(game+"/servers.dat","one.example",-1,error));
    auto data=InstanceEditorFiles::snapshot(root,folders);
    assert(data.value("mods").toList().size()==2);
    assert(data.value("mods").toList()[0].toMap().value("enabled").toBool());
    assert(!data.value("mods").toList()[1].toMap().value("enabled").toBool());
    assert(data.value("resourcePacks").toList().size()==1 && data.value("shaderPacks").toList().size()==1);
    assert(data.value("worlds").toList().size()==1 && data.value("screenshots").toList().size()==1);
    assert(data.value("components").toList().size()==2);
    assert(data.value("minecraftLog").toString().startsWith("[Showing the end"));
    assert(data.value("minecraftLog").toString().endsWith("LAST LOG LINE"));
    assert(data.value("otherLogs").toString().contains("actual crash report"));
    assert(data.value("servers").toList()[0].toMap().value("address")=="one.example");
    assert(data.value("error").toString().isEmpty());
    // Unknown root fields and server metadata survive additions/removals.
    auto doc=InstanceEditorFiles::serverDocument(game+"/servers.dat");
    doc->put("extra",nbt::tag_int(42));
    doc->at("servers").as<nbt::tag_list>()[0].as<nbt::tag_compound>().put("icon",std::string("preserved-icon"));
    std::ostringstream stream;nbt::io::write_tag("",*doc,stream);write(game+"/servers.dat",QByteArray::fromStdString(stream.str()));
    assert(InstanceEditorFiles::changeServer(game+"/servers.dat","two.example",-1,error));
    doc=InstanceEditorFiles::serverDocument(game+"/servers.dat");
    assert(doc->at("extra").as<nbt::tag_int>().get()==42);
    assert(std::string(doc->at("servers").as<nbt::tag_list>()[0].as<nbt::tag_compound>().at("icon"))=="preserved-icon");
    assert(!InstanceEditorFiles::changeServer(game+"/servers.dat","wrong.example",0,error));
    assert(InstanceEditorFiles::changeServer(game+"/servers.dat","one.example",0,error));
    QStringList errors;assert(InstanceEditorFiles::servers(game+"/servers.dat",errors).size()==1);
    assert(InstanceEditorFiles::servers(game+"/servers.dat",errors)[0].toMap().value("address")=="two.example");
    write(game+"/servers.dat","corrupt servers file");
    assert(!InstanceEditorFiles::changeServer(game+"/servers.dat","three.example",-1,error));
    QFile file(game+"/servers.dat");assert(file.open(QIODevice::ReadOnly));assert(file.readAll()=="corrupt servers file");
    assert(InstanceEditorFiles::snapshot(root,folders).value("error").toString().contains("servers.dat"));
    std::cout<<"Actual instance directories, log tails, components and NBT server read/write checks passed\n";
}
