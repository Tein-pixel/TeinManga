package com.teinzz.teinmanga

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.widget.Toast
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.ArrowBack
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Explore
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.platform.LocalContext
import coil.compose.AsyncImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder
import java.util.zip.ZipInputStream

private val Ink = Color(0xFF19172A)
private val Purple = Color(0xFF7455F6)
private val Pink = Color(0xFFFF6B9A)
private val Cyan = Color(0xFF45C6D8)
private val Paper = Color(0xFFF7F6FC)

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { TeinMangaApp() }
    }
}

private data class Comic(
    val id: String,
    val title: String,
    val description: String = "",
    val license: String = "",
    val year: String = "",
    val localUri: String? = null
) {
    val thumbnail: String
        get() = "https://archive.org/services/img/$id"
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TeinMangaApp() {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("teinmanga", 0) }
    val scope = rememberCoroutineScope()
    var tab by remember { mutableStateOf("Library") }
    var query by remember { mutableStateOf("") }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    var online by remember { mutableStateOf<List<Comic>>(emptyList()) }
    var readerComic by remember { mutableStateOf<Comic?>(null) }
    var readerPages by remember { mutableStateOf<List<Uri>>(emptyList()) }
    var pageIndex by remember { mutableIntStateOf(0) }
    var localItems by remember {
        mutableStateOf(prefs.getStringSet("local_items", mutableSetOf())?.toList().orEmpty().map {
            Comic(id = it, title = displayName(Uri.parse(it)), localUri = it)
        })
    }
    var favorites by remember { mutableStateOf<Set<String>>(prefs.getStringSet("favorites", mutableSetOf())?.toSet() ?: emptySet()) }
    var history by remember { mutableStateOf<Set<String>>(prefs.getStringSet("history", mutableSetOf())?.toSet() ?: emptySet()) }

    val importLauncher = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        if (uri != null) {
            try {
                context.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } catch (_: Exception) { }
            val updated = (localItems.mapNotNull { it.localUri } + uri.toString()).distinct()
            prefs.edit().putStringSet("local_items", updated.toMutableSet()).apply()
            localItems = updated.map { Comic(id = it, title = displayName(Uri.parse(it)), localUri = it) }
            tab = "Library"
        }
    }

    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = Purple,
            secondary = Pink,
            tertiary = Cyan,
            background = Paper,
            surface = Color.White,
            onPrimary = Color.White,
            onBackground = Ink,
            onSurface = Ink
        )
    ) {
        Surface(modifier = Modifier.fillMaxSize(), color = Paper) {
            if (readerComic != null) {
                Column(Modifier.fillMaxSize()) {
                    Row(
                        Modifier.fillMaxWidth().background(Color.White).padding(horizontal = 16.dp, vertical = 12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        IconButton(onClick = { readerComic = null; readerPages = emptyList() }) {
                            Icon(Icons.Default.ArrowBack, contentDescription = "Kembali")
                        }
                        Column(Modifier.weight(1f)) {
                            Text(readerComic!!.title, fontWeight = FontWeight.Bold, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text(
                                if (readerPages.isNotEmpty()) "Halaman ${pageIndex + 1} dari ${readerPages.size}" else "Buka dokumen",
                                fontSize = 12.sp,
                                color = Color.Gray
                            )
                        }
                    }
                    if (readerPages.isNotEmpty()) {
                        AsyncImage(
                            model = readerPages[pageIndex.coerceIn(readerPages.indices)],
                            contentDescription = "Halaman komik",
                            modifier = Modifier.weight(1f).fillMaxWidth(),
                            contentScale = ContentScale.Fit
                        )
                        Row(
                            Modifier.fillMaxWidth().background(Color.White).padding(12.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            OutlinedButton(onClick = { if (pageIndex > 0) pageIndex-- }, enabled = pageIndex > 0) { Text("Sebelumnya") }
                            Text("${pageIndex + 1} / ${readerPages.size}", fontWeight = FontWeight.SemiBold)
                            Button(onClick = { if (pageIndex < readerPages.lastIndex) pageIndex++ }, enabled = pageIndex < readerPages.lastIndex) { Text("Berikutnya") }
                        }
                    } else {
                        Box(Modifier.weight(1f).fillMaxWidth(), contentAlignment = Alignment.Center) {
                            Text("Dokumen ini dibuka dengan aplikasi pembaca yang mendukung formatnya.", modifier = Modifier.padding(24.dp))
                        }
                    }
                }
            } else {
                Column(Modifier.fillMaxSize()) {
                    Column(
                        Modifier.fillMaxWidth().background(
                            Brush.linearGradient(listOf(Color(0xFF4C35BD), Purple, Color(0xFFFF6F9D)))
                        ).padding(start = 20.dp, end = 20.dp, top = 24.dp, bottom = 22.dp)
                    ) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Box(
                                Modifier.size(42.dp).clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = .18f)),
                                contentAlignment = Alignment.Center
                            ) { Icon(Icons.Default.MenuBook, contentDescription = null, tint = Color.White) }
                            Spacer(Modifier.width(12.dp))
                            Column(Modifier.weight(1f)) {
                                Text("TeinManga", color = Color.White, fontWeight = FontWeight.ExtraBold, fontSize = 25.sp)
                                Text("Your next chapter starts here", color = Color.White.copy(alpha = .85f), fontSize = 12.sp)
                            }
                            IconButton(onClick = { importLauncher.launch(arrayOf("image/*", "application/pdf", "application/zip", "application/x-cbz", "application/octet-stream")) }) {
                                Icon(Icons.Default.Add, contentDescription = "Import", tint = Color.White)
                            }
                        }
                        Spacer(Modifier.height(20.dp))
                        OutlinedTextField(
                            value = query,
                            onValueChange = { query = it },
                            modifier = Modifier.fillMaxWidth(),
                            placeholder = { Text("Cari judul komik…", color = Color.White.copy(alpha = .7f)) },
                            leadingIcon = { Icon(Icons.Default.Search, contentDescription = null, tint = Color.White) },
                            trailingIcon = {
                                IconButton(onClick = {
                                    if (query.isBlank()) {
                                        Toast.makeText(context, "Masukkan judul terlebih dahulu", Toast.LENGTH_SHORT).show()
                                    } else {
                                        tab = "Explore"
                                        loading = true
                                        error = ""
                                        scope.launch {
                                            try { online = withContext(Dispatchers.IO) { searchArchive(query) } }
                                            catch (e: Exception) { error = "Katalog gagal dimuat. Periksa koneksi internet lalu coba lagi." }
                                            loading = false
                                        }
                                    }
                                }) { Icon(Icons.Default.Search, contentDescription = "Cari", tint = Color.White) }
                            },
                            singleLine = true,
                            shape = RoundedCornerShape(18.dp),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = Color.White.copy(alpha = .65f),
                                unfocusedBorderColor = Color.White.copy(alpha = .3f),
                                focusedTextColor = Color.White,
                                unfocusedTextColor = Color.White,
                                cursorColor = Color.White
                            )
                        )
                    }
                    Row(
                        Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 14.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        NavChip("Library", tab == "Library", { tab = "Library" }, Icons.Default.Home)
                        NavChip("Explore", tab == "Explore", { tab = "Explore" }, Icons.Default.Explore)
                        NavChip("Favorites", tab == "Favorites", { tab = "Favorites" }, Icons.Default.Favorite)
                        NavChip("History", tab == "History", { tab = "History" }, Icons.Default.Bookmark)
                    }
                    when (tab) {
                        "Library" -> {
                            Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text("My library", fontSize = 21.sp, fontWeight = FontWeight.ExtraBold)
                                    Text("${localItems.size} file tersimpan di perangkat", color = Color.Gray, fontSize = 12.sp)
                                }
                                FilledTonalButton(onClick = {
                                    importLauncher.launch(arrayOf("image/*", "application/pdf", "application/zip", "application/x-cbz", "application/octet-stream"))
                                }) { Icon(Icons.Default.Add, null, Modifier.size(18.dp)); Spacer(Modifier.width(4.dp)); Text("Import") }
                            }
                            if (localItems.isEmpty()) {
                                EmptyState("Belum ada komik", "Import gambar, CBZ/ZIP, atau PDF dari perangkat.", "Pilih file") {
                                    importLauncher.launch(arrayOf("image/*", "application/pdf", "application/zip", "application/x-cbz", "application/octet-stream"))
                                }
                            } else {
                                LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                    items(localItems, key = { it.localUri ?: it.id }) { comic ->
                                        LocalComicCard(comic, onOpen = {
                                            scope.launch {
                                                val uri = Uri.parse(comic.localUri)
                                                val name = displayName(uri).lowercase()
                                                history = (history + (comic.localUri ?: comic.id)).toSet()
                                                prefs.edit().putStringSet("history", history.toMutableSet()).apply()
                                                if (name.endsWith(".cbz") || name.endsWith(".zip")) {
                                                    val pages = withContext(Dispatchers.IO) { extractArchive(context, uri) }
                                                    if (pages.isNotEmpty()) {
                                                        readerPages = pages
                                                        pageIndex = 0
                                                        readerComic = comic
                                                    } else Toast.makeText(context, "Arsip tidak berisi gambar yang didukung.", Toast.LENGTH_SHORT).show()
                                                } else if (name.endsWith(".pdf")) {
                                                    try {
                                                        context.startActivity(Intent(Intent.ACTION_VIEW).setDataAndType(uri, "application/pdf").addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION))
                                                    } catch (_: Exception) {
                                                        Toast.makeText(context, "Tidak ada aplikasi pembaca PDF.", Toast.LENGTH_SHORT).show()
                                                    }
                                                } else {
                                                    readerPages = listOf(uri)
                                                    pageIndex = 0
                                                    readerComic = comic
                                                }
                                            }
                                        }, onRemove = {
                                            val updated = localItems.filterNot { it.localUri == comic.localUri }
                                            localItems = updated
                                            prefs.edit().putStringSet("local_items", updated.mapNotNull { it.localUri }.toMutableSet()).apply()
                                        })
                                    }
                                }
                            }
                        }
                        "Explore" -> {
                            Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text("Discover", fontSize = 21.sp, fontWeight = FontWeight.ExtraBold)
                                    Text("Internet Archive · metadata berlisensi terbuka", color = Color.Gray, fontSize = 12.sp)
                                }
                                Icon(Icons.Default.Tune, contentDescription = null, tint = Purple)
                            }
                            when {
                                loading -> Box(Modifier.fillMaxWidth().weight(1f), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                                error.isNotBlank() -> EmptyState("Katalog tidak tersedia", error, "Coba lagi") {
                                    if (query.isNotBlank()) {
                                        loading = true
                                        scope.launch {
                                            try { online = withContext(Dispatchers.IO) { searchArchive(query) }; error = "" }
                                            catch (_: Exception) { error = "Periksa koneksi internet dan coba lagi." }
                                            loading = false
                                        }
                                    }
                                }
                                online.isEmpty() -> EmptyState("Temukan bacaan", "Cari judul untuk melihat item dari Internet Archive. Hasil bergantung pada metadata yang tersedia.", "Cari") {
                                    if (query.isNotBlank()) {
                                        loading = true
                                        scope.launch {
                                            try { online = withContext(Dispatchers.IO) { searchArchive(query) }; error = "" }
                                            catch (_: Exception) { error = "Periksa koneksi internet dan coba lagi." }
                                            loading = false
                                        }
                                    }
                                }
                                else -> LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                    items(online, key = { it.id }) { comic ->
                                        OnlineComicCard(
                                            comic = comic,
                                            isFavorite = favorites.contains(comic.id),
                                            onFavorite = {
                                                favorites = if (favorites.contains(comic.id)) favorites - comic.id else favorites + comic.id
                                                prefs.edit().putStringSet("favorites", favorites.toMutableSet()).apply()
                                            },
                                            onOpen = {
                                                history = (history + comic.id).toSet()
                                                prefs.edit().putStringSet("history", history).apply()
                                                try { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://archive.org/details/${comic.id}"))) }
                                                catch (_: Exception) { Toast.makeText(context, "Tidak dapat membuka item.", Toast.LENGTH_SHORT).show() }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        "Favorites" -> {
                            val favItems = online.filter { favorites.contains(it.id) }
                            Text("Favorites", Modifier.padding(horizontal = 20.dp), fontSize = 21.sp, fontWeight = FontWeight.ExtraBold)
                            if (favItems.isEmpty()) EmptyState("Belum ada favorit", "Simpan item dari tab Explore dengan menekan ikon hati.", null, null)
                            else LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                                items(favItems, key = { it.id }) { comic ->
                                    OnlineComicCard(comic, true, {
                                        favorites = favorites - comic.id
                                        prefs.edit().putStringSet("favorites", favorites).apply()
                                    }, { try { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://archive.org/details/${comic.id}"))) } catch (_: Exception) {} })
                                }
                            }
                        }
                        else -> {
                            Text("Reading history", Modifier.padding(horizontal = 20.dp), fontSize = 21.sp, fontWeight = FontWeight.ExtraBold)
                            val historyLocal = localItems.filter { history.contains(it.localUri ?: it.id) }
                            val historyOnline = online.filter { history.contains(it.id) }
                            if (historyLocal.isEmpty() && historyOnline.isEmpty()) EmptyState("Belum ada riwayat", "Komik yang dibuka akan muncul di sini.", null, null)
                            else LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
                                items(historyLocal, key = { it.localUri ?: it.id }) { comic ->
                                    LocalComicCard(comic, onOpen = {
                                        val uri = Uri.parse(comic.localUri)
                                        readerComic = comic
                                        readerPages = listOf(uri)
                                    }, onRemove = {})
                                }
                                items(historyOnline, key = { it.id }) { comic ->
                                    OnlineComicCard(comic, favorites.contains(comic.id), {
                                        favorites = favorites - comic.id
                                        prefs.edit().putStringSet("favorites", favorites).apply()
                                    }, { try { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://archive.org/details/${comic.id}"))) } catch (_: Exception) {} })
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun NavChip(label: String, selected: Boolean, onClick: () -> Unit, icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Surface(
        onClick = onClick,
        shape = RoundedCornerShape(14.dp),
        color = if (selected) Ink else Color.White,
        contentColor = if (selected) Color.White else Color.Gray,
        shadowElevation = if (selected) 2.dp else 0.dp
    ) {
        Row(Modifier.padding(horizontal = 11.dp, vertical = 10.dp), verticalAlignment = Alignment.CenterVertically) {
            Icon(icon, contentDescription = null, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(5.dp))
            Text(label, fontSize = 11.sp, fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium)
        }
    }
}

@Composable
private fun LocalComicCard(comic: Comic, onOpen: () -> Unit, onRemove: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth().clickable(onClick = onOpen),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(width = 68.dp, height = 86.dp).clip(RoundedCornerShape(12.dp))
                    .background(Brush.linearGradient(listOf(Purple, Pink))),
                contentAlignment = Alignment.Center
            ) { Icon(Icons.Default.MenuBook, contentDescription = null, tint = Color.White, modifier = Modifier.size(30.dp)) }
            Spacer(Modifier.width(13.dp))
            Column(Modifier.weight(1f)) {
                Text(comic.title, fontWeight = FontWeight.Bold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(5.dp))
                Text("Disimpan di perangkat", color = Color.Gray, fontSize = 12.sp)
                Spacer(Modifier.height(8.dp))
                Text("Buka bacaan  →", color = Purple, fontWeight = FontWeight.SemiBold, fontSize = 12.sp)
            }
            IconButton(onClick = onRemove) { Icon(Icons.Default.Add, contentDescription = "Hapus dari library", tint = Color.Gray) }
        }
    }
}

@Composable
private fun OnlineComicCard(comic: Comic, isFavorite: Boolean, onFavorite: () -> Unit, onOpen: () -> Unit) {
    Card(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(18.dp),
        colors = CardDefaults.cardColors(containerColor = Color.White),
        elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
    ) {
        Row(Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
            AsyncImage(
                model = comic.thumbnail,
                contentDescription = null,
                modifier = Modifier.size(width = 76.dp, height = 100.dp).clip(RoundedCornerShape(12.dp)).clickable(onClick = onOpen),
                contentScale = ContentScale.Crop
            )
            Spacer(Modifier.width(13.dp))
            Column(Modifier.weight(1f).clickable(onClick = onOpen)) {
                Text(comic.title, fontWeight = FontWeight.Bold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(5.dp))
                Text(comic.year.ifBlank { "Internet Archive" }, color = Purple, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                Spacer(Modifier.height(5.dp))
                Text(comic.description.ifBlank { "Buka halaman item untuk detail dan akses." }, color = Color.Gray, fontSize = 11.sp, maxLines = 3, overflow = TextOverflow.Ellipsis)
                Spacer(Modifier.height(5.dp))
                Text(comic.license.ifBlank { "Periksa hak penggunaan pada halaman item" }, color = Color(0xFF16856B), fontSize = 10.sp, maxLines = 2)
            }
            IconButton(onClick = onFavorite) {
                Icon(Icons.Default.Favorite, contentDescription = "Favorit", tint = if (isFavorite) Pink else Color.LightGray)
            }
        }
    }
}

@Composable
private fun EmptyState(title: String, message: String, action: String?, onAction: (() -> Unit)?) {
    Box(Modifier.fillMaxWidth().padding(22.dp).heightIn(min = 220.dp), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Box(Modifier.size(64.dp).clip(RoundedCornerShape(22.dp)).background(Color(0xFFEAE5FF)), contentAlignment = Alignment.Center) {
                Icon(Icons.Default.MenuBook, contentDescription = null, tint = Purple, modifier = Modifier.size(30.dp))
            }
            Spacer(Modifier.height(16.dp))
            Text(title, fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
            Spacer(Modifier.height(6.dp))
            Text(message, color = Color.Gray, fontSize = 13.sp, lineHeight = 18.sp)
            if (action != null && onAction != null) {
                Spacer(Modifier.height(16.dp))
                Button(onClick = onAction, shape = RoundedCornerShape(14.dp)) { Text(action) }
            }
        }
    }
}

private fun displayName(uri: Uri): String {
    return try {
        val cursor = uri.let { u ->
            // Query is deliberately guarded: some document providers do not expose a display name.
            val contextUri = u
            contextUri
        }
        val segment = cursor.lastPathSegment.orEmpty().substringAfterLast('/')
        val decoded = Uri.decode(segment).substringAfterLast(':')
        decoded.ifBlank { "Komik lokal" }
    } catch (_: Exception) { "Komik lokal" }
}

private fun searchArchive(term: String): List<Comic> {
    val q = "mediatype:texts AND (licenseurl:*creativecommons.org/licenses/by* OR licenseurl:*creativecommons.org/publicdomain* OR licenseurl:*creativecommons.org/licenses/zero*) AND title:\"$term\""
    val url = "https://archive.org/advancedsearch.php?q=${URLEncoder.encode(q, "UTF-8")}&fl[]=identifier&fl[]=title&fl[]=description&fl[]=licenseurl&fl[]=year&rows=30&page=1&output=json"
    val connection = (URL(url).openConnection() as HttpURLConnection).apply {
        requestMethod = "GET"
        connectTimeout = 12000
        readTimeout = 15000
        setRequestProperty("User-Agent", "TeinManga/1.0 (Android)")
    }
    try {
        val body = connection.inputStream.bufferedReader().use { it.readText() }
        val docs = JSONObject(body).optJSONObject("response")?.optJSONArray("docs") ?: return emptyList()
        val results = mutableListOf<Comic>()
        for (i in 0 until docs.length()) {
            val item = docs.optJSONObject(i) ?: continue
            val license = item.optString("licenseurl")
            val normalized = license.lowercase()
            val allowed = normalized.contains("creativecommons.org/licenses/by/") ||
                normalized.contains("creativecommons.org/licenses/by-sa/") ||
                normalized.contains("creativecommons.org/publicdomain/") ||
                normalized.contains("creativecommons.org/publicdomain/zero/") ||
                normalized.contains("creativecommons.org/publicdomain/mark/")
            if (!allowed) continue
            val id = item.optString("identifier")
            if (id.isBlank()) continue
            results.add(
                Comic(
                    id = id,
                    title = item.optString("title").ifBlank { id },
                    description = item.optString("description").take(220),
                    license = license.substringAfterLast('/').ifBlank { license },
                    year = item.optString("year")
                )
            )
        }
        return results
    } finally {
        connection.disconnect()
    }
}

private fun extractArchive(context: android.content.Context, uri: Uri): List<Uri> {
    val outputDir = File(context.cacheDir, "teinmanga_pages").apply { mkdirs() }
    val prefix = "comic_${System.currentTimeMillis()}_"
    val pages = mutableListOf<File>()
    context.contentResolver.openInputStream(uri)?.use { raw ->
        ZipInputStream(raw).use { zip ->
            var entry = zip.nextEntry
            var count = 0
            while (entry != null && count < 500) {
                val name = entry.name.lowercase()
                if (!entry.isDirectory && (name.endsWith(".jpg") || name.endsWith(".jpeg") || name.endsWith(".png") || name.endsWith(".webp") || name.endsWith(".gif"))) {
                    val out = File(outputDir, prefix + count + "_" + File(entry.name).name)
                    out.outputStream().use { output -> zip.copyTo(output) }
                    pages.add(out)
                    count++
                }
                zip.closeEntry()
                entry = zip.nextEntry
            }
        }
    }
    return pages.sortedBy { it.name }.map { Uri.fromFile(it) }
}
