import QtQuick
import QtQuick.Dialogs
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import QtCore
import "CanvasLayout.js" as CanvasLayout
import "InstanceData.js" as InstanceData

ApplicationWindow {
    id: appRoot
    width: 1220
    height: 780
    minimumWidth: 850
    minimumHeight: 560
    visible: true
    title: "Project Glass · Core 11.24"
    function syncPrismInstances() {
        for(var i=instances.count-1;i>=0;i--)if(instances.get(i).key.indexOf("prism:")===0)instances.remove(i)
        var records=prismBridge.instances
        for(var j=0;j<records.length;j++)instances.append(records[j])
        if(records.length && (selectedId.indexOf("prism:")!==0 || !instanceRecord(selectedId)))chooseCard(records[0])
        statusMessage=prismBridge.status
        syncDockArtwork()
        syncCanvasCards()
    }
    Connections {
        target: prismBridge
        function onChanged() { appRoot.statusMessage = prismBridge.status;if(prismBridge.currentAccountName){appRoot.accountDisplayName=prismBridge.currentAccountName;appRoot.accountProvider="Microsoft account"} }
        function onInstancesChanged() { appRoot.syncPrismInstances() }
        function onInstanceReady(key) {
            var record=appRoot.instanceRecord(key)
            if(record)appRoot.chooseCard(record)
            appRoot.syncDockArtwork();appRoot.syncCanvasCards()
        }
    }
    FolderDialog { id:prismRootChooser; title:"Choose Prism Launcher root"; onAccepted:prismRootField.text=decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//,"")) }
    FileDialog { id:prismExecutableChooser; title:"Choose Prism executable or .app"; onAccepted:prismExecutableField.text=decodeURIComponent(selectedFile.toString().replace(/^file:\/\//,"")) }
    component ConnectionField: TextField {
        implicitHeight:36
        font.pixelSize:13; color:appRoot.ink
        leftPadding:12;rightPadding:12
        selectByMouse:true
        onAccepted:focus=false
        Keys.onEscapePressed:focus=false
        background:Rectangle {
            objectName:"accountGlassControl";radius:10
            color:macWindowMetrics.nativeAccountGlass ? "transparent" : (appRoot.darkMode?"#24FFFFFF":"#60FFFFFF")
            border.width:macWindowMetrics.nativeAccountGlass?0:1;border.color:appRoot.outline
        }
    }
    component ConnectionButton: Button {
        property bool primary:false
        implicitHeight:34;implicitWidth:Math.max(80,implicitContentWidth+28)
        leftPadding:14;rightPadding:14
        contentItem:Text { text:parent.text;color:appRoot.ink;font.pixelSize:13;font.weight:parent.primary?Font.DemiBold:Font.Normal;horizontalAlignment:Text.AlignHCenter;verticalAlignment:Text.AlignVCenter }
        background:Rectangle {
            objectName:"accountGlassControl";radius:17
            property bool glassHovered:parent.hovered
            color:parent.primary?Qt.rgba(appRoot.accent.r,appRoot.accent.g,appRoot.accent.b,0.28):(macWindowMetrics.nativeAccountGlass?"transparent":appRoot.glassSoft)
            border.width:parent.primary?1:0;border.color:appRoot.accent
        }
    }
    Timer {
        interval:80;repeat:true;running:prismConnection.visible && macWindowMetrics.nativeGlassDock
        onTriggered:macWindowMetrics.setAccountGlass(prismConnection.contentItem,true)
    }
    Popup {
        id:prismConnection
        parent:appRoot.contentItem
        modal:true;focus:true;dim:false;padding:24
        popupType:macWindowMetrics.nativeGlassDock ? Popup.Window : Popup.Item
        anchors.centerIn:parent
        width:Math.min(600,appRoot.width-64)
        height:prismConnectionLayout.implicitHeight+48
        closePolicy:Popup.CloseOnEscape
        onOpened:if(macWindowMetrics.nativeGlassDock)macWindowMetrics.setAccountGlass(contentItem,true)
        onClosed:macWindowMetrics.setAccountGlass(contentItem,false)
        background:GlassPane {
            radius:24
            color:macWindowMetrics.nativeAccountGlass?"transparent":appRoot.glassStrong
            edgeGlow:!macWindowMetrics.nativeAccountGlass
            border.width:macWindowMetrics.nativeAccountGlass?0:1
        }
        contentItem:ColumnLayout {
            id:prismConnectionLayout;spacing:18
            RowLayout {
                Layout.fillWidth:true
                Image { source:macWindowMetrics.symbolIcon("link",appRoot.accent.toString());Layout.preferredWidth:28;Layout.preferredHeight:28;fillMode:Image.PreserveAspectFit }
                Text { text:"Launcher core";color:appRoot.ink;font.pixelSize:20;font.weight:Font.DemiBold;Layout.fillWidth:true }
            }
            Text { text:"Built-in authentication, Java and game launch";color:appRoot.muted;font.pixelSize:13 }
            ColumnLayout {
                Layout.fillWidth:true;spacing:8
                Text { text:"Backend";color:appRoot.ink;font.pixelSize:13;font.weight:Font.Medium }
                RowLayout { Layout.fillWidth:true;spacing:10
                    ConnectionField { id:prismExecutableField;Layout.fillWidth:true;text:prismBridge.executable;readOnly:true }
                    
                }
                Item { Layout.preferredHeight:4 }
                Text { text:"Data folder";color:appRoot.ink;font.pixelSize:13;font.weight:Font.Medium }
                RowLayout { Layout.fillWidth:true;spacing:10
                    ConnectionField { id:prismRootField;Layout.fillWidth:true;text:prismBridge.dataRoot;readOnly:true }
                    
                }
                Text { text:"Active data folder. Restart with --dir to use another folder.";color:appRoot.muted;font.pixelSize:11;wrapMode:Text.Wrap;Layout.fillWidth:true }
            }
            Rectangle { Layout.fillWidth:true;implicitHeight:1;color:appRoot.outline;opacity:0.35 }
            Text {
                Layout.fillWidth:true;color:appRoot.muted;font.pixelSize:12;wrapMode:Text.Wrap
                text:prismBridge.status.indexOf("Launch request sent")===0?"Launch request sent to Prism. Open Logs for details.":prismBridge.status
            }
            RowLayout { Layout.fillWidth:true;spacing:10
                ConnectionButton { text:"Accounts";onClicked:accountsPopup.open() }
                ConnectionButton { text:"Core settings";onClicked:prismBridge.openCoreSettings() }
                ConnectionButton { text:"Logs";onClicked:prismBridge.openLogs() }
                Item { Layout.fillWidth:true }
                ConnectionButton { text:"Refresh";onClicked:{prismBridge.configure(prismExecutableField.text,prismRootField.text);appRoot.syncPrismInstances()} }
                ConnectionButton { text:"Done";primary:true;onClicked:prismConnection.close() }
            }
        }
    }
    property string backgroundMode: "Gray"
    property string backgroundImage: ""
    property string backgroundPlacement: "Fill"
    readonly property color backgroundColor: backgroundMode === "White" ? "#FFFFFF" : backgroundMode === "Black" ? "#000000" : "#1E1E1E"
    property bool darkMode: backgroundMode === "White" ? false : backgroundMode === "Custom" ? Qt.styleHints.colorScheme === Qt.Dark : true
    property color customColorStart:"#152238"
    property color customColorEnd:"#7356a6"
    property string gradientStopsJson:'[{"color":"#152238","position":0},{"color":"#7356a6","position":1}]'
    readonly property var gradientStops:JSON.parse(gradientStopsJson)
    function updateGradientStop(index,color,position) {var stops=JSON.parse(gradientStopsJson);if(color)stops[index].color=color;if(position!==undefined)stops[index].position=Math.max(0,Math.min(1,position));gradientStopsJson=JSON.stringify(stops)}
    function snapGradientAngle(value){var snap=Math.round(value/45)*45;return Math.abs(value-snap)<=3?snap:value}
    function addGradientStop(){var stops=JSON.parse(gradientStopsJson);stops.push({color:"#ffffff",position:0.5});gradientStopsJson=JSON.stringify(stops)}
    function removeGradientStop(index){var stops=JSON.parse(gradientStopsJson);if(stops.length<=2)return;stops.splice(index,1);gradientStopsJson=JSON.stringify(stops)}
    onGradientStopsJsonChanged:syncBackground()
    property bool customGradient:false
    property real customGradientAngle:45
    function syncBackground() { macWindowMetrics.setBackground(backgroundMode, backgroundMode==="Custom color"?JSON.stringify({start:customColorStart.toString(),end:customColorEnd.toString(),gradient:customGradient,stops:gradientStops,angle:customGradientAngle}):backgroundImage, backgroundPlacement) }
    onCustomColorStartChanged:syncBackground()
    onCustomColorEndChanged:syncBackground()
    onCustomGradientChanged:syncBackground()
    onCustomGradientAngleChanged:syncBackground()
    onBackgroundModeChanged: syncBackground()
    onBackgroundImageChanged: syncBackground()
    onBackgroundPlacementChanged: syncBackground()
    FileDialog {
        id: backgroundFileDialog
        title: "Choose background image"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: {
            appRoot.backgroundImage = selectedFile.toString()
            appRoot.backgroundMode = "Custom"
        }
    }
    property color ink: darkMode ? "#F7FAFF" : "#172333"
    property color muted: darkMode ? "#AAB8CC" : "#58697D"
    property color glass: darkMode ? "#A82A394D" : "#D9F6FAFF"
    property color glassStrong: darkMode ? "#CC30465E" : "#ECF8FBFF"
    property color glassSoft: darkMode ? "#84334660" : "#DCEEF7FF"
    property color outline: darkMode ? "#65E5F5FF" : "#8095B5CD"
    property string themeChoice: "System"
    property color customAccent: "#8B5CF6"
    property color systemAccent: "#0A84FF"
    readonly property var themePalette: ({Blue:"#0A84FF",Purple:"#BF5AF2",Pink:"#FF375F",Red:"#FF453A",Orange:"#FF9F0A",Yellow:"#FFD60A",Green:"#30D158"})
    readonly property color autoAccent: backgroundMode==="Custom"?macWindowMetrics.artworkTint(backgroundImage):backgroundMode==="Custom color"?(customGradient?gradientStops[Math.floor(gradientStops.length/2)].color:customColorStart):systemAccent
    readonly property color chosenAccent: themeChoice === "Auto" ? autoAccent : themeChoice === "System" ? systemAccent : themeChoice === "Custom" ? customAccent : (themePalette[themeChoice] || systemAccent)
    function readableAccent(value) {
        function luminance(r,g,b) {
            function linear(v) {return v<=0.04045?v/12.92:Math.pow((v+0.055)/1.055,2.4)}
            return 0.2126*linear(r)+0.7152*linear(g)+0.0722*linear(b)
        }
        var background=darkMode?luminance(30/255,30/255,30/255):1
        var r=value.r,g=value.g,b=value.b
        for(var i=0;i<=32;i++) {
            var l=luminance(r,g,b)
            if((Math.max(l,background)+0.05)/(Math.min(l,background)+0.05)>=3)break
            var t=(i+1)/32, target=darkMode?1:0
            r=value.r+(target-value.r)*t;g=value.g+(target-value.g)*t;b=value.b+(target-value.b)*t
        }
        return Qt.rgba(r,g,b,1)
    }
    readonly property color accent: readableAccent(chosenAccent)
    onAccentChanged: { macWindowMetrics.setThemeAccent(accent.toString()); sidebarMaterialSignature=""; if(appRoot)appRoot.queueSidebarMaterials() }
    property bool sidebarGuideSeen: false
    property int sidebarGuideStep: 0
    function showSidebarGuide() { sidebarGuideStep=0; sidebarGuideSeen=false; sidebarMode=true; activePage="Launch" }
    ColorDialog { id: themeColorDialog; title: "Accent color"; selectedColor: appRoot.customAccent
        onAccepted: { appRoot.customAccent=selectedColor; appRoot.themeChoice="Custom" } }

    property bool smartLayout: true
    property bool quickCards: true
    // Opt-in, full-window aligned compositor; default off preserves stable 09.21.1 visuals.
    property bool dockLiveBlur: false
    // Adjustable intensity: 0 = no blur, 1 = strongest. Saved automatically.
    property real dockBlurAmount: 0.30
    property int globalMemoryMiB: 4096
    property var systemMemory: ({})
    readonly property int memoryLimitMiB: systemMemory.totalMiB > 0 ? Math.max(0, Math.floor(systemMemory.totalMiB - systemMemory.usedMiB)) : 0
    function clampMemory(value) { return Math.max(Math.min(512, memoryLimitMiB), Math.min(memoryLimitMiB, Math.round(Number(value) || 4096))) }
    function effectiveMemoryMiB(key) {
        if(key===editingInstanceKey && coreEditing && editingMetadata.memoryMiB)return Number(editingMetadata.memoryMiB)
        var meta = cardMetadata[key] || ({})
        return clampMemory(meta.useDefaultMemory !== false ? globalMemoryMiB : (meta.memoryMiB || globalMemoryMiB))
    }
    readonly property string memoryStatus: systemMemory.totalMiB > 0 ?
        "System: " + (systemMemory.totalMiB / 1024).toFixed(1) + " GiB total · " + (systemMemory.usedMiB / 1024).toFixed(1) + " GiB used · " + (memoryLimitMiB / 1024).toFixed(1) + " GiB available" : "System memory unavailable"
    Timer { interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { appRoot.systemMemory = macWindowMetrics.systemMemory(); appRoot.systemAccent=macWindowMetrics.systemAccentColor() }
    }
    property real glassOpacity: 0.72
    onGlassOpacityChanged: macWindowMetrics.setGlassStrength(glassOpacity)
    onDarkModeChanged: { macWindowMetrics.setGlassStrength(glassOpacity); sidebarMaterialSignature = ""; appRoot.queueSidebarMaterials() }
    Connections { target: Qt.styleHints
        function onColorSchemeChanged() {
            Qt.callLater(function() { macWindowMetrics.setGlassStrength(appRoot.glassOpacity); appRoot.sidebarMaterialSignature=""; appRoot.queueSidebarMaterials() })
        }
    }
    readonly property color materialTint: darkMode ? Qt.rgba(0.11, 0.23, 0.31, glassOpacity) : Qt.rgba(0.94, 0.98, 1.0, glassOpacity)
    property bool autoSelect: true
    property string sortMode: "Smart"
    property string selectedId: "rebirth"
    property string searchText: ""
    property bool searchExpanded: false
    property bool sidebarMode: false
    property bool instancePickerOpen: false
    readonly property color navigationText: darkMode ? "#FAFBFF" : "#242424"
    readonly property color navigationSelectedText: darkMode ? "#FFFFFF" : "#050505"
    property var selectedCardKeys: ["rebirth"]
    property string selectionAnchor: "rebirth"
    property string instanceRecordsJson: ""
    property string cardMetadataJson: "{}"
    readonly property var cardMetadata: { try { return JSON.parse(cardMetadataJson) } catch(e) { return ({}) } }
    property string editingInstanceKey: ""
    readonly property var editingRecord: instanceRecord(editingInstanceKey)
    readonly property bool coreEditing:editingInstanceKey.indexOf("prism:")===0
    readonly property var editingMetadata: coreEditing ? Object.assign({mods:[],resourcePacks:[],shaderPacks:[],worlds:[],screenshots:[],servers:[],components:[]},{background:(cardMetadata[editingInstanceKey] || {}).background || ""},prismBridge.editorInstanceKey===editingInstanceKey?prismBridge.editorDetails:{}) : cardMetadata[editingInstanceKey] || ({mods:[],background:""})
    property string editorLogText:""
    property var editorDirtyFields:({})
    function syncEditorFields() {
        var data=editingMetadata
        if(!editorDirtyFields.name && !editInstanceName.activeFocus)editInstanceName.text=editingRecord?editingRecord.label:""
        if(!editInstanceVersion.activeFocus)editInstanceVersion.text=editingRecord?editingRecord.version:""
        if(!editorDirtyFields.notes && !instanceNotes.activeFocus)instanceNotes.text=data.notes || ""
        if(!editorDirtyFields.javaPath && !instanceJava.activeFocus)instanceJava.text=data.javaPath || ""
        if(!editorDirtyFields.javaArgs && !instanceJavaArgs.activeFocus)instanceJavaArgs.text=data.javaArgs || ""
        if(logKeepUpdating || editorLogText.length===0)editorLogText=data.minecraftLog || ""
    }
    Connections {target:prismBridge;function onEditorDetailsChanged(){appRoot.syncEditorFields()}}
    Timer {interval:1000;repeat:true;running:appRoot.activePage==="Instance" && appRoot.coreEditing && appRoot.logKeepUpdating;onTriggered:prismBridge.refreshEditor()}
    onEditorTabChanged:if(coreEditing && activePage==="Instance")prismBridge.refreshEditor()
    onLogKeepUpdatingChanged:if(logKeepUpdating)editorLogText=editingMetadata.minecraftLog || ""
    function toggleEditorAsset(bucket,entry,enabled) {
        if(coreEditing)return prismBridge.setEditorAssetEnabled(editingInstanceKey,bucket,entry.fileName,enabled)
        var list=InstanceData.clone(editingMetadata[bucket] || []);for(var i=0;i<list.length;i++)if(list[i].source===entry.source)list[i].enabled=enabled
        saveEditorAssets(list,bucket);return true
    }
    function removeEditorAsset(bucket,entry) {
        if(coreEditing){prismBridge.removeEditorAsset(editingInstanceKey,bucket,entry.fileName);return}
        saveEditorAssets((editingMetadata[bucket] || []).filter(function(item){return item.source!==entry.source}),bucket)
    }
    function openEditorAsset(bucket,entry) {
        if(coreEditing)prismBridge.revealEditorAsset(editingInstanceKey,bucket,entry.fileName);else Qt.openUrlExternally(entry.source)
    }
    function addEditorServer(address) {
        address=address.trim();if(!address)return
        if(coreEditing){prismBridge.editServer(editingInstanceKey,address,-1);return}
        var list=InstanceData.clone(editingMetadata.servers || []);list.push({name:address,address:address});setInstanceMetadata(editingInstanceKey,{servers:list})
    }
    function removeEditorServer(entry,index) {
        if(coreEditing){prismBridge.editServer(editingInstanceKey,entry.address || entry.name,entry.index);return}
        var list=InstanceData.clone(editingMetadata.servers || []);list.splice(index,1);setInstanceMetadata(editingInstanceKey,{servers:list})
    }
    property string pendingBackgroundKey: ""
    function instanceRecord(key) {
        for(var i=0;i<instances.count;i++)if(instances.get(i).key===key)return instances.get(i)
        return null
    }
    function instanceRecords() { var records=[];for(var i=0;i<instances.count;i++)records.push(JSON.parse(JSON.stringify(instances.get(i))));return records }
    function persistInstances() { instanceRecordsJson=JSON.stringify(instanceRecords()) }
    function selectCanvasCard(card,modifiers,rangeCards) {
        var keys=(rangeCards || sortedCards).map(function(c){return c.key})
        if((modifiers & Qt.ShiftModifier) && keys.indexOf(selectionAnchor)>=0) {
            var a=keys.indexOf(selectionAnchor),b=keys.indexOf(card.key)
            selectedCardKeys=keys.slice(Math.min(a,b),Math.max(a,b)+1)
        } else {
            selectedCardKeys=InstanceData.select(selectedCardKeys,card.key,!!(modifiers & (Qt.ControlModifier|Qt.MetaModifier)))
            selectionAnchor=card.key
        }
        chooseCard(card,true)
    }
    function openCardMenu(card,x,y) {
        if(selectedCardKeys.indexOf(card.key)<0)selectedCardKeys=[card.key]
        cardContextMenu.contextKeys=selectedCardKeys.slice()
        accountMenuOpen=false
        cardContextMenu.popup(x,y)
    }
    function duplicateCards(keys) {
        var sourceRecords=instanceRecords(), sources=sourceRecords.filter(function(r){return keys.indexOf(r.key)>=0})
        var result=InstanceData.duplicate(sourceRecords,keys,cardMetadata)
        result.copies.forEach(function(record){instances.append(record)})
        cardMetadataJson=JSON.stringify(result.metadata)
        var groups=InstanceData.clone(instanceGroups)
        groups.forEach(function(g){result.copies.forEach(function(copy,i){
            var source=sources[i]
            if(source && g.keys.indexOf(source.key)>=0)g.keys.push(copy.key)
        })})
        instanceGroupsJson=JSON.stringify(groups)
        customInstanceOrder=customInstanceOrder.concat(result.copies.map(function(c){return c.key}))
        selectedCardKeys=result.copies.map(function(c){return c.key})
        if(selectedCardKeys.length)selectedId=selectedCardKeys[0]
        persistInstances()
    }
    function setInstanceMetadata(key,patch) {
        if(key.indexOf("prism:")===0) {
            var settings={},visual={}
            Object.keys(patch).forEach(function(name){if(["notes","javaPath","javaArgs","memoryMiB","useDefaultMemory"].indexOf(name)>=0)settings[name]=patch[name];else visual[name]=patch[name]})
            if(Object.keys(settings).length && prismBridge.saveEditorSettings(key,settings)) {
                Object.keys(settings).forEach(function(name){delete editorDirtyFields[name]});syncEditorFields()
            }
            patch=visual;if(!Object.keys(patch).length)return
        }
        var data=InstanceData.clone(cardMetadata),record=data[key]||{mods:[],background:""}
        Object.keys(patch).forEach(function(k){record[k]=patch[k]})
        data[key]=record;cardMetadataJson=JSON.stringify(data)
    }
    function saveInstanceDetails(name,version) {
        if(!name.trim().length)return
        if(coreEditing){if(prismBridge.saveEditorSettings(editingInstanceKey,{name:name})){delete editorDirtyFields.name;syncEditorFields()}return}
        for(var i=0;i<instances.count;i++)if(instances.get(i).key===editingInstanceKey){
            instances.setProperty(i,"label",name.trim());instances.setProperty(i,"version",version.trim());break
        }
        persistInstances()
    }
    function editInstance(key) {
        editingInstanceKey=key;editorDirtyFields=({});editorLogText="";editorTab="Overview";activePage="Instance"
        if(coreEditing)prismBridge.watchInstance(key)
        syncEditorFields()
    }
    function moveCardsToGroup(keys,id) {
        var groups=instanceGroups
        keys.forEach(function(key){groups=CanvasLayout.assignGroup(groups,key,id)})
        instanceGroupsJson=JSON.stringify(groups);groupedLayoutEnabled=true;groupingMethod="Custom"
    }
    FileDialog {
        id: cardBackgroundDialog
        title: "Choose instance background"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.bmp)"]
        onAccepted: appRoot.setInstanceMetadata(appRoot.pendingBackgroundKey,{background:selectedFile.toString()})
    }
    FileDialog {
        id: instanceModsDialog
        title: "Add Mod files"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Mods (*.jar)"]
        onAccepted: {
            if(appRoot.coreEditing){for(var f=0;f<selectedFiles.length;f++)prismBridge.importEditorAsset(appRoot.editingInstanceKey,"mods",selectedFiles[f]);return}
            var mods=InstanceData.clone(appRoot.editingMetadata.mods||[])
            for(var i=0;i<selectedFiles.length;i++){
                var url=selectedFiles[i].toString()
                if(!mods.some(function(m){return m.source===url}))mods.push({name:decodeURIComponent(url.split("/").pop()),source:url,enabled:true})
            }
            appRoot.setInstanceMetadata(appRoot.editingInstanceKey,{mods:mods})
        }
    }
    property string collapsedInstanceGroupsJson: "[]"
    readonly property var collapsedInstanceGroups: {try{return JSON.parse(collapsedInstanceGroupsJson)}catch(e){return []}}
    function sidebarDisplayRows() { return InstanceData.sidebarRows(sortedCards,effectiveInstanceGroups,collapsedInstanceGroups,hasInstanceGroups) }
    function toggleSidebarGroup(id) {
        var ids=collapsedInstanceGroups.slice(),i=ids.indexOf(id)
        if(i<0)ids.push(id);else ids.splice(i,1)
        collapsedInstanceGroupsJson=JSON.stringify(ids)
    }
    property string editorTab: "Overview"
    readonly property var editorTabs: ["Overview","Minecraft Log","Version","Mods","Resource Packs","Shader Packs","Notes","Worlds","Servers","Screenshots","Settings","Other Logs"]
    property string editorAssetBucket: "mods"
    property string exportPayload: ""
    property var deletionKeys: []
    property bool logKeepUpdating: true
    property bool logWrapLines: true
    function exportSelection(keys) {
        var records=instanceRecords().filter(function(r){return keys.indexOf(r.key)>=0}), metadata={}
        keys.forEach(function(key){metadata[key]=cardMetadata[key]||{}})
        return JSON.stringify({format:"ProjectGlass-instance-config",version:1,instances:records,metadata:metadata},null,2)
    }
    function showInstanceFolder(key) { if(key.indexOf("prism:")===0)prismBridge.openInstance(key);else macWindowMetrics.openInstanceFolder(key,exportSelection([key])) }
    function requestExport(keys,modsOnly) {
        exportPayload=modsOnly ? keys.map(function(key){return (key.indexOf("prism:")===0?prismBridge.instanceDetails(key):(cardMetadata[key]||{})).mods||[]}).reduce(function(a,b){return a.concat(b)},[]).map(function(m){return (m.enabled?"[enabled] ":"[disabled] ")+m.name+"  "+m.source}).join("\n") : exportSelection(keys)
        exportConfigDialog.nameFilters=modsOnly ? ["Mod list (*.txt)"] : ["Instance configuration (*.json)"]
        exportConfigDialog.open()
    }
    function deleteInstances(keys) {
        for(var i=instances.count-1;i>=0;i--)if(keys.indexOf(instances.get(i).key)>=0)instances.remove(i)
        var metadata=InstanceData.clone(cardMetadata);keys.forEach(function(key){delete metadata[key]})
        cardMetadataJson=JSON.stringify(metadata)
        instanceGroupsJson=JSON.stringify(instanceGroups.map(function(g){return {id:g.id,name:g.name,keys:g.keys.filter(function(key){return keys.indexOf(key)<0})}}))
        customInstanceOrder=customInstanceOrder.filter(function(key){return keys.indexOf(key)<0})
        selectedCardKeys=[];selectedId=instances.count?instances.get(0).key:"";persistInstances()
    }
    function openEditorAssets(bucket) {
        editorAssetBucket=bucket
        if(coreEditing && (bucket==="worlds" || bucket==="screenshots")){prismBridge.openEditorFolder(editingInstanceKey,bucket);return}
        if(bucket==="worlds")instanceWorldDialog.open()
        else {
            editorAssetsDialog.nameFilters=bucket==="screenshots" ? ["Images (*.png *.jpg *.jpeg *.webp)"] : bucket==="mods" ? ["Mods (*.jar)"] : ["Packs (*.zip)"]
            editorAssetsDialog.open()
        }
    }
    function addEditorAsset(source) {
        if(coreEditing){prismBridge.importEditorAsset(editingInstanceKey,editorAssetBucket,source);return}
        var entries=InstanceData.clone(editingMetadata[editorAssetBucket]||[])
        if(!entries.some(function(e){return e.source===source}))entries.push({name:decodeURIComponent(source.replace(/\/$/,"").split("/").pop()),source:source,enabled:true})
        var patch={};patch[editorAssetBucket]=entries;setInstanceMetadata(editingInstanceKey,patch)
    }
    function saveEditorAssets(entries,bucket) {if(coreEditing){prismBridge.refreshEditor();return}var patch={};patch[bucket]=entries;setInstanceMetadata(editingInstanceKey,patch)}
    FileDialog {
        id: exportConfigDialog; title: "Export instance"; fileMode: FileDialog.SaveFile
        onAccepted: if(!macWindowMetrics.writeTextFile(selectedFile,appRoot.exportPayload))appRoot.statusMessage="Could not save export"
    }
    FileDialog {
        id: shortcutDialog; title: "Create launch shortcut"; fileMode: FileDialog.SaveFile
        nameFilters: ["macOS launch shortcut (*.command)"]
        onAccepted: if(!macWindowMetrics.writeLaunchShortcut(selectedFile,cardContextMenu.contextKeys[0]))appRoot.statusMessage="Could not save shortcut"
    }
    FileDialog {
        id: editorAssetsDialog; fileMode: FileDialog.OpenFiles
        onAccepted: {for(var i=0;i<selectedFiles.length;i++)appRoot.addEditorAsset(selectedFiles[i].toString())}
    }
    FolderDialog { id: instanceWorldDialog; title: "Add world folder"; onAccepted: appRoot.addEditorAsset(selectedFolder.toString()) }
    Dialog {
        id: deleteInstanceDialog
        parent: appRoot.contentItem
        popupType: macWindowMetrics.nativeGlassDock ? Popup.Window : Popup.Item
        title: "Delete instance configuration?"
        width: 380
        modal: true; dim: false
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent
        onAccepted: appRoot.deleteInstances(appRoot.deletionKeys)
        contentItem: Text { text: "The launcher configuration will be removed. Referenced files are kept."; color: appRoot.ink; wrapMode: Text.WordWrap }
        background: GlassPane { radius: 24; emphasized: true }
    }
    function launchInstanceKey(key) { var record=instanceRecord(key);if(record){activePage="Launch";activateCard(record)} }
    property bool accountMenuOpen: false
    property string accountDisplayName: "Player"
    property string accountProvider: "Not signed in"
    property bool sidebarInstancesExpanded: false
    property bool sidebarQuickDownloadExpanded: false
    readonly property var quickVersionOptions: {
        var versions = downloadData.quickVersions.slice()
        if (sidebarQuickVersion && versions.indexOf(sidebarQuickVersion) < 0) versions.unshift(sidebarQuickVersion)
        return versions
    }
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
                if (appRoot.downloadRowKeys[i] !== key(rows[i])) append = false
            if (!append) { downloadRows.clear(); appRoot.downloadRowKeys = [] }
            var keys = appRoot.downloadRowKeys.slice()
            for (var j = downloadRows.count; j < rows.length; j++) {
                downloadRows.append({ entry: rows[j] })
                keys.push(key(rows[j]))
            }
            appRoot.downloadRowKeys = keys
        }
    }
    DownloadData { id: downloadData; objectName: "downloadData" }
    property bool downloadReady: false
    Component.onCompleted: {
        if(instanceRecordsJson.length) {
            try { var records=JSON.parse(instanceRecordsJson);if(Array.isArray(records)){instances.clear();records.forEach(function(r){instances.append(r)})} } catch(e) {}
        }
        if(activePage==="Instance")activePage="Launch"
        syncPrismInstances()
        downloadProvider = "Modrinth"
        downloadReady = true
        if (groupingMethod === "Off") groupedLayoutEnabled=false
        else if (!groupedLayoutEnabled) { lastActiveGroupingMethod=groupingMethod; groupingMethod="Off" }
        if (canvasLayoutRevision < 2) { sortMode = "Smart"; resetCanvas(); canvasLayoutRevision = 2 }
        macWindowMetrics.setDockInfo(selectedLabel(), selectedVersion())
        macWindowMetrics.setDockGeometry(bottomDock.x, bottomDock.y, bottomDock.width,
                                         bottomDock.height, bottomDock.radius)
        if (activePage === "Download") catalogueRefresh.restart()
    }
    Timer {
        id: catalogueRefresh
        interval: 350
        onTriggered: {
            if (appRoot.downloadReady && appRoot.activePage === "Download" && !appRoot.downloadSelection)
                downloadData.loadCatalogue(appRoot.downloadCategory, appRoot.downloadSearch, appRoot.downloadSort, false, appRoot.downloadLoaderFilter, appRoot.downloadProvider)
        }
    }
    function refreshCatalogue() {
        if (!downloadReady) return
        downloadData.invalidateCatalogue()
        catalogueRefresh.restart()
    }
    function submitDownloadSearch(query) {
        if (!downloadReady || activePage !== "Download" || downloadSelection) return
        downloadSearch = String(query).trim()
        catalogueRefresh.stop()
        downloadData.invalidateCatalogue()
        downloadData.loadCatalogue(downloadCategory, downloadSearch, downloadSort, false,
                                   downloadLoaderFilter, downloadProvider)
    }
    onDownloadSearchChanged: refreshCatalogue()
    onDownloadCategoryChanged: refreshCatalogue()
    onDownloadSortChanged: refreshCatalogue()
    onDownloadProviderChanged: { if (downloadProvider !== "Modrinth") downloadProvider = "Modrinth"; else refreshCatalogue() }
    onDownloadLoaderFilterChanged: refreshCatalogue()
    onActivePageChanged: {
        if(activePage!=="Launch")cardSizeEditing=false
        if(activePage!=="Instance" && editingInstanceKey.indexOf("prism:")===0)prismBridge.watchInstance("")
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
    property bool projectIntroduction: false
    property string projectBody: ""
    property string projectBodyError: ""
    property bool projectBodyBusy: false
    property var collapsedReleaseGroups: ({})
    function toggleReleaseGroup(group) {
        var next=Object.assign({},collapsedReleaseGroups)
        next[group]=!next[group]; collapsedReleaseGroups=next
    }
    function releaseRows() {
        var result=[], previous=""
        for(var i=0;i<releaseChoices.length;i++) {
            var release=releaseChoices[i]
            if(release.group!==previous) { result.push({heading:true,group:release.group});previous=release.group }
            if(!collapsedReleaseGroups[release.group]) result.push(release)
        }
        return result
    }
    function openProject(entry) {
        beginDownload(entry)
        if(entry.category === "Versions") return
        projectIntroduction=true; projectBody=""; projectBodyError=""
        if(!entry.projectId) { projectBody=entry.detail || "";return }
        projectBodyBusy=true
        var identity=downloadSelection
        downloadData.request("introduction",downloadData.modrinthBase+"/project/"+encodeURIComponent(entry.projectId),function(error,data) {
            if(appRoot.downloadSelection!==identity)return
            appRoot.projectBodyBusy=false
            appRoot.projectBodyError=error || ""
            appRoot.projectBody=data ? (data.body || data.description || entry.detail || "") : ""
        })
    }
    property string selectedLoader: sidebarQuickLoader
    readonly property string targetMinecraftVersion: {
        var source = selectedVersion()
        var match = source.match(/\d+(?:\.\d+)+/)
        return match ? match[0] : ""
    }
    readonly property string targetLoader: {
        var source = selectedVersion()
        return source.indexOf("Fabric") === 0 ? "Fabric" : source.indexOf("NeoForge") === 0 ? "NeoForge" : source.indexOf("Forge") === 0 ? "Forge" : source.indexOf("Quilt") === 0 ? "Quilt" : "Vanilla"
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
        function onDeletionConfirmed() { appRoot.deleteInstances(appRoot.deletionKeys) }
        function onSearchCloseRequested() { appRoot.searchExpanded = false }
        function onSearchStateRequested(text, sort, scale) {
            appRoot.searchText = text
            appRoot.groupingMethod = sort
            appRoot.zoom = scale
        }
        function onNativeGlassDockChanged() {
            appRoot.syncNativeNavigation()
            appRoot.syncBackground()
            macWindowMetrics.setGlassStrength(appRoot.glassOpacity)
            macWindowMetrics.setThemeAccent(appRoot.accent.toString())
        }
        function onNativeSidebarChanged() { appRoot.syncNativeNavigation(); appRoot.syncBackground() }
        function onNavigationRequested(action) {
            appRoot.instancePickerOpen = false
            if (action === 5) appRoot.sidebarMode = false
            else if (action === 0) appRoot.sidebarMode = true
            else if (action === 4) appRoot.toggleSearch()
            else if (action === 6) appRoot.toggleAccountMenu()
            else appRoot.activePage = ["Launch", "Download", "Settings"][action - 1]
        }
        function onInstanceSelected(index) {
            if (index >= 0 && index < instances.count) appRoot.chooseCard(instances.get(index))
            appRoot.instancePickerOpen = false
        }
        function onInstancePickerRequested() { appRoot.instancePickerOpen = !appRoot.instancePickerOpen }
        function onLaunchRequested() { appRoot.launchInstanceKey(appRoot.selectedId) }
    }
    function beginDownload(entry) {
        projectIntroduction=false; projectBodyBusy=false; collapsedReleaseGroups=({})
        downloadData.cancel("introduction")
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
        if (!downloadSelection) { downloadData.cancel("introduction"); projectBodyBusy=false; projectIntroduction=false }
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
            if (appRoot.activePage === "Download" && appRoot.downloadSelection)
                downloadData.loadReleases(appRoot.downloadSelection, appRoot.selectedLoader, appRoot.targetMinecraftVersion, appRoot.targetLoader)
        }
    }
    function canInstallRelease(release) {
        return !!downloadSelection && !!release && !release.heading && !!release.eligible && !prismBridge.installing &&
            !downloadData.releaseBusy && !downloadData.releaseError &&
            (downloadSelection.category === "Versions" || downloadSelection.category === "Modpacks" || selectedId.indexOf("prism:")===0)
    }
    function downloadRelease(release) {
        if(!canInstallRelease(release))return
        selectedRelease=release.id
        installSelectedRelease()
    }
    function installSelectedRelease() {
        if (!downloadSelection || prismBridge.installing) return
        if (downloadSelection.category === "Versions") {
            prismBridge.installGame(downloadSelection.version, selectedLoader,
                                   selectedReleaseDetails ? selectedReleaseDetails.loaderVersion : "")
        } else if (selectedReleaseDetails && selectedReleaseDetails.eligible) {
            prismBridge.installModrinth(selectedId, downloadSelection.category, downloadSelection.projectId,
                                        downloadSelection.name, selectedReleaseDetails.raw)
        }
    }

    // One animation drives sidebar, navigation and the content-region geometry.
    property real sidebarProgress: macWindowMetrics.nativeSidebar
        ? macWindowMetrics.sidebarAnimationProgress : (sidebarMode ? 1.0 : 0.0)
    Behavior on sidebarProgress {
        enabled: !macWindowMetrics.nativeSidebar
        NumberAnimation { duration: 390; easing.type: Easing.InOutCubic }
    }
    property real sidebarPreferredWidth: 282
    readonly property real sidebarMaximumWidth: Math.max(240, Math.min(420, width - 520))
    readonly property real contentLeft: sidebarProgress * sidebar.width
    property bool groupedLayoutEnabled: true
    property string groupingMethod: "Smart"
    property string lastActiveGroupingMethod: "Smart"
    onGroupedLayoutEnabledChanged: {
        if (!downloadReady) return
        if (!groupedLayoutEnabled && groupingMethod !== "Off") {
            lastActiveGroupingMethod=groupingMethod; groupingMethod="Off"
        } else if (groupedLayoutEnabled && groupingMethod === "Off") groupingMethod=lastActiveGroupingMethod
        resetCanvas()
    }
    onGroupingMethodChanged: {
        if (!downloadReady) return
        if (groupingMethod === "Off") groupedLayoutEnabled=false
        else { lastActiveGroupingMethod=groupingMethod; groupedLayoutEnabled=true }
        resetCanvas()
    }
    readonly property var effectiveInstanceGroups: groupingMethod === "Custom" ? instanceGroups : CanvasLayout.automaticGroups(sortedCards,groupingMethod)
    property string instanceGroupsJson: "[]"
    readonly property var instanceGroups: {
        try { var groups=JSON.parse(instanceGroupsJson); return Array.isArray(groups) ? groups : [] }
        catch(e) { return [] }
    }
    readonly property bool hasInstanceGroups: groupedLayoutEnabled && groupingMethod !== "Off"
    function createInstanceGroup(name, key) {
        name = name.trim()
        if (!name.length) return
        var groups=instanceGroups.slice(), id="group-"+Date.now(), suffix=0
        while(groups.some(function(g){return g.id===id})) id="group-"+Date.now()+"-"+(++suffix)
        groups.push({id:id,name:name,keys:[]})
        var keys=Array.isArray(key)?key:(key?[key]:[])
        keys.forEach(function(k){groups=CanvasLayout.assignGroup(groups,k,id)})
        instanceGroupsJson=JSON.stringify(groups)
        groupedLayoutEnabled=true; groupingMethod="Custom"
        resetCanvas()
    }
    function renameInstanceGroup(id,name) {
        name=name.trim(); if(!name.length)return
        var current=instanceGroups.filter(function(g){return g.id===id})
        if(!current.length || current[0].name===name)return
        instanceGroupsJson=JSON.stringify(instanceGroups.map(function(g){return {id:g.id,name:g.id===id?name:g.name,keys:g.keys.slice()}}))
    }
    function deleteInstanceGroup(id) {
        instanceGroupsJson=JSON.stringify(instanceGroups.filter(function(g){return g.id!==id}))
        resetCanvas()
    }
    function assignInstanceGroup(key,id) {
        groupedLayoutEnabled=true; groupingMethod="Custom"
        instanceGroupsJson=JSON.stringify(CanvasLayout.assignGroup(instanceGroups,key,id))
    }
    property var customInstanceOrder: []
    property string draggedInstanceKey: ""
    property int instanceDropSlot: -1
    property real instanceDragSceneY: 0
    property int canvasLayoutRevision: 0
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
        if (macWindowMetrics.nativeSidebar) macWindowMetrics.animateSidebar(sidebarMode)
        accountMenuOpen = false
        instancePickerOpen = false
        // Keep the canvas offsets and zoom untouched.
    }
    property string statusMessage: "Built-in launcher core"
    color: macWindowMetrics.nativeSidebar ? "transparent" : appRoot.backgroundColor
    // Persistent user preferences and window geometry (Qt application settings).
    Settings {
        category: "ProjectGlassPrototype091"
        property alias gradientStopsJson:appRoot.gradientStopsJson
        property alias customColorStart:appRoot.customColorStart
        property alias customColorEnd:appRoot.customColorEnd
        property alias customGradient:appRoot.customGradient
        property alias customGradientAngle:appRoot.customGradientAngle
        property alias backgroundMode: appRoot.backgroundMode
        property alias backgroundImage: appRoot.backgroundImage
        property alias backgroundPlacement: appRoot.backgroundPlacement
        property alias sidebarMode: appRoot.sidebarMode
        property alias sidebarWidth: appRoot.sidebarPreferredWidth
        property alias smartLayout: appRoot.smartLayout
        property alias quickCards: appRoot.quickCards
        property alias dockLiveBlur: appRoot.dockLiveBlur
        property alias dockBlurAmount: appRoot.dockBlurAmount
        property alias themeChoice: appRoot.themeChoice
        property alias customAccent: appRoot.customAccent
        property alias sidebarGuideSeen: appRoot.sidebarGuideSeen
        property alias globalMemoryMiB: appRoot.globalMemoryMiB
        property alias glassOpacity: appRoot.glassOpacity
        property alias autoSelect: appRoot.autoSelect
        property alias sortMode: appRoot.sortMode
        property alias selectedId: appRoot.selectedId
        property alias accountDisplayName: appRoot.accountDisplayName
        property alias sidebarInstancesExpanded: appRoot.sidebarInstancesExpanded
        property alias sidebarQuickVersion: appRoot.sidebarQuickVersion
        property alias sidebarQuickLoader: appRoot.sidebarQuickLoader
        property alias downloadCategory: appRoot.downloadCategory
        property alias downloadProvider: appRoot.downloadProvider
        property alias activePage: appRoot.activePage
        property alias searchText: appRoot.searchText
        property alias searchExpanded: appRoot.searchExpanded
        property alias groupedLayoutEnabled: appRoot.groupedLayoutEnabled
        property alias lastActiveGroupingMethod: appRoot.lastActiveGroupingMethod
        property alias groupingMethod: appRoot.groupingMethod
        property alias collapsedInstanceGroupsJson: appRoot.collapsedInstanceGroupsJson
        property alias instanceRecordsJson: appRoot.instanceRecordsJson
        property alias cardMetadataJson: appRoot.cardMetadataJson
        property alias instanceGroupsJson: appRoot.instanceGroupsJson
        property alias customInstanceOrder: appRoot.customInstanceOrder
        property alias canvasLayoutRevision: appRoot.canvasLayoutRevision
        property alias freeAvoidOverlap:appRoot.freeAvoidOverlap
        property alias freeMinimumGap:appRoot.freeMinimumGap
        property alias freeCanvasEnabled:appRoot.freeCanvasEnabled
        property alias groupCardSizesJson:appRoot.groupCardSizesJson
        property alias customCardSizesJson:appRoot.customCardSizesJson
        property alias freeRectsJson:appRoot.freeRectsJson
        property alias freeHiddenJson:appRoot.freeHiddenJson
        property alias panX: appRoot.panX
        property alias panY: appRoot.panY
        property alias zoom: appRoot.zoom
        property alias windowWidth: appRoot.width
        property alias windowHeight: appRoot.height
        property alias windowX: appRoot.x
        property alias windowY: appRoot.y
    }


    // Window-space navigation: top 14pt + height 56pt + equal bottom gap 14pt.
    readonly property real navigationTopInset: 14
    readonly property real navigationBarHeight: 56
    readonly property real compactPageTop: navigationTopInset * 2 + navigationBarHeight
    readonly property real sidebarPageTop: sidebarScroll && sidebar ? sidebar.y + sidebarScroll.y : 28
    readonly property real sidebarPageWindowTop: sidebarPageTop + contentItem.y
    function pageTop() {
        return (compactPageTop - contentItem.y) * (1 - sidebarProgress) + sidebarPageTop * sidebarProgress
    }
    function panelHeight(top) {
        // Full-window dock: bottom inset 20, then its height, then a 16pt clear gap.
        return Math.max(0,height-contentItem.y-20-bottomDock.height-16-top)
    }
    readonly property real compactContentRise: 12 * (1 - sidebarProgress)
    property bool sidebarDownloadExpanded: true
    property var sidebarDownloadAnchor: null
    readonly property bool sidebarDownloadTools: macWindowMetrics.nativeGlassDock && sidebarProgress > 0.5 && sidebarDownloadAnchor !== null
    function syncNativePageUI() {
        if (!downloadReady || !macWindowMetrics.nativeGlassDock) return
        var page = activePage === "Instance" ? (editorTab === "Minecraft Log" ? logControlsNativeArea : instanceMemoryNativeArea) : (activePage === "Settings" ? pageContent : downloadPage)
        var point = page.mapToItem(null, 0, 0)
        macWindowMetrics.setPageUI({editorTab: editorTab, logKeepUpdating: logKeepUpdating, logWrapLines: logWrapLines,
            gradientStops:gradientStops,customGradient:customGradient,customColorStart:customColorStart.toString(),customGradientAngle:customGradientAngle,themeChoice: themeChoice, customAccent: customAccent.toString(), accent: accent.toString(),
            edgeX: contentLeft, settingsTop: pageContent.mapToItem(null,0,0).y, page: activePage, sidebarDownloads: sidebarDownloadTools, categoriesExpanded: sidebarDownloadExpanded,
            categoryX: sidebarDownloadAnchor ? sidebarDownloadAnchor.mapToItem(null,0,0).x : 0,
            categoryY: sidebarDownloadAnchor ? sidebarDownloadAnchor.mapToItem(null,0,0).y : 0,
            categoryWidth: sidebarDownloadAnchor ? sidebarDownloadAnchor.width : 0,
            categoryHeight: sidebarDownloadAnchor ? sidebarDownloadAnchor.height : 0,
            sidebarClipTop: sidebarScroll.mapToItem(null,0,0).y - (sidebarDownloadAnchor ? sidebarDownloadAnchor.mapToItem(null,0,0).y : 0),
            sidebarClipBottom: sidebarAccountFooter.mapToItem(null,0,0).y - 14 - (sidebarDownloadAnchor ? sidebarDownloadAnchor.mapToItem(null,0,0).y : 0), x: point.x, y: point.y,
            width: page.width, height: page.height,
            visible: (activePage === "Instance" && editorTab === "Settings") || activePage === "Settings" || (activePage === "Download" && !downloadSelection),
            dark: darkMode,
            interactive: !prismConnection.visible && !accountMenuOpen && !instancePickerOpen && !searchExpanded,
            smart: smartLayout, grouped: groupedLayoutEnabled, groupingMethod: groupingMethod, quick: quickCards, background: backgroundMode,
            instanceDefault: editingMetadata.useDefaultMemory !== false,
            memoryTotal: systemMemory.totalMiB || 0, memoryUsed: systemMemory.usedMiB || 0,
            memory: activePage === "Instance" ? effectiveMemoryMiB(editingInstanceKey) : clampMemory(globalMemoryMiB), memoryLimit: memoryLimitMiB, memoryStatus: memoryStatus,
            image: backgroundImage, placement: backgroundPlacement, glass: glassOpacity,
            provider: downloadProvider, query: downloadSearch, category: downloadCategory,
            sort: downloadSort, loader: downloadLoaderFilter, busy: downloadData.catalogueBusy})
    }
    Connections {
        target: macWindowMetrics
        function onPageControlChanged(key, value) {
            if(key === "prismConnection")prismConnection.open()
            else if(key === "logKeepUpdating") appRoot.logKeepUpdating=value
            else if(key === "logWrapLines") appRoot.logWrapLines=value
            else if (key === "themeChoice") appRoot.themeChoice=value
            else if(key === "customAccent") { appRoot.customAccent=value; appRoot.themeChoice="Custom" }
            else if(key === "sidebarGuide") appRoot.showSidebarGuide()
            else if (key === "grouped") appRoot.groupedLayoutEnabled = value
            else if (key === "groupingMethod") appRoot.groupingMethod = value
            else if (key === "smart") appRoot.smartLayout = value
            else if (key === "quick") appRoot.quickCards = value
            else if (key === "background") appRoot.backgroundMode=value
            else if (key === "placement") appRoot.backgroundPlacement = value
            else if (key === "instanceDefault") appRoot.setInstanceMetadata(appRoot.editingInstanceKey, {useDefaultMemory: value})
            else if (key === "instanceMemory") appRoot.setInstanceMetadata(appRoot.editingInstanceKey, {memoryMiB: appRoot.clampMemory(value)})
            else if (key === "memory") appRoot.globalMemoryMiB = appRoot.clampMemory(value)
            else if (key === "glass") appRoot.glassOpacity = value
            else if (key === "chooseImage") {if(appRoot.backgroundMode!=="Custom color")backgroundFileDialog.open()}
            else if(key==="gradientStops")appRoot.gradientStopsJson=JSON.stringify(value)
            else if(key==="customGradient")appRoot.customGradient=value
            else if(key==="customColorStart")appRoot.customColorStart=value
            else if(key==="customGradientAngle")appRoot.customGradientAngle=appRoot.snapGradientAngle(value)
            else if (key === "provider") appRoot.downloadProvider = value
            else if (key === "query") appRoot.downloadSearch = value
            else if (key === "searchSubmit") appRoot.submitDownloadSearch(value)
            else if (key === "accountClose") appRoot.accountMenuOpen = false
            else if (key === "accountName") appRoot.accountDisplayName = value
            else if (key === "accountSettings") { appRoot.accountMenuOpen = false; appRoot.activePage = "Settings" }
            else if (key === "accountMicrosoft") {
                appRoot.accountMenuOpen = false
                prismBridge.useMicrosoft()
            }
            else if (key === "category") appRoot.openDownloadCategory(value)
            else if (key === "sort") appRoot.downloadSort = value
            else if (key === "loader") appRoot.downloadLoaderFilter = value
            else if (key === "refresh") appRoot.refreshCatalogue()
        }
    }

    function queueSidebarMaterials() {
        if (downloadReady && sidebarMaterialSync) sidebarMaterialSync.restart()
    }
    function syncNativeSearchButton() {
        if (!downloadReady || !searchDock || !searchToggle) return
        var target = appRoot.searchExpanded ? searchToggle : searchDock
        var point = target.mapToItem(null, 0, 0)
        macWindowMetrics.setSearchButton(point.x, point.y, target.height, searchDock.opacity,
            searchDock.visible && searchDock.enabled && !appRoot.searchExpanded && !appRoot.accountMenuOpen && !appRoot.instancePickerOpen,
            appRoot.searchExpanded)
        var panelPoint = searchDock.mapToItem(null, 0, 0)
        macWindowMetrics.setSearchPanel(panelPoint.x, panelPoint.y, searchDock.width, searchDock.height,
            searchDock.opacity, searchDock.visible && appRoot.searchExpanded && !appRoot.accountMenuOpen && !appRoot.instancePickerOpen,
            appRoot.searchText, appRoot.groupingMethod, appRoot.zoom)
    }
    component MemoryAllocation: ColumnLayout {
        id: memoryControl
        property int allocation: 4096
        signal committed(int value)
        spacing: 10
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: 16; radius: 8; clip: true
            color: "#CCFFFFFF"
            readonly property real total: Math.max(1, appRoot.systemMemory.totalMiB || 1)
            Rectangle { height: parent.height; width: parent.width * Math.min(1,(appRoot.systemMemory.usedMiB || 0)/parent.total); color: "#888888" }
            Rectangle { height: parent.height; x: parent.width * Math.min(1,(appRoot.systemMemory.usedMiB || 0)/parent.total)
                width: parent.width * Math.min(appRoot.memoryLimitMiB,memoryControl.allocation)/parent.total; color: appRoot.accent }
        }
        RowLayout {
            Slider { Layout.fillWidth: true; enabled: appRoot.memoryLimitMiB >= 512
                from: Math.min(512, appRoot.memoryLimitMiB); to: Math.max(from,appRoot.memoryLimitMiB); stepSize: 128
                value: Math.min(memoryControl.allocation,appRoot.memoryLimitMiB); onMoved: memoryControl.committed(appRoot.clampMemory(value)) }
            GroupField { Layout.preferredWidth: 100; enabled: appRoot.memoryLimitMiB >= 512
                text: String(appRoot.clampMemory(memoryControl.allocation)); selectByMouse: true
                validator: IntValidator { bottom: Math.min(512,appRoot.memoryLimitMiB); top: appRoot.memoryLimitMiB }
                onAccepted: focus=false
                Keys.onEscapePressed: focus=false
                onEditingFinished: { var value = appRoot.clampMemory(text); memoryControl.committed(value); text = Qt.binding(function() { return String(appRoot.clampMemory(memoryControl.allocation)) }) } }
        }
        Text { text: "Used · Allocation limit · Remaining"; color: appRoot.muted; font.pixelSize: 11 }
    }

    component RoundedInstanceImage: Item {
        id: roundedInstanceImage
        property url source
        property real cornerRadius: 6
        property bool defaultArtwork:false
        Rectangle {anchors.fill:parent;radius:roundedInstanceImage.cornerRadius;color:roundedInstanceImage.defaultArtwork?(macWindowMetrics.artworkTint(roundedInstanceImage.source) || "#80466E41"):"transparent"}
        Image {
            anchors.fill: parent
            anchors.margins:roundedInstanceImage.defaultArtwork?Math.min(parent.width,parent.height)*0.175:0
            source: roundedInstanceImage.source
            fillMode:roundedInstanceImage.defaultArtwork?Image.PreserveAspectFit:Image.PreserveAspectCrop
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: instanceIconMaskTexture
                maskThresholdMin: 0.5
                maskSpreadAtMin: 0
            }
        }
        Rectangle {
            id: instanceIconMask
            width: roundedInstanceImage.width
            height: roundedInstanceImage.height
            radius: roundedInstanceImage.cornerRadius
            color: "white"
            visible: false
        }
        ShaderEffectSource {
            id: instanceIconMaskTexture
            sourceItem: instanceIconMask
            hideSource: true
            live: true
            visible: false
        }
    }
    component SidebarControl: Rectangle {
        objectName: "sidebarGlassControl"
        property color fallbackColor: "transparent"
        property bool nativeSelected: false
        property string nativeRole: "row"
        color: macWindowMetrics.nativeSidebar ? "transparent" : fallbackColor
        onXChanged: if (appRoot) appRoot.queueSidebarMaterials()
        onYChanged: if (appRoot) appRoot.queueSidebarMaterials()
        onChildrenRectChanged: if (appRoot) appRoot.queueSidebarMaterials()
        onWidthChanged: if (appRoot) appRoot.queueSidebarMaterials()
        onHeightChanged: if (appRoot) appRoot.queueSidebarMaterials()
        onVisibleChanged: if (appRoot) appRoot.queueSidebarMaterials()
        onNativeSelectedChanged: if (appRoot) appRoot.queueSidebarMaterials()
        Component.onCompleted: if (appRoot) appRoot.queueSidebarMaterials()
    }
    Timer {
        id: sidebarMaterialSync
        interval: 0
        onTriggered: appRoot.syncSidebarMaterials()
    }
    property string sidebarMaterialSignature: ""
    function syncSidebarMaterials() {
        var rows = []
        if (sidebarProgress > 0.001 && macWindowMetrics.nativeSidebar) {
            var clipTop = sidebarScroll.mapToItem(null, 0, 0).y
            var clipBottom = sidebarAccountFooter.mapToItem(null, 0, 0).y - 14
            function visit(item, clipped) {
                if (!item || !item.visible) return
                if (item.objectName === "sidebarGlassControl") {
                    var point = item.mapToItem(null, 0, 0)
                    var top = clipped ? Math.max(point.y, clipTop) : point.y
                    var bottom = clipped ? Math.min(point.y + item.height, clipBottom) : point.y + item.height
                    if (bottom > top && item.width > 0)
                        rows.push({x: point.x, y: top, width: item.width, height: bottom - top,
                                   radius: item.radius, active: !!item.nativeSelected, role: item.nativeRole || "row",
                                   opacity: Math.min(1, sidebarProgress * 1.7)})
                }
                for (var i = 0; i < item.children.length; ++i) visit(item.children[i], clipped)
            }
            visit(sidebar, true)
            visit(sidebarAccountFooter, false)
        }
        var signature = JSON.stringify(rows)
        if (signature === sidebarMaterialSignature) return
        sidebarMaterialSignature = signature
        macWindowMetrics.setSidebarControls(rows)
    }
    Connections {
        target: appRoot
        function onAfterAnimating() {
            macWindowMetrics.setEditorGlass(appRoot.activePage === "Launch" ? appRoot.contentItem : appRoot.activePage === "Download" ? (appRoot.downloadSelection ? releasePage : downloadPage) : instanceEditorPage,
                appRoot.activePage === "Instance" || appRoot.activePage === "Download" || appRoot.activePage === "Launch")
            appRoot.syncNativePageUI()
            appRoot.syncCanvasCards()
            if(canvasQuickDownload.visible)macWindowMetrics.setAccountGlass(canvasQuickDownload.contentItem,true)
            if(accountSettingsPopup.visible)macWindowMetrics.setAccountGlass(accountSettingsPopup.contentItem,true)

            appRoot.syncSidebarMaterials()
            appRoot.syncNativeSearchButton()
            macWindowMetrics.setAccountButton(appRoot.width - 62, 18,
                Math.max(0, 1 - appRoot.sidebarProgress * 4),
                appRoot.sidebarProgress < 0.999, !appRoot.accountMenuOpen)
            if (sidebarCloseButton) {
                var point = sidebarCloseButton.mapToItem(null, 0, 0)
                macWindowMetrics.setSidebarButton(point.x, point.y, appRoot.sidebarProgress, topBar.parent.height)
            }
        }
        function onSelectedIdChanged() { appRoot.queueSidebarMaterials() }
        function onSidebarInstancesExpandedChanged() { appRoot.queueSidebarMaterials() }
        function onSidebarQuickDownloadExpandedChanged() {
            appRoot.queueSidebarMaterials()
            if (appRoot.sidebarQuickDownloadExpanded) downloadData.loadQuickVersions(false)
        }
    }
    Connections {
        target: macWindowMetrics
        function onNativeSidebarChanged() {
            if (macWindowMetrics.nativeSidebar)
                macWindowMetrics.animateSidebar(appRoot.sidebarMode, true)
        }
    }
    // Glass-styled ComboBox keeps Qt's native selection, keyboard and popup
    // handling while placing the popup in the unclipped application overlay.
    component NativeChevron: Image {
        property string symbol: "chevron.down"
        readonly property bool disclosure: symbol === "chevron.down" || symbol === "chevron.right" || symbol === "chevron.up"
        width:16; height:16
        source:{ var revision=macWindowMetrics.symbolRevision; return macWindowMetrics.symbolIcon(disclosure ? (symbol === "chevron.right" ? "appkit.disclosure.closed" : "appkit.disclosure.open") : symbol,appRoot.muted.toString()) }
        // The AppKit cell is centered in a padded canvas at its natural size.
        // Explicit raster size avoids treating Retina pixels as logical points.
        sourceSize.width:32; sourceSize.height:32
        fillMode:Image.PreserveAspectFit
    }
    component GlassSelect: ComboBox {
        id: glassSelectRoot
        property var options: []
        property string selected: ""
        property bool accountMaterial: false
        property bool nativeDownloadMaterial: false
        property bool sidebarMaterial: false
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
            color: appRoot.ink
            font.pixelSize: 12
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        indicator: GlassPane {
            x:glassSelectRoot.width-width-6; y:(glassSelectRoot.height-height)/2
            width:24; height:24; radius:12
            objectName:glassSelectRoot.sidebarMaterial ? "sidebarGlassControl" : ""
            property string nativeRole:"field"
            color:macWindowMetrics.nativeSidebar && glassSelectRoot.sidebarMaterial ? "transparent" : (appRoot.darkMode ? "#20FFFFFF" : "#20000000")
            border.width:0
            edgeGlow:false
            NativeChevron { anchors.centerIn:parent; width:14; height:14; symbol:"appkit.selector" }
            MouseArea {
                anchors.fill:parent
                onPressed:function(mouse) { if(glassSelectRoot.popup.visible)glassSelectRoot.popup.close();else glassSelectRoot.popup.open();mouse.accepted=true }
            }
        }
        background: Rectangle {
            objectName: glassSelectRoot.accountMaterial && macWindowMetrics.nativeGlassDock ? "accountGlassControl" : glassSelectRoot.nativeDownloadMaterial && macWindowMetrics.nativeGlassDock ? "editorGlassControl" : (glassSelectRoot.sidebarMaterial ? "sidebarGlassControl" : "")
            property bool nativeSelected: glassSelectRoot.popup.visible
            property string nativeRole: "field"
            radius: glassSelectRoot.cornerRadius
            color: (glassSelectRoot.accountMaterial && macWindowMetrics.nativeGlassDock) || (glassSelectRoot.nativeDownloadMaterial && macWindowMetrics.nativeGlassDock) || (macWindowMetrics.nativeSidebar && glassSelectRoot.sidebarMaterial) ? "transparent" : (appRoot.darkMode ? "#3E57768C" : "#C7EAF4FC")
            border.width: (glassSelectRoot.accountMaterial && macWindowMetrics.nativeGlassDock) || (glassSelectRoot.nativeDownloadMaterial && macWindowMetrics.nativeGlassDock) || (macWindowMetrics.nativeSidebar && glassSelectRoot.sidebarMaterial) ? 0 : 1
            border.color: glassSelectRoot.hovered || glassSelectRoot.popup.visible
                          ? appRoot.accent : appRoot.outline
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
                color: appRoot.ink
                font.pixelSize: 12
                font.bold: modelData === glassSelectRoot.selected
                verticalAlignment: Text.AlignVCenter
            }
            onHoveredChanged: if(selectorPopup.visible && macWindowMetrics.nativeGlassDock)macWindowMetrics.setAccountGlass(selectorPopup.contentItem,true)
            background: Rectangle {
                objectName: macWindowMetrics.nativeGlassDock && (modelData === glassSelectRoot.selected || parent.hovered) ? "accountGlassControl" : ""
                property bool selectedGlass: modelData === glassSelectRoot.selected
                radius: 13
                color: macWindowMetrics.nativeGlassDock ? "transparent" : modelData === glassSelectRoot.selected
                       ? (appRoot.darkMode ? "#5474AAD1" : "#9BC8E8FA")
                       : (parent.hovered ? (appRoot.darkMode ? "#30FFFFFF" : "#80FFFFFF") : "transparent")
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
            popupType:macWindowMetrics.nativeGlassDock ? Popup.Window : Popup.Item
            onOpened:if(macWindowMetrics.nativeGlassDock)macWindowMetrics.setAccountGlass(contentItem,true)
            onClosed:if(macWindowMetrics.nativeGlassDock)macWindowMetrics.setAccountGlass(contentItem,false)
            Timer { interval:16;repeat:true;running:selectorPopup.visible && macWindowMetrics.nativeGlassDock;onTriggered:macWindowMetrics.setAccountGlass(selectorPopup.contentItem,true) }
            focus: true
            modal: false
            padding: 6
            z: 300
            width: glassSelectRoot.width
            height: Math.min(glassSelectRoot.options.length * 39 + 12, appRoot.height - 24)
            readonly property point triggerPoint: glassSelectRoot.mapToItem(appRoot.contentItem, 0, 0)
            readonly property real triggerGap: 8
            y: triggerPoint.y + glassSelectRoot.height + triggerGap + height <= appRoot.height - 12
               ? glassSelectRoot.height + triggerGap
               : -height - triggerGap
            closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutsideParent
            background: GlassPane {
                radius: 24
                emphasized: true
                color:macWindowMetrics.nativeAccountGlass?"transparent":appRoot.glassStrong
                edgeGlow:!macWindowMetrics.nativeAccountGlass
                border.width:macWindowMetrics.nativeAccountGlass?0:1
                border.color: appRoot.outline
            }
            contentItem: ListView {
                clip: true
                model: selectorPopup.visible ? glassSelectRoot.delegateModel : null
                currentIndex: glassSelectRoot.highlightedIndex
                onContentYChanged:if(selectorPopup.visible && macWindowMetrics.nativeGlassDock)macWindowMetrics.setAccountGlass(selectorPopup.contentItem,true)
                implicitHeight: contentHeight
                ScrollBar.vertical: ScrollBar { }
            }
        }
    }

    // Shared QML fallback glass surface. On macOS 26 and later the persistent
    // launch dock is replaced by an AppKit NSGlassEffectView; other QML panes
    // still use this cross-platform approximation until their native bridge.
    component GlassPane: Rectangle {
        property bool prominent: false
        property string materialRole: "glass"
        property bool emphasized: false
        property bool subtle: false
        property bool selectedGlass: false
        property bool edgeGlow: true
        // Only overlays OUTSIDE sceneLayer may capture it: this prevents
        // feedback loops and keeps instance cards efficient.
        property bool backdropBlur: false
        radius: appRoot.panelRadius
        clip: backdropBlur
        color: backdropBlur ? (appRoot.darkMode ? "#66324661" : "#99F4FAFF")
                            : (subtle ? appRoot.glassSoft : (emphasized ? appRoot.glassStrong : appRoot.glass))
        border.width: selectedGlass ? 1.6 : 1
        border.color: selectedGlass ? appRoot.accent : appRoot.outline
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
            opacity: appRoot.darkMode ? 0.84 : 0.90
            z: 0
        }
        // Top-edge specular sheen, clipped to the panel shape.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Math.max(0, parent.radius - 1)
            color: "transparent"
            border.width: 1
            border.color: appRoot.darkMode ? "#23FFFFFF" : "#78FFFFFF"
            visible: parent.edgeGlow
            z: -1
        }
        Behavior on color { ColorAnimation { duration: appRoot.motionMs } }
        Behavior on border.color { ColorAnimation { duration: appRoot.motionMs } }
        // Broad, low-contrast specular gradient; the native material bridge
        // is a separate macOS integration and is not emulated here.
        Rectangle {
            anchors.fill: parent
            anchors.margins: 2
            radius: Math.max(0, parent.radius - 2)
            gradient: Gradient { GradientStop { position: 0.0; color: appRoot.darkMode ? "#1CFFFFFF" : "#50FFFFFF" } GradientStop { position: 0.22; color: "#08FFFFFF" } GradientStop { position: 0.85; color: "#00FFFFFF" } GradientStop { position: 1.0; color: appRoot.darkMode ? "#0DFFFFFF" : "#15FFFFFF" } }
            opacity: parent.edgeGlow ? 0.65 : 0.0
            z: -1
        }
    }

    ListModel {
        id: instances
        ListElement { key: "rebirth"; coverKey: "rebirth"; label: "The Rebirth"; version: "Fabric 1.21.5"; hours: 182; launches: 96; installed: true; lastPlayed: true }
        ListElement { key: "vanilla"; coverKey: "vanilla"; label: "Survival"; version: "Minecraft 1.20.1"; hours: 25; launches: 48; installed: true; lastPlayed: false }
        ListElement { key: "creative"; coverKey: "creative"; label: "Creative"; version: "Minecraft 26.3"; hours: 8; launches: 33; installed: true; lastPlayed: false }
        ListElement { key: "skyblock"; coverKey: "skyblock"; label: "Skyblock"; version: "Fabric 1.21.1"; hours: 61; launches: 124; installed: true; lastPlayed: false }
        ListElement { key: "adventure"; coverKey: "adventure"; label: "Adventure"; version: "NeoForge 1.21.1"; hours: 44; launches: 22; installed: true; lastPlayed: false }
        ListElement { key: "redstone"; coverKey: "redstone"; label: "Redstone Lab"; version: "Minecraft 1.21.5"; hours: 16; launches: 83; installed: true; lastPlayed: false }
        ListElement { key: "factory"; coverKey: "factory"; label: "Factory"; version: "Forge 1.20.1"; hours: 102; launches: 57; installed: true; lastPlayed: false }
        ListElement { key: "hardcore"; coverKey: "hardcore"; label: "Hardcore"; version: "Minecraft 1.21.8"; hours: 3; launches: 7; installed: true; lastPlayed: false }
        ListElement { key: "explorer"; coverKey: "explorer"; label: "Explorer"; version: "Fabric 1.21.4"; hours: 79; launches: 41; installed: true; lastPlayed: false }
        ListElement { key: "builders"; coverKey: "builders"; label: "Builders"; version: "Minecraft 1.20.4"; hours: 12; launches: 65; installed: true; lastPlayed: false }
        ListElement { key: "legacy"; coverKey: "legacy"; label: "Legacy World"; version: "Forge 1.12.2"; hours: 35; launches: 18; installed: true; lastPlayed: false }
        ListElement { key: "fabric"; coverKey: "fabric"; label: "Fabric 1.21.8"; version: "Quick download"; hours: 0; launches: 0; installed: false; lastPlayed: false }
        ListElement { key: "neoforge"; coverKey: "neoforge"; label: "NeoForge"; version: "Quick download"; hours: 0; launches: 0; installed: false; lastPlayed: false }
        ListElement { key: "quilt"; coverKey: "quilt"; label: "Quilt"; version: "Quick download"; hours: 0; launches: 0; installed: false; lastPlayed: false }
    }
    property var sortedCards: {
        var a = []
        for (var i = 0; i < instances.count; i++) {
            var v = instances.get(i)
            if(prismBridge.instances.length>0 && v.installed && v.key.indexOf("prism:")!==0)continue
            if ((!v.installed && !quickCards) ||
                (searchText.length && (v.label + " " + v.version).toLowerCase().indexOf(searchText.toLowerCase()) < 0)) continue
            a.push({ key: v.key, label: v.label, version: v.version, hours: v.hours, launches: v.launches, installed: v.installed, coverKey: v.coverKey || v.key, background: (cardMetadata[v.key]||{}).background || "" })
        }
        if (sortMode === "Name") a.sort(function(x,y) { return x.label.localeCompare(y.label) })
        else if (sortMode === "Smart") a.sort(function(x,y) { return y.hours - x.hours || y.launches - x.launches })
        else if (sortMode === "Custom") {
            var order = appRoot.customInstanceOrder
            a.sort(function(x,y) {
                var xi=order.indexOf(x.key), yi=order.indexOf(y.key)
                return (xi < 0 ? 100000 : xi) - (yi < 0 ? 100000 : yi)
            })
        }
        return a
    }
    function sidebarOrderIndex(key) {
        var list=sidebarInstalledCards()
        for(var i=0;i<list.length;i++)if(list[i].key===key)return i
        return -1
    }
    function updateInstanceDrop(sceneY) {
        instanceDragSceneY=sceneY
        var all=sidebarInstalledCards(), display=sidebarDisplayRows(), y=instanceRows.mapFromItem(null,0,sceneY).y, top=0
        instanceDropSlot=0
        for(var i=0;i<display.length;i++) {
            var row=display[i], height=row.type==="header"?28:35
            if(row.type==="instance" && y<top+height/2) {
                for(var j=0;j<all.length;j++)if(all[j].key===row.key){instanceDropSlot=j;return}
            }
            if(row.type==="instance")instanceDropSlot=sidebarOrderIndex(row.key)+1
            top+=height+3
        }
    }
    function commitInstanceDrop(key, slot) {
        var visibleRows = sidebarInstalledCards()
        if (!key || slot < 0 || !visibleRows.length) return
        var keys = sortedCards.map(function(card){return card.key})
        for (var i=0; i<instances.count; i++) {
            var id = instances.get(i).key
            if (keys.indexOf(id)<0) keys.push(id)
        }
        var after = slot >= visibleRows.length
        var target = visibleRows[after ? visibleRows.length-1 : slot].key
        customInstanceOrder = CanvasLayout.reorder(keys, key, target, after)
        sortMode="Custom"
    }
    function sidebarInstalledCards() {
        var a = []
        var source = appRoot.sortedCards
        for (var i = 0; i < source.length; ++i) {
            if (source[i].installed) a.push(source[i])
        }
        return a
    }
    readonly property var selectedDockCard: {
        var cards=sortedCards
        for(var i=0;i<cards.length;i++)if(cards[i].key===selectedId)return cards[i]
        return null
    }
    readonly property string selectedDockArtwork: selectedDockCard ? (selectedDockCard.background || defaultCardArt(selectedDockCard)) : ""
    readonly property bool selectedDockDefaultArtwork: !selectedDockCard || !selectedDockCard.background
    function syncDockArtwork() {
        macWindowMetrics.setDockArtwork(selectedDockArtwork,selectedDockDefaultArtwork)
        macWindowMetrics.setDockInfo(selectedLabel(),selectedVersion())
    }
    onSelectedDockArtworkChanged: syncDockArtwork()
    onSelectedDockDefaultArtworkChanged: syncDockArtwork()
    function selectedLabel() {
        for (var i=0;i<instances.count;i++) if (instances.get(i).key === selectedId) return instances.get(i).label
        return "Select a version"
    }
    function selectedVersion() {
        for (var i=0;i<instances.count;i++) if (instances.get(i).key === selectedId) return instances.get(i).version
        return ""
    }
    function chooseCard(c,keepSelection) {
        if (!c || !c.key) return
        if(!keepSelection) selectedCardKeys=[c.key]
        selectedId = c.key
        statusMessage = c.installed ? "Selected " + c.label : "Quick download: " + c.label
    }
    function defaultCardArt(c) {
        var key=c.coverKey||"vanilla"
        if(["fabric","forge","neoforge","quilt"].indexOf(key)<0)key="vanilla"
        return Qt.resolvedUrl("assets/default-"+key+((key==="vanilla"||key==="forge")?".png":".svg")).toString()
    }
    function activateCard(c) {
        chooseCard(c)
        if (!c.installed) {
            var loaders = {fabric:"Fabric",forge:"Forge",neoforge:"NeoForge",quilt:"Quilt"}
            sidebarQuickLoader = loaders[c.coverKey] || "Vanilla"
            canvasQuickDownload.open()
        } else if(c.key.indexOf("prism:")===0)prismBridge.launch(c.key)
        else {statusMessage="Test card · Connect a real Prism instance to launch";prismConnection.open()}
    }
    function toggleSearch() {
        searchExpanded = !searchExpanded
        if (searchExpanded && !macWindowMetrics.nativeGlassDock) searchInput.forceActiveFocus()
        else searchInput.focus = false
    }
    property bool cardSizeEditing:false
    property string customCardSizesJson:"{}"
    readonly property var customCardSizes:JSON.parse(customCardSizesJson)
    readonly property var cardSizeBounds:({minWidth:180,minHeight:126,maxWidth:640,maxHeight:480})
    property string groupCardSizesJson:"{}"
    readonly property var groupCardSizes:JSON.parse(groupCardSizesJson)
    function cardSizeGroupKey(key) {
        var groups=effectiveInstanceGroups
        for(var i=0;i<groups.length;i++)if(groups[i].keys.indexOf(key)>=0)return groupingMethod+":"+groups[i].id
        return groupingMethod+":ungrouped"
    }
    function cardSize(key,width,height) {
        return (hasInstanceGroups?groupCardSizes[cardSizeGroupKey(key)]:customCardSizes[key]) || {width:width,height:height}
    }
    function setCardSize(key,width,height) {
        var bounded=CanvasLayout.resizeRect({x:0,y:0,width:width,height:height},"bottomright",0,0,cardSizeBounds)
        if(hasInstanceGroups) {
            var groupSizes=JSON.parse(groupCardSizesJson);groupSizes[cardSizeGroupKey(key)]={width:bounded.width,height:bounded.height};groupCardSizesJson=JSON.stringify(groupSizes)
            return
        }
        var sizes=JSON.parse(customCardSizesJson);sizes[key]={width:bounded.width,height:bounded.height};customCardSizesJson=JSON.stringify(sizes)
        if(freeCanvasActive)setFreeRect(key,{width:bounded.width,height:bounded.height})
    }
    function toggleCardSizeEditing() {
        cardSizeEditing=!cardSizeEditing
        statusMessage=cardSizeEditing?"Resize: 180×126–640×480 · Esc to finish":"Card sizes saved"
    }
    function resizeCardFromEdge(key,start,edge,dx,dy) {
        var rect=CanvasLayout.resizeRect(start,edge,dx,dy,cardSizeBounds)
        setCardSize(key,rect.width,rect.height)
        if(freeCanvasActive)setFreeRect(key,rect)
    }
    Shortcut {sequence:"Escape";enabled:appRoot.cardSizeEditing;onActivated:{appRoot.cardSizeEditing=false;appRoot.statusMessage="Card sizes saved"}}
    property bool freeCanvasEnabled:false
    readonly property bool freeCanvasActive:freeCanvasEnabled && !hasInstanceGroups
    property string freeRectsJson:"{}"
    property string freeHiddenJson:"[]"
    property bool freeCardDragging:false
    property bool freeAvoidOverlap:false
    property int freeMinimumGap:24
    function freeLayer(key) {var r=freeRects[key];return r && r.layer!==undefined ? r.layer : 0}
    function reorderFreeLayers(keys,action) {
        var cards=canvasCards.slice().sort(function(a,b){return freeLayer(a.key)-freeLayer(b.key)})
        var selected=cards.filter(function(c){return keys.indexOf(c.key)>=0}),others=cards.filter(function(c){return keys.indexOf(c.key)<0})
        if(action==="front")cards=others.concat(selected)
        else if(action==="back")cards=selected.concat(others)
        else if(action==="up") {for(var i=cards.length-2;i>=0;i--)if(keys.indexOf(cards[i].key)>=0 && keys.indexOf(cards[i+1].key)<0){var c=cards[i];cards[i]=cards[i+1];cards[i+1]=c}}
        else {for(var i=1;i<cards.length;i++)if(keys.indexOf(cards[i].key)>=0 && keys.indexOf(cards[i-1].key)<0){var c=cards[i];cards[i]=cards[i-1];cards[i-1]=c}}
        var rects=JSON.parse(freeRectsJson),auto=CanvasLayout.spread(canvasCards.length,24);cards.forEach(function(c,i){if(!rects[c.key])rects[c.key]=auto[canvasCards.indexOf(c)];rects[c.key].layer=i});freeRectsJson=JSON.stringify(rects)
    }
    function normalizeFreeSpacing() {
        if(!freeAvoidOverlap || !freeCanvasActive)return
        var rects=JSON.parse(freeRectsJson),placed=[]
        var auto=CanvasLayout.spread(canvasCards.length,24)
        canvasCards.forEach(function(c,i){var r=rects[c.key] || auto[i];rects[c.key]=r;var safe=CanvasLayout.avoidOverlap(r,placed,freeMinimumGap);r.x=safe.x;r.y=safe.y;placed.push(r)})
        var encoded=JSON.stringify(rects);if(encoded!==freeRectsJson)freeRectsJson=encoded
    }
    onFreeCanvasActiveChanged:normalizeFreeSpacing()
    onFreeAvoidOverlapChanged:normalizeFreeSpacing()
    onFreeMinimumGapChanged:normalizeFreeSpacing()
    readonly property var freeRects:JSON.parse(freeRectsJson)
    readonly property var freeHidden:JSON.parse(freeHiddenJson)
    readonly property var canvasCards:sortedCards.filter(function(c){return freeHidden.indexOf(c.key)<0})
    function setFreeRect(key,patch) {
        var rects=JSON.parse(freeRectsJson),rect=rects[key] || {x:0,y:0,width:240,height:168}
        Object.keys(patch).forEach(function(k){rect[k]=patch[k]})
        if(freeAvoidOverlap && freeCanvasActive && !cardSizeEditing && (patch.x!==undefined || patch.y!==undefined || patch.width!==undefined || patch.height!==undefined)) {
            var obstacles=canvasCards.filter(function(c){return c.key!==key}).map(function(c){return rects[c.key]}).filter(function(r){return !!r})
            var safe=CanvasLayout.avoidOverlap(rect,obstacles,freeMinimumGap);rect.x=safe.x;rect.y=safe.y
        }
        rects[key]=rect;freeRectsJson=JSON.stringify(rects)
    }
    function setFreeVisible(key,show) {
        var hidden=freeHidden.filter(function(k){return k!==key});if(!show)hidden.push(key)
        freeHiddenJson=JSON.stringify(hidden);normalizeFreeSpacing()
    }
    function enableFreeCanvas() {
        var rects=JSON.parse(freeRectsJson),auto=CanvasLayout.spread(sortedCards.length,24)
        sortedCards.forEach(function(c,i){if(!rects[c.key])rects[c.key]=auto[i]})
        freeRectsJson=JSON.stringify(rects);freeCanvasEnabled=!freeCanvasEnabled;normalizeFreeSpacing()
    }
    Timer { id:canvasBoundsSettle;interval:0;onTriggered:appRoot.clampCanvas() }
    function clampCanvas() {
        if(hasInstanceGroups || freeCardDragging || !world || !canvas)return
        var bounds=world.currentPanLimits
        var x=Math.max(bounds.minX,Math.min(bounds.maxX,panX))
        var y=Math.max(bounds.minY,Math.min(bounds.maxY,panY))
        if(Math.abs(x-panX)>0.01)panX=x
        if(Math.abs(y-panY)>0.01)panY=y
    }
    Connections {
        target:appRoot
        function onPanXChanged(){appRoot.clampCanvas()}
        function onPanYChanged(){appRoot.clampCanvas()}
        function onZoomChanged(){canvasBoundsSettle.restart()}
        function onWidthChanged(){canvasBoundsSettle.restart()}
        function onHeightChanged(){canvasBoundsSettle.restart()}
        function onSortedCardsChanged(){appRoot.normalizeFreeSpacing();canvasBoundsSettle.restart()}
        function onCanvasCardsChanged(){canvasBoundsSettle.restart()}
        function onSidebarProgressChanged(){canvasBoundsSettle.restart()}
        function onHasInstanceGroupsChanged(){canvasBoundsSettle.restart()}
    }
    function resetCanvas() { panX=0; panY=0; zoom=1;canvasBoundsSettle.restart() }
    function changeZoom(factor) {
        zoom = Math.max(0.55, Math.min(1.65, zoom * factor))
    }
    // Keyboard navigation: zoom in/out and return to the original view.
    Shortcut { sequences: ["Ctrl++", "Ctrl+="]; enabled: appRoot.activePage === "Launch"; onActivated: appRoot.changeZoom(1.12) }
    Shortcut { sequence: "Ctrl+-"; enabled: appRoot.activePage === "Launch"; onActivated: appRoot.changeZoom(1 / 1.12) }
    Shortcut { sequence: "Ctrl+0"; enabled: appRoot.activePage === "Launch"; onActivated: appRoot.resetCanvas() }
    // Direct trackpad pinching must feel immediate; the slider animates its own thumb.


    component CanvasCard: GlassPane {
        id:instanceCard
        objectName:"canvasNativeCard"
        opacity:macWindowMetrics.nativeGlassDock?0:1
        materialRole:"quickCard"
        color:modelData.installed || macWindowMetrics.nativeGlassDock ? "transparent" : appRoot.glassSoft
        edgeGlow:false
        border.width:modelData.installed && selectedGlass?2:0
        required property var modelData
        property bool featured:false
        property bool resizeHovered:false
        readonly property real footerFadeStart:Math.max(0,Math.min(1,(cardCaption.y-12)/height))
        width:240;height:168;radius:appRoot.cardRadius
        selectedGlass:appRoot.selectedCardKeys.indexOf(modelData.key)>=0
        Item {
            anchors.fill:parent;anchors.margins:2
            layer.enabled:true
            layer.effect:MultiEffect { maskEnabled:true;maskSource:coverMaskTexture }
            Image {
                id:cardArtwork;anchors.fill:parent;visible:instanceCard.modelData.installed
                source:visible ? instanceCard.modelData.background || appRoot.defaultCardArt(instanceCard.modelData) : ""
                fillMode:Image.PreserveAspectCrop
            }
            Rectangle {
                id:bottomFadeMask;width:parent.width;height:parent.height
                visible:false;layer.enabled:true
                gradient:Gradient {
                    GradientStop { position:0;color:"transparent" }
                    GradientStop { position:instanceCard.footerFadeStart;color:"transparent" }
                    GradientStop { position:instanceCard.footerFadeStart+(1-instanceCard.footerFadeStart)*0.45;color:"white" }
                    GradientStop { position:1;color:"white" }
                }
            }
            MultiEffect {
                anchors.fill:parent;visible:instanceCard.modelData.installed
                source:cardArtwork;blurEnabled:true;blur:0.75;blurMax:40
                maskEnabled:true;maskSource:bottomFadeMask
                maskThresholdMin:0.5;maskSpreadAtMin:1.0
            }
            Rectangle {
                anchors.fill:parent;visible:instanceCard.modelData.installed
                gradient:Gradient {
                    GradientStop { position:0;color:"transparent" }
                    GradientStop { position:instanceCard.footerFadeStart;color:"transparent" }
                    GradientStop { position:instanceCard.footerFadeStart+(1-instanceCard.footerFadeStart)*0.45;color:"#99000000" }
                    GradientStop { position:1;color:"#D9000000" }
                }
            }
        }
        Rectangle { id:coverMask;width:parent.width-4;height:parent.height-4;radius:Math.max(0,parent.radius-2);color:"white";visible:false }
        ShaderEffectSource { id:coverMaskTexture;sourceItem:coverMask;hideSource:true;live:true;visible:false }
        Text { visible:!modelData.installed;x:20;y:16;text:"↓";color:appRoot.accent;font.pixelSize:28 }
        Column {
            id:cardCaption
            anchors.left:parent.left;anchors.leftMargin:20
            anchors.bottom:parent.bottom;anchors.bottomMargin:18
            width:Math.max(60,parent.width-(modelData.installed?148:40));spacing:5
            Text { width:parent.width;text:modelData.label;font.pixelSize:featured?22:18;font.bold:true;color:!modelData.installed?appRoot.ink:"white";elide:Text.ElideRight }
            Text { width:parent.width;text:modelData.version;font.pixelSize:12;color:!modelData.installed?appRoot.muted:"#DDE6ED";elide:Text.ElideRight }
        }
        Text {
            visible:modelData.installed
            anchors.right:parent.right;anchors.rightMargin:16
            anchors.bottom:parent.bottom;anchors.bottomMargin:18
            width:100;horizontalAlignment:Text.AlignRight;elide:Text.ElideRight
            text:Number(Number(modelData.hours || 0).toFixed(2))+" h · "+modelData.launches+" runs"
            color:"#DDE6ED";font.pixelSize:10
        }
        DragHandler {
            target:null;enabled:appRoot.freeCanvasActive && !appRoot.cardSizeEditing;acceptedButtons:Qt.LeftButton
            property real startX:0;property real startY:0
            onActiveChanged:{ if(active){startX=instanceCard.x;startY=instanceCard.y;appRoot.freeCardDragging=true}else {appRoot.freeCardDragging=false;canvasBoundsSettle.restart()} }
            onTranslationChanged:if(active)appRoot.setFreeRect(instanceCard.modelData.key,{x:startX+translation.x/appRoot.zoom,y:startY+translation.y/appRoot.zoom})
        }
        Repeater {
            model:appRoot.cardSizeEditing?(appRoot.freeCanvasActive?["top","bottom","left","right","topleft","topright","bottomleft","bottomright"]:["right","bottom","bottomright"]):[]
            delegate:MouseArea {
                required property string modelData
                objectName:"cardResizeHandle-"+instanceCard.modelData.key+"-"+modelData
                readonly property bool horizontal:modelData==="top" || modelData==="bottom"
                readonly property bool vertical:modelData==="left" || modelData==="right"
                readonly property real handle:12
                x:modelData.indexOf("left")>=0?0:modelData.indexOf("right")>=0?instanceCard.width-handle:handle
                y:modelData.indexOf("top")>=0?0:modelData.indexOf("bottom")>=0?instanceCard.height-handle:handle
                width:horizontal?Math.max(handle,instanceCard.width-handle*2):handle
                height:vertical?Math.max(handle,instanceCard.height-handle*2):handle
                z:20;acceptedButtons:Qt.LeftButton;hoverEnabled:true;preventStealing:true
                cursorShape:horizontal?Qt.SizeVerCursor:vertical?Qt.SizeHorCursor:(modelData==="topleft" || modelData==="bottomright")?Qt.SizeFDiagCursor:Qt.SizeBDiagCursor
                Rectangle {anchors.fill:parent;radius:3;color:appRoot.accent;opacity:parent.containsMouse?0.3:0.08;visible:!macWindowMetrics.nativeGlassDock}
                property var startRect:({})
                property point startScene:Qt.point(0,0)
                property real sceneScale:1
                onEntered:instanceCard.resizeHovered=true
                onExited:if(!pressed)instanceCard.resizeHovered=false
                onPressed:function(mouse) {
                    appRoot.selectCanvasCard(instanceCard.modelData,Qt.NoModifier)
                    startRect={x:instanceCard.x,y:instanceCard.y,width:instanceCard.width,height:instanceCard.height}
                    startScene=mapToItem(appRoot.contentItem,mouse.x,mouse.y)
                    var p=instanceCard.mapToItem(appRoot.contentItem,0,0),q=instanceCard.mapToItem(appRoot.contentItem,instanceCard.width,0)
                    sceneScale=Math.max(0.01,Math.abs(q.x-p.x)/instanceCard.width)
                    appRoot.freeCardDragging=true
                }
                onPositionChanged:function(mouse) {
                    if(!pressed)return
                    var point=mapToItem(appRoot.contentItem,mouse.x,mouse.y)
                    appRoot.resizeCardFromEdge(instanceCard.modelData.key,startRect,modelData,(point.x-startScene.x)/sceneScale,(point.y-startScene.y)/sceneScale)
                }
                onReleased:{appRoot.freeCardDragging=false;instanceCard.resizeHovered=containsMouse;appRoot.normalizeFreeSpacing();canvasBoundsSettle.restart()}
                onCanceled:{appRoot.freeCardDragging=false;instanceCard.resizeHovered=false;canvasBoundsSettle.restart()}
            }
        }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            if(mouse.button===Qt.RightButton) {
                                var point=mapToItem(appRoot.contentItem,mouse.x,mouse.y)
                                appRoot.openCardMenu(modelData,point.x,point.y)
                            } else appRoot.selectCanvasCard(modelData,mouse.modifiers)
                        }
                        onDoubleClicked: function(mouse) {
                            if(!appRoot.cardSizeEditing && mouse.button===Qt.LeftButton && !(mouse.modifiers & (Qt.ControlModifier|Qt.MetaModifier|Qt.ShiftModifier)))appRoot.activateCard(modelData)
                        }
                    }
    }

    // Composite background and cards into one offscreen scene for sidebar blur.
    // The sidebar itself is outside this scene to avoid recursive capture.
    Item {
        id: sceneViewport
        y: -appRoot.contentItem.y
        x: macWindowMetrics.nativeSidebar ? appRoot.contentLeft : 0
        width: appRoot.width - x
        height: parent.height + appRoot.contentItem.y
        clip: true
        Item {
        id: sceneLayer
        objectName: "sidebarSceneSource"
        x: -sceneViewport.x
        width: appRoot.width
        height: sceneViewport.height
    Rectangle {
        id: backgroundBackdrop
        anchors.fill: parent
        color: appRoot.backgroundMode==="Custom color"?appRoot.customColorStart:appRoot.backgroundColor
        visible: !macWindowMetrics.nativeSidebar
    }
    Canvas {
        id:customGradientCanvas
        anchors.fill:parent;visible:appRoot.backgroundMode==="Custom color" && appRoot.customGradient && !macWindowMetrics.nativeSidebar
        onWidthChanged:requestPaint();onHeightChanged:requestPaint()
        Connections {target:appRoot
            function onCustomColorStartChanged(){customGradientCanvas.requestPaint()}
            function onCustomColorEndChanged(){customGradientCanvas.requestPaint()}
            function onCustomGradientAngleChanged(){customGradientCanvas.requestPaint()}
            function onGradientStopsJsonChanged(){customGradientCanvas.requestPaint()}
        }
        onPaint:{var c=getContext("2d"),a=appRoot.customGradientAngle*Math.PI/180,span=(Math.abs(width*Math.cos(a))+Math.abs(height*Math.sin(a)))/2;var g=c.createLinearGradient(width/2-Math.cos(a)*span,height/2-Math.sin(a)*span,width/2+Math.cos(a)*span,height/2+Math.sin(a)*span);var stops=appRoot.gradientStops.slice().sort(function(a,b){return a.position-b.position});for(var i=0;i<stops.length;i++)g.addColorStop(stops[i].position,stops[i].color);c.fillStyle=g;c.fillRect(0,0,width,height)}
    }
    Image {
        id: wallpaperImage
        anchors.fill: parent
        source: appRoot.backgroundMode === "Custom" ? appRoot.backgroundImage : ""
        visible: appRoot.backgroundMode === "Custom" && !macWindowMetrics.nativeSidebar
        asynchronous: true
        clip: true
        fillMode: appRoot.backgroundPlacement === "Stretch" ? Image.Stretch
                  : appRoot.backgroundPlacement === "Fit" ? Image.PreserveAspectFit
                  : appRoot.backgroundPlacement === "Center" ? Image.Pad
                  : appRoot.backgroundPlacement === "Tile" ? Image.Tile : Image.PreserveAspectCrop
    }

    // Full-window canvas: the floating controls never divide the background.
    Item {
        id: canvas
        anchors.fill: parent
        clip: true
        visible: appRoot.activePage === "Launch"
        MouseArea {
            anchors.fill: parent
            acceptedButtons: appRoot.freeCanvasActive ? Qt.LeftButton|Qt.RightButton : Qt.RightButton
            property point lastPoint:Qt.point(0,0)
            onPressed:function(mouse){lastPoint=Qt.point(mouse.x,mouse.y)}
            onPositionChanged:function(mouse){if(appRoot.freeCanvasActive && pressed && (pressedButtons & Qt.LeftButton)){appRoot.panX+=mouse.x-lastPoint.x;appRoot.panY+=mouse.y-lastPoint.y;lastPoint=Qt.point(mouse.x,mouse.y)}}
            onClicked: function(mouse) { if(mouse.button!==Qt.RightButton)return;var point=mapToItem(appRoot.contentItem,mouse.x,mouse.y);canvasAppearanceMenu.popup(point.x,point.y) }
        }
        Item {
            id: world
            visible: !appRoot.hasInstanceGroups
            readonly property var cardPositions: {
                if(appRoot.hasInstanceGroups)return []
                var auto=CanvasLayout.spread(appRoot.canvasCards.length,24,appRoot.canvasCards.map(function(c){return appRoot.customCardSizes[c.key] || null}))
                return appRoot.canvasCards.map(function(c,i){
                    if(!appRoot.freeCanvasActive)return auto[i]
                    var rect=Object.assign({},appRoot.freeRects[c.key] || auto[i]),size=appRoot.customCardSizes[c.key]
                    if(size){rect.width=size.width;rect.height=size.height}
                    return rect
                })
            }
            readonly property var currentPanLimits: CanvasLayout.panLimits(cardPositions,appRoot.zoom,originX,originY,
                {left:(macWindowMetrics.nativeSidebar?24:appRoot.contentLeft+24)-80,
                 top:(appRoot.sidebarProgress>0.5?appRoot.sidebarPageWindowTop:appRoot.compactPageTop)-80,
                 right:canvas.width+56,bottom:canvas.height-32},{x:32,y:180})
            onCurrentPanLimitsChanged:canvasBoundsSettle.restart()
            readonly property real originX:(canvas.width+appRoot.contentLeft)/2
            x:originX+appRoot.panX
            readonly property real layoutTop: appRoot.canvasCards.length ? Math.min.apply(null,CanvasLayout.spread(appRoot.canvasCards.length,24).map(function(rect){return rect.y})) : 0
            readonly property real originY:(canvas.height/2-appRoot.compactContentRise)*(1-appRoot.sidebarProgress)+(appRoot.sidebarPageWindowTop-layoutTop*appRoot.zoom)*appRoot.sidebarProgress
            y:originY+appRoot.panY
            scale: appRoot.zoom
            Repeater {
                model: appRoot.hasInstanceGroups ? [] : appRoot.canvasCards
                delegate: CanvasCard {
                    required property int index
                    featured: index === 0
                    readonly property var placement: world.cardPositions[index] || ({x:0,y:0,width:240,height:168})
                    x: placement.x; y: placement.y; width: placement.width; height: placement.height
                    z:appRoot.freeCanvasActive?appRoot.freeLayer(modelData.key):0
                }
            }
        }
        Flickable {
            id: groupedPage
            visible: appRoot.hasInstanceGroups
            // Clip only at the window edge. Insets belong to scrollable content.
            x: 0; y: 0
            width: canvas.width
            height: canvas.height
            readonly property real contentInsetLeft: appRoot.contentLeft+28
            readonly property real contentInsetTop: appRoot.compactPageTop * (1-appRoot.sidebarProgress) + appRoot.sidebarPageWindowTop*appRoot.sidebarProgress
            readonly property real contentInsetBottom: bottomDock.height+44
            contentWidth: width
            contentHeight: contentInsetTop+groupedColumn.implicitHeight+contentInsetBottom
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds
            interactive:!appRoot.freeCardDragging
            clip: true
            ScrollBar.vertical: ScrollBar { }
            Connections {
                target: appRoot
                function onGroupingMethodChanged() { groupedPage.contentY=0 }
                function onGroupedLayoutEnabledChanged() { groupedPage.contentY=0 }
            }
            Column {
                id: groupedColumn
                y: groupedPage.contentInsetTop
                width: groupedPage.width
                spacing: 36
                Repeater {
                    id: groupedSections
                    model: appRoot.hasInstanceGroups ? CanvasLayout.grouped(appRoot.canvasCards,appRoot.effectiveInstanceGroups,appRoot.groupingMethod).sections : []
                    delegate: Item {
                        id: groupSection
                        required property var modelData
                        readonly property var cards: appRoot.canvasCards.filter(function(card) {
                            if (modelData.id === "ungrouped")
                                return !appRoot.effectiveInstanceGroups.some(function(g){return g.keys.indexOf(card.key)>=0})
                            var groups=appRoot.effectiveInstanceGroups.filter(function(g){return g.id===modelData.id})
                            return groups.length && groups[0].keys.indexOf(card.key)>=0
                        })
                        property alias rowViewport: groupRow
                        readonly property bool frequent: appRoot.groupingMethod === "Smart" && modelData.name === "Frequently played"
                        readonly property real cardWidth: modelData.cardWidth
                        readonly property real cardHeight: modelData.cardHeight
                        readonly property var rowMetrics:CanvasLayout.shelfSizes(cards.map(function(card){return appRoot.cardSize(card.key,cardWidth,cardHeight)}),24)
                        width: groupedColumn.width
                        height: cards.length ? rowMetrics.height+40 : 76
                        Text { height:implicitHeight+(42-implicitHeight)*appRoot.sidebarProgress; verticalAlignment:Text.AlignVCenter; x: groupedPage.contentInsetLeft; text: groupSection.modelData.name; color: appRoot.ink; font.pixelSize: 22; font.bold: true }
                        Text {
                            x: groupedPage.contentInsetLeft; y: 40; visible: !groupSection.cards.length
                            text: "Right-click a card to add it to this group"; color: appRoot.muted; font.pixelSize: 12
                        }
                        Item {
                            y: 40; width: parent.width; height: groupSection.rowMetrics.height
                            visible: groupSection.cards.length > 0
                            Flickable {
                                id: groupRow
                                anchors.fill: parent
                                contentWidth: groupedPage.contentInsetLeft+groupSection.rowMetrics.width+28
                                interactive:!appRoot.freeCardDragging
                                contentHeight: height
                                flickableDirection: Flickable.HorizontalFlick
                                boundsBehavior: Flickable.StopAtBounds
                                clip: true
                                Repeater {
                                    model: groupSection.cards
                                    delegate: CanvasCard {
                                        required property int index
                                        readonly property var sizePlacement:groupSection.rowMetrics.positions[index] || ({x:0,width:240,height:168})
                                        x: groupedPage.contentInsetLeft+sizePlacement.x; y: 0
                                        featured: groupSection.frequent
                                        width:sizePlacement.width;height:sizePlacement.height
                                    }
                                }
                            }

                        }
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: groupedPage
            visible: appRoot.hasInstanceGroups
            acceptedButtons: Qt.NoButton
            onWheel: function(event) {
                var pixels = event.pixelDelta.x !== 0 || event.pixelDelta.y !== 0
                var dx = pixels ? event.pixelDelta.x : event.angleDelta.x * 0.5
                var dy = pixels ? event.pixelDelta.y : event.angleDelta.y * 0.5
                var route = CanvasLayout.routeScroll(dx,dy,!!(event.modifiers & Qt.ShiftModifier))
                if(route.axis === "y") {
                    groupedPage.cancelFlick()
                    groupedPage.contentY=CanvasLayout.scrollPosition(groupedPage.contentY,route.delta,groupedPage.contentHeight,groupedPage.height)
                } else {
                    for(var i=0;i<groupedSections.count;i++) {
                        var section=groupedSections.itemAt(i)
                        if(!section)continue
                        var row=section.rowViewport
                        var point=row.mapToItem(groupedPage,0,0)
                        if(event.y>=point.y && event.y<point.y+row.height) {
                            row.cancelFlick()
                            row.contentX=CanvasLayout.scrollPosition(row.contentX,route.delta,row.contentWidth,row.width)
                            break
                        }
                    }
                }
                event.accepted=true
            }
        }
        PinchHandler {
            id: canvasPinch
            target: null
            enabled: !appRoot.hasInstanceGroups && appRoot.activePage === "Launch" && !appRoot.instancePickerOpen
                     && !sidebarHover.hovered && !navHover.hovered
                     && !searchHover.hovered && !bottomHover.hovered
            property real lastFactor: 1.0
            onActiveChanged: { lastFactor = 1.0 }
            onScaleChanged: {
                if (!active) return
                var factor = scale / Math.max(0.0001, lastFactor)
                appRoot.changeZoom(factor)
                lastFactor = scale
            }
        }
        DragHandler {
            id: canvasDrag
            target: null
            acceptedButtons: Qt.LeftButton
            // Overlay hover regions disable panning before the gesture begins.
            enabled: !appRoot.hasInstanceGroups && !appRoot.freeCanvasActive && appRoot.activePage === "Launch" && !appRoot.instancePickerOpen && !windowStripHover.hovered && !canvasPinch.active && !sidebarHover.hovered && !navHover.hovered && !searchHover.hovered && !statusHover.hovered && !bottomHover.hovered
            onTranslationChanged: {
                appRoot.panX += translation.x - previousTranslation.x
                appRoot.panY += translation.y - previousTranslation.y
                previousTranslation = translation
            }
            property point previousTranslation: Qt.point(0,0)
            onActiveChanged: if(!active)previousTranslation=Qt.point(0,0)
        }
        WheelHandler {
            target: null
            enabled: !appRoot.hasInstanceGroups && appRoot.activePage === "Launch" && !appRoot.instancePickerOpen && !canvasPinch.active
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: function(event) {
                if (appRoot.hasInstanceGroups || appRoot.activePage !== "Launch" || appRoot.instancePickerOpen || sidebarHover.hovered || navHover.hovered || searchHover.hovered || bottomHover.hovered) return
                if (event.modifiers & Qt.ControlModifier) {
                    var dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y
                    if (dy !== 0) appRoot.changeZoom(Math.exp(dy * 0.0015))
                } else {
                    appRoot.panX += event.pixelDelta.x !== 0 ? event.pixelDelta.x : event.angleDelta.x * .55
                    appRoot.panY += event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y * .55
                }
            }
        }
    }

    } // sceneLayer
    } // sceneViewport

    function syncCanvasCards() {
        if(!macWindowMetrics.nativeGlassDock)return
        var rows=[]
        function collect(item) {
            if(!item.visible)return
            if(item.objectName==="canvasNativeCard") {
                var p=item.mapToItem(null,0,0),q=item.mapToItem(null,item.width,item.height)
                var x=Math.min(p.x,q.x),y=Math.min(p.y,q.y),w=Math.abs(q.x-p.x),h=Math.abs(q.y-p.y)
                var left=Math.max(x,0),top=Math.max(0,y),right=Math.min(appRoot.width,x+w),bottom=Math.min(appRoot.height,y+h)
                for(var a=item.parent;a;a=a.parent)if(a.clip && a!==sceneViewport){var ap=a.mapToItem(null,0,0),aq=a.mapToItem(null,a.width,a.height);left=Math.max(left,Math.min(ap.x,aq.x));top=Math.max(top,Math.min(ap.y,aq.y));right=Math.min(right,Math.max(ap.x,aq.x));bottom=Math.min(bottom,Math.max(ap.y,aq.y))}
                var c=item.modelData,scale=w/Math.max(1,item.width)
                rows.push({key:c.key,x:x,y:y,width:w,height:h,scale:scale,radius:item.radius*scale,clipX:left,clipY:top,clipW:Math.max(0,right-left),clipH:Math.max(0,bottom-top),installed:c.installed,label:c.label,version:c.version,stats:Number(Number(c.hours||0).toFixed(2))+" h · "+c.launches+" runs",image:c.background || appRoot.defaultCardArt(c),defaultArtwork:!c.background,featured:item.featured,selected:item.selectedGlass,dark:appRoot.darkMode,resize:appRoot.cardSizeEditing && item.resizeHovered,editingSize:appRoot.cardSizeEditing,layer:item.z,order:rows.length})
                return
            }
            for(var i=0;i<item.children.length;i++)collect(item.children[i])
        }
        if(activePage==="Launch")collect(canvas)
        rows.sort(function(a,b){return a.layer-b.layer || a.order-b.order})
        macWindowMetrics.setCanvasCards(rows)
    }
    function syncNativeNavigation() {
        if (!downloadReady || !sidebar || !topBar) return
        macWindowMetrics.setNavigation(sidebarProgress, activePage, topBar.parent.height, sidebar.width)
        appRoot.queueSidebarMaterials()
        if (sidebarCloseButton) {
            var point = sidebarCloseButton.mapToItem(null, 0, 0)
            macWindowMetrics.setSidebarButton(point.x, point.y, sidebarProgress, topBar.parent.height)
        }
    }
    Connections {
        target: appRoot
        function onSidebarProgressChanged() { appRoot.syncNativeNavigation() }
        function onActivePageChanged() { appRoot.syncNativeNavigation() }
        function onHeightChanged() { appRoot.syncNativeNavigation() }
        function onWidthChanged() { appRoot.syncNativeNavigation() }
        function onSidebarPreferredWidthChanged() { appRoot.syncNativeNavigation() }
    }
    // Unified Apple Music-inspired compact navigation.
    GlassPane {
        id: topBar
        objectName: "topBar"
        backdropBlur: false // The full-window compositor below handles blur.
        color: appRoot.materialTint
        z: 50
        visible: appRoot.sidebarProgress < 0.999 && !macWindowMetrics.nativeGlassDock
        opacity: 1.0 - appRoot.sidebarProgress
        enabled: appRoot.sidebarProgress < 0.15
        width: appRoot.activePage === "Launch" ? 412 : 367
        height: 56
        x: (appRoot.width - width) / 2
        y: 14 - appRoot.contentItem.y
        radius: 28
        emphasized: true
        HoverHandler { id: navHover }
        Row {
            anchors.fill: parent
            anchors.margins: 6
            spacing: 5
            Rectangle {
                width: 40; height: 40; radius: 20
                anchors.verticalCenter: parent.verticalCenter
                color: sidebarButtonHover.hovered ? (appRoot.darkMode ? "#5588B8F5" : "#99C8E3FF") : "transparent"
                HoverHandler { id: sidebarButtonHover }
                // Apple Music-style split sidebar icon (sidebar currently closed).
                Canvas {
                    id: expandSidebarIcon
                    anchors.centerIn: parent
                    width: 23; height: 20
                    Connections {
                        target: appRoot
                        function onDarkModeChanged() { expandSidebarIcon.requestPaint() }
                    }
                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.clearRect(0, 0, width, height)
                        ctx.strokeStyle = appRoot.darkMode ? "#EAF4FF" : "#23374B"
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
                    onClicked: appRoot.sidebarMode = true
                }
            }
            Repeater {
                model: ["Launch", "Download", "Settings"]
                delegate: Rectangle {
                    required property string modelData
                    width: 100; height: 44; radius: 22
                    color: appRoot.activePage === modelData
                           ? (appRoot.darkMode ? "#5588B8F5" : "#99C8E3FF") : "transparent"
                    border.width: appRoot.activePage === modelData ? 1 : 0
                    border.color: appRoot.darkMode ? "#55D5EDFF" : "#80FFFFFF"
                    Behavior on color { ColorAnimation { duration: appRoot.motionMs } }
                    Text {
                        anchors.centerIn: parent
                        text: modelData
                        color: appRoot.activePage === modelData ? appRoot.navigationSelectedText : appRoot.navigationText
                        font.pixelSize: 13
                        font.bold: appRoot.activePage === modelData
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        preventStealing: true
                        onClicked: appRoot.activePage = modelData
                    }
                }
            }
            Rectangle {
                visible: appRoot.activePage === "Launch"
                width: 40; height: 40; radius: 20
                anchors.verticalCenter: parent.verticalCenter
                color: appRoot.searchExpanded ? (appRoot.darkMode ? "#5588B8F5" : "#99C8E3FF") : "transparent"
                Text { anchors.centerIn: parent; text: "⌕"; font.pixelSize: 27; color: appRoot.ink }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appRoot.toggleSearch()
                }
            }
        }
    }

    // Account access in compact-navigation mode, aligned to the upper-right.
    GlassPane {
        id: compactAccountButton
        backdropBlur: false // Disable misaligned local scene sampling; keep glass tint and highlight
        z: 72
        visible: appRoot.sidebarProgress < 0.999 && !macWindowMetrics.nativeGlassDock
        // Disappear in place; do not travel into the sidebar profile footer.
        opacity: Math.max(0, 1.0 - appRoot.sidebarProgress * 4)
        enabled: appRoot.sidebarProgress < 0.10
        width: 48; height: 48
        x: appRoot.width - width - 14
        y: 18 - appRoot.contentItem.y
        radius: 24
        selectedGlass: appRoot.accountMenuOpen
        HoverHandler { id: accountButtonHover }
        Rectangle {
            anchors.centerIn: parent
            width: 30; height: 30; radius: 15
            color: appRoot.darkMode ? "#476B8CA7" : "#8BC4E2F3"
            Image { anchors.centerIn: parent; width: 24; height: 24; source: macWindowMetrics.defaultAccountAvatar; fillMode: Image.PreserveAspectFit }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: appRoot.toggleAccountMenu()
        }
    }

    Item {
        id: sidebar
        objectName: "sidebar"
        z: 60
        // Sidebar mode is a full-height, edge-to-edge navigation rail.
        visible: appRoot.sidebarProgress > 0.001
        x: -width * (1.0 - appRoot.sidebarProgress)
        opacity: Math.min(1, appRoot.sidebarProgress * 1.7)
        enabled: appRoot.sidebarProgress > 0.85
        y: 0
        width: Math.max(240, Math.min(appRoot.sidebarMaximumWidth, appRoot.sidebarPreferredWidth))
        onWidthChanged: appRoot.syncNativeNavigation()
        height: appRoot.height
        // The full-height navigation rail never needs a rounded floating frame.
        // Full-window aligned blur is shared with the dock and navigation below.
        clip: true
        Rectangle {
            anchors.fill: parent
            visible: !macWindowMetrics.nativeSidebar
            color: appRoot.materialTint
        }
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
        HoverHandler { id: sidebarHover }
        // Scrollable sidebar content is clipped ABOVE the fixed account footer.
        // Keep all navigation/instance/download elements clear of the account area.
        Flickable {
            id: sidebarScroll
            onContentYChanged: appRoot.syncNativeNavigation()
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
                    id: sidebarCloseButton
                    width: 40; height: 40; radius: width / 2
                    opacity: macWindowMetrics.nativeGlassDock ? 0 : 1
                    enabled: !macWindowMetrics.nativeGlassDock
                    color: sidebarCloseHover.hovered ? (appRoot.darkMode ? "#20FFFFFF" : "#18000000") : "transparent"
                    HoverHandler { id: sidebarCloseHover }
                    // Apple Music-style collapse icon (sidebar currently open).
                    Canvas {
                        id: collapseSidebarIcon
                        anchors.centerIn: parent
                        width: 23; height: 20
                        Connections {
                            target: appRoot
                            function onDarkModeChanged() { collapseSidebarIcon.requestPaint() }
                        }
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0, 0, width, height)
                            ctx.strokeStyle = appRoot.darkMode ? "#EAF4FF" : "#23374B"
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
                        onClicked: appRoot.sidebarMode = false
                    }
                }
            }
            Column {
                visible: appRoot.sidebarProgress > 0.001
                width: parent.width; spacing: 10
                Repeater {
                    model: ["Launch", "Download", "Settings"]
                    delegate: Column {
                        required property string modelData
                        width: parent.width; spacing: 8
                        SidebarControl {
                        width: parent.width; height: 42; radius: height / 2
                        // Same selected-glass treatment as the top navigation.
                        fallbackColor: appRoot.activePage === modelData
                               ? (appRoot.darkMode ? "#20FFFFFF" : "#18000000") : "transparent"
                        nativeSelected: appRoot.activePage === modelData
                        border.width: 0
                        border.color: appRoot.darkMode ? "#55D5EDFF" : "#80FFFFFF"
                        Behavior on color { ColorAnimation { duration: appRoot.motionMs } }
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10
                            // Fixed-width icon column aligns every navigation label.
                            Item {
                                width:24; height:parent.height
                                readonly property string symbolName: modelData === "Launch" ? "play.fill" : modelData === "Download" ? "arrow.down.circle" : "gearshape"
                                Image { anchors.centerIn:parent; width:19; height:19
                                    source: macWindowMetrics.nativeGlassDock ? macWindowMetrics.symbolIcon(parent.symbolName,appRoot.accent.toString()) : ""
                                    fillMode: Image.PreserveAspectFit }
                                Text { anchors.centerIn:parent; visible:!macWindowMetrics.nativeGlassDock
                                    text:modelData==="Launch"?"▶":modelData==="Download"?"↓":"⚙"; color:appRoot.accent }
                            }
                            Text {
                                height: parent.height
                                verticalAlignment: Text.AlignVCenter
                                text: modelData
                                color: appRoot.activePage === modelData ? appRoot.navigationSelectedText : appRoot.navigationText
                                font.pixelSize: 14
                                font.bold: appRoot.activePage === modelData
                            }
                        }
                        MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        preventStealing: true
                        onClicked: function(mouse) {
                            mouse.accepted = true
                            if(modelData === "Download") {
                                if(appRoot.activePage === "Download") appRoot.sidebarDownloadExpanded=!appRoot.sidebarDownloadExpanded
                                else appRoot.sidebarDownloadExpanded=true
                            }
                            appRoot.activePage = modelData
                        }
                    }
                        NativeChevron {
                            anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter
                            visible: modelData === "Download"
                            symbol: appRoot.sidebarDownloadExpanded ? "chevron.down" : "chevron.right"
                        }
                        MouseArea {
                            anchors.right: parent.right; width: 42; height: parent.height
                            visible: modelData === "Download"
                            onClicked: appRoot.sidebarDownloadExpanded=!appRoot.sidebarDownloadExpanded
                        }
                    }
                        Item {
                            width: parent.width; height: visible ? 236 : 0
                            visible: appRoot.sidebarDownloadExpanded && modelData === "Download" && appRoot.activePage === "Download" && !appRoot.downloadSelection && macWindowMetrics.nativeGlassDock
                            Component.onCompleted: if(modelData === "Download") appRoot.sidebarDownloadAnchor = this
                        }
                    }
                }
                Item { width: parent.width; height: 10 }

                Column {
                    visible: !appRoot.sidebarGuideSeen
                    width:parent.width; spacing:8; leftPadding:12; rightPadding:12
                    Text { text:"Sidebar · " + (appRoot.sidebarGuideStep+1) + "/3"; color:appRoot.ink; font.pixelSize:12; font.bold:true }
                    Text { width:parent.width-24; wrapMode:Text.Wrap; color:appRoot.muted; font.pixelSize:12
                        text: ["Launch keeps your instances and groups together. Select a card, then use the launch bar.","Download categories expand below Download. Search and filters stay in the right pane.","Settings controls appearance and shared defaults. Drag the sidebar edge to resize it."][appRoot.sidebarGuideStep] }
                    Row { spacing:16
                        Text { text:"Skip"; color:appRoot.muted; font.pixelSize:12; TapHandler { onTapped:appRoot.sidebarGuideSeen=true } }
                        Text { text:appRoot.sidebarGuideStep===2?"Done":"Next"; color:appRoot.accent; font.pixelSize:12; font.bold:true
                            TapHandler { onTapped: { if(appRoot.sidebarGuideStep===2)appRoot.sidebarGuideSeen=true;else {appRoot.sidebarGuideStep++;appRoot.activePage=["Launch","Download","Settings"][appRoot.sidebarGuideStep]} } } }
                    }
                }
                // Collapsible sidebar instance section. Installed instances follow
                // the exact same Name/Smart ordering used by the canvas.
                SidebarControl {
                    width: parent.width
                    height: 34
                    radius: 12
                    fallbackColor: "transparent"
                    HoverHandler { id: instancesHeaderHover }
                    Row {
                        anchors.fill: parent
                        spacing: 8
                        Text {
                            width: parent.width - 28
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Instances"
                            color: muted
                            font.pixelSize: 13
                            font.letterSpacing: 0
                        }
                        NativeChevron {
                            anchors.verticalCenter: parent.verticalCenter
                            symbol: appRoot.sidebarInstancesExpanded ? "chevron.down" : "chevron.right"
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appRoot.sidebarInstancesExpanded = !appRoot.sidebarInstancesExpanded
                    }
                }

                Column {
                    id: instanceRows
                    visible: appRoot.sidebarInstancesExpanded
                    width: parent.width
                    spacing: 3

                    Repeater {
                        model: appRoot.sidebarDisplayRows()
                        delegate: SidebarControl {
                            required property var modelData
                            required property int index
                            width: sidebar.width - 44
                            height: modelData.type === "header" ? 28 : 35
                            radius: height / 2
                            opacity: appRoot.draggedInstanceKey === modelData.key ? 0.5 : 1
                            nativeSelected: appRoot.selectedCardKeys.indexOf(modelData.key)>=0
                            fallbackColor: appRoot.selectedCardKeys.indexOf(modelData.key)>=0 ? (appRoot.darkMode ? "#20FFFFFF" : "#18000000") : "transparent"
                            RoundedInstanceImage {
                                visible: modelData.type !== "header"
                                x: 12; anchors.verticalCenter: parent.verticalCenter
                                width: 24; height: 24
                                defaultArtwork:!modelData.background
                                source: modelData.type === "header" ? "" : modelData.background || appRoot.defaultCardArt(modelData)
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.left: parent.left
                                anchors.leftMargin: modelData.type === "header" ? 12 : 46
                                width: parent.width - 58; elide: Text.ElideRight
                                text: modelData.label
                                color: modelData.type === "header" ? appRoot.muted : (appRoot.selectedCardKeys.indexOf(modelData.key)>=0 ? appRoot.navigationSelectedText : appRoot.navigationText)
                                font.bold: modelData.type === "header" || appRoot.selectedCardKeys.indexOf(modelData.key)>=0
                                font.pixelSize: modelData.type === "header" ? 12 : 13
                            }
                            NativeChevron {
                                visible: modelData.type === "header"
                                anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter
                                symbol: appRoot.collapsedInstanceGroups.indexOf(modelData.groupId)>=0 ? "chevron.right" : "chevron.down"
                            }
                            Rectangle {
                                x: 6; y: -2; width: parent.width - 12; height: 2
                                color: appRoot.accent
                                visible: appRoot.draggedInstanceKey.length > 0 && modelData.type!=="header" && appRoot.instanceDropSlot === appRoot.sidebarOrderIndex(modelData.key)
                            }
                            Rectangle {
                                x: 6; y: parent.height + 1; width: parent.width - 12; height: 2
                                color: appRoot.accent
                                visible: appRoot.draggedInstanceKey.length > 0 && modelData.type!=="header" && appRoot.instanceDropSlot === appRoot.sidebarOrderIndex(modelData.key)+1
                            }
                            MouseArea {
                                anchors.fill: parent
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                preventStealing: modelData.type!=="header"
                                cursorShape: modelData.type!=="header" ? (pressed?Qt.ClosedHandCursor:Qt.OpenHandCursor) : Qt.PointingHandCursor
                                property real pressY: 0
                                onPressed: function(mouse){pressY=mapToItem(null,mouse.x,mouse.y).y}
                                onPositionChanged: function(mouse) {
                                    if(!pressed || !(pressedButtons & Qt.LeftButton) || modelData.type==="header")return
                                    var point=mapToItem(null,mouse.x,mouse.y)
                                    if(Math.abs(point.y-pressY)>6 || appRoot.draggedInstanceKey.length){appRoot.draggedInstanceKey=modelData.key;appRoot.updateInstanceDrop(point.y)}
                                }
                                onReleased: function(mouse) {
                                    if(mouse.button!==Qt.LeftButton)return
                                    var key=appRoot.draggedInstanceKey,slot=appRoot.instanceDropSlot
                                    appRoot.draggedInstanceKey="";appRoot.instanceDropSlot=-1
                                    if(key.length)appRoot.commitInstanceDrop(key,slot)
                                    else if(modelData.type==="header")appRoot.toggleSidebarGroup(modelData.groupId)
                                    else appRoot.selectCanvasCard(modelData,mouse.modifiers,appRoot.sidebarDisplayRows().filter(function(r){return r.type==="instance"}))
                                }
                                onClicked: function(mouse) {
                                    if(mouse.button!==Qt.RightButton || modelData.type==="header")return
                                    var point=mapToItem(appRoot.contentItem,mouse.x,mouse.y)
                                    appRoot.openCardMenu(modelData,point.x,point.y)
                                }
                                onDoubleClicked: function(mouse){if(mouse.button===Qt.LeftButton && modelData.type!=="header")appRoot.activateCard(modelData)}
                                onCanceled: {appRoot.draggedInstanceKey="";appRoot.instanceDropSlot=-1}
                            }
                        }
                    }

                }

                    // Sidebar download remains available with instances collapsed.
                    SidebarControl {
                        width: sidebar.width - 44
                        height: 38
                        radius: height / 2
                        nativeSelected: appRoot.sidebarQuickDownloadExpanded
                        fallbackColor: appRoot.sidebarQuickDownloadExpanded ? "#20FFFFFF" : "transparent"
                        HoverHandler { id: quickDownloadHover }
                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 10
                            spacing: 10
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "↓"
                                color: appRoot.accent
                                font.pixelSize: 18
                                width: 24
                                horizontalAlignment: Text.AlignHCenter
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 64
                                text: "Quick Download"
                                color: appRoot.sidebarQuickDownloadExpanded ? appRoot.navigationSelectedText : appRoot.navigationText
                                font.bold: appRoot.sidebarQuickDownloadExpanded
                                font.pixelSize: 13
                            }
                            NativeChevron {
                                anchors.verticalCenter: parent.verticalCenter
                                symbol: appRoot.sidebarQuickDownloadExpanded ? "chevron.down" : "chevron.right"
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                appRoot.sidebarQuickDownloadExpanded = !appRoot.sidebarQuickDownloadExpanded
                            }
                        }
                    }

                    SidebarControl {
                        nativeRole: "panel"
                        visible: appRoot.sidebarQuickDownloadExpanded
                        width: sidebar.width - 44
                        height: quickDownloadFields.implicitHeight + 20
                        radius: 17
                        Column {
                            id: quickDownloadFields
                            anchors.fill: parent
                            anchors.margins: 10
                            spacing: 8
                            GlassSelect {
                                id: sidebarQuickVersionSelect
                                sidebarMaterial: true
                                width: parent.width
                                options: appRoot.quickVersionOptions
                                selected: appRoot.sidebarQuickVersion
                                onChosen: function(value) { appRoot.sidebarQuickVersion = value }
                            }
                            GlassSelect {
                                sidebarMaterial: true
                                width: parent.width
                                options: ["Vanilla", "Fabric", "Forge", "NeoForge", "Quilt"]
                                selected: appRoot.sidebarQuickLoader
                                onChosen: function(value) { appRoot.sidebarQuickLoader = value }
                            }
                            Text {
                                width:parent.width;visible:downloadData.quickVersionsBusy || !!downloadData.quickVersionsError
                                text:downloadData.quickVersionsBusy?"Loading versions…":downloadData.quickVersionsError
                                color:appRoot.muted;font.pixelSize:11;wrapMode:Text.WordWrap
                            }
                            SidebarControl {
                                width:parent.width;height:34;radius:15;visible:!!downloadData.quickVersionsError
                                Text {anchors.centerIn:parent;text:"Retry versions";color:appRoot.ink;font.pixelSize:12}
                                MouseArea {anchors.fill:parent;onClicked:downloadData.loadQuickVersions(true)}
                            }
                            SidebarControl {
                                width: parent.width
                                height: 34
                                radius: 15
                                fallbackColor: appRoot.darkMode ? "#7E79C9ED" : "#5D8ED7"
                                Text {
                                    anchors.centerIn: parent
                                    text: "↓  Download"
                                    color: appRoot.ink
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        appRoot.beginDownload({ category: "Versions", name: "Minecraft " + appRoot.sidebarQuickVersion, version: appRoot.sidebarQuickVersion })
                                    }
                                }
                            }
                        }
                    }
            }
            Column {
                visible: appRoot.sidebarProgress < 0.001
                width: parent.width; spacing: 15
                Text { text: "SELECTED INSTANCE"; color: muted; font.pixelSize: 10; font.letterSpacing: 1.2 }
                Text { text: appRoot.selectedLabel(); color: ink; font.pixelSize: 21; font.bold: true; width: parent.width; elide: Text.ElideRight }
                Text { text: appRoot.selectedVersion(); color: muted; font.pixelSize: 12 }
                Text { text: "Drag empty canvas to pan · Double-click card to activate"; color: muted; font.pixelSize: 11; wrapMode: Text.WordWrap; width: parent.width }
            }
            }
        }
    }

    Timer {
        interval: 32; repeat: true
        running: appRoot.draggedInstanceKey.length > 0
        onTriggered: {
            var top = sidebarScroll.mapToItem(null, 0, 0).y
            var y = appRoot.instanceDragSceneY
            if (y < top+28) sidebarScroll.contentY = Math.max(0, sidebarScroll.contentY-10)
            else if (y > top+sidebarScroll.height-28)
                sidebarScroll.contentY = Math.min(Math.max(0, sidebarScroll.contentHeight-sidebarScroll.height), sidebarScroll.contentY+10)
            appRoot.updateInstanceDrop(y)
        }
    }
    // A narrow handle captures only edge drags, leaving sidebar rows usable.
    MouseArea {
        id: sidebarResizeHandle
        z: 100
        visible: appRoot.sidebarProgress >= 0.999
        enabled: visible
        x: sidebar.width - width / 2
        y: 0
        width: 10
        height: appRoot.height
        cursorShape: Qt.SplitHCursor
        preventStealing: true
        property real pressSceneX: 0
        property real pressWidth: 0
        onPressed: function(mouse) {
            pressSceneX = mapToItem(null, mouse.x, mouse.y).x
            pressWidth = sidebar.width
        }
        onPositionChanged: function(mouse) {
            if (!pressed) return
            var sceneX = mapToItem(null, mouse.x, mouse.y).x
            appRoot.sidebarPreferredWidth = Math.max(240, Math.min(appRoot.sidebarMaximumWidth,
                pressWidth + sceneX - pressSceneX))
        }
        onDoubleClicked: appRoot.sidebarPreferredWidth = 282
    }

    // Sidebar account footer, similar to Apple Music's bottom-left profile.
    SidebarControl {
        id: sidebarAccountFooter
        nativeRole: "accountContents"
        z: 67
        visible: appRoot.sidebarProgress > 0.001
        enabled: appRoot.sidebarProgress > 0.85
        // Match the sidebar and its native glass during the entire transition.
        opacity: Math.min(1, appRoot.sidebarProgress * 1.7)
        x: sidebar.x + 22
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: sidebar.width - 44
        height: 68
        radius: appRoot.macOSWindowCornerRadius
        fallbackColor: "transparent"
        border.width: 0
        border.color: appRoot.outline
        HoverHandler { id: footerHover }
        Row {
            anchors.fill: parent
            anchors.margins: 9
            spacing: 11
            SidebarControl {
                nativeRole: "avatar"
                width: 41; height: 41; radius: 20.5
                anchors.verticalCenter: parent.verticalCenter
                fallbackColor: appRoot.darkMode ? "#527FA0C4" : "#9ED5EBFC"
                Image { anchors.centerIn: parent; width: 29; height: 29; source: macWindowMetrics.defaultAccountAvatar; fillMode: Image.PreserveAspectFit }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                width: parent.width - 78
                Text { text: prismBridge.offlineMode ? prismBridge.offlineName : (prismBridge.currentAccountName || "Not signed in"); color: appRoot.ink; font.pixelSize: 14; font.bold: true; elide: Text.ElideRight; width: parent.width }
                Text { text: prismBridge.offlineMode ? "Offline profile" : (prismBridge.currentAccountName?"Microsoft account":"Not signed in"); color: appRoot.muted; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
            }
            NativeChevron { anchors.verticalCenter: parent.verticalCenter }
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: appRoot.toggleAccountMenu()
        }
    }

    // Prototype 09.25.1: one full-window backdrop capture and one full-window
    // rounded alpha mask. The two textures share exactly the window's origin,
    // extent, and device-pixel scaling. No per-panel sourceRect or crop.
    // The scene contains only the canvas/background, never its glass overlays.
    ShaderEffectSource {
        id: dockSceneTexture
        anchors.fill: parent
        sourceItem: appRoot.dockLiveBlur ? sceneLayer : null
        hideSource: false
        live: appRoot.dockLiveBlur
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
        live: appRoot.dockLiveBlur
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
        blur: Math.max(0, Math.min(1, appRoot.dockBlurAmount))
        blurMax: 40
        autoPaddingEnabled: false
        visible: appRoot.dockLiveBlur && !macWindowMetrics.nativeGlassDock
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
        live: appRoot.dockLiveBlur && appRoot.sidebarProgress < 1
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
        blur: Math.max(0, Math.min(1, appRoot.dockBlurAmount))
        blurMax: 40
        autoPaddingEnabled: false
        visible: appRoot.dockLiveBlur && !macWindowMetrics.nativeGlassDock && appRoot.sidebarProgress < 0.999
    }

    // Apple Music-inspired persistent launch bar.
    GlassPane {
        id: bottomDock
        objectName: "bottomDock"
        backdropBlur: false // Never enable old per-panel sourceRect blur.
        // A separate, aligned full-window compositor sits behind this pane.
        // Keep sampled background text as soft shapes, never as a second
        // readable/ghosted text layer. Foreground labels remain crisp above.
        color: appRoot.materialTint
        z: 85
        width: Math.min(560, appRoot.width - appRoot.contentLeft - 48)
        height: sidebarAccountFooter.height
        // Center the launch bar in the available content area, not at
        // the sidebar edge. The account panel remains stationary.
        x: appRoot.contentLeft + (appRoot.width - appRoot.contentLeft - width) / 2
        visible: !macWindowMetrics.nativeGlassDock
        anchors.bottom: parent.bottom
        anchors.bottomMargin: sidebarAccountFooter.anchors.bottomMargin
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
                color: appRoot.instancePickerOpen ? (appRoot.darkMode ? "#5587B9E7" : "#A9DDF4FF") : "#305B7890"
                border.width: appRoot.instancePickerOpen ? 1 : 0
                border.color: appRoot.accent
                RoundedInstanceImage {anchors.fill:parent;source:appRoot.selectedDockArtwork;defaultArtwork:appRoot.selectedDockDefaultArtwork;cornerRadius:14}
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: appRoot.instancePickerOpen = !appRoot.instancePickerOpen
                }
            }
            Column {
                transform: Translate { x: 6 }
                anchors.verticalCenter: parent.verticalCenter; spacing: 4
                width: Math.max(100, bottomDock.width - 210)
                Text { text: appRoot.selectedLabel(); color: ink; font.bold: true; font.pixelSize: 14; width: parent.width; elide: Text.ElideRight }
                Text { text: appRoot.selectedVersion(); color: muted; font.pixelSize: 11; width: parent.width; elide: Text.ElideRight }
            }
            GlassPane {
                anchors.verticalCenter: parent.verticalCenter
                width: 105; height: 42; radius: 21
                backdropBlur:true
                color: Qt.rgba(appRoot.accent.r,appRoot.accent.g,appRoot.accent.b,0.45)
                Text { anchors.centerIn: parent; text: "▶  Launch"; color: appRoot.ink; font.bold: true; font.pixelSize: 13 }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; preventStealing: true; onClicked: appRoot.launchInstanceKey(appRoot.selectedId) }
            }
        }
    }
    Connections {
        target: bottomDock
        function syncDockGeometry() { macWindowMetrics.setDockGeometry(bottomDock.x, bottomDock.y, bottomDock.width, bottomDock.height, bottomDock.radius) }
        function onXChanged() { syncDockGeometry() }
        function onYChanged() { syncDockGeometry() }
        function onWidthChanged() { syncDockGeometry() }
        function onHeightChanged() { syncDockGeometry() }
        function onRadiusChanged() { syncDockGeometry() }
    }

    // Dock-style upward instance picker. Native ListView scrolling works
    // with mouse wheel and macOS trackpad two-finger gestures.
    MouseArea {
        z: 75
        anchors.fill: parent
        visible: appRoot.instancePickerOpen
        onClicked: appRoot.instancePickerOpen = false
    }
    GlassPane {
        id: instancePicker
        backdropBlur: false // Disable misaligned local scene sampling; keep glass tint and highlight
        z: 95
        visible: appRoot.instancePickerOpen && !macWindowMetrics.nativeGlassDock
        x: bottomDock.x
        y: bottomDock.y - height - 12
        width: Math.min(310, appRoot.width - 32)
        height: Math.min(370, instances.count * 58 + 56)
        radius: 24
        emphasized: true
        clip: true
        transformOrigin: Item.Bottom
        scale: appRoot.instancePickerOpen ? 1 : 0.94
        opacity: appRoot.instancePickerOpen ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
        Behavior on opacity { NumberAnimation { duration: 160 } }
        Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 5
            Text {
                text: "INSTANCES  ·  SCROLL TO BROWSE"
                color: appRoot.muted
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
                    color: appRoot.selectedId === key ? (appRoot.darkMode ? "#5088B8F0" : "#88BDE7FF") : "transparent"
                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: installed ? "◆" : "↓"
                            color: appRoot.accent
                            font.pixelSize: 19
                            width: 25
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 60
                            spacing: 3
                            Text { text: label; color: appRoot.ink; font.pixelSize: 13; font.bold: true; elide: Text.ElideRight; width: parent.width }
                            Text { text: version; color: appRoot.muted; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            appRoot.chooseCard(instances.get(index))
                            appRoot.instancePickerOpen = false
                        }
                    }
                }
            }
        }
    }
    onInstancePickerOpenChanged: {
        var rows = []
        var selected = -1
        for (var n = 0; n < instances.count; ++n) {
            var entry = instances.get(n)
            rows.push({label: entry.label, version: entry.version, installed: entry.installed})
            if (entry.key === selectedId) selected = n
        }
        macWindowMetrics.setInstanceMenu(instancePickerOpen, rows, selected)
        if (instancePickerOpen) {
            for (var i = 0; i < instances.count; ++i) {
                if (instances.get(i).key === selectedId) {
                    pickerList.positionViewAtIndex(i, ListView.Contain)
                    break
                }
            }
        }
    }

    component EditorGlassPane: Rectangle {
        objectName: "editorGlassControl"
        clip: true
        radius: 24
        color: macWindowMetrics.nativeGlassDock ? "transparent" : appRoot.glassStrong
    }
    component EditorLogBody: Flickable {
        id: logViewport
        property string logText: ""
        property bool wrapLines: true
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: false
        contentWidth: width
        contentHeight: logTextArea.height
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        TextArea {
            id: logTextArea
            width: logViewport.width; height: Math.max(implicitHeight, logViewport.height)
            readOnly: true; text: logViewport.logText; color: appRoot.ink
            wrapMode: logViewport.wrapLines ? TextEdit.Wrap : TextEdit.NoWrap
            background: null
        }
    }
    component EditorSectionHeader: Item {
        id: sectionHeader
        property string title: ""
        property string actionText: ""
        signal triggered()
        default property alias controls: headerContents.data
        Layout.fillWidth: true
        implicitHeight: 44
        Rectangle {
            objectName: "editorGlassControl"
            property string materialRole: "sectionHeader"
            readonly property string headerTitle: sectionHeader.title
            readonly property string headerActionText: sectionHeader.actionText
            readonly property bool headerLog: sectionHeader.title === "Minecraft Log"
            readonly property bool keepUpdating: appRoot.logKeepUpdating
            readonly property bool wrapLines: appRoot.logWrapLines
            signal nativeKeep(bool value)
            signal nativeWrap(bool value)
            signal nativeCopy()
            signal nativeRefresh()
            onNativeKeep: function(value){appRoot.logKeepUpdating=value}
            onNativeWrap: function(value){appRoot.logWrapLines=value}
            onNativeCopy: macWindowMetrics.copyText(appRoot.editorLogText)
            onNativeRefresh: {if(appRoot.coreEditing)prismBridge.refreshEditor();appRoot.editorLogText=appRoot.editingMetadata.minecraftLog || ""}
            signal nativeAction()
            onNativeAction: sectionHeader.triggered()
            // The native mask rounds only the outside top corners.
            x: -16; y: -16; width: parent.width+32; height: parent.height+16
            radius: 24
            color: macWindowMetrics.nativeGlassDock ? "transparent" : appRoot.glassStrong
            Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 24; color: parent.color }
        }
        RowLayout { id: headerContents; visible: !macWindowMetrics.nativeGlassDock; anchors.fill: parent; anchors.bottomMargin: 10; spacing: 12 }
        Rectangle { visible: !macWindowMetrics.nativeGlassDock; x: -16; anchors.bottom: parent.bottom; width: parent.width+32; height: 1; color: appRoot.outline; opacity: 0.45 }
    }
    component EditorAssetList: EditorGlassPane {
        property string bucket: "mods"
        readonly property var entries: appRoot.editingMetadata[bucket]||[]
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 16; spacing: 12
            EditorSectionHeader {
                title: appRoot.editorTab
                actionText: appRoot.coreEditing && (bucket==="worlds" || bucket==="screenshots")?"Open folder…":"Add…"
                onTriggered: appRoot.openEditorAssets(bucket)
                Text { text: appRoot.editorTab; color: appRoot.ink; font.pixelSize: 20; font.bold: true; Layout.fillWidth: true }
                GroupButton { text: appRoot.coreEditing && (bucket==="worlds" || bucket==="screenshots")?"Open folder…":"Add…"; onClicked: appRoot.openEditorAssets(bucket) }
            }
            ListView {
                id:editorAssetViewport
                objectName: "editorAssetViewport"
                ScrollBar.vertical:ScrollBar {policy:ScrollBar.AsNeeded}
                displayMarginBeginning:height;displayMarginEnd:height
                Layout.fillWidth: true; Layout.fillHeight: true; clip: false; spacing: 8
                model: entries
                delegate: Item {
                    required property var modelData;required property int index
                    objectName:"editorGlassControl";property string materialRole:"assetRow"
                    width:Math.max(0,ListView.view.width-14);height:52
                    readonly property var assetData:modelData
                    readonly property string assetBucket:bucket
                    signal nativeToggle(bool enabled)
                    signal nativeOpen()
                    signal nativeRemove()
                    onNativeToggle:function(enabled){appRoot.toggleEditorAsset(bucket,modelData,enabled)}
                    onNativeOpen:appRoot.openEditorAsset(bucket,modelData)
                    onNativeRemove:appRoot.removeEditorAsset(bucket,modelData)
                    RowLayout {anchors.fill:parent;spacing:14;visible:!macWindowMetrics.nativeGlassDock
                        Switch {visible:bucket!=="worlds" && bucket!=="screenshots";checked:modelData.enabled!==false;onToggled:appRoot.toggleEditorAsset(bucket,modelData,checked)}
                        Image {source:modelData.icon || "";Layout.preferredWidth:32;Layout.preferredHeight:32}
                        Text {text:modelData.name+"  "+(modelData.version || "");color:appRoot.ink;Layout.fillWidth:true;elide:Text.ElideRight}
                        GroupButton {text:"Open";onClicked:appRoot.openEditorAsset(bucket,modelData)}
                        GroupButton {text:"Remove";onClicked:appRoot.removeEditorAsset(bucket,modelData)}
                    }
                }
            }
            Text { visible: !entries.length; text: "No entries found"; color: appRoot.muted }
        }
    }
    Item {
        id: instanceEditorPage
        visible: appRoot.activePage==="Instance"
        z: 12
        x: appRoot.contentLeft+28; y: appRoot.pageTop()
        width: appRoot.width-x-28; height: appRoot.panelHeight(y)
        ColumnLayout {
            anchors.fill: parent; spacing: 14
            RowLayout {
                Layout.preferredHeight:36+6*appRoot.sidebarProgress
                GroupButton { text: "‹ Back"; onClicked: appRoot.activePage="Launch" }
                Text { text: appRoot.editingRecord?appRoot.editingRecord.label:"Instance"; color: appRoot.ink; font.pixelSize: 24; font.bold: true; Layout.fillWidth: true }
                GroupButton {visible:appRoot.coreEditing;text:"Refresh";onClicked:prismBridge.refreshEditor()}
            }
            Text {visible:!!appRoot.editingMetadata.error;Layout.fillWidth:true;text:appRoot.editingMetadata.error || "";color:appRoot.accent;wrapMode:Text.Wrap}
            Text {visible:!appRoot.coreEditing;Layout.fillWidth:true;text:"This card is not linked to installed game files. Open an installed instance to manage its files.";color:appRoot.muted;wrapMode:Text.Wrap}
            Text {visible:appRoot.coreEditing;Layout.fillWidth:true;text:prismBridge.status;color:appRoot.muted;font.pixelSize:11;wrapMode:Text.Wrap}
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
                EditorGlassPane {
                    Layout.preferredWidth: 184; Layout.fillHeight: true
                    Flickable {
                        anchors.fill: parent; anchors.margins: 8; clip: false
                        contentHeight: editorNavigation.implicitHeight; contentWidth: width
                        Column {
                            id: editorNavigation; width: parent.width; spacing: 4
                            Repeater {
                                model: appRoot.editorTabs
                                delegate: Rectangle {
                                    required property string modelData
                                    width: editorNavigation.width; height: 36; radius: 12
                                    color: appRoot.editorTab===modelData?"#28FFFFFF":"transparent"
                                    Text { anchors.fill: parent; anchors.leftMargin: 10; verticalAlignment: Text.AlignVCenter; text: modelData; color: appRoot.editorTab===modelData?appRoot.navigationSelectedText:appRoot.navigationText; font.bold: appRoot.editorTab===modelData; font.pixelSize: 12; elide: Text.ElideRight }
                                    MouseArea { anchors.fill: parent; onClicked: appRoot.editorTab=modelData }
                                }
                            }
                        }
                    }
                }
                StackLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    currentIndex: appRoot.editorTabs.indexOf(appRoot.editorTab)
                    EditorGlassPane {
                        ColumnLayout { anchors.fill:parent; anchors.margins:16; spacing:12
                            EditorSectionHeader { title: "Overview"; Text { text: "Overview"; color: appRoot.ink; font.pixelSize:20; font.bold:true } }
                            Text { text:appRoot.editingRecord?appRoot.editingRecord.label:""; color:appRoot.ink; font.pixelSize:18; Layout.fillWidth:true; elide:Text.ElideRight }
                            Text { text:appRoot.editingRecord?appRoot.editingRecord.version:""; color:appRoot.muted; Layout.fillWidth:true; wrapMode:Text.Wrap }
                            Rectangle { Layout.fillWidth:true; height:1; color:appRoot.outline; opacity:0.3 }
                            Text { text:appRoot.editingRecord?(appRoot.editingRecord.hours+" hours played · "+appRoot.editingRecord.launches+" launches"):"";color:appRoot.muted }
                            Text { text:"Memory · " + appRoot.effectiveMemoryMiB(appRoot.editingInstanceKey) + " MiB · " + (appRoot.editingMetadata.useDefaultMemory!==false?"Global default":"Instance override");color:appRoot.muted;Layout.fillWidth:true;wrapMode:Text.Wrap }
                            Text { text:((appRoot.editingMetadata.mods||[]).length)+" mods · "+((appRoot.editingMetadata.resourcePacks||[]).length)+" resource packs · "+((appRoot.editingMetadata.shaderPacks||[]).length)+" shader packs";color:appRoot.muted;Layout.fillWidth:true;wrapMode:Text.Wrap }
                            Flow { Layout.fillWidth:true; spacing:12
                                GroupButton { text:"Edit details";onClicked:appRoot.editorTab="Version" }
                                GroupButton { text:"Runtime settings";onClicked:appRoot.editorTab="Settings" }
                            }
                            Item { Layout.fillHeight:true }
                        }
                    }
                    EditorGlassPane {
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            EditorSectionHeader {
                                title: "Minecraft Log"
                                Text { text: "Minecraft Log"; color: appRoot.ink; font.pixelSize: 20; font.bold: true }
                            }
                            Item { id: logControlsNativeArea; visible:false; Layout.preferredHeight:0 }
                            EditorLogBody { logText: appRoot.editorLogText||"No Minecraft log available"; wrapLines: appRoot.logWrapLines }
                        }
                    }
                    EditorGlassPane {
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16; spacing: 12
                            EditorSectionHeader { title: "Version"; Text { text: "Version"; color: appRoot.ink; font.pixelSize:20; font.bold:true } }
                            Text { text: "Instance name"; color: appRoot.ink }
                            GroupField { id: editInstanceName;onTextEdited:appRoot.editorDirtyFields.name=true; Layout.fillWidth: true; text: appRoot.editingRecord?appRoot.editingRecord.label:"" }
                            Text { text: "Minecraft / loader"; color: appRoot.ink }
                            GroupField { id: editInstanceVersion;readOnly:appRoot.coreEditing; Layout.fillWidth: true; text: appRoot.editingRecord?appRoot.editingRecord.version:"" }
                            ListView {
                                id:versionListViewport
                                visible:appRoot.coreEditing;Layout.fillWidth:true;Layout.fillHeight:true;clip:true
                                model:appRoot.editingMetadata.components || []
                                delegate:Text {required property var modelData;width:ListView.view.width;height:28;text:modelData.name+" · "+modelData.version;color:appRoot.ink;elide:Text.ElideRight}
                            }
                            Flow { Layout.fillWidth:true; spacing:12
                                GroupButton { text: "Save"; onClicked: appRoot.saveInstanceDetails(editInstanceName.text,editInstanceVersion.text) }
                                GroupButton { text: "Background…"; onClicked: {appRoot.pendingBackgroundKey=appRoot.editingInstanceKey;cardBackgroundDialog.open()} }
                            }
                            Text { text: appRoot.editingRecord?appRoot.editingRecord.hours+" h · "+appRoot.editingRecord.launches+" launches":""; color: appRoot.muted }
                            Item { Layout.fillHeight: true }
                        }
                    }
                    EditorAssetList { bucket: "mods" }
                    EditorAssetList { bucket: "resourcePacks" }
                    EditorAssetList { bucket: "shaderPacks" }
                    EditorGlassPane {
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            EditorSectionHeader { title: "Notes"; Text { text: "Notes"; color: appRoot.ink; font.pixelSize:20; font.bold:true } }
                            ScrollView { Layout.fillWidth: true; Layout.fillHeight: true; TextArea { id: instanceNotes;onTextChanged:if(activeFocus)appRoot.editorDirtyFields.notes=true; text: appRoot.editingMetadata.notes||""; color: appRoot.ink; wrapMode: TextEdit.Wrap } }
                            GroupButton { text: "Save notes"; onClicked: appRoot.setInstanceMetadata(appRoot.editingInstanceKey,{notes:instanceNotes.text}) }
                        }
                    }
                    EditorAssetList { bucket: "worlds" }
                    EditorGlassPane {
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            EditorSectionHeader { title: "Servers"; Text { text: "Servers"; color: appRoot.ink; font.pixelSize:20; font.bold:true } }
                            RowLayout {
                                GroupField { id: serverAddress; placeholderText: "Server address"; Layout.fillWidth: true }
                                GroupButton { text: "Add"; onClicked:{appRoot.addEditorServer(serverAddress.text);serverAddress.text=""} }
                            }
                            ListView {
                                id:serverListViewport
                                Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                                model: appRoot.editingMetadata.servers||[]
                                delegate: RowLayout {
                                    required property var modelData; required property int index
                                    width: ListView.view.width
                                    Text { text: modelData.name; color: appRoot.ink; Layout.fillWidth: true }
                                    GroupButton { text: "Remove"; onClicked:appRoot.removeEditorServer(modelData,index) }
                                }
                            }
                        }
                    }
                    EditorAssetList { bucket: "screenshots" }
                    EditorGlassPane {
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16; spacing: 12
                            EditorSectionHeader { title: "Settings"; Text { text: "Settings"; color: appRoot.ink; font.pixelSize:20; font.bold:true } }
                            Text { text: "Java path"; color: appRoot.ink }
                            GroupField { id: instanceJava;onTextEdited:appRoot.editorDirtyFields.javaPath=true; Layout.fillWidth: true; text: appRoot.editingMetadata.javaPath||"" }
                            Text { text: "Java arguments"; color: appRoot.ink }
                            GroupField { id: instanceJavaArgs;onTextEdited:appRoot.editorDirtyFields.javaArgs=true; Layout.fillWidth: true; text: appRoot.editingMetadata.javaArgs||"" }
                            Item {
                                id: instanceMemoryNativeArea
                                Layout.fillWidth: true; Layout.preferredHeight: 176
                                ColumnLayout {
                                    anchors.fill: parent; visible: !macWindowMetrics.nativeGlassDock; spacing: 10
                                    RowLayout {
                                        Text { text: "Maximum memory (MiB)"; color: appRoot.ink; Layout.fillWidth: true }
                                        Switch { text: "Default"; checked: appRoot.editingMetadata.useDefaultMemory !== false
                                            onToggled: appRoot.setInstanceMetadata(appRoot.editingInstanceKey, {useDefaultMemory: checked}) }
                                    }
                                    MemoryAllocation { Layout.fillWidth: true
                                        enabled: appRoot.editingMetadata.useDefaultMemory === false
                                        allocation: appRoot.effectiveMemoryMiB(appRoot.editingInstanceKey)
                                        onCommitted: function(value) { appRoot.setInstanceMetadata(appRoot.editingInstanceKey, {memoryMiB: value}) } }
                                    Text { text: appRoot.memoryStatus; color: appRoot.muted; Layout.fillWidth: true; wrapMode: Text.Wrap }
                                }
                            }
                            GroupButton { text: "Save"; onClicked: appRoot.setInstanceMetadata(appRoot.editingInstanceKey,{javaPath:instanceJava.text,javaArgs:instanceJavaArgs.text}) }
                            Item { Layout.fillHeight: true }
                        }
                    }
                    EditorGlassPane {
                        ColumnLayout {
                            anchors.fill: parent; anchors.margins: 16
                            EditorSectionHeader {
                                title: "Other Logs"
                                Text { text: "Other Logs"; color: appRoot.ink; font.pixelSize: 20; font.bold: true }
                            }
                            EditorLogBody { logText: appRoot.editingMetadata.otherLogs||"No other logs available"; wrapLines: true }
                        }
                    }
                }
            }
        }
    }
    // Dedicated content pages replace the canvas, never float above it.
    Item {
        id: pageContent
        z: 12
        opacity: macWindowMetrics.nativeGlassDock ? 0 : 1
        enabled: !macWindowMetrics.nativeGlassDock
        visible: appRoot.activePage === "Settings"
        x: appRoot.contentLeft + 28
        y: appRoot.pageTop()
        width: appRoot.width - appRoot.contentLeft - 56
        height: appRoot.height-appRoot.contentItem.y-y
        Flickable {
            x:0; y:-pageContent.y-appRoot.contentItem.y
            width:parent.width; height:appRoot.height
            contentWidth: width; contentHeight: settingsContent.y+settingsContent.implicitHeight+108
            clip: false; boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { }
        Column {
            id: settingsContent
            y: pageContent.y+appRoot.contentItem.y
            width: parent.width
            spacing: 24
            GroupButton { text:"Launcher core…";onClicked:prismConnection.open() }
            Text {
                text: appRoot.activePage === "Settings" ? "Appearance & layout" : "Minecraft versions and loaders"
                font.pixelSize: 15; color: muted
            }
            Column {
                visible: appRoot.activePage === "Settings"
                width: Math.min(660, pageContent.width)
                spacing: 18
                GlassPane {
                    width:parent.width; height:158; radius:appRoot.settingsCardRadius
                    ColumnLayout { anchors.fill:parent; anchors.margins:16; spacing:12
                        Text { text:"Accent color"; color:appRoot.ink; font.bold:true }
                        RowLayout { Layout.fillWidth:true
                            GlassSelect { Layout.fillWidth:true; options:["Auto","System","Blue","Purple","Pink","Red","Orange","Yellow","Green","Custom"];selected:appRoot.themeChoice;onChosen:function(value){appRoot.themeChoice=value} }
                            GroupButton { text:"Choose…";onClicked:themeColorDialog.open() }
                        }
                        GroupButton { text:"Show sidebar guide";onClicked:appRoot.showSidebarGuide() }
                    }
                }
                GlassPane {
                    width: parent.width; height: 176; radius: appRoot.settingsCardRadius
                    ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 10
                        Text { text: "General · Maximum memory (MiB)"; color: appRoot.ink }
                        MemoryAllocation { Layout.fillWidth: true; allocation: appRoot.globalMemoryMiB
                            onCommitted: function(value) { appRoot.globalMemoryMiB = value } }
                        Text { text: appRoot.memoryStatus; color: appRoot.muted }
                    }
                }
                GlassPane {
                    width: parent.width; height: 74; radius: appRoot.settingsCardRadius
                    Row {
                        anchors.fill: parent; anchors.margins: 20; spacing: 12
                        Text { text: "Grouped layout"; color: ink; font.pixelSize: 15; width: parent.width - 100; anchors.verticalCenter: parent.verticalCenter }
                        Switch { checked: appRoot.groupedLayoutEnabled; anchors.verticalCenter: parent.verticalCenter; onToggled: appRoot.groupedLayoutEnabled = checked }
                    }
                }
                GlassPane {
                    width: parent.width; height: 74; radius: appRoot.settingsCardRadius
                    Row {
                        anchors.fill: parent; anchors.margins: 16; spacing: 12
                        Text { text: "Group by"; color: ink; font.pixelSize: 15; width: parent.width-240; anchors.verticalCenter: parent.verticalCenter }
                        GlassSelect {
                            width: 220
                            options: ["Off", "Smart", "Minecraft version", "Mod loader", "Installed status", "Custom"]
                            selected: appRoot.groupingMethod
                            onChosen: function(value) { appRoot.groupingMethod=value }
                        }
                    }
                }
                GlassPane {
                    width: parent.width; height: 74; radius: appRoot.settingsCardRadius
                    Row {
                        anchors.fill: parent; anchors.margins: 20; spacing: 12
                        Text { text: "Quick cards"; color: ink; font.pixelSize: 15; width: parent.width - 100; anchors.verticalCenter: parent.verticalCenter }
                        Switch { checked: appRoot.quickCards; anchors.verticalCenter: parent.verticalCenter; onToggled: appRoot.quickCards = checked }
                    }
                }
                GlassPane {
                    width: parent.width
                    height: appRoot.backgroundMode === "Custom color" ? 240+appRoot.gradientStops.length*44 : appRoot.backgroundMode === "Custom" ? 240 : 108
                    radius: appRoot.settingsCardRadius
                    Column {
                        anchors.fill: parent; anchors.margins: 16; spacing: 12
                        Text { text: "Background"; color: ink; font.pixelSize: 14 }
                        GlassSelect {
                            width: parent.width; options: ["White", "Gray", "Black", "Custom", "Custom color"]
                            selected: appRoot.backgroundMode
                            onChosen: function(value) { appRoot.backgroundMode = value }
                        }
                        Column {
                            visible:appRoot.backgroundMode==="Custom color";width:parent.width;spacing:8
                            GlassSelect {width:parent.width;options:["Solid","Gradient"];selected:appRoot.customGradient?"Gradient":"Solid";onChosen:function(value){appRoot.customGradient=value==="Gradient"}}
                            ConnectionField {visible:!appRoot.customGradient;width:parent.width;text:appRoot.customColorStart.toString();onTextEdited:if(/^#[0-9a-fA-F]{6}$/.test(text))appRoot.customColorStart=text}
                            Repeater {model:appRoot.customGradient?appRoot.gradientStops:[];delegate:Row {
                                required property var modelData;required property int index;width:parent.width;spacing:8
                                ConnectionField {width:120;text:modelData.color;onEditingFinished:if(/^#[0-9a-fA-F]{6}$/.test(text))appRoot.updateGradientStop(index,text)}
                                Slider {width:150;from:0;to:1;value:modelData.position;onMoved:appRoot.updateGradientStop(index,"",value)}
                                ConnectionButton {text:"−";enabled:appRoot.gradientStops.length>2;onClicked:appRoot.removeGradientStop(index)}
                            }}
                            ConnectionButton {visible:appRoot.customGradient;text:"Add stop";onClicked:appRoot.addGradientStop()}
                            Text {visible:appRoot.customGradient;text:"Angle · "+Math.round(appRoot.customGradientAngle)+"°";color:appRoot.ink}
                            Slider {visible:appRoot.customGradient;width:parent.width;from:0;to:360;value:appRoot.customGradientAngle;onMoved:appRoot.customGradientAngle=appRoot.snapGradientAngle(value)}
                        }
                        Button {
                            visible: appRoot.backgroundMode === "Custom"
                            text: "Choose image…"; onClicked: backgroundFileDialog.open()
                        }
                        Text {
                            visible: appRoot.backgroundMode === "Custom"
                            width: parent.width; elide: Text.ElideMiddle
                            text: appRoot.backgroundImage.length ? decodeURIComponent(appRoot.backgroundImage.split("/").pop()) : "No image selected"
                            color: muted; font.pixelSize: 11
                        }
                        GlassSelect {
                            visible: appRoot.backgroundMode === "Custom"
                            width: parent.width; options: ["Fill", "Fit", "Stretch", "Center", "Tile"]
                            selected: appRoot.backgroundPlacement
                            onChosen: function(value) { appRoot.backgroundPlacement = value }
                        }
                    }
                }
                GlassPane {
                    width: parent.width; height: 106; radius: appRoot.settingsCardRadius
                    Column {
                        anchors.fill: parent; anchors.margins: 16; spacing: 8
                        Row {
                            width: parent.width
                            Text { text: "Glass appearance"; color: ink; font.pixelSize: 14; width: parent.width - 50 }
                            Text { text: Math.round(appRoot.glassOpacity * 100) + "%"; color: muted; width: 50; horizontalAlignment: Text.AlignRight }
                        }
                        Slider {
                            width: parent.width; from: 0; to: 1; stepSize: 0.01
                            value: appRoot.glassOpacity
                            onMoved: appRoot.glassOpacity = value
                        }
                        Row {
                            width: parent.width
                            Text { text: "Clear"; color: muted; font.pixelSize: 11; width: parent.width / 2 }
                            Text { text: "Frosted"; color: muted; font.pixelSize: 11; width: parent.width / 2; horizontalAlignment: Text.AlignRight }
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
        visible: appRoot.activePage === "Download" && !appRoot.downloadSelection
        x: appRoot.contentLeft + 28
        y: appRoot.pageTop()
        width: Math.max(0, appRoot.width - appRoot.contentLeft - 56)
        height: Math.max(0, appRoot.height - y)
        ColumnLayout {
            anchors.fill: parent
            spacing: 12
            RowLayout {
                opacity: macWindowMetrics.nativeGlassDock ? 0 : 1
                enabled: !macWindowMetrics.nativeGlassDock
                Layout.fillWidth: true
                GlassSelect {
                    Layout.preferredWidth: 148
                    Layout.preferredHeight: 42
                    controlHeight: 42
                    cornerRadius: appRoot.downloadControlRadius
                    options: ["Modrinth"]
                    selected: appRoot.downloadProvider
                    onChosen: function(value) { appRoot.downloadProvider = value }
                }
                TextField {
                    Layout.fillWidth: true
                    Layout.preferredWidth: Math.min(360, downloadPage.width * 0.52)
                    Layout.preferredHeight: 42
                    placeholderText: "Search " + appRoot.downloadCategory.toLowerCase() + "…"
                    text: appRoot.downloadSearch
                    onTextEdited: appRoot.downloadSearch = text
                    onAccepted: { appRoot.submitDownloadSearch(text); focus=false }
                    Keys.onEscapePressed: focus=false
                    color: appRoot.ink
                    background: GlassPane {
                    objectName: "editorGlassControl"
                    property string materialRole:"button"
                    color: macWindowMetrics.nativeGlassDock ? "transparent" : prominent ? Qt.rgba(appRoot.accent.r,appRoot.accent.g,appRoot.accent.b,0.24) : (appRoot.darkMode ? "#0CFFFFFF" : "#35FFFFFF")
                    border.width: macWindowMetrics.nativeGlassDock ? 0 : 1
                    edgeGlow: !macWindowMetrics.nativeGlassDock; radius: appRoot.downloadControlRadius; subtle: true }
                }
            }
            RowLayout {
                visible: !appRoot.sidebarDownloadTools
                opacity: macWindowMetrics.nativeGlassDock ? 0 : 1
                enabled: !macWindowMetrics.nativeGlassDock
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
                            model: appRoot.downloadCategories
                            delegate: GlassPane {
                    objectName: "editorGlassControl"
                    property string materialRole:"button"
                    color: macWindowMetrics.nativeGlassDock ? "transparent" : prominent ? Qt.rgba(appRoot.accent.r,appRoot.accent.g,appRoot.accent.b,0.24) : (appRoot.darkMode ? "#0CFFFFFF" : "#35FFFFFF")
                    border.width: macWindowMetrics.nativeGlassDock ? 0 : 1
                    edgeGlow: !macWindowMetrics.nativeGlassDock
                                required property string modelData
                                width: categoryLabel.implicitWidth + 28; height: 40; radius: 20
                                selectedGlass: appRoot.downloadCategory === modelData
                                subtle: true
                                Text { id: categoryLabel; anchors.centerIn: parent; text: modelData; color: appRoot.ink; font.pixelSize: 13 }
                                TapHandler { onTapped: appRoot.openDownloadCategory(modelData) }
                            }
                        }
                    }
                }
                GlassPane {
                    objectName: "editorGlassControl"
                    property string materialRole:"button"
                    color: macWindowMetrics.nativeGlassDock ? "transparent" : prominent ? Qt.rgba(appRoot.accent.r,appRoot.accent.g,appRoot.accent.b,0.24) : (appRoot.darkMode ? "#0CFFFFFF" : "#35FFFFFF")
                    border.width: macWindowMetrics.nativeGlassDock ? 0 : 1
                    edgeGlow: !macWindowMetrics.nativeGlassDock
                    Layout.preferredWidth: 72; Layout.preferredHeight: 42; radius: appRoot.downloadControlRadius
                    Text { anchors.centerIn: parent; text: "Refresh"; color: appRoot.ink; font.pixelSize: 12 }
                    TapHandler { enabled: !downloadData.catalogueBusy; onTapped: appRoot.refreshCatalogue() }
                }
                GlassSelect {
                    visible: appRoot.downloadCategory === "Mods"
                    Layout.preferredWidth: 132
                    Layout.preferredHeight: 42
                    controlHeight: 42
                    cornerRadius: appRoot.downloadControlRadius
                    options: ["All loaders", "Fabric", "Forge", "NeoForge", "Quilt"]
                    selected: appRoot.downloadLoaderFilter
                    onChosen: function(value) { appRoot.downloadLoaderFilter = value }
                }
                GlassSelect {
                    Layout.preferredWidth: 142
                    Layout.preferredHeight: 42
                    controlHeight: 42
                    cornerRadius: appRoot.downloadControlRadius
                    options: ["Featured", "Newest", "Updated"]
                    selected: appRoot.downloadSort
                    onChosen: function(value) { appRoot.downloadSort = value }
                }
            }
            RowLayout {
                visible: downloadData.catalogueError.length > 0
                Layout.fillWidth: true
                Text { text: downloadData.catalogueError; Layout.fillWidth: true; wrapMode: Text.WordWrap; color: appRoot.muted }
                GlassPane {
                    objectName: "editorGlassControl"
                    property string materialRole:"button"
                    color: macWindowMetrics.nativeGlassDock ? "transparent" : prominent ? Qt.rgba(appRoot.accent.r,appRoot.accent.g,appRoot.accent.b,0.24) : (appRoot.darkMode ? "#0CFFFFFF" : "#35FFFFFF")
                    border.width: macWindowMetrics.nativeGlassDock ? 0 : 1
                    edgeGlow: !macWindowMetrics.nativeGlassDock
                    visible: true
                    Layout.preferredWidth: 72; Layout.preferredHeight: 34; radius: 17
                    Text { anchors.centerIn: parent; text: "Retry"; color: appRoot.ink }
                    TapHandler { onTapped: downloadData.retryCatalogue() }
                }
            }
            ListView {
                id: downloadList
                header: Item {
                    width:downloadList.width; height:38
                    Text { anchors.left:parent.left; anchors.right:parent.right; anchors.verticalCenter:parent.verticalCenter
                        text:"Target · " + appRoot.selectedLabel() + " · " + appRoot.selectedVersion();color:appRoot.muted;font.pixelSize:12;elide:Text.ElideRight }
                }
                objectName: "downloadList"
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: false; spacing: 12
                displayMarginBeginning: appRoot.height
                displayMarginEnd: appRoot.height
                model: downloadRows
                boundsBehavior: Flickable.StopAtBounds
                // Append preserves scroll position. New queries reset below via the query key.
                property string displayedQuery: ""
                function maybeFetchMore() {
                    if (appRoot.activePage !== "Download" || appRoot.downloadSelection || downloadData.catalogueBusy || downloadData.catalogueError || !downloadData.hasMore) return
                    if (contentY + height >= contentHeight - 2 * 142)
                        downloadData.loadCatalogue(appRoot.downloadCategory, appRoot.downloadSearch, appRoot.downloadSort, true, appRoot.downloadLoaderFilter, appRoot.downloadProvider)
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
                        color: appRoot.muted; font.pixelSize: 12
                    }
                }
                ScrollBar.vertical: ScrollBar { }
                delegate: GlassPane {
                    objectName: "editorGlassControl"
                    property string materialRole:"downloadRow"
                    readonly property var nativeRow: modelData
                    readonly property url nativeIconSource: modelData.category === "Versions" ? Qt.resolvedUrl("assets/version-grass.png") : modelData.icon || ""
                    color: macWindowMetrics.nativeGlassDock ? "transparent" : prominent ? Qt.rgba(appRoot.accent.r,appRoot.accent.g,appRoot.accent.b,0.24) : (appRoot.darkMode ? "#0CFFFFFF" : "#35FFFFFF")
                    border.width: 0
                    edgeGlow: false
                    id: downloadCard
                    required property var entry
                    readonly property var modelData: entry
                    width: downloadList.width
                    readonly property bool narrow: width < 650
                    height: narrow ? 142 : 118
                    radius: Math.max(appRoot.macOSWindowCornerRadius, downloadCard.padding + 12)
                    selectedGlass: modelData.category === "Versions" && modelData.version === appRoot.sidebarQuickVersion
                    readonly property real padding: 16
                    Rectangle {
                        visible: !macWindowMetrics.nativeGlassDock
                        x: iconTile.x + iconTile.width + 16; y: downloadCard.height + (downloadList.spacing - height) / 2
                        width: Math.max(0,downloadCard.width-x-downloadCard.padding); height: 1
                        color: appRoot.darkMode ? "#30FFFFFF" : "#25000000"
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: appRoot.openProject(downloadCard.modelData)
                    }
                    Rectangle {
                        id: iconTile
                        visible: !macWindowMetrics.nativeGlassDock
                        objectName: "downloadIconTile"
                        x: downloadCard.padding; y: downloadCard.padding
                        width: downloadCard.height - 2 * downloadCard.padding; height: width
                        radius: Math.max(0, downloadCard.radius - downloadCard.padding)
                        color: appRoot.darkMode ? "#355B7890" : "#A3DEECF8"
                        Image {
                            id: projectIcon
                            anchors.fill: parent
                            source: downloadCard.modelData.category === "Versions" ? Qt.resolvedUrl("assets/version-grass.png") : downloadCard.modelData.icon || ""
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
                        Text { visible: projectIcon.status !== Image.Ready; anchors.centerIn: parent; text: downloadCard.modelData.badge; textFormat: Text.PlainText; color: appRoot.accent; font.pixelSize: 12; font.bold: true }
                        Rectangle {
                            anchors.fill: parent; radius: parent.radius
                            color: "transparent"; border.width: 1; border.color: appRoot.outline
                        }
                    }
                    Column {
                        visible: !macWindowMetrics.nativeGlassDock
                        x: iconTile.x + iconTile.width + 16
                        y: downloadCard.narrow ? downloadCard.padding : (downloadCard.height - height) / 2
                        width: Math.max(0, downloadCard.width - x - downloadCard.padding - (downloadCard.narrow ? 0 : 128))
                        spacing: 8
                        Text { width: parent.width; text: downloadCard.modelData.name; textFormat: Text.PlainText; elide: Text.ElideRight; color: appRoot.ink; font.pixelSize: 18; font.bold: true }
                        Text { width: parent.width; text: downloadCard.modelData.detail; textFormat: Text.PlainText; color: appRoot.darkMode ? "#DEFFFFFF" : "#D51C1C1E"; font.pixelSize: 13; wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight }
                    }
                    Row {
                        anchors.right: parent.right; anchors.rightMargin: 16
                        y: downloadCard.narrow ? downloadCard.height - 36 - downloadCard.padding : (downloadCard.height - 36) / 2
                        spacing: 10
                        GlassPane {
                    objectName: macWindowMetrics.nativeGlassDock ? "" : "editorGlassControl"
                    property string materialRole:"button"
                    color: macWindowMetrics.nativeGlassDock ? "transparent" : prominent ? Qt.rgba(appRoot.accent.r,appRoot.accent.g,appRoot.accent.b,0.24) : (appRoot.darkMode ? "#0CFFFFFF" : "#35FFFFFF")
                    border.width: macWindowMetrics.nativeGlassDock ? 0 : 1
                    edgeGlow: !macWindowMetrics.nativeGlassDock
                            width: 112; height: 36; radius: 18; selectedGlass: true; prominent: true
                            Text { visible: !macWindowMetrics.nativeGlassDock; anchors.centerIn: parent; text: "↓  Download"; color: appRoot.ink; font.pixelSize: 13; font.bold: true }
                            TapHandler {
                                onTapped: {
                                    if (downloadCard.modelData.category === "Versions") appRoot.sidebarQuickVersion = downloadCard.modelData.version
                                    appRoot.beginDownload(downloadCard.modelData)
                                }
                            }
                        }
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: downloadList.count === 0 && !downloadData.catalogueError
                    text: downloadData.catalogueBusy ? "Loading catalogue…" : "No matches · Try another search"
                    color: appRoot.muted
                }
            }

        }
    }


    Item {
        id: releasePage
        z: 12
        visible: appRoot.activePage === "Download" && appRoot.downloadSelection !== null
        x: appRoot.contentLeft + 28; y: appRoot.pageTop()
        width: Math.max(0, appRoot.width - appRoot.contentLeft - 56)
        height: appRoot.panelHeight(y)
        readonly property bool game: appRoot.downloadSelection !== null && appRoot.downloadSelection.category === "Versions"
        ColumnLayout {
            anchors.fill: parent; spacing: 12
            RowLayout {
                Layout.preferredHeight:36+6*appRoot.sidebarProgress
                Layout.fillWidth: true
                GlassPane {
                    objectName: "editorGlassControl"
                    property string materialRole:"button"
                    color: macWindowMetrics.nativeGlassDock ? "transparent" : prominent ? Qt.rgba(appRoot.accent.r,appRoot.accent.g,appRoot.accent.b,0.24) : (appRoot.darkMode ? "#0CFFFFFF" : "#35FFFFFF")
                    border.width: macWindowMetrics.nativeGlassDock ? 0 : 1
                    edgeGlow: !macWindowMetrics.nativeGlassDock
                    Layout.preferredWidth: 88; Layout.preferredHeight: 36; radius: 18
                    Text { anchors.centerIn: parent; text: "‹  Back"; color: appRoot.ink }
                    TapHandler { onTapped: { if(!appRoot.projectIntroduction && appRoot.downloadSelection.category!=="Versions")appRoot.projectIntroduction=true; else appRoot.downloadSelection=null } }
                }
                Text {
                    Layout.fillWidth: true; elide: Text.ElideRight
                    text: appRoot.downloadSelection ? appRoot.downloadSelection.name : ""
                    textFormat: Text.PlainText
                    color: appRoot.ink; font.pixelSize: 24; font.bold: true
                }
            }

            Flickable {
                visible: appRoot.projectIntroduction
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true; contentWidth: width; contentHeight: introductionColumn.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { }
                Column {
                    id: introductionColumn; width: parent.width; spacing: 20
                    Text { width: parent.width; text: appRoot.downloadSelection ? (appRoot.downloadSelection.detail || "") : ""; textFormat: Text.PlainText; wrapMode: Text.WordWrap; color: appRoot.ink; font.pixelSize: 17 }
                    Text { width: parent.width; text: appRoot.projectBodyBusy ? "Loading introduction…" : appRoot.projectBodyError || appRoot.projectBody; textFormat: appRoot.projectBodyBusy || appRoot.projectBodyError ? Text.PlainText : Text.MarkdownText; wrapMode: Text.WordWrap; color: appRoot.ink; linkColor: appRoot.accent; onLinkActivated: function(link) { Qt.openUrlExternally(link) } }
                    GroupButton { visible: !!appRoot.projectBodyError; text: "Retry"; onClicked: appRoot.openProject(appRoot.downloadSelection) }
                }
            }
            GroupButton {
                visible: appRoot.projectIntroduction
                text: "Choose a version…"
                onClicked: appRoot.projectIntroduction=false
            }
            Text {
                visible: !appRoot.projectIntroduction
                Layout.fillWidth: true; wrapMode: Text.WordWrap
                text: releasePage.game ? "Choose a loader, then choose its version" : "Target: " + appRoot.selectedLabel() + " · " + appRoot.selectedVersion()
                color: appRoot.muted; font.pixelSize: 14
            }
            RowLayout {
                visible: !appRoot.projectIntroduction && releasePage.game; Layout.fillWidth: true
                Text { text: "Mod loader"; color: appRoot.ink; Layout.fillWidth: true }
                GlassSelect {
                    nativeDownloadMaterial: true
                    Layout.preferredWidth: 170
                    options: ["Vanilla", "Fabric", "Forge", "NeoForge", "Quilt"]
                    selected: appRoot.selectedLoader
                    onChosen: function(value) { appRoot.selectedLoader = value; appRoot.selectedRelease = "" }
                }
            }
            Text {
                visible: !appRoot.projectIntroduction && releasePage.game && appRoot.selectedLoader === "Vanilla"
                text: "Vanilla uses the selected Minecraft version; no loader version is needed."
                Layout.fillWidth: true; wrapMode: Text.WordWrap; color: appRoot.muted
            }
            RowLayout {
                visible: !appRoot.projectIntroduction && (downloadData.releaseBusy || downloadData.releaseError.length > 0 || (appRoot.releaseChoices.length === 0 && !downloadData.vanillaValid))
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true; wrapMode: Text.WordWrap; color: appRoot.muted
                    text: downloadData.releaseBusy ? "Loading versions…" : downloadData.releaseError || "No versions listed for this selection. Try another loader or project."
                }
                GlassPane {
                    objectName: "editorGlassControl"
                    property string materialRole:"button"
                    color: macWindowMetrics.nativeGlassDock ? "transparent" : prominent ? Qt.rgba(appRoot.accent.r,appRoot.accent.g,appRoot.accent.b,0.24) : (appRoot.darkMode ? "#0CFFFFFF" : "#35FFFFFF")
                    border.width: macWindowMetrics.nativeGlassDock ? 0 : 1
                    edgeGlow: !macWindowMetrics.nativeGlassDock
                    visible: !downloadData.releaseBusy
                    Layout.preferredWidth: 72; Layout.preferredHeight: 34; radius: 17
                    Text { anchors.centerIn: parent; text: "Retry"; color: appRoot.ink }
                    TapHandler { onTapped: downloadData.retryReleases() }
                }
            }
            ListView {
                id: releaseList
                displayMarginBeginning: appRoot.height
                displayMarginEnd: appRoot.height
                Layout.fillWidth: true; Layout.fillHeight: true
                visible: !appRoot.projectIntroduction && (!releasePage.game || appRoot.selectedLoader !== "Vanilla")
                clip: false; spacing: 8
                model: appRoot.releaseRows()
                ScrollBar.vertical: ScrollBar { }
                delegate: GlassPane {
                    id:releaseCard
                    required property var modelData
                    objectName: !modelData.heading && macWindowMetrics.nativeGlassDock ? "editorGlassControl" : ""
                    materialRole:"releaseRow"
                    readonly property bool nativeReleaseRow:true
                    readonly property var nativeRow:({name:modelData.label || "",detail:modelData.detail || "",badge:""})
                    readonly property bool downloadEnabled:appRoot.canInstallRelease(modelData)
                    color:modelData.heading || macWindowMetrics.nativeGlassDock?"transparent":appRoot.glassSoft
                    border.width:0;edgeGlow:false
                    width:releaseList.width;height:modelData.heading?36:82;radius:20
                    selectedGlass:!modelData.heading && appRoot.selectedRelease===modelData.id
                    MouseArea {
                        anchors.fill:parent
                        onClicked:if(modelData.heading)appRoot.toggleReleaseGroup(modelData.group);else appRoot.selectedRelease=modelData.id
                    }
                    NativeChevron {visible:!!modelData.heading;anchors.verticalCenter:parent.verticalCenter;symbol:appRoot.collapsedReleaseGroups[modelData.group]?"chevron.right":"chevron.down"}
                    Text {
                        visible:!!modelData.heading;anchors.fill:parent;leftPadding:24;verticalAlignment:Text.AlignVCenter
                        text:modelData.group + " · Newest first";color:appRoot.muted;font.pixelSize:12
                    }
                    Column {
                        visible:!modelData.heading && !macWindowMetrics.nativeGlassDock
                        x:16;y:16;width:Math.max(0,parent.width-160);spacing:6
                        Text {width:parent.width;text:modelData.label || "";elide:Text.ElideRight;color:appRoot.ink}
                        Text {width:parent.width;text:modelData.detail || "";elide:Text.ElideRight;color:appRoot.muted;font.pixelSize:11}
                    }
                    GlassPane {
                        objectName:"releaseDownloadButton"
                        visible:!modelData.heading
                        x:parent.width-128;y:(parent.height-height)/2;width:112;height:36;radius:18
                        color:macWindowMetrics.nativeGlassDock?"transparent":appRoot.glassSoft
                        edgeGlow:false;border.width:0
                        opacity:releaseCard.downloadEnabled?1:0.45
                        Text {visible:!macWindowMetrics.nativeGlassDock;anchors.centerIn:parent;text:"↓  Download";color:appRoot.ink;font.pixelSize:13;font.bold:true}
                        MouseArea {
                            anchors.fill:parent;preventStealing:true
                            cursorShape:releaseCard.downloadEnabled?Qt.PointingHandCursor:Qt.ArrowCursor
                            onClicked:appRoot.downloadRelease(releaseCard.modelData)
                        }
                    }
                }
            }
            Item { visible: !appRoot.projectIntroduction && releasePage.game && appRoot.selectedLoader === "Vanilla"; Layout.fillHeight: true }
            Text {
                visible: !appRoot.projectIntroduction
                Layout.fillWidth: true
                text: prismBridge.status
                color: appRoot.muted; font.pixelSize: 12; wrapMode: Text.WordWrap
                Accessible.role: Accessible.StaticText
            }
            GlassPane {
                    objectName: "editorGlassControl"
                    property string materialRole:"button"
                    color: macWindowMetrics.nativeGlassDock ? "transparent" : prominent ? Qt.rgba(appRoot.accent.r,appRoot.accent.g,appRoot.accent.b,0.24) : (appRoot.darkMode ? "#0CFFFFFF" : "#35FFFFFF")
                    border.width: macWindowMetrics.nativeGlassDock ? 0 : 1
                    edgeGlow: !macWindowMetrics.nativeGlassDock
                visible: !appRoot.projectIntroduction && releasePage.game && appRoot.selectedLoader==="Vanilla"
                Layout.fillWidth: true; Layout.preferredHeight: 48; radius: 22
                readonly property bool ready: !prismBridge.installing && !downloadData.releaseBusy && !downloadData.releaseError && ((releasePage.game && appRoot.selectedLoader === "Vanilla" && downloadData.vanillaValid) || (appRoot.selectedReleaseDetails !== null && appRoot.selectedReleaseDetails.eligible && (releasePage.game || appRoot.downloadSelection.category === "Modpacks" || appRoot.selectedId.indexOf("prism:") === 0)))
                opacity: ready ? 1 : 0.5
                Text { anchors.centerIn: parent; text: prismBridge.installing ? "Installing · " + Math.round(prismBridge.installProgress * 100) + "%" : "Install"; color: appRoot.ink; font.bold: true }
                TapHandler {
                    enabled: parent.ready
                    onTapped: appRoot.installSelectedRelease()
                }
            }
        }
    }

    // Search and zoom share a single expandable liquid-glass control.
    MouseArea {
        anchors.fill: parent
        z: 74
        visible: appRoot.searchExpanded && !macWindowMetrics.nativeGlassDock
        onClicked: appRoot.searchExpanded = false
    }
    GlassPane {
        id:resizeDoneButton
        objectName:"editorGlassControl";materialRole:"button"
        visible:appRoot.cardSizeEditing && appRoot.activePage==="Launch"
        readonly property bool besideSearch:searchDock.visible && searchDock.opacity>0.5
        x:(besideSearch?searchDock.x:compactAccountButton.x)-width-12
        y:besideSearch?searchDock.y+(searchDock.height-height)/2:compactAccountButton.y+(compactAccountButton.height-height)/2
        width:166;height:36;radius:18;z:76
        color:macWindowMetrics.nativeGlassDock?"transparent":appRoot.glassSoft
        border.width:0;edgeGlow:false
        Text {anchors.centerIn:parent;text:"Done resizing";color:appRoot.ink;font.pixelSize:13}
        MouseArea {anchors.fill:parent;onClicked:appRoot.toggleCardSizeEditing()}
    }
    GlassPane {
        id: searchDock
        color: macWindowMetrics.nativeGlassDock ? "transparent" : appRoot.materialTint
        edgeGlow: !macWindowMetrics.nativeGlassDock
        border.width: macWindowMetrics.nativeGlassDock ? 0 : 1
        backdropBlur: false // Disable misaligned local scene sampling; keep glass tint and highlight
        // In compact mode, the search toggle lives in topBar. Only show this
        // separate dock when the search tools are expanded. In sidebar mode
        // it doubles as the standalone top-right search button.
        visible: appRoot.activePage === "Launch" && (appRoot.searchExpanded || appRoot.sidebarProgress > 0.55)
        z: 75
        // A two-phase crossfade: disappear first, swap geometry while hidden,
        // then appear at the other destination. Never draw a second search
        // icon over the compact navigation bar as the sidebar starts moving.
        readonly property bool sidebarDestination: appRoot.sidebarProgress >= 0.5
        opacity: sidebarDestination
                 ? Math.max(0, Math.min(1, (appRoot.sidebarProgress - 0.60) / 0.25))
                 : Math.max(0, Math.min(1, (0.40 - appRoot.sidebarProgress) / 0.25))
        enabled: opacity > 0.95
        x: sidebarDestination ? appRoot.width - width - 22 : (appRoot.width - width) / 2
        y: sidebarDestination ? sidebarScroll.y + (42 - height) / 2
                              : topBar.y + topBar.height + 10
        width: appRoot.searchExpanded ? Math.min(568, Math.max(180,appRoot.width - appRoot.contentLeft - 70 - (appRoot.cardSizeEditing?178:0))) : 40
        height: 40
        radius: appRoot.pillRadius
        emphasized: true
        HoverHandler { id: searchHover }
        Behavior on width { enabled: !sidebarResizeHandle.pressed && (appRoot.sidebarProgress <= 0 || appRoot.sidebarProgress >= 1); NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            visible: appRoot.searchExpanded
            opacity: macWindowMetrics.nativeGlassDock ? 0 : 1
            enabled: !macWindowMetrics.nativeGlassDock
            TextField {
                id: searchInput
                width: Math.max(95, parent.width - 340)
                height: 34
                placeholderText: "Search versions..."
                text: appRoot.searchText
                onTextChanged: appRoot.searchText = text
                color: appRoot.ink
                font.pixelSize: 12
                background: Rectangle { color: "#16FFFFFF"; radius: 17 }
                Keys.onEscapePressed: { appRoot.searchExpanded = false; focus = false }
            }
            GlassSelect {
                id: sortCombo
                width: 140
                height: 34
                compact: true
                options: ["Off", "Smart", "Minecraft version", "Mod loader", "Installed status", "Custom"]
                selected: appRoot.groupingMethod
                onChosen: function(value) { appRoot.groupingMethod = value }
            }
            Slider {
                id: zoomSlider
                width: 92
                height: 34
                from: 0.55; to: 1.65; stepSize: 0
                value: appRoot.zoom
                onMoved: appRoot.zoom = value
                background: Rectangle {
                    x: zoomSlider.leftPadding
                    y: zoomSlider.topPadding + zoomSlider.availableHeight / 2 - height / 2
                    width: zoomSlider.availableWidth
                    height: 7; radius: 3.5
                    color: appRoot.darkMode ? "#446F88A2" : "#A6D6E8F5"
                    border.width: 1
                    border.color: appRoot.darkMode ? "#50D8F1FF" : "#99FFFFFF"
                    Rectangle {
                        width: zoomSlider.visualPosition * parent.width
                        height: parent.height; radius: parent.radius
                        color: appRoot.darkMode ? "#A3BFE7FF" : "#8B75BDE9"
                    }
                }
                handle: Rectangle {
                    x: zoomSlider.leftPadding + zoomSlider.visualPosition * (zoomSlider.availableWidth - width)
                    y: zoomSlider.topPadding + zoomSlider.availableHeight / 2 - height / 2
                    width: 19; height: 19; radius: 9.5
                    color: appRoot.darkMode ? "#F1F8FF" : "#FFFFFF"
                    border.width: 1
                    border.color: appRoot.darkMode ? "#99D8F2FF" : "#A0A6C5D9"
                    Rectangle { anchors.centerIn: parent; width: 7; height: 7; radius: 3.5; color: appRoot.accent }
                }
            }
            Text {
                width: 35
                anchors.verticalCenter: parent.verticalCenter
                text: Math.round(appRoot.zoom * 100) + "%"
                color: appRoot.ink; font.pixelSize: 11
                horizontalAlignment: Text.AlignHCenter
            }
            Rectangle {
                width: 40; height: 32; radius: 16
                color: resetHover.hovered ? (appRoot.darkMode ? "#5588B8F5" : "#99C8E3FF") : "#18FFFFFF"
                Text { anchors.centerIn: parent; text: "Reset"; color: appRoot.ink; font.pixelSize: 11 }
                HoverHandler { id: resetHover }
                MouseArea { anchors.fill: parent; onClicked: { appRoot.resetCanvas(); appRoot.searchText = "" } }
            }
        }
        Rectangle {
            id: searchToggle
            visible: !appRoot.searchExpanded
            opacity: macWindowMetrics.nativeGlassDock ? 0 : 1
            enabled: !macWindowMetrics.nativeGlassDock
            anchors.right: parent.right
            anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            width: 40; height: 40; radius: 20
            color: "#20FFFFFF"
            Text { anchors.centerIn: parent; text: appRoot.searchExpanded ? "×" : "⌕"; font.pixelSize: 26; color: appRoot.ink }
            TapHandler {
                onTapped: {
                    appRoot.toggleSearch()
                }
            }
        }
    }
    Timer {
        interval: 32
        repeat: true
        running: appRoot.accountMenuOpen && macWindowMetrics.nativeGlassDock
        onTriggered: macWindowMetrics.setAccountGlass(accountMenu, true)
    }
    component GroupButton: Button {
        id: groupButton
        implicitHeight: 36
        implicitWidth: Math.max(88,groupButtonLabel.implicitWidth+32)
        contentItem: Text {
            id: groupButtonLabel
            text: groupButton.text; color: appRoot.ink
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            objectName: "accountGlassControl"
            property bool glassHovered: groupButton.hovered
            radius: 14
            color: (macWindowMetrics.nativeAccountGlass || (macWindowMetrics.nativeGlassDock && appRoot.activePage==="Instance")) ? "transparent" : appRoot.glass
        }
    }
    component GroupField: TextField {
        implicitHeight: 34
        color: appRoot.ink
        background: Rectangle {
            objectName: "accountGlassControl"
            radius: 12
            color: (macWindowMetrics.nativeAccountGlass || (macWindowMetrics.nativeGlassDock && appRoot.activePage==="Instance")) ? "transparent" : appRoot.glass
        }
    }
    Timer {
        interval: 32; repeat: true
        running: macWindowMetrics.nativeGlassDock && groupManagerPopup.visible
        onTriggered: macWindowMetrics.setAccountGlass(groupManagerPopup.contentItem,true)
    }
    GlassPane {
        id: groupManagerButton
        visible: appRoot.activePage === "Launch" && appRoot.groupedLayoutEnabled && appRoot.groupingMethod === "Custom"
        z: 73
        x: appRoot.width-width-28
        y: (80-appRoot.contentItem.y)*(1-appRoot.sidebarProgress)+(appRoot.sidebarPageTop+4)*appRoot.sidebarProgress
        width: 108; height: 34; radius: 17
        Text { anchors.centerIn: parent; text: "Groups"; color: appRoot.ink; font.pixelSize: 13 }
        TapHandler { onTapped: { appRoot.accountMenuOpen=false; groupManagerPopup.pendingKey="";groupManagerPopup.pendingKeys=[]; groupManagerPopup.open() } }
    }
    Popup {
        id: groupManagerPopup
        parent: appRoot.contentItem
        popupType: macWindowMetrics.nativeGlassDock ? Popup.Window : Popup.Item
        property string pendingKey: ""
        property var pendingKeys: []
        x: appRoot.width-width-14; y: 120-appRoot.contentItem.y
        width: 350; height: Math.min(440,appRoot.height-150)
        padding: 16; dim: false; focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onClosed: macWindowMetrics.setAccountGlass(contentItem,false)
        background: GlassPane {
            radius: 24; emphasized: true
            color: macWindowMetrics.nativeAccountGlass ? "transparent" : appRoot.glassStrong
            border.width: macWindowMetrics.nativeAccountGlass ? 0 : 1
            edgeGlow: !macWindowMetrics.nativeAccountGlass
        }
        contentItem: ColumnLayout {
            spacing: 12
            Text { text: "Groups"; color: appRoot.ink; font.pixelSize: 20; font.bold: true }
            RowLayout {
                Layout.fillWidth: true
                GroupField {
                    id: newGroupName
                    Layout.fillWidth: true; placeholderText: "New group name"; color: appRoot.ink
                    onAccepted: {
                        appRoot.createInstanceGroup(text,groupManagerPopup.pendingKeys.length ? groupManagerPopup.pendingKeys : groupManagerPopup.pendingKey)
                        text=""; groupManagerPopup.pendingKey="";groupManagerPopup.pendingKeys=[]
                    }
                }
                GroupButton {
                    text: "Add"
                    onClicked: {
                        appRoot.createInstanceGroup(newGroupName.text,groupManagerPopup.pendingKeys.length ? groupManagerPopup.pendingKeys : groupManagerPopup.pendingKey)
                        newGroupName.text=""; groupManagerPopup.pendingKey="";groupManagerPopup.pendingKeys=[]
                    }
                }
            }
            Text { text: "Right-click a card to move it into a group."; color: appRoot.muted; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap }
            ScrollView {
                Layout.fillWidth: true; Layout.fillHeight: true
                clip: true
                Column {
                    width: groupManagerPopup.availableWidth; spacing: 8
                    Repeater {
                        model: appRoot.instanceGroups
                        delegate: RowLayout {
                            required property var modelData
                            width: parent.width
                            GroupField {
                                Layout.fillWidth: true; text: modelData.name; color: appRoot.ink
                                onEditingFinished: appRoot.renameInstanceGroup(modelData.id,text)
                            }
                            GroupButton { text: "Delete"; onClicked: appRoot.deleteInstanceGroup(modelData.id) }
                        }
                    }
                }
            }
            Text { text: "Deleting a group keeps its instances."; color: appRoot.muted; font.pixelSize: 11 }
        }
    }
    Menu {
        id: canvasAppearanceMenu
        MenuItem {text:appRoot.cardSizeEditing?"Finish editing card sizes":"Edit card sizes…";checkable:true;checked:appRoot.cardSizeEditing;onTriggered:appRoot.toggleCardSizeEditing()}
        MenuItem { text:"Free mode";checkable:true;checked:appRoot.freeCanvasActive;enabled:!appRoot.hasInstanceGroups;onTriggered:appRoot.enableFreeCanvas() }
        Menu {
            id:freeVisibilityMenu;title:"Visible cards"
            Instantiator {
                model:appRoot.sortedCards
                delegate:MenuItem { required property var modelData;text:modelData.label;checkable:true;checked:appRoot.freeHidden.indexOf(modelData.key)<0;onTriggered:appRoot.setFreeVisible(modelData.key,appRoot.freeHidden.indexOf(modelData.key)>=0) }
                onObjectAdded:function(i,o){freeVisibilityMenu.insertItem(i,o)}
                onObjectRemoved:function(i,o){freeVisibilityMenu.removeItem(o)}
            }
        }
        MenuItem { text:"Prevent overlap";enabled:appRoot.freeCanvasActive;checkable:true;checked:appRoot.freeAvoidOverlap;onTriggered:appRoot.freeAvoidOverlap=!appRoot.freeAvoidOverlap }
        Menu {
            id:freeGapMenu;title:"Minimum gap";enabled:appRoot.freeCanvasActive && appRoot.freeAvoidOverlap
            Instantiator {
                model:[8,16,24,32,48,64]
                delegate:MenuItem {required property int modelData;text:modelData+" pt";checkable:true;checked:appRoot.freeMinimumGap===modelData;onTriggered:appRoot.freeMinimumGap=modelData}
                onObjectAdded:function(i,o){freeGapMenu.insertItem(i,o)}
                onObjectRemoved:function(i,o){freeGapMenu.removeItem(o)}
            }
        }
        MenuItem { text:"Recenter canvas";onTriggered:appRoot.resetCanvas() }
        MenuItem { text:"Launcher core…";onTriggered:prismConnection.open() }
        MenuSeparator { }
        parent: appRoot.contentItem
        popupType: Qt.platform.os === "osx" ? Popup.Native : Popup.Window
        MenuItem { text: "Use groups"; checkable: true; checked: appRoot.groupedLayoutEnabled; onTriggered: appRoot.groupedLayoutEnabled=!appRoot.groupedLayoutEnabled }
        MenuItem { text:"Quick Download…";onTriggered:canvasQuickDownload.open() }
        MenuItem { text: "Show Quick Download cards"; checkable: true; checked: appRoot.quickCards; onTriggered: appRoot.quickCards=!appRoot.quickCards }
        MenuSeparator { }
        Menu {
            id: canvasGroupingMenu; title: "Group by"
            Instantiator {
                model: ["Off", "Smart", "Minecraft version", "Mod loader", "Installed status", "Custom"]
                delegate: MenuItem {
                    required property string modelData
                    text: modelData; checkable: true; checked: appRoot.groupingMethod===modelData
                    onTriggered: appRoot.groupingMethod=modelData
                }
                onObjectAdded: function(index,object) { canvasGroupingMenu.insertItem(index,object) }
                onObjectRemoved: function(index,object) { canvasGroupingMenu.removeItem(object) }
            }
        }
        Menu {
            id: canvasBackgroundMenu; title: "Background"
            Instantiator {
                model: ["White", "Gray", "Black", "Custom"]
                delegate: MenuItem {
                    required property string modelData
                    text: modelData === "Custom" ? "Current custom wallpaper" : modelData
                    enabled: modelData!=="Custom" || appRoot.backgroundImage.length>0
                    checkable: true; checked: appRoot.backgroundMode===modelData
                    onTriggered: appRoot.backgroundMode=modelData
                }
                onObjectAdded: function(index,object) { canvasBackgroundMenu.insertItem(index,object) }
                onObjectRemoved: function(index,object) { canvasBackgroundMenu.removeItem(object) }
            }
        }
    }
    Menu {
        id: cardContextMenu
        parent: appRoot.contentItem
        popupType: Qt.platform.os === "osx" ? Popup.Native : Popup.Window
        property var contextKeys: []
        readonly property bool multiple: contextKeys.length>1
        Menu {
            title:"Layer";enabled:appRoot.freeCanvasActive
            MenuItem {text:"Bring to front";onTriggered:appRoot.reorderFreeLayers(cardContextMenu.contextKeys,"front")}
            MenuItem {text:"Move forward";onTriggered:appRoot.reorderFreeLayers(cardContextMenu.contextKeys,"up")}
            MenuItem {text:"Move backward";onTriggered:appRoot.reorderFreeLayers(cardContextMenu.contextKeys,"down")}
            MenuItem {text:"Send to back";onTriggered:appRoot.reorderFreeLayers(cardContextMenu.contextKeys,"back")}
        }
        Menu {
            title:"Card size"
            MenuItem {text:"Custom…";onTriggered:{appRoot.cardSizeEditing=true;appRoot.statusMessage="Drag card edges · 180×126 to 640×480 · Esc to finish"}}
            MenuItem { text:"Small";onTriggered:cardContextMenu.contextKeys.forEach(function(k){appRoot.setCardSize(k,180,126)}) }
            MenuItem { text:"Medium";onTriggered:cardContextMenu.contextKeys.forEach(function(k){appRoot.setCardSize(k,240,168)}) }
            MenuItem { text:"Large";onTriggered:cardContextMenu.contextKeys.forEach(function(k){appRoot.setCardSize(k,340,240)}) }
        }
        MenuItem { text:"Show on canvas";checkable:true;checked:cardContextMenu.contextKeys.every(function(k){return appRoot.freeHidden.indexOf(k)<0});onTriggered:{var show=cardContextMenu.contextKeys.some(function(k){return appRoot.freeHidden.indexOf(k)>=0});cardContextMenu.contextKeys.forEach(function(k){appRoot.setFreeVisible(k,show)})} }
        MenuItem {
            text: "Launch"; visible: !cardContextMenu.multiple
            enabled: cardContextMenu.contextKeys.length===1 && !!appRoot.instanceRecord(cardContextMenu.contextKeys[0]) && appRoot.instanceRecord(cardContextMenu.contextKeys[0]).installed
            onTriggered: appRoot.activateCard(appRoot.instanceRecord(cardContextMenu.contextKeys[0]))
        }
        MenuItem { text:"Play offline…";visible:!cardContextMenu.multiple;enabled:cardContextMenu.contextKeys.length===1 && !!appRoot.instanceRecord(cardContextMenu.contextKeys[0]) && appRoot.instanceRecord(cardContextMenu.contextKeys[0]).installed;onTriggered:{prismBridge.promptOffline(cardContextMenu.contextKeys[0])} }
        MenuItem { text: "Kill"; visible: !cardContextMenu.multiple; enabled: false }
        MenuItem { text: "Edit…"; visible: !cardContextMenu.multiple; onTriggered: appRoot.editInstance(cardContextMenu.contextKeys[0]) }
        MenuSeparator { visible: !cardContextMenu.multiple }
        MenuItem { text: cardContextMenu.multiple ? "Duplicate selected instances" : "Duplicate"; onTriggered: appRoot.duplicateCards(cardContextMenu.contextKeys) }
        MenuItem {
            text: "Change background…"; visible: !cardContextMenu.multiple
            onTriggered: { appRoot.pendingBackgroundKey=cardContextMenu.contextKeys[0];cardBackgroundDialog.open() }
        }
        MenuItem { text: "Folder"; visible: !cardContextMenu.multiple; onTriggered: appRoot.showInstanceFolder(cardContextMenu.contextKeys[0]) }
        Menu {
            title: "Export"; visible: !cardContextMenu.multiple
            MenuItem { text: "Instance configuration…"; onTriggered: appRoot.requestExport(cardContextMenu.contextKeys,false) }
            MenuItem { text: "Mod list…"; onTriggered: appRoot.requestExport(cardContextMenu.contextKeys,true) }
        }
        MenuItem { text: "Copy"; onTriggered: macWindowMetrics.copyText(appRoot.exportSelection(cardContextMenu.contextKeys)) }
        MenuItem {
            text: "Delete…"; visible: !cardContextMenu.multiple
            onTriggered: { appRoot.deletionKeys=cardContextMenu.contextKeys.slice();if(!macWindowMetrics.requestDeleteConfirmation())deleteInstanceDialog.open() }
        }
        MenuItem { text: "Create Shortcut…"; visible: !cardContextMenu.multiple; onTriggered: shortcutDialog.open() }
        MenuSeparator { }
        MenuItem {
            text: "New group with selection…"
            onTriggered: { groupManagerPopup.pendingKeys=cardContextMenu.contextKeys.slice();groupManagerPopup.open() }
        }
        Menu {
            id: moveToGroupMenu
            title: "Change Group"; enabled: appRoot.instanceGroups.length>0
            Instantiator {
                model: appRoot.instanceGroups
                delegate: MenuItem {
                    required property var modelData
                    text: modelData.name
                    onTriggered: appRoot.moveCardsToGroup(cardContextMenu.contextKeys,modelData.id)
                }
                onObjectAdded: function(index,object){moveToGroupMenu.insertItem(index,object)}
                onObjectRemoved: function(index,object){moveToGroupMenu.removeItem(object)}
            }
        }
        MenuItem { text: "Remove from group"; onTriggered: appRoot.moveCardsToGroup(cardContextMenu.contextKeys,"") }
    }
    Shortcut {
        sequences: ["Ctrl+A","Meta+A"]
        enabled: appRoot.activePage==="Launch" && !appRoot.searchExpanded && !appRoot.accountMenuOpen && !groupManagerPopup.visible
        onActivated: appRoot.selectedCardKeys=appRoot.sortedCards.map(function(c){return c.key})
    }
    Shortcut {
        sequence: "Escape"
        enabled: appRoot.activePage==="Launch" && appRoot.selectedCardKeys.length>1 && !cardContextMenu.visible && !groupManagerPopup.visible
        onActivated: appRoot.selectedCardKeys=[]
    }
    Popup {
        id:accountsPopup;parent:appRoot.contentItem;anchors.centerIn:parent
        width:Math.min(480,appRoot.width-40);height:Math.min(appRoot.height-40,accountManagerColumn.implicitHeight+40)
        modal:true;focus:true;padding:20;popupType:Popup.Window
        onOpened:macWindowMetrics.setAccountGlass(contentItem,true)
        onClosed:macWindowMetrics.setAccountGlass(contentItem,false)
        Timer {interval:32;repeat:true;running:accountsPopup.visible && macWindowMetrics.nativeGlassDock;onTriggered:macWindowMetrics.setAccountGlass(accountsPopup.contentItem,true)}
        background:GlassPane {radius:24;color:macWindowMetrics.nativeAccountGlass?"transparent":appRoot.glassStrong}
        contentItem:Column {
            id:accountManagerColumn;spacing:12
            Text {text:"Accounts";color:appRoot.ink;font.pixelSize:20}
            ListView {width:parent.width;height:Math.min(220,count*48);clip:true;spacing:8;model:prismBridge.savedAccounts || [];delegate:RowLayout {
                required property var modelData;width:accountManagerColumn.width;spacing:10
                ConnectionButton {Layout.fillWidth:true;text:(modelData.selected?"✓  ":"")+modelData.name;onClicked:prismBridge.selectSavedAccount(modelData.id)}
                ConnectionButton {text:"Remove";onClicked:{removeAccountPopup.accountId=modelData.id;removeAccountPopup.open()}}
            }}
            Text {visible:!(prismBridge.savedAccounts || []).length;text:"No saved Microsoft accounts";color:appRoot.muted}
            RowLayout {width:parent.width;spacing:12
                ConnectionButton {text:"Add account";onClicked:{accountsPopup.close();loginPopup.open();prismBridge.signIn()}}
                Item {Layout.fillWidth:true}
                ConnectionButton {text:"Close";onClicked:accountsPopup.close()}
            }
        }
    }
    Popup {
        id:removeAccountPopup;property string accountId:"";parent:appRoot.contentItem;anchors.centerIn:parent
        width:340;height:150;modal:true;focus:true;padding:20;popupType:Popup.Window
        onOpened:macWindowMetrics.setAccountGlass(contentItem,true)
        onClosed:macWindowMetrics.setAccountGlass(contentItem,false)
        Timer {interval:32;repeat:true;running:removeAccountPopup.visible && macWindowMetrics.nativeGlassDock;onTriggered:macWindowMetrics.setAccountGlass(removeAccountPopup.contentItem,true)}
        background:GlassPane {radius:24;color:macWindowMetrics.nativeAccountGlass?"transparent":appRoot.glassStrong}
        contentItem:Column {spacing:16
            Text {text:"Remove this saved account?";color:appRoot.ink}
            Row {spacing:12
                ConnectionButton {text:"Cancel";onClicked:removeAccountPopup.close()}
                ConnectionButton {text:"Remove";onClicked:{prismBridge.removeSavedAccount(removeAccountPopup.accountId);removeAccountPopup.close()}}
            }
        }
    }
    Popup {
        id:loginPopup
        Connections {
            target: prismBridge
            function onChanged() {
                if(prismBridge.signingIn && !loginPopup.visible)loginPopup.open()
                else if(!prismBridge.signingIn && prismBridge.status==="Microsoft account added")loginPopup.close()
            }
        }
        parent:appRoot.contentItem;anchors.centerIn:parent
        width:Math.min(500,appRoot.width-40);height:Math.min(appRoot.height-40,loginColumn.implicitHeight+40)
        modal:true;focus:true;padding:20;popupType:Popup.Window;closePolicy:Popup.NoAutoClose
        onOpened:macWindowMetrics.setAccountGlass(contentItem,true)
        onClosed:macWindowMetrics.setAccountGlass(contentItem,false)
        Timer {interval:32;repeat:true;running:loginPopup.visible && macWindowMetrics.nativeGlassDock;onTriggered:macWindowMetrics.setAccountGlass(loginPopup.contentItem,true)}
        background:GlassPane {radius:24;color:macWindowMetrics.nativeAccountGlass?"transparent":appRoot.glassStrong}
        contentItem:Column {id:loginColumn;spacing:16
            Text {text:"Sign in with Microsoft";color:appRoot.ink;font.pixelSize:20}
            Text {width:parent.width;text:prismBridge.status;wrapMode:Text.Wrap;color:appRoot.muted}
            Image {source:prismBridge.loginQr || "";visible:!!source;width:180;height:180;fillMode:Image.PreserveAspectFit;smooth:false}
            ConnectionButton {text:"Copy code";enabled:!!prismBridge.loginCode;onClicked:prismBridge.copyLoginCode()}
            Text {text:prismBridge.loginCode || "";color:appRoot.ink;font.pixelSize:32;font.bold:true}
            Text {width:parent.width;visible:!!prismBridge.loginCode;text:"Open the Microsoft page and enter this code. Complete authentication in your browser.";wrapMode:Text.Wrap;color:appRoot.muted}
            Row {spacing:12
                ConnectionButton {text:"Open Microsoft";enabled:!!prismBridge.loginUrl;onClicked:Qt.openUrlExternally(prismBridge.loginUrl)}
                ConnectionButton {text:prismBridge.signingIn?"Cancel":"Close";onClicked:{prismBridge.cancelSignIn();loginPopup.close()}}
            }
        }
    }
    Popup {
        id:accountSettingsPopup;parent:appRoot.contentItem;anchors.centerIn:parent
        width:Math.min(540,appRoot.width-40);height:Math.min(appRoot.height-40,contentItem.implicitHeight+40);padding:20;modal:true;focus:true
        popupType:Popup.Window
        onOpened:{macWindowMetrics.setAccountGlass(contentItem,true);Qt.callLater(function(){clientIdField.forceActiveFocus(Qt.PopupFocusReason)})}
        onClosed:macWindowMetrics.setAccountGlass(contentItem,false)
        Timer {interval:16;repeat:true;running:accountSettingsPopup.visible && macWindowMetrics.nativeGlassDock;onTriggered:macWindowMetrics.setAccountGlass(accountSettingsPopup.contentItem,true)}
        background:GlassPane {radius:24;color:macWindowMetrics.nativeAccountGlass?"transparent":appRoot.glassStrong}
        contentItem:Column {
            spacing:12
            Text {text:"Microsoft sign-in";color:appRoot.ink;font.pixelSize:20}
            Text {width:parent.width;text:"Project Glass needs its own registered Microsoft application. Enable personal Microsoft accounts and public client flows, then enter the Application (client) ID. Minecraft API access may also require approval. Never enter a password or client secret here.";wrapMode:Text.WordWrap;color:appRoot.muted}
            ConnectionField {id:clientIdField;width:parent.width;text:prismBridge.microsoftClientId();placeholderText:"Microsoft client ID";activeFocusOnPress:true;readonly property bool validClientId:/^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$/.test(text.trim())}
            Row {spacing:10
                ConnectionButton {text:"Register app";onClicked:Qt.openUrlExternally("https://entra.microsoft.com/#view/Microsoft_AAD_RegisteredApps/ApplicationsListBlade")}
                ConnectionButton {text:"Setup guide";onClicked:Qt.openUrlExternally("https://learn.microsoft.com/en-us/entra/identity-platform/scenario-desktop-app-registration")}
            }
            Text {width:parent.width;visible:clientIdField.text.length>0 && !clientIdField.validClientId;text:"Enter the Application (client) ID in UUID format.";color:appRoot.muted;wrapMode:Text.WordWrap}
            Row {width:parent.width;layoutDirection:Qt.RightToLeft
                ConnectionButton {text:"Close";onClicked:accountSettingsPopup.close()}
            }
            ConnectionButton {text:"Save and sign in";enabled:clientIdField.validClientId;onClicked:{prismBridge.setMicrosoftClientId(clientIdField.text);if(prismBridge.microsoftClientId().toLowerCase()===clientIdField.text.trim().toLowerCase()){accountSettingsPopup.close();loginPopup.open();prismBridge.signIn()}}}
        }
    }
    Popup {
        id:canvasQuickDownload;parent:appRoot.contentItem;anchors.centerIn:parent
        width:360;height:Math.min(appRoot.height-40,contentItem.implicitHeight+padding*2);padding:24;modal:true;popupType:Popup.Window
        onOpened:{macWindowMetrics.setAccountGlass(contentItem,true);downloadData.loadQuickVersions(false)}
        onClosed:macWindowMetrics.setAccountGlass(contentItem,false)
        Timer {interval:16;repeat:true;running:canvasQuickDownload.visible && macWindowMetrics.nativeGlassDock;onTriggered:macWindowMetrics.setAccountGlass(canvasQuickDownload.contentItem,true)}
        background:GlassPane {radius:24;color:macWindowMetrics.nativeGlassDock?"transparent":appRoot.glassStrong;border.width:macWindowMetrics.nativeGlassDock?0:1}
        contentItem:Column {
            spacing:14
            Text {text:"Quick Download";font.pixelSize:20;font.bold:true;color:appRoot.ink}
            GlassSelect {accountMaterial:true;id:canvasQuickVersionSelect;width:parent.width;options:appRoot.quickVersionOptions;selected:appRoot.sidebarQuickVersion;onChosen:function(value){appRoot.sidebarQuickVersion=value}}
            GlassSelect {accountMaterial:true;width:parent.width;options:["Vanilla","Fabric","Forge","NeoForge","Quilt"];selected:appRoot.sidebarQuickLoader;onChosen:function(value){appRoot.sidebarQuickLoader=value}}
            Text {width:parent.width;text:"Continue to choose a compatible loader release and install.";wrapMode:Text.WordWrap;color:appRoot.muted;font.pixelSize:11}
            Text {
                width:parent.width; visible:downloadData.quickVersionsBusy || !!downloadData.quickVersionsError
                text:downloadData.quickVersionsBusy ? "Loading Minecraft versions…" : downloadData.quickVersionsError
                color:appRoot.muted;font.pixelSize:11;wrapMode:Text.WordWrap
            }
            ConnectionButton {visible:!!downloadData.quickVersionsError;text:"Retry versions";onClicked:downloadData.loadQuickVersions(true)}
            ConnectionButton {text:"Continue";onClicked:{canvasQuickDownload.close();appRoot.beginDownload({category:"Versions",name:"Minecraft "+appRoot.sidebarQuickVersion,version:appRoot.sidebarQuickVersion,detail:"Java Edition"})}}
        }
    }
    // Original account card in a window popup: same QML layout, above native views.
    Popup {
        id: accountPopup
        parent: appRoot.contentItem
        popupType: macWindowMetrics.nativeGlassDock ? Popup.Window : Popup.Item
        visible: appRoot.accountMenuOpen
        modal: false
        dim: false
        focus: true
        padding: 0
        margins: 12
        width: Math.min(340,appRoot.width-24)
        height: 216
        x: Math.max(12,Math.min(appRoot.width-width-12,appRoot.sidebarProgress>0.9?sidebar.x+22:compactAccountButton.x+compactAccountButton.width-width))
        y: Math.max(12,Math.min(appRoot.height-height-12,appRoot.sidebarProgress>0.9?sidebarAccountFooter.y-height-10:compactAccountButton.y+compactAccountButton.height+10))
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
        onOpened: if (macWindowMetrics.nativeGlassDock) macWindowMetrics.setAccountGlass(accountMenu, true)
        onClosed: {
            appRoot.accountMenuOpen = false
            macWindowMetrics.setAccountGlass(accountMenu, false)
        }
        background: Rectangle {
            radius: 24
            color: macWindowMetrics.nativeAccountGlass ? "transparent" : "#3D000000"
        }
        contentItem: GlassPane {
            id: accountMenu
            color: macWindowMetrics.nativeAccountGlass ? "transparent" : appRoot.glassStrong
            border.width: macWindowMetrics.nativeAccountGlass ? 0 : 1
            edgeGlow: !macWindowMetrics.nativeAccountGlass
            backdropBlur: false
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
                    TapHandler {onTapped:{appRoot.accountMenuOpen=false;accountsPopup.open()}}
                    objectName: "accountGlassControl"
                    width: 44; height: 44; radius: 22
                    color: macWindowMetrics.nativeAccountGlass ? "transparent" : (appRoot.darkMode ? "#527FA0C4" : "#9ED5EBFC")
                    Image { anchors.centerIn: parent; width: 30; height: 30; source: macWindowMetrics.defaultAccountAvatar; fillMode: Image.PreserveAspectFit }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    TextField {
                        id: profileName
                        text: prismBridge.offlineMode ? prismBridge.offlineName : (prismBridge.currentAccountName || "Not signed in")
                        width: accountMenu.width-112; height:26; padding:0;leftInset:0;rightInset:0;leftPadding:0;rightPadding:0
                        readOnly: true; selectByMouse: !readOnly
                        font.bold:true;font.pixelSize:15
                        color:readOnly?"transparent":appRoot.ink
                        Text {visible:profileName.readOnly;x:0;anchors.verticalCenter:parent.verticalCenter;width:parent.width;text:profileName.text;color:appRoot.ink;font:profileName.font;elide:Text.ElideRight}
                        background:Rectangle {color:profileName.readOnly?"transparent":appRoot.glassSoft;radius:6}
                        MouseArea {anchors.fill:parent;z:10;preventStealing:true;enabled:profileName.readOnly;onDoubleClicked:{if(!prismBridge.offlineMode)return;profileName.readOnly=false;profileName.forceActiveFocus();profileName.selectAll()}}
                        onAccepted:{if(prismBridge.offlineMode){if(!prismBridge.renameOffline(text))return}else appRoot.accountDisplayName=text.trim();readOnly=true;focus=false}
                        onEditingFinished: {if(!readOnly){if(prismBridge.offlineMode)prismBridge.renameOffline(text);else appRoot.accountDisplayName=text.trim();readOnly=true}}
                        Keys.onEscapePressed:{text=prismBridge.offlineMode?prismBridge.offlineName:appRoot.accountDisplayName;readOnly=true;focus=false}
                    }
                    Text { text: prismBridge.offlineMode ? "Offline profile" : (prismBridge.currentAccountName?"Microsoft account":"Not signed in"); font.pixelSize: 11; color: appRoot.muted; width: accountMenu.width - 112; elide: Text.ElideRight }
                }
            }
            Rectangle { width: parent.width; height: 1; color: appRoot.outline }
            Rectangle {
                objectName: "accountGlassControl"
                property bool glassHovered: microsoftHover.hovered
                width: parent.width; height: 40; radius: 16
                color: macWindowMetrics.nativeAccountGlass ? "transparent" : microsoftHover.hovered ? (appRoot.darkMode ? "#4D719BC3" : "#A5D5ECFC") : "#24FFFFFF"
                border.width: macWindowMetrics.nativeAccountGlass ? 0 : 1; border.color: appRoot.outline
                HoverHandler { id: microsoftHover }
                Text {
                    anchors.centerIn: parent
                    text: "＋  Add Microsoft account"
                    color: appRoot.ink
                    font.pixelSize: 13
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        appRoot.accountMenuOpen = false
                        loginPopup.open();prismBridge.useMicrosoft()
                    }
                }
            }
            RowLayout {
                width:parent.width;spacing:8
                Row {
                    spacing:8
                    Rectangle {
                        objectName:"accountGlassControl"
                        width:56;height:36;radius:18
                        property string nativeKind:"switch"
                        property bool nativeChecked:prismBridge.offlineMode
                        signal nativeActivated()
                        onNativeActivated:prismBridge.setOfflineMode(!prismBridge.offlineMode)
                        color:macWindowMetrics.nativeAccountGlass ? "transparent" : prismBridge.offlineMode ? Qt.rgba(appRoot.accent.r,appRoot.accent.g,appRoot.accent.b,0.38) : appRoot.glassSoft
                        border.width:macWindowMetrics.nativeAccountGlass?0:1;border.color:appRoot.outline
                        Accessible.role:Accessible.CheckBox;Accessible.name:"Play offline";Accessible.checked:prismBridge.offlineMode
                        activeFocusOnTab:true
                        Keys.onSpacePressed:prismBridge.setOfflineMode(!prismBridge.offlineMode)
                        Rectangle {visible:!macWindowMetrics.nativeAccountGlass;objectName:"accountGlassControl";width:22;height:22;radius:11;y:7;x:prismBridge.offlineMode?31:3;color:macWindowMetrics.nativeAccountGlass?"#60FFFFFF":"white";Behavior on x {NumberAnimation {duration:160}}}
                        TapHandler {onTapped:prismBridge.setOfflineMode(!prismBridge.offlineMode)}
                    }
                    Text {text:"Offline";color:appRoot.ink;font.pixelSize:12;anchors.verticalCenter:parent.verticalCenter}
                }
                Item {Layout.fillWidth:true}
                Rectangle {
                    objectName:"accountGlassControl";visible:!prismBridge.microsoftClientId();width:96;height:36;radius:18
                    property string nativeKind:"button"
                    signal nativeActivated()
                    onNativeActivated:{appRoot.accountMenuOpen=false;accountSettingsPopup.open()}
                    color:macWindowMetrics.nativeAccountGlass?"transparent":appRoot.glassSoft
                    border.width:macWindowMetrics.nativeAccountGlass?0:1;border.color:appRoot.outline
                    Text {visible:!macWindowMetrics.nativeAccountGlass;anchors.centerIn:parent;text:"Settings";color:appRoot.ink;font.pixelSize:12}
                    TapHandler {onTapped:{appRoot.accountMenuOpen=false;accountSettingsPopup.open()}}
                }
            }
        }
    }
    }
    GlassPane {
        id: statusDock
        visible: false
        z: 40
        HoverHandler { id: statusHover }
        // Keep the status above the dock and away from the sidebar.
        anchors.right: parent.right; anchors.rightMargin: 32; anchors.bottom: parent.bottom; anchors.bottomMargin: 110
        width: Math.min(355, appRoot.width - appRoot.contentLeft - 64)
        height: 38; radius: 19; subtle: true
        color: appRoot.darkMode ? appRoot.glassSoft : "#F3F8FD"
        Text { anchors.centerIn: parent; text: statusMessage; color: muted; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width - 24; horizontalAlignment: Text.AlignHCenter }
    }
    MouseArea {
        id:windowDragStrip;z:1000;x:0;y:-appRoot.contentItem.y;width:appRoot.width
        height:Math.max(24,topBar.y+appRoot.contentItem.y)
        acceptedButtons:Qt.LeftButton;preventStealing:true
        HoverHandler {id:windowStripHover}
        onPressed:function(mouse){appRoot.startSystemMove();mouse.accepted=true}
        onDoubleClicked:if(appRoot.visibility===Window.Maximized)appRoot.showNormal();else appRoot.showMaximized()
    }

}
