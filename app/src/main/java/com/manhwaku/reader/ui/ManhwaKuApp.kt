package com.manhwaku.reader.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.RowScope
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.BookmarkBorder
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FavoriteBorder
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.OpenInNew
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Translate
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.Visibility
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil.compose.AsyncImage
import coil.request.ImageRequest
import com.manhwaku.reader.data.Chapter
import com.manhwaku.reader.data.LibraryStore
import com.manhwaku.reader.data.ManhwaRepository
import com.manhwaku.reader.data.Series
import com.manhwaku.reader.data.canonicalTitle
import com.manhwaku.reader.data.normalizeTitle
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

private val Bg = Color(0xFF080D16)
private val Panel = Color(0xFF111A29)
private val Panel2 = Color(0xFF19263A)
private val Accent = Color(0xFF36C5F0)
private val AccentAlt = Color(0xFF9B8CFF)
private val Ink = Color(0xFFF4F7FC)
private val Muted = Color(0xFF8F9BAD)
private val Stroke = Color(0xFF26364B)

@Composable
fun ManhwaKuApp() {
    val context = LocalContext.current
    val repository = remember { ManhwaRepository() }
    val library = remember { LibraryStore(context) }
    val scope = rememberCoroutineScope()

    var tab by remember { mutableIntStateOf(0) }
    var selectedSeries by remember { mutableStateOf<Series?>(null) }
    var selectedChapter by remember { mutableStateOf<Chapter?>(null) }

    BackHandler(enabled = selectedChapter != null || selectedSeries != null) {
        if (selectedChapter != null) selectedChapter = null else selectedSeries = null
    }

    fun openSeries(item: Series) {
        library.addHistory(item)
        selectedSeries = item
    }

    when {
        selectedSeries != null && selectedChapter != null -> {
            ReaderScreen(
                series = selectedSeries!!,
                chapter = selectedChapter!!,
                repository = repository,
                onBack = { selectedChapter = null }
            )
        }
        selectedSeries != null -> {
            DetailScreen(
                initial = selectedSeries!!,
                repository = repository,
                library = library,
                onBack = { selectedSeries = null },
                onOpenChapter = { selectedChapter = it }
            )
        }
        else -> Scaffold(
            containerColor = Bg,
            bottomBar = {
                NavigationBar(
                    containerColor = Color(0xFF050A12),
                    contentColor = Ink,
                    tonalElevation = 0.dp
                ) {
                    val destinations = listOf(
                        "Home" to Icons.Default.Home,
                        "Jelajahi" to Icons.Default.Explore,
                        "Cari" to Icons.Default.Search,
                        "Koleksi" to Icons.Default.Bookmark,
                        "Riwayat" to Icons.Default.History
                    )
                    destinations.forEachIndexed { index, destination ->
                        NavigationBarItem(
                            selected = tab == index,
                            onClick = { tab = index },
                            icon = { Icon(destination.second, contentDescription = destination.first) },
                            label = { Text(destination.first, fontSize = 10.sp) },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = Accent,
                                selectedTextColor = Accent,
                                indicatorColor = Panel2,
                                unselectedIconColor = Muted,
                                unselectedTextColor = Muted
                            )
                        )
                    }
                }
            }
        ) { padding ->
            Box(Modifier.fillMaxSize().padding(padding)) {
                when (tab) {
                    0 -> HomeScreen(
                        repository = repository,
                        onOpen = ::openSeries,
                        onSearch = { tab = 2 },
                        onExplore = { tab = 1 },
                        onFavorites = { tab = 3 },
                        onHistory = { tab = 4 }
                    )
                    1 -> CatalogScreen(repository, initialType = "all", mode = "explore", onOpen = ::openSeries)
                    2 -> CatalogScreen(repository, initialType = "all", mode = "search", onOpen = ::openSeries)
                    3 -> LibraryScreen(library = library, onOpen = ::openSeries)
                    else -> HistoryScreen(library = library, onOpen = ::openSeries)
                }
            }
        }
    }
}

