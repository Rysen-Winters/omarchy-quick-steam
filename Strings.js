.pragma library

// UI text in English and Spanish, picked in the settings or from the system
// locale, plus the formatting helpers that depend on the language.

var table = {
  en: {
    title: "Quick Steam",
    search: "Search games  ·  /",
    // The key hints line is put together from these, depending on what is shown.
    hintGame: "P play · I install · U uninstall · S store",
    hintLibrary: "L library",
    hintBigPicture: "B Big Picture",
    hintSort: "F sort",
    hintTab: "Tab list",
    hintSearch: "/ search",
    hintSettings: "C settings",
    installed: "Installed",
    notInstalled: "Not installed",
    sortRecent: "Recent",
    sortName: "Name",
    sortSize: "Size",
    library: "Library",
    bigPicture: "Big Picture",
    play: "Play",
    install: "Install",
    uninstall: "Uninstall",
    store: "Store",
    openDownloads: "Open downloads",
    resumeInSteam: "Resume in Steam",
    playing: "Playing now",
    installing: "Installing",
    noResults: "No games match.",
    noSteam: "Steam was not found.",
    loading: "Reading the library…",
    lastPlayed: "Played %1",
    neverPlayed: "Never played",
    playtime: "%1 played",
    today: "today",
    yesterday: "yesterday",
    daysAgo: "%1 days ago",
    monthsAgo: "%1 months ago",
    monthAgo: "a month ago",
    yearsAgo: "%1 years ago",
    yearAgo: "a year ago",
    hours: "%1 h",
    minutes: "%1 min",
    hoursMinutes: "%1 h %2 min",
    lessThanMinute: "less than a minute",
    nativeLinux: "Native Linux",
    reviews: "%1% positive",
    deck3: "Deck Verified",
    deck2: "Deck Playable",
    deck1: "Deck Unsupported",
    hiddenBadge: "Hidden",
    protondb: "ProtonDB %1",
    protondbReports: "%1 reports",
    noDescription: "No description available.",
    free: "%1 free of %2",
    freeShort: "%1 free",
    onLibrary: "%1 on %2",
    // Activity
    downloading: "Downloading",
    updating: "Updating",
    queued: "Queued",
    paused: "Paused",
    workshopDownloading: "Downloading from the Workshop",
    workshopPaused: "Workshop paused",
    workshopItems: "%1 items",
    workshopItem: "1 item",
    left: "%1 left",
    of: "%1 of %2",
    compiling: "Compiling shaders",
    finishing: "Finishing up",
    starting: "Starting",
    background: "in the background",
    beforeLaunch: "before the game launches",
    shaderQueue: "%1 more queued",
    running: "running for %1",
    // Notifications
    downloadDoneTitle: "Ready to play",
    downloadDoneBody: "%1 finished downloading.",
    updateDoneTitle: "Update finished",
    updateDoneBody: "%1 is up to date.",
    workshopDoneTitle: "Workshop ready",
    workshopDoneBody: "%1 finished downloading its Workshop items.",
    shadersDoneTitle: "Steam shaders ready",
    shadersDoneBody: "Processed %1 in %2.",
    games: "%1 games",
    game: "1 game",
    // Tooltip
    tooltipIdle: "Quick Steam",
    tooltipPlaying: "Playing %1 · %2",
    tooltipDownload: "%1 · %2",
    tooltipWorkshop: "%1 · Workshop · %2",
    tooltipShaders: "Shaders: %1 · %2",
    playingFor: "Playing now · %1",
    // Settings
    settings: "Settings",
    language: "Language",
    languageAuto: "Automatic (system)",
    sections: "Sections",
    sectionActivity: "Activity",
    sectionActivityHelp: "Downloads, updates, Workshop items and shader pre-caching in progress.",
    sectionLibrary: "Game list",
    sectionLibraryHelp: "Installed and not installed games, with search.",
    sectionDetails: "Game details",
    sectionDetailsHelp: "Cover, ProtonDB, Proton version and store description of the selected game.",
    settingHidden: "Hidden games",
    settingHiddenHelp: "The games you hid in Steam, marked as hidden.",
    needsList: "Needs the game list.",
    atLeastOne: "Activity or the game list has to stay on.",
    barAndNotices: "Bar and notifications",
    settingProgress: "Progress in the bar",
    settingProgressHelp: "Percentage and a line under the icon while Steam downloads or compiles shaders.",
    settingNotifyDownloads: "Notify finished downloads",
    settingNotifyDownloadsHelp: "When a game finishes installing or updating, or its Workshop items finish downloading.",
    settingNotifyShaders: "Notify finished shaders",
    settingNotifyShadersHelp: "When Steam empties its shader queue after more than a minute in the background.",
    settingsHints: "C or Esc goes back · Tab moves between options · Space changes",
    nothingHappening: "Steam is not downloading or compiling shaders."
  },
  es: {
    title: "Quick Steam",
    search: "Buscar juegos  ·  /",
    hintGame: "P jugar · I instalar · U desinstalar · S tienda",
    hintLibrary: "L biblioteca",
    hintBigPicture: "B Big Picture",
    hintSort: "F orden",
    hintTab: "Tab lista",
    hintSearch: "/ buscar",
    hintSettings: "C ajustes",
    installed: "Instalados",
    notInstalled: "No instalados",
    sortRecent: "Recientes",
    sortName: "Nombre",
    sortSize: "Tamaño",
    library: "Biblioteca",
    bigPicture: "Big Picture",
    play: "Jugar",
    install: "Instalar",
    uninstall: "Desinstalar",
    store: "Tienda",
    openDownloads: "Ver descargas",
    resumeInSteam: "Reanudar en Steam",
    playing: "Jugando ahora",
    installing: "Instalando",
    noResults: "Ningún juego coincide.",
    noSteam: "No se encontró Steam.",
    loading: "Leyendo la biblioteca…",
    lastPlayed: "Jugado %1",
    neverPlayed: "Nunca jugado",
    playtime: "%1 jugadas",
    today: "hoy",
    yesterday: "ayer",
    daysAgo: "hace %1 días",
    monthsAgo: "hace %1 meses",
    monthAgo: "hace un mes",
    yearsAgo: "hace %1 años",
    yearAgo: "hace un año",
    hours: "%1 h",
    minutes: "%1 min",
    hoursMinutes: "%1 h %2 min",
    lessThanMinute: "menos de un minuto",
    nativeLinux: "Nativo de Linux",
    reviews: "%1% positivas",
    deck3: "Verificado en Deck",
    deck2: "Jugable en Deck",
    deck1: "No compatible con Deck",
    hiddenBadge: "Oculto",
    protondb: "ProtonDB %1",
    protondbReports: "%1 reportes",
    noDescription: "No hay descripción disponible.",
    free: "%1 libres de %2",
    freeShort: "%1 libres",
    onLibrary: "%1 en %2",
    downloading: "Descargando",
    updating: "Actualizando",
    queued: "En cola",
    paused: "En pausa",
    workshopDownloading: "Descargando del Workshop",
    workshopPaused: "Workshop en pausa",
    workshopItems: "%1 elementos",
    workshopItem: "1 elemento",
    left: "faltan %1",
    of: "%1 de %2",
    compiling: "Compilando shaders",
    finishing: "Terminando",
    starting: "Empezando",
    background: "en segundo plano",
    beforeLaunch: "antes de abrir el juego",
    shaderQueue: "%1 más en cola",
    running: "lleva %1",
    downloadDoneTitle: "Listo para jugar",
    downloadDoneBody: "%1 terminó de descargarse.",
    updateDoneTitle: "Actualización terminada",
    updateDoneBody: "%1 está al día.",
    workshopDoneTitle: "Workshop listo",
    workshopDoneBody: "%1 terminó de descargar el contenido del Workshop.",
    shadersDoneTitle: "Shaders de Steam listos",
    shadersDoneBody: "Procesó %1 en %2.",
    games: "%1 juegos",
    game: "1 juego",
    tooltipIdle: "Quick Steam",
    tooltipPlaying: "Jugando %1 · %2",
    tooltipDownload: "%1 · %2",
    tooltipWorkshop: "%1 · Workshop · %2",
    tooltipShaders: "Shaders: %1 · %2",
    playingFor: "Jugando ahora · %1",
    settings: "Ajustes",
    language: "Idioma",
    languageAuto: "Automático (sistema)",
    sections: "Secciones",
    sectionActivity: "Actividad",
    sectionActivityHelp: "Descargas, actualizaciones, contenido del Workshop y shaders en curso.",
    sectionLibrary: "Lista de juegos",
    sectionLibraryHelp: "Juegos instalados y no instalados, con buscador.",
    sectionDetails: "Detalle del juego",
    sectionDetailsHelp: "Portada, ProtonDB, versión de Proton y descripción de la tienda del juego elegido.",
    settingHidden: "Juegos ocultos",
    settingHiddenHelp: "Los juegos que ocultaste en Steam, marcados como ocultos.",
    needsList: "Necesita la lista de juegos.",
    atLeastOne: "Tiene que quedar prendida la actividad o la lista de juegos.",
    barAndNotices: "Barra y avisos",
    settingProgress: "Progreso en la barra",
    settingProgressHelp: "Porcentaje y una línea bajo el ícono mientras Steam descarga o compila shaders.",
    settingNotifyDownloads: "Avisar descargas terminadas",
    settingNotifyDownloadsHelp: "Cuando un juego termina de instalarse o actualizarse, o de descargar su contenido del Workshop.",
    settingNotifyShaders: "Avisar shaders terminados",
    settingNotifyShadersHelp: "Cuando Steam vacía su cola de shaders después de más de un minuto en segundo plano.",
    settingsHints: "C o Esc vuelve · Tab recorre las opciones · Espacio cambia",
    nothingHappening: "Steam no está descargando ni compilando shaders."
  }
}

