#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#include <QQuickWindow>
#include <QPointer>
#include <QScreen>
#include <QUrl>
#include <QColor>
#include <QElapsedTimer>
#include <QQuickItem>
#include <QJSValue>
#include <QQuickItemGrabResult>
#include <cstring>
#include <memory>
#include <QDebug>
#include <QImage>
#include <QPainter>
#include <QPainterPath>
#include <QHash>
#include <QBuffer>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMetaObject>
#include <algorithm>
#include <cmath>
#include <vector>
#include <QJsonArray>
#include "MacWindowMetrics.h"

static NSColor *PGThemeAccent = nil;
static NSColor *PGAccent() { return PGThemeAccent ?: NSColor.controlAccentColor; }

// AppKit owns timing; one value updates both Qt content and native surfaces.
@interface PGSidebarAnimation : NSAnimation
@property(nonatomic, assign) MacWindowMetrics *metrics;
@property(nonatomic) CGFloat startValue;
@property(nonatomic) CGFloat endValue;
@end
@implementation PGSidebarAnimation
- (void)setCurrentProgress:(NSAnimationProgress)progress
{
    [super setCurrentProgress:progress];
    if (self.metrics)
        self.metrics->updateSidebarAnimationProgress(self.startValue +
            (self.endValue - self.startValue) * self.currentValue);
}
@end

static NSString *PGString(const QString &value)
{
    const QByteArray utf8 = value.toUtf8();
    return [[NSString alloc] initWithBytes:utf8.constData()
                                    length:static_cast<NSUInteger>(utf8.size())
                                  encoding:NSUTF8StringEncoding];
}

// Compact toolbar outline matching the supplied sidebar reference.
static NSImage *PGSidebarHeaderIcon()
{
    NSImage *image = [NSImage imageWithSize:NSMakeSize(20, 18) flipped:NO drawingHandler:^BOOL(NSRect rect) {
        Q_UNUSED(rect);
        [NSColor.labelColor setStroke];
        NSBezierPath *outline = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(1.5, 1.5, 17, 15) xRadius:2 yRadius:2];
        outline.lineWidth = 1.5;
        [outline stroke];
        NSBezierPath *bar = [NSBezierPath bezierPath];
        bar.lineWidth = 1.5;
        bar.lineCapStyle = NSLineCapStyleRound;
        [bar moveToPoint:NSMakePoint(5.5, 13.5)];
        [bar lineToPoint:NSMakePoint(14.5, 13.5)];
        [bar stroke];
        return YES;
    }];
    [image setTemplate:YES];
    return image;
}

