# QML smoke test with mocked core/platform adapters. Requires PySide6 Essentials.
# Exercises page creation and navigation; does NOT validate AppKit or core downloads.
import os,re
from pathlib import Path
os.environ['QT_QPA_PLATFORM']='offscreen'
os.environ['QT_QUICK_BACKEND']='software'
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickItem
from PySide6.QtQml import QQmlEngine,QQmlComponent,QQmlExpression,QQmlContext,qmlContext
from PySide6.QtCore import QUrl,QTimer,qInstallMessageHandler,Qt,QPoint,QPointF
from PySide6.QtTest import QTest
app=QGuiApplication([]);app.setOrganizationName('PGSmoke');app.setApplicationName('PGSmoke')
root=Path(__file__).resolve().parents[1]
engine=QQmlEngine();owned=[]
metrics=(root/'MacWindowMetrics.h').read_text()
props=[]
for typ,name in re.findall(r'Q_PROPERTY\((\w+) (\w+)',metrics):
 t={'bool':'bool','qreal':'real','QString':'string','int':'int'}[typ]
 v='false' if t=='bool' else '""' if t=='string' else '24' if name=='windowCornerRadius' else '0'
 props.append(f'property {t} {name}: {v}')
funcs=[]
for name in set(re.findall(r'Q_INVOKABLE\s+\w+\s+(\w+)\(',metrics)):
 result='"#0A84FF"' if name=='systemAccentColor' else '({totalMiB:16384,usedMiB:4096})' if name=='systemMemory' else '""'
 funcs.append(f'function {name}() {{ return {result}; }}')
signals=[]
for name in set(re.findall(r'function on(\w+)\(', (root/'Main.qml').read_text())):
 n=name[0].lower()+name[1:]
 if n not in [p+'Changed' for _,p in re.findall(r'Q_PROPERTY\((\w+) (\w+)',metrics)]:signals.append(f'signal {n}(var a, var b, var c)')
for name,body in [('macWindowMetrics','\n'.join(props+funcs+signals)),('prismBridge','''property var savedAccounts:[];property string currentAccountName:"";property bool signingIn:false;property string loginQr:"";property string loginCode:"";property string loginUrl:"";property var instances: [];property string status:"Ready";property bool offlineMode:true;property string offlineName:"Player";property string executable:"core";property string dataRoot:"/tmp";property bool installing:false;property real installProgress:0;property string editorInstanceKey:"";property var editorDetails:({});property var editorRequests:[]
property var editorFixture:({mods:[{name:"fabric-api.jar",fileName:"fabric-api.jar",source:"file:///tmp/mods/fabric-api.jar",enabled:true}],resourcePacks:[{name:"pack.zip",fileName:"pack.zip",source:"file:///tmp/resourcepacks/pack.zip",enabled:true}],shaderPacks:[],worlds:[{name:"Survival",fileName:"Survival",source:"file:///tmp/saves/Survival",enabled:true}],screenshots:[],servers:[{name:"Example",address:"example.test",index:0}],components:[{uid:"net.minecraft",name:"Minecraft",version:"1.20.1"}],notes:"Saved instance notes",minecraftLog:"Actual latest.log text",otherLogs:"Crash report text",javaPath:"/example/java",javaArgs:"-XX:+UseG1GC",memoryMiB:4096,useDefaultMemory:false,error:""})
function watchInstance(key) {editorInstanceKey=key;editorDetails=key?Object.assign({key:key},JSON.parse(JSON.stringify(editorFixture))):({})}
function refreshEditor(){if(editorInstanceKey)editorDetails=Object.assign({key:editorInstanceKey},JSON.parse(JSON.stringify(editorFixture)))}
function saveEditorSettings(key,patch) {editorRequests=editorRequests.concat([{action:"settings",key:key,patch:patch}]);editorFixture=Object.assign({},editorFixture,patch);refreshEditor();return true}
function importEditorAsset(key,bucket,source) {editorRequests=editorRequests.concat([{action:"import",key:key,bucket:bucket,source:source}]);return true}
function setEditorAssetEnabled(key,bucket,fileName,enabled) {editorRequests=editorRequests.concat([{action:"enabled",key:key,bucket:bucket,fileName:fileName,enabled:enabled}]);return true}
function removeEditorAsset(key,bucket,fileName) {editorRequests=editorRequests.concat([{action:"remove",key:key,bucket:bucket,fileName:fileName}]);return true}
function editServer(key,address,index) {editorRequests=editorRequests.concat([{action:"server",key:key,address:address,index:index}]);return true}
function openEditorFolder(){}
function revealEditorAsset(){}
signal changed();signal instanceReady(string key);property var installedRequests: []
function installModrinth(key,category,project,name,release) { installedRequests = installedRequests.concat([{key:key,category:category,project:project,release:release}]);return true; }
function installGame(game,loader,version) { installedRequests = installedRequests.concat([{game:game,loader:loader,version:version}]);return true; }
property int copyRequests:0;function copyLoginCode(){copyRequests++}
function cancelSignIn(){}
function signIn(){}
function selectSavedAccount(id){}
function removeSavedAccount(id){}
function microsoftClientId(){return "";}''')]:
 c=QQmlComponent(engine);c.setData(('import QtQuick\nQtObject{'+body+'}').encode(),QUrl());o=c.create()
 if not o:raise Exception([e.toString() for e in c.errors()])
 owned.extend([c,o]);engine.rootContext().setContextProperty(name,o)
