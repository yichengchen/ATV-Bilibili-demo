package com.bilibili.tv.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.tv.material3.ExperimentalTvMaterial3Api
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.darkColorScheme

object BiliColors {
    val AppBackground = Color(0xFF14161A)
    val Surface = Color(0xFF202228)
    val SurfaceFocused = Color(0xFF2B2E35)
    val SurfaceVariant = Color(0xFF262A31)
    val BrandBlue = Color(0xFF00A1D6)
    val BrandPink = Color(0xFFFB7299)
    val TextPrimary = Color.White
    val TextSecondary = Color(0xFFAAAAAA)
}

private val BiliDarkColorScheme = darkColorScheme(
    primary = BiliColors.BrandBlue,
    onPrimary = Color.White,
    secondary = BiliColors.BrandPink,
    surface = BiliColors.Surface,
    onSurface = Color.White,
    surfaceVariant = BiliColors.SurfaceVariant,
    onSurfaceVariant = BiliColors.TextSecondary,
    background = BiliColors.AppBackground,
    onBackground = Color.White,
    error = Color(0xFFFF6B6B)
)

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun BiliTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = BiliDarkColorScheme,
        content = content
    )
}
