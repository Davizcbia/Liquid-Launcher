import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Qt.labs.settings

ApplicationWindow {
    id: window
    width: 1220
    height: 780
    minimumWidth: 850
    minimumHeight: 560
    visible: true
    title: "Project Glass · Prototype 09.31"
    property bool darkMode: Qt.styleHints.colorScheme === Qt.Dark
    property color ink: darkMode ? "#F7FAFF" : "#172333"
    property color muted: darkMode ? "#AAB8CC" : "#58697D"
    property color glass: darkMode ? "#A82A394D" : "#D9F6FAFF"
    property color glassStrong: darkMode ? "#CC30465E" : "#ECF8FBFF"
    property color glassSoft: darkMode ? "#84334660" : "#DCEEF7FF"
    property color outline: darkMode ? "#65E5F5FF" : "#8095B5CD"
    property color accent: darkMode ? "#A9D8FF" : "#397AD1"
    property bool smartLayout: true
    property bool quickCards: true
    // Opt-in, full-window aligned compositor; default off preserves stable 09.21.1 visuals.
    property bool dockLiveBlur: false
    // Adjustable intensity: 0 = no blur, 1 = strongest. Saved automatically.
    property real dockBlurAmount: 0.30
    property real glassOpacity: 0.72
    readonly property color materialTint: darkMode ? Qt.rgba(0.11, 0.23, 0.31, glassOpacity) : Qt.rgba(0.94, 0.98, 1.0, glassOpacity)
    property bool autoSelect: true
    property string sortMode: "Smart"
    property string selectedId: "rebirth"
    property string searchText: ""
    property bool searchExpanded: false
    property bool sidebarMode: false
    property bool instancePickerOpen: false
    property bool accountMenuOpen: false
    property string accountDisplayName: "Player"
    property string accountProvider: "Not signed in"
    property bool sidebarInstancesExpanded: false
    property bool sidebarQuickDownloadExpanded: false
    property string sidebarQuickVersion: "1.21.8"
    property string sidebarQuickLoader: "Fabric"
    function toggleAccountMenu() {
        accountMenuOpen = !accountMenuOpen
        if (accountMenuOpen) {
            instancePickerOpen = false
            if (sidebarMode) {
                sidebarInstancesExpanded = false
                sidebarQuickDownloadExpanded = false
            }
        }
    }
    property string activePage: "Launch"
    property string downloadCategory: "Versions"
    property string downloadSearch: ""
    property string downloadSort: "Featured"
    property string downloadProvider: "Modrinth"
    property string downloadLoaderFilter: "All loaders"
    readonly property var downloadCategories: ["Versions", "Mods", "Shaders", "Resource packs", "Modpacks"]
    readonly property var downloadResults: downloadData.catalogue
    ListModel { id: downloadRows; dynamicRoles: true }
    property var downloadRowKeys: []
    Connections {
        target: downloadData
        function onCatalogueChanged() {
            var rows = downloadData.catalogue
            function key(row) { return row.projectId || row.version || row.name }
            var append = rows.length >= downloadRows.count
            for (var i = 0; append && i < downloadRows.count; i++)
                if (window.downloadRowKeys[i] !== key(rows[i])) append = false
            if (!append) { downloadRows.clear(); window.downloadRowKeys = [] }
            var keys = window.downloadRowKeys.slice()
            for (var j = downloadRows.count; j < rows.length; j++) {
                downloadRows.append({ entry: rows[j] })
                keys.push(key(rows[j]))
            }
            window.downloadRowKeys = keys
        }
    }
    DownloadData { id: downloadData; objectName: "downloadData" }
    property bool downloadReady: false
    Component.onCompleted: {
        downloadReady = true
        macWindowMetrics.setDockInfo(selectedLabel(), selectedVersion())
        macWindowMetrics.setDockGeometry(bottomDock.x, bottomDock.y, bottomDock.width,
                                         bottomDock.height, bottomDock.radius)
        if (activePage === "Download") catalogueRefresh.restart()
    }
    Timer {
        id: catalogueRefresh
        interval: 350
        onTriggered: {
            if (window.downloadReady && window.activePage === "Download" && !window.downloadSelection)
                downloadData.loadCatalogue(window.downloadCategory, window.downloadSearch, window.downloadSort, false, window.downloadLoaderFilter, window.downloadProvider)
        }
    }
    function refreshCatalogue() {
        if (!downloadReady) return
        downloadData.invalidateCatalogue()
        catalogueRefresh.restart()
    }
    onDownloadSearchChanged: refreshCatalogue()
    onDownloadCategoryChanged: refreshCatalogue()
    onDownloadSortChanged: refreshCatalogue()
    onDownloadProviderChanged: refreshCatalogue()
    onDownloadLoaderFilterChanged: refreshCatalogue()
    onActivePageChanged: {
        if (!downloadReady) return
        if (activePage === "Download") {
            if (downloadSelection) releaseRefresh.restart()
            else refreshCatalogue()
        } else {
            catalogueRefresh.stop()
            releaseRefresh.stop()
            downloadData.invalidateCatalogue()
            downloadData.closeReleases()
            selectedRelease = ""
        }
    }
    function openDownloadCategory(category) {
        downloadCategory = category
        activePage = "Download"
        downloadSelection = null
        accountMenuOpen = false
        instancePickerOpen = false
    }
    property var downloadSelection: null
    property string selectedLoader: sidebarQuickLoader
    readonly property string targetMinecraftVersion: {
        var source = selectedVersion()
        var match = source.match(/\d+(?:\.\d+)+/)
        return match ? match[0] : ""
    }
    readonly property string targetLoader: {
        var source = selectedVersion()
        return source.indexOf("Fabric") === 0 ? "Fabric" : source.indexOf("NeoForge") === 0 ? "NeoForge" : source.indexOf("Forge") === 0 ? "Forge" : "Vanilla"
    }
    property string selectedRelease: ""
    onSelectedIdChanged: {
        macWindowMetrics.setDockInfo(selectedLabel(), selectedVersion())
        selectedRelease = ""
        if (downloadReady && downloadSelection && downloadSelection.category !== "Versions") {
            downloadData.closeReleases()
            releaseRefresh.restart()
        }
    }
    Connections {
        target: macWindowMetrics
        function onInstancePickerRequested() { window.instancePickerOpen = !window.instancePickerOpen }
        function onLaunchRequested() { window.statusMessage = "Prototype only · Launch is not connected to Prism" }
    }
    function beginDownload(entry) {
        downloadSelection = JSON.parse(JSON.stringify(entry))
        selectedLoader = sidebarQuickLoader
        selectedRelease = ""
        activePage = "Download"
    }
    readonly property var releaseChoices: downloadData.releases
    readonly property var selectedReleaseDetails: {
        for (var i = 0; i < releaseChoices.length; i++) if (releaseChoices[i].id === selectedRelease) return releaseChoices[i]
        return null
    }
    onDownloadSelectionChanged: {
        if (!downloadReady) return
        selectedRelease = ""
        downloadData.closeReleases()
        releaseRefresh.stop()
        if (downloadSelection) {
            catalogueRefresh.stop()
            downloadData.cancel("catalogue")
            downloadData.catalogueBusy = false
            releaseRefresh.restart()
        } else if (activePage === "Download") refreshCatalogue()
    }
    onSelectedLoaderChanged: {
        if (!downloadReady || !downloadSelection || downloadSelection.category !== "Versions") return
        selectedRelease = ""
        downloadData.closeReleases()
        releaseRefresh.restart()
    }
    Timer {
        id: releaseRefresh
        interval: 1
        onTriggered: {
            if (window.activePage === "Download" && window.downloadSelection)
                downloadData.loadReleases(window.downloadSelection, window.selectedLoader, window.targetMinecraftVersion, window.targetLoader)
        }
    }
    function previewDownload(name) {
        statusMessage = "Preview only · " + name + " · installation backend is not connected"
        downloadNotice.open()
    }
    Dialog {
        id: downloadNotice
        parent: Overlay.overlay
        anchors.centerIn: parent
        width: Math.min(420, window.width - 40)
        modal: true
        title: "Installation preview"
        standardButtons: Dialog.Ok
        background: GlassPane { radius: 24; emphasized: true }
        contentItem: Text {
            text: window.statusMessage
            color: window.ink
            wrapMode: Text.WordWrap
            padding: 16
        }
    }

    // One animation drives sidebar, navigation and the content-region geometry.
    property real sidebarProgress: sidebarMode ? 1.0 : 0.0
    Behavior on sidebarProgress {
        NumberAnimation { duration: 390; easing.type: Easing.InOutCubic }
    }
    readonly property real contentLeft: sidebarProgress * sidebar.width
    property real panX: 0
    property real panY: 0
    property real zoom: 1
    // Shared geometry tokens for consistent cross-platform corners.
    readonly property real panelRadius: 30
    readonly property real cardRadius: 26
    readonly property real pillRadius: 24
    readonly property real innerRadius: 16
    readonly property real settingsCardRadius: 22
    readonly property real downloadControlRadius: 21
    readonly property real macOSWindowCornerRadius: macWindowMetrics.windowCornerRadius
    readonly property int motionMs: 280
    onSidebarModeChanged: {
        accountMenuOpen = false
        instancePickerOpen = false
        // Keep the canvas offsets and zoom untouched.
    }
    property string statusMessage: "Prototype mode · Minecraft launch is not connected"
    color: darkMode ? "#101722" : "#E8F0F8"
    // Persistent user preferences and window geometry (Qt application settings).
    Settings {
        category: "ProjectGlassPrototype091"
        property alias sidebarMode: window.sidebarMode
        property alias smartLayout: window.smartLayout
        property alias quickCards: window.quickCards
        property alias dockLiveBlur: window.dockLiveBlur
        property alias dockBlurAmount: window.dockBlurAmount
        property alias glassOpacity: window.glassOpacity
        property alias autoSelect: window.autoSelect
        property alias sortMode: window.sortMode
        property alias selectedId: window.selectedId
        property alias accountDisplayName: window.accountDisplayName
        property alias sidebarInstancesExpanded: window.sidebarInstancesExpanded
        property alias sidebarQuickVersion: window.sidebarQuickVersion
        property alias sidebarQuickLoader: window.sidebarQuickLoader
        property alias downloadCategory: window.downloadCategory
        property alias downloadProvider: window.downloadProvider
        property alias activePage: window.activePage
        property alias searchText: window.searchText
        property alias searchExpanded: window.searchExpanded
        property alias panX: window.panX
        property alias panY: window.panY
        property alias zoom: window.zoom
        property alias windowWidth: window.width
        property alias windowHeight: window.height
        property alias windowX: window.x
        property alias windowY: window.y
    }


    // Glass-styled ComboBox keeps Qt's native selection, keyboard and popup
    // handling while placing the popup in the unclipped application overlay.
    component GlassSelect: ComboBox {
        id: glassSelectRoot
        property var options: []
        property string selected: ""
        property bool compact: false
        property real controlHeight: 34
        property real cornerRadius: 14
        signal chosen(string value)
        height: controlHeight
        implicitHeight: controlHeight
        model: options
        function syncSelectedIndex() {
            var index = options.indexOf(selected)
            if (index >= 0 && currentIndex !== index) currentIndex = index
        }
        onSelectedChanged: syncSelectedIndex()
        onOptionsChanged: syncSelectedIndex()
        Component.onCompleted: syncSelectedIndex()
        onActivated: function(index) { chosen(options[index]) }

        contentItem: Text {
            leftPadding: 12
            rightPadding: 30
            text: glassSelectRoot.selected
            color: window.ink
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        indicator: Text {
            x: glassSelectRoot.width - width - 10
            y: (glassSelectRoot.height - height) / 2
            text: glassSelectRoot.popup.visible ? "⌃" : "⌄"
            color: window.muted
            font.pixelSize: 16
        }
        background: Rectangle {
            radius: glassSelectRoot.cornerRadius
            color: window.darkMode ? "#3E57768C" : "#C7EAF4FC"
            border.width: 1
            border.color: glassSelectRoot.hovered || glassSelectRoot.popup.visible
                          ? window.accent : window.outline
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }
        delegate: ItemDelegate {
            required property string modelData
            required property int index
            width: glassSelectRoot.popup.availableWidth
            height: 38
            highlighted: glassSelectRoot.highlightedIndex === index
            contentItem: Text {
                text: modelData
                color: window.ink
                font.pixelSize: 12
                font.bold: modelData === glassSelectRoot.selected
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 13
                color: modelData === glassSelectRoot.selected
                       ? (window.darkMode ? "#5474AAD1" : "#9BC8E8FA")
                       : (parent.hovered ? (window.darkMode ? "#30FFFFFF" : "#80FFFFFF") : "transparent")
                Behavior on color { ColorAnimation { duration: 130 } }
            }
            onClicked: {
                glassSelectRoot.currentIndex = index
                glassSelectRoot.chosen(modelData)
                glassSelectRoot.popup.close()
            }
        }
        popup: Popup {
            id: selectorPopup
            focus: true
            modal: false
            padding: 6
            z: 300
            width: glassSelectRoot.width
            height: Math.min(glassSelectRoot.options.length * 39 + 12, window.height - 24)
            readonly property point triggerPoint: glassSelectRoot.mapToItem(window.contentItem, 0, 0)
            readonly property real triggerGap: 8
            y: triggerPoint.y + glassSelectRoot.height + triggerGap + height <= window.height - 12
               ? glassSelectRoot.height + triggerGap
               : -height - triggerGap
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
            background: GlassPane {
                radius: 19
                emphasized: true
                border.width: 1
                border.color: window.outline
            }
            contentItem: ListView {
                clip: true
                model: selectorPopup.visible ? glassSelectRoot.delegateModel : null
                currentIndex: glassSelectRoot.highlightedIndex
                implicitHeight: contentHeight
            }
        }
    }

    // Shared QML fallback glass surface. On macOS 26 and later the persistent
    // launch dock is replaced by an AppKit NSGlassEffectView; other QML panes
    // still use this cross-platform approximation until their native bridge.
    component GlassPane: Rectangle {
        property bool emphasized: false
        property bool subtle: false
        property bool selectedGlass: false
        property bool edgeGlow: true
        // Only overlays OUTSIDE sceneLayer may capture it: this prevents
        // feedback loops and keeps instance cards efficient.
        property bool backdropBlur: false
        radius: window.panelRadius
        clip: backdropBlur
        color: backdropBlur ? (window.darkMode ? "#66324661" : "#99F4FAFF")
                            : (subtle ? window.glassSoft : (emphasized ? window.glassStrong : window.glass))
        border.width: selectedGlass ? 1.6 : 1
        border.color: selectedGlass ? window.accent : window.outline
        // Real-time Qt Quick backdrop blur. The captured source consists of
        // the canvas and background only, never this overlay or its text.
        ShaderEffectSource {
            id: panelBackdropSource
            anchors.fill: parent
            sourceItem: parent.backdropBlur ? sceneLayer : null
            sourceRect: {
                if (!parent.backdropBlur) return Qt.rect(0, 0, 0, 0)
                var p = parent.mapToItem(sceneLayer, 0, 0)
                return Qt.rect(p.x, p.y, parent.width, parent.height)
            }
            live: parent.backdropBlur
            hideSource: false
            visible: false
        }
        // Rounded alpha mask: clip:true only clips a rectangular QQuickItem.
        // Without this mask, the blurred image forms a visible square behind
        // rounded panels (particularly the bottom launch dock).
        Rectangle {
            id: panelBlurMaskShape
            width: parent.width
            height: parent.height
            radius: parent.radius
            color: "white"
            visible: false
        }
        ShaderEffectSource {
            id: panelBlurMaskTexture
            sourceItem: panelBlurMaskShape
            hideSource: true
            live: true
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: panelBackdropSource
            visible: parent.backdropBlur
            maskEnabled: parent.backdropBlur
            maskSource: panelBlurMaskTexture
            blurEnabled: true
            blur: 0.85
            blurMax: 42
            autoPaddingEnabled: false
            opacity: window.darkMode ? 0.84 : 0.90
            z: 0
        }
        // Top-edge specular sheen, clipped to the panel shape.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: window.darkMode ? "#23FFFFFF" : "#78FFFFFF"
            visible: parent.edgeGlow
            z: -1
        }
        Behavior on color { ColorAnimation { duration: window.motionMs } }
        Behavior on border.color { ColorAnimation { duration: window.motionMs } }
        // Broad, low-contrast specular gradient; the native material bridge
        // is a separate macOS integration and is not emulated here.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Math.max(0, parent.radius - 2)
            gradient: Gradient { GradientStop { position: 0.0; color: window.darkMode ? "#1CFFFFFF" : "#50FFFFFF" } GradientStop { position: 0.22; color: "#08FFFFFF" } GradientStop { position: 0.85; color: "#00FFFFFF" } GradientStop { position: 1.0; color: window.darkMode ? "#0DFFFFFF" : "#15FFFFFF" } }
            opacity: parent.edgeGlow ? 0.65 : 0.0
            z: -1
        }
    }

    ListModel {
        id: instances
        ListElement { key: "rebirth"; label: "The Rebirth"; version: "Fabric 1.21.5"; hours: 82; installed: true; lastPlayed: true }
        ListElement { key: "vanilla"; label: "Survival"; version: "Minecraft 1.20.1"; hours: 25; installed: true; lastPlayed: false }
        ListElement { key: "creative"; label: "Creative"; version: "Minecraft 26.3"; hours: 8; installed: true; lastPlayed: false }
        ListElement { key: "fabric"; label: "Fabric 1.21.8"; version: "Quick download"; hours: 0; installed: false; lastPlayed: false }
        ListElement { key: "neoforge"; label: "NeoForge"; version: "Quick download"; hours: 0; installed: false; lastPlayed: false }
        ListElement { key: "quilt"; label: "Quilt"; version: "Quick download"; hours: 0; installed: false; lastPlayed: false }
    }
    property var sortedCards: {
        var a = []
        for (var i = 0; i < instances.count; i++) {
            var v = instances.get(i)
            if ((!v.installed && !quickCards) ||
                (searchText.length && (v.label + " " + v.version).toLowerCase().indexOf(searchText.toLowerCase()) < 0)) continue
            a.push({ key: v.key, label: v.label, version: v.version, hours: v.hours, installed: v.installed })
        }
        if (sortMode === "Name") a.sort(function(x,y) { return x.label.localeCompare(y.label) })
        else if (sortMode === "Smart") a.sort(function(x,y) { return y.hours - x.hours })
        return a
    }
    function sidebarInstalledCards() {
        var a = []
        var source = window.sortedCards
        for (var i = 0; i < source.length; ++i) {
            if (source[i].installed) a.push(source[i])
        }
        return a
    }
    function selectedLabel() {
        for (var i=0;i<instances.count;i++) if (instances.get(i).key === selectedId) return instances.get(i).label
        return "Select a version"
    }
    function selectedVersion() {
        for (var i=0;i<instances.count;i++) if (instances.get(i).key === selectedId) return instances.get(i).version
        return ""
    }
    function chooseCard(c) {
        if (!c || !c.key) return
        selectedId = c.key
        statusMessage = c.installed ? "Selected " + c.label : "Quick download preview: " + c.label
    }
    function activateCard(c) {
        chooseCard(c)
        statusMessage = c.installed ? "Demo only: would launch " + c.label : "Demo only: would download " + c.label
    }
    function toggleSearch() {
        searchExpanded = !searchExpanded
        if (searchExpanded) searchInput.forceActiveFocus()
        else searchInput.focus = false
    }
    function resetCanvas() { panX=0; panY=0; zoom=1 }
    function changeZoom(factor) {
        zoom = Math.max(0.55, Math.min(1.65, zoom * factor))
    }
    // Keyboard navigation: zoom in/out and return to the original view.
    Shortcut { sequences: ["Ctrl++", "Ctrl+="]; enabled: window.activePage === "Launch"; onActivated: window.changeZoom(1.12) }
    Shortcut { sequence: "Ctrl+-"; enabled: window.activePage === "Launch"; onActivated: window.changeZoom(1 / 1.12) }
    Shortcut { sequence: "Ctrl+0"; enabled: window.activePage === "Launch"; onActivated: window.resetCanvas() }
    // Direct trackpad pinching must feel immediate; the slider animates its own thumb.


    // Composite background and cards into one offscreen scene for sidebar blur.
    // The sidebar itself is outside this scene to avoid recursive capture.
    Item {
        id: sceneLayer
        anchors.fill: parent
    Rectangle {
        id: backgroundBackdrop
        anchors.fill: parent
        gradient: Gradient { GradientStop { position: 0; color: window.darkMode ? "#1B3048" : "#C8DDF4" } GradientStop { position: 0.52; color: window.darkMode ? "#111A29" : "#EDF4FA" } GradientStop { position: 1; color: window.darkMode ? "#222032" : "#D8E5F2" } }
    }
    Rectangle { x: width * .46; y: height * .17; width: 440; height: 440; radius: 220; color: darkMode ? "#203A75A8" : "#5584C4FF"; opacity: darkMode ? .25 : .08 }
    Rectangle { x: width * .72; y: height * .62; width: 350; height: 350; radius: 175; color: "#997EADFF"; opacity: darkMode ? .13 : .04 }

    // Full-window canvas: the floating controls never divide the background.
    Item {
        id: canvas
        anchors.fill: parent
        clip: true
        visible: window.activePage === "Launch"
        Item {
            id: world
            x: canvas.width / 2 + panX
            y: canvas.height / 2 + panY
            scale: zoom
            Repeater {
                model: window.sortedCards
                delegate: GlassPane {
                    required property var modelData
                    required property int index
                    property bool featured: window.smartLayout && modelData.installed && index === 0
                    property real baseWidth: !window.smartLayout ? 230 : (featured ? 330 : (modelData.installed && index === 1 ? 270 : 220))
                    property real cardWidth: Math.min(baseWidth, Math.max(155, canvas.width * .34))
                    property real cardHeight: featured ? 230 : 168
                    property real theta: index === 0 ? 0 : (index - 1) * 2.399963
                    property real distance: index === 0 ? 0 : 265 + Math.sqrt(index - 1) * 88
                    width: cardWidth
                    height: cardHeight
                    x: (index === 0 ? -cardWidth/2 : Math.cos(theta) * distance - cardWidth/2)
                    y: (index === 0 ? -cardHeight/2 : Math.sin(theta) * distance - cardHeight/2)
                    radius: window.cardRadius
                    subtle: !modelData.installed
                    emphasized: featured
                    selectedGlass: selectedId === modelData.key
                    opacity: modelData.installed ? 1 : (window.darkMode ? .68 : .94)
                    Behavior on x { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    Behavior on y { NumberAnimation { duration: 420; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 250 } }
                    Column {
                        anchors.fill: parent
                        anchors.margins: 20
                        spacing: 8
                        Text { text: modelData.installed ? "◆" : "↓"; font.pixelSize: 29; color: accent }
                        Item { height: 5; width: 1 }
                        Text { text: modelData.label; font.pixelSize: featured ? 24 : 19; font.bold: true; color: ink; elide: Text.ElideRight; width: parent.width }
                        Text { text: modelData.version; font.pixelSize: 13; color: muted; elide: Text.ElideRight; width: parent.width }
                        Item { width: 1; height: 1; Layout.fillHeight: true }
                        Text { text: modelData.installed ? modelData.hours + " hours played" : "Available to install"; font.pixelSize: 11; color: muted }
                    }
                    // Tap is recognized without stealing drag gestures from the parent.
                    TapHandler {
                        acceptedButtons: Qt.LeftButton
                        gesturePolicy: TapHandler.DragThreshold
                        enabled: window.activePage === "Launch"
                        onTapped: {
                            if (window.activePage === "Launch") window.chooseCard(modelData)
                        }
                        onDoubleTapped: {
                            if (window.activePage === "Launch") window.activateCard(modelData)
                        }
                    }
                }
            }
        }
        PinchHandler {
            id: canvasPinch
            target: null
            enabled: window.activePage === "Launch" && !window.instancePickerOpen
                     && !sidebarHover.hovered && !navHover.hovered
                     && !searchHover.hovered && !bottomHover.hovered
            property real lastFactor: 1.0
            onActiveChanged: { lastFactor = 1.0 }
            onScaleChanged: {
                if (!active) return
                var factor = scale / Math.max(0.0001, lastFactor)
                window.changeZoom(factor)
                lastFactor = scale
            }
        }
        DragHandler {
            id: canvasDrag
            target: null
            acceptedButtons: Qt.LeftButton
            // Overlay hover regions disable panning before the gesture begins.
            enabled: window.activePage === "Launch" && !window.instancePickerOpen && !canvasPinch.active && !sidebarHover.hovered && !navHover.hovered && !searchHover.hovered && !statusHover.hovered && !bottomHover.hovered
            onTranslationChanged: {
                window.panX += translation.x - previousTranslation.x
                window.panY += translation.y - previousTranslation.y
                previousTranslation = translation
            }
            property point previousTranslation: Qt.point(0,0)
            onActiveChanged: if (!active) previousTranslation = Qt.point(0,0)
        }
        WheelHandler {
            target: null
            enabled: window.activePage === "Launch" && !window.instancePickerOpen && !canvasPinch.active
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                if (window.activePage !== "Launch" || window.instancePickerOpen || sidebarHover.hovered || navHover.hovered || searchHover.hovered || bottomHover.hovered) return
                if (event.modifiers & Qt.ControlModifier) {
                    var dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y
                    if (dy !== 0) window.changeZoom(Math.exp(dy * 0.0015))
                } else {
                    window.panX += event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x * .55
                    window.panY += event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y * .55
                }
            }
        }
    }

    } // sceneLayer

    // Unified Apple Music-inspired compact navigation.
    GlassPane {
        id: topBar
        objectName: "topBar"
        backdropBlur: false // The full-window compositor below handles blur.
        color: window.materialTint
        z: 50
        visible: window.sidebarProgress < 0.999
        opacity: 1.0 - window.sidebarProgress
        enabled: window.sidebarProgress < 0.15
        width: 430
        height: 56
        x: (window.width - width) / 2
        y: 18
        radius: 28
        emphasized: true
        HoverHandler { id: navHover }
        Row {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 5
            Rectangle {
                width: 43; height: 44; radius: 22
                color: sidebarButtonHover.hovered ? (window.darkMode ? "#5588B8F5" : "#99C8E3FF") : "transparent"
                HoverHandler { id: sidebarButtonHover }
                // Apple Music-style split sidebar icon (sidebar currently closed).
                Canvas {
                    id: expandSidebarIcon
                    anchors.centerIn: parent
                    width: 23; height: 20
                    Connections {
                        target: window
                        function onDarkModeChanged() { expandSidebarIcon.requestPaint() }
                    }
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = window.darkMode ? "#EAF4FF" : "#23374B"
                        ctx.lineWidth = 1.8
                        ctx.lineJoin = "round"
                        ctx.beginPath()
                        ctx.moveTo(5, 2); ctx.lineTo(18, 2)
                        ctx.quadraticCurveTo(21, 2, 21, 5)
                        ctx.lineTo(21, 15); ctx.quadraticCurveTo(21, 18, 18, 18)
                        ctx.lineTo(5, 18); ctx.quadraticCurveTo(2, 18, 2, 15)
                        ctx.lineTo(2, 5); ctx.quadraticCurveTo(2, 2, 5, 2)
                        ctx.closePath(); ctx.stroke()
                        ctx.beginPath(); ctx.moveTo(8.5, 2); ctx.lineTo(8.5, 18); ctx.stroke()
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.sidebarMode = true
                }
            }
            Repeater {
                model: ["Launch", "Download", "Settings"]
                delegate: Rectangle {
                    required property string modelData
                    width: 100; height: 44; radius: 22
                    color: window.activePage === modelData
                           ? (window.darkMode ? "#5588B8F5" : "#99C8E3FF") : "transparent"
                    border.width: window.activePage === modelData ? 1 : 0
                    border.color: window.darkMode ? "#55D5EDFF" : "#80FFFFFF"
                    Behavior on color { ColorAnimation { duration: window.motionMs } }
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: window.ink
                        font.pixelSize: 13
                        font.bold: window.activePage === modelData
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        preventStealing: true
                        onClicked: window.activePage = modelData
                    }
                }
            }
            Rectangle {
                width: 43; height: 44; radius: 22
                color: window.searchExpanded ? (window.darkMode ? "#5588B8F5" : "#99C8E3FF") : "transparent"
                Text { anchors.centerIn: parent; text: "⌕"; font.pixelSize: 27; color: window.ink }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.toggleSearch()
                }
            }
        }
    }

    // Account access in compact-navigation mode, aligned to the upper-right.
    GlassPane {
        id: compactAccountButton
        backdropBlur: false // Disable misaligned local scene sampling; keep glass tint and highlight
        z: 72
        visible: window.sidebarProgress < 0.999
        // Disappear in place; do not travel into the sidebar profile footer.
        opacity: Math.max(0, 1.0 - window.sidebarProgress * 4)
        enabled: window.sidebarProgress < 0.10
        width: 48; height: 48
        x: window.width - width - 30
        y: 22
        radius: 24
        selectedGlass: window.accountMenuOpen
        HoverHandler { id: accountButtonHover }
        Rectangle {
            anchors.centerIn: parent
            width: 30; height: 30; radius: 15
            color: window.darkMode ? "#476B8CA7" : "#8BC4E2F3"
            Text { anchors.centerIn: parent; text: "☺"; color: window.ink; font.pixelSize: 18 }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: window.toggleAccountMenu()
        }
    }

    GlassPane {
        id: sidebar
        objectName: "sidebar"
        z: 60
        // Sidebar mode is a full-height, edge-to-edge navigation rail.
        visible: window.sidebarProgress > 0.001
        x: -width * (1.0 - window.sidebarProgress)
        opacity: Math.min(1, window.sidebarProgress * 1.7)
        enabled: window.sidebarProgress > 0.85
        y: 0
        width: 282
        height: window.height
        // The full-height navigation rail never needs a rounded floating frame.
        radius: 0
        emphasized: true
        // Full-window aligned blur is shared with the dock and navigation below.
        color: window.materialTint
        clip: true
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 1
            color: window.darkMode ? "#55FFFFFF" : "#B5FFFFFF"
        }
        border.width: 0
        // This hit-test layer consumes canvas gestures while leaving children interactive.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            hoverEnabled: true
            preventStealing: true
            propagateComposedEvents: false
            onPressed: function(mouse) { mouse.accepted = true }
            onWheel: function(wheel) { wheel.accepted = true }
        }
        Behavior on x { NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
        Behavior on height { NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
        HoverHandler { id: sidebarHover }
        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.InOutCubic } }
        // Scrollable sidebar content is clipped ABOVE the fixed account footer.
        // Keep all navigation/instance/download elements clear of the account area.
        Flickable {
            id: sidebarScroll
            x: 22
            y: 28
            width: sidebar.width - 44
            height: Math.max(0, sidebarAccountFooter.y - y - 14)
            clip: true
            contentWidth: width
            contentHeight: sidebarContent.implicitHeight + 10
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {
                policy: sidebarScroll.contentHeight > sidebarScroll.height
                        ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
            }
            Column {
                id: sidebarContent
                width: sidebarScroll.width
                spacing: 13
            Row {
                width: parent.width
                height: 42
                spacing: 8
                Text {
                    text: "Project Glass"
                    color: ink
                    font.pixelSize: 23
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 50
                }
                Rectangle {
                    width: 42; height: 40; radius: 20
                    color: sidebarCloseHover.hovered ? (window.darkMode ? "#5588B8F5" : "#99C8E3FF") : "transparent"
                    HoverHandler { id: sidebarCloseHover }
                    // Apple Music-style collapse icon (sidebar currently open).
                    Canvas {
                        id: collapseSidebarIcon
                        anchors.centerIn: parent
                        width: 23; height: 20
                        Connections {
                            target: window
                            function onDarkModeChanged() { collapseSidebarIcon.requestPaint() }
                        }
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = window.darkMode ? "#EAF4FF" : "#23374B"
                            ctx.lineWidth = 1.8
                            ctx.lineJoin = "round"
                            ctx.beginPath()
                        ctx.moveTo(5, 2); ctx.lineTo(18, 2)
                        ctx.quadraticCurveTo(21, 2, 21, 5)
                        ctx.lineTo(21, 15); ctx.quadraticCurveTo(21, 18, 18, 18)
                        ctx.lineTo(5, 18); ctx.quadraticCurveTo(2, 18, 2, 15)
                        ctx.lineTo(2, 5); ctx.quadraticCurveTo(2, 2, 5, 2)
                        ctx.closePath(); ctx.stroke()
                            ctx.beginPath(); ctx.moveTo(2, 7); ctx.lineTo(21, 7); ctx.stroke()
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.sidebarMode = false
                    }
                }
            }
            Column {
                visible: window.sidebarMode
                width: parent.width; spacing: 10
                Repeater {
                    model: ["Launch", "Download", "Settings"]
                    delegate: Rectangle {
                        required property string modelData
                        width: parent.width; height: 42; radius: window.innerRadius
                        // Same selected-glass treatment as the top navigation.
                        color: window.activePage === modelData
                               ? (window.darkMode ? "#5588B8F5" : "#99C8E3FF") : "transparent"
                        border.width: window.activePage === modelData ? 1 : 0
                        border.color: window.darkMode ? "#55D5EDFF" : "#80FFFFFF"
                        Behavior on color { ColorAnimation { duration: window.motionMs } }
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 16
                            anchors.rightMargin: 16
                            spacing: 12
                            // Fixed-width icon column aligns every navigation label.
                            Text {
                                width: 20
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                text: modelData === "Launch" ? "▶" : (modelData === "Download" ? "↓" : "⚙")
                                color: window.activePage === modelData ? window.accent : window.ink
                                font.family: "SF Pro Text"
                                font.pixelSize: modelData === "Launch" ? 13 : 18
                            }
                            Text {
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: modelData
                                color: window.ink
                                font.pixelSize: 14
                                font.bold: window.activePage === modelData
                            }
                        }
                        MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        preventStealing: true
                        onClicked: function(mouse) {
                            mouse.accepted = true
                            window.activePage = modelData
                        }
                    }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: outline }

                // Collapsible sidebar instance section. Installed instances follow
                // the exact same Name/Smart ordering used by the canvas.
                Rectangle {
                    width: parent.width
                    height: 34
                    radius: 12
                    color: instancesHeaderHover.hovered ? "#16FFFFFF" : "transparent"
                    HoverHandler { id: instancesHeaderHover }
                    Row {
                        anchors.fill: parent
                        spacing: 8
                        Text {
                            width: parent.width - 28
                            anchors.verticalCenter: parent.verticalCenter
                            text: "INSTANCES  ·  " + window.sortMode.toUpperCase()
                            color: muted
                            font.pixelSize: 10
                            font.letterSpacing: 1.1
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: window.sidebarInstancesExpanded ? "⌃" : "⌄"
                            color: muted
                            font.pixelSize: 16
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: window.sidebarInstancesExpanded = !window.sidebarInstancesExpanded
                    }
                }

                Column {
                    visible: window.sidebarInstancesExpanded
                    width: parent.width
                    spacing: 3

                    Repeater {
                        model: window.sidebarInstalledCards()
                        delegate: Rectangle {
                            required property var modelData
                            width: sidebar.width - 44
                            height: 35
                            radius: 13
                            color: selectedId === modelData.key ? "#308BC4EA" : "transparent"
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: 12
                                text: modelData.label
                                color: ink
                                font.pixelSize: 13
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton
                                preventStealing: true
                                onClicked: function(mouse) {
                                    mouse.accepted = true
                                    window.chooseCard(modelData)
                                }
                            }
                        }
                    }

                }

                    // Sidebar download remains available with instances collapsed.
                    Rectangle {
                        width: sidebar.width - 44
                        height: 38
                        radius: 13
                        color: window.sidebarQuickDownloadExpanded ? "#258BC4EA" :
                               (quickDownloadHover.hovered ? "#16FFFFFF" : "transparent")
                        HoverHandler { id: quickDownloadHover }
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 11
                            anchors.rightMargin: 10
                            spacing: 9
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "↓"
                                color: window.accent
                                font.pixelSize: 18
                                width: 20
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 58
                                text: "Quick Download"
                                color: window.ink
                                font.pixelSize: 13
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: window.sidebarQuickDownloadExpanded ? "⌃" : "⌄"
                                color: window.muted
                                font.pixelSize: 15
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                window.sidebarQuickDownloadExpanded = !window.sidebarQuickDownloadExpanded
                                if (window.sidebarQuickDownloadExpanded) {
                                    window.activePage = "Download"
                                    window.downloadCategory = "Versions"
                                    window.downloadSelection = null
                                }
                            }
                        }
                    }

                    GlassPane {
                        visible: window.sidebarQuickDownloadExpanded
                        width: sidebar.width - 44
                        height: 142
                        radius: 17
                        subtle: true
                        Column {
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8
                            GlassSelect {
                                width: parent.width
                                options: ["1.21.8", "1.21.5", "1.21.1", "1.20.1"]
                                selected: window.sidebarQuickVersion
                                onChosen: function(value) { window.sidebarQuickVersion = value }
                            }
                            GlassSelect {
                                width: parent.width
                                options: ["Fabric", "NeoForge", "Quilt", "Vanilla"]
                                selected: window.sidebarQuickLoader
                                onChosen: function(value) { window.sidebarQuickLoader = value }
                            }
                            Rectangle {
                                width: parent.width
                                height: 34
                                radius: 15
                                color: window.darkMode ? "#7E79C9ED" : "#5D8ED7"
                                Text {
                                    anchors.centerIn: parent
                                    text: "↓  Download"
                                    color: window.darkMode ? "#102638" : "white"
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        window.beginDownload({ category: "Versions", name: "Minecraft " + window.sidebarQuickVersion, version: window.sidebarQuickVersion })
                                    }
                                }
                            }
                        }
                    }
            }
            Column {
                visible: !window.sidebarMode
                width: parent.width; spacing: 15
                Text { text: "SELECTED INSTANCE"; color: muted; font.pixelSize: 10; font.letterSpacing: 1.2 }
                Text { text: window.selectedLabel(); color: ink; font.pixelSize: 21; font.bold: true; width: parent.width; elide: Text.ElideRight }
                Text { text: window.selectedVersion(); color: muted; font.pixelSize: 12 }
                Text { text: "Drag empty canvas to pan · Double-click card to activate"; color: muted; font.pixelSize: 11; wrapMode: Text.WordWrap; width: parent.width }
            }
            }
        }
    }

    // Sidebar account footer, similar to Apple Music's bottom-left profile.
    Rectangle {
        id: sidebarAccountFooter
        z: 67
        visible: window.sidebarProgress > 0.001
        enabled: window.sidebarProgress > 0.85
        // The sidebar profile fades in only after the sliding sidebar settles.
        opacity: Math.max(0, Math.min(1, (window.sidebarProgress - 0.75) * 4))
        x: sidebar.x + 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: sidebar.width - 44
        height: 68
        radius: window.macOSWindowCornerRadius
        color: footerHover.hovered ? (window.darkMode ? "#4C7594B5" : "#7ACAE6FA") : "#18FFFFFF"
        border.width: footerHover.hovered ? 1 : 0
        border.color: window.outline
        HoverHandler { id: footerHover }
        Row {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 11
            Rectangle {
                width: 41; height: 41; radius: 20.5
                anchors.verticalCenter: parent.verticalCenter
                color: window.darkMode ? "#527FA0C4" : "#9ED5EBFC"
                Text { anchors.centerIn: parent; text: "☺"; font.pixelSize: 22; color: window.ink }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                width: parent.width - 78
                Text { text: window.accountDisplayName; color: window.ink; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; width: parent.width }
                Text { text: window.accountProvider; color: window.muted; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
            }
            Text { anchors.verticalCenter: parent.verticalCenter; text: "⌄"; color: window.muted; font.pixelSize: 18 }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: window.toggleAccountMenu()
        }
    }

    // Prototype 09.25.1: one full-window backdrop capture and one full-window
    // rounded alpha mask. The two textures share exactly the window's origin,
    // extent, and device-pixel scaling. No per-panel sourceRect or crop.
    // The scene contains only the canvas/background, never its glass overlays.
    ShaderEffectSource {
        id: dockSceneTexture
        anchors.fill: parent
        sourceItem: window.dockLiveBlur ? sceneLayer : null
        hideSource: false
        live: window.dockLiveBlur
        recursive: false
        visible: false
    }
    Item {
        id: dockMaskShape
        anchors.fill: parent
        visible: false
        Rectangle {
            x: bottomDock.x
            y: bottomDock.y
            width: bottomDock.width
            height: bottomDock.height
            radius: bottomDock.radius
            color: "white"
        }
    }
    ShaderEffectSource {
        id: dockMaskTexture
        anchors.fill: parent
        sourceItem: dockMaskShape
        hideSource: true
        live: window.dockLiveBlur
        visible: false
    }
    MultiEffect {
        id: dockBackdropBlur
        anchors.fill: parent
        z: 84
        source: dockSceneTexture
        maskEnabled: true
        maskSource: dockMaskTexture
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.0
        blurEnabled: true
        blur: Math.max(0, Math.min(1, window.dockBlurAmount))
        blurMax: 40
        autoPaddingEnabled: false
        visible: window.dockLiveBlur
    }

    // 09.25: compact-navigation glass uses the SAME scene texture as the
    // launch bar, with a separate full-window alpha mask. It never crops the
    // texture or applies its blur over navigation icons / labels.
    Item {
        id: navMaskShape
        anchors.fill: parent
        visible: false
        Rectangle {
            x: topBar.x
            y: topBar.y
            width: topBar.width
            height: topBar.height
            radius: topBar.radius
            color: "white"
            opacity: topBar.opacity
        }
    }
    ShaderEffectSource {
        id: navMaskTexture
        anchors.fill: parent
        sourceItem: navMaskShape
        hideSource: true
        live: window.dockLiveBlur && window.sidebarProgress < 1
        visible: false
    }
    MultiEffect {
        id: navBackdropBlur
        anchors.fill: parent
        z: 49 // Behind topBar (50), so labels and icons remain sharp.
        source: dockSceneTexture
        maskEnabled: true
        maskSource: navMaskTexture
        maskThresholdMin: 0.5
        maskSpreadAtMin: 0.0
        blurEnabled: true
        blur: Math.max(0, Math.min(1, window.dockBlurAmount))
        blurMax: 40
        autoPaddingEnabled: false
        visible: window.dockLiveBlur && window.sidebarProgress < 0.999
    }

    Item {
        id: sidebarMaskShape
        anchors.fill: parent; visible: false
        Rectangle {
            x: sidebar.x; y: sidebar.y; width: sidebar.width; height: sidebar.height
            radius: sidebar.radius; color: "white"; opacity: sidebar.opacity
        }
    }
    ShaderEffectSource {
        id: sidebarMaskTexture
        anchors.fill: parent; sourceItem: sidebarMaskShape
        hideSource: true; live: window.dockLiveBlur && window.sidebarProgress > 0.999
        visible: false
    }
    MultiEffect {
        objectName: "sidebarBackdropBlur"
        anchors.fill: parent; z: 59
        source: dockSceneTexture
        maskEnabled: true; maskSource: sidebarMaskTexture
        maskThresholdMin: 0.5; maskSpreadAtMin: 0
        blurEnabled: true; blur: window.dockBlurAmount; blurMax: 40
        autoPaddingEnabled: false
        // Stop sampling as soon as the rail starts closing. A cached blur mask
        // otherwise leaves a rectangular ghost in the old sidebar position.
        visible: window.dockLiveBlur && window.sidebarProgress > 0.999
    }

    // Apple Music-inspired persistent launch bar.
    GlassPane {
        id: bottomDock
        objectName: "bottomDock"
        backdropBlur: false // Never enable old per-panel sourceRect blur.
        // A separate, aligned full-window compositor sits behind this pane.
        // Keep sampled background text as soft shapes, never as a second
        // readable/ghosted text layer. Foreground labels remain crisp above.
        color: window.materialTint
        z: 85
        width: Math.min(560, window.width - window.contentLeft - 48)
        height: 68
        // Center the launch bar in the available content area, not at
        // the sidebar edge. The account panel remains stationary.
        x: window.contentLeft + (window.width - window.contentLeft - width) / 2
        visible: !macWindowMetrics.nativeGlassDock
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        radius: height / 2; emphasized: true
        HoverHandler { id: bottomHover }
        MouseArea {
            objectName: "dockInputShield"
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
            hoverEnabled: true; preventStealing: true
            propagateComposedEvents: false
            scrollGestureEnabled: true
            onPressed: function(mouse) { mouse.accepted = true }
            onDoubleClicked: function(mouse) { mouse.accepted = true }
            onWheel: function(wheel) { wheel.accepted = true }
        }
        Row {
            anchors.fill: parent; anchors.margins: 10; spacing: 12
            Rectangle {
                id: dockInstanceIcon
                transform: Translate { x: 6 }
                width: 46; height: 46; radius: 14
                color: window.instancePickerOpen ? (window.darkMode ? "#5587B9E7" : "#A9DDF4FF") : "#305B7890"
                border.width: window.instancePickerOpen ? 1 : 0
                border.color: window.accent
                Text { anchors.centerIn: parent; text: "◆"; color: accent; font.pixelSize: 25 }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: window.instancePickerOpen = !window.instancePickerOpen
                }
            }
            Column {
                transform: Translate { x: 6 }
                anchors.verticalCenter: parent.verticalCenter; spacing: 4
                width: Math.max(100, bottomDock.width - 210)
                Text { text: window.selectedLabel(); color: ink; font.bold: true; font.pixelSize: 14; width: parent.width; elide: Text.ElideRight }
                Text { text: window.selectedVersion(); color: muted; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight }
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: 105; height: 42; radius: 21
                color: darkMode ? "#91A9DCEF" : "#5287D3"
                Text { anchors.centerIn: parent; text: "▶  Launch"; color: darkMode ? "#122638" : "white"; font.bold: true; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true; onClicked: window.statusMessage = "Prototype only · Launch is not connected to Prism" }
            }
        }
    }
    Connections {
        target: bottomDock
        function onXChanged() { macWindowMetrics.setDockGeometry(bottomDock.x, bottomDock.y, bottomDock.width, bottomDock.height, bottomDock.radius) }
        function onYChanged() { macWindowMetrics.setDockGeometry(bottomDock.x, bottomDock.y, bottomDock.width, bottomDock.height, bottomDock.radius) }
        function onWidthChanged() { macWindowMetrics.setDockGeometry(bottomDock.x, bottomDock.y, bottomDock.width, bottomDock.height, bottomDock.radius) }
        function onHeightChanged() { macWindowMetrics.setDockGeometry(bottomDock.x, bottomDock.y, bottomDock.width, bottomDock.height, bottomDock.radius) }
        function onRadiusChanged() { macWindowMetrics.setDockGeometry(bottomDock.x, bottomDock.y, bottomDock.width, bottomDock.height, bottomDock.radius) }
    }

    // Dock-style upward instance picker. Native ListView scrolling works
    // with mouse wheel and macOS trackpad two-finger gestures.
    MouseArea {
        z: 75
        anchors.fill: parent
        visible: window.instancePickerOpen
        onClicked: window.instancePickerOpen = false
    }
    GlassPane {
        id: instancePicker
        backdropBlur: false // Disable misaligned local scene sampling; keep glass tint and highlight
        z: 95
        visible: window.instancePickerOpen
        x: bottomDock.x
        y: bottomDock.y - height - 12
        width: Math.min(310, window.width - 32)
        height: Math.min(370, instances.count * 58 + 56)
        radius: 24
        emphasized: true
        clip: true
        transformOrigin: Item.Bottom
        scale: window.instancePickerOpen ? 1 : 0.94
        opacity: window.instancePickerOpen ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5
            Text {
                text: "INSTANCES  ·  SCROLL TO BROWSE"
                color: window.muted
                font.pixelSize: 10
                font.letterSpacing: 0.7
                leftPadding: 10
                height: 28
                verticalAlignment: Text.AlignVCenter
            }
            ListView {
                id: pickerList
                width: parent.width
                height: parent.height - 33
                model: instances
                clip: true
                interactive: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: 3
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    required property string key
                    required property string label
                    required property string version
                    required property bool installed
                    required property int index
                    width: pickerList.width - 8
                    height: 54
                    radius: 14
                    color: window.selectedId === key ? (window.darkMode ? "#5088B8F0" : "#88BDE7FF") : "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: installed ? "◆" : "↓"
                            color: window.accent
                            font.pixelSize: 19
                            width: 25
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 60
                            spacing: 3
                            Text { text: label; color: window.ink; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; width: parent.width }
                            Text { text: version; color: window.muted; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            window.chooseCard(instances.get(index))
                            window.instancePickerOpen = false
                        }
                    }
                }
            }
        }
    }
    onInstancePickerOpenChanged: {
        if (instancePickerOpen) {
            for (var i = 0; i < instances.count; ++i) {
                if (instances.get(i).key === selectedId) {
                    pickerList.positionViewAtIndex(i, ListView.Contain)
                    break
                }
            }
        }
    }

    // Dedicated content pages replace the canvas, never float above it.
    Item {
        id: pageContent
        z: 12
        visible: window.activePage === "Settings"
        x: window.contentLeft + 28
        y: window.sidebarMode ? 28 : 108
        width: window.width - window.contentLeft - 56
        height: Math.max(0, window.height - y - bottomDock.height - 44)
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.InOutCubic } }
        Flickable {
            anchors.fill: parent
            contentWidth: width; contentHeight: settingsContent.implicitHeight + 20
            clip: true; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }
        Column {
            id: settingsContent
            width: parent.width
            spacing: 24
            Text { text: window.activePage; font.pixelSize: 32; font.bold: true; color: ink }
            Text {
                text: window.activePage === "Settings" ? "Appearance & layout" : "Minecraft versions and loaders"
                font.pixelSize: 15; color: muted
            }
            Column {
                visible: window.activePage === "Settings"
                width: Math.min(660, pageContent.width)
                spacing: 18
                GlassPane {
                    width: parent.width; height: 74; radius: window.settingsCardRadius
                    Row {
                        anchors.fill: parent; anchors.margins: 20; spacing: 12
                        Text { text: "Smart layout"; color: ink; font.pixelSize: 15; width: parent.width - 100; anchors.verticalCenter: parent.verticalCenter }
                        Switch { checked: window.smartLayout; anchors.verticalCenter: parent.verticalCenter; onToggled: window.smartLayout = checked }
                    }
                }
                GlassPane {
                    width: parent.width; height: 74; radius: window.settingsCardRadius
                    Row {
                        anchors.fill: parent; anchors.margins: 20; spacing: 12
                        Text { text: "Quick cards"; color: ink; font.pixelSize: 15; width: parent.width - 100; anchors.verticalCenter: parent.verticalCenter }
                        Switch { checked: window.quickCards; anchors.verticalCenter: parent.verticalCenter; onToggled: window.quickCards = checked }
                    }
                }
                GlassPane {
                    width: parent.width; height: 76; radius: window.settingsCardRadius
                    Row {
                        anchors.fill: parent; anchors.margins: 20; spacing: 12
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            width: parent.width - 100
                            Text { text: "Live glass blur: sidebar, dock & navigation"; color: ink; font.pixelSize: 14 }
                            Text { text: "All three surfaces share the same material"; color: muted; font.pixelSize: 11 }
                        }
                        Switch {
                            checked: window.dockLiveBlur
                            anchors.verticalCenter: parent.verticalCenter
                            onToggled: window.dockLiveBlur = checked
                        }
                    }
                }
                GlassPane {
                    width: parent.width; height: 100; radius: window.settingsCardRadius
                    Column {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        Row {
                            width: parent.width
                            Text { text: "Glass blur strength"; font.pixelSize: 14; color: ink; width: parent.width - 60 }
                            Text { text: Math.round(window.dockBlurAmount * 100) + "%"; font.pixelSize: 13; color: muted; horizontalAlignment: Text.AlignRight; width: 60 }
                        }
                        Row {
                            width: parent.width
                            spacing: 12
                            Text { text: "0"; font.pixelSize: 12; color: muted; anchors.verticalCenter: parent.verticalCenter }
                            Slider {
                                id: dockBlurSlider
                                width: parent.width - 75
                                from: 0
                                to: 1
                                stepSize: 0.01
                                value: window.dockBlurAmount
                                enabled: window.dockLiveBlur
                                onMoved: window.dockBlurAmount = value
                                // Native control uses the Basic style selected in main.cpp.
                            }
                            Text { text: "100"; font.pixelSize: 12; color: muted; anchors.verticalCenter: parent.verticalCenter }
                        }
                    }
                }
                GlassPane {
                    width: parent.width; height: 100
                    Column {
                        anchors.fill: parent; anchors.margins: 16; spacing: 8
                        Row {
                            width: parent.width
                            Text { text: "Glass opacity · sidebar, dock & navigation"; color: window.ink; font.pixelSize: 13; width: parent.width - 50 }
                            Text { text: Math.round(window.glassOpacity * 100) + "%"; color: window.muted; width: 50; horizontalAlignment: Text.AlignRight }
                        }
                        Slider {
                            width: parent.width; from: 0.1; to: 1; stepSize: 0.01
                            value: window.glassOpacity
                            onMoved: window.glassOpacity = value
                        }
                    }
                }

            }

        }
        }
    }


    // Download uses an independent query so instance search remains untouched.
    Item {
        id: downloadPage
        z: 12
        visible: window.activePage === "Download" && !window.downloadSelection
        x: window.contentLeft + 28
        y: window.sidebarMode ? 28 : 92
        width: Math.max(0, window.width - window.contentLeft - 56)
        height: Math.max(0, window.height - y)
        ColumnLayout {
            anchors.fill: parent
            spacing: 12
            RowLayout {
                Layout.fillWidth: true
                GlassSelect {
                    Layout.preferredWidth: 148
                    Layout.preferredHeight: 42
                    controlHeight: 42
                    cornerRadius: window.downloadControlRadius
                    options: ["Modrinth", "CurseForge"]
                    selected: window.downloadProvider
                    onChosen: function(value) { window.downloadProvider = value }
                }
                TextField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Math.min(360, downloadPage.width * 0.52)
                    Layout.preferredHeight: 42
                    placeholderText: "Search " + window.downloadCategory.toLowerCase() + "…"
                    text: window.downloadSearch
                    onTextEdited: window.downloadSearch = text
                    color: window.ink
                    background: GlassPane { radius: window.downloadControlRadius; subtle: true }
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                Flickable {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    Layout.minimumWidth: 0
                    contentWidth: categoryRow.width; contentHeight: height
                    clip: true; boundsBehavior: Flickable.StopAtBounds
                    Row {
                        id: categoryRow; spacing: 7
                        Repeater {
                            model: window.downloadCategories
                            delegate: GlassPane {
                                required property string modelData
                                width: categoryLabel.implicitWidth + 28; height: 40; radius: 20
                                selectedGlass: window.downloadCategory === modelData
                                subtle: true
                                Text { id: categoryLabel; anchors.centerIn: parent; text: modelData; color: window.ink; font.pixelSize: 13 }
                                TapHandler { onTapped: window.openDownloadCategory(modelData) }
                            }
                        }
                    }
                }
                GlassPane {
                    Layout.preferredWidth: 72; Layout.preferredHeight: 42; radius: window.downloadControlRadius
                    Text { anchors.centerIn: parent; text: "Refresh"; color: window.ink; font.pixelSize: 12 }
                    TapHandler { enabled: !downloadData.catalogueBusy; onTapped: window.refreshCatalogue() }
                }
                GlassSelect {
                    visible: window.downloadCategory === "Mods"
                    Layout.preferredWidth: 132
                    Layout.preferredHeight: 42
                    controlHeight: 42
                    cornerRadius: window.downloadControlRadius
                    options: ["All loaders", "Fabric", "Forge", "NeoForge", "Quilt"]
                    selected: window.downloadLoaderFilter
                    onChosen: function(value) { window.downloadLoaderFilter = value }
                }
                GlassSelect {
                    Layout.preferredWidth: 142
                    Layout.preferredHeight: 42
                    controlHeight: 42
                    cornerRadius: window.downloadControlRadius
                    options: ["Featured", "Newest", "Updated"]
                    selected: window.downloadSort
                    onChosen: function(value) { window.downloadSort = value }
                }
            }
            RowLayout {
                visible: downloadData.catalogueError.length > 0
                Layout.fillWidth: true
                Text { text: downloadData.catalogueError; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: window.muted }
                GlassPane {
                    visible: window.downloadProvider !== "CurseForge" || window.downloadCategory === "Versions"
                    Layout.preferredWidth: 72; Layout.preferredHeight: 34; radius: 17
                    Text { anchors.centerIn: parent; text: "Retry"; color: window.ink }
                    TapHandler { onTapped: downloadData.retryCatalogue() }
                }
            }
            ListView {
                id: downloadList
                objectName: "downloadList"
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; spacing: 12
                model: downloadRows
                boundsBehavior: Flickable.StopAtBounds
                // Append preserves scroll position. New queries reset below via the query key.
                property string displayedQuery: ""
                function maybeFetchMore() {
                    if (window.activePage !== "Download" || window.downloadSelection || downloadData.catalogueBusy || downloadData.catalogueError || !downloadData.hasMore) return
                    if (contentY + height >= contentHeight - 2 * 142)
                        downloadData.loadCatalogue(window.downloadCategory, window.downloadSearch, window.downloadSort, true, window.downloadLoaderFilter, window.downloadProvider)
                }
                onContentYChanged: autoPage.restart()
                onHeightChanged: autoPage.restart()
                onContentHeightChanged: autoPage.restart()
                Connections {
                    target: downloadData
                    function onCatalogueBusyChanged() { autoPage.restart() }
                    function onCatalogueKeyChanged() {
                        if (downloadList.displayedQuery !== downloadData.catalogueKey) {
                            downloadList.displayedQuery = downloadData.catalogueKey
                            downloadList.positionViewAtBeginning()
                        }
                    }
                }
                Timer { id: autoPage; interval: 80; onTriggered: downloadList.maybeFetchMore() }
                footer: Item {
                    width: downloadList.width
                    height: bottomDock.height + 32
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter; y: 8
                        text: downloadData.catalogueBusy ? "Loading…" : ""
                        color: window.muted; font.pixelSize: 12
                    }
                }
                ScrollBar.vertical: ScrollBar { }
                delegate: GlassPane {
                    id: downloadCard
                    required property var entry
                    readonly property var modelData: entry
                    width: downloadList.width
                    readonly property bool narrow: width < 650
                    height: narrow ? 142 : 118
                    radius: window.macOSWindowCornerRadius
                    selectedGlass: modelData.category === "Versions" && modelData.version === window.sidebarQuickVersion
                    readonly property real padding: 16
                    Rectangle {
                        id: iconTile
                        objectName: "downloadIconTile"
                        x: downloadCard.padding; y: downloadCard.padding
                        width: downloadCard.height - 2 * downloadCard.padding; height: width
                        radius: 18
                        color: window.darkMode ? "#355B7890" : "#A3DEECF8"
                        Image {
                            id: projectIcon
                            anchors.fill: parent
                            source: downloadCard.modelData.icon || ""
                            asynchronous: true; fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: MultiEffect {
                                maskEnabled: true; maskSource: iconMask
                                maskThresholdMin: 0.5; maskSpreadAtMin: 0
                            }
                        }
                        Rectangle {
                            id: iconMask
                            width: iconTile.width; height: iconTile.height
                            radius: iconTile.radius
                            color: "white"; layer.enabled: true; visible: false
                        }
                        Text { visible: projectIcon.status !== Image.Ready; anchors.centerIn: parent; text: downloadCard.modelData.badge; textFormat: Text.PlainText; color: window.accent; font.pixelSize: 12; font.bold: true }
                        Rectangle {
                            anchors.fill: parent; radius: parent.radius
                            color: "transparent"; border.width: 1; border.color: window.outline
                        }
                    }
                    Column {
                        x: iconTile.x + iconTile.width + 16
                        y: downloadCard.narrow ? downloadCard.padding : (downloadCard.height - height) / 2
                        width: Math.max(0, downloadCard.width - x - downloadCard.padding - (downloadCard.narrow ? 0 : 128))
                        spacing: 8
                        Text { width: parent.width; text: downloadCard.modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight; color: window.ink; font.pixelSize: 18; font.bold: true }
                        Text { width: parent.width; text: downloadCard.modelData.detail; textFormat: Text.PlainText; color: window.muted; font.pixelSize: 12; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 16
                        y: downloadCard.narrow ? downloadCard.height - 36 - downloadCard.padding : (downloadCard.height - 36) / 2
                        spacing: 10
                        GlassPane {
                            width: 112; height: 36; radius: 18; selectedGlass: true
                            color: window.darkMode ? "#BB79C9ED" : "#397AD1"
                            Text { anchors.centerIn: parent; text: "↓  Download"; color: window.darkMode ? "#102638" : "white"; font.pixelSize: 13; font.bold: true }
                            TapHandler {
                                onTapped: {
                                    if (downloadCard.modelData.category === "Versions") window.sidebarQuickVersion = downloadCard.modelData.version
                                    window.beginDownload(downloadCard.modelData)
                                }
                            }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: downloadList.count === 0 && !downloadData.catalogueError
                    text: downloadData.catalogueBusy ? "Loading catalogue…" : "No matches · Try another search"
                    color: window.muted
                }
            }

        }
    }


    Item {
        id: releasePage
        z: 12
        visible: window.activePage === "Download" && window.downloadSelection !== null
        x: window.contentLeft + 28; y: window.sidebarMode ? 28 : 108
        width: Math.max(0, window.width - window.contentLeft - 56)
        height: Math.max(0, window.height - y - bottomDock.height - 44)
        readonly property bool game: window.downloadSelection !== null && window.downloadSelection.category === "Versions"
        ColumnLayout {
            anchors.fill: parent; spacing: 12
            RowLayout {
                Layout.fillWidth: true
                GlassPane {
                    Layout.preferredWidth: 88; Layout.preferredHeight: 36; radius: 18
                    Text { anchors.centerIn: parent; text: "‹  Back"; color: window.ink }
                    TapHandler { onTapped: window.downloadSelection = null }
                }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideRight
                    text: window.downloadSelection ? window.downloadSelection.name : ""
                    textFormat: Text.PlainText
                    color: window.ink; font.pixelSize: 24; font.bold: true
                }
            }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: releasePage.game ? "Choose a loader, then choose its version" : "Target: " + window.selectedLabel() + " · " + window.selectedVersion()
                color: window.muted; font.pixelSize: 14
            }
            Text {
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: releasePage.game ? "Loader metadata · Prism Launcher · Installation is not connected" : "Releases from Modrinth · Current instance first · Installation is not connected"
                color: window.muted; font.pixelSize: 12
            }
            RowLayout {
                visible: releasePage.game; Layout.fillWidth: true
                Text { text: "Mod loader"; color: window.ink; Layout.fillWidth: true }
                GlassSelect {
                    Layout.preferredWidth: 170
                    options: ["Vanilla", "Fabric", "Forge", "NeoForge", "Quilt"]
                    selected: window.selectedLoader
                    onChosen: function(value) { window.selectedLoader = value; window.selectedRelease = "" }
                }
            }
            Text {
                visible: releasePage.game && window.selectedLoader === "Vanilla"
                text: "Vanilla uses the selected Minecraft version; no loader version is needed."
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: window.muted
            }
            RowLayout {
                visible: downloadData.releaseBusy || downloadData.releaseError.length > 0 || (window.releaseChoices.length === 0 && !downloadData.vanillaValid)
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; color: window.muted
                    text: downloadData.releaseBusy ? "Loading versions…" : downloadData.releaseError || "No versions listed for this selection. Try another loader or project."
                }
                GlassPane {
                    visible: !downloadData.releaseBusy
                    Layout.preferredWidth: 72; Layout.preferredHeight: 34; radius: 17
                    Text { anchors.centerIn: parent; text: "Retry"; color: window.ink }
                    TapHandler { onTapped: downloadData.retryReleases() }
                }
            }
            Text {
                visible: !releasePage.game && !downloadData.releaseBusy && window.releaseChoices.length > 0 && !window.releaseChoices.some(function(v) { return v.eligible })
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: window.muted; font.pixelSize: 12
                text: "No release matches the current instance version and loader. Other releases are shown below."
            }
            ListView {
                id: releaseList
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: !releasePage.game || window.selectedLoader !== "Vanilla"
                clip: true; spacing: 8
                model: window.releaseChoices
                section.property: "group"
                section.criteria: ViewSection.FullString
                section.delegate: Text {
                    required property string section
                    width: releaseList.width; height: 36
                    text: section + " · Newest first"; textFormat: Text.PlainText; color: window.muted
                    verticalAlignment: Text.AlignVCenter; font.pixelSize: 12
                }
                ScrollBar.vertical: ScrollBar { }
                delegate: GlassPane {
                    required property var modelData
                    width: releaseList.width - 12; height: 82; radius: 20
                    selectedGlass: window.selectedRelease === modelData.id
                    RowLayout {
                        anchors.fill: parent; anchors.margins: 16
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 6
                            Text { text: modelData.label; textFormat: Text.PlainText; color: window.ink; Layout.fillWidth: true; elide: Text.ElideRight }
                            Text { text: modelData.detail; textFormat: Text.PlainText; color: window.muted; font.pixelSize: 11; Layout.fillWidth: true; elide: Text.ElideRight }
                        }
                        Text { text: window.selectedRelease === modelData.id ? "Selected ✓" : "Select"; color: window.accent }
                    }
                    TapHandler { onTapped: window.selectedRelease = modelData.id }
                }
            }
            Item { visible: releasePage.game && window.selectedLoader === "Vanilla"; Layout.fillHeight: true }
            GlassPane {
                Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 22
                readonly property bool ready: !downloadData.releaseBusy && !downloadData.releaseError && ((releasePage.game && window.selectedLoader === "Vanilla" && downloadData.vanillaValid) || window.selectedReleaseDetails !== null)
                opacity: ready ? 1 : 0.5
                Text { anchors.centerIn: parent; text: "Preview installation"; color: window.ink; font.bold: true }
                TapHandler {
                    enabled: parent.ready
                    onTapped: window.previewDownload(window.downloadSelection.name + " · " + (releasePage.game ? window.selectedLoader : window.selectedLabel()) + " · " + (window.selectedReleaseDetails ? window.selectedReleaseDetails.label : window.downloadSelection.version))
                }
            }
        }
    }

    // Search and zoom share a single expandable liquid-glass control.
    GlassPane {
        id: searchDock
        backdropBlur: false // Disable misaligned local scene sampling; keep glass tint and highlight
        // In compact mode, the search toggle lives in topBar. Only show this
        // separate dock when the search tools are expanded. In sidebar mode
        // it doubles as the standalone top-right search button.
        visible: window.activePage === "Launch" && (window.searchExpanded || window.sidebarProgress > 0.55)
        z: 75
        // A two-phase crossfade: disappear first, swap geometry while hidden,
        // then appear at the other destination. Never draw a second search
        // icon over the compact navigation bar as the sidebar starts moving.
        readonly property bool sidebarDestination: window.sidebarProgress >= 0.5
        opacity: sidebarDestination
                 ? Math.max(0, Math.min(1, (window.sidebarProgress - 0.60) / 0.25))
                 : Math.max(0, Math.min(1, (0.40 - window.sidebarProgress) / 0.25))
        enabled: opacity > 0.95
        x: sidebarDestination ? window.width - width - 22 : (window.width - width) / 2
        y: sidebarDestination ? sidebarScroll.y + (42 - height) / 2
                              : topBar.y + topBar.height + 10
        width: window.searchExpanded ? Math.min(510, window.width - window.contentLeft - 70) : 48
        height: 48
        radius: window.pillRadius
        emphasized: true
        HoverHandler { id: searchHover }
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: searchToggle.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            visible: window.searchExpanded
            TextField {
                id: searchInput
                width: Math.max(95, parent.width - 300)
                height: 34
                placeholderText: "Search versions..."
                text: window.searchText
                onTextChanged: window.searchText = text
                color: window.ink
                font.pixelSize: 12
                background: Rectangle { color: "#16FFFFFF"; radius: 17 }
                Keys.onEscapePressed: { window.searchExpanded = false; focus = false }
            }
            GlassSelect {
                id: sortCombo
                width: 100
                height: 34
                compact: true
                options: ["Smart", "Name", "Custom"]
                selected: window.sortMode
                onChosen: function(value) { window.sortMode = value }
            }
            Slider {
                id: zoomSlider
                width: 92
                height: 34
                from: 0.55; to: 1.65; stepSize: 0
                value: window.zoom
                onMoved: window.zoom = value
                background: Rectangle {
                    x: zoomSlider.leftPadding
                    y: zoomSlider.topPadding + zoomSlider.availableHeight / 2 - height / 2
                    width: zoomSlider.availableWidth
                    height: 7; radius: 3.5
                    color: window.darkMode ? "#446F88A2" : "#A6D6E8F5"
                    border.width: 1
                    border.color: window.darkMode ? "#50D8F1FF" : "#99FFFFFF"
                    Rectangle {
                        width: zoomSlider.visualPosition * parent.width
                        height: parent.height; radius: parent.radius
                        color: window.darkMode ? "#A3BFE7FF" : "#8B75BDE9"
                    }
                }
                handle: Rectangle {
                    x: zoomSlider.leftPadding + zoomSlider.visualPosition * (zoomSlider.availableWidth - width)
                    y: zoomSlider.topPadding + zoomSlider.availableHeight / 2 - height / 2
                    width: 19; height: 19; radius: 9.5
                    color: window.darkMode ? "#F1F8FF" : "#FFFFFF"
                    border.width: 1
                    border.color: window.darkMode ? "#99D8F2FF" : "#A0A6C5D9"
                    Rectangle { anchors.centerIn: parent; width: 7; height: 7; radius: 3.5; color: window.accent }
                }
            }
            Text {
                width: 35
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(window.zoom * 100) + "%"
                color: window.ink; font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                width: 40; height: 32; radius: 16
                color: resetHover.hovered ? (window.darkMode ? "#5588B8F5" : "#99C8E3FF") : "#18FFFFFF"
                Text { anchors.centerIn: parent; text: "Reset"; color: window.ink; font.pixelSize: 11 }
                HoverHandler { id: resetHover }
                MouseArea { anchors.fill: parent; onClicked: { window.resetCanvas(); window.searchText = "" } }
            }
        }
        Rectangle {
            id: searchToggle
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40; radius: 20
            color: "#20FFFFFF"
            Text { anchors.centerIn: parent; text: window.searchExpanded ? "×" : "⌕"; font.pixelSize: 26; color: window.ink }
            TapHandler {
                onTapped: {
                    window.toggleSearch()
                }
            }
        }
    }
    // Prototype account panel. UI only: Microsoft authentication is not connected.
    MouseArea {
        anchors.fill: parent
        z: 105
        visible: window.accountMenuOpen
        onClicked: window.accountMenuOpen = false
    }
    GlassPane {
        id: accountMenu
        backdropBlur: false // Disable misaligned local scene sampling; keep glass tint and highlight
        z: 110
        visible: window.accountMenuOpen
        // Keep the entire popover within the sidebar's 22px content margins.
        width: window.sidebarMode ? sidebar.width - 44 : 300
        height: 278
        x: window.sidebarMode ? sidebar.x + 22 : window.width - width - 28
        y: window.sidebarMode
           ? Math.max(82, sidebarAccountFooter.y - height - 10)
           : 82
        radius: 24
        emphasized: true
        clip: true
        Column {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12
            Row {
                width: parent.width
                height: 46
                spacing: 12
                Rectangle {
                    width: 44; height: 44; radius: 22
                    color: window.darkMode ? "#527FA0C4" : "#9ED5EBFC"
                    Text { anchors.centerIn: parent; text: "☺"; color: window.ink; font.pixelSize: 22 }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Text { text: window.accountDisplayName; font.bold: true; font.pixelSize: 15; color: window.ink; width: accountMenu.width - 112; elide: Text.ElideRight }
                    Text { text: window.accountProvider; font.pixelSize: 11; color: window.muted; width: accountMenu.width - 112; elide: Text.ElideRight }
                }
            }
            Rectangle { width: parent.width; height: 1; color: window.outline }
            Text { text: "DISPLAY NAME"; color: window.muted; font.pixelSize: 10; font.letterSpacing: 1 }
            TextField {
                id: accountNameInput
                width: parent.width
                height: 38
                text: window.accountDisplayName
                maximumLength: 28
                selectByMouse: true
                font.pixelSize: 13
                color: window.ink
                onEditingFinished: {
                    if (text.trim().length > 0) window.accountDisplayName = text.trim()
                }
                background: Rectangle {
                    radius: 14
                    color: window.darkMode ? "#3A7095B6" : "#99FFFFFF"
                    border.color: window.outline
                }
            }
            Rectangle {
                width: parent.width; height: 40; radius: 16
                color: microsoftHover.hovered ? (window.darkMode ? "#4D719BC3" : "#A5D5ECFC") : "#24FFFFFF"
                border.width: 1; border.color: window.outline
                HoverHandler { id: microsoftHover }
                Text {
                    anchors.centerIn: parent
                    text: "＋  Add Microsoft account"
                    color: window.ink
                    font.pixelSize: 13
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        window.statusMessage = "Microsoft sign-in is not connected yet"
                        window.accountMenuOpen = false
                    }
                }
            }
            Rectangle {
                width: parent.width; height: 40; radius: 16
                color: accountSettingsHover.hovered ? (window.darkMode ? "#4D719BC3" : "#A5D5ECFC") : "transparent"
                HoverHandler { id: accountSettingsHover }
                Text { anchors.centerIn: parent; text: "Account settings"; color: window.ink; font.pixelSize: 13 }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        window.activePage = "Settings"
                        window.accountMenuOpen = false
                    }
                }
            }
        }
    }
    GlassPane {
        id: statusDock
        visible: window.activePage === "Launch"
        z: 40
        HoverHandler { id: statusHover }
        // Keep the status above the dock and away from the sidebar.
        anchors.right: parent.right; anchors.rightMargin: 32; anchors.bottom: parent.bottom; anchors.bottomMargin: 110
        width: Math.min(355, window.width - window.contentLeft - 64)
        height: 38; radius: 19; subtle: true
        color: window.darkMode ? window.glassSoft : "#F3F8FD"
        Text { anchors.centerIn: parent; text: statusMessage; color: muted; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 24; horizontalAlignment: Text.AlignHCenter }
    }
}
