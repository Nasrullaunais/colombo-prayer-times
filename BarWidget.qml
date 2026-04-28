import QtQuick
import Quickshell
import qs.Commons
import qs.Modules.Bar.Extras
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  property var cfg:      pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property bool showCountdown: cfg.showCountdown ?? defaults.showCountdown ?? true
  readonly property bool use12h:        (typeof Settings !== "undefined" && Settings.data) ? Settings.data.location.use12hourFormat : false
  readonly property bool isJumuah:      new Date().getDay() === 5

  readonly property var    mainInstance:   pluginApi?.mainInstance
  readonly property var    prayerTimings:  mainInstance?.prayerTimings  ?? null
  readonly property bool   isLoading:      mainInstance?.isLoading      ?? false
  readonly property bool   hasError:       mainInstance?.hasError       ?? false
  readonly property int    secondsToNext:  mainInstance?.secondsToNext  ?? -1
  readonly property string nextPrayerName: mainInstance?.nextPrayerName ?? ""
  readonly property bool   prayerNow:      secondsToNext === 0 && nextPrayerName !== ""

  // Per-second countdown refresh (only active when countdown is visible)
  Timer {
    interval: 1000
    running: secondsToNext > 0 && secondsToNext <= 3600
    repeat: true
    onTriggered: mainInstance?.updateCountdown()
  }

  readonly property string nextPrayerLabel: {
    if (nextPrayerName === "Dhuhr" && isJumuah) return "Jumu'ah"
    return nextPrayerName
  }

  readonly property string nextPrayerTimeStr: {
    if (!prayerTimings || !nextPrayerName) return "--:--"
    const raw = prayerTimings[nextPrayerName]
    if (!raw) return "--:--"
    if (!use12h) return raw
    const parts = raw.split(":")
    let h = parseInt(parts[0])
    const m    = parts[1]
    const ampm = h >= 12 ? "PM" : "AM"
    h = h % 12 || 12
    return h + ":" + m + " " + ampm
  }

  readonly property string countdownStr: {
    if (secondsToNext <= 0) return ""
    const h = Math.floor(secondsToNext / 3600)
    const m = Math.floor((secondsToNext % 3600) / 60)
    if (h > 0) return h + "h " + m + "m"
    if (m > 0) return m + "m"
    return pluginApi?.tr("widget.soon") ?? "soon"
  }

  readonly property string displayText: {
    if (isLoading && !prayerTimings) return "..."
    if (hasError) return "!"
    if (!prayerTimings || !nextPrayerName) return "—"
    if (prayerNow) return nextPrayerLabel + " · " + (pluginApi?.tr("widget.now") ?? "Now")
    if (showCountdown && secondsToNext > 0) return nextPrayerLabel + " " + countdownStr
    return nextPrayerLabel + " " + nextPrayerTimeStr
  }

  readonly property string prayerTooltipText: {
    if (!prayerTimings) return pluginApi?.tr("widget.tooltip.noData") ?? "Prayer data not loaded"
    return nextPrayerLabel + ": " + nextPrayerTimeStr + "\n" +
           (pluginApi?.tr("widget.tooltip.countdown") ?? "Time remaining") + ": " + countdownStr
  }

  implicitWidth: pill.width
  implicitHeight: pill.height

  BarPill {
    id: pill

    screen: root.screen
    oppositeDirection: BarService.getPillDirection(root)
    icon: "building-mosque"
    text: root.displayText
    tooltipText: root.prayerTooltipText

    onClicked: {
      if (pluginApi) {
        pluginApi.openPanel(root.screen, this)
      }
    }

    onRightClicked: {
      var popupMenuWindow = PanelService.getPopupMenuWindow(screen)
      if (popupMenuWindow) {
        popupMenuWindow.showContextMenu(contextMenu)
      }
    }
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      { "label": pluginApi?.tr("menu.openPanel") ?? "Open Prayer Times", "action": "open",     "icon": "building-mosque" },
      { "label": pluginApi?.tr("menu.settings")  ?? "Widget Settings",   "action": "settings", "icon": "settings" }
    ]
    onTriggered: function (action) {
      var popupMenuWindow = PanelService.getPopupMenuWindow(screen)
      if (popupMenuWindow) {
        popupMenuWindow.close()
      }
      if (action === "open") {
        pluginApi.openPanel(root.screen, root)
      } else if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest)
      }
    }
  }
}
