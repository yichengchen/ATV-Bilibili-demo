package com.bilibili.tv.ui.screen.hot

import androidx.compose.runtime.Composable
import androidx.compose.ui.focus.FocusRequester
import androidx.hilt.navigation.compose.hiltViewModel
import com.bilibili.tv.ui.component.BaseVideoGridScreen

@Composable
fun HotScreen(
    restoreFocusRequester: FocusRequester,
    upFocusRequester: FocusRequester,
    onVideoClick: (Long) -> Unit,
    viewModel: HotViewModel = hiltViewModel()
) {
    BaseVideoGridScreen(
        state = viewModel.uiState,
        restoreFocusRequester = restoreFocusRequester,
        upFocusRequester = upFocusRequester,
        onRetry = viewModel::reload,
        onLoadMore = viewModel::loadMore,
        onVideoClick = onVideoClick
    )
}
