import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Modules.DesktopWidgets
import qs.Widgets

DraggableDesktopWidget {
  id: root
  property var pluginApi: null

  readonly property var mainInstance:   pluginApi?.mainInstance
  readonly property var prayerTimings:  mainInstance?.prayerTimings  ?? null
  readonly property string nextPrayerName: mainInstance?.nextPrayerName ?? ""
  readonly property int    secondsToNext:  mainInstance?.secondsToNext  ?? -1
  readonly property bool   prayerNow:      secondsToNext === 0 && nextPrayerName !== ""
  readonly property bool   isJumuah:       new Date().getDay() === 5
  readonly property bool   use12h:         Settings.data.location.use12hourFormat

  // Per-second countdown refresh
  Timer {
    interval: 1000
    running: secondsToNext > 0
    repeat: true
    onTriggered: mainInstance?.updateCountdown()
  }

  implicitWidth: 280
  implicitHeight: 340

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
    anchors.margins: Style.marginM
    spacing: Style.marginS

    // ── Header ────────────────────────────────────────────────────────────
    RowLayout {
      Layout.fillWidth: true
      spacing: Style.marginS

      NIcon {
        icon: "building-mosque"
        pointSize: Style.fontSizeL
        color: Color.mPrimary
        Layout.alignment: Qt.AlignVCenter
      }
      NText {
        text: pluginApi?.tr("panel.title") ?? "Prayer Times"
        pointSize: Style.fontSizeM
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
      rowSpacing: Style.marginS
      columnSpacing: Style.marginS

      Repeater {
        model: root.prayerOrder
        delegate: Rectangle {
          required property var modelData
          required property int index

          readonly property string pKey:     modelData.key
          readonly property string rawTime:  prayerTimings?.[pKey] || ""
          readonly property bool   isNext:   pKey === nextPrayerName
          readonly property bool   isActive: isNext && prayerNow

          width:  (prayerGrid.width - prayerGrid.columnSpacing) / 2
          height: (prayerGrid.height - prayerGrid.rowSpacing * 2) / 3
          radius: Style.radiusM
          color:  isActive ? Qt.alpha(Color.mPrimary, 0.20)
                : isNext   ? Qt.alpha(Color.mPrimary, 0.10)
                           : Color.mSurfaceVariant

          Behavior on color { ColorAnimation { duration: 300 } }

          ColumnLayout {
            anchors.fill: parent
            anchors.margins: Style.marginS
            spacing: 2

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.marginXS

              NIcon {
                icon: modelData.icon
                pointSize: Style.fontSizeS
                color: isNext ? Color.mPrimary : Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignVCenter
              }
              NText {
                text: pluginApi?.tr(modelData.labelKey) ?? modelData.key
                pointSize: Style.fontSizeXS
                font.weight: isNext ? Style.fontWeightSemiBold : Style.fontWeightRegular
                color: isNext ? Color.mPrimary : Color.mOnSurfaceVariant
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                elide: Text.ElideRight
              }
            }

            NText {
              text: rawTime ? formatTime(rawTime) : "--:--"
              pointSize: Style.fontSizeL
              font.weight: isNext ? Font.Bold : Style.fontWeightMedium
              color: isNext ? Color.mPrimary : Color.mOnSurface
              Layout.fillWidth: true
              horizontalAlignment: Text.AlignLeft
            }
          }
        }
      }
    }
  }
}
