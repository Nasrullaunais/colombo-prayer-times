import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root
  property var pluginApi: null

  // ── Prayer data ───────────────────────────────────────────────────────────
  property var    prayerTimings:    null
  property int    hijriDayRaw:      0
  property int    hijriDay:         0
  property int    hijriMonth:       0
  property int    hijriYear:        0
  property string hijriMonthNameEn: ""
  property string hijriMonthNameAr: ""
  property int    hijriMonthDays:   30
  property bool   isRamadan:        hijriMonth === 9

  // ── State ─────────────────────────────────────────────────────────────────
  property bool   isLoading:      false
  property bool   hasError:       false
  property string errorMessage:   ""
  property string lastLoadedDate: ""

  // ── Countdown ─────────────────────────────────────────────────────────────
  property int    secondsToNext:  -1
  property string nextPrayerName: ""

  // ── Settings ──────────────────────────────────────────────────────────────
  property var cfg:      pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  readonly property string method:            cfg.method            ?? defaults.method            ?? "acju"
  readonly property bool   showNotifications: cfg.showNotifications ?? defaults.showNotifications ?? true
  readonly property int    hijriDayOffset:    cfg.hijriDayOffset    ?? defaults.hijriDayOffset    ?? 0

  onHijriDayOffsetChanged: {
    if (hijriDayRaw > 0)
      hijriDay = Math.max(1, Math.min(30, hijriDayRaw + hijriDayOffset))
  }

  // Only re-load today if databases are already loaded
  onMethodChanged: { if (_loadedCount >= 2) Qt.callLater(refreshToday) }

  readonly property var prayerKeys:       ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]
  readonly property var notificationKeys: ["Fajr", "Dhuhr", "Asr", "Maghrib", "Isha"]

  // ── Local databases ───────────────────────────────────────────────────────
  property var  acjuDatabase:    []
  property var  oldDatabase:     []
  property int  _loadedCount:    0
  property bool _dbLoadStarted:  false

  // pluginApi is injected after Component.onCompleted fires; watch both events
  onPluginApiChanged: Qt.callLater(_startLoading)

  function _startLoading() {
    if (_dbLoadStarted) return
    if (!pluginApi?.pluginDir) return
    _dbLoadStarted = true
    isLoading = true
    Logger.d("ColomboPT", "Starting load from:", pluginApi.pluginDir)
    acjuCatProcess.command = ["cat", pluginApi.pluginDir + "/assets/ACJU_colombo.json"]
    oldCatProcess.command  = ["cat", pluginApi.pluginDir + "/assets/OLD.json"]
    acjuCatProcess.running = true
    oldCatProcess.running  = true
  }

  function _onDbLoaded() {
    _loadedCount++
    if (_loadedCount < 2) return
    isLoading = false
    Logger.d("ColomboPT", "Both databases loaded — ACJU:", acjuDatabase.length, "OLD:", oldDatabase.length)
    refreshToday()
    fetchHijriDate()
  }

  Process {
    id: acjuCatProcess
    property string _buf: ""
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => acjuCatProcess._buf += data + "\n"
    }
    onExited: code => {
      if (code === 0 && _buf.length > 0) {
        try {
          root.acjuDatabase = JSON.parse(_buf)
          Logger.d("ColomboPT", "ACJU parsed:", root.acjuDatabase.length, "entries")
        } catch (e) {
          Logger.e("ColomboPT", "ACJU JSON parse error:", e.message)
          root.hasError = true
          root.errorMessage = root.pluginApi?.tr("error.generic") ?? "Failed to load."
        }
      } else if (code !== 0) {
        Logger.e("ColomboPT", "ACJU cat failed, exit code:", code)
        root.hasError = true
        root.errorMessage = root.pluginApi?.tr("error.generic") ?? "Failed to load."
      }
      root._onDbLoaded()
    }
  }

  Process {
    id: oldCatProcess
    property string _buf: ""
    running: false
    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => oldCatProcess._buf += data + "\n"
    }
    onExited: code => {
      if (code === 0 && _buf.length > 0) {
        try {
          root.oldDatabase = JSON.parse(_buf)
          Logger.d("ColomboPT", "OLD parsed:", root.oldDatabase.length, "entries")
        } catch (e) {
          Logger.e("ColomboPT", "OLD JSON parse error:", e.message)
          root.hasError = true
          root.errorMessage = root.pluginApi?.tr("error.generic") ?? "Failed to load."
        }
      } else if (code !== 0) {
        Logger.e("ColomboPT", "OLD cat failed, exit code:", code)
        root.hasError = true
        root.errorMessage = root.pluginApi?.tr("error.generic") ?? "Failed to load."
      }
      root._onDbLoaded()
    }
  }

  // ── Entry normalization (luhr→Dhuhr, magrib→Maghrib) ─────────────────────
  function normalizeEntry(e) {
    return {
      Fajr:    e.fajr    || "",
      Sunrise: e.sunrise || "",
      Dhuhr:   e.luhr    || "",
      Asr:     e.asr     || "",
      Maghrib: e.magrib  || "",
      Isha:    e.isha    || ""
    }
  }

  function getTodayKey() {
    const d  = new Date()
    const mm = String(d.getMonth() + 1).padStart(2, "0")
    const dd = String(d.getDate()).padStart(2, "0")
    return mm + "-" + dd
  }

  function refreshToday() {
    const key = getTodayKey()
    const db  = (method === "acju") ? acjuDatabase : oldDatabase
    if (!db || db.length === 0) {
      Logger.w("ColomboPT", "refreshToday: database empty for method:", method)
      return
    }
    let entry = null
    for (const e of db) { if (e.date === key) { entry = e; break } }
    if (!entry) {
      Logger.e("ColomboPT", "No entry for date:", key)
      hasError = true
      errorMessage = pluginApi?.tr("error.generic") ?? "No data for today."
      return
    }
    prayerTimings  = normalizeEntry(entry)
    hasError       = false
    lastLoadedDate = new Date().toISOString().substring(0, 10)
    updateCountdown()
    startSyncedTimer()
    Logger.d("ColomboPT", "Prayer times loaded — date:", key, "method:", method, "Fajr:", prayerTimings.Fajr)
  }

  // ── Hijri date via aladhan.com /gToH/ (cached, offline-safe) ─────────────
  property var _hijriXhr: null

  function fetchHijriDate() {
    const now     = new Date()
    const dd      = String(now.getDate()).padStart(2, "0")
    const mm      = String(now.getMonth() + 1).padStart(2, "0")
    const yyyy    = String(now.getFullYear())
    const dateKey = yyyy + "-" + mm + "-" + dd

    // Check cache first — Gregorian→Hijri mapping is fixed, so cache never expires
    try {
      const raw = pluginApi?.pluginSettings?._hijriCache
      if (raw) {
        const obj = JSON.parse(raw)
        if (obj[dateKey]) {
          const h = obj[dateKey]
          hijriDayRaw      = h.day
          hijriDay         = Math.max(1, Math.min(30, h.day + hijriDayOffset))
          hijriMonth       = h.month
          hijriYear        = h.year
          hijriMonthNameEn = h.monthEn
          hijriMonthNameAr = h.monthAr
          hijriMonthDays   = h.monthDays
          Logger.d("ColomboPT", "Hijri from cache:", hijriDay, hijriMonthNameEn, hijriYear)
          return
        }
      }
    } catch (e) {}

    if (_hijriXhr) return
    const url = "https://api.aladhan.com/v1/gToH/" + dd + "-" + mm + "-" + yyyy
    const xhr = new XMLHttpRequest()
    _hijriXhr = xhr
    xhr.onreadystatechange = function () {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      _hijriXhr = null
      if (xhr.status === 200) {
        try {
          const json = JSON.parse(xhr.responseText)
          const h    = json.data.hijri
          hijriDayRaw      = parseInt(h.day)
          hijriDay         = Math.max(1, Math.min(30, hijriDayRaw + hijriDayOffset))
          hijriMonth       = h.month.number
          hijriYear        = parseInt(h.year)
          hijriMonthNameEn = h.month.en
          hijriMonthNameAr = h.month.ar
          hijriMonthDays   = parseInt(h.month.days) || 30
          Logger.d("ColomboPT", "Hijri fetched:", hijriDay, hijriMonthNameEn, hijriYear)
          // Persist to cache
          try {
            const existingRaw = pluginApi?.pluginSettings?._hijriCache
            const cacheObj    = existingRaw ? JSON.parse(existingRaw) : {}
            cacheObj[dateKey] = {
              day: hijriDayRaw, month: hijriMonth, year: hijriYear,
              monthEn: hijriMonthNameEn, monthAr: hijriMonthNameAr, monthDays: hijriMonthDays
            }
            pluginApi.pluginSettings._hijriCache = JSON.stringify(cacheObj)
            pluginApi.saveSettings()
          } catch (e) {}
        } catch (e) {
          Logger.w("ColomboPT", "Hijri parse failed:", e.message)
        }
      } else {
        // Offline — Hijri date simply stays at default (0), panel omits the row
        Logger.w("ColomboPT", "Hijri fetch failed (offline?):", xhr.status)
      }
    }
    xhr.open("GET", url)
    xhr.send()
  }

  // ── Clock-synced timer ────────────────────────────────────────────────────
  Timer {
    id: syncTimer; repeat: false; running: false
    onTriggered: { root.onClockTick(); updateTimer.start() }
  }

  property string lastTickMinute: ""

  Timer {
    id: updateTimer; interval: 1000; repeat: true; running: false
    onTriggered: {
      const now  = new Date()
      const hhmm = now.getHours().toString().padStart(2, "0") + ":" + now.getMinutes().toString().padStart(2, "0")
      if (hhmm !== root.lastTickMinute) { root.lastTickMinute = hhmm; root.onClockTick() }
    }
  }

  function onClockTick() {
    const today = new Date().toISOString().substring(0, 10)
    if (today !== lastLoadedDate) {
      refreshToday()
      fetchHijriDate()
    } else {
      checkPrayerTimes()
      updateCountdown()
    }
  }

  function startSyncedTimer() {
    syncTimer.stop(); updateTimer.stop()
    checkPrayerTimes(); updateCountdown()
    const now      = new Date()
    const secsLeft = now.getSeconds() === 0 ? 0 : (60 - now.getSeconds())
    const ms       = Math.max(0, secsLeft * 1000 - now.getMilliseconds())
    if (ms === 0) { onClockTick(); updateTimer.start() }
    else { syncTimer.interval = ms; syncTimer.start() }
  }

  // ── Notifications ─────────────────────────────────────────────────────────
  property string lastNotifiedMinute: ""

  function checkPrayerTimes() {
    if (!prayerTimings) return
    const now  = new Date()
    const hhmm = now.getHours().toString().padStart(2, "0") + ":" + now.getMinutes().toString().padStart(2, "0")
    if (hhmm === lastNotifiedMinute) return
    for (const key of notificationKeys) {
      if (prayerTimings[key] === hhmm) { lastNotifiedMinute = hhmm; onPrayerTime(key) }
    }
  }

  Process {
    id: notifProcess; running: false
    onExited: notifProcess.running = false
  }

  function sendNotification(title, body) {
    notifProcess.command = ["notify-send", "-a", "Colombo Prayer Times", "-u", "critical", "-t", "10000", title, body]
    notifProcess.running = true
  }

  function onPrayerTime(prayerKey) {
    if (!showNotifications) return
    const timeStr  = prayerTimings?.[prayerKey] || ""
    const isJumuah = new Date().getDay() === 5
    if (prayerKey === "Dhuhr" && isJumuah) {
      sendNotification("🕌 Jumu'ah — " + timeStr, "حان وقت صلاة الجمعة")
      return
    }
    const arNames = {
      "Fajr": "الفجر", "Dhuhr": "الظهر", "Asr": "العصر",
      "Maghrib": "المغرب", "Isha": "العشاء"
    }
    sendNotification("🕌 " + prayerKey + " — " + timeStr, "حان الآن موعد صلاة " + (arNames[prayerKey] || prayerKey))
  }

  // ── Countdown ─────────────────────────────────────────────────────────────
  function updateCountdown() {
    if (!prayerTimings) { secondsToNext = -1; return }
    const now           = new Date()
    const gracePeriodMs = 5 * 60 * 1000

    function timeToday(timeStr) {
      if (!timeStr) return null
      const p = timeStr.split(":")
      const d = new Date(); d.setHours(parseInt(p[0]), parseInt(p[1]), 0, 0)
      return d
    }

    const prayers = []
    for (const key of prayerKeys) {
      const t = prayerTimings[key]; if (!t) continue
      const d = timeToday(t); if (d) prayers.push({ name: key, time: d })
    }
    if (prayers.length === 0) { secondsToNext = -1; return }

    for (let i = 0; i < prayers.length; i++) {
      const ms = now - prayers[i].time
      if (ms >= 0 && ms < gracePeriodMs) {
        nextPrayerName = prayers[i].name; secondsToNext = 0; return
      }
    }

    let nextIdx = -1
    for (let i = 0; i < prayers.length; i++) {
      if (prayers[i].time > now) { nextIdx = i; break }
    }

    let next
    if (nextIdx === -1) {
      next = { name: prayers[0].name, time: new Date(prayers[0].time) }
      next.time.setDate(next.time.getDate() + 1)
    } else {
      next = prayers[nextIdx]
    }

    const diff = Math.floor((next.time - now) / 1000)
    nextPrayerName = next.name
    secondsToNext  = diff > 0 ? diff : 0
  }

  // ── Startup ───────────────────────────────────────────────────────────────
  Component.onCompleted: Qt.callLater(_startLoading)
}
