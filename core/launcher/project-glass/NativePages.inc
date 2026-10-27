// Native popup geometry and material are shared by every page selector.
@interface PGSelectorCell : NSPopUpButtonCell
@end
@implementation PGSelectorCell
- (NSRect)titleRectForBounds:(NSRect)bounds {
    NSRect rect=[super titleRectForBounds:bounds];
    rect.origin.x=NSMinX(bounds)+8;
    rect.size.width=std::max(0.0,NSWidth(bounds)-44);
    return rect;
}
@end
@interface PGAccentMenuRow : NSView
@property(nonatomic,weak) NSPopUpButton *selector;
@property(nonatomic,weak) NSMenuItem *item;
@property(nonatomic) BOOL hovered;
@property(nonatomic,strong) NSTrackingArea *tracking;
@end
@implementation PGAccentMenuRow
- (void)updateTrackingAreas {
    [super updateTrackingAreas];if(self.tracking)[self removeTrackingArea:self.tracking];
    self.tracking=[[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingMouseEnteredAndExited|NSTrackingActiveAlways owner:self userInfo:nil];[self addTrackingArea:self.tracking];
}
- (void)mouseEntered:(NSEvent *)event {Q_UNUSED(event);self.hovered=YES;[self setNeedsDisplay:YES];}
- (void)mouseExited:(NSEvent *)event {Q_UNUSED(event);self.hovered=NO;[self setNeedsDisplay:YES];}
- (void)drawRect:(NSRect)rect {
    Q_UNUSED(rect);const BOOL active=self.hovered || self.item.highlighted;
    if(active){[[PGAccent() colorWithAlphaComponent:0.75] setFill];[[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(self.bounds,3,1) xRadius:9 yRadius:9] fill];}
    NSString *text=[NSString stringWithFormat:@"%@%@",self.selector.selectedItem==self.item?@"✓  ":@"    ",self.item.title];
    [text drawAtPoint:NSMakePoint(10,8) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:13],NSForegroundColorAttributeName:NSColor.labelColor}];
}
- (void)mouseUp:(NSEvent *)event {
    Q_UNUSED(event);if(!self.item.enabled)return;[self.selector selectItem:self.item];[self.item.menu cancelTracking];[self.selector sendAction:self.selector.action to:self.selector.target];
}
@end
@interface PGGlassPopUpButton : NSPopUpButton
@property(nonatomic,strong) NSView *indicatorGlass;
@end
@implementation PGGlassPopUpButton
- (void)mouseDown:(NSEvent *)event {
    CGFloat width=NSWidth(self.bounds);
    for(NSMenuItem *item in self.itemArray)width=std::max(width,[item.title sizeWithAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:13]}].width+52);
    for(NSMenuItem *item in self.itemArray){PGAccentMenuRow *row=[[PGAccentMenuRow alloc] initWithFrame:NSMakeRect(0,0,width,32)];row.selector=self;row.item=item;item.view=row;}
    [super mouseDown:event];
}
- (instancetype)initWithFrame:(NSRect)frame pullsDown:(BOOL)pullsDown {
    self=[super initWithFrame:frame pullsDown:pullsDown];
    if(self) {
        PGSelectorCell *cell=[[PGSelectorCell alloc] initTextCell:@"" pullsDown:pullsDown];
        cell.arrowPosition=NSPopUpNoArrow;cell.alignment=NSTextAlignmentLeft;
        self.cell=cell;
        self.controlSize=NSControlSizeRegular;
        self.font=[NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSControlSizeRegular]];
        self.indicatorGlass=[[NSClassFromString(@"NSGlassEffectView") alloc] initWithFrame:NSMakeRect(0,0,24,24)];
        [self.indicatorGlass setValue:@12 forKey:@"cornerRadius"];
        [self.indicatorGlass setValue:@YES forKey:@"effectIsInteractive"];
        NSImageView *symbol=[[NSImageView alloc] initWithFrame:NSMakeRect(5,5,14,14)];
        symbol.image=[NSImage imageWithSystemSymbolName:@"chevron.up.chevron.down" accessibilityDescription:@"Choose an option"];
        symbol.contentTintColor=NSColor.secondaryLabelColor;
        // NSGlassEffectView does not create a contentView automatically.
        // Retain an explicit, sized content host before attaching the symbol.
        NSView *content=[[NSView alloc] initWithFrame:NSMakeRect(0,0,24,24)];
        [self.indicatorGlass setValue:content forKey:@"contentView"];
        NSImage *configured=[symbol.image imageWithSymbolConfiguration:
            [NSImageSymbolConfiguration configurationWithPointSize:[NSFont systemFontSizeForControlSize:NSControlSizeSmall] weight:NSFontWeightSemibold]];
        if(configured)symbol.image=configured;
        if(!symbol.image) { cell.arrowPosition=NSPopUpArrowAtBottom;self.indicatorGlass.hidden=YES; }
        symbol.imageScaling=NSImageScaleProportionallyDown;
        [content addSubview:symbol];[self addSubview:self.indicatorGlass];
    }
    return self;
}
- (void)layout {
    [super layout];
    self.indicatorGlass.frame=NSMakeRect(NSWidth(self.bounds)-28,(NSHeight(self.bounds)-24)/2,24,24);
}
- (NSView *)hitTest:(NSPoint)point {
    NSPoint local=[self convertPoint:point fromView:self.superview];
    return !self.hidden && NSPointInRect(local,self.bounds) ? self : nil;
}
@end

// A narrow, within-window blurred edge with a continuous alpha falloff.
// The view never participates in hit testing, scrolling or focus.
@interface PGScrollEdgeView : NSVisualEffectView
@property(nonatomic,strong) CAGradientLayer *fadeMask;
@property(nonatomic,strong) CALayer *shade;
@property(nonatomic) BOOL upperEdge;
- (instancetype)initUpper:(BOOL)upper;
@end
@implementation PGScrollEdgeView
- (instancetype)initUpper:(BOOL)upper {
    self=[super initWithFrame:NSZeroRect];
    if(self) {
        self.upperEdge=upper;self.material=NSVisualEffectMaterialHUDWindow;
        self.blendingMode=NSVisualEffectBlendingModeWithinWindow;self.state=NSVisualEffectStateActive;
        self.wantsLayer=YES;
        self.fadeMask=[CAGradientLayer layer];
        self.fadeMask.colors=@[(id)NSColor.blackColor.CGColor,(id)NSColor.clearColor.CGColor];
        self.fadeMask.startPoint=CGPointMake(0.5,upper?1:0);
        self.fadeMask.endPoint=CGPointMake(0.5,upper?0:1);
        self.layer.mask=self.fadeMask;
        self.shade=[CALayer layer];self.shade.backgroundColor=NSColor.clearColor.CGColor;
        [self.layer addSublayer:self.shade];
    }
    return self;
}
- (void)layout { [super layout];self.fadeMask.frame=self.bounds;self.shade.frame=self.bounds; }
- (NSView *)hitTest:(NSPoint)point { Q_UNUSED(point);return nil; }
@end


