package com.manhwaku.reader.data

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder
import java.nio.charset.StandardCharsets
import java.util.concurrent.TimeUnit

class ManhwaRepository {
    private val client = OkHttpClient.Builder()
        .connectTimeout(8, TimeUnit.SECONDS)
        .readTimeout(12, TimeUnit.SECONDS)
        .callTimeout(18, TimeUnit.SECONDS)
        .retryOnConnectionFailure(true)
        .build()

    @Volatile private var nextMangaDexRequestAt = 0L

    private fun throttleMangaDex() {
        synchronized(this) {
            val now = System.currentTimeMillis()
            val wait = (nextMangaDexRequestAt - now).coerceAtLeast(0L)
            if (wait > 0L) Thread.sleep(wait)
            nextMangaDexRequestAt = System.currentTimeMillis() + 350L
        }
    }

    private fun requestJson(url: String, mangaDex: Boolean = false): JSONObject {
        var lastError: Exception? = null
        repeat(2) { attempt ->
            if (mangaDex) throttleMangaDex()
            try {
                val request = Request.Builder()
                    .url(url)
                    .header("Accept", "application/json")
                    .header("User-Agent", "ManhwaKu/3.0 (Android; https://github.com/Tein-pixel/TeinManga)")
                    .build()
                client.newCall(request).execute().use { response ->
                    val body = response.body?.string().orEmpty()
                    if (response.isSuccessful) return JSONObject(body)
                    if (response.code == 429 || response.code in 500..504) {
                        val retrySeconds = retryDelaySeconds(response.header("Retry-After"),
                            response.header("X-RateLimit-Retry-After"))
                        if (attempt == 0 && retrySeconds in 1..20) {
                            Thread.sleep(retrySeconds * 1000L)
                            return@repeat
                        }
                    }
                    throw IllegalStateException("HTTP ${response.code}")
                }
            } catch (error: Exception) {
                lastError = error
                if (attempt == 0) Thread.sleep(450L)
            }
        }
        throw lastError ?: IllegalStateException("Permintaan API gagal")
    }

    private fun retryDelaySeconds(retryAfter: String?, mangaDexRetry: String?): Long {
        val ordinary = retryAfter?.trim()?.toLongOrNull()
        if (ordinary != null) return ordinary.coerceIn(1, 20)
        val epoch = mangaDexRetry?.trim()?.toLongOrNull()
        if (epoch != null) {
            val value = if (epoch > 1_000_000_000L) epoch - System.currentTimeMillis() / 1000L else epoch
            return value.coerceIn(1, 20)
        }
        return 1L
    }

    suspend fun search(
        query: String = "",
        page: Int = 1,
        type: String = "all",
        latest: Boolean = false
    ): List<Series> = withContext(Dispatchers.IO) {
        val cleanQuery = canonicalTitle(query).trim()
        val mangaBaka = runCatching { searchMangaBaka(cleanQuery, page, type, latest) }.getOrDefault(emptyList())
        val mangaDex = if (type in setOf("all", "manga", "manhwa", "manhua", "webtoon")) {
            runCatching { searchMangaDex(cleanQuery, page, type, latest) }.getOrDefault(emptyList())
        } else emptyList()

        val merged = LinkedHashMap<String, Series>()
        mangaBaka.forEach { item ->
            if (item.contentRating == "safe" && !isPreSerialization(item.title)) {
                merged[normalizeTitle(item.title)] = item
            }
        }
        mangaDex.forEach { item ->
            if (item.contentRating != "safe" || isPreSerialization(item.title)) return@forEach
            val key = normalizeTitle(item.title)
            val existing = merged[key]
            merged[key] = if (existing != null) {
                existing.copy(
                    cover = existing.cover.ifBlank { item.cover },
                    coverLarge = existing.coverLarge.ifBlank { item.coverLarge.ifBlank { item.cover } },
                    description = existing.description.ifBlank { item.description },
                    author = existing.author.ifBlank { item.author },
                    mangaDexId = item.mangaDexId,
                    availableLanguages = item.availableLanguages
                )
            } else item
        }
        merged.values.toList()
    }

