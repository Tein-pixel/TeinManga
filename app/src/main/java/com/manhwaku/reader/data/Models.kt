package com.manhwaku.reader.data

import org.json.JSONArray
import org.json.JSONObject
import java.net.URI
import java.util.Locale

data class Series(
    val id: Int,
    val title: String,
    val type: String,
    val url: String,
    val cover: String,
    val coverLarge: String = "",
    val description: String = "",
    val status: String = "unknown",
    val rating: Double? = null,
    val author: String = "",
    val language: String = "unknown",
    val contentRating: String = "unknown",
    val source: String = "MangaBaka",
    val mangaBakaId: Int? = null,
    val mangaDexId: String? = null,
    val availableLanguages: List<String> = emptyList(),
    val publisherUrl: String = ""
) {
    fun toJson(): JSONObject = JSONObject().apply {
        put("id", id)
        put("title", title)
        put("type", type)
        put("url", url)
        put("cover", cover)
        put("coverLarge", coverLarge)
        put("description", description)
        put("status", status)
        put("rating", rating ?: JSONObject.NULL)
        put("author", author)
        put("language", language)
        put("contentRating", contentRating)
        put("source", source)
        put("mangaBakaId", mangaBakaId ?: JSONObject.NULL)
        put("mangaDexId", mangaDexId ?: JSONObject.NULL)
        put("availableTranslatedLanguages", JSONArray(availableLanguages))
        put("publisherUrl", publisherUrl)
    }

    companion object {
        fun fromJson(value: JSONObject): Series = Series(
            id = value.optInt("id"),
            title = value.optString("title", "Tanpa judul"),
            type = value.optString("type", "other"),
            url = value.optString("url"),
            cover = value.optString("cover"),
            coverLarge = value.optString("coverLarge"),
            description = value.optString("description"),
            status = value.optString("status", "unknown"),
            rating = if (value.isNull("rating")) null else value.optDouble("rating"),
            author = value.optString("author"),
            language = value.optString("language", "unknown"),
            contentRating = value.optString("contentRating", "unknown"),
            source = value.optString("source", "MangaBaka"),
            mangaBakaId = if (value.isNull("mangaBakaId")) null else value.optInt("mangaBakaId"),
            mangaDexId = value.optString("mangaDexId").takeIf { it.isNotBlank() && it != "null" },
            availableLanguages = value.optJSONArray("availableTranslatedLanguages").toStringList(),
            publisherUrl = value.optString("publisherUrl")
        )

        fun fromMangaBaka(value: JSONObject): Series? {
            val id = value.optInt("id")
            if (id <= 0) return null
            val language = value.optString("original_language", "unknown").lowercase(Locale.ROOT)
            val titles = value.optJSONArray("titles")
            val title = pickTitle(titles, language)
                .ifBlank { value.optString("title") }
                .ifBlank { value.optString("romanized_title") }
                .ifBlank { value.optString("native_title") }
                .ifBlank { "Tanpa judul" }
            if (isPreSerialization(title)) return null

            val coverObject = value.optJSONObject("cover") ?: JSONObject()
            val cover = coverValue(coverObject, listOf("x350", "x250", "x150", "raw"), "x2")
            val large = coverValue(coverObject, listOf("x350", "x250", "raw"), "x3").ifBlank { cover }
            val rating = if (value.has("rating") && !value.isNull("rating")) value.optDouble("rating") else null
            val authors = value.optJSONArray("authors").toStringList().take(2).joinToString(", ")
            val safeRating = value.optString("content_rating", "unknown").lowercase(Locale.ROOT)
            if (safeRating != "safe" || hasRestrictedTags(value.optJSONArray("tags"))) return null

            return Series(
                id = id,
                title = title,
                type = value.optString("type", "other").lowercase(Locale.ROOT),
                url = value.optString("canonical_url", "https://mangabaka.org/"),
                cover = cover,
                coverLarge = large,
                description = value.optString("description"),
                status = value.optString("status", value.optString("state", "unknown")),
                rating = rating,
                author = authors,
                language = language,
                contentRating = safeRating,
                source = "MangaBaka",
                mangaBakaId = id,
                publisherUrl = extractPublisher(value.optJSONArray("links"), value.optJSONArray("links_v2"))
            )
        }

        fun fromMangaDex(value: JSONObject): Series? {
            val attributes = value.optJSONObject("attributes") ?: return null
            if (attributes.optString("contentRating") != "safe" ||
                hasRestrictedTags(attributes.optJSONArray("tags"))) return null

            val uuid = value.optString("id")
            if (!UUID_PATTERN.matches(uuid)) return null
            val language = attributes.optString("originalLanguage", "unknown")
            val type = when (language.lowercase(Locale.ROOT)) {
                "ko" -> "manhwa"
                "zh", "zh-hk", "zh-mo" -> "manhua"
                "ja" -> "manga"
                else -> "other"
            }
            val titles = attributes.optJSONObject("title") ?: JSONObject()
            val title = sequenceOf(
                titles.optString("en"),
                titles.optString(language),
                titles.optString("ja-ro"),
                titles.optString("ko-ro")
            ).plus(titles.keys().asSequence().map { titles.optString(it) })
                .firstOrNull { it.isNotBlank() && it != "null" } ?: return null
            if (isPreSerialization(title)) return null

            var coverFile = ""
            var author = ""
            val relationships = value.optJSONArray("relationships")
            if (relationships != null) {
                for (i in 0 until relationships.length()) {
                    val relationship = relationships.optJSONObject(i) ?: continue
                    val attrs = relationship.optJSONObject("attributes") ?: JSONObject()
                    when (relationship.optString("type")) {
                        "cover_art" -> coverFile = attrs.optString("fileName")
                        "author" -> if (author.isBlank()) author = attrs.optString("name")
                    }
                }
            }
            val cover = if (coverFile.isBlank()) "" else
                "https://uploads.mangadex.org/covers/$uuid/$coverFile.512.jpg"
            val coverLarge = if (coverFile.isBlank()) "" else
                "https://uploads.mangadex.org/covers/$uuid/$coverFile"
            val translated = attributes.optJSONArray("availableTranslatedLanguages").toStringList()
                .map { it.lowercase(Locale.ROOT) }
                .distinct()
            val descriptionObject = attributes.optJSONObject("description") ?: JSONObject()
            val synopsis = sequenceOf(
                descriptionObject.optString("en"),
                descriptionObject.optString("id"),
                descriptionObject.optString(language)
            ).plus(descriptionObject.keys().asSequence().map { descriptionObject.optString(it) })
                .firstOrNull { it.isNotBlank() && it != "null" }.orEmpty()

            return Series(
                id = stableId("mangadex:$uuid"),
                title = title,
                type = type,
                url = "https://mangadex.org/title/$uuid",
                cover = cover,
                coverLarge = coverLarge,
                description = synopsis,
                status = attributes.optString("status", "unknown"),
                author = author,
                language = language,
                contentRating = "safe",
                source = "MangaDex",
                mangaDexId = uuid,
                availableLanguages = translated
            )
        }
    }
}