@interface PGPageContentView : NSView
@end
@implementation PGPageContentView
- (BOOL)isFlipped { return YES; }
@end

@interface PGCenteredSearchCell : NSSearchFieldCell
@end
@implementation PGCenteredSearchCell
// AppKit owns the search icon inset, placeholder baseline and field-editor rect.
// Overriding titleRect/ searchTextRect independently moved the editor over the icon.

@end

// Preserve AppKit's field editor and input methods inside the Qt host view.
@interface PGDownloadSearchField : NSSearchField
@end
@implementation PGDownloadSearchField
- (BOOL)acceptsFirstMouse:(NSEvent *)event { Q_UNUSED(event); return YES; }
- (void)mouseDown:(NSEvent *)event
{
    [self.window makeFirstResponder:self];
    [super mouseDown:event];
}
@end

static NSView *PGPageGlass(NSRect frame, CGFloat radius)
{
    NSView *glass = [[NSClassFromString(@"NSGlassEffectView") alloc] initWithFrame:frame];
    [glass setValue:@(radius) forKey:@"cornerRadius"];
    [glass setValue:@YES forKey:@"effectIsInteractive"];
    [glass setValue:[[PGPageContentView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)] forKey:@"contentView"];
    return glass;
}

// Both memory editors use the same AppKit controls and transparent field editor.
@interface PGMemoryBar : PGPageContentView
@property(nonatomic) double total;
@property(nonatomic) double used;
@property(nonatomic) double allocation;
@end
@implementation PGMemoryBar
- (void)drawRect:(NSRect)dirty {
    Q_UNUSED(dirty);
    const NSRect bounds = self.bounds;
    [NSGraphicsContext saveGraphicsState];
    [[NSBezierPath bezierPathWithRoundedRect:bounds xRadius:7 yRadius:7] addClip];
    [[NSColor whiteColor] setFill]; NSRectFill(bounds);
    const double total = std::max(1.0, self.total);
    const double used = std::max(0.0, std::min(total, self.used));
    const double allocation = std::max(0.0, std::min(total - used, self.allocation));
    [[NSColor systemGrayColor] setFill]; NSRectFill(NSMakeRect(0,0,NSWidth(bounds)*used/total,NSHeight(bounds)));
    [PGAccent() setFill]; NSRectFill(NSMakeRect(NSWidth(bounds)*used/total,0,NSWidth(bounds)*allocation/total,NSHeight(bounds)));
    [NSGraphicsContext restoreGraphicsState];
}
@end

@interface PGMemoryPanel : PGPageContentView
@property(nonatomic,strong) NSTextField *title;
@property(nonatomic,strong) NSSwitch *defaultSwitch;
@property(nonatomic,strong) NSTextField *defaultLabel;
@property(nonatomic,strong) NSSlider *slider;
@property(nonatomic,strong) NSTextField *field;
@property(nonatomic,strong) NSView *fieldGlass;
@property(nonatomic,strong) PGMemoryBar *bar;
@property(nonatomic,strong) NSTextField *status;
@property(nonatomic,strong) NSTextField *legend;
@property(nonatomic) CGFloat appliedStrength;
@property(nonatomic,copy) NSString *appliedAppearance;
- (instancetype)initWithTarget:(id)target;
- (void)updateMemory:(const QVariantMap &)state strength:(CGFloat)strength instance:(BOOL)instance;
@end
@implementation PGMemoryPanel
- (instancetype)initWithTarget:(id)target {
    self = [super initWithFrame:NSZeroRect];
    if(self) {
        _appliedStrength=-1;
        _title = [NSTextField labelWithString:@"Maximum memory (MiB)"]; [self addSubview:_title];
        _defaultLabel = [NSTextField labelWithString:@"Default"]; [self addSubview:_defaultLabel];
        _defaultSwitch = [[NSSwitch alloc] initWithFrame:NSZeroRect];
        _defaultSwitch.tag=110; _defaultSwitch.target=target; _defaultSwitch.action=@selector(changed:); [self addSubview:_defaultSwitch];
        _bar = [[PGMemoryBar alloc] initWithFrame:NSZeroRect]; [self addSubview:_bar];
        _slider = [NSSlider sliderWithValue:4096 minValue:512 maxValue:65536 target:target action:@selector(changed:)];
        _slider.tag=108; _slider.continuous=YES; [self addSubview:_slider];
        _fieldGlass = PGPageGlass(NSZeroRect,10); [self addSubview:_fieldGlass];
        _field = [[NSTextField alloc] initWithFrame:NSZeroRect];
        _field.delegate=target; _field.tag=109; _field.target=target; _field.action=@selector(changed:);
        _field.bezeled=NO; _field.bordered=NO; _field.drawsBackground=NO;
        _field.backgroundColor=NSColor.clearColor; _field.textColor=NSColor.labelColor;
        _field.font=[NSFont monospacedDigitSystemFontOfSize:13 weight:NSFontWeightRegular];
        [(NSView *)[_fieldGlass valueForKey:@"contentView"] addSubview:_field];
        _status=[NSTextField labelWithString:@""]; _status.textColor=NSColor.secondaryLabelColor; [self addSubview:_status];
        _legend=[NSTextField labelWithString:@"Gray: used   ·   Accent: allocation limit   ·   White: remaining"];
        _legend.font=[NSFont systemFontOfSize:11]; _legend.textColor=NSColor.secondaryLabelColor; [self addSubview:_legend];
    } return self;
}
- (void)updateMemory:(const QVariantMap &)state strength:(CGFloat)strength instance:(BOOL)instance {
    const CGFloat w=NSWidth(self.bounds);
    self.title.frame=NSMakeRect(0,0,std::max(100.0,w-130),24);
    self.defaultLabel.hidden=!instance; self.defaultSwitch.hidden=!instance;
    self.defaultLabel.frame=NSMakeRect(w-114,3,64,22); self.defaultSwitch.frame=NSMakeRect(w-44,0,44,26);
    self.defaultSwitch.state=state.value("instanceDefault").toBool()?NSControlStateValueOn:NSControlStateValueOff;
    const int limit=std::max(0,state.value("memoryLimit").toInt());
    const int value=std::max(0,std::min(limit,state.value("memory").toInt()));
    const BOOL editable=limit>=512 && (!instance || !state.value("instanceDefault").toBool());
    self.bar.frame=NSMakeRect(0,38,w,14);
    self.bar.total=state.value("memoryTotal").toDouble(); self.bar.used=state.value("memoryUsed").toDouble();
    self.bar.allocation=value; self.bar.needsDisplay=YES;
    self.bar.toolTip=[NSString stringWithFormat:@"Used %.0f MiB · Allocation %d MiB · Remaining %.0f MiB",self.bar.used,value,std::max(0.0,double(limit-value))];
    self.slider.frame=NSMakeRect(0,64,std::max(30.0,w-126),28);
    self.slider.minValue=std::min(512,limit); self.slider.maxValue=std::max(1,limit); self.slider.integerValue=value; self.slider.enabled=editable;
    const NSRect fieldFrame=NSMakeRect(w-110,60,110,36);
    if(!NSEqualRects(self.fieldGlass.frame,fieldFrame))self.fieldGlass.frame=fieldFrame;
    NSString *appearance=self.effectiveAppearance.name;
    if(self.appliedStrength!=strength || ![self.appliedAppearance isEqualToString:appearance]) {
        PGApplyGlass(self.fieldGlass,strength); self.appliedStrength=strength; self.appliedAppearance=appearance;
    }
    const NSRect textFrame=NSMakeRect(12,9,86,20);
    if(!NSEqualRects(self.field.frame,textFrame))self.field.frame=textFrame;
    self.field.enabled=editable;
    if(!self.field.currentEditor && self.field.integerValue!=value) self.field.integerValue=value;
    self.field.textColor=editable?NSColor.labelColor:NSColor.secondaryLabelColor;
    self.status.frame=NSMakeRect(0,108,w,22); self.status.stringValue=PGString(state.value("memoryStatus").toString());
    self.legend.frame=NSMakeRect(0,136,w,20);
}
@end

