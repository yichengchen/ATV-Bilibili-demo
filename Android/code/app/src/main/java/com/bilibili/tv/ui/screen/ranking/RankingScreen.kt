package com.bilibili.tv.ui.screen.ranking

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.runtime.Composable
import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.Modifier
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.tv.material3.ExperimentalTvMaterial3Api
import androidx.tv.material3.MaterialTheme
import androidx.tv.material3.Surface
import androidx.tv.material3.Text
import com.bilibili.tv.ui.component.BaseVideoGridScreen
import com.bilibili.tv.ui.theme.BiliColors

@OptIn(ExperimentalTvMaterial3Api::class, ExperimentalComposeUiApi::class)
@Composable
fun RankingScreen(
    restoreFocusRequester: FocusRequester,
    upFocusRequester: FocusRequester,
    onVideoClick: (Long) -> Unit,
    viewModel: RankingViewModel = hiltViewModel()
) {
    Row(Modifier.fillMaxSize().background(BiliColors.AppBackground)) {
        LazyColumn(
            modifier = Modifier.width(200.dp).fillMaxHeight()
                .background(BiliColors.Surface).padding(top = 16.dp)
        ) {
            itemsIndexed(viewModel.categories) { index, cat ->
                val isSelected = index == viewModel.selectedCategory
                Surface(
                    onClick = { viewModel.selectCategory(index) },
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                ) {
                    Text(
                        cat.title,
                        modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
                        color = if (isSelected) MaterialTheme.colorScheme.primary
                        else MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }

        BaseVideoGridScreen(
            state = viewModel.uiState,
            restoreFocusRequester = restoreFocusRequester,
            upFocusRequester = upFocusRequester,
            onRetry = { viewModel.reload() },
            onLoadMore = null,
            onVideoClick = onVideoClick
        )
    }
}
