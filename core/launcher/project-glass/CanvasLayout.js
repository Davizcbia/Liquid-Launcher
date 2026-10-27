.pragma library

// Actual rectangle edges keep a shared safety gap even in a staggered layout.
function intersects(a, b, gap) {
    return a.x < b.x + b.width + gap && a.x + a.width + gap > b.x &&
           a.y < b.y + b.height + gap && a.y + a.height + gap > b.y
}
// Grow a compact frontier in all directions, without rows or column widths.
function spread(count, gap, sizes) {
    if (count <= 0) return []
    var first=sizes && sizes[0] || {width:340,height:240}
    var placed = [{x:-first.width/2, y:-first.height/2, width:first.width, height:first.height}]
    var widths = [252,228,264,236,248,220,256]
    var heights = [176,184,164,180,168,188,172]
    while (placed.length < count) {
        var rank=placed.length, custom=sizes && sizes[rank], w=custom?custom.width:widths[(rank-1)%widths.length], h=custom?custom.height:heights[(rank-1)%heights.length]
        var targetAngle=rank*2.399963229728653, best=null, bestScore=Infinity
        for (var i=0;i<placed.length;i++) {
            var a=placed[i], candidates=[]
            for (var k=0;k<5;k++) {
                var t=k/4
                var x=a.x+(a.width-w)*t, y=a.y+(a.height-h)*t
                candidates.push({x:a.x+a.width+gap,y:y,width:w,height:h})
                candidates.push({x:a.x-w-gap,y:y,width:w,height:h})
                candidates.push({x:x,y:a.y+a.height+gap,width:w,height:h})
                candidates.push({x:x,y:a.y-h-gap,width:w,height:h})
            }
            for (var c=0;c<candidates.length;c++) {
                var r=candidates[c], fits=true
                for (var j=0;j<placed.length;j++) {
                    if (intersects(r,placed[j],gap-0.0001)) { fits=false; break }
                }
                if (!fits) continue
                var cx=r.x+w/2, cy=r.y+h/2, distance=cx*cx+cy*cy
                // Prefer nearby open edges, while rotating the growth direction.
                var score=distance*(1+0.28*(1-Math.cos(Math.atan2(cy,cx)-targetAngle)))
                if (score<bestScore) { bestScore=score; best=r }
            }
        }
        if (!best) throw new Error("No free edge for card")
        placed.push(best)
    }
    return placed
}
function reorder(keys, draggedKey, targetKey, after) {
    var result = keys.slice(), from = result.indexOf(draggedKey)
    if (from < 0 || draggedKey === targetKey) return result
    result.splice(from, 1)
    var target = result.indexOf(targetKey)
    if (target < 0) return keys.slice()
    result.splice(target + (after ? 1 : 0), 0, draggedKey)
    return result
}

// Group membership uses stable instance keys; ordering comes from sorted cards.
function assignGroup(groups, key, groupId) {
    return groups.map(function(g) {
        var keys=g.keys.filter(function(k){return k!==key})
        if(g.id===groupId) keys.push(key)
        return {id:g.id,name:g.name,keys:keys}
    })
}
function shelfMetrics(name, method) {
    var frequent=method==="Smart" && name==="Frequently played"
    return {width:frequent?300:240,height:frequent?210:168}
}
function grouped(cards, groups, method) {
    var sections=[], positions={}, used={}, y=0, gap=24, w=240, h=168
    function append(id,name,items) {
        var metrics=shelfMetrics(name,method), w=metrics.width, h=metrics.height
        sections.push({id:id,name:name,y:y,count:items.length,cardWidth:w,cardHeight:h})
        for(var i=0;i<items.length;i++) {
            positions[items[i].key]={x:i*(w+gap),y:y+40,width:w,height:h}
            used[items[i].key]=true
        }
        y+=items.length ? 40+h+36 : 96
    }
    for(var g=0;g<groups.length;g++) {
        var group=groups[g]
        append(group.id,group.name,cards.filter(function(card){return group.keys.indexOf(card.key)>=0 && !used[card.key]}))
    }
    var remaining=cards.filter(function(card){return !used[card.key]})
    if(remaining.length) append("ungrouped","Ungrouped",remaining)
    return {sections:sections,positions:cards.map(function(card){return positions[card.key]}),height:y}
}

