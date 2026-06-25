package com.bilibili.tv.ui.screen.upspace

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.focus.FocusRequester
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.tv.material3.ExperimentalTvMaterial3Api
import com.bilibili.tv.ui.component.BaseVideoGridScreen

@OptIn(ExperimentalTvMaterial3Api::class, ExperimentalComposeUiApi::class)
@Composable
fun UpSpaceScreen(
    mid: Long,
    onVideoClick: (Long) -> Unit,
    viewModel: UpSpaceViewModel = hiltViewModel()
) {
    val restoreFocus = remember { FocusRequester() }

    LaunchedEffect(mid) { viewModel.initMid(mid) }

    BaseVideoGridScreen(
        state = viewModel.uiState,
        restoreFocusRequester = restoreFocus,
        onRetry = { viewModel.reload() },
        onLoadMore = { viewModel.loadMore() },
        onVideoClick = onVideoClick,
        emptyText = "该UP主暂无视频"
    )
}