errors=[]
def message(kind,context,text):
 if any(marker in text for marker in ['ReferenceError', 'TypeError', 'Error:', 'Unable to assign', 'Cannot assign', 'Binding loop']):errors.append(text)
qInstallMessageHandler(message)
c=QQmlComponent(engine,QUrl.fromLocalFile(str(root/'Main.qml')));obj=c.create()
print('Root created:',bool(obj));print('Component errors:',[e.toString() for e in c.errors()])
def evaluate(code):
 expression=QQmlExpression(qmlContext(obj),obj,code)
 result=expression.evaluate()
 if expression.hasError():raise AssertionError(expression.error().toString())
 return result
obj.setProperty('downloadReady',False)
obj.setProperty('activePage','Download')
evaluate('downloadRows.append({entry:{category:"Versions",name:"Minecraft 1.20.1",version:"1.20.1",badge:"MC",detail:"Java Edition",icon:""}})')
app.processEvents()
evaluate('downloadList.contentY=40')
engine.rootContext().contextProperty('macWindowMetrics').setProperty('nativeGlassDock',True)
app.processEvents()
evaluate('beginDownload({category:"Versions",name:"Minecraft 1.20.1",version:"1.20.1"})')
app.processEvents()
# Check the real QML installation dispatcher, with only the backend mocked.
bridge=engine.rootContext().contextProperty('prismBridge')
for category in ['Mods','Resource packs','Shaders','Modpacks']:
 evaluate('beginDownload({category:'+repr(category)+',projectId:"project",name:"Example"})')
 evaluate('downloadData.releases=[{id:"release",eligible:true,raw:{id:"release",project_id:"project",files:[]}}]; selectedId="prism:test"; selectedRelease="release"; installSelectedRelease()')
