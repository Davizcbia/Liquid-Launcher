#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#include <QQuickWindow>
#include <QDebug>
#include <QMetaObject>
#include <algorithm>
#include "MacWindowMetrics.h"

static NSString *PGString(const QString &value)
{
    const QByteArray utf8 = value.toUtf8();
    return [[NSString alloc] initWithBytes:utf8.constData()
                                    length:static_cast<NSUInteger>(utf8.size())
                                  encoding:NSUTF8StringEncoding];
}

@interface PGNativeGlassDockView : NSView
@property(nonatomic, assign) MacWindowMetrics *metrics;
@property(nonatomic, strong) NSView *glassView;
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
    self.glassView = glass;

    NSView *content = [[NSView alloc] initWithFrame:NSZeroRect];
    content.wantsLayer = YES;
    content.layer.backgroundColor = NSColor.clearColor.CGColor;
    [glass setValue:content forKey:@"contentView"];

    NSView *iconTile = [[NSView alloc] initWithFrame:NSZeroRect];
    iconTile.translatesAutoresizingMaskIntoConstraints = NO;
    iconTile.wantsLayer = YES;
    iconTile.layer.cornerRadius = 15.0;
    iconTile.layer.backgroundColor = [NSColor colorWithCalibratedRed:0.14 green:0.36 blue:0.48 alpha:0.50].CGColor;
    NSTextField *diamond = [NSTextField labelWithString:@"◆"];
    diamond.translatesAutoresizingMaskIntoConstraints = NO;
    diamond.textColor = [NSColor colorWithCalibratedRed:0.32 green:0.82 blue:1.0 alpha:1.0];
    diamond.font = [NSFont systemFontOfSize:26.0 weight:NSFontWeightRegular];
    [iconTile addSubview:diamond];
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

    NSStackView *labels = [[NSStackView alloc] initWithViews:@[self.titleLabel, self.versionLabel]];
    labels.translatesAutoresizingMaskIntoConstraints = NO;
    labels.orientation = NSUserInterfaceLayoutOrientationVertical;
    labels.alignment = NSLayoutAttributeLeading;
    labels.distribution = NSStackViewDistributionFill;
    labels.spacing = 4.0;

    NSButton *launchButton = [NSButton buttonWithTitle:@"▶  Launch" target:self action:@selector(launchPressed:)];
    launchButton.translatesAutoresizingMaskIntoConstraints = NO;
    launchButton.bezelStyle = NSBezelStyleRounded;
    launchButton.controlSize = NSControlSizeRegular;
    launchButton.font = [NSFont systemFontOfSize:12.0 weight:NSFontWeightSemibold];

    [content addSubview:iconTile];
    [content addSubview:labels];
    [content addSubview:launchButton];
    [NSLayoutConstraint activateConstraints:@[
        [iconTile.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:18.0],
        [iconTile.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [iconTile.widthAnchor constraintEqualToConstant:46.0],
        [iconTile.heightAnchor constraintEqualToConstant:46.0],
        [diamond.centerXAnchor constraintEqualToAnchor:iconTile.centerXAnchor],
        [diamond.centerYAnchor constraintEqualToAnchor:iconTile.centerYAnchor],
        [labels.leadingAnchor constraintEqualToAnchor:iconTile.trailingAnchor constant:16.0],
        [labels.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [labels.trailingAnchor constraintLessThanOrEqualToAnchor:launchButton.leadingAnchor constant:-12.0],
        [launchButton.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-14.0],
        [launchButton.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [launchButton.widthAnchor constraintEqualToConstant:105.0],
        [launchButton.heightAnchor constraintEqualToConstant:40.0]
    ]];

    [self addSubview:glass];
    return self;
}

- (void)layout
{
    [super layout];
    if (!self.glassView) return;
    const CGFloat y = NSHeight(self.bounds) - _dockY - _dockHeight;
    self.glassView.frame = NSMakeRect(_dockX, y, _dockWidth, _dockHeight);
    [self.glassView setValue:@(_dockRadius) forKey:@"cornerRadius"];
}

- (NSView *)hitTest:(NSPoint)point
{
    if (!self.glassView || !NSPointInRect(point, self.glassView.frame)) return nil;
    const NSPoint localPoint = [self.glassView convertPoint:point fromView:self];
    return [self.glassView hitTest:localPoint];
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
    NSView *qtView = reinterpret_cast<NSView *>(window->winId());
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
            metrics->setDockInfoUpdater([dock](const QString &title, const QString &version,
                                               qreal x, qreal y, qreal width, qreal height, qreal radius) {
                [dock setDockTitle:PGString(title) version:PGString(version)
                                  x:x y:y width:width height:height radius:radius];
            });
            metrics->setNativeGlassDock(true);
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

    qInfo() << "ProjectGlass 09.31: native Liquid Glass dock and macOS titlebar configured";
}
