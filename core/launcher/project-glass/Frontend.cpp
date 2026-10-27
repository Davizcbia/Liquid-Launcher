// SPDX-License-Identifier: GPL-3.0-only
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QQuickStyle>
#include <QTimer>
#include <QPointer>
#include <QEvent>
#include <QApplication>
#include <QStyleFactory>
#include <QWindow>
#include <QWidget>
#include <QMenu>
#ifdef Q_OS_MACOS
void clearMacPopupBackground(QWindow *window);
#endif
class PopupTransparency final:public QObject {
public:using QObject::QObject;
 bool eventFilter(QObject *object,QEvent *event)override {
  if(event->type()==QEvent::Polish){
   if(auto *widget=qobject_cast<QWidget *>(object)) {
    if(widget->isWindow() && (widget->windowType()==Qt::Popup || widget->windowType()==Qt::ToolTip)) {
     widget->setAttribute(Qt::WA_TranslucentBackground,true);
     widget->setAutoFillBackground(false);
    }
   }
  }
  if(event->type()==QEvent::Show || event->type()==QEvent::Expose){
#ifdef Q_OS_MACOS
   if(auto *widget=qobject_cast<QWidget *>(object)) {
    if(widget->isWindow() && (widget->windowType()==Qt::Popup || widget->windowType()==Qt::ToolTip))
     if(auto *handle=widget->windowHandle())clearMacPopupBackground(handle);
   }
   if(auto *handle=qobject_cast<QWindow *>(object)) {
    if(handle->type()==Qt::Popup || handle->type()==Qt::ToolTip)clearMacPopupBackground(handle);
   }
#endif
   if(auto *window=qobject_cast<QQuickWindow *>(object)) {
    window->setColor(Qt::transparent);
#ifdef Q_OS_MACOS
    if(window->transientParent() && (window->type()==Qt::Popup || window->type()==Qt::ToolTip || window->type()==Qt::Tool)) {
     clearMacPopupBackground(window);
     QTimer::singleShot(0,window,[window]{clearMacPopupBackground(window);});
    }
#endif
   }

  }return false;
 }
};
#include "Application.h"
#include "PrismBridge.h"
#include "MacWindowMetrics.h"
#ifdef Q_OS_MACOS
void configureMacWindow(QQuickWindow *,MacWindowMetrics *);
#endif
// Own the frontend explicitly: QObject child creation order is not teardown order.
class FrontendSession final:public QObject {
public:
    explicit FrontendSession(Application *app):QObject(app),app(app){
        bridge=new PrismBridge(app);bridge->setParent(this);
        metrics=new MacWindowMetrics(this);
        engine=new QQmlApplicationEngine(this);
        engine->rootContext()->setContextProperty("prismBridge",bridge);
        engine->rootContext()->setContextProperty("macWindowMetrics",metrics);
        this->app->installEventFilter(this);
        QObject::connect(app,&QCoreApplication::aboutToQuit,this,[this]{shutdown();});
        QObject::connect(app,&Application::updateAllowedChanged,this,[this](bool allowed){
            if(allowed && closeRequested)this->app->quit();
        });
        QObject::connect(engine,&QQmlApplicationEngine::objectCreated,this,[this](QObject *object,const QUrl &){
            auto *window=qobject_cast<QQuickWindow *>(object);if(!window)return;
            mainWindow=window;window->setColor(Qt::transparent);
            if (this->app->property("projectGlassPendingSignIn").toBool()) {
                this->app->setProperty("projectGlassPendingSignIn", false);
                QMetaObject::invokeMethod(bridge, "signIn", Qt::QueuedConnection);
            }
#ifdef Q_OS_MACOS
            QPointer<MacWindowMetrics> safeMetrics=metrics;
            QTimer::singleShot(0,window,[window,safeMetrics]{if(safeMetrics)configureMacWindow(window,safeMetrics);});
#endif
        });
        QObject::connect(engine,&QQmlApplicationEngine::objectCreationFailed,this,[this]{this->app->exit(1);},Qt::QueuedConnection);
        engine->loadFromModule("ProjectGlass","Main");
    }
    ~FrontendSession()override{shutdown();}
    bool eventFilter(QObject *object,QEvent *event)override{
        if(!stopping && object==mainWindow && event->type()==QEvent::Close){
            QPointer<FrontendSession> self=this;
            // Check after QML has accepted/rejected closing the window.
            QTimer::singleShot(0,this,[self]{
                if(!self || self->stopping || (self->mainWindow && self->mainWindow->isVisible()))return;
                self->closeRequested=true;
                if(self->app->updatesAreAllowed())self->app->quit();
            });
        }
        return false;
    }
    void shutdown(){
        if(stopping)return;
        stopping=true;this->app->removeEventFilter(this);
        if(bridge)for(auto *timer:bridge->findChildren<QTimer *>())timer->stop();
        if(engine){
            for(auto *timer:engine->findChildren<QTimer *>())timer->stop();
            // Destroy QML windows while both context objects remain valid.
            delete engine;engine=nullptr;mainWindow=nullptr;
        }
        if(metrics){metrics->clearNativeCallbacks();delete metrics;metrics=nullptr;}
        this->app->setProperty("projectGlassAuthBridge", QVariant());
        delete bridge;bridge=nullptr;
    }
private:
    Application *app;
    PrismBridge *bridge=nullptr;
    MacWindowMetrics *metrics=nullptr;
    QQmlApplicationEngine *engine=nullptr;
    QPointer<QQuickWindow> mainWindow;
    bool stopping=false,closeRequested=false;
};

void startProjectGlass(Application *app){
    auto *wait=new QTimer(app);wait->setInterval(30);
    QObject::connect(wait,&QTimer::timeout,app,[app,wait]{
        if(app->status()==Application::Failed){app->exit(1);return;}
        if(app->status()!=Application::Initialized)return;
        wait->stop();wait->deleteLater();
        app->setStyleSheet(QString());
#ifdef Q_OS_MACOS
        if(auto *style=QStyleFactory::create("macos"))app->setStyle(style);
#endif
        app->installEventFilter(new PopupTransparency(app));
        new FrontendSession(app);
    });wait->start();
}