// Steam's genre ids, as appinfo.vdf stores them.
var genres = {
  en: { 1: "Action", 2: "Strategy", 3: "RPG", 4: "Casual", 9: "Racing", 18: "Sports", 23: "Indie",
        25: "Adventure", 28: "Simulation", 29: "Massively Multiplayer", 37: "Free to Play",
        70: "Early Access", 73: "Violent", 74: "Gore", 57: "Utilities" },
  es: { 1: "Acción", 2: "Estrategia", 3: "Rol", 4: "Casual", 9: "Carreras", 18: "Deportes", 23: "Indie",
        25: "Aventura", 28: "Simulación", 29: "Multijugador masivo", 37: "Gratuito",
        70: "Acceso anticipado", 73: "Violento", 74: "Gore", 57: "Utilidades" }
}

var tiers = {
  en: { platinum: "Platinum", gold: "Gold", silver: "Silver", bronze: "Bronze", borked: "Borked", pending: "Pending", native: "Native" },
  es: { platinum: "Platino", gold: "Oro", silver: "Plata", bronze: "Bronce", borked: "Roto", pending: "Pendiente", native: "Nativo" }
}

function language(localeName) {
  var code = String(localeName || "").split(/[_-]/)[0]
  return table[code] ? code : "en"
}

function text(lang, key) {
  var value = (table[lang] || table.en)[key] || table.en[key] || key
  for (var i = 2; i < arguments.length; i++)
    value = value.replace("%" + (i - 1), arguments[i])
  return value
}

