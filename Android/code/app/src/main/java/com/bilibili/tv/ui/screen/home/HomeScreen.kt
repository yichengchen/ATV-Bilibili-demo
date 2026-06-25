package com.bilibili.tv.ui.screen.home

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.focusGroup
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.focusRestorer
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.tv.material3.Button
import androidx.tv.material3.ExperimentalTvMaterial3Api
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.SelectableSurfaceDefaults
import androidx.tv.material3.Surface
import androidx.tv.material3.Text
import com.bilibili.tv.ui.theme.BiliColors

@OptIn(ExperimentalComposeUiApi::class, ExperimentalTvMaterial3Api::class)
@Composable
fun HomeScreen(
    selectedTab: Int,
    onSelectedTabChange: (Int) -> Unit,
    contentFocusRequesters: List<FocusRequester>,
    onVideoClick: (Long) -> Unit,
    feedContent: @Composable (FocusRequester) -> Unit,
    hotContent: @Composable (FocusRequester) -> Unit,
    followsContent: @Composable (FocusRequester) -> Unit,
    rankingContent: @Composable (FocusRequester) -> Unit,
    followUpsContent: @Composable (FocusRequester) -> Unit,
    toViewContent: @Composable (FocusRequester) -> Unit,
    historyContent: @Composable (FocusRequester) -> Unit,
    settingsContent: @Composable (FocusRequester) -> Unit,
    onExitConfirmed: () -> Unit
) {
    data class HomeTab(val label: String)

    val tabs = listOf(
        HomeTab("推荐"),
        HomeTab("热门"),
        HomeTab("关注"),
        HomeTab("排行榜"),
        HomeTab("关注UP"),
        HomeTab("稍后再看"),
        HomeTab("历史"),
        HomeTab("设置")
    )

    val tabFocusRequesters = remember { List(tabs.size) { FocusRequester() } }
    val fallbackFocusRequester = contentFocusRequesters.getOrNull(selectedTab) ?: tabFocusRequesters[selectedTab]
    var showExitDialog by remember { mutableStateOf(false) }

    BackHandler(enabled = !showExitDialog) {
        showExitDialog = true
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(BiliColors.AppBackground)
            .focusRestorer(fallbackFocusRequester)
            .focusGroup()
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(86.dp)
                .padding(horizontal = 48.dp)
        ) {
            Row(
                modifier = Modifier
                    .align(Alignment.Center)
                    .clip(RoundedCornerShape(28.dp))
                    .background(Color.White.copy(alpha = 0.06f))
                    .padding(5.dp),
                horizontalArrangement = Arrangement.spacedBy(3.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                tabs.forEachIndexed { index, tab ->
                    val isSelected = selectedTab == index
                    Surface(
                        selected = selectedTab == index,
                        onClick = {
                            onSelectedTabChange(index)
                        },
                        modifier = Modifier
                            .focusRequester(tabFocusRequesters[index])
                            .onFocusChanged { focusState ->
                                if (focusState.isFocused) onSelectedTabChange(index)
                            },
                        shape = SelectableSurfaceDefaults.shape(
                            shape = RoundedCornerShape(28.dp),
                            focusedShape = RoundedCornerShape(28.dp),
                            selectedShape = RoundedCornerShape(28.dp),
                            focusedSelectedShape = RoundedCornerShape(28.dp)
                        ),
                        colors = SelectableSurfaceDefaults.colors(
                            containerColor = Color.Transparent,
                            contentColor = Color.White.copy(alpha = 0.58f),
                            focusedContainerColor = Color.White.copy(alpha = 0.14f),
                            focusedContentColor = Color.White,
                            selectedContainerColor = Color.White.copy(alpha = 0.16f),
                            selectedContentColor = Color.White,
                            focusedSelectedContainerColor = Color.White.copy(alpha = 0.26f),
                            focusedSelectedContentColor = Color.White
                        ),
                        scale = SelectableSurfaceDefaults.scale(
                            scale = 1f,
                            focusedScale = 1.04f,
                            selectedScale = 1f,
                            focusedSelectedScale = 1.05f
                        )
                    ) {
                        Box(
                            modifier = Modifier
                                .width(76.dp)
                                .height(38.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                tab.label,
                                style = MaterialTheme.typography.titleMedium.copy(
                                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                                    fontSize = 15.sp
                                )
                            )
                        }
                    }
                }
            }
        }

        when (selectedTab) {
            0 -> feedContent(tabFocusRequesters[0])
            1 -> hotContent(tabFocusRequesters[1])
            2 -> followsContent(tabFocusRequesters[2])
            3 -> rankingContent(tabFocusRequesters[3])
            4 -> followUpsContent(tabFocusRequesters[4])
            5 -> toViewContent(tabFocusRequesters[5])
            6 -> historyContent(tabFocusRequesters[6])
            7 -> settingsContent(tabFocusRequesters[7])
        }
    }

    if (showExitDialog) {
        ExitConfirmDialog(
            onDismiss = { showExitDialog = false },
            onConfirm = {
                showExitDialog = false
                onExitConfirmed()
            }
        )
    }
}

@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
private fun ExitConfirmDialog(
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    val cancelFocusRequester = remember { FocusRequester() }

    BackHandler(onBack = onDismiss)
    LaunchedEffect(Unit) {
        cancelFocusRequester.requestFocus()
    }

    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black.copy(alpha = 0.58f)),
            contentAlignment = Alignment.Center
        ) {
            Surface(
                shape = RoundedCornerShape(14.dp),
                colors = androidx.tv.material3.SurfaceDefaults.colors(
                    containerColor = Color(0xFF202124),
                    contentColor = Color.White
                )
            ) {
                Column(
                    modifier = Modifier
                        .width(420.dp)
                        .padding(28.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text(
                        "退出应用？",
                        style = MaterialTheme.typography.headlineSmall.copy(
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Bold
                        ),
                        color = Color.White
                    )
                    Text(
                        "确认后将关闭当前应用",
                        modifier = Modifier.padding(top = 10.dp),
                        style = MaterialTheme.typography.bodyMedium.copy(fontSize = 16.sp),
                        color = Color.White.copy(alpha = 0.64f)
                    )
                    Row(
                        modifier = Modifier.padding(top = 28.dp),
                        horizontalArrangement = Arrangement.spacedBy(18.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Button(
                            onClick = onDismiss,
                            modifier = Modifier
                                .size(width = 128.dp, height = 48.dp)
                                .focusRequester(cancelFocusRequester)
                        ) {
                            Text("取消")
                        }
                        Button(
                            onClick = onConfirm,
                            modifier = Modifier.size(width = 128.dp, height = 48.dp)
                        ) {
                            Text("退出")
                        }
                    }
                }
            }
        }
    }
}
