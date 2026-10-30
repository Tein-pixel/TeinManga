# ManhwaKu

Flutter Android app for Android 10+ (application ID: com.manhwaku.reader).

## Features
- Native dark discovery home with a horizontal featured shelf and three-column catalogue grid.
- Live catalogue discovery for manga, manhwa, manhua, novels/light novels, OEL and other media types.
- Search by series title, safe-content filter, trending/latest/popularity sorting, and paged loading.
- Series details with available cover, synopsis, author, status, and score metadata.
- WEBTOON Indonesia featured series shortcuts and a direct in-app view of its popular ranking.
- On-device favourites and reading history using SharedPreferences.
- Source-page WebView with loading state, retry, navigation and external-browser fallback.

## Catalogue and reading
Catalogue data is fetched online from the public MangaBaka API. The client requests the safe content rating and exposes additional result pages with the API's documented 25-item page limit. The client does not apply the English-only licensed-series filter, because MangaBaka documents that its licence flag currently tracks English editions only. The API is a metadata catalogue, not a chapter file host; coverage is not exhaustive and changes as providers update their data.

ManhwaKu does not download, scrape, bundle, or redistribute third-party chapters. Reading links, regional availability, login requirements and paid/free access remain controlled by each publisher or platform. WEBTOON titles open through their official WEBTOON pages.

MangaBaka data is subject to its non-commercial licence and attribution requirements. Third-party fields remain subject to their providers' terms. See https://mangabaka.org/developers/concepts/license-and-attribution.

## Build
GitHub Actions runs Flutter analysis and widget tests, builds a release APK, and uploads the ManhwaKu-online-reader-release artifact.