function automaticGroups(cards, method) {
    var groups=[], lookup={}
    for(var i=0;i<cards.length;i++) {
        var card=cards[i], name="", order=0
        if(method==="Minecraft version") {
            var match=String(card.version).match(/\b\d+\.\d+(?:\.\d+)?\b/)
            name=match ? match[0] : "Quick download"
        } else if(method==="Mod loader") {
            var text=(card.version+" "+card.label+" "+card.key).toLowerCase()
            name=text.indexOf("neoforge")>=0 ? "NeoForge" : text.indexOf("fabric")>=0 ? "Fabric" : text.indexOf("quilt")>=0 ? "Quilt" : text.indexOf("forge")>=0 ? "Forge" : "Vanilla"
            order=["Vanilla","Fabric","Forge","NeoForge","Quilt"].indexOf(name)
        } else if(method==="Installed status") {
            name=card.installed ? "Installed" : "Quick download"; order=card.installed ? 0 : 1
        } else {
            if(!card.installed) {name="Quick download";order=3}
            else if(card.hours>=60 || card.launches>=60) {name="Frequently played";order=0}
            else if(card.hours>0 || card.launches>0) {name="Played";order=1}
            else {name="Not played yet";order=2}
        }
        if(lookup[name]===undefined) {
            lookup[name]=groups.length
            groups.push({id:"auto-"+method+"-"+name,name:name,keys:[],order:order})
        }
        groups[lookup[name]].keys.push(card.key)
    }
    groups.sort(function(a,b) {
        if(method==="Minecraft version") {
            if(a.name==="Quick download")return 1
            if(b.name==="Quick download")return -1
            var av=a.name.split("."),bv=b.name.split(".")
            for(var i=0;i<Math.max(av.length,bv.length);i++) {
                var delta=Number(bv[i]||0)-Number(av[i]||0)
                if(delta)return delta
            }
            return 0
        }
        return a.order-b.order
    })
    return groups
}

function routeScroll(dx, dy, shift) {
    if (shift || Math.abs(dx)>Math.abs(dy)) return {axis:"x",delta:shift && dx===0 ? dy : dx}
    return {axis:"y",delta:dy}
}
function scrollPosition(current, delta, content, viewport) {
    return Math.max(0,Math.min(Math.max(0,content-viewport),current-delta))
}

// Keep a small layout fully in view; allow a large layout to pan only across
// its actual bounds. Coordinates include the current zoom and canvas origin.
function panLimits(rects,scale,originX,originY,viewport,slack) {
    if(!rects.length)return {minX:0,maxX:0,minY:0,maxY:0}
    var minX=Infinity,minY=Infinity,maxX=-Infinity,maxY=-Infinity
    rects.forEach(function(r){minX=Math.min(minX,originX+r.x*scale);maxX=Math.max(maxX,originX+(r.x+r.width)*scale);minY=Math.min(minY,originY+r.y*scale);maxY=Math.max(maxY,originY+(r.y+r.height)*scale)})
    function axis(low,high,start,end) {
        end=Math.max(start+1,end)
        if(high-low<=end-start)return {min:start-low,max:end-high}
        return {min:end-high,max:start-low}
    }
    var x=axis(minX,maxX,viewport.left,viewport.right),y=axis(minY,maxY,viewport.top,viewport.bottom)
    slack=slack||{x:0,y:0}
    return {minX:x.min-Math.max(0,slack.x||0),maxX:x.max+Math.max(0,slack.x||0),
            minY:y.min-Math.max(0,slack.y||0),maxY:y.max+Math.max(0,slack.y||0)}
}

// Nearest valid placement among the requested point and obstacle edge alignments.
function avoidOverlap(request,obstacles,gap) {
    var xs=[request.x],ys=[request.y]
    obstacles.forEach(function(o){xs.push(o.x-request.width-gap,o.x+o.width+gap);ys.push(o.y-request.height-gap,o.y+o.height+gap)})
    var best=null,score=Infinity
    xs.forEach(function(x){ys.forEach(function(y){var r={x:x,y:y,width:request.width,height:request.height};if(obstacles.some(function(o){return intersects(r,o,gap-0.001)}))return;var d=(x-request.x)*(x-request.x)+(y-request.y)*(y-request.y);if(d<score){best=r;score=d}})})
    return best || request
}

// Resizing never crosses the opposite edge or exceeds the stored size limits.
function resizeRect(start, edge, dx, dy, bounds) {
    var west=edge.indexOf("left")>=0,east=edge.indexOf("right")>=0
    var north=edge.indexOf("top")>=0,south=edge.indexOf("bottom")>=0
    var width=Math.max(bounds.minWidth,Math.min(bounds.maxWidth,start.width+(east?dx:west?-dx:0)))
    var height=Math.max(bounds.minHeight,Math.min(bounds.maxHeight,start.height+(south?dy:north?-dy:0)))
    return {x:west?start.x+start.width-width:start.x,y:north?start.y+start.height-height:start.y,width:width,height:height}
}
function shelfSizes(sizes,gap) {
    var x=0,height=0,positions=[]
    sizes.forEach(function(size){positions.push({x:x,y:0,width:size.width,height:size.height});x+=size.width+gap;height=Math.max(height,size.height)})
    return {positions:positions,width:Math.max(0,x-gap),height:height}
}
