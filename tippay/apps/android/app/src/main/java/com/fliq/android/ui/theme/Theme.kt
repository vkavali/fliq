package com.fliq.android.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

private val LightColors = lightColorScheme(
    primary = FliqBlue,
    secondary = FliqMint,
    tertiary = FliqGold,
    background = FliqSurface,
    surface = androidx.compose.ui.graphics.Color.White,
    onPrimary = androidx.compose.ui.graphics.Color.White,
    onSecondary = androidx.compose.ui.graphics.Color.White,
    onTertiary = androidx.compose.ui.graphics.Color.White,
    onBackground = FliqInk,
    onSurface = FliqInk,
)

private val DarkColors = darkColorScheme(
    primary = FliqBlue,
    secondary = FliqMint,
    tertiary = FliqGold,
)

@Composable
fun FliqAndroidTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val colors = if (darkTheme) DarkColors else LightColors

    MaterialTheme(
        colorScheme = colors,
        typography = FliqTypography,
        content = content,
    )
}
