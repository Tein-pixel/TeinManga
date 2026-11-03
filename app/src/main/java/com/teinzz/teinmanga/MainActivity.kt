package com.manhwaku.reader

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import com.manhwaku.reader.ui.ManhwaKuApp

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.statusBarColor = android.graphics.Color.rgb(8, 11, 19)
        window.navigationBarColor = android.graphics.Color.rgb(5, 9, 16)
        window.decorView.systemUiVisibility = 0

        setContent {
            MaterialTheme(
                colorScheme = darkColorScheme(
                    primary = androidx.compose.ui.graphics.Color(0xFF78A6FF),
                    onPrimary = androidx.compose.ui.graphics.Color(0xFF071321),
                    secondary = androidx.compose.ui.graphics.Color(0xFFAB91FF),
                    background = androidx.compose.ui.graphics.Color(0xFF080B13),
                    surface = androidx.compose.ui.graphics.Color(0xFF111827),
                    onSurface = androidx.compose.ui.graphics.Color(0xFFF7F8FC),
                    surfaceVariant = androidx.compose.ui.graphics.Color(0xFF1A2740)
                )
            ) {
                ManhwaKuApp()
            }
        }
    }
}
