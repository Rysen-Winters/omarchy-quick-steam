import QtQuick
import Quickshell
import Quickshell.Io
import "Strings.js" as Strings
import "Model.js" as Model

// Quick Steam's state, once per shell, so Steam is watched, the library read
// and each notification sent once however many bars (one per monitor) there
// are. Under Omarchy's own bar this is the plugin's service and every bar
// widget reads it. A replacement bar gives widgets no way to reach a service,
// so there the first widget runs an instance of its own and the others read
// that one (see BarWidget.qml). BarWidget.qml draws the icon and owns its
// panel; Panel.qml only displays. Three helpers in bin/ do the reading:
//
//   quick-steam-library   the whole library from local files (when a panel
//                         opens, and whenever a download starts or ends)
//   quick-steam-watch     the game being played, downloads, Workshop items and
//                         shaders: one process for the whole session that
//                         prints a line only when something changes
//   quick-steam-details   description, ProtonDB tier and missing cover art,
//                         the only network access, one request at a time
Item {
  id: root

  readonly property string moduleName: "io.github.rysen-winters.quick-steam"
  readonly property string pluginDir: decodeURIComponent(Qt.resolvedUrl(".").toString().replace(/^file:\/\//, "")).replace(/\/$/, "")

  // Injected by the shell: this plugin's own facade, enough to open and close
  // its panel from IPC. A widget-run instance gets the widget's entry facade.
  property var shell: null

  // Nothing runs until a widget uses this instance. The shell starts the
  // plugin's service under any bar, and under a replacement bar no widget can
  // reach it, so on its own it would only watch Steam twice and notify twice.
  property bool claimed: false

  onClaimedChanged: if (claimed) {
    watchProcess.running = true
    refreshLibrary()
  }

  // ---- Settings -----------------------------------------------------------------

  // The widget's entry in shell.json. The plugin has one entry, so every bar
  // widget pushes the same values; the settings page saves through a widget.
  property var settings: ({})

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  // "auto" follows the system language.
  readonly property string languageSetting: String(setting("language", "auto"))
  readonly property string lang: languageSetting === "en" || languageSetting === "es"
    ? languageSetting : Strings.language(Qt.locale().name)

  // The panel's sections. Activity or the game list is always on: with both
  // off (only possible by editing shell.json) the activity comes back. The
  // details belong to the list.
  readonly property bool showLibrary: setting("showLibrary", true) !== false
  readonly property bool showActivity: setting("showActivity", true) !== false || !showLibrary
  readonly property bool showDetails: showLibrary && setting("showDetails", true) !== false
  // Games hidden in Steam stay out of the list, as they do in Steam's library.
  readonly property bool showHidden: setting("showHidden", false) === true
  // Their covers were skipped while they were out of the list.
  onShowHiddenChanged: if (showHidden && claimed) refreshLibrary()

  // Descriptions come in the panel's language: a new one asks again (the
  // disk cache keeps one copy per language, so going back costs nothing).
  onLangChanged: {
    details = ({})
    jobs = jobs.filter(function(j) { return j.kind !== "details" })
  }

  // ---- Library ------------------------------------------------------------------

  property var library: ({ ok: false, loading: true, games: [], libraries: [], running: "" })
  property bool libraryPending: false

  function refreshLibrary() {
    if (libraryProcess.running) libraryPending = true
    else libraryProcess.running = true
  }

  function libraryLoaded(output) {
    var next
    try { next = JSON.parse(output) } catch (e) { return }
    next.loading = false
    library = next
    // Covers are only drawn by the game list.
    var missing = showLibrary ? (next.games || []).filter(function(g) { return !g.art && (showHidden || !g.hidden) }) : []
    missing.sort(function(a, b) { return (b.installed - a.installed) || (b.lastPlayed - a.lastPlayed) })
    for (var i = 0; i < Math.min(missing.length, 60); i++) requestCover(missing[i])
    if (runningId) requestHeader(game(runningId))
    announceFinishedDownloads()
    announceUninstalls()
  }

  function game(id) {
    var games = library.games || []
    for (var i = 0; i < games.length; i++) if (games[i].id === id) return games[i]
    return null
  }

  // A library by its index in libraryfolders.vdf, the one Steam's commands take.
  function libraryByFolder(folder) {
    var libs = library.libraries || []
    for (var i = 0; i < libs.length; i++) if (libs[i].folder === folder) return libs[i]
    return null
  }

  function coverFor(game) {
    if (!game) return ""
    return game.art || covers[game.id] || ""
  }

  Process {
    id: libraryProcess
    command: ["python3", "-I", root.pluginDir + "/bin/quick-steam-library"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.libraryLoaded(text)
    }
    onExited: if (root.libraryPending) {
      root.libraryPending = false
      Qt.callLater(root.refreshLibrary)
    }
  }

  // A panel opening wants fresh playtimes and free space, and a clock that
  // has not been ticking while nothing was timed.
  function panelOpened() {
    now = Date.now()
    refreshLibrary()
  }

  // ---- Activity -----------------------------------------------------------------

  property var activity: ({ downloads: [], shaders: null, queued: 0 })
  readonly property var downloads: activity.downloads || []
  readonly property var shaders: activity.shaders || null
  readonly property var mainDownload: {
    for (var i = 0; i < downloads.length; i++) if (downloads[i].status === "downloading") return downloads[i]
    return null
  }
  readonly property bool busy: mainDownload !== null || shaders !== null

  // The game being played, from the reaper process Steam starts it under;
  // library.running (registry.vdf) covers the moments before the next poll.
  readonly property var running: activity.running || null
  readonly property string runningId: running ? running.id : (library.running || "")
  readonly property string runningBanner: {
    if (!runningId) return ""
    var current = game(runningId)
    if (current && current.header) return "file://" + current.header
    return headers[runningId] || ""
  }

  // A game starting or stopping changes last played and playtime.
  onRunningIdChanged: {
    refreshLibrary()
    if (runningId) requestHeader(game(runningId))
  }

  // Downloads seen running, so their end can be noticed; finished ones wait
  // for the next library read to tell a completed install from a cancelled one.
  property var runningDownloads: ({})
  property var finishedDownloads: []

  // A shader run lasts from the moment processing shows up until it goes
  // quiet. It ends in a notification only when the queue is empty, Steam was
  // working in the background (a pre-launch pass is followed by the game
  // itself), and it took long enough to have been worth waiting for.
  property real shaderRunStartedAt: 0
  property bool shaderRunInBackground: false
  property var shaderRunApps: ({})

  function activityLoaded(output) {
    var next
    try { next = JSON.parse(output) } catch (e) { return }
    trackDownloads(next.downloads || [])
    trackShaders(next.shaders || null, next.queued || 0)
    activity = next
  }

  // A game's Workshop items download on their own, with the game's id.
  function downloadKey(download) {
    return download.kind === "workshop" ? "workshop:" + download.id : download.id
  }

  function trackDownloads(list) {
    var seen = {}
    var changed = false
    for (var i = 0; i < list.length; i++) {
      var key = downloadKey(list[i])
      seen[key] = list[i]
      if (!downloads.some(function(d) { return downloadKey(d) === key })) changed = true
    }
    var running = runningDownloads
    for (var id in running) {
      if (!seen[id]) {
        // A stopped Workshop job stays listed as paused, so one that is gone
        // finished; the library has nothing to confirm.
        if (running[id].kind === "workshop") announceWorkshop(running[id])
        else finishedDownloads = finishedDownloads.concat([running[id]])
        delete running[id]
        changed = true
      }
    }
    for (var j = 0; j < list.length; j++)
      if (list[j].status === "downloading") running[downloadKey(list[j])] = list[j]
    runningDownloads = running
    announceStartedInstalls(list)
    if (changed) refreshLibrary()
  }

  // Installs sent from the panel, until Steam lists the download (queued or
  // not): then a notification says it started, and where. One Steam never
  // gets to is forgotten after a few minutes.
  property var requestedInstalls: ({})

  function announceStartedInstalls(list) {
    var requested = requestedInstalls
    var changed = false
    for (var i = 0; i < list.length; i++) {
      var request = requested[list[i].id]
      if (!request || list[i].kind === "workshop") continue
      delete requested[list[i].id]
      changed = true
      if (Date.now() - request.at > 300000 || !setting("notifyDownloads", true)) continue
      notify(Strings.text(lang, "installStartedTitle"),
        Strings.text(lang, "installStartedBody", request.name || list[i].name, request.label))
    }
    if (changed) requestedInstalls = Object.assign({}, requested)
  }

  // Uninstalls sent from the panel. Nothing downloads, so the watcher has
  // nothing to say: the library is read again every two seconds until the
  // game shows as not installed. Steam takes a few seconds to start when it
  // was closed, so it gets half a minute. A game still there by then is most
  // likely one uninstalled while it downloaded: Steam cancels the download,
  // deletes the files and says it is done, but sometimes writes the manifest
  // back as a paused install, which it ignores until it restarts. That gets a
  // notification of its own.
  property var requestedUninstalls: ({})

  function announceUninstalls() {
    var requested = requestedUninstalls
    var changed = false
    for (var id in requested) {
      var current = game(id)
      if (current && current.installed) continue
      var request = requested[id]
      delete requested[id]
      changed = true
      if (!setting("notifyDownloads", true)) continue
      notify(Strings.text(lang, "uninstallDoneTitle"), request.size > 0
        ? Strings.text(lang, "uninstallDoneBody", request.name, Strings.size(lang, request.size), request.label)
        : Strings.text(lang, "uninstallDoneBodyNoSize", request.name, request.label))
    }
    if (changed) requestedUninstalls = Object.assign({}, requested)
  }

  Timer {
    interval: 2000
    repeat: true
    running: Object.keys(root.requestedUninstalls).length > 0
    onTriggered: {
      var requested = root.requestedUninstalls
      for (var id in requested) {
        if (++requested[id].tries <= 15) continue
        if (root.setting("notifyDownloads", true))
          root.notify(Strings.text(root.lang, "uninstallStuckTitle"), Strings.text(root.lang, "uninstallStuckBody", requested[id].name))
        delete requested[id]
      }
      root.requestedUninstalls = Object.assign({}, requested)
      root.refreshLibrary()
    }
  }

  function announceWorkshop(item) {
    if (setting("notifyDownloads", true))
      notify(Strings.text(lang, "workshopDoneTitle"), Strings.text(lang, "workshopDoneBody", item.name))
  }

  function announceFinishedDownloads() {
    if (finishedDownloads.length === 0) return
    var waiting = []
    for (var i = 0; i < finishedDownloads.length; i++) {
      var item = finishedDownloads[i]
      var current = game(item.id)
      // Gone from the library: the install was cancelled.
      if (!current || !current.installed) continue
      if (!Model.isReady(current) || (current.state & 2)) {
        // Steam is still committing; the next read will tell.
        waiting.push(item)
        continue
      }
      if (!setting("notifyDownloads", true)) continue
      var update = item.kind === "update"
      notify(Strings.text(lang, update ? "updateDoneTitle" : "downloadDoneTitle"),
        Strings.text(lang, update ? "updateDoneBody" : "downloadDoneBody", current.name))
    }
    finishedDownloads = waiting
  }

  function trackShaders(next, queued) {
    if (next) {
      if (!shaders) {
        shaderRunStartedAt = Date.now()
        shaderRunInBackground = false
        shaderRunApps = ({})
      }
      if (next.mode === "background") shaderRunInBackground = true
      if (next.app) {
        var apps = shaderRunApps
        apps[next.app] = true
        shaderRunApps = apps
      }
      return
    }
    if (!shaders) return
    var seconds = (Date.now() - shaderRunStartedAt) / 1000
    var count = Object.keys(shaderRunApps).length
    if (queued > 0 || !shaderRunInBackground || seconds < 60 || count === 0) return
    if (!setting("notifyShaders", true)) return
    notify(Strings.text(lang, "shadersDoneTitle"),
      Strings.text(lang, "shadersDoneBody", Strings.games(lang, count), Strings.duration(lang, seconds)))
  }

  function notify(title, body) {
    Quickshell.execDetached(["notify-send", "--app-name=Steam", "--icon=steam", title, body])
  }

  // The game's own download; its Workshop items do not make it unplayable.
  function downloadFor(id) {
    for (var i = 0; i < downloads.length; i++)
      if (downloads[i].id === id && downloads[i].kind !== "workshop") return downloads[i]
    return null
  }

  // Started once and kept running: it looks at Steam's files every 2 s on its
  // own and writes a line only when something changed, so a quiet Steam costs
  // the shell nothing. If it ever exits, it comes back after a few seconds.
  Process {
    id: watchProcess
    command: ["python3", "-I", root.pluginDir + "/bin/quick-steam-watch"]
    stdout: SplitParser {
      onRead: function(line) { root.activityLoaded(line) }
    }
    onExited: watchRestart.restart()
  }

  Timer {
    id: watchRestart
    interval: 5000
    onTriggered: if (root.claimed) watchProcess.running = true
  }

  // The watcher sends when things started; durations come from this clock,
  // which only ticks while there is a session or a shader job to time.
  property real now: Date.now()

  function elapsedSince(startedAt) {
    return startedAt > 0 ? Math.max(0, Math.floor(now / 1000 - startedAt)) : 0
  }

  Timer {
    interval: 30000
    repeat: true
    running: root.running !== null || root.shaders !== null
    triggeredOnStart: true
    onTriggered: root.now = Date.now()
  }

  // ---- Details and covers: the network side, one request at a time ----------------

  property var details: ({})
  property var covers: ({})
  property var headers: ({})
  property var jobs: []
  property var currentJob: null

  function validId(id) {
    return /^[0-9]{1,10}$/.test(String(id))
  }

  // Description and ProtonDB are only shown by the details.
  function requestDetails(id) {
    if (!showDetails || !validId(id) || details[id] !== undefined) return
    if (jobs.some(function(j) { return j.kind === "details" && j.id === id })) return
    if (currentJob && currentJob.kind === "details" && currentJob.id === id) return
    // The game on screen goes ahead of any cover prefetching.
    jobs = [{ kind: "details", id: id }].concat(jobs)
    runNextJob()
  }

  function requestCover(game) {
    if (!game || !validId(game.id) || game.art || covers[game.id] !== undefined) return
    if (jobs.some(function(j) { return j.kind === "cover" && j.id === game.id })) return
    jobs = jobs.concat([{ kind: "cover", id: game.id, asset: game.asset || "" }])
    runNextJob()
  }

  function requestHeader(game) {
    if (!game || !validId(game.id) || game.header || headers[game.id] !== undefined) return
    if (jobs.some(function(j) { return j.kind === "header" && j.id === game.id })) return
    jobs = [{ kind: "header", id: game.id, asset: game.headerAsset || "" }].concat(jobs)
    runNextJob()
  }

  function runNextJob() {
    if (detailsProcess.running || jobs.length === 0) return
    currentJob = jobs[0]
    jobs = jobs.slice(1)
    var script = root.pluginDir + "/bin/quick-steam-details"
    detailsProcess.command = currentJob.kind === "details"
      ? ["python3", "-I", script, currentJob.id, "--lang", root.lang]
      : ["python3", "-I", script, currentJob.id, currentJob.kind === "header" ? "--header" : "--cover", currentJob.asset]
    detailsProcess.running = true
  }

  function jobFinished(output) {
    var job = currentJob
    currentJob = null
    var result = null
    try { result = JSON.parse(output) } catch (e) {}
    if (job && job.kind === "details") {
      var nextDetails = Object.assign({}, details)
      nextDetails[job.id] = result && !result.error ? result : { description: "", protondb: null }
      details = nextDetails
    } else if (job && job.kind === "header") {
      var nextHeaders = Object.assign({}, headers)
      nextHeaders[job.id] = result && result.cover ? "file://" + result.cover : ""
      headers = nextHeaders
    } else if (job) {
      var nextCovers = Object.assign({}, covers)
      nextCovers[job.id] = result && result.cover ? "file://" + result.cover : ""
      covers = nextCovers
    }
    Qt.callLater(runNextJob)
  }

  Process {
    id: detailsProcess
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.jobFinished(text)
    }
  }

  // ---- Steam links ---------------------------------------------------------------

  // Every steam:// link goes through here, and the first one may start Steam.
  // Launched straight from the shell, Steam and every game it runs would land
  // in the compositor's cgroup (wayland-wm@hyprland.desktop.service): their
  // memory would count as the compositor's, and systemd-oomd, which watches
  // app.slice, would never see them. uwsm-app gives them their own scope in
  // app-graphical.slice, the way Omarchy's launchers do; without uwsm the link
  // goes to xdg-open directly. The url travels as an argument, never as code.
  function openSteam(url) {
    Quickshell.execDetached(["sh", "-c",
      'if command -v uwsm-app >/dev/null; then exec uwsm-app -- xdg-open "$1"; else exec xdg-open "$1"; fi',
      "quick-steam", url])
  }

  // Installs and uninstalls the panel has already asked about go to Steam as
  // console commands on the steam launcher's command line. The launcher hands
  // them to the running client through ~/.steam/steam.pipe, which only this
  // user can write to, or starts Steam with them, -silent keeping its window
  // closed. Unlike steam://install and steam://uninstall, they ask nothing.
  // Steam does bring its window forward when it was already running. Through
  // uwsm-app for the same reason as openSteam: this may be what starts Steam.
  readonly property bool directActions: library.launcher === true

  function runSteam(args) {
    Quickshell.execDetached(["sh", "-c",
      'if command -v uwsm-app >/dev/null; then exec uwsm-app -- steam -silent "$@"; else exec steam -silent "$@"; fi',
      "quick-steam"].concat(args))
  }

  function play(id) {
    if (!validId(id)) return false
    openSteam("steam://rungameid/" + id)
    return true
  }

  // The library the panel installed to last, offered first next time.
  property int lastFolder: -1

  // folder is the library's index in libraryfolders.vdf, picked in the panel.
  // Without it, or without the launcher, Steam's own dialog asks where.
  function install(id, folder) {
    if (!validId(id)) return
    var target = /^[0-9]{1,3}$/.test(String(folder)) ? libraryByFolder(Number(folder)) : null
    if (!directActions || !target) {
      openSteam("steam://install/" + id)
      return
    }
    var current = game(id)
    var requested = Object.assign({}, requestedInstalls)
    requested[id] = { name: current ? current.name : "", label: target.label, at: Date.now() }
    requestedInstalls = requested
    lastFolder = target.folder
    runSteam(["+app_install", id, String(target.folder)])
  }

  // confirmed: the panel asked first. Otherwise Steam asks itself.
  function uninstall(id, confirmed) {
    if (!validId(id)) return
    if (!directActions || confirmed !== true) {
      openSteam("steam://uninstall/" + id)
      return
    }
    var current = game(id)
    var libs = library.libraries || []
    var requested = Object.assign({}, requestedUninstalls)
    requested[id] = {
      name: current ? current.name : "",
      size: current ? current.size : 0,
      label: current && current.library >= 0 && current.library < libs.length ? libs[current.library].label : "Steam",
      tries: 0
    }
    requestedUninstalls = requested
    runSteam(["+app_uninstall", id])
  }

  function openStore(id) {
    if (validId(id)) openSteam("steam://store/" + id)
  }

  function bigPicture() {
    openSteam("steam://open/bigpicture")
  }

  function openLibrary() {
    openSteam("steam://open/games")
  }

  // Steam has no URL that resumes a download; its Downloads page does.
  function openDownloads() {
    openSteam("steam://open/downloads")
  }

  // For a keybinding: quickshell ipc -p "$OMARCHY_PATH/shell" call quick-steam toggle
  // One handler for the whole shell, on the instance in use; the shell picks
  // which bar's panel opens.
  IpcHandler {
    // An idle instance registers nothing, so it cannot take the name from the
    // one in use.
    enabled: root.claimed
    target: root.claimed ? "quick-steam" : ""

    function toggle(): void { if (root.shell) root.shell.toggle(root.moduleName) }
    function open(): void { if (root.shell) root.shell.summon(root.moduleName) }
    function close(): void { if (root.shell) root.shell.hide(root.moduleName) }
    function bigPicture(): void {
      root.bigPicture()
      if (root.shell) root.shell.hide(root.moduleName)
    }
  }
}