assert evaluate('prismBridge.installedRequests.length')[0] == 4
assert evaluate('prismBridge.installedRequests[3].release.id')[0] == 'release'
evaluate('downloadData.releases=[{id:"bad",eligible:false,raw:{id:"bad"}}];selectedRelease="bad";installSelectedRelease()')
assert evaluate('prismBridge.installedRequests.length')[0] == 4
bridge.setProperty('installing',True)
evaluate('downloadData.releases=[{id:"busy",eligible:true,raw:{id:"busy"}}];selectedRelease="busy";installSelectedRelease()')
assert evaluate('prismBridge.installedRequests.length')[0] == 4
bridge.setProperty('installing',False)
# A newly installed instance selects the right artwork immediately.
evaluate('prismBridge.instances=[{key:"prism:installed",label:"Fresh Fabric",version:"Fabric 1.20.1",coverKey:"fabric",hours:0,launches:0,installed:true,lastPlayed:false}];prismBridge.instanceReady("prism:installed")')
assert evaluate('selectedId')[0] == 'prism:installed'
assert 'default-fabric.svg' in evaluate('selectedDockArtwork')[0]
evaluate('setInstanceMetadata("prism:installed",{background:"file:///tmp/custom-card.png"})')
assert evaluate('selectedDockArtwork')[0] == 'file:///tmp/custom-card.png'
assert evaluate('selectedDockDefaultArtwork')[0] is False
evaluate('setInstanceMetadata("prism:installed",{background:""})')
assert 'default-fabric.svg' in evaluate('selectedDockArtwork')[0]
# Catalogue refreshes and release selection must not shrink quick-download options.
evaluate('downloadData.quickVersions=Array.from({length:100},function(_,i){return "1.20."+i});sidebarQuickVersion="1.20.1"')
assert evaluate('quickVersionOptions.length')[0] == 100
evaluate('downloadData.closeReleases();downloadData.catalogue=[]')
assert evaluate('quickVersionOptions.length')[0] == 100
engine.rootContext().contextProperty('macWindowMetrics').setProperty('nativeGlassDock',False)
evaluate('sidebarQuickDownloadExpanded=true;canvasQuickDownload.open();canvasQuickVersionSelect.popup.open()')
app.processEvents()
evaluate('canvasQuickVersionSelect.popup.contentItem.positionViewAtIndex(99,ListView.End)')
evaluate('canvasQuickVersionSelect.chosen("1.20.99");canvasQuickVersionSelect.popup.close();canvasQuickDownload.close()')
assert evaluate('sidebarQuickVersion')[0] == '1.20.99'
assert evaluate('quickVersionOptions.length')[0] == 100
obj.setProperty('activePage','Launch')
for zoom in [0.55,0.75,1.0,1.35,1.65]:
 obj.setProperty('zoom',zoom);app.processEvents()
