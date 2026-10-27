# 09.100 — Search, sidebar gap and nested corners

- Native download search field uses a centered 22pt intrinsic-height control inside the 42pt glass surface; preserves text-cell centering and shared sidebar/no-sidebar layout code.
- Sidebar category container now matches its 236pt document height, removing the trailing 22pt blank gap before Settings.
- Image corner radius = max(0, row outer radius - row padding). Image mask/border share that radius, creating concentric corners rather than equal numeric radii.
- Other page geometry/materials remain unchanged. AppKit visual verification required on Mac.

09.100
- Download icon corner radius is at least 12pt; outer corner equals inset plus icon corner for concentric alignment.
- Click a catalogue row for its project introduction (Modrinth project body, Markdown, retry); Download still opens release selection.
- Release group headers fold independently. Dividers use (spacing - lineHeight) / 2.
- Launch background native context menu shares group, Quick Download, grouping method and background preferences with Settings. Custom selects only the existing image.
- Linux QML parsing and offscreen state checks completed. AppKit visual behavior requires macOS verification.

09.100 — Settings scrolling and native disclosure controls
- Settings NSScrollView now spans the full window. Initial content inset preserves the accepted top alignment; 108pt trailing content padding lets the final controls scroll clear of the dock.
- Hit testing prioritizes dock, navigation, account, search and instance picker before Settings.
- Top/bottom 30pt NSVisualEffectView bands use within-window blending plus a fading alpha mask and black tint. Effects ignore all pointer input and cover only the main content region.
- All four Settings selectors share x=w-220 and width=204. The accent well sits before the selector so both text and arrow columns align.
- Shared native popup uses NSPopUpButton menu behavior, SF Symbols chevron.up.chevron.down, and a 24pt NSGlassEffectView indicator. Sidebar disclosures use chevron.down/right SF Symbols, replacing Unicode glyphs. Windows legacy source retained.
- QML parser and native-flag/fallback state smoke tests pass. Objective-C++ compilation and visual verification require macOS.

09.100 — Missing menu indicators and disclosure geometry
- Fixed nil NSGlassEffectView.contentView in PGGlassPopUpButton. The explicit 24pt host now owns the NSImageView, restoring the arrows in all shared selectors including System.
- Popup label remains regular control size; indicator uses the system small-control symbol configuration and proportional scaling. Falls back to the system popup arrow if the symbol cannot be loaded.
- Disclosure marks are now rendered by NSButtonCell using NSBezelStyleDisclosure + NSButtonTypePushOnPushOff + NSControlSizeSmall and sizeToFit. QML keeps existing row click handling and uses a centered Retina-safe raster; this is native cell artwork, not a live AppKit button or animation bridge.
- Main content, aligned selector columns and window-edge effects remain unchanged.
- QML syntax/state tests pass. macOS AppKit compilation and visual rendering cannot be verified on Linux.

10.00 — First functional Prism bridge
- Preserves 09.100 visual baseline. New PrismBridge QObject discovers real OneSix instances read-only from instance.cfg/mmc-pack.json. Supports configured InstanceDir.
- Default macOS app/root detection plus editable connection dialog in Settings and Launch context menu.
- Real records feed the shared canvas/sidebar/dock model. Existing installed demo cards hide when real records exist. Native dock, fallback Launch and card double-click all use the same launch path.
- Launch uses a detached QProcess, literal argument list --dir / --launch, validates discovered IDs and executable, guards rapid duplicate requests, and redirects bridge output to a local log. Closing Glass does not terminate Prism.
- This is an external CLI bridge, not an embedded Prism core. No credential reads, no instance/config/world writes. Authentication, Java, memory, downloads and game logs remain in Prism. Status confirms handoff only; existing Prism IPC may make the bridge log incomplete.
- Next: verify real macOS launch, then IPC/lifecycle/game logs and coordinated settings before deeper core integration.

10.02 — Prism connection panel
- User confirmed real Minecraft launch. Bridge implementation unchanged.
- Rebuilt connection Popup.Window as a compact 600pt panel with 24pt padding, 36pt fields and 34pt actions.
- Uses existing native account-glass attachment for popup material and marked field/button surfaces; glass opacity follows the shared setting.
- Application/data paths, refresh and log access preserved; status condenses successful launch path into a readable message.
- QML syntax and installer shell syntax checked; AppKit material needs macOS visual verification.

10.03 — Quick Download selectors and download toolbar
- Quick Download popup uses an independent Popup.Window with the existing native glass attachment. Selector indicator uses AppKit popup-cell artwork.
- Search cell drawing/title/editing rectangles include the same vertical correction for placeholder and entered text.
- Sidebar download toolbar reserves 132pt provider, 76pt refresh, 148pt loader and 140pt sorting; search uses remaining width.
- Installer syntax checked. QML parser unavailable in current runtime; macOS visual verification required. Prism launch bridge unchanged.

