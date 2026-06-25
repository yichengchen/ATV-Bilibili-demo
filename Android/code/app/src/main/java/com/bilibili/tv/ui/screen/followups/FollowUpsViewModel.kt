package com.bilibili.tv.ui.screen.followups

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bilibili.tv.data.local.AccountDataStore
import com.bilibili.tv.data.model.FollowingUser
import com.bilibili.tv.data.repository.FeedRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import timber.log.Timber
import javax.inject.Inject

data class FollowUpsUiState(
    val isLoading: Boolean = false,
    val items: List<FollowingUser> = emptyList(),
    val error: String? = null,
    val hasMore: Boolean = true
)

@HiltViewModel
class FollowUpsViewModel @Inject constructor(
    private val feedRepository: FeedRepository,
    private val accountDataStore: AccountDataStore
) : ViewModel() {

    var uiState by mutableStateOf(FollowUpsUiState())
        private set

    private var currentPage = 1

    init { loadFollowUps() }

    fun loadFollowUps() {
        if (uiState.isLoading) return
        currentPage = 1
        viewModelScope.launch {
            uiState = FollowUpsUiState(isLoading = true)
            try {
                val mid = accountDataStore.getActiveAccount()?.token?.mid?.toLong() ?: return@launch
                val items = feedRepository.getFollowings(mid, 1)
                uiState = FollowUpsUiState(items = items, hasMore = items.size >= 40)
                Timber.d("FollowUps loaded: ${items.size} items")
            } catch (e: Exception) {
                Timber.e(e, "Load followUps failed")
                uiState = FollowUpsUiState(error = e.message)
            }
        }
    }

    fun loadMore() {
        if (uiState.isLoading || !uiState.hasMore) return
        currentPage++
        viewModelScope.launch {
            uiState = uiState.copy(isLoading = true)
            try {
                val mid = accountDataStore.getActiveAccount()?.token?.mid?.toLong() ?: return@launch
                val items = feedRepository.getFollowings(mid, currentPage)
                uiState = uiState.copy(
                    items = uiState.items + items,
                    isLoading = false,
                    hasMore = items.size >= 40
                )
            } catch (e: Exception) {
                Timber.e(e, "Load more followUps failed")
                uiState = uiState.copy(isLoading = false)
            }
        }
    }
}