# The release body selects; its separate button starts the chosen download.
evaluate('beginDownload({category:"Mods",projectId:"project",name:"Example"});selectedId="prism:installed";downloadData.releaseBusy=false;downloadData.releaseError="";downloadData.releases=[{id:"row-one",label:"Release one",detail:"Fabric",group:"Current instance",eligible:true,raw:{id:"row-one",project_id:"project"}},{id:"row-bad",label:"Wrong loader",detail:"Forge",group:"Current instance",eligible:false,raw:{id:"row-bad",project_id:"project"}}];selectedRelease=""')
app.processEvents()
row=evaluate('releaseList.itemAtIndex(1)')[0]
assert row is not None
before=evaluate('prismBridge.installedRequests.length')[0]
p=row.mapToScene(QPointF(30,41));QTest.mouseClick(obj,Qt.LeftButton,Qt.NoModifier,QPoint(round(p.x()),round(p.y())))
assert evaluate('selectedRelease')[0]=='row-one'
assert evaluate('prismBridge.installedRequests.length')[0]==before
p=row.mapToScene(QPointF(row.width()-72,41));QTest.mouseClick(obj,Qt.LeftButton,Qt.NoModifier,QPoint(round(p.x()),round(p.y())))
assert evaluate('prismBridge.installedRequests.length')[0]==before+1
bad=evaluate('releaseList.itemAtIndex(2)')[0]
p=bad.mapToScene(QPointF(bad.width()-72,41));QTest.mouseClick(obj,Qt.LeftButton,Qt.NoModifier,QPoint(round(p.x()),round(p.y())))
assert evaluate('prismBridge.installedRequests.length')[0]==before+1
assert evaluate('selectedRelease')[0]=='row-one'
obj.setProperty('activePage','Launch')
# A real pointer drag at 75% zoom must resize in logical canvas units.
evaluate('instances.clear();syncPrismInstances();groupedLayoutEnabled=false;groupingMethod="Off";freeCanvasEnabled=true;freeHiddenJson="[]";customCardSizesJson=JSON.stringify({"prism:installed":{width:240,height:168}});freeRectsJson=JSON.stringify({"prism:installed":{x:-120,y:-84,width:240,height:168}});cardSizeEditing=true;zoom=0.75')
app.processEvents()
handle=evaluate('(function visit(item){if(item.objectName==="cardResizeHandle-prism:installed-right")return item;for(var i=0;i<item.children.length;i++){var found=visit(item.children[i]);if(found)return found}return null})(canvas)')[0]
assert handle is not None
point=handle.mapToScene(QPointF(handle.width()/2,handle.height()/2))
position=QPoint(round(point.x()),round(point.y()))
QTest.mousePress(obj,Qt.LeftButton,Qt.NoModifier,position)
QTest.mouseMove(obj,position+QPoint(60,0),20)
QTest.mouseRelease(obj,Qt.LeftButton,Qt.NoModifier,position+QPoint(60,0))
app.processEvents()
actual=evaluate('customCardSizes["prism:installed"].width')[0]
assert abs(actual-320)<2, actual
evaluate('setCardSize("prism:installed",9999,1)')
assert evaluate('customCardSizes["prism:installed"].width')[0]==640
assert evaluate('customCardSizes["prism:installed"].height')[0]==126
# Grouped shelves also resize while preserving their layout and saved sizes.
evaluate('groupCardSizesJson="{}";customCardSizesJson=JSON.stringify({"prism:installed":{width:240,height:168}});freeCanvasEnabled=false;groupedLayoutEnabled=true;groupingMethod="Smart"')
engine.rootContext().contextProperty('macWindowMetrics').setProperty('nativeGlassDock',True)
app.processEvents()
handle=evaluate('(function visit(item){if(item.visible && item.objectName==="cardResizeHandle-prism:installed-right")return item;for(var i=0;i<item.children.length;i++){var found=visit(item.children[i]);if(found)return found}return null})(canvas)')[0]
assert handle is not None
point=handle.mapToScene(QPointF(handle.width()/2,handle.height()/2))
position=QPoint(round(point.x()),round(point.y()))
QTest.mousePress(obj,Qt.LeftButton,Qt.NoModifier,position)
QTest.mouseMove(obj,position+QPoint(48,0),20)
QTest.mouseRelease(obj,Qt.LeftButton,Qt.NoModifier,position+QPoint(48,0))
app.processEvents()
assert abs(evaluate('cardSize("prism:installed",240,168).width')[0]-288)<2
assert evaluate('customCardSizes["prism:installed"].width')[0]==240
assert evaluate('hasInstanceGroups')[0] is True
# Group resizing affects every member and does not overwrite individual sizes.
evaluate('prismBridge.instances=prismBridge.instances.concat([{key:"prism:peer",label:"Peer",version:"Fabric 1.20.1",coverKey:"fabric",hours:0,launches:0,installed:true,lastPlayed:false},{key:"prism:frequent",label:"Frequent",version:"Minecraft 1.20.1",coverKey:"vanilla",hours:100,launches:100,installed:true,lastPlayed:true}]);setCardSize("prism:installed",400,260)')
assert evaluate('cardSize("prism:peer",240,168).width')[0]==400
assert evaluate('cardSize("prism:frequent",300,210).width')[0]==300
assert evaluate('customCardSizes["prism:installed"].width')[0]==240
evaluate('groupedLayoutEnabled=false;groupingMethod="Off";setCardSize("prism:installed",350,210)')
assert evaluate('cardSize("prism:installed",240,168).width')[0]==350
assert evaluate('cardSize("prism:peer",240,168).width')[0]==240
evaluate('groupedLayoutEnabled=true;groupingMethod="Smart"')
assert evaluate('cardSize("prism:installed",240,168).width')[0]==400
# Position and vertical alignment switch between the search and account anchors.
evaluate('sidebarMode=false;searchExpanded=false')
QTest.qWait(450)
assert evaluate('resizeDoneButton.besideSearch')[0] is False
assert abs(evaluate('resizeDoneButton.y+resizeDoneButton.height/2-compactAccountButton.y-compactAccountButton.height/2')[0])<0.1
evaluate('sidebarMode=true')
QTest.qWait(450)
assert evaluate('resizeDoneButton.besideSearch')[0] is True
assert abs(evaluate('resizeDoneButton.x+resizeDoneButton.width+12-searchDock.x')[0])<0.1
assert abs(evaluate('resizeDoneButton.y+resizeDoneButton.height/2-searchDock.y-searchDock.height/2')[0])<0.1
evaluate('searchExpanded=true')
QTest.qWait(250)
assert abs(evaluate('resizeDoneButton.x+resizeDoneButton.width+12-searchDock.x')[0])<0.1
assert abs(evaluate('resizeDoneButton.y+resizeDoneButton.height/2-searchDock.y-searchDock.height/2')[0])<0.1
evaluate('searchExpanded=false')
evaluate('cardSizeEditing=false;cardMetadataJson=JSON.stringify({"prism:installed":{mods:[{name:"UI-only fake entry"}]}});editInstance("prism:installed")')
assert evaluate('editingMetadata.mods[0].name')[0]=='fabric-api.jar'
assert evaluate('editingMetadata.worlds[0].name')[0]=='Survival'
assert evaluate('editingMetadata.notes')[0]=='Saved instance notes'
assert evaluate('editorLogText')[0]=='Actual latest.log text'
for tab in ['Overview','Minecraft Log','Version','Mods','Resource Packs','Shader Packs','Notes','Worlds','Servers','Screenshots','Settings','Other Logs']:
 obj.setProperty('editorTab',tab);app.processEvents()