@interface PGNativePageUI : PGPageContentView <NSSearchFieldDelegate>
@property(nonatomic) BOOL compactSearchExpanded;
@property(nonatomic,strong) id searchDismissMonitor;
@property(nonatomic, assign) MacWindowMetrics *metrics;
@property(nonatomic, strong) PGMemoryPanel *globalMemoryPanel;
@property(nonatomic, strong) PGMemoryPanel *instanceMemoryPanel;
@property(nonatomic, strong) PGPageContentView *logControls;
@property(nonatomic, strong) NSScrollView *settingsScroll;
@property(nonatomic, strong) PGPageContentView *settingsDocument;
@property(nonatomic, strong) PGPageContentView *downloadToolbar;
@property(nonatomic, strong) NSScrollView *categoryScroll;
@property(nonatomic, strong) PGPageContentView *categoryDocument;
@property(nonatomic, strong) NSBox *settingsDivider;
@property(nonatomic, strong) NSBox *groupModeDivider;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSControl *> *controls;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSView *> *surfaces;
@property(nonatomic, strong) NSMutableArray<NSView *> *groups;
@property(nonatomic, strong) NSMutableArray<NSView *> *groupSurfaces;
- (void)updateState:(const QVariantMap &)state strength:(CGFloat)strength;
- (void)changed:(id)sender;
- (void)submitSearch:(id)sender;
- (void)refreshSearchLayout;
- (void)buildSettings;
- (void)buildDownloads;
@end

