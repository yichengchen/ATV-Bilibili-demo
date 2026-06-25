package com.bilibili.tv.ui.screen.history

import androidx.compose.runtime.Composable
import androidx.compose.ui.focus.FocusRequester
import androidx.hilt.navigation.compose.hiltViewModel
import com.bilibili.tv.ui.component.BaseVideoGridScreen

@Composable
fun HistoryScreen(
    restoreFocusRequester: FocusRequester,
    upFocusRequester: FocusRequester,
    onVideoClick: (Long) -> Unit,
    viewModel: HistoryViewModel = hiltViewModel()
) {
    BaseVideoGridScreen(
        state = viewModel.uiState,
        restoreFocusRequester = restoreFocusRequester,
        upFocusRequester = upFocusRequester,
        onRetry = viewModel::reload,
        onLoadMore = null,
        onVideoClick = onVideoClick,
        emptyText = "暂无观看历史"
    )
}
