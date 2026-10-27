#include "PrismBridge.h"
#include <QCoreApplication>
#include <QTemporaryDir>
#include <QThread>
#include <cstdio>
static void check(bool ok,const char *message){if(!ok){fprintf(stderr,"FAIL: %s\n",message);exit(1);}}
static void write(const QString &path,const QByteArray &data){QFile f(path);check(f.open(QIODevice::WriteOnly),"fixture open");check(f.write(data)==data.size(),"fixture write");}
int main(int argc,char **argv){
    QCoreApplication app(argc,argv);app.setApplicationName("GlassBridgeTest");
    QTemporaryDir temp;check(temp.isValid(),"temporary directory");
    qputenv("XDG_DATA_HOME",temp.path().toUtf8());
    QSettings::setDefaultFormat(QSettings::IniFormat);QSettings::setPath(QSettings::IniFormat,QSettings::UserScope,temp.path());
    const QString root=temp.path()+"/Prism data",instance=root+"/custom instances/My Test World";
    check(QDir().mkpath(instance),"fixture folders");
    const QByteArray config="[General]\nInstanceDir=custom instances\n";
    write(root+"/prismlauncher.cfg",config);
    write(instance+"/instance.cfg","[General]\nInstanceType=OneSix\nname=Real world\ntotalTimePlayed=7200\n");
    write(instance+"/mmc-pack.json",R"({"components":[{"uid":"net.minecraft","version":"1.21.5"},{"uid":"net.fabricmc.fabric-loader","version":"0.16.14"}]})");
    const QString executable=temp.path()+"/Fake Prism";
    write(executable,"#!/bin/sh\nprintf '%s\\n' \"$@\"\n");QFile::setPermissions(executable,QFile::ReadOwner|QFile::WriteOwner|QFile::ExeOwner);
    PrismBridge bridge;bridge.configure(executable,root);
    check(bridge.instances().size()==1,"custom InstanceDir discovery");
    const auto record=bridge.instances().first().toMap();check(record.value("label").toString()=="Real world","display name");check(record.value("version").toString()=="Fabric 1.21.5","loader metadata");
    check(!bridge.launch("prism:../invalid"),"unknown ID rejected");
    check(bridge.launch(record.value("key").toString()),"CLI handoff");check(!bridge.launch(record.value("key").toString()),"duplicate guard");
    QStringList logs;const QString logDir=QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation)+"/prism-launch-logs";
    QByteArray output;
    for(int i=0;i<100;i++){logs=QDir(logDir).entryList({"*.log"},QDir::Files);if(!logs.isEmpty()){QFile f(logDir+"/"+logs.first());if(f.open(QIODevice::ReadOnly))output=f.readAll();if(!output.isEmpty())break;}QThread::msleep(20);}
    check(output=="--dir\n"+root.toUtf8()+"\n--launch\nMy Test World\n","literal argv with spaces");
    QFile unchanged(root+"/prismlauncher.cfg");unchanged.open(QIODevice::ReadOnly);check(unchanged.readAll()==config,"Prism config untouched");
    bridge.configure(executable,temp.path()+"/missing");check(bridge.instances().isEmpty(),"invalid root clears discovery");
    puts("PASS: discovery, loader metadata, literal launch args, duplicate guard, read-only config, invalid root");
}
