.pragma library

// Filtering and ordering of the library list, kept out of the QML so the
// panel only binds to results.

function fold(value) {
  var lowered = String(value || "").toLowerCase()
  try {
    return lowered.normalize("NFD").replace(/[̀-ͯ]/g, "")
  } catch (e) {
    return lowered
  }
}

// Games for one tab, matching every word of the query, in the chosen order.
// The game Steam reports as running always comes first.
function visibleGames(games, installedTab, query, sort, running) {
  var terms = fold(query).split(/\s+/).filter(function(t) { return t !== "" })
  // Each name is folded once here, not on every comparison of the sort.
  var entries = (games || []).filter(function(game) {
    return game.installed === installedTab
  }).map(function(game) {
    return { game: game, name: fold(game.name) }
  }).filter(function(entry) {
    for (var i = 0; i < terms.length; i++)
      if (entry.name.indexOf(terms[i]) < 0) return false
    return true
  })
  entries.sort(function(x, y) {
    var a = x.game, b = y.game
    if (running) {
      if (a.id === running && b.id !== running) return -1
      if (b.id === running && a.id !== running) return 1
    }
    if (sort === "size" && installedTab && b.size !== a.size) return b.size - a.size
    if (sort === "recent" && b.lastPlayed !== a.lastPlayed) return b.lastPlayed - a.lastPlayed
    return x.name < y.name ? -1 : x.name > y.name ? 1 : 0
  })
  return entries.map(function(entry) { return entry.game })
}

function count(games, installedTab) {
  var n = 0
  for (var i = 0; i < (games || []).length; i++)
    if (games[i].installed === installedTab) n++
  return n
}

// StateFlags: 4 = fully installed, 2 = update required, 1024 = update started.
function isReady(game) {
  return !!game && game.installed && (game.state & 4) !== 0
}

// Steam's own progress counts downloaded bytes; staging (writing to disk) only
// matters when there is nothing left to fetch.
function downloadPercent(download) {
  var done = download.total > 0 ? download.done : download.staged
  var total = download.total > 0 ? download.total : download.stageTotal
  if (!total || total <= 0) return 0
  return Math.max(0, Math.min(100, 100 * done / total))
}

function downloadRemaining(download) {
  return download.total > 0 ? Math.max(0, download.total - download.done) : Math.max(0, download.stageTotal - download.staged)
}

function initials(name) {
  var words = String(name || "").replace(/[^A-Za-z0-9 ]/g, " ").split(/\s+/).filter(function(w) { return w !== "" })
  return words.slice(0, 2).map(function(w) { return w.charAt(0).toUpperCase() }).join("")
}
