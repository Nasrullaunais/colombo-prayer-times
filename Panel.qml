import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  readonly property var  geometryPlaceholder: panelContainer
  property real contentPreferredWidth:  360 * Style.uiScaleRatio
  property real contentPreferredHeight: Math.min(contentColumn.implicitHeight + Style.marginL * 2, 600 * Style.uiScaleRatio)
  property bool panelReady: false

  Behavior on contentPreferredHeight {
    enabled: panelReady
    NumberAnimation { duration: 180; easing.type: Easing.InOutCubic }
  }

  readonly property bool allowAttach: true

  anchors.fill: parent

  Timer {
    id: readyTimer; interval: 400; repeat: false; running: false
    onTriggered: panelReady = true
  }
  Component.onCompleted: readyTimer.start()

  property var cfg:      pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property bool use12h: (typeof Settings !== "undefined" && Settings.data) ? Settings.data.location.use12hourFormat : false

  readonly property var    mainInstance:     pluginApi?.mainInstance
  readonly property var    prayerTimings:    mainInstance?.prayerTimings    ?? null
  readonly property bool   isRamadan:        mainInstance?.isRamadan        ?? false
  readonly property bool   isLoading:        mainInstance?.isLoading        ?? false
  readonly property bool   hasError:         mainInstance?.hasError         ?? false
  readonly property string errorMessage:     mainInstance?.errorMessage     ?? ""
  readonly property int    secondsToNext:    mainInstance?.secondsToNext    ?? -1
  readonly property string nextPrayerName:   mainInstance?.nextPrayerName   ?? ""
  readonly property int    hijriDay:         mainInstance?.hijriDay         ?? 0
  readonly property int    hijriMonth:       mainInstance?.hijriMonth       ?? 0
  readonly property int    hijriYear:        mainInstance?.hijriYear        ?? 0
  readonly property string hijriMonthNameEn: mainInstance?.hijriMonthNameEn ?? ""

  readonly property bool prayerNow: secondsToNext === 0 && nextPrayerName !== ""
  readonly property bool isJumuah:  new Date().getDay() === 5

  readonly property color countdownColor: Color.mPrimary

  // Per-second countdown refresh while panel is open — always active
  Timer {
    interval: 1000; running: true; repeat: true
    onTriggered: {
      mainInstance?.updateCountdown()
      if (mainInstance && mainInstance.secondsToNext === 0)
        mainInstance.checkPrayerTimes()
    }
  }

  function formatTime(rawTime) {
    if (!rawTime) return "--:--"
    if (!use12h) return rawTime
    const parts = rawTime.split(":")
    let h = parseInt(parts[0])
    const m    = parts[1]
    const ampm = h >= 12 ? "PM" : "AM"
    h = h % 12 || 12
    return h + ":" + m + " " + ampm
  }

  function formatCountdown(secs) {
    if (secs <= 0) return ""
    const h = Math.floor(secs / 3600)
    const m = Math.floor((secs % 3600) / 60)
    const s = secs % 60
    if (h > 0) return h + "h " + m.toString().padStart(2, "0") + "m " + s.toString().padStart(2, "0") + "s"
    if (m > 0) return m + "m " + s.toString().padStart(2, "0") + "s"
    return s + "s"
  }

  readonly property string hijriDateStr: {
    if (!hijriDay || !hijriMonthNameEn || !hijriYear) return ""
    return hijriDay + " " + hijriMonthNameEn + " " + hijriYear + " AH"
  }

  readonly property var prayerOrder: [
    { key: "Fajr",    labelKey: "panel.fajr",    icon: "sunrise"    },
    { key: "Sunrise", labelKey: "panel.sunrise",  icon: "sun"        },
    { key: "Dhuhr",   labelKey: isJumuah ? "panel.jumuah" : "panel.dhuhr", icon: "sun-high" },
    { key: "Asr",     labelKey: "panel.asr",      icon: "sun-low"    },
    { key: "Maghrib", labelKey: "panel.maghrib",  icon: "sunset"     },
    { key: "Isha",    labelKey: "panel.isha",     icon: "moon-stars" }
  ]

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: "transparent"

    ColumnLayout {
      id: contentColumn
      anchors { fill: parent; margins: Style.marginL }
      spacing: Style.marginM

      // ── Header ────────────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true; spacing: Style.marginM

        NIcon {
          icon: "building-mosque"
          pointSize: Style.fontSizeXL
          color: Color.mPrimary
          Layout.alignment: Qt.AlignVCenter
        }
        NText {
          text: pluginApi?.tr("panel.title") ?? "Prayer Times"
          pointSize: Style.fontSizeL
          font.weight: Font.Bold
          color: Color.mOnSurface
          Layout.alignment: Qt.AlignVCenter
        }
        Item { Layout.fillWidth: true }
        NIconButton {
          icon: "settings"
          tooltipText: pluginApi?.tr("menu.settings") ?? "Settings"
          onClicked: {
            const screen = pluginApi?.panelOpenScreen
            if (screen) {
              pluginApi.closePanel(screen)
              Qt.callLater(() => BarService.openPluginSettings(screen, pluginApi.manifest))
            }
          }
          Layout.alignment: Qt.AlignVCenter
        }
        NIconButton {
          icon: "x"
          tooltipText: pluginApi?.tr("panel.close") ?? "Close"
          onClicked: {
            const screen = pluginApi?.panelOpenScreen
            if (screen) pluginApi.closePanel(screen)
          }
          Layout.alignment: Qt.AlignVCenter
        }
      }

      // ── Date row ──────────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true; spacing: Style.marginS

        NText {
          text: Qt.formatDate(new Date(), "dd MMM yyyy")
          pointSize: Style.fontSizeS
          color: Color.mSecondary
          Layout.alignment: Qt.AlignVCenter
        }
        Item { Layout.fillWidth: true }
        NText {
          visible: hijriDateStr !== ""
          text: hijriDateStr
          pointSize: Style.fontSizeS
          color: isRamadan ? Color.mPrimary : Color.mSecondary
          Layout.alignment: Qt.AlignVCenter
        }
      }

      // ── Countdown banner ──────────────────────────────────────────────────
      Rectangle {
        Layout.fillWidth: true
        implicitHeight: countdownColumn.implicitHeight + Style.marginM * 2
        color: Qt.alpha(countdownColor, 0.12); radius: Style.radiusL
        visible: prayerTimings !== null && nextPrayerName !== "" && secondsToNext >= 0

        ColumnLayout {
          id: countdownColumn
          anchors.centerIn: parent; spacing: Style.marginXS

          NText {
            Layout.alignment: Qt.AlignHCenter
            text: {
              if (!nextPrayerName) return ""
              let label = nextPrayerName
              if (nextPrayerName === "Dhuhr" && isJumuah)
                label = pluginApi?.tr("panel.jumuah") ?? "Jumu'ah"
              return prayerNow
                ? label + " — " + (pluginApi?.tr("panel.now") ?? "Now")
                : label + " in"
            }
            pointSize: Style.fontSizeS
            color: countdownColor
            opacity: prayerNow ? 0.7 : 1.0
          }

          NText {
            Layout.alignment: Qt.AlignHCenter
            visible: !prayerNow
            text: formatCountdown(secondsToNext)
            pointSize: Style.fontSizeXXL
            font.weight: Font.Bold
            color: countdownColor
          }
        }
      }

      // ── Loading / error state ─────────────────────────────────────────────
      Item {
        Layout.fillWidth: true
        implicitHeight: Style.baseWidgetSize
        visible: isLoading || hasError

        NBusyIndicator {
          anchors.centerIn: parent
          visible: isLoading
          running: isLoading
        }
        NText {
          anchors.centerIn: parent
          visible: hasError && !isLoading
          text: errorMessage || (pluginApi?.tr("error.generic") ?? "Failed to load.")
          color: Color.mError
          pointSize: Style.fontSizeS
          wrapMode: Text.Wrap
          horizontalAlignment: Text.AlignHCenter
          width: parent.width
        }
      }

      // ── Prayer list ───────────────────────────────────────────────────────
      NScrollView {
        Layout.fillWidth: true
        Layout.preferredHeight: prayerListColumn.implicitHeight
        horizontalPolicy: ScrollBar.AlwaysOff
        visible: prayerTimings !== null

        ColumnLayout {
          id: prayerListColumn
          width: parent.width
          spacing: Style.marginS

          Repeater {
            model: root.prayerOrder
            delegate: Rectangle {
              required property var modelData

              readonly property string rawTime:  prayerTimings?.[modelData.key] || ""
              readonly property bool   isNext:   modelData.key === nextPrayerName && prayerNow
              readonly property color  rowColor:  isNext ? Qt.alpha(Color.mPrimary, 0.15) : Color.mSurfaceVariant
              readonly property color  itemColor: isNext ? Color.mPrimary : Color.mOnSurface

              Layout.fillWidth: true
              implicitWidth: parent.width
              implicitHeight: rowLayout.implicitHeight + Style.marginS * 2
              radius: Style.radiusM
              color: rowColor

              Behavior on color { ColorAnimation { duration: 300 } }

              RowLayout {
                id: rowLayout
                anchors {
                  fill: parent
                  leftMargin:   Style.marginM
                  rightMargin:  Style.marginM
                  topMargin:    Style.marginS
                  bottomMargin: Style.marginS
                }
                spacing: Style.marginM

                NIcon {
                  icon: modelData.icon
                  pointSize: Style.fontSizeM
                  color: itemColor
                  Layout.alignment: Qt.AlignVCenter
                }
                NText {
                  text: pluginApi?.tr(modelData.labelKey) ?? modelData.key
                  pointSize: Style.fontSizeM
                  font.weight: isNext ? Style.fontWeightSemiBold : Style.fontWeightRegular
                  color: itemColor
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                }
                NText {
                  text: rawTime ? formatTime(rawTime) : "—"
                  pointSize: Style.fontSizeM
                  font.weight: isNext ? Style.fontWeightBold : Style.fontWeightRegular
                  color: itemColor
                  Layout.alignment: Qt.AlignVCenter
                }
              }
            }
          }
        }
      }

      // ── Empty state ───────────────────────────────────────────────────────
      Item {
        Layout.fillWidth: true
        implicitHeight: Style.baseWidgetSize * 2
        visible: prayerTimings === null && !isLoading && !hasError

        ColumnLayout {
          anchors.centerIn: parent; spacing: Style.marginM
          NIcon {
            icon: "building-mosque"
            pointSize: Style.fontSizeXXXL
            color: Color.mSecondary
            Layout.alignment: Qt.AlignHCenter
          }
          NText {
            text: pluginApi?.tr("panel.configure") ?? "Enable the plugin in Settings"
            color: Color.mSecondary
            pointSize: Style.fontSizeM
            wrapMode: Text.Wrap
            horizontalAlignment: Text.AlignHCenter
            Layout.alignment: Qt.AlignHCenter
          }
        }
      }
    }
  }
}
