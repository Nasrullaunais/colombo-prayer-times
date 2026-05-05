import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null

  readonly property var mainInstance:    pluginApi?.mainInstance
  readonly property var prayerTimings: mainInstance?.prayerTimings  ?? null
  readonly property string nextPrayerName: mainInstance?.nextPrayerName ?? ""
  readonly property int    secondsToNext:  mainInstance?.secondsToNext  ?? -1
  readonly property bool   prayerNow:      secondsToNext === 0 && nextPrayerName !== ""
  readonly property bool   isJumuah:       new Date().getDay() === 5
  readonly property bool use12h:         (typeof Settings !== "undefined" && Settings.data) ? Settings.data.location.use12hourFormat : false

  // Per-second countdown refresh — always active so widget stays in sync
  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: mainInstance?.updateCountdown()
  }

  // Base dimensions before scaling
  readonly property int baseWidth:  260
  readonly property int baseHeight: 320

  implicitWidth: Math.round(baseWidth  * widgetScale)
  implicitHeight: Math.round(baseHeight * widgetScale)

  readonly property var prayerOrder: [
    { key: "Fajr",    labelKey: "panel.fajr",    icon: "sunrise"    },
    { key: "Sunrise", labelKey: "panel.sunrise",  icon: "sun"        },
    { key: "Dhuhr",   labelKey: isJumuah ? "panel.jumuah" : "panel.dhuhr", icon: "sun-high" },
    { key: "Asr",     labelKey: "panel.asr",      icon: "sun-low"    },
    { key: "Maghrib", labelKey: "panel.maghrib",  icon: "sunset"     },
    { key: "Isha",    labelKey: "panel.isha",     icon: "moon-stars" }
  ]

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

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Math.round(Style.marginM * widgetScale)
    spacing: Math.round(Style.marginS * widgetScale)

    // ── Header ────────────────────────────────────────────────────────────
    RowLayout {
      Layout.fillWidth: true
      spacing: Math.round(Style.marginS * widgetScale)

      NIcon {
        icon: "building-mosque"
        pointSize: Math.round(Style.fontSizeL * widgetScale)
        color: Color.mPrimary
        Layout.alignment: Qt.AlignVCenter
      }
      NText {
        text: pluginApi?.tr("panel.title") ?? "Prayer Times"
        pointSize: Math.round(Style.fontSizeM * widgetScale)
        font.weight: Font.Bold
        color: Color.mOnSurface
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
      }
    }

    // ── 2×3 Prayer Grid ──────────────────────────────────────────────────
    Grid {
      id: prayerGrid
      Layout.fillWidth: true
      Layout.fillHeight: true
      columns: 2
      rowSpacing: Math.round(Style.marginS * widgetScale)
      columnSpacing: Math.round(Style.marginS * widgetScale)

      Repeater {
        model: root.prayerOrder
        delegate: Rectangle {
          required property var modelData
          required property int index

          readonly property string pKey:     modelData.key
          readonly property string rawTime:  prayerTimings?.[pKey] || ""
          readonly property bool   isNext:   pKey === nextPrayerName
          readonly property bool   isActive: isNext && prayerNow

          readonly property int scaledRadius: Math.round(Style.radiusM * widgetScale)
          width:  (prayerGrid.width - prayerGrid.columnSpacing) / 2
          height: (prayerGrid.height - prayerGrid.rowSpacing * 2) / 3
          radius: scaledRadius
          color:  isActive ? Qt.alpha(Color.mPrimary, 0.20)
                : isNext   ? Qt.alpha(Color.mPrimary, 0.10)
                           : "transparent"

          Behavior on color { ColorAnimation { duration: 300 } }

          ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 2 * Math.round(Style.marginS * widgetScale)
            spacing: 2

            // Icon + Name row
            RowLayout {
              Layout.alignment: Qt.AlignHCenter
              spacing: Math.round(Style.marginXS * widgetScale)

              NIcon {
                icon: modelData.icon
                pointSize: Math.round(Style.fontSizeS * widgetScale)
                color: isNext ? Color.mPrimary : Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignVCenter
              }
              NText {
                text: pluginApi?.tr(modelData.labelKey) ?? modelData.key
                pointSize: Math.round(Style.fontSizeXS * widgetScale)
                font.weight: isNext ? Style.fontWeightSemiBold : Style.fontWeightRegular
                color: isNext ? Color.mPrimary : Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
              }
            }

            // Time
            NText {
              Layout.alignment: Qt.AlignHCenter
              text: rawTime ? formatTime(rawTime) : "--:--"
              pointSize: Math.round(Style.fontSizeL * widgetScale)
              font.weight: isNext ? Font.Bold : Style.fontWeightMedium
              color: isNext ? Color.mPrimary : Color.mOnSurface
              horizontalAlignment: Text.AlignHCenter
            }
          }
        }
      }
    }
  }
}
