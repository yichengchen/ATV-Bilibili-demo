package com.bilibili.tv.ui.component

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.focusGroup
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
import androidx.compose.foundation.lazy.grid.rememberLazyGridState
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.runtime.Composable
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.focus.focusRestorer
import androidx.compose.ui.focus.focusProperties
import androidx.compose.ui.focus.onFocusChanged
import androidx.compose.ui.unit.dp
import androidx.tv.material3.Button
import androidx.tv.material3.ExperimentalTvMaterial3Api
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Text
import com.bilibili.tv.ui.theme.BiliColors
import kotlinx.coroutines.launch

data class VideoGridItem(
    val aid: Long,
    val key: String = aid.toString(),
    val title: String,
    val coverUrl: String?,
    val ownerName: String,
    val avatarUrl: String? = null,
    val playCount: String = "",
    val danmakuCount: String = "",
    val duration: String? = null
)

@OptIn(ExperimentalComposeUiApi::class, ExperimentalTvMaterial3Api::class)
@Composable
fun BaseVideoGridScreen(
    state: VideoGridUiState,
    restoreFocusRequester: FocusRequester,
    upFocusRequester: FocusRequester? = null,
    onRetry: () -> Unit,
    onLoadMore: (() -> Unit)?,
    onVideoClick: (Long) -> Unit,
    modifier: Modifier = Modifier,
    emptyText: String? = null,
    errorHint: String? = null,
    loadMoreThreshold: Int = 8,
    columns: Int = 4
) {
    BaseVideoGridScreen(
        items = state.items,
        isLoading = state.isLoading,
        error = state.error,
        restoreFocusRequester = restoreFocusRequester,
        upFocusRequester = upFocusRequester,
        onRetry = onRetry,
        onLoadMore = onLoadMore,
        onVideoClick = onVideoClick,
        modifier = modifier,
        emptyText = emptyText,
        errorHint = errorHint,
        loadMoreThreshold = loadMoreThreshold,
        columns = columns
    )
}

@OptIn(ExperimentalComposeUiApi::class, ExperimentalTvMaterial3Api::class)
@Composable
fun BaseVideoGridScreen(
    items: List<VideoGridItem>,
    isLoading: Boolean,
    error: String?,
    restoreFocusRequester: FocusRequester,
    upFocusRequester: FocusRequester? = null,
    onRetry: () -> Unit,
    onLoadMore: (() -> Unit)?,
    onVideoClick: (Long) -> Unit,
    modifier: Modifier = Modifier,
    emptyText: String? = null,
    errorHint: String? = null,
    loadMoreThreshold: Int = 8,
    columns: Int = 4
) {
    val gridState = rememberLazyGridState()
    val coroutineScope = rememberCoroutineScope()
    var lastFocusedKey by rememberSaveable { mutableStateOf("") }
    val restoreKey = remember(items, lastFocusedKey) {
        if (items.any { it.key == lastFocusedKey }) {
            lastFocusedKey
        } else {
            items.firstOrNull()?.key.orEmpty()
        }
    }
    val isAtTop by remember {
        derivedStateOf {
            gridState.firstVisibleItemIndex == 0 && gridState.firstVisibleItemScrollOffset == 0
        }
    }

    BackHandler(enabled = items.isNotEmpty() && !isAtTop) {
        coroutineScope.launch {
            lastFocusedKey = items.firstOrNull()?.key.orEmpty()
            gridState.animateScrollToItem(0)
            restoreFocusRequester.requestFocus()
        }
    }

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(BiliColors.AppBackground)
    ) {
        if (items.isEmpty() && isLoading) {
            CircularProgressIndicator(
                modifier = Modifier
                    .align(Alignment.Center)
                    .focusRequester(restoreFocusRequester)
                    .focusable()
            )
        } else if (error != null && items.isEmpty()) {
            Column(
                modifier = Modifier.align(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text("加载失败: $error", color = MaterialTheme.colorScheme.error)
                if (errorHint != null) {
                    Text(errorHint, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Button(
                    modifier = Modifier.focusRequester(restoreFocusRequester),
                    onClick = onRetry
                ) { Text("重试") }
            }
        } else if (items.isEmpty() && emptyText != null) {
            Text(
                emptyText,
                modifier = Modifier
                    .align(Alignment.Center)
                    .focusRequester(restoreFocusRequester)
                    .focusable(),
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        } else {
            LazyVerticalGrid(
                columns = GridCells.Fixed(columns),
                state = gridState,
                contentPadding = PaddingValues(start = 32.dp, end = 32.dp, top = 24.dp, bottom = 48.dp),
                horizontalArrangement = Arrangement.spacedBy(20.dp),
                verticalArrangement = Arrangement.spacedBy(28.dp),
                modifier = Modifier
                    .fillMaxSize()
                    .focusRestorer(restoreFocusRequester)
                    .focusGroup()
            ) {
                itemsIndexed(
                    items = items,
                    key = { _, item -> item.key }
                ) { index, item ->
                    VideoCard(
                        title = item.title,
                        coverUrl = item.coverUrl,
                        ownerName = item.ownerName,
                        avatarUrl = item.avatarUrl,
                        playCount = item.playCount,
                        danmakuCount = item.danmakuCount,
                        duration = item.duration,
                        onClick = {
                            lastFocusedKey = item.key
                            onVideoClick(item.aid)
                        },
                        modifier = Modifier
                            .then(
                                if (upFocusRequester != null && index < columns) {
                                    Modifier.focusProperties { up = upFocusRequester }
                                } else {
                                    Modifier
                                }
                            )
                            .then(
                                if (item.key == restoreKey) {
                                    Modifier.focusRequester(restoreFocusRequester)
                                } else {
                                    Modifier
                                }
                            )
                            .onFocusChanged { focusState ->
                                if (focusState.isFocused) lastFocusedKey = item.key
                            }
                    )

                    if (onLoadMore != null && index >= items.size - loadMoreThreshold) {
                        onLoadMore()
                    }
                }
            }
        }
    }
}