function genreNames(lang, ids) {
  var names = genres[lang] || genres.en
  var out = []
  for (var i = 0; i < (ids || []).length; i++)
    if (names[ids[i]]) out.push(names[ids[i]])
  return out
}

function tierName(lang, tier) {
  var names = tiers[lang] || tiers.en
  return names[tier] || (tier ? tier.charAt(0).toUpperCase() + tier.slice(1) : "")
}

function number(lang, value, decimals) {
  var fixed = Number(value).toFixed(decimals)
  return lang === "es" ? fixed.replace(".", ",") : fixed
}

function size(lang, bytes) {
  if (!bytes || bytes <= 0) return "0 B"
  var units = ["B", "KB", "MB", "GB", "TB"]
  var i = 0
  var value = bytes
  while (value >= 1000 && i < units.length - 1) { value /= 1000; i++ }
  return number(lang, value, value >= 100 || i === 0 ? 0 : 1) + " " + units[i]
}

function rate(lang, bytesPerSecond) {
  return size(lang, bytesPerSecond) + "/s"
}

function duration(lang, seconds) {
  var minutes = Math.floor(seconds / 60)
  if (minutes < 1) return text(lang, "lessThanMinute")
  if (minutes < 60) return text(lang, "minutes", minutes)
  var hours = Math.floor(minutes / 60)
  return minutes % 60 === 0 || hours >= 10 ? text(lang, "hours", hours) : text(lang, "hoursMinutes", hours, minutes % 60)
}

function playtime(lang, minutes) {
  if (!minutes) return ""
  return minutes < 60 ? text(lang, "minutes", minutes) : text(lang, "hours", Math.round(minutes / 60))
}

function relative(lang, epochSeconds) {
  if (!epochSeconds) return ""
  var now = new Date()
  var then = new Date(epochSeconds * 1000)
  var startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  var days = Math.floor((startOfToday - new Date(then.getFullYear(), then.getMonth(), then.getDate()).getTime()) / 86400000)
  if (days <= 0) return text(lang, "today")
  if (days === 1) return text(lang, "yesterday")
  if (days < 31) return text(lang, "daysAgo", days)
  var months = Math.floor(days / 30.4)
  if (months < 12) return months === 1 ? text(lang, "monthAgo") : text(lang, "monthsAgo", months)
  var years = Math.floor(days / 365)
  return years === 1 ? text(lang, "yearAgo") : text(lang, "yearsAgo", years)
}

function toolName(lang, tool, linux) {
  if (!tool) return linux ? text(lang, "nativeLinux") : ""
  var match = /^proton_(.+)$/i.exec(tool)
  if (!match) return tool
  var version = match[1].replace(/_/g, " ")
  return "Proton " + version.charAt(0).toUpperCase() + version.slice(1)
}

// Whole numbers, except below 10 % where a stalled-looking 0 % would hide progress.
function percent(lang, value) {
  return value > 0 && value < 10 ? number(lang, Math.floor(value * 10) / 10, 1) + "%" : Math.floor(value) + "%"
}

function games(lang, count) {
  return count === 1 ? text(lang, "game") : text(lang, "games", count)
}

function items(lang, count) {
  return count === 1 ? text(lang, "workshopItem") : text(lang, "workshopItems", count)
}
