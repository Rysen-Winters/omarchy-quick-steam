import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui
import "Strings.js" as Strings
import "Model.js" as Model

// Quick Steam: the Steam library one click (or one key) from the bar, plus
// what Steam is doing right now — downloads, updates, Workshop items and
// shader pre-caching.
//
// Each bar (one per monitor) gets one of these: the icon, its progress and
// its own panel. What Steam is doing, the library and the notifications live
// in Service.qml, once per shell; this item passes them on to Panel.qml, which
// only displays.
BarWidget {
  id: root
  moduleName: "io.github.rysen-winters.quick-steam"

  // Under Omarchy's own bar, the plugin's service, shared by every bar (null
  // until the shell has started it, which can come after the bars).
  readonly property var sharedService: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor(moduleName) : null

  // A replacement bar hands widgets no service, so the first instance of this
  // widget across all monitors runs one and the others read it. When its
  // monitor goes away, the next instance takes over with a fresh one. Until
  // the bar is injected nobody knows who is first, or whether the shared
  // service is coming, so nobody leads.
  readonly property var peers: !bar ? []
    : typeof bar.moduleWidgets === "function" ? bar.moduleWidgets(moduleName) : [root]
  readonly property bool first: !sharedService && peers.length > 0 && peers[0] === root
  readonly property var ownService: ownServiceLoader.item

  // Taking over waits a moment: while a bar is torn down its widgets go one
  // by one, and each would otherwise start a service only to lose it.
  property bool leads: false
  onFirstChanged: {
    if (first) leadDelay.restart()
    else leads = false
  }

  Timer {
    id: leadDelay
    interval: 500
    onTriggered: root.leads = root.first
  }

  readonly property var service: sharedService
    || (leads ? ownService : (peers.length > 0 && peers[0] ? peers[0].ownService || null : null))

  Loader {
    id: ownServiceLoader
    active: root.leads
    visible: false
    source: Qt.resolvedUrl("Service.qml")
    // The widget's entry facade can open and close this plugin's panel.
    onLoaded: item.shell = Qt.binding(function() { return root.bar ? root.bar.shell : null })
  }

  // The service reads the same entry; every bar hands it the same values, and
  // the first one to do so sets it going.
  function pushSettings() {
    if (!service) return
    service.settings = settings
    service.claimed = true
  }
  onSettingsChanged: pushSettings()
  onServiceChanged: pushSettings()

  // ---- Settings -----------------------------------------------------------------

  readonly property string languageSetting: service ? service.languageSetting : String(setting("language", "auto"))
  readonly property string lang: service ? service.lang : Strings.language(Qt.locale().name)
  readonly property bool showLibrary: service ? service.showLibrary : true
  readonly property bool showActivity: service ? service.showActivity : true
  readonly property bool showDetails: service ? service.showDetails : true
  readonly property bool showHidden: service ? service.showHidden : false
  readonly property string version: service ? service.version : ""

  // Chosen on the panel's settings page and kept in this widget's entry in
  // shell.json. The shell replaces the whole entry, so the current settings go
  // along with the change, the way the clock panel saves its own. Assigning
  // settings first applies it at once, and keeps it for the session if the
  // write fails.
  function saveSettings(values) {
    var entry = { id: root.moduleName }
    for (var existing in root.settings) if (existing !== "id") entry[existing] = root.settings[existing]
    for (var key in values) entry[key] = values[key]
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setSetting(key, value) {
    var values = {}
    values[key] = value
    saveSettings(values)
  }

  // Material Design Icons code points, present in every Nerd Font.
  readonly property string steamIcon: String.fromCodePoint(0xF04D3)
  readonly property string downloadIcon: String.fromCodePoint(0xF01DA)
  readonly property string shaderIcon: String.fromCodePoint(0xF08AE)

  // ---- What the service knows, for this bar and its panel -------------------------

  readonly property var library: service ? service.library : ({ ok: false, loading: true, games: [], libraries: [], running: "" })
  readonly property var details: service ? service.details : ({})
  readonly property var downloads: service ? service.downloads : []
  readonly property var shaders: service ? service.shaders : null
  readonly property var mainDownload: service ? service.mainDownload : null
  readonly property bool busy: service ? service.busy : false
  readonly property var running: service ? service.running : null
  readonly property string runningId: service ? service.runningId : ""
  readonly property string runningBanner: service ? service.runningBanner : ""

  function requestDetails(id) {
    if (service) service.requestDetails(id)
  }

  function coverFor(game) {
    return service ? service.coverFor(game) : (game && game.art) || ""
  }

  function elapsedSince(startedAt) {
    return service ? service.elapsedSince(startedAt) : 0
  }

  function downloadFor(id) {
    return service ? service.downloadFor(id) : null
  }

  // ---- Actions -------------------------------------------------------------------

  // The links themselves are the service's; the ones that hand over to Steam
  // close this bar's panel.
  function play(id) {
    if (service && service.play(id)) close()
  }

  // Whether the panel can pick the library and confirm uninstalls itself, and
  // the library it installed to last.
  readonly property bool directActions: service ? service.directActions : false
  readonly property int lastFolder: service ? service.lastFolder : -1

  // Steam takes the focus either way, with its dialog or by bringing its
  // window forward with the command.
  function install(id, folder) {
    if (service) service.install(id, folder)
    close()
  }

  function uninstall(id, confirmed) {
    if (service) service.uninstall(id, confirmed)
    close()
  }

  function openStore(id) {
    if (service) service.openStore(id)
  }

  function bigPicture() {
    if (service) service.bigPicture()
    close()
  }

  function openLibrary() {
    if (service) service.openLibrary()
    close()
  }

  function openDownloads() {
    if (service) service.openDownloads()
    close()
  }

  // ---- Bar ------------------------------------------------------------------------

  readonly property real activityPercent: mainDownload ? Model.downloadPercent(mainDownload) : (shaders ? shaders.percent : 0)

  readonly property bool showPercent: busy && !vertical && setting("showProgress", true)

  // While a game runs, its store banner takes the icon's place, sized and
  // rounded like the album art in the Spotify widget.
  readonly property bool showBanner: runningBanner !== "" && !vertical
  readonly property real bannerHeight: Style.bar.iconCanvas + Style.space(2)
  readonly property real bannerWidth: Math.round(bannerHeight * 460 / 215)
  readonly property real markWidth: showBanner ? bannerWidth + Style.space(12) : Style.bar.iconSlot

  readonly property string tooltip: {
    if (running) return Strings.text(lang, "tooltipPlaying", running.name, Strings.duration(lang, elapsedSince(running.startedAt)))
    if (mainDownload) return Strings.text(lang, mainDownload.kind === "workshop" ? "tooltipWorkshop" : "tooltipDownload",
      mainDownload.name, Strings.percent(lang, Model.downloadPercent(mainDownload)))
    if (shaders) return Strings.text(lang, "tooltipShaders", shaders.name || "Steam", Strings.percent(lang, shaders.percent))
    return Strings.text(lang, "tooltipIdle")
  }

  // Shape contract for shell.summon/hide/toggle routing: the bar looks for
  // open/close/opened on the bar-widget root.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  onOpenedChanged: if (opened && service) service.panelOpened()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // While the percentage shows, the bar's open-panel mark underlines icon and
  // number together; otherwise it keeps the length every icon widget gets.
  readonly property real openPanelIndicatorWidth: showPercent ? button.implicitWidth - Style.space(8) : (showBanner ? bannerWidth : 0)

  onBarChanged: injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    fixedWidth: root.vertical ? -1 : root.markWidth + (root.showPercent ? percentLabel.implicitWidth + Style.space(6) : 0)
    fixedHeight: root.vertical ? Style.bar.iconSlot : -1
    // The theme's accent while Steam downloads or compiles shaders.
    foreground: root.busy ? Color.accent : (root.bar ? root.bar.barForeground : Color.foreground)
    tooltipText: root.opened ? "" : root.tooltip
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) root.toggle()
      else if (buttonCode === Qt.MiddleButton) root.bigPicture()
      else if (buttonCode === Qt.RightButton) root.openLibrary()
    }

    // The icon sits in the same slot, optically centred, that Omarchy's own
    // icon widgets use (BarIconButton): Nerd Font glyphs are rarely centred in
    // their advance, so centring the text box leaves the mark off to one side.
    Item {
      id: iconSlot
      width: root.markWidth
      height: parent.height

      Item {
        id: banner
        visible: root.showBanner
        anchors.centerIn: parent
        width: root.bannerWidth
        height: root.bannerHeight

        Image {
          id: bannerImage
          anchors.fill: parent
          source: root.runningBanner
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          smooth: true
          mipmap: true
          sourceSize.width: root.bannerWidth * 3
          sourceSize.height: root.bannerHeight * 3
          visible: false
          layer.enabled: true
        }

        Rectangle {
          id: bannerMask
          anchors.fill: parent
          // Follow the theme: rounded on rounded themes, square on sharp ones.
          radius: Style.cornerRadius > 0 ? Math.max(2, Math.round(root.bannerHeight * 0.22)) : 0
          visible: false
          layer.enabled: true
        }

        MultiEffect {
          anchors.fill: parent
          source: bannerImage
          maskEnabled: true
          maskSource: bannerMask
        }
      }

      Item {
        visible: !root.showBanner
        anchors.centerIn: parent
        width: Style.bar.iconCanvas
        height: Style.bar.iconCanvas

        OpticalGlyph {
          anchors.fill: parent
          text: root.steamIcon
          fontFamily: button.fontFamily
          fontSize: Style.bar.iconFont
          color: button.foreground
        }
      }
    }

    Text {
      id: percentLabel
      visible: root.showPercent
      anchors.left: iconSlot.right
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: Strings.percent(root.lang, root.activityPercent)
      color: button.foreground
      font.family: button.fontFamily
      font.pixelSize: button.fontSize
    }

    // Progress of whatever Steam is doing, as a hairline under the label.
    Rectangle {
      // Hidden while the panel is open: the bar's own mark sits in the same place.
      visible: root.busy && root.setting("showProgress", true) && !root.opened
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      anchors.leftMargin: Style.space(4)
      anchors.bottomMargin: Style.space(3)
      height: Math.max(2, Style.space(2))
      radius: height / 2
      width: Math.max(0, (parent.width - Style.space(8)) * root.activityPercent / 100)
      color: Color.accent

      Behavior on width {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
      }
    }
  }
}
