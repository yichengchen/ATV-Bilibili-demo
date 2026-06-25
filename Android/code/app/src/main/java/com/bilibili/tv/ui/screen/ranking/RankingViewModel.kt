package com.bilibili.tv.ui.screen.ranking

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.viewModelScope
import com.bilibili.tv.data.model.VideoDetail
import com.bilibili.tv.data.repository.FeedRepository
import com.bilibili.tv.ui.component.BaseVideoGridViewModel
import com.bilibili.tv.ui.component.VideoGridItem
import com.bilibili.tv.ui.component.VideoGridPage
import com.bilibili.tv.ui.component.VideoGridUiState
import com.bilibili.tv.ui.component.formatCount
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.launch
import timber.log.Timber
import javax.inject.Inject

data class RankCategory(val title: String, val rid: Int)

@HiltViewModel
class RankingViewModel @Inject constructor(
    private val feedRepository: FeedRepository
) : BaseVideoGridViewModel() {

    override val supportsLoadMore = false

    val categories = listOf(
        RankCategory("全站", 0), RankCategory("动画", 1005), RankCategory("番剧", 1),
        RankCategory("国创", 4), RankCategory("音乐", 1003), RankCategory("舞蹈", 1004),
        RankCategory("游戏", 1008), RankCategory("知识", 1010), RankCategory("科技", 1012),
        RankCategory("运动", 1018), RankCategory("汽车", 1013), RankCategory("生活", 160),
        RankCategory("美食", 1020), RankCategory("动物", 1024), RankCategory("鬼畜", 1007),
        RankCategory("时尚", 1014), RankCategory("娱乐", 1002), RankCategory("影视", 1001)
    )

    var selectedCategory by mutableIntStateOf(0)
        private set

    init { reload() }

    fun selectCategory(index: Int) {
        selectedCategory = index
        reload()
    }

    override suspend fun requestPage(page: Int): VideoGridPage {
        val rid = categories[selectedCategory].rid
        val items = feedRepository.getRanking(rid)
        Timber.d("Ranking loaded: ${items.size} items for rid=$rid")
        return VideoGridPage(items = items.toGridItems(), hasMore = false)
    }

    private fun List<VideoDetail.Info>.toGridItems() = map { info ->
        VideoGridItem(
            aid = info.aid,
            title = info.title,
            coverUrl = info.pic,
            ownerName = info.owner.name,
            avatarUrl = info.owner.face,
            playCount = formatCount(info.stat.view),
            danmakuCount = formatCount(info.stat.danmaku),
            duration = if (info.duration > 0) "%d:%02d".format(info.duration / 60, info.duration % 60) else null
        )
    }
}
