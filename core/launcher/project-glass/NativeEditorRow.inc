@interface PGEditorAction : NSObject { @public QPointer<QQuickItem> item; }
- (void)toggle:(NSSwitch *)sender;
- (void)open:(id)sender;
- (void)remove:(id)sender;
@end
@implementation PGEditorAction
- (void)toggle:(NSSwitch *)sender {if(item)QMetaObject::invokeMethod(item.data(),"nativeToggle",Qt::QueuedConnection,Q_ARG(bool,sender.state==NSControlStateValueOn));}
- (void)open:(id)sender {Q_UNUSED(sender);if(item)QMetaObject::invokeMethod(item.data(),"nativeOpen",Qt::QueuedConnection);}
- (void)remove:(id)sender {Q_UNUSED(sender);if(item)QMetaObject::invokeMethod(item.data(),"nativeRemove",Qt::QueuedConnection);}
@end
@interface PGEditorRow : NSView
@property(nonatomic,weak) NSView *qtHost;
@property(nonatomic,strong) NSSwitch *toggle;
@property(nonatomic,strong) NSImageView *icon;
@property(nonatomic,strong) NSTextField *label;
@property(nonatomic,strong) NSButton *openButton;
@property(nonatomic,strong) NSButton *removeButton;
@property(nonatomic,strong) PGEditorAction *action;
- (void)updateItem:(QQuickItem *)item;
@end
@implementation PGEditorRow
- (BOOL)isFlipped{return YES;}
- (void)scrollWheel:(NSEvent *)event {[self.qtHost scrollWheel:event];}
- (instancetype)initWithFrame:(NSRect)rect {
 self=[super initWithFrame:rect];if(self){
  _action=[PGEditorAction new];_toggle=[[NSSwitch alloc] initWithFrame:NSZeroRect];_toggle.target=_action;_toggle.action=@selector(toggle:);
  _icon=[[NSImageView alloc] initWithFrame:NSZeroRect];_icon.imageScaling=NSImageScaleProportionallyUpOrDown;_icon.wantsLayer=YES;_icon.layer.cornerRadius=8;_icon.layer.masksToBounds=YES;
  _label=[NSTextField labelWithString:@""];_label.lineBreakMode=NSLineBreakByTruncatingTail;
  _openButton=[NSButton buttonWithTitle:@"Open" target:_action action:@selector(open:)];
  _removeButton=[NSButton buttonWithTitle:@"Remove" target:_action action:@selector(remove:)];
  for(NSButton *button in @[_openButton,_removeButton]){button.bezelStyle=NSBezelStyleRounded;}
  for(NSView *v in @[_toggle,_icon,_label,_openButton,_removeButton])[self addSubview:v];
 }return self;
}
- (void)updateItem:(QQuickItem *)item {
 self.action->item=item;auto v=item->property("assetData");auto row=v.canConvert<QJSValue>()?v.value<QJSValue>().toVariant().toMap():v.toMap();
 const auto bucket=item->property("assetBucket").toString();self.toggle.hidden=bucket=="worlds" || bucket=="screenshots";
 self.toggle.state=row.value("enabled",true).toBool()?NSControlStateValueOn:NSControlStateValueOff;
 [self.toggle sizeToFit];self.toggle.frame=NSMakeRect(4,(NSHeight(self.bounds)-NSHeight(self.toggle.frame))/2,NSWidth(self.toggle.frame),NSHeight(self.toggle.frame));
 const CGFloat x=self.toggle.hidden?4:NSMaxX(self.toggle.frame)+14,w=NSWidth(self.bounds);
 self.icon.frame=NSMakeRect(x,10,32,32);QString src=row.value("icon").toString();
 if(src.startsWith("data:image/png;base64,")){auto bytes=QByteArray::fromBase64(src.mid(22).toLatin1());self.icon.image=[[NSImage alloc] initWithData:[NSData dataWithBytes:bytes.constData() length:bytes.size()]];}else if(bucket=="screenshots")self.icon.image=[[NSImage alloc] initWithContentsOfFile:PGString(QUrl(row.value("source").toString()).toLocalFile())];else self.icon.image=[NSImage imageWithSystemSymbolName:@"puzzlepiece.extension" accessibilityDescription:nil];
 if(self.icon.image){NSBitmapImageRep *bitmap=[NSBitmapImageRep imageRepWithData:self.icon.image.TIFFRepresentation];double rr=0,gg=0,bb=0,weight=0;for(int y=0;y<bitmap.pixelsHigh;y+=std::max(1,(int)bitmap.pixelsHigh/16))for(int x=0;x<bitmap.pixelsWide;x+=std::max(1,(int)bitmap.pixelsWide/16)){NSColor *c=[[bitmap colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];double a=c.alphaComponent;rr+=c.redComponent*a;gg+=c.greenComponent*a;bb+=c.blueComponent*a;weight+=a;}if(weight>0)self.icon.layer.backgroundColor=[NSColor colorWithSRGBRed:rr/weight green:gg/weight blue:bb/weight alpha:0.45].CGColor;}
 if([self.toggle respondsToSelector:@selector(setContentTintColor:)])[self.toggle setValue:PGAccent() forKey:@"contentTintColor"];
 self.label.stringValue=PGString(row.value("name").toString()+"  "+row.value("version").toString());self.label.textColor=NSColor.labelColor;
 self.label.frame=NSMakeRect(x+42,17,std::max(0.0,w-x-238),20);
 self.openButton.frame=NSMakeRect(w-188,8,84,36);self.removeButton.frame=NSMakeRect(w-100,8,96,36);
}
@end

// Title, action and material share one native view above the scrolling rows.
@interface PGEditorHeaderAction : NSObject { @public QPointer<QQuickItem> item; }
- (void)activate:(id)sender;
- (void)logControl:(id)sender;
@end
@implementation PGEditorHeaderAction
- (void)logControl:(id)sender {
 if(!item)return;const NSInteger tag=[sender tag];
 if(tag==1 || tag==2)QMetaObject::invokeMethod(item.data(),tag==1?"nativeKeep":"nativeWrap",Qt::QueuedConnection,Q_ARG(bool,[(NSSwitch *)sender state]==NSControlStateValueOn));
 else QMetaObject::invokeMethod(item.data(),tag==3?"nativeCopy":"nativeRefresh",Qt::QueuedConnection);
}

- (void)activate:(id)sender {Q_UNUSED(sender);if(item)QMetaObject::invokeMethod(item.data(),"nativeAction",Qt::QueuedConnection);}
@end
@interface PGEditorHeader : PGPageContentView
@property(nonatomic,weak) NSView *qtHost;
@property(nonatomic,strong) NSView *glass;
@property(nonatomic,strong) NSTextField *title;
@property(nonatomic,strong) NSView *buttonGlass;
@property(nonatomic,strong) NSButton *button;
@property(nonatomic,strong) NSBox *divider;
@property(nonatomic,strong) NSMutableArray<NSView *> *logTools;
@property(nonatomic,strong) PGEditorHeaderAction *action;
- (void)updateItem:(QQuickItem *)item strength:(CGFloat)strength;
@end
@implementation PGEditorHeader
- (instancetype)initWithFrame:(NSRect)rect {
    self=[super initWithFrame:rect];
    if(self) {
        self.glass=PGPageGlass(NSZeroRect,0);[self addSubview:self.glass];
        NSView *content=[self.glass valueForKey:@"contentView"];
        self.title=[NSTextField labelWithString:@""];self.title.font=[NSFont boldSystemFontOfSize:20];[content addSubview:self.title];
        self.buttonGlass=PGPageGlass(NSZeroRect,16);[content addSubview:self.buttonGlass];
        self.action=[PGEditorHeaderAction new];
        self.button=[NSButton buttonWithTitle:@"" target:self.action action:@selector(activate:)];self.button.bordered=NO;
        [[self.buttonGlass valueForKey:@"contentView"] addSubview:self.button];
        self.logTools=[NSMutableArray array];
        for(NSInteger i=1;i<=4;i++) {
            NSControl *control=i<=2?(NSControl *)[[NSSwitch alloc] initWithFrame:NSZeroRect]:(NSControl *)[NSButton buttonWithTitle:i==3?@"Copy":@"Refresh" target:self.action action:@selector(logControl:)];
            control.tag=i;control.target=self.action;control.action=@selector(logControl:);[content addSubview:control];[self.logTools addObject:control];
            if(i<=2){NSTextField *label=[NSTextField labelWithString:i==1?@"Keep updating":@"Wrap lines"];label.tag=i+10;[content addSubview:label];[self.logTools addObject:label];}
        }
        self.divider=[[NSBox alloc] initWithFrame:NSZeroRect];self.divider.boxType=NSBoxSeparator;[self addSubview:self.divider];
    }
    return self;
}
- (void)updateItem:(QQuickItem *)item strength:(CGFloat)strength {
    self.action->item=item;const CGFloat w=NSWidth(self.bounds),h=NSHeight(self.bounds);
    self.glass.frame=self.bounds;[[self.glass valueForKey:@"contentView"] setFrame:self.bounds];PGApplyGlass(self.glass,strength);
    self.title.stringValue=PGString(item->property("headerTitle").toString());self.title.textColor=NSColor.labelColor;
    NSString *action=PGString(item->property("headerActionText").toString());self.button.title=action;self.buttonGlass.hidden=action.length==0;
    const CGFloat bw=std::max(88.0,[action sizeWithAttributes:@{NSFontAttributeName:self.button.font}].width+32);
    self.buttonGlass.frame=NSMakeRect(w-bw-16,16,bw,std::max(0.0,h-26));
    NSView *buttonContent=[self.buttonGlass valueForKey:@"contentView"];buttonContent.frame=self.buttonGlass.bounds;self.button.frame=NSInsetRect(buttonContent.bounds,8,4);PGApplyGlass(self.buttonGlass,strength);
    self.title.frame=NSMakeRect(16,NSMidY(self.bounds)-12,std::max(0.0,w-32-(action.length?bw+12:0)),26);
    const BOOL logs=item->property("headerLog").toBool();
    for(NSView *tool in self.logTools)tool.hidden=!logs;
    if(logs) {
        // Measure the real switch and label widths before placing adjacent groups.
        const BOOL narrow=w<760;const CGFloat innerGap=10,groupGap=18,buttonGap=8,buttonWidth=66;
        CGFloat widths[2]={0,0},switchWidths[2]={0,0},labelWidths[2]={0,0};
        for(NSView *tool in self.logTools) {
            if(tool.tag>=11){NSInteger i=tool.tag-11;NSTextField *label=(NSTextField *)tool;
                label.stringValue=i==0?(narrow?@"Keep":@"Keep updating"):(narrow?@"Wrap":@"Wrap lines");
                label.font=[NSFont systemFontOfSize:12];[label sizeToFit];labelWidths[i]=std::ceil(NSWidth(label.frame));
            }else if(tool.tag<=2){NSSwitch *toggle=(NSSwitch *)tool;toggle.controlSize=NSControlSizeSmall;[toggle sizeToFit];switchWidths[tool.tag-1]=NSWidth(toggle.frame);}
        }
        for(int i=0;i<2;i++)widths[i]=labelWidths[i]+innerGap+switchWidths[i];
        const CGFloat total=widths[0]+widths[1]+groupGap*2+buttonWidth*2+buttonGap;
        const CGFloat x0=std::max(16.0,w-total-16),second=x0+widths[0]+groupGap,buttons=second+widths[1]+groupGap;
        for(NSView *tool in self.logTools){NSInteger tag=tool.tag;
            if(tag>=11){NSInteger i=tag-11;tool.frame=NSMakeRect(i==0?x0:second,NSMidY(self.bounds)-NSHeight(tool.frame)/2,labelWidths[i],NSHeight(tool.frame));}
            else if(tag<=2){NSInteger i=tag-1;NSSwitch *toggle=(NSSwitch *)tool;toggle.frame=NSMakeRect((i==0?x0:second)+labelWidths[i]+innerGap,NSMidY(self.bounds)-NSHeight(toggle.frame)/2,switchWidths[i],NSHeight(toggle.frame));toggle.state=item->property(tag==1?"keepUpdating":"wrapLines").toBool()?NSControlStateValueOn:NSControlStateValueOff;}
            else tool.frame=NSMakeRect(buttons+(tag-3)*(buttonWidth+buttonGap),NSMidY(self.bounds)-16,buttonWidth,32);
        }
        self.title.frame=NSMakeRect(16,NSMidY(self.bounds)-12,std::max(0.0,x0-28),26);self.title.lineBreakMode=NSLineBreakByTruncatingTail;
    }
    self.divider.frame=NSMakeRect(0,h-1,w,1);
}
- (void)scrollWheel:(NSEvent *)event {[self.qtHost scrollWheel:event];}
@end