    private fun searchMangaBaka(
        query: String,
        page: Int,
        type: String,
        latest: Boolean
    ): List<Series> {
        if (type == "webtoon") return emptyList()
        val params = mutableListOf(
            "limit=24",
            "page=${page.coerceAtLeast(1)}",
            "content_rating=safe",
            "with_ignore_content_rating_count=true"
        )
        if (query.isNotBlank()) params += "q=${encode(query)}"
        else params += "sort_by=${if (latest) "latest" else "trending_7d"}"
        if (type != "all") {
            val apiType = if (type == "lightnovel") "novel" else type
            params += "type=${encode(apiType)}"
        }
        val json = requestJson("https://api.mangabaka.org/v2/series/search?${params.joinToString("&")}")
        val data = json.optJSONArray("data") ?: return emptyList()
        return (0 until data.length()).mapNotNull { index ->
            data.optJSONObject(index)?.let(Series::fromMangaBaka)
        }
    }

    private fun searchMangaDex(
        query: String,
        page: Int,
        type: String,
        latest: Boolean
    ): List<Series> {
        val params = mutableListOf(
            "limit=24",
            "offset=${(page.coerceAtLeast(1) - 1) * 24}",
            "contentRating%5B%5D=safe",
            "includes%5B%5D=cover_art",
            "includes%5B%5D=author"
        )
        if (query.isNotBlank()) {
            params += "title=${encode(query)}"
            params += "order%5Brelevance%5D=desc"
        } else if (latest) {
            params += "order%5BlatestUploadedChapter%5D=desc"
        } else {
            params += "order%5BfollowedCount%5D=desc"
        }
        when (type) {
            "manga" -> params += "originalLanguage%5B%5D=ja"
            "manhwa" -> params += "originalLanguage%5B%5D=ko"
            "manhua" -> params += "originalLanguage%5B%5D=zh"
            "all", "webtoon" -> {
                params += "originalLanguage%5B%5D=ja"
                params += "originalLanguage%5B%5D=ko"
                params += "originalLanguage%5B%5D=zh"
            }
            else -> return emptyList()
        }
        if (type == "webtoon") {
            params += "includedTags%5B%5D=e197df38-d0e7-43b5-9b09-2842d0c326dd"
        }
        val json = requestJson("https://api.mangadex.org/manga?${params.joinToString("&")}", mangaDex = true)
        val data = json.optJSONArray("data") ?: return emptyList()
        return (0 until data.length()).mapNotNull { index ->
            data.optJSONObject(index)?.let(Series::fromMangaDex)
        }
    }

    suspend fun matchMangaDex(item: Series): Series? = withContext(Dispatchers.IO) {
        val query = canonicalTitle(item.title)
        if (query.isBlank() || isPreSerialization(query)) return@withContext null
        val params = listOf(
            "limit=100",
            "title=${encode(query)}",
            "contentRating%5B%5D=safe",
            "includes%5B%5D=cover_art",
            "includes%5B%5D=author",
            "order%5Brelevance%5D=desc"
        )
        val data = runCatching {
            requestJson("https://api.mangadex.org/manga?${params.joinToString("&")}", mangaDex = true)
                .optJSONArray("data") ?: JSONArray()
        }.getOrElse { return@withContext null }

        val target = normalizeTitle(query)
        val matches = mutableListOf<Series>()
        for (i in 0 until data.length()) {
            val row = data.optJSONObject(i) ?: continue
            val candidate = Series.fromMangaDex(row) ?: continue
            if (isPreSerialization(candidate.title)) continue
            val attributes = row.optJSONObject("attributes") ?: continue
            val names = mutableListOf<String>()
            val titles = attributes.optJSONObject("title")
            if (titles != null) titles.keys().forEach { names += titles.optString(it) }
            val alternatives = attributes.optJSONArray("altTitles")
            if (alternatives != null) {
                for (j in 0 until alternatives.length()) {
                    val obj = alternatives.optJSONObject(j) ?: continue
                    obj.keys().forEach { names += obj.optString(it) }
                }
            }
            if (names.none { normalizeTitle(it) == target }) continue
            matches += candidate
        }
        matches.sortedByDescending { candidateScore(it, item) }.firstOrNull()
    }

    private fun candidateScore(candidate: Series, source: Series): Int {
        var score = 0
        if (candidate.availableLanguages.contains("id")) score += 8
        if (source.language != "unknown" && candidate.language == source.language) score += 4
        if (source.type != "other" && candidate.type == source.type) score += 3
        if (candidate.coverLarge.isNotBlank()) score++
        return score
    }

