# ManhwaKu

Flutter Android app for Android 10+ (application ID: com.manhwaku.reader).

## Features
- Native dark discovery home with a horizontal featured shelf and three-column catalogue grid.
- Live catalogue discovery for manga, manhwa, manhua, novels/light novels, OEL and other media types.
- Search by series title, safe-content filter, trending/latest/popularity sorting, and paged loading.
- Series details with available cover, synopsis, author, status, and score metadata.
- WEBTOON Indonesia featured series shortcuts and a direct in-app view of its popular ranking.
- On-device favourites and reading history using SharedPreferences.
- Native MangaDex chapter list and image reader for safe-rated supported titles.
- HTTPS publisher links from MangaBaka metadata when explicitly tagged as publisher.
- Modular source adapters, request deduplication, memory/disk cache and bounded retry for transient API errors.

## Catalogue and reading
Catalogue data is fetched online from the public MangaBaka API. The client requests the safe content rating and exposes additional result pages with the API's documented 25-item page limit. The client does not apply the English-only licensed-series filter, because MangaBaka documents that its licence flag currently tracks English editions only. The API is a metadata catalogue, not a chapter file host; coverage is not exhaustive and changes as providers update their data.

ManhwaKu does not download, scrape, bundle, or redistribute third-party chapters. Reading links, regional availability, login requirements and paid/free access remain controlled by each publisher or platform. WEBTOON titles open through their official WEBTOON pages.

MangaBaka data is subject to CC BY-NC-SA 4.0 and attribution requirements; third-party fields have separate, more restrictive terms. See https://mangabaka.org/about/data-license.

## Build
GitHub Actions runs Flutter analysis and widget tests, builds a release APK, and uploads the ManhwaKu-online-reader-release artifact.


## Catalog sources (v2.4)

ManhwaKu aggregates metadata from MangaBaka and MangaDex. Only entries with an explicit safe rating are displayed in the safe catalogue. The app does not scrape third-party websites or embed third-party pages. Source terms and attribution requirements apply; MangaBaka data is for personal/non-commercial use unless separately licensed. The public catalog endpoints do not require end-user API keys.


## v2.5.0 updates

- Safe-rated metadata catalog from MangaBaka, MangaDex, and Jikan.
- Native chapter list and reader for MangaDex titles explicitly rated safe; Indonesian and English chapter lists; data-saver image mode; vertical and paged reading modes; scanlation-group attribution.
- Local reading shelves: Reading, Planned, Completed, and Dropped.
- Lazy tab creation prevents unused catalog tabs from making requests during cold launch.
- ARM split APKs are built for armeabi-v7a and arm64-v8a. Android 10+ requires no manual multidex configuration.

MangaDex acceptable-use requirements apply: credit MangaDex and chapter groups, honor removal requests, and do not add advertisements or paid services when using its API. MangaBaka is for personal/non-commercial use with attribution. Public metadata endpoints do not require an end-user API key.


## v2.6.1 fixes

- Catalog requests run through MangaBaka v2 and MangaDex with seven-second per-provider timeouts; Jikan is not on the blocking first-load route.
- Memory + disk metadata cache allows a warm start to show saved results immediately and refresh in the background.
- Explicit pull-to-refresh and retry actions bypass stale catalog cache.
- Full MangaBaka detail records can enrich missing synopsis/cover metadata when a matching safe record ID is present; detail enrichment runs in the background and never blocks opening the details page.
- MangaDex chapter language selection is driven by availableTranslatedLanguages and the original language, so Korean titles can default to the original language when Indonesian chapters are absent.
- Chapter reader images and covers are disk cached and downsampled for lower-memory Android devices.
- MangaDex and MangaBaka tags are checked against additional restricted-content labels when those tags are present in the response; content-rating safe remains a separate provider rating, not a universal maturity guarantee.

Provider limits and licenses remain in force. MangaBaka data is personal/non-commercial with attribution. MangaDex API use requires provider and scanlation-group attribution and must follow its acceptable-use policy.


## v2.6.2 fixes

- Background title matching can connect subtitles/alternate title editions to MangaBaka full metadata without blocking the search screen.
- MangaDex chapter list retries up to two alternate languages advertised on the title when the default first-open language has no safe chapter results.
- Chapter feed pages are cached in memory for two minutes to reduce repeat waits; manually selected language remains respected.
- Explicit refresh continues to bypass stale catalog metadata.
- Regression tests cover v2 multilingual parsing, source-synopsis fallback, tag filtering and local reading-status persistence.


## v2.8.0 reliability and source architecture

- Live catalogue providers use independent adapter classes for the documented MangaDex and MangaBaka public APIs.
- AniList is intentionally not integrated because its current API terms prohibit use in competing, non-complementary manga list/tracker services. Jikan remains an inactive mapping helper and is not represented as a live source.
- Missing content ratings now become `unknown`, never `safe`; unknown and restricted records are excluded from the safe catalogue.
- The MangaBaka full-record lookup may contribute a publisher URL only when the record explicitly marks it as `publisher` and the URL uses HTTPS.
- Transient 429/502/503/504 responses receive at most one bounded retry. Long or unrecognized `Retry-After` values are not overridden.
- The chapter screen offers an available publisher page when the supported chapter source has no safe chapters. It does not invent counts or silently substitute a different series.
- MangaDex attribution, scanlation-group credit, removal requests, and no-ads/no-paid-services requirements remain in force.



## v2.9.0 language and artwork polish

- Indonesian (`id`) is the first/default MangaDex chapter language. Other languages remain optional; an empty Indonesian feed is explained instead of silently switching languages.
- MangaBaka cover metadata uses the documented 2x variant for catalogue cards and 3x variant for detail views when available.
- MangaDex keeps its 512px thumbnail for catalogue cards and exposes the original cover only on the detail page. Decoded detail images are bounded to 720px.
- The detail hero no longer enlarges the portrait cover as a blurry full-width background. It uses a glossy navy/cyan/purple gradient that avoids expensive image blur on low-end devices.
- Publisher and reading-platform links use the documented `links_v2` schema and are exposed only when marked active, trusted/official, and HTTPS.
- Unofficial mirrors, unverified private APIs, and third-party HTML scraping are not integrated. MangaDex remains the connected chapter feed; MangaBaka is used for metadata only.

