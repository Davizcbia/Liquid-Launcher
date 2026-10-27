# Offline tests for the independent quick-version metadata request lifecycle.
import os
from pathlib import Path
os.environ['QT_QPA_PLATFORM'] = 'offscreen'
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlEngine, QQmlComponent, QQmlExpression, qmlContext
from PySide6.QtCore import QUrl
app = QGuiApplication([])
engine = QQmlEngine()
root = Path(__file__).resolve().parents[1]
component = QQmlComponent(engine)
component.setData(b'''import QtQuick
DownloadData {
    property var pending: ({})
    function request(channel, url, done) { pending[channel] = done }
}''', QUrl.fromLocalFile(str(root / 'QuickVersionsHarness.qml')))
api = component.create()
assert api is not None, [e.toString() for e in component.errors()]
def evaluate(code):
    expression = QQmlExpression(qmlContext(api), api, code)
    value = expression.evaluate()[0]
    assert not expression.hasError(), expression.error().toString()
    return value

evaluate('loadQuickVersions(false)')
assert api.property('quickVersionsBusy') is True
evaluate('pending.quickVersions(null,{versions:Array.from({length:100},function(_,i){return {version:"1.20."+i,type:"release",releaseTime:"2026-01-01"}})})')
assert api.property('quickVersionsBusy') is False
assert evaluate('quickVersions.length') == 100
# A filtered catalogue and loader page have their own channels and state.
evaluate('loadCatalogue("Versions","1.20.1","Newest",false,"Vanilla","Modrinth");pending.catalogue(null,{versions:[{version:"1.20.1",type:"release"}]});closeReleases()')
assert evaluate('catalogue.length') == 1
assert evaluate('quickVersions.length') == 100
# Failed refreshes retain the last good complete list and allow retry.
evaluate('loadQuickVersions(true);pending.quickVersions("Network unavailable",null)')
assert api.property('quickVersionsBusy') is False
assert api.property('quickVersionsError') == 'Network unavailable'
assert evaluate('quickVersions.length') == 100
evaluate('loadQuickVersions(true);pending.quickVersions(null,{versions:[{version:"1.22",type:"release"}]})')
assert evaluate('quickVersions.length') == 1
assert api.property('quickVersionsError') == ''
print('Independent quick-version catalogue, retained options and retry checks passed')