10.04 — Sidebar indicator initialization
- symbolRevision NOTIFY property invalidates QML NativeChevron images when the AppKit symbol provider is installed after engine creation. Initial empty results no longer wait for a click/state change.
- Quick Download uses the same SF chevron.up.chevron.down symbol as native selectors, rendered proportionally in a padded 16pt canvas; removed the clipped 16pt NSPopUpButton snapshot.
- Selector circle participates in native sidebar material collection instead of using the old blue QML glass fill.
- QML parser and installer shell checks pass; macOS runtime appearance still requires verification.

10.05 — Card composition and selector toggle
- Selector arrow handles press explicitly, toggling an open popup closed. Popup outside policy excludes its trigger parent to prevent close/reopen races.
- Installed card artwork remains unchanged above the footer; a masked MultiEffect blur and black gradient appear only near the bottom. Name/version anchor bottom-left, compact hours/runs bottom-right, maximum two fractional digits. Installed top-left badge removed.
- Quick Download artwork removed. Cards join the existing native glass material collector while Launch is active and retain the download glyph.
- QML parser and installer shell checks pass; AppKit appearance and pointer routing require Mac verification.

10.06 — Footer fade bounds and native card geometry
- Footer gradient start follows caption top minus 12pt rather than fixed card percentage; blur mask uses a continuous full-range ramp.
- Native material frames use mapRectToScene, including ancestor zoom; corner radius scales by mapped width/local width.
- Quick card material masks intersect all clipped visual ancestors, the window bounds and the content region to the right of contentLeft. Fully clipped surfaces hide. Non-card pooled surfaces clear stale masks.
- QML and installer syntax checks pass. Objective-C++ rendering, zoom and scroll require macOS verification.

10.07 — Stronger footer and shared grouping selector
- Increased masked footer blur to 0.75/max40; white mask reaches full strength inside the text region. Dark gradient reaches 60% near caption and 85% at bottom, with unchanged transparent boundary above caption.
- Quick Download removes the QML border including selected outline; native glass supplies the single visible edge.
- Search selector uses the same six grouping choices and groupingMethod state as Settings, including Off. Native search popup border disabled; wider 180pt selector and 608pt panel allow longer group names.
- QML parser and installer syntax pass. macOS visuals and scrolling need real-device verification.

10.08 — Canvas bounds, sidebar ordering and material motion
- Search grouping selector narrowed to 140pt; expanded panel max568pt.
- Native material frame, radius and mask updates run in a zero-duration NSAnimationContext and disabled-actions CATransaction. No independent layer interpolation is added to the Qt scroll/flick trajectory. Cross-compositor timing still needs macOS verification.
- Sidebar drag works in every sorting mode. It snapshots current visible card order, commits the drop, switches sortMode to Custom and uses the same order for canvas/sidebar; grouping remains unchanged.
- Free canvas pan limits derive from actual spread rectangles, zoom, viewport and content origin. Small layouts fit inside available content; larger layouts pan across their bounds. Changes in count, zoom, viewport, sidebar or grouping re-clamp saved pan. Grouped scrolling retains existing bounds.
- QML parser and installer syntax pass. Node tests cover 18 count/zoom cases, extreme pans, small-layout visibility and reorder. macOS pointer/scroll rendering remains unverified.

10.09 — Stable relaxed bounds and persistent Free canvas
- Bounds use explicit world origin properties instead of subtracting pan from bound geometry. Viewport gets 80pt overscroll room. Pan clamps synchronously; resize/zoom/layout changes settle after 220ms. Free card edits do not re-clamp while dragging.
- Free mode toggle in canvas native context menu, enabled only with groups Off. Per-key positions/sizes and hidden keys persist separately; grouped layouts ignore these preferences. World origin stays independent of custom card coordinates.
- Card DragHandler moves by screen delta/zoom; selected bottom-right handle resizes within 180–640 x 126–480. Card context menu includes Small/Medium/Large and checked Show on canvas, supporting selected keys.
- Canvas Visible cards submenu restores hidden records without removing instances from sidebar or backend. Canvas Recenter action re-clamps bounds.
- QML parser/shell checks and 12 stable pan-bound cases pass. Pointer interaction and native material rendering still require macOS checks.

10.10 — Unified native cards and Free canvas controls
- Every macOS card uses one AppKit host for artwork/material/footer/labels/icon, with a shared frame, clip and native stacking order. Qt delegates remain transparent hit targets. Native updates run after Qt animation updates with implicit animations disabled.
- Card context Layer menu supports front/back/one step; persistent layer order drives both Qt hit targets and native hosts.
- Canvas Prevent overlap and Minimum gap (8–64pt) persist. Nearest valid edge placement applies on move/resize; enabling/changing spacing and restoring cards normalizes the layout.
- Restored Free-mode wheel panning and separate blank-canvas mouse drag; card dragging does not pan the canvas.
- QML parser and installer syntax checks pass. Node CanvasLayoutTest.cjs passes 192 placement/gap/resize/stability assertions. macOS Objective-C++ build, material rendering and pointer interactions are not verified in this Linux environment.