# The list renders through its former inner margins, and the enclosing pane clips it.
obj.setProperty('editorTab','Mods');app.processEvents()
assert evaluate('(function visit(item){if(item.objectName==="editorAssetViewport" && item.visible){var pane=item.parent.parent;return !item.clip && pane.clip && pane.radius===24}for(var i=0;i<item.children.length;i++){if(visit(item.children[i]))return true}return false})(instanceEditorPage)')[0]
assert evaluate('(function visit(item){if(item.visible && item.materialRole==="sectionHeader" && item.headerTitle==="Mods")return true;for(var i=0;i<item.children.length;i++){if(visit(item.children[i]))return true}return false})(instanceEditorPage)')[0]
evaluate('toggleEditorAsset("mods",editingMetadata.mods[0],false);removeEditorAsset("resourcePacks",editingMetadata.resourcePacks[0]);editorAssetBucket="mods";addEditorAsset("file:///tmp/new.jar");setInstanceMetadata(editingInstanceKey,{notes:"Updated notes",memoryMiB:6144});addEditorServer("server.test");removeEditorServer(editingMetadata.servers[0],0)')
assert evaluate('prismBridge.editorRequests.length')[0]==6
assert evaluate('prismBridge.editorRequests[0].fileName')[0]=='fabric-api.jar'
assert evaluate('prismBridge.editorRequests[1].fileName')[0]=='pack.zip'
assert evaluate('editingMetadata.memoryMiB')[0]==6144
assert evaluate('editingMetadata.notes')[0]=='Updated notes'
# Background updates must not discard unsaved form edits.
evaluate('instanceJavaArgs.text="-Xmx-draft";editorDirtyFields.javaArgs=true;prismBridge.editorFixture.minecraftLog+=" new line";prismBridge.refreshEditor()')
assert evaluate('instanceJavaArgs.text')[0]=='-Xmx-draft'
evaluate('prismBridge.editorFixture.mods=prismBridge.editorFixture.mods.concat([{name:"new.jar",fileName:"new.jar",source:"file:///tmp/mods/new.jar",enabled:true}]);prismBridge.refreshEditor()')
assert evaluate('editingMetadata.mods.length')[0]==2
obj.setProperty('activePage','Launch')
assert bridge.property('editorInstanceKey')==''
# Exercise real keyboard input in the popup window (not programmatic text assignment).
evaluate('accountSettingsPopup.open();clientIdField.text=""')
QTest.qWait(30);app.processEvents()
field=evaluate('clientIdField')[0]
assert field.property('activeFocus')
for ch in 'not-a-client-id':QTest.keyClick(field.window(),ord(ch.upper()),Qt.NoModifier)
assert len(field.property('text'))>0
assert evaluate('clientIdField.validClientId')[0] is False
evaluate('clientIdField.text=""')
for ch in '01234567-89ab-cdef-0123-456789abcdef':
 QTest.keyClick(field.window(),ord(ch.upper()),Qt.NoModifier)