// Opaque application backdrop: sidebar glass never samples the desktop.
@interface PGSidebarBackdrop : NSView
@property(nonatomic, strong) NSColor *backgroundColor;
@property(nonatomic, strong) NSGradient *colorGradient;
@property(nonatomic) CGFloat gradientAngle;
@property(nonatomic, strong) NSImage *wallpaper;
@property(nonatomic, copy) NSString *placement;
@property(nonatomic, strong) NSImage *sceneSnapshot;
@property(nonatomic, strong) NSImage *sceneHalo;
@property(nonatomic, assign) NSRect sceneFrame;
@property(nonatomic, assign) CGFloat sceneVisibleWidth;
@end
@implementation PGSidebarBackdrop
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return YES; }
- (void)drawRect:(NSRect)dirtyRect
{
    Q_UNUSED(dirtyRect);
    [(self.backgroundColor ?: [NSColor colorWithWhite:30.0 / 255.0 alpha:1]) setFill];
    NSRectFill(self.bounds);
    if(self.colorGradient)[self.colorGradient drawInRect:self.bounds angle:self.gradientAngle];
    NSImage *image = self.wallpaper;
    if (image && image.size.width > 0 && image.size.height > 0) {
    const NSSize size = image.size;
    const NSRect bounds = self.bounds;
    [NSGraphicsContext saveGraphicsState];
    NSRectClip(bounds);
    if ([self.placement isEqualToString:@"Tile"]) {
        for (CGFloat y = NSMinY(bounds); y < NSMaxY(bounds); y += size.height)
            for (CGFloat x = NSMinX(bounds); x < NSMaxX(bounds); x += size.width)
                [image drawInRect:NSMakeRect(x, y, size.width, size.height) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    } else {
        NSRect destination = bounds;
        if (![self.placement isEqualToString:@"Stretch"]) {
            CGFloat scale = 1;
            if ([self.placement isEqualToString:@"Fit"])
                scale = std::min(NSWidth(bounds) / size.width, NSHeight(bounds) / size.height);
            else if (![self.placement isEqualToString:@"Center"])
                scale = std::max(NSWidth(bounds) / size.width, NSHeight(bounds) / size.height);
            destination = NSMakeRect(NSMidX(bounds) - size.width * scale / 2,
                NSMidY(bounds) - size.height * scale / 2, size.width * scale, size.height * scale);
        }
        [image drawInRect:destination fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    }
    [NSGraphicsContext restoreGraphicsState];
    }
    if (self.sceneSnapshot && self.sceneVisibleWidth > 0) {
        [NSGraphicsContext saveGraphicsState];
        NSRectClip(NSMakeRect(0, 0, self.sceneVisibleWidth, NSHeight(self.bounds)));
        // Only a broad color field is extended; no mirrored card geometry.
        if (self.sceneHalo)
            [self.sceneHalo drawInRect:NSMakeRect(0, self.sceneFrame.origin.y, self.sceneVisibleWidth, self.sceneFrame.size.height)
                             fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
        [self.sceneSnapshot drawInRect:self.sceneFrame
                            fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
        [NSGraphicsContext restoreGraphicsState];
    }
}
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; [self setNeedsDisplay:YES]; }
@end

// All native surfaces use the same clear content layer and shadow policy.
static void PGApplyGlass(NSView *glass, CGFloat strength, bool sidebar = false, bool selected = false)
{
    if (!glass) return;
    glass.wantsLayer = YES;
    glass.layer.shadowOpacity = 0;
    glass.layer.shadowRadius = 0;
    glass.layer.shadowOffset = CGSizeZero;
    glass.layer.shadowColor = NSColor.clearColor.CGColor;
    NSView *content = [glass valueForKey:@"contentView"];
    content.wantsLayer = YES;
    NSString *appearance = [glass.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
    const BOOL dark = [appearance isEqualToString:NSAppearanceNameDarkAqua];
    NSVisualEffectView *frost = nil;
    for (NSView *view in content.subviews) {
        if ([view.identifier isEqualToString:@"PGGlobalFrost"]) { frost = (NSVisualEffectView *)view; break; }
    }
    if (sidebar && frost) { [frost removeFromSuperview]; frost = nil; }
    if (!sidebar && !frost) {
        frost = [[NSVisualEffectView alloc] initWithFrame:content.bounds];
        frost.identifier = @"PGGlobalFrost";
        frost.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        frost.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        frost.material = NSVisualEffectMaterialHUDWindow;
        frost.state = NSVisualEffectStateActive;
        [content addSubview:frost positioned:NSWindowBelow relativeTo:nil];
    }
    frost.alphaValue = std::min(1.0, strength * strength * 0.80 + (sidebar ? 0.18 : 0.0));
    content.layer.backgroundColor = [NSColor colorWithWhite:selected ? (dark ? 1.0 : 0.0) : (dark ? 0.08 : 1.0) alpha:selected ? 0.08 : strength * strength * 0.65].CGColor;
}

#include "NativePages.inc"
#include "NativeCanvas.inc"
#include "NativeDownloadRow.inc"
#include "NativeEditorRow.inc"

@interface PGAccountAction : NSObject {
@public QPointer<QObject> item;
}
- (void)activate:(id)sender;
@end
@implementation PGAccountAction
- (void)activate:(id)sender { Q_UNUSED(sender); if(item)QMetaObject::invokeMethod(item.data(),"nativeActivated",Qt::QueuedConnection); }
@end

@interface PGAccountGlassAttachment : NSObject
@property(nonatomic, weak) NSView *host;
@property(nonatomic, strong) NSView *glass;
@property(nonatomic, strong) NSView *backing;
@property(nonatomic, strong) NSMutableArray<NSView *> *controls;
@end
@implementation PGAccountGlassAttachment
@end

@interface PGDockArtworkView : NSView
@property(nonatomic,strong) NSImage *image;
@property(nonatomic,strong) NSColor *tint;
@property(nonatomic) BOOL defaultArtwork;
@end
@implementation PGDockArtworkView
- (void)drawRect:(NSRect)dirty {
    Q_UNUSED(dirty);
    [NSGraphicsContext saveGraphicsState];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:15 yRadius:15] addClip];
    [(self.tint?:NSColor.clearColor) setFill];NSRectFill(self.bounds);
    const NSSize size=self.image.size;
    if(size.width>0 && size.height>0) {
        const CGFloat factor=self.defaultArtwork?std::min(NSWidth(self.bounds),NSHeight(self.bounds))*0.65/std::max(size.width,size.height):std::max(NSWidth(self.bounds)/size.width,NSHeight(self.bounds)/size.height);
        NSRect imageRect=NSMakeRect((NSWidth(self.bounds)-size.width*factor)/2,(NSHeight(self.bounds)-size.height*factor)/2,size.width*factor,size.height*factor);
        [self.image drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES hints:nil];
    }
    [NSGraphicsContext restoreGraphicsState];
}
@end

@interface PGNativeGlassDockView : NSView <NSSearchFieldDelegate>
@property(nonatomic, assign) MacWindowMetrics *metrics;
@property(nonatomic,strong) PGDockArtworkView *instanceArtwork;
@property(nonatomic, strong) NSButton *primaryLaunchButton;
@property(nonatomic, strong) NSView *primaryLaunchGlass;
@property(nonatomic) BOOL downloadReadingActive;
@property(nonatomic, strong) NSView *glassView;
@property(nonatomic, strong) NSView *pickerGlass;
@property(nonatomic, strong) NSView *navigationGlass;
@property(nonatomic, strong) PGNativePageUI *pageUI;
@property(nonatomic,strong) PGCanvasCards *canvasCards;
@property(nonatomic, strong) PGScrollEdgeView *upperScrollEdge;
@property(nonatomic, strong) PGScrollEdgeView *lowerScrollEdge;
@property(nonatomic, strong) NSMutableArray<NSView *> *editorMaterials;
@property(nonatomic) BOOL pageUIInteractive;
@property(nonatomic, strong) NSView *accountButtonGlass;
@property(nonatomic) BOOL accountButtonInteractive;
@property(nonatomic) CGFloat sidebarWidth;
@property(nonatomic, strong) NSView *navigationSelectionGlass;
@property(nonatomic) NSInteger navigationSelectedTag;
@property(nonatomic, strong) NSView *sidebarButtonGlass;
@property(nonatomic, strong) NSView *searchButtonGlass;
@property(nonatomic, strong) NSButton *searchButton;
@property(nonatomic, strong) NSView *searchPanelGlass;
@property(nonatomic, strong) NSSearchField *nativeSearchField;
@property(nonatomic, strong) NSPopUpButton *nativeSort;
@property(nonatomic, strong) NSSlider *nativeZoom;
@property(nonatomic, strong) NSTextField *nativeZoomLabel;
@property(nonatomic, strong) NSButton *nativeReset;
- (void)searchControlChanged:(id)sender;
@property(nonatomic, strong) NSMutableArray<NSView *> *sidebarControlGlass;
@property(nonatomic, strong) NSView *sidebarGlass;
@property(nonatomic, strong) NSView *sidebarBackdrop;
@property(nonatomic, assign) CGFloat glassStrength;
- (void)applyGlassStrength:(CGFloat)strength;
- (void)applySidebarMaterial;
@property(nonatomic, strong) NSArray<NSButton *> *navigationButtons;
- (void)updateNavigation:(CGFloat)progress page:(NSString *)page contentHeight:(CGFloat)contentHeight;
- (void)navigationPressed:(id)sender;
- (void)updateInstanceMenu:(BOOL)open rows:(const QVariantList &)rows selected:(int)selected;
- (void)instanceRowPressed:(id)sender;
@property(nonatomic, strong) NSTextField *titleLabel;
@property(nonatomic, strong) NSTextField *versionLabel;
- (void)setDockTitle:(NSString *)title version:(NSString *)version
                   x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width
              height:(CGFloat)height radius:(CGFloat)radius;
- (void)instancePickerPressed:(id)sender;
- (void)launchPressed:(id)sender;
@end

@implementation PGNativeGlassDockView
{
    CGFloat _dockX;
    CGFloat _dockY;
    CGFloat _dockWidth;
    CGFloat _dockHeight;
    CGFloat _dockRadius;
}

- (BOOL)isFlipped
{
    // Keep the native overlay in the same top-left coordinate system as QML.
    return YES;
}

- (instancetype)initWithFrame:(NSRect)frame metrics:(MacWindowMetrics *)metrics
{
    self = [super initWithFrame:frame];
    if (!self) return nil;
    _metrics = metrics;
    self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    // Resolve the macOS 26 AppKit class dynamically so this source still
    // builds with older SDK headers; the real material is used when present.
    Class glassClass = NSClassFromString(@"NSGlassEffectView");
    if (!glassClass) return self;

    NSView *glass = [[glassClass alloc] initWithFrame:NSZeroRect];
    [glass setValue:@34.0 forKey:@"cornerRadius"];
    [glass setValue:@YES forKey:@"effectIsInteractive"];
    glass.wantsLayer = YES;
    glass.layer.shadowOpacity = 0.0;
    glass.layer.shadowRadius = 0.0;
    glass.layer.shadowOffset = CGSizeZero;
    glass.layer.shadowColor = NSColor.clearColor.CGColor;
    self.glassView = glass;

    NSView *content = [[NSView alloc] initWithFrame:NSZeroRect];
    content.wantsLayer = YES;
    content.layer.backgroundColor = NSColor.clearColor.CGColor;
    [glass setValue:content forKey:@"contentView"];

    PGDockArtworkView *iconTile=[[PGDockArtworkView alloc] initWithFrame:NSZeroRect];
    self.instanceArtwork=iconTile;
    iconTile.translatesAutoresizingMaskIntoConstraints=NO;
    NSButton *pickerButton = [NSButton buttonWithTitle:@"" target:self action:@selector(instancePickerPressed:)];
    pickerButton.bordered = NO;
    pickerButton.translatesAutoresizingMaskIntoConstraints = NO;
    [iconTile addSubview:pickerButton];
    [NSLayoutConstraint activateConstraints:@[
        [pickerButton.leadingAnchor constraintEqualToAnchor:iconTile.leadingAnchor],
        [pickerButton.trailingAnchor constraintEqualToAnchor:iconTile.trailingAnchor],
        [pickerButton.topAnchor constraintEqualToAnchor:iconTile.topAnchor],
        [pickerButton.bottomAnchor constraintEqualToAnchor:iconTile.bottomAnchor]
    ]];

    self.titleLabel = [NSTextField labelWithString:@"The Rebirth"];
    self.titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.titleLabel.textColor = NSColor.labelColor;
    self.titleLabel.font = [NSFont systemFontOfSize:15.0 weight:NSFontWeightSemibold];
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    self.versionLabel = [NSTextField labelWithString:@"Fabric 1.21.5"];
    self.versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.versionLabel.textColor = NSColor.secondaryLabelColor;
    self.versionLabel.font = [NSFont systemFontOfSize:11.0 weight:NSFontWeightRegular];
    self.versionLabel.lineBreakMode = NSLineBreakByTruncatingTail;

    NSStackView *labels = [[NSStackView alloc] init];
    [labels addArrangedSubview:self.titleLabel];
    [labels addArrangedSubview:self.versionLabel];
    labels.translatesAutoresizingMaskIntoConstraints = NO;
    labels.orientation = NSUserInterfaceLayoutOrientationVertical;
    labels.alignment = NSLayoutAttributeLeading;
    labels.distribution = NSStackViewDistributionFill;
    labels.spacing = 4.0;

    NSButton *launchButton = [NSButton buttonWithTitle:@"▶  Launch" target:self action:@selector(launchPressed:)];
    NSView *launchSurface=PGPageGlass(NSMakeRect(0,0,105,40),20);
    self.primaryLaunchGlass=launchSurface;
    launchSurface.translatesAutoresizingMaskIntoConstraints=NO;
    NSView *launchContent=[launchSurface valueForKey:@"contentView"];
    launchButton.frame=NSMakeRect(0,0,105,40);
    launchButton.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    [launchContent addSubview:launchButton];
    PGApplyGlass(launchSurface,self.glassStrength);
    self.primaryLaunchButton=launchButton;
    launchButton.bezelStyle = NSBezelStyleRounded;
    launchButton.bordered=NO;
    launchButton.contentTintColor=NSColor.labelColor;
    launchButton.controlSize = NSControlSizeRegular;
    launchButton.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold];

    [content addSubview:iconTile];
    [content addSubview:labels];
    [content addSubview:launchSurface];
    [NSLayoutConstraint activateConstraints:@[
        [iconTile.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:18.0],
        [iconTile.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [iconTile.widthAnchor constraintEqualToConstant:46.0],
        [iconTile.heightAnchor constraintEqualToConstant:46.0],
        [labels.leadingAnchor constraintEqualToAnchor:iconTile.trailingAnchor constant:16.0],
        [labels.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [labels.trailingAnchor constraintLessThanOrEqualToAnchor:launchSurface.leadingAnchor constant:-12.0],
        [launchSurface.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-14.0],
        [launchSurface.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [launchSurface.widthAnchor constraintEqualToConstant:105.0],
        [launchSurface.heightAnchor constraintEqualToConstant:40.0]
    ]];

    [self addSubview:glass];
    return self;
}

- (void)layout
{
    [super layout];
    if (!self.glassView) return;
    // Match sidebarAccountFooter: 68pt tall, 20pt above the bottom.
    // QML content excludes the titlebar; native bounds may include it.
    // Bottom anchoring avoids mixing those two vertical origins.
    self.glassView.frame = NSMakeRect(_dockX, NSMaxY(self.bounds) - 20.0 - _dockHeight,
                                     _dockWidth, _dockHeight);
    [self.glassView setValue:@(_dockRadius) forKey:@"cornerRadius"];
    if (self.pickerGlass) {
        const CGFloat h = NSHeight(self.pickerGlass.frame);
        self.pickerGlass.frame = NSMakeRect(_dockX, NSMinY(self.glassView.frame) - 12.0 - h,
                                           std::min(310.0, NSWidth(self.bounds) - 32.0), h);
    }
}

- (NSView *)hitTest:(NSPoint)point
{
    // AppKit supplies hitTest points in the superview coordinate system.
    const NSPoint local = [self convertPoint:point fromView:self.superview];
    if (self.hidden) return nil;
    if(self.pageUI && !self.pageUI.hidden && self.pageUIInteractive && self.pageUI.categoryScroll.superview==self && !self.pageUI.categoryScroll.hidden &&
       NSPointInRect(local,self.pageUI.categoryScroll.frame)) {
        NSView *categories=self.pageUI.categoryScroll;
        const NSPoint p=[categories convertPoint:local fromView:self];
        if(!categories.layer.mask || CGPathContainsPoint(((CAShapeLayer *)categories.layer.mask).path,nullptr,CGPointMake(p.x,p.y),false))
            return [categories hitTest:local];
    }
    if (self.accountButtonGlass && !self.accountButtonGlass.hidden && self.accountButtonGlass.alphaValue > 0.01 &&
        self.accountButtonInteractive && NSPointInRect(local, self.accountButtonGlass.frame))
        return [self.accountButtonGlass hitTest:local] ?: self;
    if (self.searchButtonGlass && !self.searchButtonGlass.hidden && NSPointInRect(local, self.searchButtonGlass.frame))
        return [self.searchButtonGlass hitTest:local] ?: self;
    if (self.searchPanelGlass && !self.searchPanelGlass.hidden && NSPointInRect(local, self.searchPanelGlass.frame))
        return [self.searchPanelGlass hitTest:local] ?: self;
    if (self.sidebarButtonGlass && !self.sidebarButtonGlass.hidden && NSPointInRect(local, self.sidebarButtonGlass.frame))
        return [self.sidebarButtonGlass hitTest:local] ?: self;
    if (self.navigationGlass && !self.navigationGlass.hidden && self.navigationGlass.alphaValue > 0.01 && NSPointInRect(local, self.navigationGlass.frame))
        return [self.navigationGlass hitTest:local] ?: self;
    if (self.pickerGlass && !self.pickerGlass.hidden && NSPointInRect(local, self.pickerGlass.frame))
        return [self.pickerGlass hitTest:local] ?: self;
    if (self.glassView && NSPointInRect(local,self.glassView.frame)) return self;
    if (self.pageUI && !self.pageUI.hidden && self.pageUIInteractive && NSPointInRect(local,self.pageUI.frame))
        return [self.pageUI hitTest:local];
    return nil;
}

- (void)mouseDown:(NSEvent *)event
{
    const NSPoint local = [self convertPoint:event.locationInWindow fromView:nil];
    // Glass backgrounds can bubble unhandled clicks to this full-window
    // overlay. Only clicks in the launch dock may invoke dock actions.
    if (!self.glassView || self.glassView.hidden ||
        !NSPointInRect(local, self.glassView.frame)) return;
    NSBezierPath *dockShape = [NSBezierPath bezierPathWithRoundedRect:self.glassView.frame
                                                                 xRadius:_dockRadius yRadius:_dockRadius];
    if (![dockShape containsPoint:local]) return;
    const CGFloat launchLeft = NSMaxX(self.glassView.frame) - 125.0;
    if (local.x >= launchLeft) [self launchPressed:self];
    else [self instancePickerPressed:self];
}

- (void)mouseUp:(NSEvent *)event { Q_UNUSED(event); }
- (void)rightMouseDown:(NSEvent *)event { Q_UNUSED(event); }
- (void)otherMouseDown:(NSEvent *)event { Q_UNUSED(event); }
- (void)scrollWheel:(NSEvent *)event { Q_UNUSED(event); }

- (void)applyGlassStrength:(CGFloat)strength
{
    self.glassStrength = strength;
    PGApplyGlass(self.primaryLaunchGlass,strength);
    [self.primaryLaunchGlass setValue:[PGAccent() colorWithAlphaComponent:0.42] forKey:@"tintColor"];
    self.primaryLaunchButton.contentTintColor=NSColor.labelColor;
    PGApplyGlass(self.glassView, strength);
    PGApplyGlass(self.navigationGlass, strength);
    PGApplyGlass(self.accountButtonGlass, strength);
    PGApplyGlass(self.navigationSelectionGlass, strength);
    PGApplyGlass(self.pickerGlass, strength);
    PGApplyGlass(self.sidebarButtonGlass, strength);
    PGApplyGlass(self.searchButtonGlass, strength);
    PGApplyGlass(self.searchPanelGlass, strength);
    for (NSView *control in self.sidebarControlGlass) PGApplyGlass(control, strength, false, [control.identifier isEqualToString:@"PGSelectedSidebar"]);
    [self applySidebarMaterial];
}
- (void)applySidebarMaterial {
    PGApplyGlass(self.sidebarGlass,self.glassStrength,true);
    if(self.downloadReadingActive && self.sidebarGlass && !self.sidebarGlass.hidden) {
        NSView *content=[self.sidebarGlass valueForKey:@"contentView"];
        const BOOL dark=[[self.sidebarGlass.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
        content.layer.backgroundColor=[NSColor colorWithWhite:dark?0.03:1.0 alpha:0.20+0.18*self.glassStrength].CGColor;
    }
}

- (void)updateNavigation:(CGFloat)progress page:(NSString *)page contentHeight:(CGFloat)contentHeight
{
    Q_UNUSED(contentHeight);
    if (!self.navigationGlass) {
        NSView *glass = [[NSClassFromString(@"NSGlassEffectView") alloc] initWithFrame:NSMakeRect(0, 0, 430, 56)];
        [glass setValue:@28.0 forKey:@"cornerRadius"];
        [glass setValue:@YES forKey:@"effectIsInteractive"];
        NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 430, 56)];
        [glass setValue:content forKey:@"contentView"];
        NSArray *titles = @[@"", @"Launch", @"Download", @"Settings", @""];
        NSMutableArray<NSButton *> *buttons = [NSMutableArray array];
        CGFloat x = 6;
        for (int i = 0; i < 5; ++i) {
            CGFloat width = (i == 0 || i == 4) ? 40 : 100;
            NSButton *button = [NSButton buttonWithTitle:titles[i] target:self action:@selector(navigationPressed:)];
            button.frame = NSMakeRect(x, 6, width, 44);
            button.tag = i;
            if (i == 0 || i == 4) {
                NSString *symbol = i == 0 ? @"sidebar.left" : @"magnifyingglass";
                button.image = [[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:i == 0 ? @"Show sidebar" : @"Search"]
                    imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:18 weight:NSFontWeightRegular]];
                button.imagePosition = NSImageOnly;
                button.contentTintColor = NSColor.labelColor;
            }
            button.bordered = NO;
            button.font = [NSFont systemFontOfSize:(i == 0 || i == 4) ? 23 : 13];
            button.wantsLayer = YES;
            button.layer.cornerRadius = 22;
            [content addSubview:button];
            [buttons addObject:button];
            x += width + 5;
        }
        self.navigationButtons = buttons;
        self.navigationGlass = glass;
        [self addSubview:glass];
    }
    const BOOL showSearch = [page isEqualToString:@"Launch"];
    const CGFloat navigationWidth = showSearch ? 412 : 367;
    self.navigationGlass.frame = NSMakeRect((NSWidth(self.bounds) - navigationWidth) / 2,
        14, navigationWidth, 56);
    NSView *navigationContent = [self.navigationGlass valueForKey:@"contentView"];
    navigationContent.frame = NSMakeRect(0, 0, navigationWidth, 56);
    CGFloat buttonX = 6;
    for (NSButton *button in self.navigationButtons) {
        const BOOL iconOnly = button.tag == 0 || button.tag == 4;
        const CGFloat width = iconOnly ? 40 : 100;
        button.frame = NSMakeRect(buttonX, iconOnly ? 8 : 6, width, iconOnly ? 40 : 44);
        button.hidden = button.tag == 4 && !showSearch;
        buttonX += width + 5;
    }
    if (!self.navigationSelectionGlass) {
        NSView *selection = [[NSClassFromString(@"NSGlassEffectView") alloc] initWithFrame:NSZeroRect];
        [selection setValue:@22.0 forKey:@"cornerRadius"];
        [selection setValue:@YES forKey:@"effectIsInteractive"];
        [selection setValue:[[NSView alloc] initWithFrame:NSZeroRect] forKey:@"contentView"];
        [navigationContent addSubview:selection positioned:NSWindowBelow relativeTo:nil];
        self.navigationSelectionGlass = selection;
        PGApplyGlass(selection, self.glassStrength);
    }
    PGApplyGlass(self.navigationGlass, self.glassStrength);
    if (self.sidebarGlass) {
        NSView *qtView = self.superview;
        PGSidebarBackdrop *backdrop = (PGSidebarBackdrop *)self.sidebarBackdrop;
        backdrop.sceneVisibleWidth = self.sidebarWidth * progress;
        [backdrop setNeedsDisplay:YES];
        self.sidebarBackdrop.frame = [qtView convertRect:qtView.bounds toView:qtView.superview];
        NSRect rect = qtView.bounds;
        rect.size.width = self.sidebarWidth;
        rect.origin.x -= self.sidebarWidth * (1 - progress);
        self.sidebarGlass.frame = [qtView convertRect:rect toView:qtView.superview];
        self.sidebarGlass.hidden = progress <= 0.001;
        self.sidebarGlass.alphaValue = std::min(1.0, progress * 1.7);
        [self applySidebarMaterial];
    }
    self.navigationGlass.hidden = progress >= 0.999;
    self.navigationGlass.alphaValue = 1.0 - progress;
    for (NSButton *button in self.navigationButtons) {
        button.enabled = progress < 0.15;
        const BOOL selected = button.tag > 0 && button.tag < 4 && [button.title isEqualToString:page];
        button.layer.backgroundColor = NSColor.clearColor.CGColor;
        if (selected && (self.navigationSelectedTag != button.tag || NSIsEmptyRect(self.navigationSelectionGlass.frame))) {
            self.navigationSelectedTag = button.tag;
            if (NSIsEmptyRect(self.navigationSelectionGlass.frame) ||
                NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion)
                self.navigationSelectionGlass.frame = button.frame;
            else {
                const NSRect destination = button.frame;
                [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
                    // Use the AppKit context default timing instead of a QML tween.
                    context.allowsImplicitAnimation = YES;
                    [[self.navigationSelectionGlass animator] setFrame:destination];
                } completionHandler:nil];
            }
        }
        if (button.tag > 0 && button.tag < 4) {
            NSString *appearance = [self.navigationGlass.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]];
            const BOOL dark = [appearance isEqualToString:NSAppearanceNameDarkAqua];
            NSColor *textColor = dark ? [NSColor colorWithWhite:selected ? 1.0 : 0.94 alpha:1]
                                      : [NSColor colorWithWhite:selected ? 0.02 : 0.14 alpha:1];
            NSFont *font = [NSFont systemFontOfSize:13 weight:selected ? NSFontWeightBold : NSFontWeightRegular];
            NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
            paragraph.alignment = NSTextAlignmentCenter;
            button.alignment = NSTextAlignmentCenter;
            button.attributedTitle = [[NSAttributedString alloc] initWithString:button.title attributes:@{
                NSFontAttributeName:font, NSForegroundColorAttributeName:textColor,
                NSParagraphStyleAttributeName:paragraph}];
        }
    }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command
{
    if(control==self.nativeSearchField && !textView.hasMarkedText &&
       (command==@selector(insertNewline:) || command==@selector(cancelOperation:))) {
        self.nativeSearchField.stringValue=textView.string;
        [self searchControlChanged:self.nativeSearchField];
        [self.window makeFirstResponder:nil];
        return YES;
    }
    return NO;
}
- (void)controlTextDidChange:(NSNotification *)notification
{
    if (notification.object == self.nativeSearchField) [self searchControlChanged:self.nativeSearchField];
}
- (void)searchControlChanged:(id)sender
{
    if (sender == self.nativeReset) {
        self.nativeSearchField.stringValue = @"";
        self.nativeZoom.doubleValue = 1;
    }
    self.nativeZoomLabel.stringValue = [NSString stringWithFormat:@"%.0f%%", self.nativeZoom.doubleValue * 100];
    const QString text = QString::fromUtf8(self.nativeSearchField.stringValue.UTF8String);
    const QString sort = QString::fromUtf8(self.nativeSort.titleOfSelectedItem.UTF8String);
    const qreal zoom = self.nativeZoom.doubleValue;
    MacWindowMetrics *metrics = self.metrics;
    if (metrics) QMetaObject::invokeMethod(metrics, [metrics, text, sort, zoom]() { metrics->updateSearchState(text, sort, zoom); }, Qt::QueuedConnection);
}

- (void)navigationPressed:(id)sender
{
    const int action = (int)[sender tag];
    MacWindowMetrics *metrics = self.metrics;
    if (metrics) QMetaObject::invokeMethod(metrics, [metrics, action]() { metrics->navigate(action); }, Qt::QueuedConnection);
}

- (void)updateInstanceMenu:(BOOL)open rows:(const QVariantList &)rows selected:(int)selected
{
    if (!open) { self.pickerGlass.hidden = YES; return; }
    if (self.pickerGlass) [self.pickerGlass removeFromSuperview];
    const CGFloat w = std::min(310.0, NSWidth(self.bounds) - 32.0);
    const CGFloat h = std::min(370.0, rows.size() * 58.0 + 56.0);
    NSView *glass = [[NSClassFromString(@"NSGlassEffectView") alloc] initWithFrame:NSMakeRect(_dockX, NSMinY(self.glassView.frame) - 12.0 - h, w, h)];
    [glass setValue:@24.0 forKey:@"cornerRadius"];
    [glass setValue:@YES forKey:@"effectIsInteractive"];
    NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, w, h)];
    [glass setValue:content forKey:@"contentView"];
    NSTextField *heading = [NSTextField labelWithString:@"INSTANCES  ·  SCROLL TO BROWSE"];
    heading.frame = NSMakeRect(18, h - 32, w - 36, 18);
    heading.font = [NSFont systemFontOfSize:10];
    heading.textColor = NSColor.secondaryLabelColor;
    [content addSubview:heading];
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSMakeRect(10, 10, w - 20, h - 48)];
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    const CGFloat documentHeight = std::max(h - 48, rows.size() * 58.0);
    NSView *document = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, w - 20, documentHeight)];
    NSButton *selectedButton = nil;
    for (int i = 0; i < rows.size(); ++i) {
        const QVariantMap row = rows[i].toMap();
        NSString *title = [NSString stringWithFormat:@"%@  %@\n     %@", row.value("installed").toBool() ? @"◆" : @"↓", PGString(row.value("label").toString()), PGString(row.value("version").toString())];
        NSButton *button = [NSButton buttonWithTitle:title target:self action:@selector(instanceRowPressed:)];
        button.frame = NSMakeRect(0, documentHeight - (i + 1) * 58, w - 24, 54);
        button.tag = i;
        button.bordered = NO;
        button.alignment = NSTextAlignmentLeft;
        button.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        button.cell.wraps = YES;
        button.wantsLayer = YES;
        button.layer.cornerRadius = 14;
        if (i == selected) {
            button.layer.backgroundColor = [PGAccent() colorWithAlphaComponent:0.25].CGColor;
            selectedButton = button;
        }
        [document addSubview:button];
    }
    scroll.documentView = document;
    [content addSubview:scroll];
    [self addSubview:glass];
    self.pickerGlass = glass;
    PGApplyGlass(glass, self.glassStrength);
    if (selectedButton) [document scrollRectToVisible:selectedButton.frame];
    else [document scrollPoint:NSMakePoint(0, documentHeight)];
}

