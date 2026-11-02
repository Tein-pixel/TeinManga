package com.manhwaku.reader.data

import android.content.Context
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.ObjectInputStream
import java.io.ObjectOutputStream
import java.util.Base64

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29])
class LibraryStoreMigrationTest {
    private lateinit var context: Context

    @Before
    fun resetPreferences() {
        context = RuntimeEnvironment.getApplication()
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit().clear().commit()
        context.getSharedPreferences("ManhwaKuMigrationBackup", Context.MODE_PRIVATE)
            .edit().clear().commit()
    }

    @Test
    fun readsExistingFlutterStringListWithoutResettingFavorites() {
        val legacy = sampleSeries()
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit()
            .putString("flutter.favorites", encodeFlutterStringList(listOf(legacy.toJson().toString())))
            .commit()

        val store = LibraryStore(context)
        val favorites = store.favorites()

        assertEquals(1, favorites.size)
        assertEquals("Lookism", favorites.single().title)
        assertEquals(legacy.cover, favorites.single().cover)
        assertEquals("MangaBaka", favorites.single().source)
        assertTrue(prefs.getString("flutter.favorites", null)!!.startsWith(LIST_PREFIX))
    }

    @Test
    fun writesFavoritesInFlutterCompatibleStringListFormat() {
        val store = LibraryStore(context)
        assertTrue(store.toggleFavorite(sampleSeries()))

        val raw = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.favorites", null)

        assertNotNull(raw)
        assertTrue(raw!!.startsWith(LIST_PREFIX))
        val decoded = decodeFlutterStringList(raw)
        assertEquals(1, decoded.size)
        assertEquals("Lookism", JSONObject(decoded.single()).getString("title"))
        assertEquals("https://cdn.example.test/cover.jpg", JSONObject(decoded.single()).getString("cover"))
    }

    @Test
    fun readingStatusMovesBetweenShelvesAndCanBeRemoved() {
        val store = LibraryStore(context)
        val item = sampleSeries()

        store.setReadingStatus(item, "reading")
        assertEquals("reading", store.readingStatus(item))

        store.setReadingStatus(item, "completed")
        assertEquals("completed", store.readingStatus(item))
        assertTrue(store.readingStatusList("reading").isEmpty())

        store.setReadingStatus(item, "none")
        assertEquals("none", store.readingStatus(item))
    }

    @Test
    fun historyDoesNotDuplicateSameSeriesTitle() {
        val store = LibraryStore(context)
        store.addHistory(sampleSeries())
        store.addHistory(sampleSeries().copy(id = 74, title = "Lookism (Pre-Serialization)"))

        assertEquals(1, store.history().size)
    }

    private fun sampleSeries() = Series(
        id = 73,
        title = "Lookism",
        type = "manhwa",
        url = "https://mangabaka.org/series/73",
        cover = "https://cdn.example.test/cover.jpg",
        coverLarge = "https://cdn.example.test/cover-large.jpg",
        description = "A school drama.",
        status = "releasing",
        rating = 8.7,
        author = "Creator",
        language = "ko",
        contentRating = "safe",
        source = "MangaBaka",
        mangaBakaId = 73,
        availableLanguages = listOf("id", "en")
    )

    private fun encodeFlutterStringList(values: List<String>): String {
        val output = ByteArrayOutputStream()
        ObjectOutputStream(output).use { it.writeObject(ArrayList(values)) }
        return LIST_PREFIX + Base64.getEncoder().encodeToString(output.toByteArray())
    }

    private fun decodeFlutterStringList(raw: String): List<String> {
        val bytes = Base64.getDecoder().decode(raw.removePrefix(LIST_PREFIX))
        return ObjectInputStream(ByteArrayInputStream(bytes)).use {
            (it.readObject() as List<*>).filterIsInstance<String>()
        }
    }

    companion object {
        private const val LIST_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBhIGxpc3Qu"
    }
}