data class Chapter(
    val id: String,
    val number: String,
    val title: String,
    val language: String,
    val pageCount: Int,
    val group: String
)

/**
 * A MangaDex feed page. nextOffset counts raw API rows, not only rows kept
 * after local validation, so filtered chapter rows cannot cause duplicates
 * or skipped records during pagination.
 */
data class ChapterPage(
    val chapters: List<Chapter>,
    val nextOffset: Int,
    val hasMore: Boolean,
    val usedFallback: Boolean = false
)

data class CatalogSearchResult(
    val series: List<Series>,
    val excludedByContentRating: Int = 0
)

fun JSONArray?.toStringList(): List<String> {
    if (this == null) return emptyList()
    return (0 until length()).mapNotNull { index ->
        when (val item = opt(index)) {
            is String -> item
            is JSONObject -> item.optString("name").takeIf { it.isNotBlank() }
            else -> null
        }
    }.filter { it.isNotBlank() && it != "null" }
}

fun cleanSynopsis(input: String): String {
    if (input.isBlank()) return ""
    val linkPattern = Regex("""\[([^\]]+)\]\((?:https?://[^)]+)\)""")
    val headingPattern = Regex("""^#{1,6}\s*""")
    val bulletPattern = Regex("""^[-*]\s+""")

    return input.lineSequence()
        .map { rawLine ->
            var line = rawLine.trim()
            line = linkPattern.replace(line) { match -> match.groupValues[1] }
            line = line.replace(Regex("""\*\*(.*?)\*\*""")) { match -> match.groupValues[1] }
            line = headingPattern.replace(line, "")
            line = bulletPattern.replace(line, "• ")
            line
        }
        .joinToString("\n")
        .replace(Regex("""\n{3,}"""), "\n\n")
        .trim()
}

fun normalizeTitle(input: String): String =
    canonicalTitle(input).lowercase(Locale.ROOT).replace(Regex("[^a-z0-9]"), "")

