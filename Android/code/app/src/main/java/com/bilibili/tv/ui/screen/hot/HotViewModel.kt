package com.bilibili.tv.ui.screen.hot

import com.bilibili.tv.data.repository.FeedRepository
import com.bilibili.tv.ui.component.BaseVideoGridViewModel
import com.bilibili.tv.ui.component.VideoGridItem
import com.bilibili.tv.ui.component.VideoGridPage
import com.bilibili.tv.ui.component.formatCount
import dagger.hilt.android.lifecycle.HiltViewModel
import javax.inject.Inject

@HiltViewModel
class HotViewModel @Inject constructor(
    private val feedRepository: FeedRepository
) : BaseVideoGridViewModel() {

    init {
        reload()
    }

    override suspend fun requestPage(page: Int): VideoGridPage {
        val resp = feedRepository.getHot(page = page)
        return VideoGridPage(
            items = resp.list.map { item ->
                val durationText = if (item.duration > 0) {
                    val min = item.duration / 60
                    val sec = item.duration % 60
                    "%d:%02d".format(min, sec)
                } else null

                VideoGridItem(
                    aid = item.aid,
                    key = "hot:$page:${item.aid}",
                    title = item.title,
                    coverUrl = item.pic,
                    ownerName = item.owner.name,
                    avatarUrl = item.owner.face,
                    playCount = formatCount(item.stat.view),
                    danmakuCount = formatCount(item.stat.danmaku),
                    duration = durationText
                )
            },
            hasMore = !resp.no_more
        )
    }
}