@Composable
private fun HomeScreen(
    repository: ManhwaRepository,
    onOpen: (Series) -> Unit,
    onSearch: () -> Unit,
    onExplore: () -> Unit,
    onFavorites: () -> Unit,
    onHistory: () -> Unit
) {
    var trending by remember { mutableStateOf<List<Series>>(emptyList()) }
    var latest by remember { mutableStateOf<List<Series>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var error by remember { mutableStateOf("") }

    suspend fun load() {
        loading = true
        error = ""
        try {
            val trendingResult = repository.search(page = 1, latest = false)
            val latestResult = repository.search(page = 1, latest = true)
            trending = trendingResult
            latest = latestResult
            if (trending.isEmpty() && latest.isEmpty()) error = "Katalog belum mengembalikan judul yang cocok."
        } catch (_: Exception) {
            error = "Katalog gagal dimuat. Periksa koneksi dan coba lagi."
        } finally {
            loading = false
        }
    }

    LaunchedEffect(Unit) { load() }

    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 20.dp)
    ) {
        item {
            Row(
                modifier = Modifier.fillMaxWidth().padding(start = 18.dp, end = 12.dp, top = 16.dp, bottom = 12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Box(
                    Modifier.size(42.dp).clip(RoundedCornerShape(13.dp))
                        .background(Brush.linearGradient(listOf(Accent, Color(0xFF6488FF)))),
                    contentAlignment = Alignment.Center
                ) { Icon(Icons.Default.MenuBook, null, tint = Bg, modifier = Modifier.size(25.dp)) }
                Spacer(Modifier.width(11.dp))
                Column(Modifier.weight(1f)) {
                    Text("ManhwaKu", color = Ink, fontSize = 21.sp, fontWeight = FontWeight.Black)
                    Text("Temukan bacaan berikutnya", color = Muted, fontSize = 10.sp)
                }
                IconButton(onClick = onSearch) { Icon(Icons.Default.Search, "Cari", tint = Ink) }
                IconButton(onClick = { }) { Icon(Icons.Default.Info, "Tentang", tint = Muted) }
            }
        }
        item {
            Surface(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp).clickable(onClick = onSearch),
                color = Panel,
                shape = RoundedCornerShape(15.dp),
                border = androidx.compose.foundation.BorderStroke(1.dp, Stroke)
            ) {
                Row(Modifier.padding(horizontal = 14.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Default.Search, null, tint = Muted)
                    Spacer(Modifier.width(10.dp))
                    Text("Cari judul manga, manhwa, atau manhua", color = Muted, fontSize = 12.sp)
                }
            }
        }
        item {
            Row(Modifier.fillMaxWidth().padding(horizontal = 17.dp, vertical = 16.dp)) {
                QuickAction("Kategori", Icons.Default.Explore, onExplore)
                QuickAction("Favorit", Icons.Default.Favorite, onFavorites)
                QuickAction("Riwayat", Icons.Default.History, onHistory)
                QuickAction("Cari", Icons.Default.Search, onSearch)
            }
        }
        if (loading && trending.isEmpty() && latest.isEmpty()) {
            item { LoadingState("Memuat katalog…") }
        } else if (error.isNotBlank() && trending.isEmpty() && latest.isEmpty()) {
            item { ErrorState(error, "Coba lagi") { kotlinx.coroutines.MainScope().launch { load() } } }
        } else {
            if (trending.isNotEmpty()) {
                item { SectionTitle("Sedang populer", "Jelajahi", onExplore) }
                item { HeroShelf(trending.take(8), onOpen) }
            }
            if (latest.isNotEmpty()) {
                item { SectionTitle("Baru diperbarui", "Lihat semua", onExplore) }
                item { HorizontalShelf(latest.take(12), onOpen) }
            }
            if (trending.isNotEmpty()) {
                item { SectionTitle("Pilihan lainnya", "Jelajahi", onExplore) }
                item { HorizontalShelf(trending.drop(5).take(12), onOpen) }
            }
            if (error.isNotBlank()) {
                item { Text(error, color = Muted, fontSize = 11.sp, modifier = Modifier.padding(18.dp)) }
            }
        }
        item {
            Text(
                "Metadata: MangaBaka · Chapter: MangaDex · Konten dengan rating aman saja",
                color = Muted,
                fontSize = 9.sp,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 20.dp)
            )
        }
    }
}