fun canonicalTitle(input: String): String {
    val cleaned = input.trim().replace(
        Regex("""\s*[\(\[]\s*pre[\s-]?serialization\s*[\)\]]\s*$""", RegexOption.IGNORE_CASE),
        ""
    ).trim()
    val normalized = cleaned.lowercase(Locale.ROOT).replace(Regex("[^a-z0-9]"), "")
    return if (normalized in setOf("nahonjamanlevelup", "ialonelevelup", "sololeveling")) {
        "Solo Leveling"
    } else cleaned
}

fun isPreSerialization(title: String): Boolean =
    Regex("""\bpre[\s-]?serialization\b""", RegexOption.IGNORE_CASE).containsMatchIn(title)

private fun pickTitle(titles: JSONArray?, originalLanguage: String): String {
    if (titles == null) return ""
    val rows = (0 until titles.length()).mapNotNull { titles.optJSONObject(it) }
    fun find(language: String, primaryOnly: Boolean): String = rows.firstOrNull {
        it.optString("language").equals(language, ignoreCase = true) &&
            (!primaryOnly || it.optBoolean("is_primary"))
    }?.optString("title").orEmpty()

    return sequenceOf(
        find("en", true),
        find("en", false),
        find(originalLanguage, true),
        find(originalLanguage, false),
        rows.firstOrNull { it.optBoolean("is_primary") }?.optString("title").orEmpty(),
        rows.firstOrNull()?.optString("title").orEmpty()
    ).firstOrNull { it.isNotBlank() }.orEmpty()
}

private fun coverValue(cover: JSONObject, keys: List<String>, density: String): String {
    for (key in keys) {
        val raw = cover.opt(key)
        val candidate = when (raw) {
            is String -> raw
            is JSONObject -> raw.optString(density).ifBlank {
                raw.optString("x2").ifBlank { raw.optString("x1").ifBlank { raw.optString("url") } }
            }
            else -> ""
        }
        if (candidate.isNotBlank() && candidate != "null") return candidate
    }
    return ""
}

private fun extractPublisher(legacy: JSONArray?, modern: JSONArray?): String {
    fun validHttps(url: String): String {
        return try {
            val uri = URI(url)
            if (uri.scheme.equals("https", true) && !uri.host.isNullOrBlank() &&
                uri.userInfo.isNullOrBlank()) uri.toString() else ""
        } catch (_: Exception) { "" }
    }

    if (modern != null) {
        for (i in 0 until modern.length()) {
            val link = modern.optJSONObject(i) ?: continue
            val type = link.optString("type").lowercase(Locale.ROOT)
            val trust = link.optString("trust_level").lowercase(Locale.ROOT)
            val status = link.optString("status").lowercase(Locale.ROOT)
            val trustedPlatform = type == "webplatform" &&
                trust in setOf("official", "trusted") && status == "active"
            if (type != "publisher" && !trustedPlatform) continue
            if (status.isNotBlank() && status != "active") continue
            if (trust.isNotBlank() && trust !in setOf("official", "trusted")) continue
            val url = validHttps(link.optString("url"))
            if (url.isNotBlank()) return url
        }
    }

    if (legacy != null) {
        for (i in 0 until legacy.length()) {
            val link = legacy.optJSONObject(i) ?: continue
            if (link.optString("type").equals("publisher", true)) {
                val url = validHttps(link.optString("url"))
                if (url.isNotBlank()) return url
            }
        }
    }
    return ""
}

private fun hasRestrictedTags(tags: JSONArray?): Boolean {
    if (tags == null) return false
    val blocked = listOf(
        "ecchi", "hentai", "erotica", "adult", "mature", "suggestive",
        "pornographic", "nudity", "sexual content", "sexual violence",
        "sexual abuse", "gore", "graphic violence"
    )
    for (i in 0 until tags.length()) {
        val row = tags.optJSONObject(i) ?: continue
        val attrs = row.optJSONObject("attributes") ?: row
        val nameObject = attrs.optJSONObject("name")
        val name = if (nameObject != null) {
            nameObject.keys().asSequence().map { nameObject.optString(it) }.joinToString(" ")
        } else attrs.optString("name")
        if (blocked.any { name.contains(it, ignoreCase = true) }) return true
        val rating = attrs.optString("contentRating", attrs.optString("content_rating"))
            .lowercase(Locale.ROOT)
        if (rating in setOf("suggestive", "erotica", "pornographic", "mature", "adult")) return true
    }
    return false
}

private const val UUID_PATTERN_SOURCE =
    "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"
private val UUID_PATTERN = Regex(UUID_PATTERN_SOURCE)

private fun stableId(seed: String): Int {
    val hash = seed.hashCode() and 0x1fffffff
    return 1_500_000_000 + hash
}
