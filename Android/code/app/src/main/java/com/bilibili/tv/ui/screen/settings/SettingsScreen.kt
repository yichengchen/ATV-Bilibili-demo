package com.bilibili.tv.ui.screen.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.interaction.collectIsFocusedAsState
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.tv.material3.ClickableSurfaceDefaults
import androidx.tv.material3.ExperimentalTvMaterial3Api
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Surface
import androidx.tv.material3.Text
import com.bilibili.tv.data.local.AccountDataStore
import com.bilibili.tv.data.local.SettingsDataStore
import com.bilibili.tv.ui.theme.BiliColors
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import javax.inject.Inject

data class SettingsUiState(
    val username: String = "",
    val avatar: String = "",
    val quality: Int = 80,
    val danmuEnabled: Boolean = true
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val settingsDataStore: SettingsDataStore,
    private val accountDataStore: AccountDataStore
) : ViewModel() {

    val qualityFlow = settingsDataStore.qualityFlow
    val danmuEnabledFlow = settingsDataStore.danmuEnabledFlow

    fun setQuality(qn: Int) {
        viewModelScope.launch { settingsDataStore.setQuality(qn) }
    }

    fun setDanmuEnabled(enabled: Boolean) {
        viewModelScope.launch { settingsDataStore.setDanmuEnabled(enabled) }
    }
}

private data class QualityOption(val title: String, val value: Int)

private val qualityOptions = listOf(
    QualityOption("1080P", 80),
    QualityOption("4K", 120),
    QualityOption("HDR 杜比", 126)
)

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun SettingsScreen(
    onLogout: () -> Unit,
    topFocusRequester: FocusRequester = FocusRequester.Default,
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val quality by viewModel.qualityFlow.collectAsState(initial = 80)
    val danmuEnabled by viewModel.danmuEnabledFlow.collectAsState(initial = true)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(BiliColors.AppBackground),
        contentAlignment = Alignment.TopCenter
    ) {
        LazyColumn(
            modifier = Modifier.width(900.dp),
            contentPadding = PaddingValues(top = 18.dp, bottom = 80.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            item {
                Text(
                    text = "设置",
                    modifier = Modifier.padding(start = 20.dp, bottom = 22.dp),
                    style = MaterialTheme.typography.headlineMedium.copy(
                        fontSize = 34.sp,
                        fontWeight = FontWeight.Bold
                    ),
                    color = Color.White
                )
            }

            item { SettingsSectionHeader("音视频") }
            items(qualityOptions.size) { index ->
                val option = qualityOptions[index]
                SettingsRow(
                    title = option.title,
                    description = if (quality == option.value) "当前" else "",
                    selected = quality == option.value,
                    upFocusRequester = if (index == 0) topFocusRequester else FocusRequester.Default,
                    onClick = { viewModel.setQuality(option.value) }
                )
            }

            item {
                Spacer(Modifier.height(18.dp))
                SettingsSectionHeader("弹幕")
            }
            item {
                SettingsRow(
                    title = "弹幕开关",
                    description = if (danmuEnabled) "开" else "关",
                    onClick = { viewModel.setDanmuEnabled(!danmuEnabled) }
                )
            }
        }
    }
}

@Composable
private fun SettingsSectionHeader(title: String) {
    Text(
        text = title,
        modifier = Modifier.padding(start = 20.dp, top = 10.dp, bottom = 4.dp),
        style = MaterialTheme.typography.labelLarge.copy(
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium
        ),
        color = Color.White.copy(alpha = 0.48f)
    )
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
private fun SettingsRow(
    title: String,
    description: String,
    selected: Boolean = false,
    upFocusRequester: FocusRequester = FocusRequester.Default,
    onClick: () -> Unit
) {
    val interactionSource = remember { MutableInteractionSource() }
    val focused by interactionSource.collectIsFocusedAsState()
    val foreground = when {
        focused -> Color.Black
        else -> Color.White
    }
    val secondary = when {
        focused -> Color.Black.copy(alpha = 0.72f)
        selected -> Color(0xFF00A1D6)
        else -> Color.White.copy(alpha = 0.48f)
    }

    Surface(
        onClick = onClick,
        modifier = Modifier
            .fillMaxWidth()
            .height(68.dp)
            .focusProperties {
                up = upFocusRequester
            },
        shape = ClickableSurfaceDefaults.shape(
            shape = RoundedCornerShape(10.dp),
            focusedShape = RoundedCornerShape(10.dp),
            pressedShape = RoundedCornerShape(10.dp)
        ),
        colors = ClickableSurfaceDefaults.colors(
            containerColor = Color.Transparent,
            contentColor = Color.White,
            focusedContainerColor = Color.White,
            focusedContentColor = Color.Black,
            pressedContainerColor = Color.White.copy(alpha = 0.86f),
            pressedContentColor = Color.Black
        ),
        scale = ClickableSurfaceDefaults.scale(
            scale = 1f,
            focusedScale = 1.025f,
            pressedScale = 1f
        ),
        interactionSource = interactionSource
    ) {
        Row(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleMedium.copy(
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Medium
                ),
                color = foreground
            )
            Spacer(Modifier.weight(1f))
            if (description.isNotEmpty()) {
                Text(
                    text = description,
                    style = MaterialTheme.typography.titleMedium.copy(
                        fontSize = 22.sp,
                        fontWeight = if (selected) FontWeight.SemiBold else FontWeight.Normal
                    ),
                    color = secondary
                )
            }
        }
    }
}
