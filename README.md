# ManhwaKu

Flutter Android app for Android 10+ (application ID: com.manhwaku.reader).

## Features
- Native dark discovery home inspired by modern comic-reader apps.
- Live catalogue search and trending/latest discovery for manga, manhwa, manhua, and novels.
- Safe-content and licensed-entry filters on the catalogue query.
- Series details, covers, synopsis, author, status, and rating where supplied by the catalogue.
- On-device favourites and reading history using SharedPreferences.
- Source-page WebView with loading state, retry, and external-browser fallback.
- Responsive three-column catalogue grid and horizontal featured carousel.

## Content and licensing
ManhwaKu is a discovery/catalogue client, not a chapter-hosting service. It does not download, scrape, bundle, or redistribute third-party chapters. Tapping a title opens its catalogue/source page; chapter access, regional availability, account requirements, and paid/free rules remain controlled by the publisher or platform.

Catalogue metadata is requested from the public MangaBaka API. Requests explicitly filter to the safe content rating and is_licensed=true. MangaBaka data is subject to its licence and attribution requirements; third-party fields remain subject to their respective providers' terms. See https://mangabaka.org/developers/concepts/license-and-attribution.

## Build
GitHub Actions resolves Flutter dependencies, runs flutter analyze and flutter test, builds a release APK, and uploads the ManhwaKu-online-reader-release artifact.
