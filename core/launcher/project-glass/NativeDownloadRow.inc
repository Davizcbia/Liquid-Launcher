// Keep every visible part of a scrolling row in one AppKit subtree.
// QML retains the hit regions and catalogue model, but paints no duplicate row.
@interface PGDownloadRow : NSView
@property(nonatomic,strong) NSView *rowGlass;
@property(nonatomic,strong) NSTextField *titleLabel;
@property(nonatomic,strong) NSTextField *detailLabel;
@property(nonatomic,strong) NSTextField *badgeLabel;
@property(nonatomic,strong) NSImageView *icon;
@property(nonatomic,strong) NSView *downloadGlass;
@property(nonatomic,strong) NSTextField *downloadLabel;
@property(nonatomic,copy) NSString *iconSource;
@property(nonatomic,strong) NSURLSessionDataTask *iconTask;
- (void)updateItem:(QQuickItem *)item strength:(CGFloat)strength;
@end
@implementation PGDownloadRow
- (BOOL)isFlipped { return YES; }
- (instancetype)initWithFrame:(NSRect)frame {
    self=[super initWithFrame:frame];
    if(self) {
        _rowGlass=PGPageGlass(self.bounds,24);
        _rowGlass.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
        [self addSubview:_rowGlass];
        _titleLabel=[NSTextField labelWithString:@""];
        _titleLabel.font=[NSFont systemFontOfSize:18 weight:NSFontWeightBold];
        _titleLabel.lineBreakMode=NSLineBreakByTruncatingTail;
        _detailLabel=[NSTextField wrappingLabelWithString:@""];
        _detailLabel.font=[NSFont systemFontOfSize:13];
        _detailLabel.maximumNumberOfLines=2;
        _detailLabel.lineBreakMode=NSLineBreakByTruncatingTail;
        _icon=[[NSImageView alloc] initWithFrame:NSZeroRect];
        _icon.imageScaling=NSImageScaleProportionallyUpOrDown;
        _icon.wantsLayer=YES;_icon.layer.masksToBounds=YES;
        _badgeLabel=[NSTextField labelWithString:@""];_badgeLabel.alignment=NSTextAlignmentCenter;
        _downloadGlass=PGPageGlass(NSZeroRect,18);
        _downloadLabel=[NSTextField labelWithString:@"↓  Download"];
        _downloadLabel.font=[NSFont systemFontOfSize:13 weight:NSFontWeightBold];
        _downloadLabel.alignment=NSTextAlignmentCenter;
        [[_downloadGlass valueForKey:@"contentView"] addSubview:_downloadLabel];
        [self addSubview:_icon];[self addSubview:_badgeLabel];
        [self addSubview:_titleLabel];[self addSubview:_detailLabel];[self addSubview:_downloadGlass];
    }
    return self;
}
- (void)setSource:(NSString *)source {
    if([self.iconSource isEqualToString:source])return;
    [self.iconTask cancel];self.iconTask=nil;self.iconSource=source;self.icon.image=nil;
    self.badgeLabel.hidden=NO;
    if([source hasPrefix:@"https://"]) {
        __weak PGDownloadRow *weakSelf=self;
        self.iconTask=[[NSURLSession sharedSession] dataTaskWithURL:[NSURL URLWithString:source]
            completionHandler:^(NSData *data,NSURLResponse *response,NSError *error) {
                if(error || !data || ![response isKindOfClass:NSHTTPURLResponse.class] || ((NSHTTPURLResponse *)response).statusCode!=200)return;
                NSImage *image=[[NSImage alloc] initWithData:data];
                dispatch_async(dispatch_get_main_queue(), ^{
                    PGDownloadRow *row=weakSelf;
                    if(row && [row.iconSource isEqualToString:source]) {
                        row.icon.image=image;row.badgeLabel.hidden=image!=nil;
                    }
                });
            }];
        [self.iconTask resume];
    } else {
        QUrl url(QString::fromUtf8(source.UTF8String));
        QString path=url.scheme()==QStringLiteral("qrc")?QStringLiteral(":")+url.path():url.toLocalFile();
        QImage image=path.isEmpty()?QImage():QImage(path);QByteArray png;QBuffer buffer(&png);buffer.open(QIODevice::WriteOnly);image.save(&buffer,"PNG");
        self.icon.image=[[NSImage alloc] initWithData:[NSData dataWithBytes:png.constData() length:png.size()]];
        self.badgeLabel.hidden=self.icon.image!=nil;
    }
}
- (void)updateItem:(QQuickItem *)item strength:(CGFloat)strength {
    self.rowGlass.frame=self.bounds;
    [self.rowGlass setValue:@(item->property("radius").toDouble()) forKey:@"cornerRadius"];
    PGApplyGlass(self.rowGlass,strength,false,item->property("selectedGlass").toBool());
    NSView *rowContent=[self.rowGlass valueForKey:@"contentView"];
    rowContent.layer.backgroundColor=NSColor.clearColor.CGColor;
    const QVariant data=item->property("nativeRow");
    const QVariantMap row=data.canConvert<QJSValue>()?data.value<QJSValue>().toVariant().toMap():data.toMap();
    self.titleLabel.stringValue=PGString(row.value("name").toString());
    self.detailLabel.stringValue=PGString(row.value("detail").toString());
    self.badgeLabel.stringValue=PGString(row.value("badge").toString());
    self.titleLabel.textColor=NSColor.labelColor;self.detailLabel.textColor=NSColor.secondaryLabelColor;
    self.badgeLabel.textColor=PGAccent();self.downloadLabel.textColor=NSColor.labelColor;
    const BOOL release=item->property("nativeReleaseRow").toBool();
    if(!release)[self setSource:PGString(item->property("nativeIconSource").toUrl().toString())];
    else {[self.iconTask cancel];self.iconTask=nil;self.iconSource=nil;}
    self.icon.hidden=release;self.badgeLabel.hidden=release || self.icon.image!=nil;
    const CGFloat w=NSWidth(self.bounds),h=NSHeight(self.bounds),iconSize=h-32;
    const BOOL narrow=!release && w<650;
    self.icon.frame=NSMakeRect(16,16,iconSize,iconSize);
    self.icon.layer.cornerRadius=std::max(0.0,item->property("radius").toDouble()-16);
    self.icon.layer.backgroundColor=[PGAccent() colorWithAlphaComponent:0.16].CGColor;
    self.badgeLabel.frame=NSMakeRect(16,16+(iconSize-18)/2,iconSize,18);
    const CGFloat x=release?16:32+iconSize,textWidth=std::max(0.0,w-x-16-(narrow?0:128));
    self.titleLabel.font=[NSFont systemFontOfSize:release?14:18 weight:release?NSFontWeightRegular:NSFontWeightBold];
    self.titleLabel.frame=NSMakeRect(x,release?16:narrow?16:30,textWidth,23);
    self.detailLabel.frame=NSMakeRect(x,release?44:narrow?47:61,textWidth,release?22:36);
    self.downloadGlass.frame=NSMakeRect(w-128,narrow?h-52:(h-36)/2,112,36);
    const QVariant enabled=item->property("downloadEnabled");
    self.downloadGlass.alphaValue=!enabled.isValid() || enabled.toBool()?1:0.45;
    NSView *content=[self.downloadGlass valueForKey:@"contentView"];content.frame=NSMakeRect(0,0,112,36);
    PGApplyGlass(self.downloadGlass,strength,false,true);
    content.layer.backgroundColor=[PGAccent() colorWithAlphaComponent:0.26].CGColor;
    self.downloadLabel.frame=NSMakeRect(0,9,112,18);
}
- (void)dealloc { [_iconTask cancel]; }
@end