- (void)instanceRowPressed:(id)sender
{
    const int index = (int)[sender tag];
    MacWindowMetrics *metrics = self.metrics;
    if (metrics) QMetaObject::invokeMethod(metrics, [metrics, index]() { metrics->chooseInstance(index); }, Qt::QueuedConnection);
}

- (void)setDockTitle:(NSString *)title version:(NSString *)version
                   x:(CGFloat)x y:(CGFloat)y width:(CGFloat)width
              height:(CGFloat)height radius:(CGFloat)radius
{
    self.titleLabel.stringValue = title ?: @"";
    self.versionLabel.stringValue = version ?: @"";
    _dockX = x;
    _dockY = y;
    _dockWidth = width;
    _dockHeight = height;
    _dockRadius = radius;
    [self setNeedsLayout:YES];
}

- (void)instancePickerPressed:(id)sender
{
    Q_UNUSED(sender);
    if (self.metrics) QMetaObject::invokeMethod(self.metrics, "requestInstancePicker", Qt::QueuedConnection);
}

- (void)launchPressed:(id)sender
{
    Q_UNUSED(sender);
    if (self.metrics) QMetaObject::invokeMethod(self.metrics, "requestLaunch", Qt::QueuedConnection);
}
@end

void configureMacWindow(QQuickWindow *window, MacWindowMetrics *metrics)
{
    if (!window) return;
    NSView *qtView = (__bridge NSView *)(reinterpret_cast<void *>(window->winId()));
    if (!qtView) return;
    NSWindow *nativeWindow = qtView.window;
    if (!nativeWindow) return;

    nativeWindow.styleMask |= NSWindowStyleMaskFullSizeContentView;
    nativeWindow.titleVisibility = NSWindowTitleHidden;
    nativeWindow.titlebarAppearsTransparent = YES;
    nativeWindow.movableByWindowBackground = NO;

    // macOS 26's NSGlassEffectView is the real Liquid Glass material. Place a
    // native launch dock over the Qt dock and let the QML layer keep handling
    // the instance picker and launch state through two small bridge signals.
    if (@available(macOS 26.0, *)) {
        Class glassClass = NSClassFromString(@"NSGlassEffectView");
        if (glassClass) {
            PGNativeGlassDockView *dock = [[PGNativeGlassDockView alloc] initWithFrame:qtView.bounds metrics:metrics];
            [qtView addSubview:dock positioned:NSWindowAbove relativeTo:nil];
            metrics->setDockInfoUpdater([dock, window](const QString &title, const QString &version,
                                                       qreal x, qreal y, qreal width,
                                                       qreal height, qreal radius) {
                [dock setDockTitle:PGString(title) version:PGString(version)
                                  x:x y:y width:width height:height radius:radius];
                [dock layoutSubtreeIfNeeded];
            });
            metrics->setInstanceMenuUpdater([dock](bool open, const QVariantList &rows, int selected) {
                [dock updateInstanceMenu:open rows:rows selected:selected];
            });
            PGSidebarAnimation *sidebarAnimation = [[PGSidebarAnimation alloc]
                initWithDuration:0.25 animationCurve:NSAnimationEaseInOut];
            sidebarAnimation.animationBlockingMode = NSAnimationNonblocking;
            sidebarAnimation.frameRate = 0; // AppKit chooses the frame rate.
            sidebarAnimation.metrics = metrics;
            metrics->setSidebarAnimationUpdater([sidebarAnimation, metrics](bool open, bool immediate) {
                [sidebarAnimation stopAnimation];
                const CGFloat destination = open ? 1.0 : 0.0;
                if (immediate || NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
                    metrics->updateSidebarAnimationProgress(destination);
                    return;
                }
                sidebarAnimation.startValue = metrics->sidebarAnimationProgress();
                sidebarAnimation.endValue = destination;
                if (std::abs(sidebarAnimation.startValue - destination) < 0.0001) return;
                sidebarAnimation.currentProgress = 0;
                [sidebarAnimation startAnimation];
            });
            QObject::connect(window, &QObject::destroyed, QCoreApplication::instance(), [sidebarAnimation]() {
                [sidebarAnimation stopAnimation];
                sidebarAnimation.metrics = nullptr;
            });
            if (qtView.superview) {
                nativeWindow.opaque = YES;
                nativeWindow.backgroundColor = NSColor.windowBackgroundColor;
                PGSidebarBackdrop *backdrop = [[PGSidebarBackdrop alloc] initWithFrame:[qtView convertRect:qtView.bounds toView:qtView.superview]];
                [qtView.superview addSubview:backdrop positioned:NSWindowBelow relativeTo:qtView];
                dock.sidebarBackdrop = backdrop;
                NSView *sidebarGlass = [[glassClass alloc] initWithFrame:NSZeroRect];
                [sidebarGlass setValue:@0.0 forKey:@"cornerRadius"];
                [sidebarGlass setValue:@YES forKey:@"effectIsInteractive"];
                [sidebarGlass setValue:[[NSView alloc] initWithFrame:NSZeroRect] forKey:@"contentView"];
                sidebarGlass.hidden = YES;
                [qtView.superview addSubview:sidebarGlass positioned:NSWindowAbove relativeTo:backdrop];
                dock.sidebarGlass = sidebarGlass;
                metrics->setNativeSidebar(true);
            }
            // Capture only the background/card scene, never sidebar controls or
            // glass. Follow rendered frames rather than a fixed-frequency timer.
            // One capture in flight prevents a queue of stale images.
            auto sceneCaptureBusy = std::make_shared<bool>(false);
            auto haloHistory = std::make_shared<QImage>();
            auto haloClock = std::make_shared<QElapsedTimer>();
            haloClock->start();
            QObject::connect(window, &QQuickWindow::frameSwapped, window, [dock, window, sceneCaptureBusy, haloHistory, haloClock]() {
                // Launch cards now pass physically behind sidebarGlass. A second
                // raster copy would duplicate them at a different capture time.
                if(window->property("activePage").toString()==QStringLiteral("Launch")) {
                    PGSidebarBackdrop *backdrop=(PGSidebarBackdrop *)dock.sidebarBackdrop;
                    if(backdrop.sceneSnapshot || backdrop.sceneHalo){backdrop.sceneSnapshot=nil;backdrop.sceneHalo=nil;[backdrop setNeedsDisplay:YES];}
                    return;
                }
                if (!window->isVisible() || window->visibility() == QWindow::Minimized ||
                    !dock.sidebarGlass || dock.sidebarGlass.hidden || *sceneCaptureBusy) return;
                auto *scene = window->findChild<QQuickItem *>(QStringLiteral("sidebarSceneSource"));
                if (!scene || scene->width() <= 0 || scene->height() <= 0) return;
                // Freeze the native contribution at the same point as the Qt grab.
                const QPointF sceneOrigin=scene->mapToScene(QPointF());
                const QSizeF sceneSize(scene->width(),scene->height());
                const QSize captureSize(qMax(1,qRound(sceneSize.width()/2)),qMax(1,qRound(sceneSize.height()/2)));
                QImage nativeCards(captureSize,QImage::Format_RGBA8888_Premultiplied);nativeCards.fill(Qt::transparent);
                [dock.canvasCards compositeScene:nativeCards origin:sceneOrigin size:sceneSize];
                auto capture = scene->grabToImage(captureSize);
                if (!capture) return;
                *sceneCaptureBusy = true;
                const NSRect sceneFrame=[dock convertRect:NSMakeRect(sceneOrigin.x(),sceneOrigin.y(),sceneSize.width(),sceneSize.height()) toView:dock.sidebarBackdrop];
                QObject::connect(capture.data(), &QQuickItemGrabResult::ready, window,
                    [capture, dock, window, sceneCaptureBusy, sceneFrame, nativeCards, haloHistory, haloClock]() {
                        QImage image = capture->image().convertToFormat(QImage::Format_RGBA8888_Premultiplied);
                        if(!image.isNull()){QPainter painter(&image);painter.drawImage(image.rect(),nativeCards);}
                        if (image.isNull()) {
                            *sceneCaptureBusy = false;
                            QObject::disconnect(capture.data(), nullptr, window, nullptr);
                            return;
                        }
                        NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc]
                            initWithBitmapDataPlanes:nullptr pixelsWide:image.width() pixelsHigh:image.height()
                            bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
                            colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:image.width() * 4 bitsPerPixel:32];
                        if (bitmap) {
                            for (int row = 0; row < image.height(); ++row)
                                std::memcpy(bitmap.bitmapData + row * bitmap.bytesPerRow,
                                            image.constScanLine(row), image.width() * 4);
                            NSImage *snapshot = [[NSImage alloc] initWithSize:NSMakeSize(image.width(), image.height())];
                            [snapshot addRepresentation:bitmap];
                            ((PGSidebarBackdrop *)dock.sidebarBackdrop).sceneSnapshot = snapshot;
                        }
                        PGSidebarBackdrop *backdrop = (PGSidebarBackdrop *)dock.sidebarBackdrop;
                        if (!image.isNull()) {
                        // Eight broad area averages retain only large color masses.
                        // No individual pixel or card-edge crossing controls the glow.
                        const qreal scale = image.width() / std::max(1.0, NSWidth(sceneFrame));
                        const qreal edge = backdrop.sceneVisibleWidth;
                        QImage bands(1, 8, QImage::Format_RGBA8888_Premultiplied);
                        bands.fill(Qt::transparent);
                        for (int band = 0; band < 8; ++band) {
                            const int centerY = qRound((band + 0.5) * image.height() / 8.0);
                            const int spread = qMax(qRound(85 * scale), image.height() / 8);
                            const QRect area(qRound((edge-NSMinX(sceneFrame)) * scale), centerY - spread,
                                             qMax(1, qRound(340 * scale)), spread * 2);
                            const QRect clipped = area.intersected(image.rect());
                            if (!clipped.isEmpty()) {
                                const QImage average = image.copy(clipped).scaled(1, 1, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
                                QColor color = average.pixelColor(0, 0);
                                color.setAlphaF(color.alphaF() * 0.78);
                                bands.setPixelColor(0, band, color);
                            }
                        }
                        const QImage vertical = bands.scaled(1, 64, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
                        QImage halo(64, 64, QImage::Format_RGBA8888_Premultiplied);
                        halo.fill(Qt::transparent);
                        for (int row = 0; row < 64; ++row) {
                            for (int column = 0; column < 64; ++column) {
                                QColor color = vertical.pixelColor(0, row);
                                const qreal distance = (63 - column) * edge / 64.0;
                                color.setAlphaF(color.alphaF() * std::exp(-distance / 140.0));
                                halo.setPixelColor(column, row, color);
                            }
                        }
                        // Smooth premultiplied color and opacity together using time,
                        // so the response stays consistent at different frame rates.
                        const qreal dt = qBound(0.001, haloClock->restart() / 1000.0, 0.25);
                        const qreal blend = 1.0 - std::exp(-dt / 0.18);
                        if (!haloHistory->isNull()) {
                            for (int y = 0; y < 64; ++y) for (int x = 0; x < 64; ++x) {
                                const QRgb old = haloHistory->pixel(x, y);
                                const QRgb next = halo.pixel(x, y);
                                auto mix = [blend](int a, int b) { return qRound(a + (b - a) * blend); };
                                halo.setPixel(x, y, qRgba(mix(qRed(old), qRed(next)), mix(qGreen(old), qGreen(next)),
                                                        mix(qBlue(old), qBlue(next)), mix(qAlpha(old), qAlpha(next))));
                            }
                        }
                        *haloHistory = halo;
                        NSBitmapImageRep *haloBitmap = [[NSBitmapImageRep alloc]
                            initWithBitmapDataPlanes:nullptr pixelsWide:64 pixelsHigh:64
                            bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO
                            colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:256 bitsPerPixel:32];
                        if (haloBitmap) {
                            for (int row = 0; row < 64; ++row)
                                std::memcpy(haloBitmap.bitmapData + row * haloBitmap.bytesPerRow, halo.constScanLine(row), 256);
                            NSImage *haloImage = [[NSImage alloc] initWithSize:NSMakeSize(64, 64)];
                            [haloImage addRepresentation:haloBitmap];
                            backdrop.sceneHalo = haloImage;
                        }
                        }
                        backdrop.sceneFrame = sceneFrame;
                        backdrop.sceneSnapshot=nil;backdrop.sceneHalo=nil;
                [backdrop setNeedsDisplay:YES];[backdrop.superview setNeedsDisplay:YES];window->update();
                        *sceneCaptureBusy = false;
                        QObject::disconnect(capture.data(), nullptr, window, nullptr);
                    });
            }, Qt::QueuedConnection);
            metrics->setSidebarControlsUpdater([dock, qtView](const QVariantList &rows) {
                if (!dock.sidebarControlGlass) dock.sidebarControlGlass = [NSMutableArray array];
                for (int i = 0; i < rows.size(); ++i) {
                    NSView *glass = nil;
                    if (i < dock.sidebarControlGlass.count) glass = dock.sidebarControlGlass[i];
                    else {
                        glass = [[NSClassFromString(@"NSGlassEffectView") alloc] initWithFrame:NSZeroRect];
                        [glass setValue:@YES forKey:@"effectIsInteractive"];
                        [glass setValue:[[NSView alloc] initWithFrame:NSZeroRect] forKey:@"contentView"];
                        [qtView.superview addSubview:glass positioned:NSWindowBelow relativeTo:qtView];
                        [dock.sidebarControlGlass addObject:glass];
                    }
                    const QVariantMap row = rows[i].toMap();
                    const NSRect rect = NSMakeRect(row.value("x").toDouble(), row.value("y").toDouble(),
                        row.value("width").toDouble(), row.value("height").toDouble());
                    glass.frame = [dock convertRect:rect toView:qtView.superview];
                    [glass setValue:@(std::min(row.value("radius").toDouble(), NSHeight(rect) / 2)) forKey:@"cornerRadius"];
                    const QString role = row.value("role").toString();
                    const bool active = row.value("active").toBool();
                    // Sidebar is one glass surface; rows gain a capsule only
                    // when selected. Keep panels and input fields distinct.
                    glass.hidden = !(active || role == "panel" || role == "account" || role == "avatar" || role == "field");
                    glass.alphaValue = row.value("opacity").toDouble();
                    glass.identifier=active?@"PGSelectedSidebar":@"PGSidebarRow";
                    PGApplyGlass(glass, dock.glassStrength, false, active);
                }
                for (NSUInteger i = rows.size(); i < dock.sidebarControlGlass.count; ++i)
                    dock.sidebarControlGlass[i].hidden = YES;
            });
            metrics->setSearchPanelUpdater([dock, nativeWindow](qreal x, qreal y, qreal width, qreal height, qreal opacity,
                bool visible, const QString &text, const QString &sort, qreal zoom) {
                if (!dock.searchPanelGlass) {
                    NSView *glass = [[NSClassFromString(@"NSGlassEffectView") alloc] initWithFrame:NSZeroRect];
                    [glass setValue:@20.0 forKey:@"cornerRadius"];
                    [glass setValue:@YES forKey:@"effectIsInteractive"];
                    NSView *content = [[NSView alloc] initWithFrame:NSZeroRect];
                    [glass setValue:content forKey:@"contentView"];
                    NSSearchField *field = [[NSSearchField alloc] initWithFrame:NSZeroRect];
                    field.placeholderString = @"Search versions…";
                    field.delegate = dock;
                    field.target = dock;
                    field.action = @selector(searchControlChanged:);
                    field.sendsSearchStringImmediately = YES;
                    NSPopUpButton *sortButton = [[PGGlassPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
                    [sortButton addItemsWithTitles:@[@"Off", @"Smart", @"Minecraft version", @"Mod loader", @"Installed status", @"Custom"]];
                    sortButton.bordered=NO;
                    sortButton.target = dock; sortButton.action = @selector(searchControlChanged:);
                    NSSlider *slider = [NSSlider sliderWithValue:1 minValue:0.55 maxValue:1.65 target:dock action:@selector(searchControlChanged:)];
                    slider.continuous = YES;
                    NSTextField *label = [NSTextField labelWithString:@"100%"];
                    label.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
                    label.usesSingleLineMode = YES;
                    label.alignment = NSTextAlignmentCenter;
                    NSButton *reset = [NSButton buttonWithTitle:@"Reset" target:dock action:@selector(searchControlChanged:)];
                    reset.bezelStyle = NSBezelStyleRounded;
                    for (NSView *view in @[field, sortButton, slider, label, reset]) [content addSubview:view];
                    dock.nativeSearchField = field; dock.nativeSort = sortButton;
                    dock.nativeZoom = slider; dock.nativeZoomLabel = label; dock.nativeReset = reset;
                    glass.hidden = YES;
                    [dock addSubview:glass positioned:NSWindowBelow relativeTo:dock.searchButtonGlass];
                    dock.searchPanelGlass = glass;
                    PGApplyGlass(glass, dock.glassStrength);
                }
                const BOOL opening = dock.searchPanelGlass.hidden && visible;
                dock.searchPanelGlass.frame = NSMakeRect(x, y, width, height);
                NSView *content = [dock.searchPanelGlass valueForKey:@"contentView"];
                content.frame = NSMakeRect(0, 0, width, height);
                const CGFloat fieldWidth = std::max(80.0, width - 366.0);
                CGFloat offset = 12;
                dock.nativeSearchField.frame = NSMakeRect(offset, (height - 28) / 2, fieldWidth, 28); offset += fieldWidth + 6;
                dock.nativeSort.frame = NSMakeRect(offset, (height - 28) / 2, 140, 28); offset += 146;
                dock.nativeZoom.frame = NSMakeRect(offset, (height - 24) / 2, 72, 24); offset += 78;
                const CGFloat percentHeight = std::ceil(dock.nativeZoomLabel.cell.cellSize.height);
                dock.nativeZoomLabel.frame = NSMakeRect(offset, (height - percentHeight) / 2, 42, percentHeight); offset += 48;
                dock.nativeReset.frame = NSMakeRect(offset, (height - 28) / 2, 64, 28);
                if (![dock.nativeSearchField.stringValue isEqualToString:PGString(text)]) dock.nativeSearchField.stringValue = PGString(text);
                [dock.nativeSort selectItemWithTitle:PGString(sort)];
                dock.nativeZoom.doubleValue = zoom;
                dock.nativeZoomLabel.stringValue = [NSString stringWithFormat:@"%.0f%%", zoom * 100];
                dock.searchPanelGlass.hidden = !visible;
                dock.searchPanelGlass.alphaValue = opacity;
                if (opening) [nativeWindow makeFirstResponder:dock.nativeSearchField];
            });
            metrics->setSearchButtonUpdater([dock](qreal x, qreal y, qreal size, qreal opacity, bool visible, bool expanded) {
                if (!dock.searchButtonGlass) {
                    NSView *glass = [[NSClassFromString(@"NSGlassEffectView") alloc] initWithFrame:NSZeroRect];
                    [glass setValue:@YES forKey:@"effectIsInteractive"];
                    NSView *content = [[NSView alloc] initWithFrame:NSZeroRect];
                    [glass setValue:content forKey:@"contentView"];
                    NSButton *button = [NSButton buttonWithTitle:@"" target:dock action:@selector(navigationPressed:)];
                    button.tag = 4;
                    button.bordered = NO;
                    button.imagePosition = NSImageOnly;
                    button.contentTintColor = NSColor.labelColor;
                    button.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
                    [content addSubview:button];
                    [dock addSubview:glass];
                    dock.searchButtonGlass = glass;
                    dock.searchButton = button;
                    PGApplyGlass(glass, dock.glassStrength);
                }
                dock.searchButtonGlass.frame = NSMakeRect(x, y, size, size);
                [dock.searchButtonGlass setValue:@(size / 2) forKey:@"cornerRadius"];
                NSView *content = [dock.searchButtonGlass valueForKey:@"contentView"];
                content.frame = NSMakeRect(0, 0, size, size);
                dock.searchButton.frame = content.bounds;
                NSString *symbol = expanded ? @"xmark" : @"magnifyingglass";
                dock.searchButton.image = [[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:expanded ? @"Close search" : @"Search"]
                    imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:18 weight:NSFontWeightRegular]];
                dock.searchButtonGlass.hidden = !visible;
                dock.searchButtonGlass.alphaValue = opacity;
            });
            metrics->setSidebarButtonUpdater([dock](qreal x, qreal y, qreal progress, qreal contentHeight) {
                if (!dock.sidebarButtonGlass) {
                    NSView *glass = [[NSClassFromString(@"NSGlassEffectView") alloc] initWithFrame:NSMakeRect(0, 0, 40, 40)];
                    [glass setValue:@20.0 forKey:@"cornerRadius"];
                    [glass setValue:@YES forKey:@"effectIsInteractive"];
                    NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 40, 40)];
                    [glass setValue:content forKey:@"contentView"];
                    NSButton *button = [NSButton buttonWithTitle:@"" target:dock action:@selector(navigationPressed:)];
                    button.frame = NSMakeRect(0, 0, 40, 40);
                    button.tag = 5;
                    button.bordered = NO;
                    button.image = PGSidebarHeaderIcon();
                    button.imagePosition = NSImageOnly;
                    button.contentTintColor = NSColor.labelColor;
                    [content addSubview:button];
                    [dock addSubview:glass];
                    dock.sidebarButtonGlass = glass;
                    PGApplyGlass(glass, dock.glassStrength);
                }
                dock.sidebarButtonGlass.frame = NSMakeRect(x, y, 40, 40);
                dock.sidebarButtonGlass.hidden = progress <= 0.001;
                dock.sidebarButtonGlass.alphaValue = std::min(1.0, progress * 1.7);
            });
            metrics->setBackgroundUpdater([dock,window](const QString &mode, const QString &source, const QString &placement) {
                PGSidebarBackdrop *backdrop = (PGSidebarBackdrop *)dock.sidebarBackdrop;
                backdrop.backgroundColor = mode == "White" ? NSColor.whiteColor : mode == "Black" ? NSColor.blackColor : [NSColor colorWithWhite:30.0 / 255.0 alpha:1];
                backdrop.colorGradient=nil;
                if(mode=="Custom color") {
                    auto config=QJsonDocument::fromJson(source.toUtf8()).object();
                    QColor start(config.value("start").toString()),end(config.value("end").toString());
                    if(start.isValid())backdrop.backgroundColor=[NSColor colorWithSRGBRed:start.redF() green:start.greenF() blue:start.blueF() alpha:1];
                    if(config.value("gradient").toBool() && end.isValid()) {
                        NSColor *finish=[NSColor colorWithSRGBRed:end.redF() green:end.greenF() blue:end.blueF() alpha:1];
                        auto stops=config.value("stops").toArray().toVariantList();
                        std::stable_sort(stops.begin(),stops.end(),[](const QVariant &a,const QVariant &b){return a.toMap().value("position").toDouble()<b.toMap().value("position").toDouble();});
                        NSMutableArray *colors=[NSMutableArray array];std::vector<CGFloat> locations;
                        for(auto entry:stops){auto stop=entry.toMap();QColor c(stop.value("color").toString());if(!c.isValid())continue;[colors addObject:[NSColor colorWithSRGBRed:c.redF() green:c.greenF() blue:c.blueF() alpha:1]];locations.push_back(std::clamp(stop.value("position").toDouble(),0.0,1.0));}
                        if(colors.count>=2)backdrop.colorGradient=[[NSGradient alloc] initWithColors:colors atLocations:locations.data() colorSpace:NSColorSpace.sRGBColorSpace];
                        else backdrop.colorGradient=[[NSGradient alloc] initWithStartingColor:backdrop.backgroundColor endingColor:finish];
                        backdrop.gradientAngle=config.value("angle").toDouble();
                    }
                }
                backdrop.placement = PGString(placement);
                backdrop.wallpaper = mode == "Custom" && !source.isEmpty() ? [[NSImage alloc] initWithContentsOfFile:PGString(QUrl(source).toLocalFile())] : nil;
                [backdrop setNeedsDisplay:YES];
            });
            metrics->setGlassStrengthUpdater([dock](qreal strength) { [dock applyGlassStrength:strength]; });
            metrics->setDeleteConfirmationHandler([metrics,nativeWindow,dock]() {
                QPointer<MacWindowMetrics> guarded(metrics);
                NSAlert *alert=[[NSAlert alloc] init];
                alert.messageText=@"Delete instance configuration?";
                alert.informativeText=@"The launcher configuration will be removed. Referenced files are kept.";
                alert.alertStyle=NSAlertStyleWarning;
                [alert addButtonWithTitle:@"Cancel"];
                NSButton *deleteButton=[alert addButtonWithTitle:@"Delete"];
                deleteButton.hasDestructiveAction=YES;
                NSView *content=alert.window.contentView;
                NSView *glass=PGPageGlass(content.bounds,24);
                glass.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
                PGApplyGlass(glass,std::max(0.75,dock.glassStrength));
                [content addSubview:glass positioned:NSWindowBelow relativeTo:nil];
                [alert beginSheetModalForWindow:nativeWindow completionHandler:^(NSModalResponse response) {
                    if(guarded && response==NSAlertSecondButtonReturn)emit guarded->deletionConfirmed();
                }];
            });
            metrics->setThemeAccentUpdater([dock](const QString &hex) {
                QColor color(hex); if(!color.isValid())return;
                PGThemeAccent=[NSColor colorWithSRGBRed:color.redF() green:color.greenF() blue:color.blueF() alpha:1];
                [dock applyGlassStrength:dock.glassStrength];
            });
            metrics->setSystemAccentReader([]() {
                NSColor *color=[NSColor.controlAccentColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
                return QColor::fromRgbF(color.redComponent,color.greenComponent,color.blueComponent).name();
            });
            metrics->setSymbolIconReader([](const QString &name,const QString &hex) {
                if(name==QStringLiteral("appkit.selector")) {
                    NSImage *symbol=[[NSImage imageWithSystemSymbolName:@"chevron.up.chevron.down" accessibilityDescription:nil]
                        imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:11 weight:NSFontWeightSemibold]];
                    if(!symbol)return QString();
                    QColor tint(hex);if(!tint.isValid())return QString();
                    NSImage *image=[[NSImage alloc] initWithSize:NSMakeSize(16,16)];
                    const NSSize natural=symbol.size;
                    const CGFloat scale=std::min(12.0/natural.width,12.0/natural.height);
                    NSRect rect=NSMakeRect((16-natural.width*scale)/2,(16-natural.height*scale)/2,natural.width*scale,natural.height*scale);
                    [image lockFocus];[symbol drawInRect:rect];
                    [[NSColor colorWithSRGBRed:tint.redF() green:tint.greenF() blue:tint.blueF() alpha:1] setFill];
                    NSRectFillUsingOperation(NSMakeRect(0,0,16,16),NSCompositingOperationSourceAtop);[image unlockFocus];
                    NSBitmapImageRep *bitmap=[NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
                    NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                    return QStringLiteral("data:image/png;base64,")+QString::fromLatin1([[png base64EncodedStringWithOptions:0] UTF8String]);
                }
                if(name==QStringLiteral("appkit.disclosure.open") || name==QStringLiteral("appkit.disclosure.closed")) {
                    // Ask AppKit to paint its standard disclosure cell at its
                    // intrinsic size. This avoids stretching a chevron glyph.
                    QColor tint(hex);
                    NSAppearance *appearance=[NSAppearance appearanceNamed:
                        tint.lightnessF()>0.5?NSAppearanceNameDarkAqua:NSAppearanceNameAqua];
                    const BOOL expanded=name==QStringLiteral("appkit.disclosure.open");
                    NSButton *button=[[NSButton alloc] initWithFrame:NSZeroRect];
                    button.title=@"";button.bezelStyle=NSBezelStyleDisclosure;
                    [button setButtonType:NSButtonTypePushOnPushOff];
                    button.controlSize=NSControlSizeSmall;
                    button.appearance=appearance;
                    button.state=expanded?NSControlStateValueOn:NSControlStateValueOff;
                    [button sizeToFit];
                    NSSize size=button.frame.size;
                    if(size.width<=0 || size.height<=0)return QString();
                    const NSSize canvas=NSMakeSize(std::max(16.0,size.width),std::max(16.0,size.height));
                    NSImage *image=[[NSImage alloc] initWithSize:canvas];
                    [appearance performAsCurrentDrawingAppearance:^{
                        [image lockFocus];
                        [button.cell drawWithFrame:NSMakeRect((canvas.width-size.width)/2,(canvas.height-size.height)/2,size.width,size.height) inView:button];
                        [image unlockFocus];
                    }];
                    NSBitmapImageRep *bitmap=[NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
                    NSData *png=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                    return QStringLiteral("data:image/png;base64,")+QString::fromLatin1([[png base64EncodedStringWithOptions:0] UTF8String]);
                }
                NSImage *symbol=[NSImage imageWithSystemSymbolName:PGString(name) accessibilityDescription:nil];
                if(!symbol)return QString();
                QColor color(hex); if(!color.isValid())return QString();
                NSImage *image=[[NSImage alloc] initWithSize:NSMakeSize(24,24)];
                [image lockFocus];
                [symbol drawInRect:NSMakeRect(2,2,20,20) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];
                [[NSColor colorWithSRGBRed:color.redF() green:color.greenF() blue:color.blueF() alpha:1] setFill];
                NSRectFillUsingOperation(NSMakeRect(0,0,24,24),NSCompositingOperationSourceAtop);
                [image unlockFocus];
                NSBitmapImageRep *bitmap=[NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
                NSData *data=[bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                return QStringLiteral("data:image/png;base64,")+QString::fromLatin1([[data base64EncodedStringWithOptions:0] UTF8String]);
            });
            NSImage *accountSymbol = [[NSImage imageWithSystemSymbolName:@"person.crop.circle" accessibilityDescription:@"Account"]
                imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:32 weight:NSFontWeightRegular]];
            if (accountSymbol) {
                NSImage *avatar = [[NSImage alloc] initWithSize:NSMakeSize(48, 48)];
                [avatar lockFocus];
                [accountSymbol drawInRect:NSMakeRect(0, 0, 48, 48)];
                [[NSColor colorWithWhite:0.88 alpha:1] setFill];
                NSRectFillUsingOperation(NSMakeRect(0, 0, 48, 48), NSCompositingOperationSourceIn);
                [avatar unlockFocus];
                NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithData:avatar.TIFFRepresentation];
                NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                if (png) metrics->setDefaultAccountAvatar(QStringLiteral("data:image/png;base64,") +
                    QString::fromLatin1([[png base64EncodedStringWithOptions:0] UTF8String]));
            }
            PGCanvasCards *canvasCards=[[PGCanvasCards alloc] init];canvasCards.qtHost=qtView;canvasCards.coordinates=dock;canvasCards.sidebarGlass=dock.sidebarGlass;canvasCards.backdrop=(PGSidebarBackdrop *)dock.sidebarBackdrop;dock.canvasCards=canvasCards;
            metrics->setDockArtworkUpdater([dock,canvasCards](const QString &source,bool defaultArtwork) {
                dock.instanceArtwork.image=[canvasCards imageForSource:PGString(source)];
                dock.instanceArtwork.defaultArtwork=defaultArtwork;
                QString path=source;QUrl url(path);if(url.isLocalFile())path=url.toLocalFile();else if(path.startsWith("qrc:"))path=path.mid(3);
                QImage art(path);QColor tint(70,110,65);
                if(!art.isNull()) {
                    double rr=0,gg=0,bb=0,weight=0;const auto small=art.scaled(24,24,Qt::KeepAspectRatio,Qt::SmoothTransformation);
                    for(int y=0;y<small.height();y++)for(int x=0;x<small.width();x++){auto c=small.pixelColor(x,y);double a=c.alphaF();rr+=c.redF()*a;gg+=c.greenF()*a;bb+=c.blueF()*a;weight+=a;}
                    if(weight>0)tint=QColor::fromRgbF(rr/weight,gg/weight,bb/weight);
                }
                dock.instanceArtwork.tint=defaultArtwork?[NSColor colorWithCalibratedRed:tint.redF() green:tint.greenF() blue:tint.blueF() alpha:0.50]:NSColor.clearColor;
                dock.instanceArtwork.needsDisplay=YES;
            });
            metrics->setCanvasCardsUpdater([canvasCards,dock,window](const QVariantList &rows){canvasCards.contentInset=window->property("contentLeft").toDouble();[canvasCards update:rows strength:dock.glassStrength];});
            metrics->setEditorGlassUpdater([dock,qtView](QObject *object,bool visible) {
                [CATransaction begin];[CATransaction setDisableActions:YES];
                [NSAnimationContext beginGrouping];NSAnimationContext.currentContext.duration=0;
                NSAnimationContext.currentContext.allowsImplicitAnimation=NO;
                if(!dock.editorMaterials) dock.editorMaterials=[NSMutableArray array];
                auto *root=qobject_cast<QQuickItem *>(object);
                int index=0;
                NSMutableArray<NSView *> *sectionHeaders=[NSMutableArray array];
                QList<QQuickItem *> visualItems;
                std::function<void(QQuickItem *)> collect=[&](QQuickItem *item) {
                    visualItems.append(item);
                    for(QQuickItem *child:item->childItems())collect(child);
                };
                if(visible && root)collect(root);
                for(QQuickItem *item:visualItems) {
                    const QString name=item->objectName();
                    if((name!=QStringLiteral("editorGlassControl") && name!=QStringLiteral("accountGlassControl")) || !item->isVisible())continue;
                    bool transparentAncestor=false;
                    for(QQuickItem *ancestor=item;ancestor;ancestor=ancestor->parentItem())
                        if(ancestor->opacity()<=0.001) { transparentAncestor=true; break; }
                    if(transparentAncestor)continue;
                    const QString role=item->property("materialRole").toString();
                    const bool reading=role==QStringLiteral("reading");
                    const bool downloadRow=role==QStringLiteral("downloadRow") || role==QStringLiteral("releaseRow");
                    const bool assetRow=role==QStringLiteral("assetRow");
                    const bool sectionHeader=role==QStringLiteral("sectionHeader");
                    const bool scrollEdge=role=="scrollEdgeTop" || role=="scrollEdgeBottom";
                    const bool content=role==QStringLiteral("content");
                    NSView *glass=index<(int)dock.editorMaterials.count?dock.editorMaterials[index]:nil;
                    if(glass && (([glass isKindOfClass:NSVisualEffectView.class]!=(content || scrollEdge)) || ([glass isKindOfClass:PGDownloadRow.class]!=downloadRow) || ([glass isKindOfClass:PGEditorRow.class]!=assetRow) || ([glass isKindOfClass:PGEditorHeader.class]!=sectionHeader) || ([glass isKindOfClass:PGScrollEdgeView.class]!=scrollEdge))) {
                        [glass removeFromSuperview]; glass=nil;
                    }
                    if(!glass) {
                        if(scrollEdge)glass=[[PGScrollEdgeView alloc] initUpper:role=="scrollEdgeTop"];
                        else if(sectionHeader)glass=[[PGEditorHeader alloc] initWithFrame:NSZeroRect];
                        else if(assetRow)glass=[[PGEditorRow alloc] initWithFrame:NSZeroRect];
                        else if(downloadRow) glass=[[PGDownloadRow alloc] initWithFrame:NSZeroRect];
                        else if(content) {
                            NSVisualEffectView *material=[[NSVisualEffectView alloc] initWithFrame:NSZeroRect];
                            material.material=NSVisualEffectMaterialContentBackground;
                            material.blendingMode=NSVisualEffectBlendingModeWithinWindow;
                            material.state=NSVisualEffectStateActive; glass=material;
                        } else glass=PGPageGlass(NSZeroRect,14);
                        [qtView.superview addSubview:glass positioned:NSWindowBelow relativeTo:qtView];
                        if(index<(int)dock.editorMaterials.count)dock.editorMaterials[index]=glass;else[dock.editorMaterials addObject:glass];
                    }
                    NSString *appearanceName=root->window() && root->window()->property("darkMode").toBool()?NSAppearanceNameDarkAqua:NSAppearanceNameAqua;
                    if(![glass.appearance.name isEqualToString:appearanceName])glass.appearance=[NSAppearance appearanceNamed:appearanceName];
                    const QRectF sceneRect=item->mapRectToScene(QRectF(0,0,item->width(),item->height()));
                    const CGFloat itemScale=item->width()>0?sceneRect.width()/item->width():1;
                    const NSRect rect=NSMakeRect(sceneRect.x(),sceneRect.y(),sceneRect.width(),sceneRect.height());
                    glass.frame=[dock convertRect:rect toView:qtView.superview];
                    glass.wantsLayer=YES;
                    if(!scrollEdge && (role==QStringLiteral("quickCard") || downloadRow || assetRow)) {
                        QRectF allowed=sceneRect.intersected(QRectF(0,0,NSWidth(dock.bounds),NSHeight(dock.bounds)));
                        for(QQuickItem *ancestor=item->parentItem();ancestor;ancestor=ancestor->parentItem())
                            if(ancestor->clip())allowed=allowed.intersected(ancestor->mapRectToScene(QRectF(0,0,ancestor->width(),ancestor->height())));
                        const qreal left=root->window()?root->window()->property("contentLeft").toDouble():0;
                        allowed=allowed.intersected(QRectF(left,0,std::max(0.0,NSWidth(dock.bounds)-left),NSHeight(dock.bounds)));
                        if(allowed.isEmpty()){glass.hidden=YES;++index;continue;}
                        const NSRect clipped=[dock convertRect:NSMakeRect(allowed.x(),allowed.y(),allowed.width(),allowed.height()) toView:qtView.superview];
                        const NSRect local=[glass convertRect:clipped fromView:qtView.superview];
                        CAShapeLayer *mask=[CAShapeLayer layer];mask.frame=glass.bounds;
                        CGPathRef path=CGPathCreateWithRect(local,nullptr);mask.path=path;CGPathRelease(path);
                        if(assetRow) {
                            CALayer *tail=mask;
                            for(QQuickItem *ancestor=item->parentItem();ancestor;ancestor=ancestor->parentItem()) {
                                const CGFloat radius=ancestor->property("radius").toDouble();
                                if(!ancestor->clip() || radius<=0)continue;
                                const QRectF pane=ancestor->mapRectToScene(QRectF(0,0,ancestor->width(),ancestor->height()));
                                NSRect paneFrame=[dock convertRect:NSMakeRect(pane.x(),pane.y(),pane.width(),pane.height()) toView:qtView.superview];
                                paneFrame=[glass convertRect:paneFrame fromView:qtView.superview];
                                CAShapeLayer *roundMask=[CAShapeLayer layer];roundMask.frame=glass.bounds;
                                CGPathRef rounded=CGPathCreateWithRoundedRect(paneFrame,radius,radius,nullptr);
                                roundMask.path=rounded;CGPathRelease(rounded);tail.mask=roundMask;tail=roundMask;
                            }
                        }
                        glass.layer.mask=mask;
                    } else if(!scrollEdge)glass.layer.mask=nil;
                    if(scrollEdge){[(PGScrollEdgeView *)glass setNeedsLayout:YES];}
                    else if(sectionHeader){((PGEditorHeader *)glass).qtHost=qtView;[(PGEditorHeader *)glass updateItem:item strength:dock.glassStrength];}
                    else if(assetRow){((PGEditorRow *)glass).qtHost=qtView;[(PGEditorRow *)glass updateItem:item];}
                    else if(downloadRow) {
                        glass.layer.cornerRadius=item->property("radius").toDouble()*itemScale;glass.layer.masksToBounds=YES;
                    } else if(content) {
                        NSVisualEffectView *material=(NSVisualEffectView *)glass;
                        material.material=NSVisualEffectMaterialContentBackground;
                        const BOOL dark=[[glass.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]] isEqualToString:NSAppearanceNameDarkAqua];
                        glass.wantsLayer=YES; glass.layer.cornerRadius=item->property("radius").toDouble()*itemScale;glass.layer.masksToBounds=YES;
                        glass.layer.backgroundColor=item->property("selectedGlass").toBool()?[PGAccent() colorWithAlphaComponent:0.12].CGColor:[NSColor colorWithWhite:dark?0.05:1.0 alpha:0.14].CGColor;
                    } else {
                        [glass setValue:@(sectionHeader?0:item->property("radius").toDouble()*itemScale) forKey:@"cornerRadius"];
                        PGApplyGlass(glass,dock.glassStrength,false,item->property("selectedGlass").toBool());
                        if(reading) {
                            NSView *readingContent=[glass valueForKey:@"contentView"];
                            const BOOL dark=root->window() && root->window()->property("darkMode").toBool();
                            readingContent.layer.backgroundColor=[NSColor colorWithWhite:dark?0.03:1.0 alpha:0.20+0.18*dock.glassStrength].CGColor;
                        }
                        if(item->property("prominent").toBool()) {
                            NSView *contentView=[glass valueForKey:@"contentView"];
                            contentView.layer.backgroundColor=[PGAccent() colorWithAlphaComponent:0.26].CGColor;
                        }
                    }
                        if(sectionHeader) {
                            // Continue the enclosing pane's top corners; the separator edge stays flat.
                            const CGFloat w=NSWidth(glass.bounds),h=NSHeight(glass.bounds),r=std::min(24.0*itemScale,h);
                            const bool flipped=glass.isFlipped;
                            CGMutablePathRef path=CGPathCreateMutable();
                            CGAffineTransform transform=flipped?CGAffineTransformIdentity:CGAffineTransformMake(1,0,0,-1,0,h);
                            CGPathMoveToPoint(path,&transform,0,h);CGPathAddLineToPoint(path,&transform,0,r);
                            CGPathAddArcToPoint(path,&transform,0,0,r,0,r);
                            CGPathAddLineToPoint(path,&transform,w-r,0);CGPathAddArcToPoint(path,&transform,w,0,w,r,r);
                            CGPathAddLineToPoint(path,&transform,w,h);CGPathCloseSubpath(path);
                            CAShapeLayer *mask=[CAShapeLayer layer];mask.frame=glass.bounds;mask.path=path;glass.layer.mask=mask;CGPathRelease(path);
                        }
                    if(downloadRow)[(PGDownloadRow *)glass updateItem:item strength:dock.glassStrength];
                    // Preserve traversal stacking even when pooled views change type.
                    [qtView.superview addSubview:glass positioned:NSWindowBelow relativeTo:qtView];
                    if(downloadRow && dock.superview==glass.superview)[glass.superview addSubview:glass positioned:NSWindowBelow relativeTo:dock];
                    if(assetRow || scrollEdge)[qtView.superview addSubview:glass positioned:NSWindowAbove relativeTo:qtView];
                    if(sectionHeader)[sectionHeaders addObject:glass];
                    glass.hidden=NO;++index;
                }
                // Fixed headers cover the scrolling rows, including native switches and icons.
                for(NSView *header in sectionHeaders)[qtView.superview addSubview:header positioned:NSWindowAbove relativeTo:nil];
                for(NSUInteger i=index;i<dock.editorMaterials.count;i++)dock.editorMaterials[i].hidden=YES;
                [NSAnimationContext endGrouping];[CATransaction commit];
            });
            metrics->setPageUIUpdater([dock](const QVariantMap &state) {
                const bool reading=state.value("page").toString()==QStringLiteral("Download");
                if(dock.downloadReadingActive!=reading) {
                    dock.downloadReadingActive=reading;
                    [dock applySidebarMaterial];
                }
                if(!dock.upperScrollEdge) {
                    dock.upperScrollEdge=[[PGScrollEdgeView alloc] initUpper:YES];
                    dock.lowerScrollEdge=[[PGScrollEdgeView alloc] initUpper:NO];
                    [dock addSubview:dock.upperScrollEdge positioned:NSWindowBelow relativeTo:dock.glassView];
                    [dock addSubview:dock.lowerScrollEdge positioned:NSWindowBelow relativeTo:dock.glassView];
                }
                const CGFloat edgeX=std::max(0.0,state.value("edgeX").toDouble());
                const CGFloat edgeWidth=std::max(0.0,NSWidth(dock.bounds)-edgeX);
                dock.upperScrollEdge.frame=NSMakeRect(edgeX,0,edgeWidth,30);
                dock.lowerScrollEdge.frame=NSMakeRect(edgeX,NSHeight(dock.bounds)-30,edgeWidth,30);
                const bool visible = state.value("visible").toBool();
                if (!dock.pageUI && !visible) return;
                if (!dock.pageUI) {
                    dock.pageUI = [[PGNativePageUI alloc] initWithFrame:NSZeroRect];
                    dock.pageUI.metrics = dock.metrics;
                    [dock addSubview:dock.pageUI positioned:NSWindowBelow relativeTo:nil];
                }
                dock.pageUI.hidden = !visible;
                dock.pageUIInteractive = state.value("interactive").toBool();
                if (!visible) { dock.pageUI.categoryScroll.hidden=YES; return; }
                dock.pageUI.categoryScroll.hidden=NO;
                const bool settings = state.value("page").toString() == "Settings";
                const NSRect pageFrame = NSMakeRect(settings ? state.value("edgeX").toDouble() : state.value("x").toDouble(), settings ? 0 : state.value("y").toDouble(),
                    settings ? NSWidth(dock.bounds)-state.value("edgeX").toDouble() : state.value("width").toDouble(), settings ? NSHeight(dock.bounds) : state.value("page").toString() == "Instance" ? state.value("height").toDouble() : (state.value("sidebarDownloads").toBool()?42:98));
                if (!NSEqualRects(dock.pageUI.frame, pageFrame)) dock.pageUI.frame = pageFrame;
                [dock.pageUI updateState:state strength:dock.glassStrength];
                NSScrollView *categories=dock.pageUI.categoryScroll;
                if(state.value("sidebarDownloads").toBool() && state.value("page").toString()=="Download") {
                    if(categories.superview!=dock) { [categories removeFromSuperview]; [dock addSubview:categories]; }
                    categories.frame=NSMakeRect(state.value("categoryX").toDouble(),state.value("categoryY").toDouble(),state.value("categoryWidth").toDouble(),state.value("categoryHeight").toDouble());
                    categories.hidden=!state.value("categoriesExpanded").toBool();
                    categories.wantsLayer=YES;
                    const CGFloat top=std::max(0.0,state.value("sidebarClipTop").toDouble());
                    const CGFloat bottom=std::min(NSHeight(categories.frame),state.value("sidebarClipBottom").toDouble());
                    CAShapeLayer *mask=[CAShapeLayer layer];
                    CGPathRef path=CGPathCreateWithRect(CGRectMake(0,top,NSWidth(categories.frame),std::max(0.0,bottom-top)),nullptr);
                    mask.path=path; CGPathRelease(path); categories.layer.mask=mask;
                } else {
                    if(categories.superview!=dock.pageUI.downloadToolbar) { [categories removeFromSuperview]; [dock.pageUI.downloadToolbar addSubview:categories]; }
                    categories.layer.mask=nil;
                }
            });
            NSMapTable<NSView *,PGAccountGlassAttachment *> *accountAttachments=[NSMapTable weakToStrongObjectsMapTable];
            metrics->setAccountGlassUpdater([accountAttachments, metrics, window, dock](QObject *object, bool visible) {
                auto *item=qobject_cast<QQuickItem *>(object);
                QQuickWindow *popup=item?item->window():nullptr;
                if(!popup || popup==window)return;
                NSView *host=(__bridge NSView *)reinterpret_cast<void *>(popup->winId());
                if(!host.window || !host.superview)return;
                PGAccountGlassAttachment *accountGlass=[accountAttachments objectForKey:host];
                if(!visible) {
                    accountGlass.glass.hidden=YES;accountGlass.backing.hidden=YES;
                    for(NSView *control in accountGlass.controls)control.hidden=YES;
                    return;
                }
                if(!accountGlass) {
                    accountGlass=[PGAccountGlassAttachment new];
                    [accountAttachments setObject:accountGlass forKey:host];
                }
                popup->setColor(Qt::transparent);
                host.window.appearance=[NSAppearance appearanceNamed:window->property("darkMode").toBool()?NSAppearanceNameDarkAqua:NSAppearanceNameAqua];
                host.window.opaque = NO;
                host.window.backgroundColor = NSColor.clearColor;
                if (accountGlass.host != host) {
                    [accountGlass.glass removeFromSuperview];
                    [accountGlass.backing removeFromSuperview];
                    for (NSView *control in accountGlass.controls) [control removeFromSuperview];
                    accountGlass.controls = [NSMutableArray array];
                    accountGlass.host = host;
                    NSView *backing = [[NSView alloc] initWithFrame:NSZeroRect];
                    backing.wantsLayer = YES; backing.layer.cornerRadius = 24;
                    backing.layer.masksToBounds = YES;
                    backing.layer.backgroundColor = [NSColor colorWithWhite:0 alpha:0.24].CGColor;
                    [host.superview addSubview:backing positioned:NSWindowBelow relativeTo:host];
                    accountGlass.backing = backing;
                    NSView *glass = PGPageGlass(NSZeroRect, 24);
                    [host.superview addSubview:glass positioned:NSWindowAbove relativeTo:backing];
                    accountGlass.glass = glass;
                }
                const NSRect frame = [host convertRect:host.bounds toView:host.superview];
                accountGlass.backing.frame = frame; accountGlass.glass.frame = frame;
                accountGlass.glass.hidden = NO; accountGlass.backing.hidden = NO;
                PGApplyGlass(accountGlass.glass, dock.glassStrength);
                int index = 0;
                QList<QQuickItem *> popupItems;
                std::function<void(QQuickItem *)> collectPopup=[&](QQuickItem *entry){
                    popupItems.append(entry);for(auto *child:entry->childItems())collectPopup(child);
                };
                collectPopup(item);
                for (QQuickItem *control : popupItems) {
                    if (control->objectName() != QStringLiteral("accountGlassControl") || !control->isVisible()) continue;
                    const QString nativeKind=control->property("nativeKind").toString();
                    const bool nativeAction=!nativeKind.isEmpty();
                    NSView *surface=index<(int)accountGlass.controls.count?accountGlass.controls[index]:nil;
                    // Native controls own their material. A second glass wrapper
                    // produces an extra bezel around both the switch and button.
                    if(surface && ([surface.identifier isEqualToString:@"PGNativeAccountControl"]!=nativeAction)) {
                        [surface removeFromSuperview];surface=nil;
                    }
                    if(!surface) {
                        surface=nativeAction?[[PGPageContentView alloc] initWithFrame:NSZeroRect]:PGPageGlass(NSZeroRect,control->property("radius").toDouble());
                        surface.identifier=nativeAction?@"PGNativeAccountControl":@"PGAccountMaterial";
                        [host.superview addSubview:surface positioned:NSWindowBelow relativeTo:host];
                        if(index<(int)accountGlass.controls.count)accountGlass.controls[index]=surface;
                        else [accountGlass.controls addObject:surface];
                    }
                    const QPointF point = control->mapToScene(QPointF());
                    const CGFloat y = host.isFlipped ? point.y() : NSHeight(host.bounds) - point.y() - control->height();
                    const NSRect local = NSMakeRect(point.x(), y, control->width(), control->height());
                    surface.frame = [host convertRect:local toView:host.superview];
                    if(nativeAction) {
                        NSControl *nativeControl=[surface viewWithTag:918];
                        const BOOL needsSwitch=nativeKind==QStringLiteral("switch");
                        if(nativeControl && ([nativeControl isKindOfClass:NSSwitch.class]!=needsSwitch)) {
                            [nativeControl removeFromSuperview];nativeControl=nil;
                        }
                        if(!nativeControl) {
                            PGAccountAction *action=[PGAccountAction new];action->item=control;
                            if(needsSwitch)nativeControl=[[NSSwitch alloc] initWithFrame:NSZeroRect];
                            else {NSButton *button=[NSButton buttonWithTitle:@"Settings" target:nil action:nil];button.bezelStyle=NSBezelStyleRounded;nativeControl=button;}
                            nativeControl.tag=918;nativeControl.target=action;nativeControl.action=@selector(activate:);
                            objc_setAssociatedObject(nativeControl,@selector(activate:),action,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                            [surface addSubview:nativeControl];
                        }
                        PGAccountAction *action=objc_getAssociatedObject(nativeControl,@selector(activate:));action->item=control;
                        if(needsSwitch) {
                            [nativeControl sizeToFit];NSSize fit=nativeControl.frame.size;
                            nativeControl.frame=NSMakeRect((NSWidth(surface.bounds)-fit.width)/2,(NSHeight(surface.bounds)-fit.height)/2,fit.width,fit.height);
                            [(NSSwitch *)nativeControl setState:control->property("nativeChecked").toBool()?NSControlStateValueOn:NSControlStateValueOff];
                        } else nativeControl.frame=surface.bounds;
                        [host.superview addSubview:surface positioned:NSWindowAbove relativeTo:host];
                    } else {
                        [host.superview addSubview:surface positioned:NSWindowBelow relativeTo:host];
                        PGApplyGlass(surface,dock.glassStrength,false,control->property("selectedGlass").toBool());
                        [surface setValue:control->property("glassHovered").toBool()?[NSColor colorWithWhite:1 alpha:0.12]:nil forKey:@"tintColor"];
                    }
                    QRectF clipped=control->mapRectToScene(QRectF(0,0,control->width(),control->height()));
                    bool needsClip=false;
                    for(auto *ancestor=control->parentItem();ancestor;ancestor=ancestor->parentItem())if(ancestor->clip()) {
                        clipped=clipped.intersected(ancestor->mapRectToScene(QRectF(0,0,ancestor->width(),ancestor->height())));needsClip=true;
                    }
                    if(needsClip) {
                        const CGFloat clipY=host.isFlipped?clipped.y():NSHeight(host.bounds)-clipped.y()-clipped.height();
                        const NSRect maskRect=[host convertRect:NSMakeRect(clipped.x(),clipY,clipped.width(),clipped.height()) toView:surface];
                        surface.wantsLayer=YES;CAShapeLayer *mask=[CAShapeLayer layer];mask.frame=surface.bounds;
                        CGPathRef path=CGPathCreateWithRect(maskRect,nullptr);mask.path=path;CGPathRelease(path);surface.layer.mask=mask;
                    } else surface.layer.mask=nil;
                    surface.hidden=clipped.isEmpty();
                    ++index;
                }
                for (NSUInteger i = index; i < accountGlass.controls.count; ++i) accountGlass.controls[i].hidden = YES;
            });
            metrics->setNativeAccountGlass(true);
            metrics->setAccountButtonUpdater([dock](qreal x, qreal y, qreal opacity, bool visible, bool interactive) {
                if (!dock.accountButtonGlass) {
                    NSView *glass = [[NSClassFromString(@"NSGlassEffectView") alloc] initWithFrame:NSZeroRect];
                    [glass setValue:@24.0 forKey:@"cornerRadius"];
                    [glass setValue:@YES forKey:@"effectIsInteractive"];
                    NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 48, 48)];
                    [glass setValue:content forKey:@"contentView"];
                    NSButton *button = [NSButton buttonWithTitle:@"" target:dock action:@selector(navigationPressed:)];
                    button.tag = 6;
                    button.frame = NSMakeRect(0, 0, 48, 48);
                    button.bordered = NO;
                    button.image = [[NSImage imageWithSystemSymbolName:@"person.crop.circle" accessibilityDescription:@"Account"]
                        imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPointSize:24 weight:NSFontWeightRegular]];
                    button.imagePosition = NSImageOnly;
                    button.contentTintColor = NSColor.labelColor;
                    [content addSubview:button];
                    [dock addSubview:glass];
                    dock.accountButtonGlass = glass;
                    PGApplyGlass(glass, dock.glassStrength);
                }
                dock.accountButtonGlass.frame = NSMakeRect(x, y, 48, 48);
                dock.accountButtonGlass.hidden = !visible;
                dock.accountButtonGlass.alphaValue = opacity;
                dock.accountButtonInteractive = interactive;
                PGApplyGlass(dock.accountButtonGlass, std::max(0.64, (double)dock.glassStrength));
                [dock.accountButtonGlass setValue:[NSColor colorWithWhite:1 alpha:interactive ? 0.08 : 0.18] forKey:@"tintColor"];
            });
            metrics->setNavigationUpdater([dock](qreal progress, const QString &page, qreal contentHeight, qreal sidebarWidth) {
                dock.sidebarWidth = sidebarWidth;
                [dock updateNavigation:progress page:PGString(page) contentHeight:contentHeight];
            });
            __weak PGNativeGlassDockView *weakDock = dock;
            __weak NSWindow *weakWindow = nativeWindow;
            id searchDismissMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:
                (NSEventMaskLeftMouseDown | NSEventMaskRightMouseDown | NSEventMaskOtherMouseDown)
                handler:^NSEvent *(NSEvent *event) {
                    PGNativeGlassDockView *view = weakDock;
                    if (!view || event.window != weakWindow || !view.searchPanelGlass || view.searchPanelGlass.hidden) return event;
                    const NSPoint point = [view convertPoint:event.locationInWindow fromView:nil];
                    if (NSPointInRect(point, view.searchPanelGlass.frame)) return event;
                    // Let the toolbar search button perform its own toggle once.
                    if (!view.navigationGlass.hidden && view.navigationButtons.count > 4) {
                        NSButton *search = view.navigationButtons[4];
                        const NSRect searchRect = [search convertRect:search.bounds toView:view];
                        if (!search.hidden && NSPointInRect(point, searchRect)) return event;
                    }
                    if (view.metrics) QMetaObject::invokeMethod(view.metrics, "requestCloseSearch", Qt::QueuedConnection);
                    return event;
                }];
            QObject::connect(window, &QObject::destroyed, QCoreApplication::instance(), [searchDismissMonitor]() {
                [NSEvent removeMonitor:searchDismissMonitor];
            });
            metrics->setNativeGlassDock(true);
            metrics->setDockOverlayVisibilityUpdater([dock](bool visible) {
                dock.hidden = !visible;
            });
            qInfo() << "ProjectGlass: native macOS Liquid Glass dock enabled";
        }
    }

    // macOS 27 exposes the resolved native corner radii on NSView. Use the
    // largest corner for the two QML surfaces that should echo the window.
    if (@available(macOS 27.0, *)) {
        NSViewCornerRadii *radii = nativeWindow.contentView.effectiveCornerRadii;
        if (radii && metrics) {
            const CGFloat radius = std::max({radii.topLeft, radii.topRight,
                                             radii.bottomLeft, radii.bottomRight});
            if (radius > 0.0) metrics->setWindowCornerRadius(radius);
        }
    }

    qInfo() << "ProjectGlass 09.100: native Liquid Glass dock follows QML screen geometry; instance picker restored";
}


// Apply to Qt popup/dialog windows as well as Quick popup windows.
// Leave the main window's opaque wallpaper backdrop untouched.
void clearMacPopupBackground(QWindow *window)
{
    if(!window || !window->handle())return;
    NSView *view=(__bridge NSView *)(reinterpret_cast<void *>(window->winId()));
    NSWindow *native=view.window;if(!native)return;
    if(native.opaque)native.opaque=NO;
    if(![native.backgroundColor isEqual:NSColor.clearColor])native.backgroundColor=NSColor.clearColor;
    native.hasShadow=YES;
}