10.11 — Sidebar scene registration and universal canvas visibility
- Sidebar backdrop uses explicit top-origin coordinates and flipped-aware image drawing. Captured scene is drawn at its converted original frame rather than stretched to backdrop bounds; halo sample x uses that same frame origin.
- Native artwork contribution freezes before requesting the Qt grab, avoiding mixing callback-time card coordinates with an older captured image. X/Y image scale is computed independently for half-resolution rounding.
- Show on canvas and Visible cards work outside Free mode. One shared filtered card list drives automatic and grouped canvases; sidebar list and restore menu retain hidden instances. Canvas bounds update on visibility changes.
- QML and shell syntax pass; all 192 layout assertions pass. macOS native build and screenshot alignment remain unverified here.

10.12 — Real cards beneath sidebar glass
- Native card hosts are stacked between the wallpaper backdrop and sidebar glass. Card clipping excludes the sidebar viewport cutout, while retaining window/scroll ancestor clips. Thus the same native view crosses the sidebar edge without a second coordinate mapping.
- Launch skips the synthetic sidebar scene snapshot and halo. Sidebar glass samples the actual card hosts; other pages retain the existing scene capture path.
- Replaced persistent blue resize block with a corner-hover-only diagonal line grip. Resizing remains available at the selected Free card's corner.
- QML parser, installer syntax and 192 layout checks pass. Native stacking, sidebar glass sampling and hover appearance require macOS runtime verification.

10.13 — AppKit background extension
- Uses public NSBackgroundExtensionView (resolved dynamically like existing NSGlassEffectView) around the native canvas. automaticallyPlacesContentView=NO; content frame begins at the animated sidebar inset. AppKit owns the mirrored blurred extension outside that frame.
- Cards and aligned wallpaper share the native content container. Card frames/masks convert directly from the existing top-origin window coordinates to that container; stacking and Qt interaction targets are unchanged.
- Layout invalidation includes sidebar inset, native window frame, wallpaper, placement and background color, even when card rows are unchanged. Empty/non-Launch card rows hide the extension. Existing native rendering remains fallback when the API is unavailable.
- No synthetic scene snapshot or area-average halo is used for Launch. API source: https://developer.apple.com/documentation/appkit/nsbackgroundextensionview and automaticallyPlacesContentView documentation; WWDC25 session 310, background extension section.
- QML parser, installer syntax and 192 layout assertions pass. Objective-C++ build and actual AppKit sampling/blur behavior are not verified on this Linux host.

10.14 — Settings horizontal overflow and color-only extension
- Settings NSScrollView now spans edgeX through the right window edge, uses a transparent borderless overlay clip view. Group surfaces retain their previous width and gain x-edgeX inside the expanded viewport. Thus global control positions and row widths are unchanged.
- NSBackgroundExtensionView now receives wallpaper and low-frequency artwork only. Artwork is area-averaged to 5x5 and smoothly enlarged; text, statistics, icons, selection and resize controls are excluded. The native extension output is masked to the sidebar; actual cards remain independent, at their original frames under sidebar glass.
- This color-only adaptation targets the requested appearance; it is not a claim about Apple Music's private implementation. Actual sidebar contrast and AppKit extension masking require macOS verification.
- QML and installer syntax plus 192 layout assertions pass. No macOS native build or visual verification was possible here.

10.15 — Replace mirrored sidebar extension
- Removed NSBackgroundExtensionView and its replicated content sources from canvas rendering. Sidebar receives a low-resolution premultiplied color field built from cached artwork averages, with Gaussian vertical and horizontal falloff and exponential card-distance weighting. No screenshot capture, reflected labels or reflected card shapes on Launch.
- Vertical center follows the card's actual window y+height/2. Contribution decreases away from the sidebar; accumulated alpha caps at 0.34. PNG decoding into NSImage avoids the previous manual bitmap orientation path. Native glass remains above the field.
- Actual card masks stop at the sidebar boundary; pan, size, layers and hit targets retain existing coordinates. Settings changes from 10.14 retained.
- QML parser, shell syntax and 192 layout checks pass; analytical vertical-peak and proximity falloff checks pass. Native compilation and resulting glass appearance remain unverified on macOS.

10.16 — Remove sidebar card cutout
- Removed max(sidebarInset, clipX) from native card masks. Sidebar glass now overlays the complete native host; material, artwork, labels and icon remain one unit beneath it. Window and clipped scroll-ancestor bounds remain enforced by the existing QML clip rectangle.
- Retains 10.15 color glow and existing card geometry/ordering. QML parser, installer syntax and 192 layout assertions pass. Native build and sidebar compositing remain unverified on macOS.
