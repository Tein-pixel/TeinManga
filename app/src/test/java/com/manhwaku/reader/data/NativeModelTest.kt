package com.manhwaku.reader.data

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class NativeModelTest {
    @Test
    fun canonicalTitleRemovesPreSerializationSuffixWithoutChangingMainTitle() {
        assertEquals("Lookism", canonicalTitle("Lookism (Pre-Serialization)"))
        assertEquals("Lookism", canonicalTitle("Lookism [pre serialization]"))
        assertEquals("Lookism", canonicalTitle("  Lookism  "))
        assertTrue(isPreSerialization("Lookism: Pre-Serialization"))
    }

    @Test
    fun mangaDexParserKeepsSafeTitleAndBuildsCoverMetadata() {
        val item = Series.fromMangaDex(mangaDexRecord())

        assertNotNull(item)
        assertEquals("Lookism", item!!.title)
        assertEquals("manhwa", item.type)
        assertEquals("ko", item.language)
        assertEquals(listOf("id", "en"), item.availableLanguages)
        assertEquals("https://uploads.mangadex.org/covers/12345678-1234-1234-1234-123456789abc/cover.jpg.512.jpg", item.cover)
        assertEquals("Creator", item.author)
    }

    @Test
    fun mangaDexParserRejectsUnknownRatingAndRestrictedTags() {
        assertNull(Series.fromMangaDex(mangaDexRecord(contentRating = "unknown")))

        val restrictedTags = JSONArray().put(
            JSONObject().put(
                "attributes",
                JSONObject().put("name", JSONObject().put("en", "Suggestive"))
            )
        )
        assertNull(Series.fromMangaDex(mangaDexRecord(tags = restrictedTags)))
    }

    @Test
    fun mangaBakaParserAcceptsOnlyExplicitSafeRecords() {
        val safe = mangaBakaRecord("safe")
        val parsed = Series.fromMangaBaka(safe)

        assertNotNull(parsed)
        assertEquals(73, parsed!!.id)
        assertEquals("Lookism", parsed.title)
        assertEquals("https://cdn.example.test/lookism-cover.jpg", parsed.cover)
        assertEquals("Creator", parsed.author)

        assertNull(Series.fromMangaBaka(mangaBakaRecord("unknown")))
        assertNull(Series.fromMangaBaka(mangaBakaRecord("suggestive")))
    }

    private fun mangaDexRecord(
        contentRating: String = "safe",
        tags: JSONArray = JSONArray()
    ) = JSONObject()
        .put("id", "12345678-1234-1234-1234-123456789abc")
        .put(
            "attributes",
            JSONObject()
                .put("contentRating", contentRating)
                .put("originalLanguage", "ko")
                .put("status", "completed")
                .put("title", JSONObject().put("en", "Lookism"))
                .put("description", JSONObject().put("en", "A school drama."))
                .put("availableTranslatedLanguages", JSONArray().put("id").put("en"))
                .put("tags", tags)
        )
        .put(
            "relationships",
            JSONArray()
                .put(
                    JSONObject()
                        .put("type", "cover_art")
                        .put("attributes", JSONObject().put("fileName", "cover.jpg"))
                )
                .put(
                    JSONObject()
                        .put("type", "author")
                        .put("attributes", JSONObject().put("name", "Creator"))
                )
        )

    private fun mangaBakaRecord(contentRating: String) = JSONObject()
        .put("id", 73)
        .put("original_language", "ko")
        .put(
            "titles",
            JSONArray().put(
                JSONObject()
                    .put("language", "en")
                    .put("title", "Lookism")
                    .put("is_primary", true)
            )
        )
        .put(
            "cover",
            JSONObject().put(
                "x350",
                JSONObject()
                    .put("x2", "https://cdn.example.test/lookism-cover.jpg")
                    .put("x3", "https://cdn.example.test/lookism-cover-large.jpg")
            )
        )
        .put("authors", JSONArray().put("Creator"))
        .put("content_rating", contentRating)
        .put("tags", JSONArray())
}
