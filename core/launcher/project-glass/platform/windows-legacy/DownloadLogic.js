.pragma library

var components = { Vanilla: "net.minecraft", Fabric: "net.fabricmc.fabric-loader", Forge: "net.minecraftforge", NeoForge: "net.neoforged", Quilt: "org.quiltmc.quilt-loader" }
var projectTypes = { Mods: "mod", Shaders: "shader", "Resource packs": "resourcepack", Modpacks: "modpack" }
function array(value) { if (!Array.isArray(value)) throw new Error("Unexpected response format"); return value }
function indexVersions(data) { return array(data && data.versions) }
function stamp(value) { var n = Date.parse(value || ""); return isNaN(n) ? 0 : n }
function date(value) { return value ? value.slice(0, 10) : "Date unavailable" }
function newest(a, b) { return stamp(b.date) - stamp(a.date) || b.label.localeCompare(a.label) }
function compareGame(a, b) {
    var x = a.match(/\d+|[^\d]+/g) || [], y = b.match(/\d+|[^\d]+/g) || []
    for (var i = 0; i < Math.min(x.length, y.length); i++) {
        var n = /^\d+$/.test(x[i]) && /^\d+$/.test(y[i]) ? Number(x[i]) - Number(y[i]) : x[i].localeCompare(y[i])
        if (n) return n
    }
    return x.length - y.length
}
function minecraftCatalogue(data, query, sort) {
    var q = query.trim().toLowerCase()
    var rows = indexVersions(data).filter(function(v) { return v.type === "release" && v.version && v.version.toLowerCase().indexOf(q) !== -1 }).map(function(v) {
        return { category: "Versions", name: "Minecraft " + v.version, version: v.version, badge: v.version, detail: "Java Edition · " + date(v.releaseTime), date: v.releaseTime, icon: "" }
    })
    rows.sort(function(a, b) { return sort === "Name A–Z" ? a.name.localeCompare(b.name) : stamp(b.date) - stamp(a.date) })
    return rows
}
function searchUrl(base, category, query, sort, offset, loader) {
    if (!projectTypes[category]) throw new Error("Unknown project category")
    var facets = [["project_type:" + projectTypes[category]]]
    if (category === "Mods" && loader && loader !== "All loaders") facets.push(["categories:" + loader.toLowerCase()])
    var index = sort === "Newest" ? "newest" : sort === "Updated" ? "updated" : "relevance"
    return base + "/search?query=" + encodeURIComponent(query) + "&facets=" + encodeURIComponent(JSON.stringify(facets)) + "&index=" + index + "&limit=20&offset=" + offset
}
function projects(data, category) {
    return array(data && data.hits).filter(function(p) { return p.project_id && p.title }).map(function(p) {
        return { category: category, projectId: p.project_id, name: p.title, detail: p.description || "", badge: category === "Mods" ? "MOD" : "PACK", icon: p.icon_url || "" }
    })
}
function requirementsMatch(row, game) {
    var reqs = row.requires || []
    for (var i = 0; i < reqs.length; i++) {
        if (reqs[i].uid === "net.minecraft" && reqs[i].equals && reqs[i].equals !== game) return false
    }
    return true
}
function loaderRows(data, loader, game) {
    return indexVersions(data).filter(function(v) {
        if (!v.version || !requirementsMatch(v, game)) return false
        // Forge and NeoForge must explicitly identify the exact Minecraft version.
        return loader === "Fabric" || loader === "Quilt" || (v.requires || []).some(function(r) { return r.uid === "net.minecraft" && r.equals === game })
    }).map(function(v) {
        return { id: loader + ":" + v.version, label: v.version, date: v.releaseTime || "", detail: date(v.releaseTime) + (v.recommended ? " · Recommended" : ""), group: loader + " · Minecraft " + game, gameVersion: game, eligible: true }
    }).sort(newest)
}
function projectRows(data, target, loader, category) {
    var wanted = loader.toLowerCase()
    return array(data).filter(function(v) { return v.id && Array.isArray(v.game_versions) && v.game_versions.length }).map(function(v) {
        var games = v.game_versions.slice().sort(function(a, b) { return -compareGame(a, b) })
        var sameGame = !!target && games.indexOf(target) >= 0
        var sameLoader = category !== "Mods" || (v.loaders || []).indexOf(wanted) >= 0
        var game = sameGame ? target : games[0]
        var rank = sameGame ? (sameLoader ? 0 : 1) : 2
        var group = rank === 0 ? "Current instance · Minecraft " + target : rank === 1 ? "Minecraft " + target + " · Different loader" : "Minecraft " + game
        return { id: v.id, label: v.name || v.version_number || v.id, date: v.date_published || "", gameVersion: game, group: group, rank: rank, eligible: sameGame && sameLoader,
                 detail: date(v.date_published) + " · " + (v.loaders || []).join(", ") + " · " + (v.version_type || "release"),
                 versionNumber: v.version_number || "", files: v.files || [], dependencies: v.dependencies || [], gameVersions: v.game_versions, loaders: v.loaders || [] }
    }).sort(function(a, b) { return a.rank - b.rank || (a.rank === 2 ? -compareGame(a.gameVersion, b.gameVersion) : 0) || newest(a, b) })
}
