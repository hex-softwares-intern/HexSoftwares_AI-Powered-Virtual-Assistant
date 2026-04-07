package com.yourname.ai_assistant

import android.Manifest
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.media.*
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.os.Bundle
import android.provider.AlarmClock
import android.provider.CalendarContract
import android.provider.ContactsContract
import android.provider.MediaStore
import android.app.SearchManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.*
import org.vosk.Model
import org.vosk.Recognizer
import java.io.File
import java.util.*

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "ARIA_System"
        private const val METHOD_CH = "com.yourname.ai_assistant/wake_word"
        private const val EVENT_CH = "com.yourname.ai_assistant/wake_word_events"
        private const val INTENT_CHANNEL = "com.yourname.ai_assistant/platform_intents"
        
        private const val SAMPLE_RATE = 16000
        private const val BUFFER_SIZE = 4096
        private val WAKE_PHRASES = listOf("hey jarvis", "ok jarvis", "okay jarvis", "jarvis boot up")
    }

    private var eventSink: EventChannel.EventSink? = null
    private var voskModel: Model? = null
    private var recognizer: Recognizer? = null
    private var audioRecord: AudioRecord? = null

    @Volatile private var isRunning = false
    @Volatile private var modelReady = false
    private var detectJob: Job? = null
    private val scope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    private var lastTrigger = 0L

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // --- Wake Word Channel ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CH).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> { startWakeWord(); result.success(null) }
                "stop" -> { scope.launch { stopWakeWordSuspend() }; result.success(null) }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CH).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(a: Any?, sink: EventChannel.EventSink?) { eventSink = sink }
            override fun onCancel(a: Any?) { eventSink = null }
        })

        // --- Main Intent and System Stats Channel ---
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INTENT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSystemStats" -> {
                    val stats = mutableMapOf<String, Any?>()
                    stats["battery"] = getBatteryInfo()
                    
                    // Trigger a nudge to the GPS hardware
                    requestSingleLocationUpdate()
                    stats["location"] = getLocationInfo()
                    
                    // 🔥 NEW: Inject real calendar events into stats
                    stats["events"] = getCalendarEvents()
                    
                    result.success(stats)
                }

                "setAlarm" -> {
                    val hour = call.argument<Int>("hour") ?: 7
                    val minute = call.argument<Int>("minute") ?: 0
                    val title = call.argument<String>("title") ?: "ARIA Alarm"
                    val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                        putExtra(AlarmClock.EXTRA_HOUR, hour)
                        putExtra(AlarmClock.EXTRA_MINUTES, minute)
                        putExtra(AlarmClock.EXTRA_MESSAGE, title)
                        putExtra(AlarmClock.EXTRA_SKIP_UI, false) 
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }

                "showAlarms" -> {
                    val intent = Intent(AlarmClock.ACTION_SHOW_ALARMS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }

                "makeCall" -> {
                    val target = call.argument<String>("target") ?: ""
                    val finalNumber = if (target.matches(Regex("^[+0-9\\s\\-]+$"))) target else getPhoneNumber(target)
                    val intent = Intent(Intent.ACTION_DIAL, Uri.parse("tel:${Uri.encode(finalNumber ?: target)}")).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }

                "sendSMS" -> {
                    val number = call.argument<String>("number") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val finalNumber = if (number.matches(Regex("^[+0-9\\s\\-]+$"))) number else getPhoneNumber(number)
                    val intent = Intent(Intent.ACTION_SENDTO).apply {
                        data = Uri.parse("smsto:${finalNumber ?: ""}")
                        putExtra("sms_body", message)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }

                "whatsappAction" -> {
                    val number = call.argument<String>("number") ?: ""
                    val message = call.argument<String>("message") ?: ""
                    val type = call.argument<String>("type") ?: "message"
                    val finalNumber = if (number.matches(Regex("^[+0-9\\s\\-]+$"))) number else getPhoneNumber(number)
                    try {
                        val intent = if (type == "message") {
                            val url = "https://api.whatsapp.com/send?phone=${finalNumber ?: ""}&text=${Uri.encode(message)}"
                            Intent(Intent.ACTION_VIEW, Uri.parse(url))
                        } else {
                            packageManager.getLaunchIntentForPackage("com.whatsapp")
                        }
                        intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("WHATSAPP_ERR", "Operation failed", e.message)
                    }
                }

                "playMusic" -> {
                    val query = call.argument<String>("query") ?: ""
                    val appChoice = call.argument<String>("app") ?: ""
                    
                    val intent = Intent(MediaStore.INTENT_ACTION_MEDIA_PLAY_FROM_SEARCH).apply {
                        putExtra(SearchManager.QUERY, query)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }

                    // 🔥 NEW: Explicit package support for requested players
                    when (appChoice.lowercase()) {
                        "blackhole" -> intent.setPackage("com.shadow.blackhole")
                        "ymusic" -> intent.setPackage("com.kapp.youtube.final")
                        "spotify" -> intent.setPackage("com.spotify.music")
                    }

                    try {
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // Fallback: search globally if the specific app isn't installed
                        intent.setPackage(null)
                        startActivity(intent)
                        result.success(true)
                    }
                }

                "createCalendarEvent" -> {
                    val title = call.argument<String>("title") ?: "New Event"
                    val startMs = (call.argument<Any>("startMs") as? Number)?.toLong() ?: System.currentTimeMillis()
                    val intent = Intent(Intent.ACTION_INSERT).apply {
                        data = CalendarContract.Events.CONTENT_URI
                        putExtra(CalendarContract.Events.TITLE, title)
                        putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, startMs)
                        putExtra(CalendarContract.EXTRA_EVENT_END_TIME, startMs + 3600000)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }

                "viewCalendar" -> {
                    val uri = CalendarContract.CONTENT_URI.buildUpon().appendPath("time").build()
                    val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    startActivity(intent)
                    result.success(true)
                }

                "openApp" -> {
                    val name = call.argument<String>("name") ?: ""
                    val success = openAppByName(name)
                    if (success) result.success(true) 
                    else result.error("404", "App not found", null)
                }

                else -> result.notImplemented()
            }
        }
        
        scope.launch { initVoskModel() }
    }

    // --- BATTERY LOGIC ---
    private fun getBatteryInfo(): Map<String, Any> {
        val bm = getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level = bm.getIntProperty(BatteryManager.BATTERY_PROPERTY_CAPACITY)
        val intent = registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, -1) ?: -1
        val isCharging = status == BatteryManager.BATTERY_STATUS_CHARGING || status == BatteryManager.BATTERY_STATUS_FULL
        return mapOf("level" to level, "isCharging" to isCharging)
    }

    // 🔥 NEW: CALENDAR DATA FETCHER ---
    private fun getCalendarEvents(): List<Map<String, String>> {
        val eventsList = mutableListOf<Map<String, String>>()
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) return eventsList

        val cursor = contentResolver.query(
            CalendarContract.Events.CONTENT_URI,
            arrayOf(CalendarContract.Events.TITLE, CalendarContract.Events.DTSTART),
            "(${CalendarContract.Events.DTSTART} >= ?) AND (${CalendarContract.Events.DTSTART} <= ?)",
            arrayOf(
                System.currentTimeMillis().toString(),
                (System.currentTimeMillis() + 86400000).toString() // Next 24 hours
            ),
            "${CalendarContract.Events.DTSTART} ASC"
        )

        cursor?.use {
            while (it.moveToNext()) {
                val title = it.getString(0) ?: "No Title"
                val startTime = it.getLong(1)
                val date = java.text.SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(startTime))
                eventsList.add(mapOf("title" to title, "time" to date))
            }
        }
        return eventsList
    }

    // --- LOCATION LOGIC ---
    private fun getLocationInfo(): Map<String, Double>? {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED) return null
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER, LocationManager.PASSIVE_PROVIDER)
        var bestLocation: Location? = null
        for (provider in providers) {
            try {
                val loc = lm.getLastKnownLocation(provider)
                if (loc != null && (bestLocation == null || loc.accuracy < bestLocation!!.accuracy)) {
                    bestLocation = loc
                }
            } catch (e: Exception) { continue }
        }
        return bestLocation?.let { mapOf("lat" to it.latitude, "lon" to it.longitude) }
    }

    private fun requestSingleLocationUpdate() {
        try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
                val provider = if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) LocationManager.NETWORK_PROVIDER else LocationManager.GPS_PROVIDER
                lm.requestSingleUpdate(provider, object : LocationListener {
                    override fun onLocationChanged(location: Location) { Log.d(TAG, "Loc updated: ${location.latitude}") }
                    override fun onStatusChanged(p: String?, s: Int, e: Bundle?) {}
                    override fun onProviderEnabled(p: String) {}
                    override fun onProviderDisabled(p: String) {}
                }, null)
            }
        } catch (e: Exception) { Log.e(TAG, "GPS Nudge failed: ${e.message}") }
    }

    // --- FUZZY APP OPENER ---
    private fun openAppByName(appName: String): Boolean {
        val pm = packageManager
        val cleanSearch = appName.lowercase().replace("application", "").replace("app", "").replace(Regex("[^a-z0-9]"), "").trim()
        if (cleanSearch.isEmpty()) return false
        val mainIntent = Intent(Intent.ACTION_MAIN, null).apply { addCategory(Intent.CATEGORY_LAUNCHER) }
        val resolvedInfos = pm.queryIntentActivities(mainIntent, 0)
        for (info in resolvedInfos) {
            val cleanLabel = info.loadLabel(pm).toString().lowercase().replace(Regex("[^a-z0-9]"), "")
            if (cleanLabel == cleanSearch || cleanLabel.contains(cleanSearch) || cleanSearch.contains(cleanLabel)) {
                pm.getLaunchIntentForPackage(info.activityInfo.packageName)?.let {
                    it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(it)
                    return true
                }
            }
        }
        val webFallbacks = mapOf("spotify" to "spotify:open", "youtube" to "https://www.youtube.com")
        val url = webFallbacks[cleanSearch] ?: return false
        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        return true
    }

    // --- CONTACTS HELPER ---
    private fun getPhoneNumber(name: String): String? {
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS) != PackageManager.PERMISSION_GRANTED) return null
        var number: String? = null
        val selection = "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} LIKE ?"
        contentResolver.query(ContactsContract.CommonDataKinds.Phone.CONTENT_URI, arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER), selection, arrayOf("%$name%"), null)?.use { cursor ->
            if (cursor.moveToFirst()) number = cursor.getString(0)
        }
        return number
    }

    // --- VOSK & AUDIO LOGIC ---
    private fun initVoskModel() { 
        try {
            val modelDir = File(cacheDir, "vosk-model")
            if (!modelDir.exists()) copyAssetFolder("vosk-model", modelDir)
            voskModel = Model(modelDir.absolutePath)
            modelReady = true
        } catch (e: Exception) { Log.e(TAG, "Model init error", e) }
    }

    private fun copyAssetFolder(assetPath: String, destDir: File) {
        destDir.mkdirs()
        assets.list(assetPath)?.forEach { file ->
            val fullPath = "$assetPath/$file"
            if (!assets.list(fullPath).isNullOrEmpty()) copyAssetFolder(fullPath, File(destDir, file))
            else assets.open(fullPath).use { input -> File(destDir, file).outputStream().use { input.copyTo(it) } }
        }
    }

    private fun startWakeWord() {
        if (isRunning || ActivityCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) return
        isRunning = true
        scope.launch {
            while (!modelReady) delay(300)
            withContext(Dispatchers.Main) { eventSink?.success(mapOf("status" to "ready")) }
            startListeningLoop()
        }
    }

    private fun startListeningLoop() {
        val model = voskModel ?: return
        val grammar = WAKE_PHRASES.joinToString(separator = "\", \"", prefix = "[\"", postfix = "\", \"[unk]\"]")
        recognizer = Recognizer(model, SAMPLE_RATE.toFloat(), grammar)
        val minBufSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT)
        try {
            audioRecord = AudioRecord(MediaRecorder.AudioSource.MIC, SAMPLE_RATE, AudioFormat.CHANNEL_IN_MONO, AudioFormat.ENCODING_PCM_16BIT, minBufSize)
            audioRecord?.startRecording()
            detectJob = scope.launch {
                val buffer = ShortArray(BUFFER_SIZE)
                while (isRunning) {
                    val read = audioRecord?.read(buffer, 0, BUFFER_SIZE) ?: 0
                    if (read <= 0) continue
                    val bytes = ByteArray(read * 2)
                    for (i in 0 until read) {
                        bytes[i * 2] = (buffer[i].toInt() and 0xFF).toByte()
                        bytes[i * 2 + 1] = (buffer[i].toInt() shr 8).toByte()
                    }
                    if (recognizer?.acceptWaveForm(bytes, bytes.size) == true) checkMatch(recognizer?.result ?: "")
                    else checkMatch(recognizer?.partialResult ?: "")
                }
            }
        } catch (e: Exception) { isRunning = false }
    }

    private suspend fun checkMatch(jsonResult: String) {
        val text = jsonResult.lowercase()
        if (WAKE_PHRASES.any { text.contains(it) }) {
            val now = System.currentTimeMillis()
            if (now - lastTrigger > 3000) {
                lastTrigger = now
                withContext(Dispatchers.Main) { eventSink?.success(mapOf("keyword" to text)) }
                scope.launch { stopWakeWordSuspend() }
            }
        }
    }

    private suspend fun stopWakeWordSuspend() {
        isRunning = false
        detectJob?.cancelAndJoin()
        try { audioRecord?.stop(); audioRecord?.release() } catch (e: Exception) { }
        audioRecord = null
        recognizer?.close()
        recognizer = null
    }

    override fun onDestroy() { 
        scope.launch { stopWakeWordSuspend() }
        voskModel?.close()
        scope.cancel()
        super.onDestroy() 
    }
}