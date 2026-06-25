package com.bilibili.tv.ui.screen.detail

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bilibili.tv.data.model.PlayUrlInfo
import com.bilibili.tv.data.model.Replys
import com.bilibili.tv.data.model.VideoDetail
import com.bilibili.tv.data.repository.FeedRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import timber.log.Timber
import javax.inject.Inject

data class DetailUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val info: VideoDetail.Info? = null,
    val related: List<VideoDetail.Info> = emptyList(),
    val card: VideoDetail.Card = VideoDetail.Card(),
    val replies: List<Replys.Reply> = emptyList(),
    val ugcEpisodes: List<VideoDetail.UgcSeason.UgcEpisode> = emptyList(),
    val ugcTitle: String = ""
)

@HiltViewModel
class VideoDetailViewModel @Inject constructor(
    private val feedRepository: FeedRepository
) : ViewModel() {

    var uiState by mutableStateOf(DetailUiState())
        private set

    var selectedCid by mutableLongStateOf(0L)
        private set

    fun loadDetail(aid: Long) {
        viewModelScope.launch {
            uiState = DetailUiState(isLoading = true)
            try {
                val detail = withContext(Dispatchers.IO) { feedRepository.getVideoDetail(aid) }
                val view = detail.view
                selectedCid = view.cid

                // Resolve UGC season episodes
                val ugcEpisodes = resolveUgcEpisodes(view, aid)
                val ugcTitle = view.ugcSeason?.let { season ->
                    "${season.title} · ${season.sections.firstOrNull()?.title ?: ""}"
                } ?: ""

                uiState = DetailUiState(
                    isLoading = false,
                    info = view,
                    related = detail.related,
                    card = detail.card,
                    replies = emptyList(),
                    ugcEpisodes = ugcEpisodes,
                    ugcTitle = ugcTitle
                )
                Timber.d("Detail loaded: title=${view.title}, related=${detail.related.size}")

                // Fetch replies separately
                launch {
                    try {
                        val replies = withContext(Dispatchers.IO) { feedRepository.getReplies(aid) }
                        uiState = uiState.copy(replies = replies)
                        Timber.d("Replies loaded: ${replies.size}, first=${replies.firstOrNull()?.content?.message?.take(30)}")
                    } catch (e: Exception) {
                        Timber.e(e, "Load replies failed")
                    }
                }
            } catch (e: Exception) {
                Timber.e(e, "Load detail failed")
                uiState = DetailUiState(error = e.message ?: "Unknown error")
            }
        }
    }

    private fun resolveUgcEpisodes(view: VideoDetail.Info, currentAid: Long): List<VideoDetail.UgcSeason.UgcEpisode> {
        val season = view.ugcSeason ?: return emptyList()
        val section = if (season.sections.size > 1) {
            season.sections.firstOrNull { s -> s.episodes.any { it.aid == currentAid } }
        } else {
            season.sections.firstOrNull()
        }
        return section?.episodes?.sortedBy { it.arc.ctime } ?: emptyList()
    }

    fun selectPage(cid: Long) {
        selectedCid = cid
    }

    fun loadPlayUrl(aid: Long, cid: Long, callback: (PlayUrlInfo?) -> Unit) {
        viewModelScope.launch {
            try {
                val playInfo = withContext(Dispatchers.IO) {
                    feedRepository.getPlayUrl(aid = aid, cid = cid, qn = 120, fnval = 4048)
                }
                callback(playInfo)
            } catch (e: Exception) {
                Timber.e(e, "Load play URL failed")
                callback(null)
            }
        }
    }
}
