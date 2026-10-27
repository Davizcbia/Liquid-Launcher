.pragma library
function clone(value) { return JSON.parse(JSON.stringify(value)) }
function select(keys,key,toggle) {
    if(!toggle)return [key]
    var result=keys.slice(), index=result.indexOf(key)
    if(index<0)result.push(key);else result.splice(index,1)
    return result
}
function menuActions(count) {
    return count===1 ? ["Launch","Kill","Edit","Duplicate","Change background","Folder","Export","Copy","Delete","Create Shortcut","New group","Move to group","Ungrouped"] : ["Duplicate","Copy","New group","Move to group","Ungrouped"]
}
function duplicate(records,keys,metadata) {
    var copies=[], result=clone(metadata), used=records.map(function(r){return r.key}), names=records.map(function(r){return r.label})
    records.forEach(function(record) {
        if(keys.indexOf(record.key)<0)return
        var n=1,key=record.key+"-copy-"+n
        while(used.indexOf(key)>=0)key=record.key+"-copy-"+(++n)
        var label=record.label+" copy",suffix=1
        while(names.indexOf(label)>=0)label=record.label+" copy "+(++suffix)
        var copy=clone(record);copy.key=key;copy.label=label;copy.hours=0;copy.launches=0;copy.lastPlayed=false
        copy.coverKey=record.coverKey||record.key
        copies.push(copy);used.push(key);names.push(label)
        result[key]=clone(metadata[record.key]||{mods:[],background:""})
    })
    return {copies:copies,metadata:result}
}

function sidebarRows(cards,groups,collapsed,enabled) {
    var installed=cards.filter(function(c){return c.installed}), rows=[], used={}
    if(!enabled)return installed.map(function(c){var r=clone(c);r.type="instance";return r})
    function append(id,name,members) {
        if(!members.length)return
        rows.push({type:"header",key:"header:"+id,groupId:id,label:name,count:members.length})
        members.forEach(function(c){used[c.key]=true})
        if(collapsed.indexOf(id)>=0)return
        members.forEach(function(c){var r=clone(c);r.type="instance";rows.push(r)})
    }
    groups.forEach(function(g){append(g.id,g.name,installed.filter(function(c){return g.keys.indexOf(c.key)>=0 && !used[c.key]}))})
    append("ungrouped","Ungrouped",installed.filter(function(c){return !used[c.key]}))
    return rows
}
function removeRecords(records,keys) { return records.filter(function(r){return keys.indexOf(r.key)<0}) }
