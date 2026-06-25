package com.bilibili.tv.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class HistoryItem(
    val aid: Long = 0,
    val cid: Long = 0,
    val title: String = "",
    val pic: String? = null,
    val owner: VideoDetail.VideoOwner = VideoDetail.VideoOwner(),
    val progress: Int = 0,
    val duration: Int = 0,
    @SerialName("view_at") val viewAt: Long = 0,
    val stat: Stat? = null
) {
    @Serializable
    data class Stat(
        val view: Long = 0,
        val danmaku: Long = 0
    )
}