    suspend fun fullMetadata(item: Series): Series? = withContext(Dispatchers.IO) {
        val canonical = canonicalTitle(item.title)
        val id = item.mangaBakaId ?: runCatching {
            searchMangaBaka(canonical, 1, "all", latest = false)
                .firstOrNull { normalizeTitle(it.title) == normalizeTitle(canonical) }
                ?.mangaBakaId
        }.getOrNull() ?: return@withContext null
        var currentId = id
        repeat(3) { depth ->
            val response = runCatching {
                requestJson("https://api.mangabaka.org/v2/series/$currentId?schema=full")
            }.getOrNull() ?: return@withContext null
            val raw = response.optJSONObject("data") ?: response
            if (raw.optString("state").equals("merged", true)) {
                val next = raw.optInt("merged_with")
                if (next > 0 && next != currentId && depth < 2) {
                    currentId = next
                    return@repeat
                }
                return@withContext null
            }
            return@withContext Series.fromMangaBaka(raw)
        }
        null
    }

    suspend fun chapters(
        mangaId: String,
        language: String = "id",
        offset: Int = 0
    ): Pair<List<Chapter>, Boolean> = withContext(Dispatchers.IO) {
        require(UUID_PATTERN.matches(mangaId)) { "ID seri MangaDex tidak valid." }
        require(offset >= 0) { "Offset chapter tidak valid." }

        fun fetchFeed(languageCode: String): List<Chapter> {
            val params = mutableListOf(
                "limit=100",
                "offset=$offset",
                "contentRating%5B%5D=safe",
                "includes%5B%5D=scanlation_group",
                "order%5Bvolume%5D=desc",
                "order%5Bchapter%5D=desc"
            )
            if (languageCode != "all") {
                params += "translatedLanguage%5B%5D=${encode(languageCode)}"
            }
            val json = requestJson(
                "https://api.mangadex.org/manga/$mangaId/feed?${params.joinToString("&")}",
                mangaDex = true
            )
            val data = json.optJSONArray("data") ?: return emptyList()
            return (0 until data.length()).mapNotNull { index ->
                val row = data.optJSONObject(index) ?: return@mapNotNull null
                val attrs = row.optJSONObject("attributes") ?: return@mapNotNull null
                if (attrs.optInt("pages") <= 0 || attrs.optString("contentRating", "safe") != "safe") {
                    return@mapNotNull null
                }
                var group = ""
                val relationships = row.optJSONArray("relationships")
                if (relationships != null) {
                    for (j in 0 until relationships.length()) {
                        val rel = relationships.optJSONObject(j) ?: continue
                        if (rel.optString("type") == "scanlation_group") {
                            group = rel.optJSONObject("attributes")?.optString("name").orEmpty()
                        }
                    }
                }
                Chapter(
                    id = row.optString("id"),
                    number = attrs.optString("chapter", "Oneshot"),
                    title = attrs.optString("title"),
                    language = attrs.optString("translatedLanguage", "unknown"),
                    pageCount = attrs.optInt("pages"),
                    group = group
                ).takeIf { UUID_PATTERN.matches(it.id) && it.pageCount > 0 }
            }
        }

        var chapters = fetchFeed(language)
        var usedFallback = false
        if (offset == 0 && language == "id" && chapters.isEmpty()) {
            chapters = fetchFeed("all")
            usedFallback = chapters.isNotEmpty()
        }
        chapters to usedFallback
    }

    suspend fun chapterPages(chapterId: String, dataSaver: Boolean = true): List<String> =
        withContext(Dispatchers.IO) {
            require(UUID_PATTERN.matches(chapterId)) { "ID chapter tidak valid." }
            val json = requestJson("https://api.mangadex.org/at-home/server/$chapterId", mangaDex = true)
            val chapter = json.optJSONObject("chapter") ?: error("Data halaman tidak dikenali.")
            val base = json.optString("baseUrl")
            val baseUri = runCatching { java.net.URI(base) }.getOrNull()
            require(baseUri != null && baseUri.scheme == "https" &&
                !baseUri.host.isNullOrBlank() && baseUri.userInfo.isNullOrBlank()) {
                "Alamat gambar tidak aman."
            }
            val hash = chapter.optString("hash")
            val files = chapter.optJSONArray(if (dataSaver) "dataSaver" else "data")
                ?: error("Halaman chapter tidak tersedia.")
            val quality = if (dataSaver) "data-saver" else "data"
            (0 until files.length()).mapNotNull { index ->
                val name = files.optString(index)
                if (name.isBlank() || name.contains("..") || name.contains('/') || name.contains('\\')) {
                    null
                } else "$base/$quality/$hash/${encodePath(name)}"
            }
        }

    private fun encode(value: String): String =
        URLEncoder.encode(value, StandardCharsets.UTF_8.toString())

    private fun encodePath(value: String): String =
        java.net.URLEncoder.encode(value, StandardCharsets.UTF_8.toString()).replace("+", "%20")

    companion object {
        private val UUID_PATTERN = Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
    }
}
