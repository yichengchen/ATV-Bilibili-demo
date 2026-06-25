package com.bilibili.tv.ui.component

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.launch
import timber.log.Timber

data class VideoGridUiState(
    val items: List<VideoGridItem> = emptyList(),
    val isLoading: Boolean = false,
    val error: String? = null,
    val hasMore: Boolean = true
)

data class VideoGridPage(
    val items: List<VideoGridItem>,
    val hasMore: Boolean = true,
    val consumedPage: Int? = null
)

abstract class BaseVideoGridViewModel : ViewModel() {
    var uiState by mutableStateOf(VideoGridUiState())
        private set

    protected open val supportsLoadMore: Boolean = true

    private var currentPage = 0

    protected abstract suspend fun requestPage(page: Int): VideoGridPage

    open fun reload() {
        if (uiState.isLoading) return
        currentPage = 0
        viewModelScope.launch {
            uiState = uiState.copy(isLoading = true, error = null)
            try {
                val page = requestPage(1)
                currentPage = page.consumedPage ?: 1
                uiState = VideoGridUiState(
                    items = page.items,
                    hasMore = page.hasMore
                )
            } catch (e: Exception) {
                Timber.e(e, "Load video grid failed")
                uiState = VideoGridUiState(error = e.message)
            }
        }
    }

    open fun loadMore() {
        val state = uiState
        if (!supportsLoadMore || state.isLoading || !state.hasMore || state.items.isEmpty()) return

        val nextPage = currentPage + 1
        viewModelScope.launch {
            uiState = state.copy(isLoading = true, error = null)
            try {
                val page = requestPage(nextPage)
                currentPage = page.consumedPage ?: nextPage
                uiState = uiState.copy(
                    items = uiState.items + page.items,
                    isLoading = false,
                    hasMore = page.hasMore
                )
            } catch (e: Exception) {
                Timber.e(e, "Load more video grid failed")
                uiState = uiState.copy(isLoading = false, error = e.message)
            }
        }
    }
}
