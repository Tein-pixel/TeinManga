package com.manhwaku.reader.data

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlinx.coroutines.runBlocking
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [29])
class NativeModelTest {
    @Test
    fun canonicalTitleRemovesPreSerializationSuffixWithoutChangingMainTitle() {
        assertEquals("Lookism", canonicalTitle("Lookism (Pre-Serialization)"))
        assertEquals("Lookism", canonicalTitle("Lookism [pre serialization]"))
        assertEquals("Lookism", canonicalTitle("  Lookism  "))
        assertTrue(isPreSerialization("Lookism: Pre-Serialization"))
    }

    @Test
    fun synopsisMarkdownIsConvertedToReadableText() {
        val formatted = cleanSynopsis(
            "**Original Webtoon:**\n[Naver Webtoon](https://example.test/title)\n\n# Synopsis\nA story."
        )

        assertEquals("Original Webtoon:\nNaver Webtoon\n\nSynopsis\nA story.", formatted)
        assertEquals("Heading\nA bold title", cleanSynopsis("# Heading\n**A bold title**"))
        assertEquals("Anchor", cleanSynopsis("[Anchor](https://example.test/path)"))
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

    @Test
    fun mangaBakaParserRejectsTagsWithNonSafeContentRating() {
        val ratedTag = JSONObject()
            .put("name", JSONObject().put("en", "Romance"))
            .put("content_rating", "suggestive")

        assertNull(Series.fromMangaBaka(mangaBakaRecord("safe", JSONArray().put(ratedTag))))
    }

    @Test
    fun chapterPaginationAdvancesByRawRowsNotOnlyValidChapters() {
        val response = JSONObject()
            .put("total", 105)
            .put(
                "data",
                JSONArray()
                    .put(chapterRecord("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", pages = 18))
                    .put(chapterRecord("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", pages = 0))
                    .put(chapterRecord("cccccccc-cccc-4ccc-8ccc-cccccccccccc", pages = 22))
            )

        val page = ManhwaRepository().parseChapterFeedResponse(response, offset = 100)

        assertEquals(1, page.chapters.size)
        assertEquals(103, page.nextOffset)
        assertTrue(page.hasMore)
        assertEquals("id", page.chapters.single().language)
    }

    @Test
    fun chapterPaginationStopsAtServerTotalAndOnEmptyPage() {
        val finalPage = JSONObject()
            .put("total", 101)
            .put("data", JSONArray().put(chapterRecord("dddddddd-dddd-4ddd-8ddd-dddddddddddd", pages = 15)))

        val parsedFinal = ManhwaRepository().parseChapterFeedResponse(finalPage, offset = 100)
        assertEquals(101, parsedFinal.nextOffset)
        assertFalse(parsedFinal.hasMore)

        val empty = JSONObject().put("total", 105).put("data", JSONArray())
        val parsedEmpty = ManhwaRepository().parseChapterFeedResponse(empty, offset = 101)
        assertEquals(101, parsedEmpty.nextOffset)
        assertFalse(parsedEmpty.hasMore)
    }

    @Test
    fun chapterFeedAcceptsValidChapterWithoutParentOnlyRatingField() {
        val first = chapterRecord("eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee", pages = 12)
        val second = chapterRecord("ffffffff-ffff-4fff-8fff-ffffffffffff", pages = 15)
        val invalid = chapterRecord("99999999-9999-4999-8999-999999999999", pages = 0)
        val response = JSONObject().put(
            "data",
            JSONArray().put(first).put(second).put(invalid)
        )

        val page = ManhwaRepository().parseChapterFeedResponse(response, offset = 0)

        assertEquals(2, page.chapters.size)
        assertEquals(3, page.nextOffset)
    }

    @Test
    fun chapterRequestRejectsSeriesWithoutExplicitSafeRating() = runBlocking {
        val unsafe = Series(
            id = 1,
            title = "Test",
            type = "manhwa",
            url = "",
            cover = "",
            contentRating = "unknown",
            mangaDexId = "12345678-1234-1234-1234-123456789abc"
        )
        val result = runCatching { ManhwaRepository().chapters(unsafe) }

        assertTrue(result.isFailure)
        assertTrue(result.exceptionOrNull() is IllegalArgumentException)
    }

    private fun chapterRecord(
        id: String,
        pages: Int
    ) = JSONObject()
        .put("id", id)
        .put(
            "attributes",
            JSONObject()
                .put("chapter", "12")
                .put("title", "Chapter test")
                .put("translatedLanguage", "id")
                .put("pages", pages)
        )
        .put(
            "relationships",
            JSONArray().put(
                JSONObject()
                    .put("type", "scanlation_group")
                    .put("attributes", JSONObject().put("name", "Test Group"))
            )
        )

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

    private fun mangaBakaRecord(contentRating: String, tags: JSONArray = JSONArray()) = JSONObject()
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
        .put("tags", tags)
}