@Composable
private fun RowScope.QuickAction(label: String, icon: androidx.compose.ui.graphics.vector.ImageVector, onClick: () -> Unit) {
    Column(
        modifier = Modifier.weight(1f).clickable(onClick = onClick).padding(vertical = 5.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            Modifier.size(48.dp).clip(RoundedCornerShape(16.dp)).background(Panel),
            contentAlignment = Alignment.Center
        ) { Icon(icon, null, tint = Accent, modifier = Modifier.size(21.dp)) }
        Spacer(Modifier.height(6.dp))
        Text(label, color = Muted, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun SectionTitle(title: String, action: String, onAction: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(start = 18.dp, end = 14.dp, top = 22.dp, bottom = 11.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(title, color = Ink, fontSize = 17.sp, fontWeight = FontWeight.ExtraBold, modifier = Modifier.weight(1f))
        TextButton(onClick = onAction, contentPadding = PaddingValues(horizontal = 6.dp)) {
            Text(action, color = Accent, fontSize = 10.sp, fontWeight = FontWeight.Bold)
        }
    }
}

@Composable
private fun HeroShelf(items: List<Series>, onOpen: (Series) -> Unit) {
    LazyRow(
        contentPadding = PaddingValues(horizontal = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        items(items, key = { it.id }) { item ->
            Row(
                Modifier.width(300.dp).height(178.dp).clip(RoundedCornerShape(18.dp))
                    .background(Brush.linearGradient(listOf(Color(0xFF18324A), Color(0xFF101725))))
                    .clickable { onOpen(item) }.padding(14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                SeriesCover(item.cover, Modifier.width(104.dp).fillMaxHeight(), true)
                Spacer(Modifier.width(13.dp))
                Column(Modifier.weight(1f), verticalArrangement = Arrangement.Center) {
                    Text(typeLabel(item.type).uppercase(), color = Accent, fontSize = 9.sp, fontWeight = FontWeight.Black)
                    Spacer(Modifier.height(7.dp))
                    Text(item.title, color = Ink, fontSize = 16.sp, fontWeight = FontWeight.Black, maxLines = 3, overflow = TextOverflow.Ellipsis)
                    Spacer(Modifier.height(7.dp))
                    Text(item.description.ifBlank { "Buka untuk melihat detail dan chapter yang tersedia." },
                        color = Muted, fontSize = 10.sp, maxLines = 3, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

@Composable
private fun HorizontalShelf(items: List<Series>, onOpen: (Series) -> Unit) {
    if (items.isEmpty()) {
        Text("Belum ada judul di bagian ini.", color = Muted, fontSize = 11.sp,
            modifier = Modifier.padding(horizontal = 18.dp, vertical = 8.dp))
        return
    }
    LazyRow(
        contentPadding = PaddingValues(horizontal = 14.dp),
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        items(items, key = { it.id }) { item ->
            Column(Modifier.width(112.dp).clickable { onOpen(item) }) {
                SeriesCover(item.cover, Modifier.fillMaxWidth().height(148.dp))
                Spacer(Modifier.height(7.dp))
                Text(item.title, color = Ink, fontSize = 11.sp, fontWeight = FontWeight.Bold,
                    maxLines = 2, overflow = TextOverflow.Ellipsis)
                Text(typeLabel(item.type), color = Muted, fontSize = 9.sp)
            }
        }
    }
}

@Composable
private fun CatalogScreen(
    repository: ManhwaRepository,
    initialType: String,
    mode: String,
    onOpen: (Series) -> Unit
) {
    val isSearch = mode == "search"
    var query by remember { mutableStateOf("") }
    var selectedType by remember { mutableStateOf(initialType) }
    var items by remember { mutableStateOf<List<Series>>(emptyList()) }
    var page by remember { mutableIntStateOf(1) }
    var loading by remember { mutableStateOf(false) }
    var loadingMore by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    var searched by remember { mutableStateOf(!isSearch) }
    val scope = rememberCoroutineScope()

    val types = listOf("Semua" to "all", "Manhwa" to "manhwa", "Manga" to "manga", "Manhua" to "manhua")

    fun load(reset: Boolean, q: String = query) {
        if (loading || loadingMore) return
        val nextPage = if (reset) 1 else page + 1
        if (reset) {
            loading = true
            error = ""
            items = emptyList()
            page = 1
            searched = true
        } else loadingMore = true
        scope.launch {
            try {
                val found = repository.search(q, nextPage, selectedType, latest = !isSearch && q.isBlank())
                items = if (reset) found else (items + found).distinctBy { normalizeTitle(it.title) }
                page = nextPage
                if (found.isEmpty() && reset) error = "Tidak ada judul yang cocok dalam katalog aman."
            } catch (_: Exception) {
                error = "Pencarian gagal. Periksa koneksi lalu coba lagi."
            } finally {
                loading = false
                loadingMore = false
            }
        }
    }

    LaunchedEffect(Unit) {
        if (!isSearch) load(reset = true, q = "")
    }

    Column(Modifier.fillMaxSize().background(Bg)) {
        Text(
            if (isSearch) "Cari komik" else "Jelajahi",
            color = Ink, fontSize = 25.sp, fontWeight = FontWeight.Black,
            modifier = Modifier.padding(start = 18.dp, end = 18.dp, top = 16.dp, bottom = 12.dp)
        )
        if (isSearch) {
            Row(Modifier.fillMaxWidth().padding(horizontal = 15.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    placeholder = { Text("Masukkan judul…", color = Muted, fontSize = 12.sp) },
                    leadingIcon = { Icon(Icons.Default.Search, null, tint = Muted) },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedTextColor = Ink, unfocusedTextColor = Ink,
                        focusedBorderColor = Accent, unfocusedBorderColor = Stroke,
                        focusedContainerColor = Panel, unfocusedContainerColor = Panel
                    ),
                    shape = RoundedCornerShape(14.dp)
                )
                Spacer(Modifier.width(7.dp))
                Button(
                    onClick = { load(true, query.trim()) },
                    colors = ButtonDefaults.buttonColors(containerColor = Accent),
                    shape = RoundedCornerShape(13.dp),
                    contentPadding = PaddingValues(horizontal = 13.dp, vertical = 14.dp)
                ) { Text("Cari", color = Bg, fontWeight = FontWeight.Black) }
            }
        }
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 12.dp, vertical = 10.dp),
            horizontalArrangement = Arrangement.spacedBy(7.dp)
        ) {
            types.forEach { (label, value) ->
                FilterChip(
                    selected = selectedType == value,
                    onClick = {
                        selectedType = value
                        load(reset = true)
                    },
                    label = { Text(label, fontSize = 11.sp) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = Accent,
                        selectedLabelColor = Bg,
                        containerColor = Panel,
                        labelColor = Ink
                    ),
                    border = FilterChipDefaults.filterChipBorder(
                        enabled = true, selected = selectedType == value,
                        borderColor = Stroke, selectedBorderColor = Accent
                    )
                )
            }
        }
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 2.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(if (items.isEmpty()) "Katalog" else "${items.size} judul",
                color = Muted, fontSize = 10.sp, modifier = Modifier.weight(1f))
            IconButton(onClick = { load(true) }) { Icon(Icons.Default.Refresh, "Muat ulang", tint = Muted) }
        }

        when {
            !searched -> EmptyState("Temukan cerita", "Cari berdasarkan judul atau pilih jenis komik.", null) {}
            loading && items.isEmpty() -> LoadingState("Mencari judul…")
            error.isNotBlank() && items.isEmpty() -> ErrorState(error, "Coba lagi") { load(true) }
            items.isEmpty() -> EmptyState("Belum ada hasil", error.ifBlank { "Coba kata kunci atau jenis yang berbeda." }, "Muat ulang") { load(true) }
            else -> {
                LazyVerticalGrid(
                    columns = GridCells.Fixed(3),
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(start = 13.dp, end = 13.dp, top = 7.dp, bottom = 8.dp),
                    horizontalArrangement = Arrangement.spacedBy(9.dp),
                    verticalArrangement = Arrangement.spacedBy(15.dp)
                ) {
                    items(items, key = { it.id }) { item -> SeriesCard(item, onOpen) }
                    if (loadingMore) item { Box(Modifier.fillMaxWidth().padding(10.dp), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = Accent, strokeWidth = 2.dp, modifier = Modifier.size(20.dp))
                    } }
                }
                if (error.isNotBlank()) Text(error, color = Muted, fontSize = 10.sp, modifier = Modifier.padding(horizontal = 17.dp))
                if (items.isNotEmpty()) {
                    OutlinedButton(
                        onClick = { load(false) },
                        enabled = !loadingMore && !loading,
                        modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = Accent),
                        border = androidx.compose.foundation.BorderStroke(1.dp, Stroke)
                    ) { Text(if (loadingMore) "Memuat…" else "Muat lebih banyak") }
                }
            }
        }
    }
}

@Composable
private fun LibraryScreen(library: LibraryStore, onOpen: (Series) -> Unit) {
    var filter by remember { mutableStateOf("favorites") }
    var items by remember { mutableStateOf(library.favorites()) }
    LaunchedEffect(filter) {
        items = if (filter == "favorites") library.favorites() else library.readingStatusList(filter)
    }
    Column(Modifier.fillMaxSize().background(Bg)) {
        Text("Koleksi", color = Ink, fontSize = 25.sp, fontWeight = FontWeight.Black,
            modifier = Modifier.padding(start = 18.dp, end = 18.dp, top = 16.dp, bottom = 10.dp))
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()).padding(horizontal = 12.dp, vertical = 6.dp),
            horizontalArrangement = Arrangement.spacedBy(7.dp)
        ) {
            listOf(
                "Favorit" to "favorites",
                "Dibaca" to "reading",
                "Rencana" to "planned",
                "Selesai" to "completed",
                "Dihentikan" to "dropped"
            ).forEach { (label, key) ->
                FilterChip(
                    selected = filter == key,
                    onClick = { filter = key },
                    label = { Text(label, fontSize = 10.sp) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = Accent, selectedLabelColor = Bg,
                        containerColor = Panel, labelColor = Ink
                    )
                )
            }
        }
        if (items.isEmpty()) {
            EmptyState("Belum ada koleksi", "Simpan judul ke favorit atau atur status bacaan dari halaman detail.", null) {}
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(3),
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(13.dp),
                horizontalArrangement = Arrangement.spacedBy(9.dp),
                verticalArrangement = Arrangement.spacedBy(15.dp)
            ) { items(items, key = { it.id }) { SeriesCard(it, onOpen) } }
        }
    }
}

@Composable
private fun HistoryScreen(library: LibraryStore, onOpen: (Series) -> Unit) {
    var items by remember { mutableStateOf(library.history()) }
    LaunchedEffect(Unit) { items = library.history() }
    Column(Modifier.fillMaxSize().background(Bg)) {
        Text("Riwayat", color = Ink, fontSize = 25.sp, fontWeight = FontWeight.Black,
            modifier = Modifier.padding(start = 18.dp, end = 18.dp, top = 16.dp, bottom = 10.dp))
        if (items.isEmpty()) {
            EmptyState("Riwayat masih kosong", "Judul yang dibuka akan tersimpan di sini.", null) {}
        } else {
            LazyColumn(contentPadding = PaddingValues(14.dp), verticalArrangement = Arrangement.spacedBy(9.dp)) {
                items(items, key = { it.id }) { item ->
                    Row(
                        Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp))
                            .background(Panel).clickable { onOpen(item) }.padding(9.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        SeriesCover(item.cover, Modifier.size(62.dp, 82.dp))
                        Spacer(Modifier.width(12.dp))
                        Column(Modifier.weight(1f)) {
                            Text(item.title, color = Ink, fontWeight = FontWeight.Bold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            Text(typeLabel(item.type) + " · " + statusLabel(item.status), color = Muted, fontSize = 10.sp)
                        }
                        Icon(Icons.Default.Visibility, null, tint = Accent)
                    }
                }
            }
        }
    }
}

@Composable
private fun SeriesCard(item: Series, onOpen: (Series) -> Unit) {
    Column(Modifier.fillMaxWidth().clickable { onOpen(item) }) {
        Box(Modifier.fillMaxWidth().height(154.dp)) {
            SeriesCover(item.cover, Modifier.fillMaxSize())
            Box(
                Modifier.align(Alignment.TopStart).padding(5.dp)
                    .clip(RoundedCornerShape(5.dp)).background(Accent).padding(horizontal = 6.dp, vertical = 3.dp)
            ) {
                Text(typeLabel(item.type).uppercase(), color = Bg, fontSize = 7.sp, fontWeight = FontWeight.Black)
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(item.title, color = Ink, fontSize = 10.sp, fontWeight = FontWeight.Bold,
            maxLines = 2, overflow = TextOverflow.Ellipsis, lineHeight = 13.sp)
        Text(statusLabel(item.status), color = Muted, fontSize = 8.sp, maxLines = 1)
    }
}

@Composable
private fun SeriesCover(url: String, modifier: Modifier = Modifier, large: Boolean = false) {
    if (url.isBlank()) {
        Box(modifier.clip(RoundedCornerShape(10.dp)).background(Panel2), contentAlignment = Alignment.Center) {
            Icon(Icons.Default.MenuBook, null, tint = Muted, modifier = Modifier.size(28.dp))
        }
    } else {
        AsyncImage(
            model = ImageRequest.Builder(LocalContext.current)
                .data(url)
                .memoryCacheKey("$url::manhwaku-native-v1")
                .diskCacheKey("$url::manhwaku-native-v1")
                .crossfade(120)
                .size(if (large) 720 else 480)
                .build(),
            contentDescription = null,
            modifier = modifier.clip(RoundedCornerShape(10.dp)).background(Panel2),
            contentScale = ContentScale.Crop
        )
    }
}

@Composable
private fun DetailScreen(
    initial: Series,
    repository: ManhwaRepository,
    library: LibraryStore,
    onBack: () -> Unit,
    onOpenChapter: (Chapter) -> Unit
) {
    var item by remember(initial.id) { mutableStateOf(initial) }
    var saved by remember(initial.id) { mutableStateOf(library.isFavorite(initial)) }
    var status by remember(initial.id) { mutableStateOf(library.readingStatus(initial)) }
    var tab by remember(initial.id) { mutableIntStateOf(0) }
    var menuStatus by remember { mutableStateOf(false) }
    var loadingMeta by remember(initial.id) { mutableStateOf(false) }
    var loadingMatch by remember(initial.id) { mutableStateOf(true) }
    var mangaDexId by remember(initial.id) { mutableStateOf<String?>(initial.mangaDexId) }
    var chapters by remember(initial.id) { mutableStateOf<List<Chapter>>(emptyList()) }
    var chaptersLoading by remember(initial.id) { mutableStateOf(false) }
    var chaptersError by remember(initial.id) { mutableStateOf("") }
    var selectedLanguage by remember(initial.id) { mutableStateOf("id") }
    var autoFallback by remember(initial.id) { mutableStateOf(false) }
    var hasMore by remember(initial.id) { mutableStateOf(false) }
    var moreLoading by remember(initial.id) { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val uriHandler = LocalUriHandler.current

    fun mergeMetadata(base: Series, extra: Series): Series = base.copy(
        title = if (base.title.contains("pre-serialization", true) && extra.title.isNotBlank()) extra.title else base.title,
        cover = extra.cover.ifBlank { base.cover },
        coverLarge = extra.coverLarge.ifBlank { base.coverLarge },
        description = extra.description.ifBlank { base.description },
        author = extra.author.ifBlank { base.author },
        status = if (base.status == "unknown") extra.status else base.status,
        rating = base.rating ?: extra.rating,
        mangaBakaId = base.mangaBakaId ?: extra.mangaBakaId,
        publisherUrl = extra.publisherUrl.ifBlank { base.publisherUrl }
    )

    LaunchedEffect(initial.id, initial.title) {
        loadingMeta = true
        loadingMatch = true
        val full = repository.fullMetadata(initial)
        if (full != null) item = mergeMetadata(item, full)
        val freshMatch = repository.matchMangaDex(initial.copy(title = canonicalTitle(initial.title)))
        mangaDexId = freshMatch?.mangaDexId
        if (freshMatch != null) {
            item = item.copy(
                title = if (item.title.contains("pre-serialization", true)) freshMatch.title else item.title,
                cover = freshMatch.cover.ifBlank { item.cover },
                coverLarge = freshMatch.coverLarge.ifBlank { item.coverLarge },
                description = item.description.ifBlank { freshMatch.description },
                author = item.author.ifBlank { freshMatch.author }
            )
        }
        loadingMeta = false
        loadingMatch = false
    }

    LaunchedEffect(mangaDexId, selectedLanguage) {
        val id = mangaDexId ?: return@LaunchedEffect
        chaptersLoading = true
        chaptersError = ""
        chapters = emptyList()
        autoFallback = false
        try {
            val result = repository.chapters(id, selectedLanguage, 0)
            chapters = result.first
            hasMore = result.first.size == 100
            if (result.second) {
                autoFallback = true
                selectedLanguage = "all"
            }
        } catch (error: Exception) {
            chaptersError = error.message ?: "Chapter gagal dimuat."
        } finally {
            chaptersLoading = false
        }
    }

    fun toggleFavorite() {
        saved = library.toggleFavorite(item)
    }

    fun changeStatus(value: String) {
        library.setReadingStatus(item, value)
        status = value
        menuStatus = false
    }

    Column(Modifier.fillMaxSize().background(Bg)) {
        Row(
            Modifier.fillMaxWidth().padding(start = 5.dp, end = 8.dp, top = 5.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "Kembali", tint = Ink) }
            Text(item.title, color = Ink, fontSize = 15.sp, fontWeight = FontWeight.Bold,
                maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            IconButton(onClick = ::toggleFavorite) {
                Icon(if (saved) Icons.Default.Favorite else Icons.Default.FavoriteBorder,
                    "Favorit", tint = if (saved) Color(0xFFFF6E8A) else Ink)
            }
        }

        Row(
            Modifier.fillMaxWidth().background(
                Brush.linearGradient(listOf(Color(0xFF18324A), Color(0xFF172239), Bg))
            ).padding(start = 18.dp, end = 16.dp, top = 15.dp, bottom = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            SeriesCover(item.coverLarge.ifBlank { item.cover }, Modifier.size(132.dp, 180.dp), true)
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Text(item.title, color = Ink, fontSize = 20.sp, lineHeight = 22.sp, fontWeight = FontWeight.Black,
                    maxLines = 3, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(7.dp))
                if (item.author.isNotBlank()) Text(item.author, color = Muted, fontSize = 11.sp, maxLines = 2)
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    DetailTag(typeLabel(item.type), Accent)
                    DetailTag(statusLabel(item.status), AccentAlt)
                }
                val rating = item.rating
                if (rating != null) {
                    Spacer(Modifier.height(8.dp))
                    Text("★ ${"%.1f".format(rating / 10.0)}", color = Color(0xFFFFC857), fontSize = 11.sp, fontWeight = FontWeight.Bold)
                }
            }
        }

        Row(
            Modifier.fillMaxWidth().padding(horizontal = 12.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically
        ) {
            DetailAction(if (saved) Icons.Default.Favorite else Icons.Default.FavoriteBorder, "Favorit", saved, ::toggleFavorite)
            Box {
                DetailAction(Icons.Default.BookmarkBorder, "Status", status != "none", { menuStatus = true })
                DropdownMenu(expanded = menuStatus, onDismissRequest = { menuStatus = false }) {
                    listOf(
                        "reading" to "Sedang dibaca",
                        "planned" to "Rencana baca",
                        "completed" to "Selesai",
                        "dropped" to "Dihentikan",
                        "none" to "Hapus status"
                    ).forEach { (key, label) ->
                        DropdownMenuItem(text = { Text(label) }, onClick = { changeStatus(key) })
                    }
                }
            }
            DetailAction(Icons.Default.OpenInNew, "Penerbit", false, {
                if (item.publisherUrl.isNotBlank()) runCatching { uriHandler.openUri(item.publisherUrl) }
            }, enabled = item.publisherUrl.isNotBlank())
        }

        TabRow(
            selectedTabIndex = tab,
            containerColor = Bg,
            contentColor = Accent,
            indicator = { tabPositions ->
                TabRowDefaults.Indicator(
                    modifier = Modifier.tabIndicatorOffset(tabPositions[tab]),
                    color = Accent, height = 3.dp
                )
            }
        ) {
            listOf("Info", "Chapters").forEachIndexed { index, label ->
                Tab(selected = tab == index, onClick = { tab = index }, text = {
                    Text(label, color = if (tab == index) Accent else Muted, fontWeight = FontWeight.Bold)
                })
            }
        }

        if (tab == 0) {
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(start = 18.dp, end = 18.dp, top = 16.dp, bottom = 30.dp)
            ) {
                item { Text("Sinopsis", color = Ink, fontSize = 17.sp, fontWeight = FontWeight.Black) }
                item {
                    Text(item.description.ifBlank { "Sinopsis belum tersedia." },
                        color = Color(0xFFD2D9E4), fontSize = 12.sp, lineHeight = 18.sp,
                        modifier = Modifier.padding(top = 9.dp))
                }
                if (loadingMeta) item {
                    LinearProgressIndicator(
                        modifier = Modifier.fillMaxWidth().padding(top = 10.dp),
                        color = Accent, trackColor = Panel
                    )
                }
                item { Spacer(Modifier.height(22.dp)); Text("Informasi", color = Ink, fontSize = 16.sp, fontWeight = FontWeight.Black) }
                item { InfoLine("Jenis", typeLabel(item.type)) }
                item { InfoLine("Status", statusLabel(item.status)) }
                if (item.author.isNotBlank()) item { InfoLine("Kreator", item.author) }
                if (item.language != "unknown") item { InfoLine("Bahasa asli", item.language.uppercase()) }
                item { InfoLine("Metadata", item.source) }
                if (item.publisherUrl.isNotBlank()) item {
                    OutlinedButton(
                        onClick = { runCatching { uriHandler.openUri(item.publisherUrl) } },
                        modifier = Modifier.fillMaxWidth().padding(top = 14.dp),
                        colors = ButtonDefaults.outlinedButtonColors(contentColor = Accent),
                        border = androidx.compose.foundation.BorderStroke(1.dp, Stroke)
                    ) {
                        Icon(Icons.Default.OpenInNew, null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(7.dp))
                        Text("Buka halaman penerbit resmi")
                    }
                }
                item {
                    Text(
                        "Metadata dari MangaBaka. Ketersediaan chapter bergantung pada bahasa dan sumber yang terhubung.",
                        color = Muted, fontSize = 9.sp, lineHeight = 13.sp, modifier = Modifier.padding(top = 20.dp)
                    )
                }
            }
        } else {
            Column(Modifier.weight(1f)) {
                Row(
                    Modifier.fillMaxWidth().padding(start = 16.dp, end = 8.dp, top = 9.dp, bottom = 5.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("Chapter", color = Ink, fontSize = 18.sp, fontWeight = FontWeight.Black, modifier = Modifier.weight(1f))
                    var languageMenu by remember { mutableStateOf(false) }
                    Box {
                        OutlinedButton(
                            onClick = { languageMenu = true },
                            contentPadding = PaddingValues(horizontal = 10.dp, vertical = 7.dp),
                            colors = ButtonDefaults.outlinedButtonColors(contentColor = Accent),
                            border = androidx.compose.foundation.BorderStroke(1.dp, Stroke)
                        ) {
                            Icon(Icons.Default.Translate, null, modifier = Modifier.size(16.dp))
                            Spacer(Modifier.width(6.dp))
                            Text(languageName(selectedLanguage), fontSize = 10.sp)
                        }
                        DropdownMenu(expanded = languageMenu, onDismissRequest = { languageMenu = false }) {
                            (listOf("id", "all", "en") + item.availableLanguages).distinct().forEach { language ->
                                DropdownMenuItem(
                                    text = { Text(languageName(language)) },
                                    onClick = { selectedLanguage = language; languageMenu = false }
                                )
                            }
                        }
                    }
                    IconButton(onClick = {
                        selectedLanguage = selectedLanguage
                        scope.launch {
                            chaptersLoading = true
                            try {
                                val result = repository.chapters(mangaDexId.orEmpty(), selectedLanguage, 0)
                                chapters = result.first
                                if (result.second) { autoFallback = true; selectedLanguage = "all" }
                                chaptersError = ""
                            } catch (e: Exception) {
                                chaptersError = e.message ?: "Chapter gagal dimuat."
                            } finally { chaptersLoading = false }
                        }
                    }) { Icon(Icons.Default.Refresh, "Muat ulang", tint = Ink) }
                }

                if (autoFallback) {
                    Row(Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                        Icon(Icons.Default.Info, null, tint = Accent, modifier = Modifier.size(14.dp))
                        Spacer(Modifier.width(6.dp))
                        Text("Chapter Indonesia tidak tersedia; menampilkan bahasa lain yang tersedia.",
                            color = Muted, fontSize = 9.sp)
                    }
                }

                when {
                    loadingMatch || chaptersLoading && chapters.isEmpty() -> LoadingState("Memuat daftar chapter…")
                    mangaDexId == null -> EmptyState(
                        "Sumber chapter belum terhubung",
                        "Judul tersedia di katalog, tetapi feed chapter belum ditemukan pada sumber yang terhubung.",
                        if (item.publisherUrl.isNotBlank()) "Buka penerbit" else null
                    ) {
                        if (item.publisherUrl.isNotBlank()) runCatching { uriHandler.openUri(item.publisherUrl) }
                    }
                    chaptersError.isNotBlank() && chapters.isEmpty() -> ErrorState(chaptersError, "Coba lagi") {
                        scope.launch {
                            chaptersLoading = true
                            try {
                                val result = repository.chapters(mangaDexId!!, selectedLanguage, 0)
                                chapters = result.first
                                if (result.second) { autoFallback = true; selectedLanguage = "all" }
                                chaptersError = ""
                            } catch (e: Exception) { chaptersError = e.message ?: "Chapter gagal dimuat." }
                            finally { chaptersLoading = false }
                        }
                    }
                    chapters.isEmpty() -> EmptyState(
                        "Belum ada chapter",
                        "Belum ada chapter aman pada bahasa yang dipilih. Coba Semua bahasa atau periksa halaman penerbit.",
                        if (item.publisherUrl.isNotBlank()) "Buka penerbit" else null
                    ) {
                        if (item.publisherUrl.isNotBlank()) runCatching { uriHandler.openUri(item.publisherUrl) }
                    }
                    else -> {
                        LazyColumn(
                            modifier = Modifier.weight(1f),
                            contentPadding = PaddingValues(horizontal = 14.dp, vertical = 3.dp),
                            verticalArrangement = Arrangement.spacedBy(2.dp)
                        ) {
                            items(chapters, key = { it.id }) { chapter ->
                                Row(
                                    Modifier.fillMaxWidth().clip(RoundedCornerShape(10.dp))
                                        .clickable { onOpenChapter(chapter) }
                                        .padding(horizontal = 4.dp, vertical = 7.dp),
                                    verticalAlignment = Alignment.CenterVertically
                                ) {
                                    SeriesCover(item.cover, Modifier.size(43.dp, 56.dp))
                                    Spacer(Modifier.width(10.dp))
                                    Column(Modifier.weight(1f)) {
                                        Text(
                                            if (chapter.number.isBlank()) "Chapter" else "Chapter ${chapter.number}" +
                                                if (chapter.title.isNotBlank()) " · ${chapter.title}" else "",
                                            color = Ink, fontSize = 12.sp, fontWeight = FontWeight.Bold,
                                            maxLines = 2, overflow = TextOverflow.Ellipsis
                                        )
                                        Text(
                                            "${languageName(chapter.language)} · ${chapter.pageCount} halaman" +
                                                if (chapter.group.isNotBlank()) " · ${chapter.group}" else "",
                                            color = Muted, fontSize = 9.sp, maxLines = 1, overflow = TextOverflow.Ellipsis
                                        )
                                    }
                                    Icon(Icons.Default.OpenInNew, null, tint = Accent, modifier = Modifier.size(16.dp))
                                }
                                HorizontalDivider(color = Stroke, thickness = .5.dp)
                            }
                            if (hasMore) item {
                                OutlinedButton(
                                    onClick = {
                                        scope.launch {
                                            moreLoading = true
                                            try {
                                                val result = repository.chapters(mangaDexId!!, selectedLanguage, chapters.size)
                                                chapters = (chapters + result.first).distinctBy { it.id }
                                                hasMore = result.first.size == 100
                                            } catch (e: Exception) { chaptersError = e.message ?: "Tidak dapat memuat chapter berikutnya." }
                                            finally { moreLoading = false }
                                        }
                                    },
                                    modifier = Modifier.fillMaxWidth().padding(vertical = 10.dp),
                                    colors = ButtonDefaults.outlinedButtonColors(contentColor = Accent),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, Stroke)
                                ) { Text(if (moreLoading) "Memuat…" else "Muat chapter berikutnya") }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ReaderScreen(
    series: Series,
    chapter: Chapter,
    repository: ManhwaRepository,
    onBack: () -> Unit
) {
    var pages by remember(chapter.id) { mutableStateOf<List<String>>(emptyList()) }
    var loading by remember(chapter.id) { mutableStateOf(true) }
    var error by remember(chapter.id) { mutableStateOf("") }
    var dataSaver by remember { mutableStateOf(true) }
    var verticalMode by remember(series.id) { mutableStateOf(series.type == "manhwa") }
    val scope = rememberCoroutineScope()

    suspend fun reload() {
        loading = true
        error = ""
        try {
            pages = repository.chapterPages(chapter.id, dataSaver)
            if (pages.isEmpty()) error = "Tidak ada halaman yang tersedia."
        } catch (e: Exception) {
            error = e.message ?: "Halaman gagal dimuat."
        } finally { loading = false }
    }

    LaunchedEffect(chapter.id, dataSaver) { reload() }

    Column(Modifier.fillMaxSize().background(Color.Black)) {
        Row(
            Modifier.fillMaxWidth().background(Color(0xFF05070C)).padding(horizontal = 4.dp, vertical = 5.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(onClick = onBack) { Icon(Icons.Default.ArrowBack, "Kembali", tint = Ink) }
            Column(Modifier.weight(1f)) {
                Text(series.title, color = Ink, fontSize = 12.sp, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                Text("Chapter ${chapter.number} · ${languageName(chapter.language)}",
                    color = Muted, fontSize = 9.sp)
            }
            IconButton(onClick = { verticalMode = !verticalMode }) {
                Icon(Icons.Default.MenuBook, "Ganti mode baca", tint = Accent)
            }
            IconButton(onClick = { dataSaver = !dataSaver }) {
                Icon(Icons.Default.Tune, if (dataSaver) "Hemat data" else "Kualitas tinggi", tint = if (dataSaver) Accent else AccentAlt)
            }
        }
        when {
            loading -> Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                CircularProgressIndicator(color = Accent)
            }
            error.isNotBlank() -> Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                EmptyState("Halaman gagal dimuat", error, "Muat ulang") { scope.launch { reload() } }
            }
            pages.isNotEmpty() && verticalMode -> {
                LazyColumn(Modifier.weight(1f).fillMaxWidth()) {
                    items(pages.size) { index ->
                        AsyncImage(
                            model = ImageRequest.Builder(LocalContext.current).data(pages[index])
                                .memoryCacheKey(pages[index]).diskCacheKey(pages[index])
                                .crossfade(100).size(1280).build(),
                            contentDescription = "Halaman ${index + 1}",
                            modifier = Modifier.fillMaxWidth(),
                            contentScale = ContentScale.FillWidth
                        )
                    }
                }
            }
            pages.isNotEmpty() -> PagedReader(pages, Modifier.weight(1f).fillMaxWidth())
        }
        Text(
            "Sumber: MangaDex · Grup: ${chapter.group.ifBlank { "tidak tercantum" }}",
            color = Muted, fontSize = 9.sp,
            modifier = Modifier.fillMaxWidth().background(Color(0xFF05070C)).padding(8.dp)
        )
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun PagedReader(pages: List<String>, modifier: Modifier = Modifier) {
    val pagerState = rememberPagerState(pageCount = { pages.size })
    Box(modifier.background(Color.Black)) {
        HorizontalPager(state = pagerState, modifier = Modifier.fillMaxSize()) { index ->
            AsyncImage(
                model = ImageRequest.Builder(LocalContext.current).data(pages[index])
                    .memoryCacheKey(pages[index]).diskCacheKey(pages[index])
                    .crossfade(100).size(1280).build(),
                contentDescription = "Halaman ${index + 1}",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Fit
            )
        }
        Text(
            "${pagerState.currentPage + 1} / ${pages.size}",
            color = Ink, fontSize = 10.sp,
            modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 12.dp)
                .clip(RoundedCornerShape(20.dp)).background(Color(0xAA111A29)).padding(horizontal = 12.dp, vertical = 6.dp)
        )
    }
}

@Composable
private fun DetailTag(text: String, color: Color) {
    Text(
        text, color = color, fontSize = 9.sp, fontWeight = FontWeight.Bold,
        modifier = Modifier.clip(RoundedCornerShape(20.dp))
            .background(color.copy(alpha = .12f))
            .padding(horizontal = 9.dp, vertical = 5.dp)
    )
}

@Composable
private fun DetailAction(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    active: Boolean,
    onClick: () -> Unit,
    enabled: Boolean = true
) {
    Column(
        modifier = Modifier.width(76.dp).clickable(enabled = enabled, onClick = onClick).padding(vertical = 4.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Box(
            Modifier.size(52.dp).clip(RoundedCornerShape(50)).background(Panel)
                .then(if (active) Modifier.background(Accent.copy(alpha = .08f)) else Modifier),
            contentAlignment = Alignment.Center
        ) { Icon(icon, null, tint = if (active) Accent else Ink, modifier = Modifier.size(23.dp)) }
        Spacer(Modifier.height(5.dp))
        Text(label, color = if (enabled) Muted else Muted.copy(alpha = .4f), fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
private fun InfoLine(label: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), verticalAlignment = Alignment.Top) {
        Text(label, color = Muted, fontSize = 11.sp, modifier = Modifier.width(100.dp))
        Text(value, color = Ink, fontSize = 11.sp, fontWeight = FontWeight.SemiBold, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun LoadingState(message: String) {
    Box(Modifier.fillMaxWidth().padding(26.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            CircularProgressIndicator(color = Accent, strokeWidth = 2.dp, modifier = Modifier.size(25.dp))
            Spacer(Modifier.height(12.dp))
            Text(message, color = Muted, fontSize = 11.sp)
        }
    }
}

@Composable
private fun EmptyState(title: String, message: String, action: String?, onAction: () -> Unit) {
    Box(Modifier.fillMaxWidth().padding(20.dp).heightIn(min = 210.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.size(64.dp).clip(RoundedCornerShape(20.dp)).background(Panel), contentAlignment = Alignment.Center) {
                Icon(Icons.Default.MenuBook, null, tint = Accent, modifier = Modifier.size(31.dp))
            }
            Spacer(Modifier.height(15.dp))
            Text(title, color = Ink, fontSize = 17.sp, fontWeight = FontWeight.Black)
            Spacer(Modifier.height(7.dp))
            Text(message, color = Muted, fontSize = 11.sp, lineHeight = 17.sp,
                modifier = Modifier.widthIn(max = 300.dp))
            if (action != null) {
                Spacer(Modifier.height(15.dp))
                Button(
                    onClick = onAction,
                    colors = ButtonDefaults.buttonColors(containerColor = Accent),
                    shape = RoundedCornerShape(24.dp)
                ) { Text(action, color = Bg, fontWeight = FontWeight.Bold) }
            }
        }
    }
}

@Composable
private fun ErrorState(message: String, action: String, onAction: () -> Unit) {
    EmptyState("Terjadi kendala", message, action, onAction)
}

private fun typeLabel(value: String): String = when (value.lowercase()) {
    "manga" -> "Manga"
    "manhwa" -> "Manhwa"
    "manhua" -> "Manhua"
    "novel" -> "Novel"
    "oel" -> "Komik original"
    "webtoon" -> "Webtoon"
    else -> "Komik"
}

private fun statusLabel(value: String): String = when (value.lowercase()) {
    "releasing" -> "Berjalan"
    "completed" -> "Tamat"
    "hiatus" -> "Hiatus"
    "upcoming" -> "Segera hadir"
    "cancelled" -> "Dibatalkan"
    "reading" -> "Sedang dibaca"
    "planned" -> "Rencana baca"
    "dropped" -> "Dihentikan"
    else -> "Status tidak diketahui"
}

private fun languageName(code: String): String = when (code.lowercase()) {
    "id" -> "Indonesia"
    "all" -> "Semua bahasa"
    "en" -> "English"
    "ko" -> "한국어"
    "ja" -> "日本語"
    "zh" -> "中文"
    "zh-hk" -> "中文 (HK)"
    "es" -> "Español"
    "pt-br" -> "Português (BR)"
    else -> code.uppercase()
}
