import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root

  property var pluginApi: null
  property var cfg:      pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property string valueMethod:            cfg.method            ?? defaults.method            ?? "acju"
  property bool   valueShowCountdown:     cfg.showCountdown     ?? defaults.showCountdown     ?? true
  property bool   valueShowNotifications: cfg.showNotifications ?? defaults.showNotifications ?? true
  property int    valueHijriDayOffset:    cfg.hijriDayOffset    ?? defaults.hijriDayOffset    ?? 0

  spacing: Style.marginL

  // ── Timetable ─────────────────────────────────────────────────────────────

  NHeader {
    label: pluginApi?.tr("settings.timetable.header") ?? "Timetable"
    description: pluginApi?.tr("settings.timetable.desc")
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.method.label") ?? "Calculation Method"
    description: pluginApi?.tr("settings.method.desc")
    currentKey: root.valueMethod
    model: [
      { "key": "acju", "name": "ACJU (All Ceylon Jamiyyathul Ulama)" },
      { "key": "old",  "name": "Old Timetable (Dept. of Waqf / Majlis)" }
    ]
    onSelected: key => root.valueMethod = key
  }

  NDivider { Layout.fillWidth: true }

  // ── Display ───────────────────────────────────────────────────────────────

  NHeader {
    label: pluginApi?.tr("settings.display.header") ?? "Display"
    Layout.bottomMargin: -Style.marginM
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showCountdown.label") ?? "Show countdown"
    description: pluginApi?.tr("settings.showCountdown.desc")
    checked: root.valueShowCountdown
    onToggled: checked => root.valueShowCountdown = checked
  }

  NDivider { Layout.fillWidth: true }

  // ── Notifications ─────────────────────────────────────────────────────────

  NHeader {
    label: pluginApi?.tr("settings.notifications.header") ?? "Notifications"
    Layout.bottomMargin: -Style.marginM
  }

  NToggle {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.showNotifications.label") ?? "Prayer notifications"
    description: pluginApi?.tr("settings.notifications.desc")
    checked: root.valueShowNotifications
    onToggled: checked => root.valueShowNotifications = checked
  }

  NDivider { Layout.fillWidth: true }

  // ── Calibration ───────────────────────────────────────────────────────────

  NHeader {
    label: pluginApi?.tr("settings.calibration.header") ?? "Calibration"
    description: pluginApi?.tr("settings.calibration.desc")
  }

  NComboBox {
    Layout.fillWidth: true
    label: pluginApi?.tr("settings.hijriDayOffset.label") ?? "Hijri Day Adjustment"
    description: pluginApi?.tr("settings.hijriDayOffset.desc")
    currentKey: String(root.valueHijriDayOffset)
    model: [
      { "key": "-1", "name": "−1 day" },
      { "key": "0",  "name": "Default (calculated)" },
      { "key": "1",  "name": "+1 day" }
    ]
    onSelected: key => root.valueHijriDayOffset = parseInt(key)
  }

  function saveSettings() {
    if (!pluginApi) return
    pluginApi.pluginSettings.method            = root.valueMethod
    pluginApi.pluginSettings.showCountdown     = root.valueShowCountdown
    pluginApi.pluginSettings.showNotifications = root.valueShowNotifications
    pluginApi.pluginSettings.hijriDayOffset    = root.valueHijriDayOffset
    pluginApi.saveSettings()
    Logger.d("ColomboPT", "Settings saved — method:", root.valueMethod)
  }
}
