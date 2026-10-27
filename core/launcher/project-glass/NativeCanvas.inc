// One AppKit container per card: material, artwork and labels share transforms,
// clipping and stacking. The transparent Qt item retains all pointer handling.
@interface PGCanvasCardHost : PGPageContentView
@property(nonatomic,strong) NSView *material;
@property(nonatomic,strong) NSImageView *art;
@property(nonatomic,strong) NSVisualEffectView *frost;
@property(nonatomic,strong) CAGradientLayer *shade;
@property(nonatomic,strong) CAGradientLayer *frostMask;
@property(nonatomic,strong) NSTextField *nameLabel;
@property(nonatomic,strong) NSTextField *versionLabel;
@property(nonatomic,strong) NSTextField *statsLabel;
@property(nonatomic,strong) NSImageView *downloadIcon;
@property(nonatomic,strong) NSView *resizeMark;
@property(nonatomic,copy) NSString *imageKey;
@end
@implementation PGCanvasCardHost
- (instancetype)initWithFrame:(NSRect)frame {
    self=[super initWithFrame:frame];if(self) {
        self.wantsLayer=YES;self.layer.masksToBounds=YES;
        _art=[[NSImageView alloc] initWithFrame:NSZeroRect];_art.imageScaling=NSImageScaleAxesIndependently;[self addSubview:_art];
        _material=PGPageGlass(NSZeroRect,26);[self addSubview:_material];
        _frost=[[NSVisualEffectView alloc] initWithFrame:NSZeroRect];_frost.material=NSVisualEffectMaterialHUDWindow;
        _frost.blendingMode=NSVisualEffectBlendingModeWithinWindow;_frost.state=NSVisualEffectStateActive;_frost.wantsLayer=YES;
        _frostMask=[CAGradientLayer layer];_frostMask.colors=@[(id)NSColor.clearColor.CGColor,(id)NSColor.blackColor.CGColor];
        _frostMask.locations=@[@0,@0.65];
        _frostMask.startPoint=CGPointMake(0.5,1);_frostMask.endPoint=CGPointMake(0.5,0);_frost.layer.mask=_frostMask;[self addSubview:_frost];
        _shade=[CAGradientLayer layer];_shade.colors=@[(id)NSColor.clearColor.CGColor,(id)[NSColor colorWithWhite:0 alpha:0.70].CGColor,(id)[NSColor colorWithWhite:0 alpha:0.85].CGColor];
        _shade.locations=@[@0,@0.45,@1];_shade.startPoint=CGPointMake(0.5,1);_shade.endPoint=CGPointMake(0.5,0);
        // AppKit's unflipped native effect view uses a bottom-origin layer.
        [_frost.layer addSublayer:_shade];
        _nameLabel=[NSTextField labelWithString:@""];_versionLabel=[NSTextField labelWithString:@""];_statsLabel=[NSTextField labelWithString:@""];
        for(NSTextField *label in @[_nameLabel,_versionLabel,_statsLabel]){label.lineBreakMode=NSLineBreakByTruncatingTail;[self addSubview:label];}
        _statsLabel.alignment=NSTextAlignmentRight;
        _downloadIcon=[[NSImageView alloc] initWithFrame:NSZeroRect];_downloadIcon.imageScaling=NSImageScaleProportionallyUpOrDown;_downloadIcon.image=[NSImage imageWithSystemSymbolName:@"arrow.down" accessibilityDescription:nil];[self addSubview:_downloadIcon];
        _resizeMark=[[NSView alloc] initWithFrame:NSZeroRect];_resizeMark.wantsLayer=YES;
        CAShapeLayer *grip=[CAShapeLayer layer];CGMutablePathRef gripPath=CGPathCreateMutable();
        CGPathMoveToPoint(gripPath,nullptr,2,12);CGPathAddLineToPoint(gripPath,nullptr,12,2);
        CGPathMoveToPoint(gripPath,nullptr,7,12);CGPathAddLineToPoint(gripPath,nullptr,12,7);
        grip.path=gripPath;CGPathRelease(gripPath);grip.strokeColor=[NSColor colorWithWhite:1 alpha:0.7].CGColor;grip.lineWidth=1;[_resizeMark.layer addSublayer:grip];[self addSubview:_resizeMark];
    }return self;
}
- (NSView *)hitTest:(NSPoint)point {Q_UNUSED(point);return nil;}
@end

