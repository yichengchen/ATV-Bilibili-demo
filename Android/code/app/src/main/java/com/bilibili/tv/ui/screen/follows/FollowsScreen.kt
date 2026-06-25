package com.bilibili.tv.ui.screen.follows

import androidx.compose.runtime.Composable
import androidx.compose.ui.focus.FocusRequester
import androidx.hilt.navigation.compose.hiltViewModel
import com.bilibili.tv.ui.component.BaseVideoGridScreen

@Composable
fun FollowsScreen(
    restoreFocusRequester: FocusRequester,
    upFocusRequester: FocusRequester,
    onVideoClick: (Long) -> Unit,
    viewModel: FollowsViewModel = hiltViewModel()
) {
    BaseVideoGridScreen(
        state = viewModel.uiState,
        restoreFocusRequester = restoreFocusRequester,
        upFocusRequester = upFocusRequester,
        onRetry = viewModel::reload,
        onLoadMore = viewModel::loadMore,
        onVideoClick = onVideoClick,
        errorHint = "可能需要登录或网络错误"
    )
}
