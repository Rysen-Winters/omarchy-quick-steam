import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Strings.js" as Strings
import "Model.js" as Model

// The Quick Steam panel: what Steam is doing right now, then the library as a
// list on the left and the selected game on the right. The gear (or c) swaps
// all of it for the settings page: language, which of those sections to show,
// and the bar and notification options.
//
// Keyboard, the way the Spotify panel does it: the list has the keys when the
// panel opens, so plain letters are shortcuts (p play, i install, u uninstall,
// s store, l library, b Big Picture, f cycles the order), Up and Down move,
// Enter plays or installs, Tab switches between installed and not installed,
// and Escape clears the search, then closes. "/" or Up on the first game go to
// the search field, where Enter plays the selected match and Down or Escape
// come back to the list, keeping the filter.
Panel {
  id: root
  moduleName: "io.github.rysen-winters.quick-steam"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var host: hostWidget

  readonly property string lang: host ? host.lang : "en"
  readonly property var library: host ? host.library : ({ games: [], libraries: [] })
  readonly property var games: library.games || []
  readonly property var downloads: host ? host.downloads : []
  readonly property var shaders: host ? host.shaders : null
  readonly property string runningId: host ? host.runningId : (library.running || "")

  // Which sections the settings leave on; the bar widget keeps them.
  readonly property bool showActivity: host ? host.showActivity : true
  readonly property bool showLibrary: host ? host.showLibrary : true
  readonly property bool showDetails: host ? host.showDetails : true
  property bool settingsOpen: false

  // Only there while the list is on.
  readonly property var listView: librarySection.item ? librarySection.item.list : null
  readonly property var searchInput: librarySection.item ? librarySection.item.search : null

  property bool installedTab: true
  property string sort: "recent"
  property string query: ""
  property string selectedId: ""

  readonly property var visibleGames: Model.visibleGames(games, installedTab, query, sort, runningId)
  readonly property int selectedIndex: {
    for (var i = 0; i < visibleGames.length; i++) if (visibleGames[i].id === selectedId) return i
    return visibleGames.length > 0 ? 0 : -1
  }
  readonly property var selected: selectedIndex >= 0 ? visibleGames[selectedIndex] : null
  readonly property var selectedDetails: selected && host ? host.details[selected.id] : undefined

  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family
  readonly property color foreground: root.barForeground
  readonly property color dim: Qt.darker(foreground, 1.4)
  readonly property int listHeight: Style.space(360)

  onSelectedChanged: if (selected && host && opened) host.requestDetails(selected.id)
  onShowDetailsChanged: if (showDetails && selected && host && opened) host.requestDetails(selected.id)
  // The bar widget drops the details in the old language first.
  onLangChanged: Qt.callLater(function() {
    if (root.selected && root.host && root.opened) root.host.requestDetails(root.selected.id)
  })

  function t(key) {
    var args = [root.lang, key]
    for (var i = 1; i < arguments.length; i++) args.push(arguments[i])
    return Strings.text.apply(null, args)
  }

  function open() {
    query = ""
    if (searchInput) searchInput.text = ""
    settingsOpen = false
    keyCatcher.forceActiveFocus()
    // Opened while playing: straight to the game being played.
    if (runningId) installedTab = true
    selectedId = runningId
    root.controller.show()
    if (selected && host) host.requestDetails(selected.id)
  }

  function close() {
    root.controller.hide()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.hostWidget || root, direction)
    return false
  }

  function move(delta) {
    if (visibleGames.length === 0) return
    var index = Math.max(0, Math.min(visibleGames.length - 1, selectedIndex + delta))
    selectedId = visibleGames[index].id
    if (listView) listView.positionViewAtIndex(index, ListView.Contain)
  }

  function setTab(installed) {
    if (installedTab === installed) return
    installedTab = installed
    selectedId = ""
    // Not installed has no size order; fall back to recent rather than an
    // order no button shows.
    if (sortOptions().indexOf(sort) < 0) sort = "recent"
    if (listView) listView.positionViewAtBeginning()
  }

  // A game that is still downloading has nothing to play yet; its button
  // leads to Steam's Downloads page, where a paused download is resumed.
  function primaryAction(game) {
    if (!game || !host) return
    if (Model.isReady(game)) host.play(game.id)
    else if (!game.installed) host.install(game.id)
    else host.openDownloads()
  }

  function primaryLabel(game) {
    if (!game) return ""
    if (game.id === runningId) return t("playing")
    if (Model.isReady(game)) return t("play")
    if (!game.installed) return t("install")
    var download = host ? host.downloadFor(game.id) : null
    return download && download.status === "paused" ? t("resumeInSteam") : t("openDownloads")
  }

  // Size only means something for installed games.
  function sortOptions() {
    return installedTab ? ["recent", "name", "size"] : ["recent", "name"]
  }

  function setSort(value) {
    sort = value
    if (listView) listView.positionViewAtBeginning()
  }

  function cycleSort() {
    var options = sortOptions()
    setSort(options[(options.indexOf(sort) + 1) % options.length])
  }

  // "/" selects what was typed so a new search replaces it; Up from the top
  // of the list just puts the cursor back at the end.
  function focusSearch(selectAll) {
    if (!searchInput) return
    searchInput.forceActiveFocus()
    if (selectAll) searchInput.selectAll()
    else searchInput.cursorPosition = searchInput.text.length
  }

  function focusList() {
    keyCatcher.forceActiveFocus()
  }

  // The keys stay with the panel, so c and Escape come back from any control
  // on the page; Tab walks its controls.
  function toggleSettings() {
    settingsOpen = !settingsOpen
    focusList()
  }

  // The key hints, for the sections that are on. Each key stays on one line
  // with its action when the line wraps on the narrow panel.
  function keyHints() {
    var parts = []
    if (showLibrary) parts.push(t("hintGame"))
    parts.push(t("hintLibrary"), t("hintBigPicture"))
    if (showLibrary) parts.push(t("hintSort"), t("hintTab"), t("hintSearch"))
    parts.push(t("hintSettings"))
    return parts.join(" · ").split(" · ").map(function(hint) {
      return hint.replace(/ /g, " ")
    }).join(" · ")
  }

  // The shortcuts do what the buttons do, and only where the button would
  // be there: p needs a game ready to play, i one that is not installed, u
  // one that is.
  function shortcut(letter) {
    var game = selected
    if (!host) return false
    if (letter === "l") host.openLibrary()
    else if (letter === "b") host.bigPicture()
    else if (letter === "c") toggleSettings()
    // The rest act on the list, so they need it there.
    else if (!showLibrary) return false
    else if (letter === "/") focusSearch(true)
    else if (letter === "p") { if (game && Model.isReady(game) && game.id !== runningId) host.play(game.id) }
    else if (letter === "i") { if (game && !game.installed) host.install(game.id) }
    else if (letter === "u") { if (game && game.installed) host.uninstall(game.id) }
    else if (letter === "s") { if (game) host.openStore(game.id) }
    else if (letter === "f") cycleSort()
    else return false
    return true
  }

  function handleListKey(event) {
    var key = event.key
    var plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
    // On the settings page only c and Escape are the panel's: Tab, the arrows,
    // Space and Enter belong to the controls, and an unclaimed Tab moves
    // between them.
    if (settingsOpen) {
      if (key === Qt.Key_Escape || (plain && String(event.text || "").toLowerCase() === "c")) {
        toggleSettings()
        event.accepted = true
      }
      return
    }
    if (key === Qt.Key_Escape) {
      if (query !== "" && searchInput) searchInput.text = ""
      else close()
      event.accepted = true
      return
    }
    // Without the list there is nothing to move through: only letters.
    if (!showLibrary) {
      if (plain && shortcut(String(event.text || "").toLowerCase())) event.accepted = true
      return
    }
    if (key === Qt.Key_Down) move(1)
    else if (key === Qt.Key_Up) {
      if (selectedIndex <= 0) focusSearch(false)
      else move(-1)
    }
    else if (key === Qt.Key_PageDown) move(8)
    else if (key === Qt.Key_PageUp) move(-8)
    else if (key === Qt.Key_Home) move(-visibleGames.length)
    else if (key === Qt.Key_End) move(visibleGames.length)
    else if (key === Qt.Key_Return || key === Qt.Key_Enter) primaryAction(selected)
    else if (key === Qt.Key_Tab || key === Qt.Key_Backtab) setTab(!installedTab)
    // Combinations with Ctrl, Alt or Super belong to the rest of the desktop.
    else if (!plain) return
    else if (!shortcut(String(event.text || "").toLowerCase())) return
    event.accepted = true
  }

  function libraryLabel(index) {
    var libs = library.libraries || []
    return index >= 0 && index < libs.length ? libs[index].label : ""
  }

  function tierColor(tier) {
    return ({ platinum: "#b4c7dc", gold: "#cfb53b", silver: "#a6a6a6", bronze: "#cd7f32", borked: "#e05050" })[tier] || dim
  }

  // ---- Pieces --------------------------------------------------------------------

  component ProgressLine: Item {
    id: progressLine
    property real value: 0
    property color fill: Color.accent
    height: Style.space(6)

    Rectangle {
      anchors.fill: parent
      radius: height / 2
      color: Util.alpha(root.foreground, 0.15)
    }

    Rectangle {
      width: parent.width * Math.max(0, Math.min(100, progressLine.value)) / 100
      height: parent.height
      radius: height / 2
      color: progressLine.fill

      Behavior on width {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
      }
    }
  }

  component ActivityRow: Item {
    id: activityRow
    signal clicked()
    property bool clickable: false
    property string icon: ""
    property string title: ""
    property string status: ""
    property string detail: ""
    property real percent: 0
    property bool muted: false

    width: parent ? parent.width : 0
    implicitHeight: rowColumn.implicitHeight
    height: implicitHeight

    Column {
      id: rowColumn
      width: parent.width
      spacing: Style.space(4)

      Item {
        width: parent.width
        height: Math.max(titleText.implicitHeight, statusText.implicitHeight)

        Text {
          id: titleText
          anchors.left: parent.left
          anchors.right: statusText.left
          anchors.rightMargin: Style.space(12)
          textFormat: Text.PlainText
          text: activityRow.icon + "  " + activityRow.title
          color: activityMouse.containsMouse ? Color.accent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          id: statusText
          anchors.right: parent.right
          textFormat: Text.PlainText
          text: activityRow.status
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.bodySmall
        }
      }

      ProgressLine {
        width: parent.width
        value: activityRow.percent
        fill: activityRow.muted ? root.dim : Color.accent
      }

      Text {
        visible: text !== ""
        width: parent.width
        textFormat: Text.PlainText
        text: activityRow.detail
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        elide: Text.ElideRight
      }
    }

    MouseArea {
      id: activityMouse
      anchors.fill: parent
      enabled: activityRow.clickable
      hoverEnabled: activityRow.clickable
      cursorShape: activityRow.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: activityRow.clicked()
    }
  }

  // A settings row. Locked, it cannot be switched and says why instead of
  // what it does.
  component SettingToggle: Toggle {
    property string help: ""
    property bool locked: false
    property string lockedHelp: ""

    width: parent ? parent.width : 0
    enabled: !locked
    opacity: locked ? 0.55 : 1
    description: locked ? lockedHelp : help
    foreground: root.foreground
    fontFamily: root.fontFamily
  }

  component Badge: Rectangle {
    id: badge
    property string label: ""
    property color dot: "transparent"

    visible: label !== ""
    width: visible ? badgeRow.implicitWidth + Style.space(12) : 0
    height: badgeRow.implicitHeight + Style.space(6)
    radius: Style.cornerRadius
    color: "transparent"
    border.width: 1
    border.color: Util.alpha(root.foreground, 0.25)

    Row {
      id: badgeRow
      anchors.centerIn: parent
      spacing: Style.space(5)

      Rectangle {
        visible: badge.dot.a > 0
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(7)
        height: width
        radius: width / 2
        color: badge.dot
      }

      Text {
        textFormat: Text.PlainText
        text: badge.label
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  component Cover: Rectangle {
    id: cover
    property var game: null
    readonly property string source: root.host ? root.host.coverFor(game) : ""

    radius: Style.space(3)
    color: Util.alpha(root.foreground, 0.08)
    clip: true

    Text {
      anchors.centerIn: parent
      visible: coverImage.status !== Image.Ready
      textFormat: Text.PlainText
      text: Model.initials(cover.game ? cover.game.name : "")
      color: root.dim
      font.family: root.fontFamily
      font.pixelSize: Math.max(Style.font.caption, parent.height / 5)
      font.bold: true
    }

    Image {
      id: coverImage
      anchors.fill: parent
      source: cover.source === "" ? "" : (cover.source.indexOf("file://") === 0 ? cover.source : "file://" + cover.source)
      sourceSize.width: Math.ceil(parent.width * 2)
      sourceSize.height: Math.ceil(parent.height * 2)
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      cache: true
    }
  }

  // ---- Layout --------------------------------------------------------------------

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    // The details need the room; without them the panel is narrower.
    contentWidth: panel.fittedContentWidth(Style.space(root.showDetails ? 780 : 540))
    contentHeight: panel.fittedContentHeight(content.implicitHeight)

    // Omarchy's PanelKeyCatcher is not used: it binds h, j, k, l and x to
    // moving and deleting, and l opens the library here.
    Item {
      id: keyCatcher
      width: parent.width
      height: content.implicitHeight
      focus: true
      Keys.onPressed: function(event) { root.handleListKey(event) }

      Column {
        id: content
        width: parent.width
        spacing: Style.space(12)

        // Title, the settings and the two Steam-wide actions.
        Item {
          width: parent.width
          height: headerButtons.implicitHeight

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: (root.host ? root.host.steamIcon + "  " : "") + root.t("title")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
            font.bold: true
          }

          Row {
            id: headerButtons
            anchors.right: parent.right
            spacing: Style.space(6)

            Button {
              iconText: String.fromCodePoint(0xF0493) // md-cog
              tooltipText: root.t("settings")
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              selected: root.settingsOpen
              onClicked: root.toggleSettings()
            }

            Button {
              text: root.t("library")
              iconText: String.fromCodePoint(0xF125F) // md-bookshelf
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: if (root.host) root.host.openLibrary()
            }

            Button {
              text: root.t("bigPicture")
              iconText: String.fromCodePoint(0xF0297) // md-gamepad
              foreground: root.foreground
              fontFamily: root.fontFamily
              bordered: true
              onClicked: if (root.host) root.host.bigPicture()
            }
          }
        }

        // The settings, in place of everything else while they are open. They
        // are saved as soon as they change.
        Column {
          id: settingsPage
          visible: root.settingsOpen
          width: parent.width
          spacing: Style.space(10)

          PanelSectionHeader {
            text: root.t("language")
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          ButtonGroup {
            foreground: root.foreground
            fontFamily: root.fontFamily
            value: root.host && (root.host.languageSetting === "en" || root.host.languageSetting === "es")
              ? root.host.languageSetting : "auto"
            // Each language in its own words, so it can be found from the other.
            options: [
              { value: "auto", label: root.t("languageAuto") },
              { value: "en", label: "English" },
              { value: "es", label: "Español" }
            ]
            onChanged: function(value) { if (root.host) root.host.setSetting("language", value) }
          }

          PanelSeparator {
            width: parent.width
            foreground: root.foreground
          }

          // Two columns on the wide panel, one on the narrow one.
          Grid {
            id: settingsGrid
            readonly property real cellWidth: columns === 2 ? (width - columnSpacing) / 2 : width
            width: parent.width
            columns: width >= Style.space(700) ? 2 : 1
            columnSpacing: Style.space(16)
            rowSpacing: Style.space(10)

            Column {
              width: settingsGrid.cellWidth
              spacing: Style.space(6)

              PanelSectionHeader {
                text: root.t("sections")
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              // Activity or the list is always on, so whichever of the two is
              // left alone cannot be switched off.
              SettingToggle {
                label: root.t("sectionActivity")
                help: root.t("sectionActivityHelp")
                checked: root.showActivity
                locked: root.showActivity && !root.showLibrary
                lockedHelp: root.t("atLeastOne")
                onClicked: root.host.setSetting("showActivity", !root.showActivity)
              }

              SettingToggle {
                label: root.t("sectionLibrary")
                help: root.t("sectionLibraryHelp")
                checked: root.showLibrary
                locked: root.showLibrary && !root.showActivity
                lockedHelp: root.t("atLeastOne")
                onClicked: root.host.setSetting("showLibrary", !root.showLibrary)
              }

              SettingToggle {
                label: root.t("sectionDetails")
                help: root.t("sectionDetailsHelp")
                checked: root.showDetails
                locked: !root.showLibrary
                lockedHelp: root.t("needsList")
                onClicked: root.host.setSetting("showDetails", !root.showDetails)
              }
            }

            Column {
              width: settingsGrid.cellWidth
              spacing: Style.space(6)

              PanelSectionHeader {
                text: root.t("barAndNotices")
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              SettingToggle {
                label: root.t("settingProgress")
                help: root.t("settingProgressHelp")
                checked: root.host ? root.host.setting("showProgress", true) !== false : true
                onClicked: root.host.setSetting("showProgress", !checked)
              }

              SettingToggle {
                label: root.t("settingNotifyDownloads")
                help: root.t("settingNotifyDownloadsHelp")
                checked: root.host ? root.host.setting("notifyDownloads", true) !== false : true
                onClicked: root.host.setSetting("notifyDownloads", !checked)
              }

              SettingToggle {
                label: root.t("settingNotifyShaders")
                help: root.t("settingNotifyShadersHelp")
                checked: root.host ? root.host.setting("notifyShaders", true) !== false : true
                onClicked: root.host.setSetting("notifyShaders", !checked)
              }
            }
          }
        }

        // What Steam is doing and the library: the panel's usual page.
        Column {
          id: mainPage
          visible: !root.settingsOpen
          width: parent.width
          spacing: Style.space(12)

          // What Steam is doing right now. Only there while something happens.
          Column {
            id: activitySection
            visible: root.showActivity && (root.downloads.length > 0 || root.shaders !== null)
            width: parent.width
            spacing: Style.space(10)

            // Alone in the panel, the activity has room for more downloads.
            Repeater {
              model: root.showActivity ? root.downloads.slice(0, root.showLibrary ? 3 : 6) : []

              ActivityRow {
                required property var modelData
                readonly property real pct: Model.downloadPercent(modelData)
                readonly property bool running: modelData.status === "downloading"
                readonly property bool workshop: modelData.kind === "workshop"

                icon: root.host ? root.host.downloadIcon : ""
                title: modelData.name
                clickable: true
                onClicked: if (root.host) root.host.openDownloads()
                percent: pct
                muted: !running
                status: (workshop
                    ? root.t(running ? "workshopDownloading" : "workshopPaused")
                    : running ? root.t(modelData.kind === "update" ? "updating" : "downloading")
                    : root.t(modelData.status === "paused" ? "paused" : "queued"))
                  + " · " + Strings.percent(root.lang, pct)
                detail: {
                  var parts = [root.t("of", Strings.size(root.lang, modelData.total > 0 ? modelData.done : modelData.staged),
                    Strings.size(root.lang, modelData.total > 0 ? modelData.total : modelData.stageTotal))]
                  if (workshop && modelData.items > 0) parts.unshift(Strings.items(root.lang, modelData.items))
                  if (running && modelData.rate > 0) {
                    parts.push(Strings.rate(root.lang, modelData.rate))
                    parts.push(root.t("left", Strings.duration(root.lang, Model.downloadRemaining(modelData) / modelData.rate)))
                  }
                  return parts.join(" · ")
                }
              }
            }

            ActivityRow {
              visible: root.shaders !== null
              icon: root.host ? root.host.shaderIcon : ""
              title: root.shaders ? (root.shaders.name || "Steam") : ""
              percent: root.shaders ? root.shaders.percent : 0
              status: !root.shaders ? ""
                : (root.shaders.phase === "merging" ? root.t("finishing")
                  : root.shaders.phase === "replaying" ? root.t("compiling") + " · " + root.shaders.percent + "%"
                  : root.t("starting"))
              detail: {
                if (!root.shaders) return ""
                var parts = [root.t(root.shaders.mode === "background" ? "background" : "beforeLaunch"),
                  root.t("running", Strings.duration(root.lang, root.host ? root.host.elapsedSince(root.shaders.startedAt) : 0))]
                var waiting = (root.shaders.queue || []).length
                if (waiting > 0) parts.push(root.t("shaderQueue", waiting))
                var line = parts.join(" · ")
                return line.charAt(0).toUpperCase() + line.slice(1)
              }
            }

            // Between the activity and the list, when there is a list.
            PanelSeparator {
              visible: root.showLibrary
              width: parent.width
              foreground: root.foreground
            }
          }

          // Activity alone with nothing going on: say so instead of an empty panel.
          Text {
            visible: root.showActivity && !root.showLibrary && root.downloads.length === 0 && root.shaders === null
            width: parent.width
            textFormat: Text.PlainText
            text: root.t("nothingHappening")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            wrapMode: Text.WordWrap
          }

          // Off, the list is not built at all: no rows and no covers in memory.
          Loader {
            id: librarySection
            active: root.showLibrary
            visible: active
            width: parent.width
            height: item ? item.implicitHeight : 0
            sourceComponent: libraryComponent
          }
        }

        // The keys, so the shortcuts can be found without a manual. On the
        // narrow panel they take two lines.
        Text {
          width: parent.width
          textFormat: Text.PlainText
          text: root.settingsOpen ? root.t("settingsHints") : root.keyHints()
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WordWrap
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        // Free space in every Steam library.
        Row {
          width: parent.width
          spacing: Style.space(16)

          Repeater {
            model: root.library.libraries || []

            Column {
              required property var modelData
              width: (parent.width - parent.spacing * Math.max(0, (root.library.libraries || []).length - 1)) / Math.max(1, (root.library.libraries || []).length)
              spacing: Style.space(4)

              // Name and free space share a line on the wide panel and get one
              // each on the narrow one, where they would not fit.
              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: parent.modelData.label + (root.showDetails ? " · " + root.t("freeShort", Strings.size(root.lang, parent.modelData.free)) : "")
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }

              Text {
                visible: !root.showDetails
                width: parent.width
                textFormat: Text.PlainText
                text: root.t("freeShort", Strings.size(root.lang, parent.modelData.free))
                color: root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }

              ProgressLine {
                width: parent.width
                height: Style.space(4)
                value: parent.modelData.total > 0 ? 100 * (parent.modelData.total - parent.modelData.free) / parent.modelData.total : 0
                fill: parent.modelData.total > 0 && parent.modelData.free / parent.modelData.total < 0.1 ? Color.urgent : root.dim
              }
            }
          }
        }
      }
    }
  }

  // The search, the list and, beside it, the selected game. Built only while
  // the list is on; the functions above reach the list and the search field
  // through librarySection.item.
  Component {
    id: libraryComponent

    Column {
      property alias list: gameList
      property alias search: searchField
      spacing: Style.space(12)

      // Search, tab and order: one line on the wide panel; on the narrow one
      // the search takes a line of its own and the buttons flow to the next.
      Flow {
        width: parent.width
        spacing: Style.space(8)

        TextField {
          id: searchField
          width: root.showDetails ? parent.width - tabs.width - sortGroup.width - parent.spacing * 2 : parent.width
          placeholderText: root.t("search")
          foreground: root.foreground
          font.family: root.fontFamily
          onTextChanged: {
            root.query = text
            root.selectedId = ""
            gameList.positionViewAtBeginning()
          }

          // Enter plays (or installs) the selected match right from here; Down
          // and Escape go back to the list, keeping the filter, so the letter
          // shortcuts work on the results.
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.primaryAction(root.selected)
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_Escape) {
              root.focusList()
            } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
              root.setTab(!root.installedTab)
            } else {
              return
            }
            event.accepted = true
          }
        }

        ButtonGroup {
          id: tabs
          focusable: false
          foreground: root.foreground
          fontFamily: root.fontFamily
          value: root.installedTab ? "installed" : "available"
          options: [
            { value: "installed", label: root.t("installed") + " " + Model.count(root.games, true) },
            { value: "available", label: root.t("notInstalled") + " " + Model.count(root.games, false) }
          ]
          onChanged: function(value) { root.setTab(value === "installed") }
        }

        ButtonGroup {
          id: sortGroup
          focusable: false
          foreground: root.foreground
          fontFamily: root.fontFamily
          value: root.sort
          options: root.installedTab
            ? [{ value: "recent", label: root.t("sortRecent") }, { value: "name", label: root.t("sortName") }, { value: "size", label: root.t("sortSize") }]
            : [{ value: "recent", label: root.t("sortRecent") }, { value: "name", label: root.t("sortName") }]
          onChanged: function(value) { root.setSort(value) }
        }
      }

      // The list and the selected game.
      Row {
        width: parent.width
        height: root.listHeight
        spacing: Style.space(14)

        ListView {
          id: gameList
          width: root.showDetails ? Math.round(parent.width * 0.42) : parent.width
          height: parent.height
          clip: true
          model: root.visibleGames
          boundsBehavior: Flickable.StopAtBounds
          spacing: Style.space(2)

          delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool isSelected: index === root.selectedIndex

            width: ListView.view.width
            height: Style.space(52)
            radius: Style.cornerRadius
            color: isSelected ? Util.alpha(Color.accent, 0.18) : (rowMouse.containsMouse ? Util.alpha(root.foreground, 0.06) : "transparent")

            Cover {
              id: thumb
              game: row.modelData
              anchors.left: parent.left
              anchors.leftMargin: Style.space(6)
              anchors.verticalCenter: parent.verticalCenter
              height: parent.height - Style.space(8)
              width: Math.round(height * 2 / 3)
            }

            Column {
              anchors.left: thumb.right
              anchors.leftMargin: Style.space(10)
              anchors.right: rowAction.visible ? rowAction.left : parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                width: parent.width
                textFormat: Text.PlainText
                text: row.modelData.name
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                font.bold: row.isSelected
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                textFormat: Text.PlainText
                color: row.modelData.id === root.runningId ? Color.accent : root.dim
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                text: {
                  var game = row.modelData
                  if (game.id === root.runningId) return root.t("playing")
                  var parts = []
                  if (game.installed && !Model.isReady(game)) {
                    var download = root.host ? root.host.downloadFor(game.id) : null
                    if (!download) parts.push(root.t("installing"))
                    else parts.push(root.t(download.status === "downloading" ? "downloading" : download.status === "paused" ? "paused" : "queued")
                      + " " + Strings.percent(root.lang, Model.downloadPercent(download)))
                  }
                  parts.push(game.lastPlayed ? Strings.relative(root.lang, game.lastPlayed) : root.t("neverPlayed"))
                  if (game.installed && game.size > 0) parts.push(Strings.size(root.lang, game.size))
                  return parts.join(" · ")
                }
              }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.selectedId = row.modelData.id
                root.focusList()
              }
              onDoubleClicked: root.primaryAction(row.modelData)
            }

            // Without the details, their main button comes to the selected
            // row. Declared after the row's mouse area so it gets the click.
            Button {
              id: rowAction
              visible: !root.showDetails && row.isSelected
              anchors.right: parent.right
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              text: root.primaryLabel(row.modelData)
              iconText: !Model.isReady(row.modelData) ? String.fromCodePoint(0xF01DA) : String.fromCodePoint(0xF040A)
              foreground: root.foreground
              fontFamily: root.fontFamily
              fontSize: Style.font.bodySmall
              selected: true
              enabled: row.modelData.id !== root.runningId
              onClicked: root.primaryAction(row.modelData)
            }
          }

          Text {
            anchors.centerIn: parent
            visible: gameList.count === 0
            textFormat: Text.PlainText
            text: !root.library.ok && !root.library.loading ? root.t("noSteam")
              : root.library.loading ? root.t("loading") : root.t("noResults")
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }
        }

        // Off, the details are not built either.
        Loader {
          active: root.showDetails
          visible: active
          width: parent.width - gameList.width - parent.spacing
          height: parent.height
          sourceComponent: detailComponent
        }
      }
    }
  }

  // The selected game, sized by the Loader that holds it.
  Component {
    id: detailComponent

    Item {
      visible: root.selected !== null

      Row {
        id: detailTop
        width: parent.width
        spacing: Style.space(14)

        Cover {
          id: detailCover
          game: root.selected
          width: Style.space(120)
          height: Style.space(180)
        }

        Column {
          width: parent.width - detailCover.width - parent.spacing
          spacing: Style.space(8)

          Text {
            width: parent.width
            textFormat: Text.PlainText
            text: root.selected ? root.selected.name : ""
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
          }

          Text {
            width: parent.width
            visible: text !== ""
            textFormat: Text.PlainText
            text: root.selected ? Strings.genreNames(root.lang, root.selected.genres).join(" · ") : ""
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          Flow {
            width: parent.width
            spacing: Style.space(6)

            Badge {
              readonly property var proton: root.selectedDetails ? root.selectedDetails.protondb : null
              label: proton && proton.tier ? root.t("protondb", Strings.tierName(root.lang, proton.tier)) : ""
              dot: proton && proton.tier ? root.tierColor(proton.tier) : "transparent"
            }

            Badge {
              label: root.selected ? Strings.toolName(root.lang, root.selected.tool, root.selected.linux) : ""
            }

            Badge {
              label: root.selected && root.selected.deck > 0 ? root.t("deck" + root.selected.deck) : ""
            }

            Badge {
              label: root.selected && root.selected.review > 0 ? root.t("reviews", root.selected.review) : ""
            }
          }

          Text {
            width: parent.width
            textFormat: Text.PlainText
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
            text: {
              var game = root.selected
              if (!game) return ""
              var lines = []
              if (game.id === root.runningId && root.host && root.host.running) {
                lines.push(root.t("playingFor", Strings.duration(root.lang, root.host.elapsedSince(root.host.running.startedAt))))
                if (game.playtime > 0) lines.push(root.t("playtime", Strings.playtime(root.lang, game.playtime)))
              } else {
                var played = game.lastPlayed ? root.t("lastPlayed", Strings.relative(root.lang, game.lastPlayed)) : root.t("neverPlayed")
                if (game.playtime > 0) played += " · " + root.t("playtime", Strings.playtime(root.lang, game.playtime))
                lines.push(played)
              }
              if (game.installed && game.size > 0)
                lines.push(root.t("onLibrary", Strings.size(root.lang, game.size), root.libraryLabel(game.library)))
              return lines.join("\n")
            }
          }
        }
      }

      Text {
        anchors.top: detailTop.bottom
        anchors.topMargin: Style.space(14)
        anchors.bottom: actions.top
        anchors.bottomMargin: Style.space(10)
        width: parent.width
        textFormat: Text.PlainText
        text: root.selectedDetails === undefined ? ""
          : (root.selectedDetails.description || root.t("noDescription"))
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        wrapMode: Text.WordWrap
        elide: Text.ElideRight
        lineHeight: 1.15
      }

      Row {
        id: actions
        anchors.bottom: parent.bottom
        width: parent.width
        spacing: Style.space(8)

        Button {
          text: root.primaryLabel(root.selected)
          iconText: root.selected && !Model.isReady(root.selected) ? String.fromCodePoint(0xF01DA) : String.fromCodePoint(0xF040A)
          foreground: root.foreground
          fontFamily: root.fontFamily
          selected: true
          enabled: !!root.selected && root.selected.id !== root.runningId
          onClicked: root.primaryAction(root.selected)
        }

        Button {
          visible: !!root.selected && root.selected.installed
          text: root.t("uninstall")
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          onClicked: if (root.host && root.selected) root.host.uninstall(root.selected.id)
        }

        Button {
          text: root.t("store")
          foreground: root.foreground
          fontFamily: root.fontFamily
          bordered: true
          onClicked: if (root.host && root.selected) root.host.openStore(root.selected.id)
        }
      }
    }
  }
}