assert field.property('text').lower()=='01234567-89ab-cdef-0123-456789abcdef', repr(field.property('text'))
assert evaluate('clientIdField.validClientId')[0] is True
evaluate('clientIdField.selectAll()')
app.clipboard().setText(' 01234567-89ab-cdef-0123-456789abcdef ')
QTest.keyClick(field.window(),Qt.Key_V,Qt.ControlModifier)
assert field.property('text')==' 01234567-89ab-cdef-0123-456789abcdef '
assert evaluate('clientIdField.validClientId')[0] is True
evaluate('accountSettingsPopup.close()')
for page in ['Launch','Download','Settings','Instance']:
 obj.setProperty('activePage',page);app.processEvents()
 assert evaluate('statusDock.visible')[0] is False
# New configuration and account surfaces load with realistic adapter data.
evaluate('prismBridge.savedAccounts=[{id:"one",name:"PlayerOne",selected:true,type:"msa"},{id:"two",name:"PlayerTwo",selected:false,type:"msa"}];accountsPopup.open()')
app.processEvents()
evaluate('accountsPopup.close();backgroundMode="Custom color";customGradient=true;customColorStart="#123456";customColorEnd="#abcdef";customGradientAngle=135')
app.processEvents()
assert evaluate('customGradientAngle')[0]==135
evaluate('loginPopup.open();prismBridge.signingIn=true;prismBridge.loginCode="ABCD1234";prismBridge.loginUrl="https://www.microsoft.com/link"')
app.processEvents()
evaluate('prismBridge.signingIn=false;prismBridge.status="Sign-in failed: test error"')
app.processEvents()
evaluate('loginPopup.close()')
evaluate('backgroundMode="Custom color";customGradient=true;addGradientStop()')
assert evaluate('gradientStops.length')[0]==3
evaluate('updateGradientStop(2,"#ff0000",0.35)')
assert evaluate('gradientStops[2].position')[0]==0.35
evaluate('removeGradientStop(2)')
assert evaluate('gradientStops.length')[0]==2
evaluate('removeGradientStop(0)')
assert evaluate('gradientStops.length')[0]==2
evaluate('prismBridge.copyLoginCode()')
assert evaluate('prismBridge.copyRequests')[0]==1
for near,wanted in [(1,0),(43,45),(92,90),(134,135),(177,180),(226,225),(268,270),(317,315),(359,360)]:
 assert evaluate('snapGradientAngle('+str(near)+')')[0]==wanted
assert evaluate('snapGradientAngle(20)')[0]==20
evaluate('backgroundMode="Custom color";customGradient=true;themeChoice="Auto";gradientStopsJson=JSON.stringify([{color:"#e06020",position:0},{color:"#20a0e0",position:1}])')
assert evaluate('autoAccent.b>autoAccent.r')[0]
QTimer.singleShot(300,app.quit);app.exec()
print('Runtime errors:',len(errors));print('\n'.join(dict.fromkeys(errors)))
if obj:obj.setProperty('visible',False);obj.deleteLater();app.processEvents()

assert obj is not None
assert not errors, "QML runtime errors were reported"