@implementation PGNativePageUI
{
    QVariantMap _lastState;
    NSSize _lastSize;
    CGFloat _lastStrength;
    BOOL _hasState;
}
// Resolve the search field before effect/background views can consume clicks.
- (NSView *)hitTest:(NSPoint)point
{
    const NSPoint local = [self convertPoint:point fromView:self.superview];
    if (self.hidden || !NSPointInRect(local, self.bounds)) return nil;

    if (!self.downloadToolbar.hidden) {
        NSSearchField *search = (NSSearchField *)self.controls[@202];
        if (search && !search.hidden && NSPointInRect(local, [search convertRect:search.bounds toView:self]))
            return search;
    }
    return [super hitTest:point];
}
- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _controls = [NSMutableDictionary dictionary];
        _surfaces = [NSMutableDictionary dictionary];
        _groups = [NSMutableArray array];
        _groupSurfaces = [NSMutableArray array];
        _downloadToolbar = [[PGPageContentView alloc] initWithFrame:NSZeroRect];
        [self addSubview:_downloadToolbar];
        _settingsScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
        _settingsScroll.drawsBackground = NO;
        _settingsScroll.contentView.drawsBackground=NO;
        _settingsScroll.borderType=NSNoBorder;
        _settingsScroll.scrollerStyle=NSScrollerStyleOverlay;
        _settingsScroll.hasVerticalScroller = YES;
        _settingsScroll.autohidesScrollers = YES;
        _settingsDocument = [[PGPageContentView alloc] initWithFrame:NSZeroRect];
        _settingsScroll.documentView = _settingsDocument;
        [self addSubview:_settingsScroll];
        [self buildSettings];
        [self buildDownloads];
        __weak PGNativePageUI *weakPage=self;
        self.searchDismissMonitor=[NSEvent addLocalMonitorForEventsMatchingMask:NSEventMaskLeftMouseDown handler:^NSEvent *(NSEvent *event) {
            PGNativePageUI *page=weakPage;
            if(page && page.compactSearchExpanded && event.window==page.window) {
                NSView *surface=page.surfaces[@202];
                NSPoint point=[surface convertPoint:event.locationInWindow fromView:nil];
                if(!NSPointInRect(point,surface.bounds)) {
                    page.compactSearchExpanded=NO;
                    [page.window makeFirstResponder:nil];
                    [page refreshSearchLayout];
                }
            }
            return event;
        }];
        _instanceMemoryPanel=[[PGMemoryPanel alloc] initWithTarget:self];
        [self addSubview:_instanceMemoryPanel];
        _logControls=[[PGPageContentView alloc] initWithFrame:NSZeroRect];
        [self addSubview:_logControls];
        for(NSInteger tag:{120,121}) {
            NSSwitch *toggle=[[NSSwitch alloc] initWithFrame:NSZeroRect];
            toggle.tag=tag;toggle.target=self;toggle.action=@selector(changed:);
            self.controls[@(tag)]=toggle;[_logControls addSubview:toggle];
            NSTextField *label=[NSTextField labelWithString:tag==120?@"Keep updating":@"Wrap lines"];
            label.tag=tag+100;[_logControls addSubview:label];
        }
    }
    return self;
}
- (NSPopUpButton *)popup:(NSArray<NSString *> *)items tag:(NSInteger)tag parent:(NSView *)parent
{
    NSPopUpButton *control = [[PGGlassPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    [control addItemsWithTitles:items]; control.bordered=NO;
    control.tag = tag; control.target = self; control.action = @selector(changed:);
    self.controls[@(tag)] = control;
    [parent addSubview:control];
    return control;
}
- (NSButton *)button:(NSString *)title tag:(NSInteger)tag parent:(NSView *)parent
{
    NSButton *button = [NSButton buttonWithTitle:title target:self action:@selector(changed:)];
    button.tag = tag; button.bezelStyle = NSBezelStyleRounded;
    self.controls[@(tag)] = button; [parent addSubview:button]; return button;
}
- (NSTextField *)label:(NSString *)title frame:(NSRect)frame parent:(NSView *)parent
{
    NSTextField *label = [NSTextField labelWithString:title];
    label.font = [NSFont systemFontOfSize:13]; label.frame = frame;
    [parent addSubview:label]; return label;
}
- (void)buildSettings
{
    // Flat grouped rows follow System Settings; controls retain system styling.
    for (int i = 0; i < 5; ++i) {
        NSView *surface = PGPageGlass(NSZeroRect, 12);
        NSView *group = [surface valueForKey:@"contentView"];
        group.wantsLayer = YES;
        group.layer.cornerRadius = 12;
        group.layer.masksToBounds = YES;
        NSVisualEffectView *material = [[NSVisualEffectView alloc] initWithFrame:group.bounds];
        material.identifier = @"PGSettingsExtraFrost";
        material.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        material.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        material.material = NSVisualEffectMaterialHUDWindow;
        material.state = NSVisualEffectStateActive;
        [group addSubview:material];
        [self.settingsDocument addSubview:surface];
        [self.groups addObject:group]; [self.groupSurfaces addObject:surface];
    }
    self.globalMemoryPanel=[[PGMemoryPanel alloc] initWithTarget:self];
    [self.groups[3] addSubview:self.globalMemoryPanel];
    NSView *theme=self.groups[4];
    [self button:@"Prism connection…" tag:114 parent:theme];
    [self label:@"Accent color" frame:NSMakeRect(16,16,160,22) parent:theme];
    [self popup:@[@"Auto",@"System",@"Blue",@"Purple",@"Pink",@"Red",@"Orange",@"Yellow",@"Green",@"Custom"] tag:111 parent:theme];
    NSColorWell *well=[[NSColorWell alloc] initWithFrame:NSZeroRect];
    well.tag=112; well.target=self; well.action=@selector(changed:); self.controls[@112]=well; [theme addSubview:well];
    [self button:@"Show sidebar guide" tag:113 parent:theme];
    NSTextField *hint=[self label:@"Accent highlights actions and sidebar symbols; artwork keeps its original colors." frame:NSZeroRect parent:theme];hint.tag=195;hint.textColor=NSColor.secondaryLabelColor;hint.font=[NSFont systemFontOfSize:11];hint.lineBreakMode=NSLineBreakByWordWrapping;hint.maximumNumberOfLines=2;
    NSView *layout = self.groups[0];
    [self label:@"Grouped layout" frame:NSMakeRect(16, 16, 240, 20) parent:layout];
    [self label:@"Quick cards" frame:NSMakeRect(16, 64, 240, 20) parent:layout];
    for (int i = 0; i < 2; ++i) {
        NSSwitch *toggle = [[NSSwitch alloc] initWithFrame:NSZeroRect];
        toggle.tag = 101 + i; toggle.target = self; toggle.action = @selector(changed:);
        self.controls[@(101 + i)] = toggle; [layout addSubview:toggle];
    }
    NSBox *divider = [[NSBox alloc] initWithFrame:NSZeroRect]; divider.boxType = NSBoxSeparator;
    self.settingsDivider = divider; [layout addSubview:divider];
    [self label:@"Group by" frame:NSMakeRect(16, 112, 180, 20) parent:layout];
    [self popup:@[@"Off", @"Smart", @"Minecraft version", @"Mod loader", @"Installed status", @"Custom"] tag:107 parent:layout];
    NSBox *modeDivider = [[NSBox alloc] initWithFrame:NSZeroRect]; modeDivider.boxType = NSBoxSeparator;
    self.groupModeDivider = modeDivider; [layout addSubview:modeDivider];
    NSView *background = self.groups[1];
    [self label:@"Background" frame:NSMakeRect(16, 16, 200, 20) parent:background];
    [self popup:@[@"White", @"Gray", @"Black", @"Custom", @"Custom color"] tag:103 parent:background];
    [self button:@"Choose image…" tag:104 parent:background];
    [self popup:@[@"Fill", @"Fit", @"Stretch", @"Center", @"Tile"] tag:105 parent:background];
    NSTextField *file = [self label:@"" frame:NSZeroRect parent:background]; file.tag = 191;
    file.lineBreakMode = NSLineBreakByTruncatingMiddle; file.textColor = NSColor.secondaryLabelColor;
    NSView *glass = self.groups[2];
    [self label:@"Glass appearance" frame:NSMakeRect(16, 16, 220, 20) parent:glass];
    NSSlider *slider = [NSSlider sliderWithValue:0.5 minValue:0 maxValue:1 target:self action:@selector(changed:)];
    slider.tag = 106; slider.continuous = YES; self.controls[@106] = slider; [glass addSubview:slider];
    NSTextField *percent = [self label:@"" frame:NSZeroRect parent:glass]; percent.tag = 192;
    percent.alignment = NSTextAlignmentRight; percent.textColor = NSColor.secondaryLabelColor;
    [self label:@"Clear" frame:NSMakeRect(16, 79, 70, 18) parent:glass];
    NSTextField *frosted = [self label:@"Frosted" frame:NSZeroRect parent:glass]; frosted.tag = 193;
    frosted.alignment = NSTextAlignmentRight;
}
- (void)buildDownloads
{
    self.categoryScroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    self.categoryScroll.drawsBackground = NO;
    self.categoryScroll.hasHorizontalScroller = YES;
    self.categoryScroll.autohidesScrollers = YES;
    self.categoryScroll.scrollerStyle = NSScrollerStyleOverlay;
    self.categoryDocument = [[PGPageContentView alloc] initWithFrame:NSMakeRect(0, 0, 454, 42)];
    self.categoryScroll.documentView = self.categoryDocument;
    [self.downloadToolbar addSubview:self.categoryScroll];
    for (NSInteger tag : {201, 202, 203, 204, 205, 210, 211, 212, 213, 214}) {
        NSView *glass = PGPageGlass(NSZeroRect, 21);
        [(tag >= 210 ? self.categoryDocument : self.downloadToolbar) addSubview:glass]; self.surfaces[@(tag)] = glass;
        NSView *content = [glass valueForKey:@"contentView"];
        if (tag == 201) [self popup:@[@"Modrinth"] tag:tag parent:content];
        else if (tag == 202) {
            NSSearchField *search = [[PGDownloadSearchField alloc] initWithFrame:NSZeroRect];
            search.cell=[[NSSearchFieldCell alloc] initTextCell:@""];
            [(NSSearchFieldCell *)search.cell setSearchButtonCell:nil];
            [(NSSearchFieldCell *)search.cell setCancelButtonCell:nil];
            NSImageView *searchIcon=[[NSImageView alloc] initWithFrame:NSMakeRect(14,13,16,16)];
            searchIcon.tag=1202;searchIcon.image=[NSImage imageWithSystemSymbolName:@"magnifyingglass" accessibilityDescription:nil];
            searchIcon.contentTintColor=NSColor.secondaryLabelColor;[content addSubview:searchIcon];
            search.font=[NSFont systemFontOfSize:13];
            search.editable = YES; search.selectable = YES; search.bezeled=NO; search.drawsBackground=NO;
            search.enabled = YES; search.refusesFirstResponder = NO;
            search.focusRingType=NSFocusRingTypeNone;search.controlSize=NSControlSizeRegular;
            search.placeholderString = @"Search versions…"; search.delegate = self;
            search.sendsSearchStringImmediately = NO;
            search.sendsWholeSearchString = YES;
            search.target = self; search.action = @selector(submitSearch:);
            self.controls[@(tag)] = search; [content addSubview:search];
            // One glass surface represents search in both expanded and compact states.
            NSButton *toggle=[self button:@"" tag:206 parent:content];
            toggle.bordered=NO;toggle.imagePosition=NSImageOnly;toggle.hidden=YES;
            toggle.image=[NSImage imageWithSystemSymbolName:@"magnifyingglass" accessibilityDescription:@"Search"];
            toggle.contentTintColor=NSColor.labelColor;
        } else if (tag == 204) [self popup:@[@"All loaders", @"Fabric", @"Forge", @"NeoForge", @"Quilt"] tag:tag parent:content];
        else if (tag == 205) [self popup:@[@"Featured", @"Newest", @"Updated"] tag:tag parent:content];
        else {
            NSArray *titles = @[@"Versions", @"Mods", @"Shaders", @"Resource packs", @"Modpacks"];
            NSButton *button = [self button:tag == 203 ? @"Refresh" : titles[tag - 210] tag:tag parent:content];
            button.bordered = NO;
        }
    }
}
- (void)layoutSurface:(NSInteger)tag rect:(NSRect)rect strength:(CGFloat)strength
{
    NSView *glass = self.surfaces[@(tag)]; glass.frame = rect;
    NSView *content = [glass valueForKey:@"contentView"];
    content.frame = NSMakeRect(0, 0, rect.size.width, rect.size.height);
    NSControl *control = self.controls[@(tag)];
    // A search cell's placeholder has intrinsic height; a tall field leaves it top-aligned.
    const CGFloat controlHeight=tag==202?22.0:rect.size.height-10;
    const CGFloat inset=tag==202?38:8;
    const NSRect controlFrame = NSMakeRect(inset, (rect.size.height-controlHeight)/2+(tag==202?3:0), std::max(0.0, rect.size.width-inset-8), controlHeight);
    if(tag==202){NSView *icon=[content viewWithTag:1202];icon.frame=NSMakeRect(14,(rect.size.height-16)/2,16,16);}
    if (!NSEqualRects(control.frame, controlFrame)) control.frame = controlFrame;
    PGApplyGlass(glass, strength);
}
- (void)updateState:(const QVariantMap &)state strength:(CGFloat)strength
{
    // Skip unchanged snapshots: do not relayout native editors each Qt frame.
    if (_hasState && _lastState == state && NSEqualSizes(_lastSize, self.bounds.size) &&
        std::abs(_lastStrength - strength) < 0.0001) return;
    _hasState = YES; _lastState = state; _lastSize = self.bounds.size; _lastStrength = strength;
    const BOOL settings = state.value("page").toString() == "Settings";
    NSString *appearanceName = state.value("dark").toBool() ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua;
    if (![self.appearance.name isEqualToString:appearanceName])
        self.appearance = [NSAppearance appearanceNamed:appearanceName];
    const BOOL instance=state.value("page").toString()=="Instance";
    self.settingsScroll.hidden = !settings; self.downloadToolbar.hidden = settings || instance;
    const BOOL logs=instance && state.value("editorTab").toString()=="Minecraft Log";
    self.logControls.hidden=!logs;
    self.instanceMemoryPanel.hidden=!instance || logs;
    if(logs) {
        self.logControls.frame=self.bounds;
        const BOOL narrow=NSWidth(self.bounds)<360;
        const CGFloat cell=narrow?NSWidth(self.bounds):(NSWidth(self.bounds)-24)/2;
        for(NSInteger i=0;i<2;++i) {
            const CGFloat x=narrow?0:i*(cell+24),y=narrow?i*44:0;
            NSTextField *label=(NSTextField *)[self.logControls viewWithTag:220+i];
            label.frame=NSMakeRect(x,y+10,std::max(60.0,cell-56),24);
            NSSwitch *toggle=(NSSwitch *)self.controls[@(120+i)];
            toggle.frame=NSMakeRect(x+cell-44,y+6,44,28);
            toggle.state=state.value(i==0?"logKeepUpdating":"logWrapLines").toBool()?NSControlStateValueOn:NSControlStateValueOff;
        }
        return;
    }
    if(instance) {
        self.instanceMemoryPanel.frame=self.bounds;
        [self.instanceMemoryPanel updateMemory:state strength:strength instance:YES];
        return;
    }
    const CGFloat width = NSWidth(self.bounds);
    if (settings) {
        self.settingsScroll.frame = self.bounds;
        const CGFloat w = std::max(0.0,state.value("width").toDouble());
        const CGFloat inset=state.value("x").toDouble()-state.value("edgeX").toDouble();
        const BOOL custom = state.value("background").toString() == "Custom";
        const BOOL customColor=state.value("background").toString()=="Custom color";
        const auto gradientStops=state.value("gradientStops").toList();
        const CGFloat backgroundHeight = custom ? 142 : customColor?(state.value("customGradient").toBool()?166+gradientStops.size()*44:108):52;
        const CGFloat top=state.value("settingsTop").toDouble();
        const CGFloat bottom=108;
        self.settingsScroll.automaticallyAdjustsContentInsets=NO;
        self.settingsDocument.frame = NSMakeRect(0, 0, width, std::max(NSHeight(self.bounds), top + 144 + 16 + backgroundHeight + 16 + 110 + 16 + 190 + 16 + 150 + bottom));
        self.groups[0].frame = NSMakeRect(0, 0, w, 144);
        self.groups[1].frame = NSMakeRect(0, 160, w, backgroundHeight);
        self.groups[2].frame = NSMakeRect(0, 176 + backgroundHeight, w, 110);
        self.groups[3].frame = NSMakeRect(0, 302 + backgroundHeight, w, 190);
        self.groups[4].frame = NSMakeRect(0, 508 + backgroundHeight, w, 150);
        self.controls[@111].frame=NSMakeRect(w-220,12,204,28);
        [(NSPopUpButton *)self.controls[@111] selectItemWithTitle:PGString(state.value("themeChoice").toString())];
        self.controls[@112].frame=NSMakeRect(w-280,12,48,28);
        QColor accentColor(state.value("customAccent").toString());
        if(accentColor.isValid())[(NSColorWell *)self.controls[@112] setColor:[NSColor colorWithSRGBRed:accentColor.redF() green:accentColor.greenF() blue:accentColor.blueF() alpha:1]];
        self.controls[@113].frame=NSMakeRect(16,56,170,28);
        self.controls[@114].frame=NSMakeRect(200,56,180,28);
        [self.groups[4] viewWithTag:195].frame=NSMakeRect(16,100,w-32,40);
        for (NSUInteger i = 0; i < self.groups.count; ++i) {
            NSView *group = self.groups[i];
            NSView *surface = self.groupSurfaces[i];
            const NSRect frame = group.frame;
            surface.frame = NSOffsetRect(frame,inset,top);
            group.frame = NSMakeRect(0, 0, frame.size.width, frame.size.height);
            // Match sidebar tint/opacity, with just a little extra native frost.
            PGApplyGlass(surface, strength, true);
            for (NSView *view in group.subviews) {
                if ([view.identifier isEqualToString:@"PGSettingsExtraFrost"]) {
                    view.frame = group.bounds;
                    view.alphaValue = 0.10 + strength * strength * 0.16;
                }
            }
        }
        self.globalMemoryPanel.frame=NSMakeRect(16,16,w-32,160);
        [self.globalMemoryPanel updateMemory:state strength:strength instance:NO];
        for (NSInteger tag : {101, 102}) {
            NSSwitch *toggle = (NSSwitch *)self.controls[@(tag)];
            toggle.frame = NSMakeRect(w - 66, tag == 101 ? 12 : 60, 44, 28);
            toggle.state = state.value(tag == 101 ? "grouped" : "quick").toBool() ? NSControlStateValueOn : NSControlStateValueOff;
        }
        self.settingsDivider.frame = NSMakeRect(16, 48, w - 32, 1);
        self.groupModeDivider.frame = NSMakeRect(16, 96, w - 32, 1);
        self.controls[@107].frame = NSMakeRect(w - 220, 108, 204, 28);
        self.controls[@107].enabled = YES;
        [(NSPopUpButton *)self.controls[@107] selectItemWithTitle:PGString(state.value("groupingMethod").toString())];
        self.controls[@103].frame = NSMakeRect(w - 220, 12, 204, 28);
        [(NSPopUpButton *)self.controls[@103] selectItemWithTitle:PGString(state.value("background").toString())];
        self.controls[@104].hidden = !custom; self.controls[@105].hidden = !custom;
        [self.groups[1] viewWithTag:191].hidden = !custom;
        for(NSNumber *key in self.controls.allKeys)if(key.integerValue>=2990)self.controls[key].hidden=YES;
        if(customColor) {
            NSView *parent=self.groups[1];
            if(!self.controls[@2990]) {
                [self popup:@[@"Solid",@"Gradient"] tag:2990 parent:parent];
                NSSlider *angle=[NSSlider sliderWithValue:45 minValue:0 maxValue:360 target:self action:@selector(changed:)];angle.numberOfTickMarks=9;angle.allowsTickMarkValuesOnly=NO;angle.tag=2991;self.controls[@2991]=angle;[parent addSubview:angle];
                [self button:@"Add color stop" tag:2992 parent:parent];
                NSTextField *angleField=[[NSTextField alloc] initWithFrame:NSZeroRect];angleField.tag=2994;angleField.target=self;angleField.action=@selector(changed:);self.controls[@2994]=angleField;[parent addSubview:angleField];
                NSColorWell *solid=[[NSColorWell alloc] initWithFrame:NSZeroRect];solid.tag=2993;solid.target=self;solid.action=@selector(changed:);self.controls[@2993]=solid;[parent addSubview:solid];
            }
            const BOOL gradient=state.value("customGradient").toBool();
            self.controls[@2990].hidden=NO;self.controls[@2990].frame=NSMakeRect(16,56,160,28);[(NSPopUpButton *)self.controls[@2990] selectItemAtIndex:gradient?1:0];
            auto nsColor=[](const QString &hex){QColor c(hex);return [NSColor colorWithSRGBRed:c.redF() green:c.greenF() blue:c.blueF() alpha:1];};
            self.controls[@2993].hidden=gradient;self.controls[@2993].frame=NSMakeRect(w-100,56,80,28);[(NSColorWell *)self.controls[@2993] setColor:nsColor(state.value("customColorStart").toString())];
            self.controls[@2991].hidden=!gradient;self.controls[@2991].frame=NSMakeRect(190,56,std::max(80.0,w-300),28);self.controls[@2994].hidden=!gradient;self.controls[@2994].frame=NSMakeRect(w-88,56,72,28);if(![(NSTextField *)self.controls[@2994] currentEditor])[(NSTextField *)self.controls[@2994] setDoubleValue:state.value("customGradientAngle").toDouble()];[(NSSlider *)self.controls[@2991] setDoubleValue:state.value("customGradientAngle").toDouble()];
            for(int i=0;gradient && i<gradientStops.size();++i){
                const int tag=3000+i*3;auto stop=gradientStops[i].toMap();
                if(!self.controls[@(tag)]) {
                    NSColorWell *well=[[NSColorWell alloc] initWithFrame:NSZeroRect];well.tag=tag;well.target=self;well.action=@selector(changed:);self.controls[@(tag)]=well;[parent addSubview:well];
                    NSSlider *position=[NSSlider sliderWithValue:0 minValue:0 maxValue:100 target:self action:@selector(changed:)];position.tag=tag+1;self.controls[@(tag+1)]=position;[parent addSubview:position];
                    [self button:@"Remove" tag:tag+2 parent:parent];
                }
                const CGFloat y=96+i*44;
                for(int j=0;j<3;++j)self.controls[@(tag+j)].hidden=NO;
                self.controls[@(tag)].frame=NSMakeRect(16,y,80,28);[(NSColorWell *)self.controls[@(tag)] setColor:nsColor(stop.value("color").toString())];
                self.controls[@(tag+1)].frame=NSMakeRect(112,y,std::max(80.0,w-232),28);[(NSSlider *)self.controls[@(tag+1)] setDoubleValue:stop.value("position").toDouble()*100];
                self.controls[@(tag+2)].frame=NSMakeRect(w-100,y,84,28);self.controls[@(tag+2)].enabled=gradientStops.size()>2;
            }
            self.controls[@2992].hidden=!gradient;self.controls[@2992].frame=NSMakeRect(16,100+gradientStops.size()*44,160,30);
        }
        self.controls[@104].frame = NSMakeRect(16, 56, 136, 28);
        self.controls[@105].frame = NSMakeRect(w - 220, 56, 204, 28);
        [(NSPopUpButton *)self.controls[@105] selectItemWithTitle:PGString(state.value("placement").toString())];
        NSTextField *file = (NSTextField *)[self.groups[1] viewWithTag:191];
        file.frame = NSMakeRect(16, 102, w - 32, 20);
        file.stringValue = PGString(state.value("image").toString().isEmpty() ? QStringLiteral("No image selected") : QUrl(state.value("image").toString()).fileName());
        self.controls[@106].frame = NSMakeRect(16, 48, w - 32, 24);
        [(NSSlider *)self.controls[@106] setDoubleValue:state.value("glass").toDouble()];
        NSTextField *percent = (NSTextField *)[self.groups[2] viewWithTag:192];
        percent.frame = NSMakeRect(w - 76, 16, 60, 20);
        percent.stringValue = [NSString stringWithFormat:@"%.0f%%", state.value("glass").toDouble() * 100];
        [self.groups[2] viewWithTag:193].frame = NSMakeRect(w - 96, 79, 80, 18);
    } else {
        self.downloadToolbar.frame = self.bounds;
        [self layoutSurface:201 rect:NSMakeRect(0, 0, 148, 42) strength:strength];
        [self layoutSurface:202 rect:NSMakeRect(156, 0, std::max(80.0, width - 156), 42) strength:strength];
        [(NSPopUpButton *)self.controls[@201] selectItemWithTitle:PGString(state.value("provider").toString())];
        NSSearchField *search = (NSSearchField *)self.controls[@202];
        NSString *query = PGString(state.value("query").toString());
        // The field editor owns live/marked text. Never replace it during typing.
        if (!search.currentEditor && ![search.stringValue isEqualToString:query])
            search.stringValue = query;
        search.placeholderString = [@"Search " stringByAppendingString:[PGString(state.value("category").toString()).lowercaseString stringByAppendingString:@"…"]];
        const BOOL mods = state.value("category").toString() == "Mods";
        CGFloat x = 0;
        const CGFloat widths[] = {78, 64, 78, 122, 92};
        for (NSInteger i = 0; i < 5; ++i) {
            CGFloat w = widths[i];
            NSView *glass=self.surfaces[@(210+i)];
            NSButton *button=(NSButton *)self.controls[@(210+i)];
            NSView *content=[glass valueForKey:@"contentView"];
            if(button.superview!=content) { [button removeFromSuperview]; [content addSubview:button]; }
            glass.hidden=NO;
            [self layoutSurface:210 + i rect:NSMakeRect(x, 0, w, 40) strength:strength]; x += w + 4;
            const BOOL selected = [button.title isEqualToString:PGString(state.value("category").toString())];
            button.font = [NSFont systemFontOfSize:12 weight:selected ? NSFontWeightSemibold : NSFontWeightRegular];
            button.contentTintColor = selected ? PGAccent() : NSColor.labelColor;
        }
        self.categoryDocument.frame = NSMakeRect(0, 0, x - 4, 42);
        const CGFloat sortWidth = 130, refreshWidth = 72, loaderWidth = mods ? 122 : 0;
        CGFloat right = width - sortWidth;
        [self layoutSurface:205 rect:NSMakeRect(right, 54, sortWidth, 42) strength:strength];
        right -= 8;
        self.surfaces[@204].hidden = !mods;
        if (mods) { right -= loaderWidth; [self layoutSurface:204 rect:NSMakeRect(right, 54, loaderWidth, 42) strength:strength]; right -= 8; }
        right -= refreshWidth; [self layoutSurface:203 rect:NSMakeRect(right, 54, refreshWidth, 42) strength:strength];
        self.categoryScroll.frame = NSMakeRect(0, 54, std::max(0.0, right - 8), 42);
        if(state.value("sidebarDownloads").toBool()) {
            const CGFloat categoryWidth=state.value("categoryWidth").toDouble();
            for(NSInteger i=0;i<5;++i) {
                NSButton *button=(NSButton *)self.controls[@(210+i)];
                NSView *glass=self.surfaces[@(210+i)];
                const BOOL selected=[button.title isEqualToString:PGString(state.value("category").toString())];
                [self layoutSurface:210+i rect:NSMakeRect(0,i*48,categoryWidth,42) strength:strength];
                glass.hidden=!selected;
                if(!selected) {
                    [button removeFromSuperview]; [self.categoryDocument addSubview:button];
                    button.frame=NSMakeRect(46,i*48+5,std::max(0.0,categoryWidth-58),32);
                }
                if(selected)button.frame=NSMakeRect(46,5,std::max(0.0,categoryWidth-58),32);
                button.alignment=NSTextAlignmentLeft;
            }
            self.categoryDocument.frame=NSMakeRect(0,0,categoryWidth,236);
            const CGFloat gap=8;
            const CGFloat provider=132;
            const CGFloat sort=140;
            const CGFloat refresh=76;
            const CGFloat loader=mods?148:0;
            const CGFloat searchWidth=std::max(60.0,width-provider-sort-refresh-loader-gap*(mods?4:3));
            CGFloat pos=0;
            [self layoutSurface:201 rect:NSMakeRect(pos,0,provider,42) strength:strength];pos+=provider+gap;
            [self layoutSurface:202 rect:NSMakeRect(pos,0,searchWidth,42) strength:strength];pos+=searchWidth+gap;
            [self layoutSurface:203 rect:NSMakeRect(pos,0,refresh,42) strength:strength];pos+=refresh+gap;
            if(mods) { [self layoutSurface:204 rect:NSMakeRect(pos,0,loader,42) strength:strength];pos+=loader+gap; }
            [self layoutSurface:205 rect:NSMakeRect(pos,0,sort,42) strength:strength];
        } else {
            for(NSInteger i=0;i<5;++i) [(NSButton *)self.controls[@(210+i)] setAlignment:NSTextAlignmentCenter];
        }
        self.controls[@203].enabled = !state.value("busy").toBool();
        const BOOL sidebar=state.value("sidebarDownloads").toBool();
        // Compact only when the current row cannot fit its controls and a useful search field.
        const CGFloat required=sidebar?(mods?688:532):(mods?902:772);
        const BOOL compact=width<required;
        NSButton *searchButton=(NSButton *)self.controls[@206];
        search.hidden=compact && !self.compactSearchExpanded;
        searchButton.hidden=!search.hidden;
        [[search.superview viewWithTag:1202] setHidden:search.hidden];
        self.surfaces[@202].hidden=NO;
        for(NSNumber *key in @[@201,@203,@204,@205])self.surfaces[key].hidden=(key.intValue==204 && !mods);
        if(compact) {
            const CGFloat gap=8,provider=110,refresh=64,loader=mods?104:0,sort=104;
            if(self.compactSearchExpanded) {
                for(NSNumber *key in @[@201,@203,@204,@205])self.surfaces[key].hidden=YES;
                [self layoutSurface:202 rect:NSMakeRect(0,0,width,42) strength:strength];
            } else {
                CGFloat x=0;
                [self layoutSurface:201 rect:NSMakeRect(x,0,provider,42) strength:strength];x+=provider+gap;
                // Replace the field in place, immediately after the provider.
                [self layoutSurface:202 rect:NSMakeRect(x,0,42,42) strength:strength];x+=42+gap;
                [self layoutSurface:203 rect:NSMakeRect(x,0,refresh,42) strength:strength];x+=refresh+gap;
                if(mods){[self layoutSurface:204 rect:NSMakeRect(x,0,loader,42) strength:strength];x+=loader+gap;}
                [self layoutSurface:205 rect:NSMakeRect(x,0,sort,42) strength:strength];
            }
            if(!sidebar)self.categoryScroll.frame=NSMakeRect(0,54,width,42);
        }
        searchButton.frame=NSMakeRect(0,0,42,42);
        if(!sidebar)self.categoryScroll.hidden=compact && self.compactSearchExpanded;
        [(NSPopUpButton *)self.controls[@204] selectItemWithTitle:PGString(state.value("loader").toString())];
        [(NSPopUpButton *)self.controls[@205] selectItemWithTitle:PGString(state.value("sort").toString())];
    }
}
- (void)dealloc { if(self.searchDismissMonitor)[NSEvent removeMonitor:self.searchDismissMonitor]; }
- (void)refreshSearchLayout {
    const QVariantMap state=_lastState;
    _hasState=NO;
    [self updateState:state strength:_lastStrength];
}
- (void)submitSearch:(id)sender
{
    NSSearchField *field = (NSSearchField *)self.controls[@202];
    NSText *editor = field.currentEditor;
    if ([editor isKindOfClass:NSTextView.class] && [(NSTextView *)editor hasMarkedText]) return;
    Q_UNUSED(sender);
    const auto submitted=QString::fromUtf8((editor ? editor.string : field.stringValue).UTF8String);
    self.compactSearchExpanded=NO;[self.window makeFirstResponder:nil];[self refreshSearchLayout];
    if (self.metrics) self.metrics->changePageControl(QStringLiteral("searchSubmit"),submitted);
}
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
    if (textView.hasMarkedText) return NO;
    if ((control.tag==109 || control.tag==202) &&
        (command==@selector(insertNewline:) || command==@selector(cancelOperation:))) {
        if(control.tag==109) {
            [(NSTextField *)control setStringValue:textView.string];
            [self changed:control];
        } else {
            [(NSSearchField *)control setStringValue:textView.string];
            if(command==@selector(insertNewline:)) [self submitSearch:control];
            else [self changed:control];
        }
        [self.window makeFirstResponder:nil];
        return YES;
    }
    return NO;
}
- (void)controlTextDidEndEditing:(NSNotification *)notification {
    if([notification.object tag]==202){self.compactSearchExpanded=NO;[self refreshSearchLayout];}
    if([notification.object tag]==109) [self changed:notification.object];
}
- (void)controlTextDidChange:(NSNotification *)notification {
    if([notification.object tag]==202) [self changed:notification.object];
}
- (void)changed:(id)sender
{
    if (!self.metrics) return;
    const NSInteger tag = [sender tag];
    if (tag == 202) {
        NSText *editor = [(NSSearchField *)sender currentEditor];
        if ([editor isKindOfClass:NSTextView.class] && [(NSTextView *)editor hasMarkedText]) return;
    }
    if(tag>=2990) {
        auto colorString=[](NSColor *color){auto c=[color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];return QColor::fromRgbF(c.redComponent,c.greenComponent,c.blueComponent).name();};
        if(tag==2990){self.metrics->changePageControl("customGradient",[(NSPopUpButton *)sender indexOfSelectedItem]==1);return;}
        if(tag==2991){self.metrics->changePageControl("customGradientAngle",([](double v){double snap=std::round(v/45)*45;return std::abs(v-snap)<=3?snap:v;})([(NSSlider *)sender doubleValue]));return;}
        if(tag==2994){self.metrics->changePageControl("customGradientAngle",std::clamp([(NSTextField *)sender doubleValue],0.0,360.0));return;}
        if(tag==2993){self.metrics->changePageControl("customColorStart",colorString([(NSColorWell *)sender color]));return;}
        auto stops=_lastState.value("gradientStops").toList();
        if(tag==2992)stops.append(QVariantMap{{"color","#ffffff"},{"position",0.5}});
        else {const int i=(tag-3000)/3,kind=(tag-3000)%3;if(i<0 || i>=stops.size())return;
            auto stop=stops[i].toMap();
            if(kind==0)stop.insert("color",colorString([(NSColorWell *)sender color]));
            if(kind==1)stop.insert("position",[(NSSlider *)sender doubleValue]/100.0);
            if(kind==2){if(stops.size()<=2)return;stops.removeAt(i);}else stops[i]=stop;
        }
        self.metrics->changePageControl("gradientStops",stops);return;
    }
    if(tag==206){self.compactSearchExpanded=YES;[self refreshSearchLayout];[self.window makeFirstResponder:self.controls[@202]];return;}
    const char *key = nullptr; QVariant value;
    switch (tag) {
    case 101: key = "grouped"; value = [(NSSwitch *)sender state] == NSControlStateValueOn; break;
    case 102: key = "quick"; value = [(NSSwitch *)sender state] == NSControlStateValueOn; break;
    case 103: key = "background"; break;
    case 104: key = "chooseImage"; break;
    case 105: key = "placement"; break;
    case 106: key = "glass"; value = [(NSSlider *)sender doubleValue]; break;
    case 120: key="logKeepUpdating";value=[(NSSwitch *)sender state]==NSControlStateValueOn;break;
    case 121: key="logWrapLines";value=[(NSSwitch *)sender state]==NSControlStateValueOn;break;
    case 114: key="prismConnection";value=true;break;
    case 111: key="themeChoice"; value=QString::fromUtf8([(NSPopUpButton *)sender titleOfSelectedItem].UTF8String); break;
    case 112: {
        NSColor *color=[[(NSColorWell *)sender color] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        key="customAccent";value=QColor::fromRgbF(color.redComponent,color.greenComponent,color.blueComponent).name();break;
    }
    case 113: key="sidebarGuide";break;
    case 110: key="instanceDefault"; value=[(NSSwitch *)sender state]==NSControlStateValueOn; break;
    case 108:
    case 109: {
        const bool instance=_lastState.value("page").toString()=="Instance";
        key=instance?"instanceMemory":"memory";
        const int limit=std::max(0,_lastState.value("memoryLimit").toInt());
        const int requested=tag==108 ? int(std::round([(NSSlider *)sender doubleValue]/128.0)*128) : int([(NSTextField *)sender integerValue]);
        const int clamped=std::max(std::min(512,limit),std::min(limit,requested));
        value=clamped;
        // Update only the number; never replace the field's material while dragging.
        PGMemoryPanel *panel=instance?self.instanceMemoryPanel:self.globalMemoryPanel;
        if(tag==108 && panel.field.currentEditor) [self.window makeFirstResponder:nil];
        panel.field.integerValue=clamped;
        NSText *editor=panel.field.currentEditor;
        if(editor) editor.string=[NSString stringWithFormat:@"%d",clamped];
        break;
    }
    case 107: key = "groupingMethod"; break;
    case 201: key = "provider"; break;
    case 202: {
        key = "query";
        NSSearchField *field = (NSSearchField *)sender;
        NSText *editor = field.currentEditor;
        value = QString::fromUtf8((editor ? editor.string : field.stringValue).UTF8String);
        break;
    }
    case 203: key = "refresh"; break;
    case 204: key = "loader"; break;
    case 205: key = "sort"; break;
    default:
        if (tag >= 210 && tag <= 214) { key = "category"; value = QString::fromUtf8([(NSButton *)sender title].UTF8String); }
    }
    if (tag == 103 || tag == 105 || tag == 107 || tag == 201 || tag == 204 || tag == 205)
        value = QString::fromUtf8([(NSPopUpButton *)sender titleOfSelectedItem].UTF8String);
    if (key) self.metrics->changePageControl(QString::fromLatin1(key), value);
}
@end