@interface PGCanvasCards : NSObject
@property(nonatomic,weak) NSView *qtHost;
@property(nonatomic,weak) NSView *coordinates;
@property(nonatomic,weak) NSView *sidebarGlass;
@property(nonatomic,weak) PGSidebarBackdrop *backdrop;
@property(nonatomic,strong) NSImageView *glowView;
@property(nonatomic) CGFloat contentInset;
@property(nonatomic,strong) NSMutableDictionary<NSString *,PGCanvasCardHost *> *cards;
@property(nonatomic,strong) NSCache<NSString *,NSImage *> *images;
- (void)update:(const QVariantList &)rows strength:(CGFloat)strength;
- (void)compositeScene:(QImage &)image origin:(QPointF)origin size:(QSizeF)size;
@end
@implementation PGCanvasCards
{ QVariantList _lastRows; QHash<QString,QImage> _qtImages; QHash<QString,QColor> _glowColors; QStringList _order; CGFloat _lastStrength; BOOL _hasRows; CGFloat _lastInset; NSRect _lastFrame; NSString *_lastWallpaper; NSString *_lastPlacement; NSColor *_lastBackground; }
- (void)compositeScene:(QImage &)image origin:(QPointF)origin size:(QSizeF)size {
    if(size.width()<=0 || size.height()<=0)return;
    QPainter painter(&image);painter.setRenderHint(QPainter::SmoothPixmapTransform);
    const qreal scale=image.width()/size.width(),scaleY=image.height()/size.height();
    for(const QVariant &value:_lastRows){auto r=value.toMap();if(!r.value("installed").toBool())continue;
        QString source=r.value("image").toString();
        if(!_qtImages.contains(source)){QString path=source;QUrl url(path);if(url.isLocalFile())path=url.toLocalFile();else if(path.startsWith("qrc:"))path=path.mid(3);if(_qtImages.size()>64)_qtImages.clear();_qtImages.insert(source,(path.isEmpty()?QImage():QImage(path)));}
        const QImage art=_qtImages.value(source);if(art.isNull())continue;
        QRectF rect((r.value("x").toDouble()-origin.x())*scale,(r.value("y").toDouble()-origin.y())*scaleY,r.value("width").toDouble()*scale,r.value("height").toDouble()*scaleY);
        painter.save();QPainterPath rounded;rounded.addRoundedRect(rect,r.value("radius").toDouble()*scale,r.value("radius").toDouble()*scale);painter.setClipPath(rounded);
        const qreal factor=std::max(rect.width()/art.width(),rect.height()/art.height());QSizeF covered(art.width()*factor,art.height()*factor);painter.drawImage(QRectF(rect.center()-QPointF(covered.width()/2,covered.height()/2),covered),art);painter.restore();
    }
}
- (NSImage *)imageForSource:(NSString *)source {
    NSImage *cached=[self.images objectForKey:source];if(cached)return cached;
    QString path=QString::fromUtf8(source.UTF8String);QUrl url(path);
    if(url.isLocalFile())path=url.toLocalFile();else if(path.startsWith("qrc:"))path=path.mid(3);
    QImage image=path.isEmpty()?QImage():QImage(path);if(image.isNull())return nil;
    QByteArray png;QBuffer buffer(&png);buffer.open(QIODevice::WriteOnly);image.save(&buffer,"PNG");
    NSImage *native=[[NSImage alloc] initWithData:[NSData dataWithBytes:png.constData() length:png.size()]];
    if(native)[self.images setObject:native forKey:source];return native;
}
- (void)update:(const QVariantList &)rows strength:(CGFloat)strength {
    const NSRect frame=[self.qtHost convertRect:self.qtHost.bounds toView:self.qtHost.superview];
    NSString *wallpaperKey=[NSString stringWithFormat:@"%p",self.backdrop.wallpaper];
    if(_hasRows && _lastRows==rows && std::abs(_lastStrength-strength)<0.0001 && _lastInset==self.contentInset && NSEqualRects(_lastFrame,frame) && [_lastWallpaper isEqualToString:wallpaperKey] && [_lastPlacement isEqualToString:self.backdrop.placement?:@""] && [_lastBackground isEqual:self.backdrop.backgroundColor])return;
    _hasRows=YES;_lastStrength=strength;_lastRows=rows;_lastInset=self.contentInset;_lastFrame=frame;
    _lastWallpaper=wallpaperKey;_lastPlacement=self.backdrop.placement?:@"";_lastBackground=self.backdrop.backgroundColor;
    QStringList order;for(const QVariant &value:rows)order.append(value.toMap().value("key").toString());
    const BOOL reorder=order!=_order;_order=order;
    if(!self.cards){self.cards=[NSMutableDictionary dictionary];self.images=[[NSCache alloc] init];self.images.countLimit=64;}
    [CATransaction begin];[CATransaction setDisableActions:YES];[NSAnimationContext beginGrouping];NSAnimationContext.currentContext.duration=0;NSAnimationContext.currentContext.allowsImplicitAnimation=NO;
    // Explicit top-origin color field. No reflected view hierarchy.
    const CGFloat inset=std::max(0.0,std::min(self.contentInset,NSWidth(self.coordinates.bounds)));
    if(!self.glowView){self.glowView=[[NSImageView alloc] initWithFrame:NSZeroRect];self.glowView.imageScaling=NSImageScaleAxesIndependently;
        [self.qtHost.superview addSubview:self.glowView positioned:NSWindowBelow relativeTo:self.sidebarGlass?:self.qtHost];}
    self.glowView.frame=[self.coordinates convertRect:NSMakeRect(0,0,inset,NSHeight(self.coordinates.bounds)) toView:self.qtHost.superview];
    self.glowView.hidden=rows.isEmpty() || inset<1;
    if(!self.glowView.hidden) {
        const int gw=64,gh=std::max(1,(int)std::ceil(NSHeight(self.coordinates.bounds)/8));
        QImage glow(gw,gh,QImage::Format_ARGB32_Premultiplied);glow.fill(Qt::transparent);
        struct Light { double y,sy,weight; QColor color; };QList<Light> lights;
        for(const QVariant &value:rows){const auto row=value.toMap();if(!row.value("installed").toBool() || row.value("clipH").toDouble()<=0)continue;
            QString path=row.value("image").toString();QUrl url(path);if(url.isLocalFile())path=url.toLocalFile();else if(path.startsWith("qrc:"))path=path.mid(3);
            if(!_glowColors.contains(path)){const QImage art=path.isEmpty()?QImage():QImage(path);if(art.isNull())continue;if(_glowColors.size()>64)_glowColors.clear();_glowColors.insert(path,art.scaled(1,1,Qt::IgnoreAspectRatio,Qt::SmoothTransformation).pixelColor(0,0));}
            const QColor color=_glowColors.value(path);
            const double distance=std::max(0.0,row.value("x").toDouble()-inset);
            const double weight=std::exp(-distance/150.0)*0.30;
            if(weight<0.003)continue;
            lights.append({row.value("y").toDouble()+row.value("height").toDouble()*0.5,std::max(65.0,row.value("height").toDouble()*0.42),weight,color});
        }
        for(int py=0;py<gh;py++)for(int px=0;px<gw;px++){
            const double y=(py+0.5)*NSHeight(self.coordinates.bounds)/gh,x=(px+0.5)*inset/gw;
            double red=0,green=0,blue=0,total=0;
            for(const auto &light:lights){const double dy=(y-light.y)/light.sy,dx=(inset-x)/190.0;
                const double w=light.weight*std::exp(-0.5*(dy*dy+dx*dx));total+=w;red+=w*light.color.redF();green+=w*light.color.greenF();blue+=w*light.color.blueF();}
            if(total>0){const double alpha=std::min(0.34,total);glow.setPixel(px,py,qRgba(qRound(255*red/total*alpha),qRound(255*green/total*alpha),qRound(255*blue/total*alpha),qRound(255*alpha)));}
        }
        QByteArray png;QBuffer buffer(&png);buffer.open(QIODevice::WriteOnly);glow.save(&buffer,"PNG");
        self.glowView.image=[[NSImage alloc] initWithData:[NSData dataWithBytes:png.constData() length:png.size()]];
    }
    NSView *cardParent=self.qtHost.superview;
    NSMutableSet<NSString *> *used=[NSMutableSet set];NSView *previous=nil;
    for(const QVariant &value:rows) {
        const QVariantMap r=value.toMap();NSString *key=PGString(r.value("key").toString());[used addObject:key];
        PGCanvasCardHost *host=self.cards[key];if(!host){host=[[PGCanvasCardHost alloc] initWithFrame:NSZeroRect];self.cards[key]=host;}
        if(reorder || host.superview!=cardParent) {
            [cardParent addSubview:host positioned:previous?NSWindowAbove:NSWindowBelow relativeTo:previous?:(self.sidebarGlass?:self.qtHost)];
        }previous=host;
        const CGFloat w=r.value("width").toDouble(),h=r.value("height").toDouble(),scale=r.value("scale").toDouble();
        const BOOL installed=r.value("installed").toBool(),dark=r.value("dark").toBool();
        const NSRect rect=NSMakeRect(r.value("x").toDouble(),r.value("y").toDouble(),w,h);
        host.frame=[self.coordinates convertRect:rect toView:cardParent];
        host.appearance=[NSAppearance appearanceNamed:dark?NSAppearanceNameDarkAqua:NSAppearanceNameAqua];
        const CGFloat cardRadius=std::max(0.0,std::min(r.value("radius").toDouble(),std::min(w,h)*0.5));
        host.layer.cornerCurve=kCACornerCurveContinuous;
        [host.material setValue:@(cardRadius) forKey:@"cornerRadius"];
        host.material.wantsLayer=YES;host.material.layer.cornerRadius=cardRadius;
        host.material.layer.cornerCurve=kCACornerCurveContinuous;host.material.layer.masksToBounds=YES;
        host.layer.cornerRadius=cardRadius;host.layer.borderWidth=installed&&r.value("selected").toBool()?2*scale:0;host.layer.borderColor=PGAccent().CGColor;
        // Sidebar glass occludes the complete card; it is not a clip boundary.
        const CGFloat clipLeft=r.value("clipX").toDouble();
        const NSRect allowed=NSMakeRect(clipLeft,r.value("clipY").toDouble(),std::max(0.0,r.value("clipX").toDouble()+r.value("clipW").toDouble()-clipLeft),r.value("clipH").toDouble());
        const NSRect inParent=[self.coordinates convertRect:allowed toView:cardParent];
        const NSRect local=[host convertRect:inParent fromView:cardParent];
        CAShapeLayer *mask=[CAShapeLayer layer];mask.frame=host.bounds;CGPathRef path=CGPathCreateWithRect(local,nullptr);mask.path=path;CGPathRelease(path);host.layer.mask=mask;
        host.hidden=w<=0||h<=0||NSIsEmptyRect(allowed);if(host.hidden)continue;
        host.art.hidden=!installed;host.material.hidden=installed;host.frost.hidden=!installed;host.downloadIcon.hidden=installed;
        if(installed){NSString *source=PGString(r.value("image").toString());if(![host.imageKey isEqualToString:source]){host.art.image=[self imageForSource:source];host.imageKey=source;}
            const NSSize natural=host.art.image.size;const CGFloat factor=natural.width>0&&natural.height>0?std::max(w/natural.width,h/natural.height):1;
            const NSSize size=NSMakeSize(natural.width*factor,natural.height*factor);host.art.frame=NSMakeRect((w-size.width)/2,(h-size.height)/2,size.width,size.height);
            host.layer.backgroundColor=[NSColor colorWithWhite:0.12 alpha:1].CGColor;
            if(r.value("defaultArtwork").toBool()) {
                host.material.hidden=NO;host.material.frame=host.bounds;
                PGApplyGlass(host.material,strength,false,r.value("selected").toBool());
                QString path=r.value("image").toString();if(path.startsWith("qrc:"))path=path.mid(3);
                QImage art=path.isEmpty()?QImage():QImage(path);QColor tint(70,110,65);
                if(!art.isNull()){double rr=0,gg=0,bb=0,weight=0;auto small=art.scaled(24,24,Qt::KeepAspectRatio,Qt::SmoothTransformation);for(int y=0;y<small.height();y++)for(int x=0;x<small.width();x++){auto c=small.pixelColor(x,y);double a=c.alphaF();rr+=c.redF()*a;gg+=c.greenF()*a;bb+=c.blueF()*a;weight+=a;}if(weight>0)tint=QColor::fromRgbF(rr/weight,gg/weight,bb/weight);}
                [host.material setValue:[NSColor colorWithRed:tint.redF() green:tint.greenF() blue:tint.blueF() alpha:0.5] forKey:@"tintColor"];
                [host addSubview:host.art positioned:NSWindowAbove relativeTo:host.material];
                const CGFloat icon=std::min(w,h)*0.55;host.art.frame=NSMakeRect((w-icon)/2,12*scale,icon,icon);host.art.imageScaling=NSImageScaleProportionallyUpOrDown;
            } else host.art.imageScaling=NSImageScaleAxesIndependently;

        }else{host.material.frame=host.bounds;[host.material setValue:@(host.layer.cornerRadius) forKey:@"cornerRadius"];PGApplyGlass(host.material,strength,false,r.value("selected").toBool());host.layer.backgroundColor=NSColor.clearColor.CGColor;}
        const CGFloat captionHeight=46*scale,bottom=18*scale,footerHeight=captionHeight+bottom+44*scale;
        host.frost.frame=NSMakeRect(0,std::max(0.0,h-footerHeight),w,std::min(h,footerHeight));host.frostMask.frame=host.frost.bounds;host.shade.frame=host.frost.bounds;
        const CGFloat left=20*scale,right=16*scale,statsWidth=100*scale;
        const CGFloat labelWidth=std::max(10.0,w-left-right-(installed?statsWidth+12*scale:0));
        host.nameLabel.frame=NSMakeRect(left,h-bottom-captionHeight,labelWidth,28*scale);host.versionLabel.frame=NSMakeRect(left,h-bottom-18*scale,labelWidth,18*scale);
        host.nameLabel.font=[NSFont systemFontOfSize:(r.value("featured").toBool()?22:18)*scale weight:NSFontWeightBold];host.versionLabel.font=[NSFont systemFontOfSize:12*scale];
        host.nameLabel.stringValue=PGString(r.value("label").toString());host.versionLabel.stringValue=PGString(r.value("version").toString());
        host.nameLabel.textColor=installed?NSColor.whiteColor:NSColor.labelColor;host.versionLabel.textColor=installed?[NSColor colorWithWhite:0.9 alpha:0.95]:NSColor.secondaryLabelColor;
        host.statsLabel.hidden=!installed;host.statsLabel.frame=NSMakeRect(w-right-statsWidth,h-bottom-18*scale,statsWidth,18*scale);host.statsLabel.font=[NSFont systemFontOfSize:10*scale];host.statsLabel.textColor=[NSColor colorWithWhite:0.9 alpha:0.95];host.statsLabel.stringValue=PGString(r.value("stats").toString());
        const CGFloat downloadScale=std::min(w/280.0,h/180.0);host.downloadIcon.frame=NSMakeRect(20*downloadScale,16*downloadScale,28*downloadScale,28*downloadScale);host.downloadIcon.symbolConfiguration=[NSImageSymbolConfiguration configurationWithPointSize:28*downloadScale weight:NSFontWeightRegular];host.downloadIcon.contentTintColor=PGAccent();
        host.resizeMark.hidden=!r.value("editingSize").toBool();host.resizeMark.frame=NSMakeRect(w-28*scale,h-28*scale,14*scale,14*scale);host.resizeMark.layer.cornerRadius=4*scale;host.resizeMark.layer.backgroundColor=[NSColor colorWithWhite:0 alpha:0.28].CGColor;
    }
    for(NSString *key in [self.cards.allKeys copy])if(![used containsObject:key]){[self.cards[key] removeFromSuperview];[self.cards removeObjectForKey:key];}
    [NSAnimationContext endGrouping];[CATransaction commit];
}
@end
