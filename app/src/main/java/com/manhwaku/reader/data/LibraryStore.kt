package com.manhwaku.reader.data

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.ObjectInputStream
import java.io.ObjectOutputStream

/**
 * Uses Flutter's original SharedPreferences file and wire format.
 *
 * Flutter's shared_preferences 2.x Android plugin stores List<String> under
 * FlutterSharedPreferences / flutter.<key>, using LIST_PREFIX + Base64(Java
 * ObjectOutputStream(List<String>)). Writing the same format lets the old
 * Flutter build read the data too, and avoids a destructive database reset.
 */
class LibraryStore(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)

    private val backup: SharedPreferences =
        context.getSharedPreferences("ManhwaKuMigrationBackup", Context.MODE_PRIVATE)

    init {
        backupLegacyValues()
    }

    private fun backupLegacyValues() {
        if (backup.getBoolean("completed", false)) return
        val editor = backup.edit()
        LEGACY_KEYS.forEach { key ->
            val raw = prefs.getString("flutter.$key", null)
            if (raw != null) editor.putString(key, raw)
        }
        editor.putBoolean("completed", true).apply()
    }

    @Synchronized
    fun read(key: String): List<Series> {
        val raw = prefs.getString("flutter.$key", null) ?: return emptyList()
        val values = decodeStringList(raw) ?: return emptyList()
        return values.mapNotNull { encoded ->
            runCatching { Series.fromJson(JSONObject(encoded)) }.getOrNull()
        }.filter { it.id > 0 && it.title.isNotBlank() }
    }

    @Synchronized
    fun write(key: String, items: List<Series>) {
        val encoded = items.map { it.toJson().toString() }
        val output = ByteArrayOutputStream()
        ObjectOutputStream(output).use { stream -> stream.writeObject(ArrayList(encoded)) }
        val stored = LIST_PREFIX + Base64.encodeToString(output.toByteArray(), Base64.NO_WRAP)
        prefs.edit().putString("flutter.$key", stored).apply()
    }

    fun favorites(): List<Series> = read("favorites")
    fun history(): List<Series> = read("history")
    fun readingStatusList(status: String): List<Series> = if (status in STATUS_KEYS) read(status) else emptyList()

    @Synchronized
    fun toggleFavorite(item: Series): Boolean {
        val items = favorites().toMutableList()
        val identity = normalizeTitle(item.title)
        val index = items.indexOfFirst {
            it.id == item.id || (identity.isNotBlank() && normalizeTitle(it.title) == identity)
        }
        val added = index < 0
        if (added) items.add(0, item) else items.removeAt(index)
        write("favorites", items.distinctBy { normalizeTitle(it.title) }.take(200))
        return added
    }

    fun isFavorite(item: Series): Boolean {
        val identity = normalizeTitle(item.title)
        return favorites().any {
            it.id == item.id || (identity.isNotBlank() && normalizeTitle(it.title) == identity)
        }
    }

    @Synchronized
    fun addHistory(item: Series) {
        val identity = normalizeTitle(item.title)
        val items = history().toMutableList()
        items.removeAll {
            it.id == item.id || (identity.isNotBlank() && normalizeTitle(it.title) == identity)
        }
        items.add(0, item)
        write("history", items.take(100))
    }

    fun readingStatus(item: Series): String {
        val identity = normalizeTitle(item.title)
        STATUS_KEYS.forEach { status ->
            if (read(status).any {
                    it.id == item.id ||
                        (identity.isNotBlank() && normalizeTitle(it.title) == identity)
                }) return status
        }
        return "none"
    }

    @Synchronized
    fun setReadingStatus(item: Series, status: String) {
        STATUS_KEYS.forEach { key ->
            val identity = normalizeTitle(item.title)
            val remaining = read(key).filterNot {
                it.id == item.id ||
                    (identity.isNotBlank() && normalizeTitle(it.title) == identity)
            }
            write(key, remaining)
        }
        if (status in STATUS_KEYS) {
            val items = read(status).toMutableList()
            items.add(0, item)
            write(status, items.distinctBy { normalizeTitle(it.title) }.take(200))
        }
    }

    private fun decodeStringList(value: String): List<String>? {
        return try {
            when {
                value.startsWith(JSON_LIST_PREFIX) -> {
                    val json = value.removePrefix(JSON_LIST_PREFIX)
                    val array = JSONArray(json)
                    (0 until array.length()).map { array.optString(it) }
                }
                value.startsWith(LIST_PREFIX) -> {
                    val payload = value.removePrefix(LIST_PREFIX)
                    val bytes = Base64.decode(payload, Base64.DEFAULT)
                    ObjectInputStream(ByteArrayInputStream(bytes)).use { input ->
                        (input.readObject() as? List<*>)?.filterIsInstance<String>()
                    }
                }
                value.trimStart().startsWith("[") -> {
                    val array = JSONArray(value)
                    (0 until array.length()).map { array.optString(it) }
                }
                else -> null
            }
        } catch (_: Exception) {
            null
        }
    }

    companion object {
        private const val LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"
        private const val JSON_LIST_PREFIX = "${LIST_PREFIX}!"
        private val STATUS_KEYS = listOf("reading", "planned", "completed", "dropped")
        private val LEGACY_KEYS = listOf("favorites", "history", "reading", "planned", "completed", "dropped")
    }
}
