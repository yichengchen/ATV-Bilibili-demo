package com.bilibili.tv.data.model

import kotlinx.serialization.Serializable

@Serializable
data class FollowingUser(
    val mid: Long = 0,
    val uname: String = "",
    val face: String = "",
    val sign: String = ""
)

@Serializable
data class ToViewData(
    val title: String = "",
    val aid: Long = 0,
    val cid: Long = 0,
    val owner: VideoDetail.VideoOwner = VideoDetail.VideoOwner(),
    val pic: String? = null,
    val pubdate: Long = 0,
    val duration: Int = 0,
    val stat: Stat? = null
) {
    @Serializable
    data class Stat(val view: Long = 0, val danmaku: Long = 0)
}
