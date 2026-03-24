import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  property ShellScreen screen
  property string widgetId: ""
  property string section: ""

  readonly property string screenName:    screen?.name ?? ""
  readonly property string barPosition:   Settings.getBarPositionForScreen(screenName)
  readonly property bool   isVertical:    barPosition === "left" || barPosition === "right"
  readonly property real   capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real   barFontSize:   Style.getBarFontSizeForScreen(screenName)

  property var cfg:      pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property bool showCountdown: cfg.showCountdown ?? defaults.showCountdown ?? true
  readonly property bool use12h:        Settings.data.location.use12hourFormat
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

  readonly property string verticalLine1: {
    if (isLoading && !prayerTimings) return "..."
    if (hasError) return "!"
    if (!prayerTimings || !nextPrayerName) return "—"
    return nextPrayerLabel
  }

  readonly property string verticalLine2: {
    if (!prayerTimings || !nextPrayerName) return ""
    if (prayerNow) return pluginApi?.tr("widget.now") ?? "Now"
    if (showCountdown && secondsToNext > 0) return countdownStr
    return nextPrayerTimeStr
  }

  readonly property string tooltipText: {
    if (!prayerTimings) return pluginApi?.tr("widget.tooltip.noData") ?? "Prayer data not loaded"
    return nextPrayerLabel + ": " + nextPrayerTimeStr + "\n" +
           (pluginApi?.tr("widget.tooltip.countdown") ?? "Time remaining") + ": " + countdownStr
  }

  readonly property real iconSize: Style.toOdd(capsuleHeight * 0.55)

  readonly property real contentWidth: {
    if (isVertical) return capsuleHeight
    return iconSize + Style.marginS + labelText.implicitWidth + Style.marginM * 2
  }
  readonly property real contentHeight: isVertical ? capsuleHeight * 2 : capsuleHeight

  implicitWidth:  contentWidth
  implicitHeight: contentHeight

  Rectangle {
    id: capsule
    x: Style.pixelAlignCenter(parent.width,  width)
    y: Style.pixelAlignCenter(parent.height, height)
    width:  root.contentWidth
    height: root.contentHeight
    radius: Style.radiusL
    color:        mouseArea.containsMouse ? Color.mHover : Style.capsuleColor
    border.color: Style.capsuleBorderColor
    border.width: Style.capsuleBorderWidth

    Behavior on color { ColorAnimation { duration: Style.animationFast } }

    // ── Horizontal layout ──────────────────────────────────────────────
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin:  Style.marginM
      anchors.rightMargin: Style.marginM
      spacing: Style.marginS
      visible: !isVertical

      NIcon {
        icon: "building-mosque"
        pointSize: root.iconSize
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mPrimary
        Layout.alignment: Qt.AlignVCenter
      }

      NText {
        id: labelText
        text: root.displayText
        pointSize: root.barFontSize
        applyUiScale: false
        color: mouseArea.containsMouse ? Color.mOnHover : (prayerNow ? Color.mPrimary : Color.mOnSurface)
        Layout.alignment: Qt.AlignVCenter
        Behavior on color { ColorAnimation { duration: 300 } }
      }
    }

    // ── Vertical layout ────────────────────────────────────────────────
    ColumnLayout {
      anchors.centerIn: parent
      spacing: Style.marginXS
      visible: isVertical

      NIcon {
        icon: "building-mosque"
        pointSize: Style.toOdd(root.capsuleHeight * 0.45)
        color: mouseArea.containsMouse ? Color.mOnHover : Color.mPrimary
        Layout.alignment: Qt.AlignHCenter
      }

      NText {
        text: root.verticalLine1
        pointSize: root.barFontSize * 0.7
        applyUiScale: false
        font.weight: Font.Medium
        color: mouseArea.containsMouse ? Color.mOnHover : (prayerNow ? Color.mPrimary : Color.mOnSurface)
        Layout.alignment: Qt.AlignHCenter
        Behavior on color { ColorAnimation { duration: 300 } }
      }

      NText {
        text: root.verticalLine2
        pointSize: root.barFontSize * 0.8
        applyUiScale: false
        opacity: 0.75
        color: mouseArea.containsMouse ? Color.mOnHover : (prayerNow ? Color.mPrimary : Color.mOnSurface)
        Layout.alignment: Qt.AlignHCenter
        visible: root.verticalLine2 !== ""
        Behavior on color { ColorAnimation { duration: 300 } }
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton

      onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) {
          if (pluginApi) pluginApi.openPanel(root.screen, root)
        } else if (mouse.button === Qt.RightButton) {
          PanelService.showContextMenu(contextMenu, root, screen)
        }
      }

      onEntered: TooltipService.show(root, tooltipText, BarService.getTooltipDirection(root.screen?.name))
      onExited:  TooltipService.hide()
    }
  }

  NPopupContextMenu {
    id: contextMenu
    model: [
      { "label": pluginApi?.tr("menu.openPanel") ?? "Open Prayer Times", "action": "open",     "icon": "building-mosque" },
      { "label": pluginApi?.tr("menu.settings")  ?? "Widget Settings",   "action": "settings", "icon": "settings" }
    ]
    onTriggered: function (action) {
      contextMenu.close()
      PanelService.closeContextMenu(screen)
      if (action === "open") {
        pluginApi.openPanel(root.screen, root)
      } else if (action === "settings") {
        BarService.openPluginSettings(root.screen, pluginApi.manifest)
      }
    }
  }
}
