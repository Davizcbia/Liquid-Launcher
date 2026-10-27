import QtQuick
import "DownloadLogic.js" as Logic

QtObject {
    id: api
    property string metadataBase: "https://meta.prismlauncher.org/v1"
    property string modrinthBase: "https://api.modrinth.com/v2"
    property int requestTimeout: 20000
    property var catalogue: []
    property int total: 0
    property int nextOffset: 0
    property bool hasMore: false
    property bool catalogueBusy: false
    property string catalogueError: ""
    property var releases: []
    property bool releaseBusy: false
    property string releaseError: ""
    property bool vanillaValid: false
    property var requests: ({})
    property var cache: ({})
    property string catalogueKey: ""
    property var catalogueArgs: null
    property var releaseArgs: null
    // Request identities isolate catalogues, project pages, loader changes, and retries.
    function cancel(channel) {
        var prior = requests[channel]
        requests[channel] = null
        if (prior) { prior.xhr.onreadystatechange = null; prior.xhr.abort() }
    }
    function request(channel, url, done) {
        cancel(channel)
        var cached = cache[url]
        if (cached && Date.now() - cached.time < 120000) { done(null, cached.data); return }
        var xhr = new XMLHttpRequest()
        var state = { xhr: xhr, deadline: Date.now() + requestTimeout, fail: done }
        requests[channel] = state
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE || requests[channel] !== state) return
            requests[channel] = null
            if (xhr.status < 200 || xhr.status >= 300) {
                var reason = xhr.status === 429 ? "Too many requests. Wait a moment and retry." : xhr.status ? "HTTP " + xhr.status + " · Please retry." : "Network unavailable · Check your connection and retry."
                done(reason, null); return
            }
            var data
            try { data = JSON.parse(xhr.responseText) }
            catch (e) { done("The server returned invalid JSON.", null); return }
            var now = Date.now()
            Object.keys(cache).forEach(function(key) { if (now - cache[key].time >= 120000) delete cache[key] })
            var keys = Object.keys(cache).sort(function(a, b) { return cache[a].time - cache[b].time })
            while (keys.length >= 12) delete cache[keys.shift()]
            cache[url] = { time: now, data: data }
            done(null, data)
        }
        try {
            xhr.open("GET", url)
            xhr.setRequestHeader("User-Agent", "ProjectGlassPrototype/0.9.30")
            xhr.setRequestHeader("Accept", "application/json")
            xhr.send()
        } catch (e) { requests[channel] = null; done("Could not start request: " + e.message, null) }
    }
    property Timer watchdog: Timer {
        interval: 250; repeat: true
        running: api.catalogueBusy || api.releaseBusy
        onTriggered: {
            for (var channel in api.requests) {
                var state = api.requests[channel]
                if (state && Date.now() >= state.deadline) {
                    api.cancel(channel)
                    state.fail("Request timed out · Please retry.", null)
                }
            }
        }
    }
    function invalidateCatalogue() {
        cancel("catalogue"); catalogueBusy = false; catalogue = []; catalogueError = ""; hasMore = false; total = 0
    }
    function loadCatalogue(category, query, sort, append, loader, provider) {
        var source = provider || "Modrinth"
        var key = source + "|" + category + "|" + query + "|" + sort + "|" + (category === "Mods" ? loader || "All loaders" : "")
        var offset = append && catalogueKey === key ? nextOffset : 0
        catalogueArgs = { category: category, query: query, sort: sort, loader: loader || "All loaders", provider: source }
        catalogueKey = key
        if (!append) { catalogue = []; total = 0; hasMore = false; nextOffset = 0 }
        catalogueBusy = true; catalogueError = ""
        if (source === "CurseForge" && category !== "Versions") {
            catalogueBusy = false
            catalogueError = "CurseForge search requires an API key. Select Modrinth to browse projects."
            return
        }
        var url = category === "Versions" ? metadataBase + "/net.minecraft/index.json" : Logic.searchUrl(modrinthBase, category, query, sort, offset, loader)
        request("catalogue", url, function(error, data) {
            catalogueBusy = false
            if (error) { catalogueError = error; return }
            try {
                var rows = category === "Versions" ? Logic.minecraftCatalogue(data, query, sort) : Logic.projects(data, category)
                catalogue = append ? catalogue.concat(rows) : rows
                total = category === "Versions" ? rows.length : Number(data.total_hits || 0)
                nextOffset = offset + (category === "Versions" ? rows.length : data.hits.length)
                hasMore = category !== "Versions" && data.hits.length > 0 && nextOffset < total
            } catch (e) { catalogueError = "Could not read catalogue: " + e.message }
        })
    }
    function retryCatalogue() {
        if (catalogueArgs) loadCatalogue(catalogueArgs.category, catalogueArgs.query, catalogueArgs.sort, false, catalogueArgs.loader, catalogueArgs.provider)
    }
    function closeReleases() {
        cancel("releases"); releases = []; releaseBusy = false; releaseError = ""; vanillaValid = false
    }
    function loadReleases(entry, loader, targetGame, targetLoader) {
        closeReleases()
        releaseArgs = { entry: entry, loader: loader, game: targetGame, targetLoader: targetLoader }
        if (!entry) return
        releaseBusy = true
        var game = entry.category === "Versions"
        var uid = Logic.components[loader]
        var url = game ? metadataBase + "/" + uid + "/index.json" : modrinthBase + "/project/" + encodeURIComponent(entry.projectId) + "/version"
        // First verify that Minecraft / intermediary metadata contains the requested game.
        function getRows() {
            request("releases", url, function(error, data) {
                releaseBusy = false
                if (error) { releaseError = error; return }
                try {
                    if (game && loader === "Vanilla") {
                        vanillaValid = Logic.indexVersions(data).some(function(v) { return v.version === entry.version })
                        if (!vanillaValid) releaseError = "This Minecraft version is not listed by the provider."
                    } else releases = game ? Logic.loaderRows(data, loader, entry.version) : Logic.projectRows(data, targetGame, targetLoader, entry.category)
                } catch (e) { releaseError = "Could not read versions: " + e.message }
            })
        }
        if (game && (loader === "Fabric" || loader === "Quilt")) {
            request("releases", metadataBase + "/net.fabricmc.intermediary/index.json", function(error, data) {
                if (error) { releaseBusy = false; releaseError = error; return }
                try {
                    if (!Logic.indexVersions(data).some(function(v) { return v.version === entry.version })) { releaseBusy = false; return }
                } catch (e) { releaseBusy = false; releaseError = "Could not read intermediary metadata."; return }
                getRows()
            })
        } else getRows()
    }
    function retryReleases() {
        if (releaseArgs) loadReleases(releaseArgs.entry, releaseArgs.loader, releaseArgs.game, releaseArgs.targetLoader)
    }
    Component.onDestruction: { cancel("catalogue"); cancel("releases") }
}
