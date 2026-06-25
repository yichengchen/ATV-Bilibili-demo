package com.bilibili.tv.ui.screen.toview

import androidx.compose.runtime.Composable
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.focus.FocusRequester
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.tv.material3.ExperimentalTvMaterial3Api
import com.bilibili.tv.ui.component.BaseVideoGridScreen

@OptIn(ExperimentalTvMaterial3Api::class, ExperimentalComposeUiApi::class)
@Composable
fun ToViewScreen(
    restoreFocusRequester: FocusRequester,
    upFocusRequester: FocusRequester,
    onVideoClick: (Long) -> Unit,
    viewModel: ToViewModel = hiltViewModel()
) {
    BaseVideoGridScreen(
        state = viewModel.uiState,
        restoreFocusRequester = restoreFocusRequester,
        upFocusRequester = upFocusRequester,
        onRetry = { viewModel.reload() },
        onLoadMore = null,
        onVideoClick = onVideoClick,
        emptyText = "稍后再看列表为空"
    )
}
