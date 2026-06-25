package com.bilibili.tv.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class FeedResp(
    @SerialName("items") val items: List<FeedItem> = emptyList()
) {
    @Serializable
    data class FeedItem(
        val param: String = "",
        val title: String = "",
        val cover: String? = null,
        val args: Args? = null,
        val mask: Mask? = null,
        @SerialName("cover_left_text_1") val durationText: String = "",
        @SerialName("cover_left_text_2") val viewText: String = "",
        @SerialName("cover_left_text_3") val danmakuText: String = "",
        val idx: Long = 0
    ) {
        val aid: Long get() = param.toLongOrNull() ?: 0
        val ownerName: String get() = args?.upName ?: ""
        val avatarUrl: String? get() = mask?.avatar?.cover
        val viewDisplay: String get() = viewText.removeSuffix("观看")
        val danmakuDisplay: String get() = danmakuText.removeSuffix("弹幕")

        @Serializable
        data class Args(
            @SerialName("up_id") val upId: Long = 0,
            @SerialName("up_name") val upName: String = ""
        )

        @Serializable
        data class Mask(
            val avatar: Avatar? = null
        ) {
            @Serializable
            data class Avatar(
                val cover: String? = null
            )
        }
    }
}

@Serializable
data class HotResp(
    val no_more: Boolean = false,
    val list: List<VideoDetail.Info> = emptyList()
)

@Serializable
data class PlayUrlInfo(
    val quality: Int = 0,
    val format: String = "",
    val timelength: Long = 0,
    val dash: DashInfo? = null
) {
    @Serializable
    data class DashInfo(
        val duration: Int = 0,
        val video: List<DashMediaInfo> = emptyList(),
        val audio: List<DashMediaInfo>? = null,
        val dolby: DolbyInfo? = null,
        val flac: FlacInfo? = null
    )

    @Serializable
    data class DashMediaInfo(
        val id: Int = 0,
        @SerialName("base_url") val baseUrl: String = "",
        @SerialName("backup_url") val backupUrl: List<String>? = null,
        val bandwidth: Int = 0,
        @SerialName("mime_type") val mimeType: String = "",
        val codecs: String = "",
        val width: Int? = null,
        val height: Int? = null,
        @SerialName("frame_rate") val frameRate: String? = null,
        @SerialName("segment_base") val segmentBase: DashSegmentBase? = null
    )

    @Serializable
    data class DashSegmentBase(
        val initialization: String = "",
        @SerialName("index_range") val indexRange: String = ""
    )

    @Serializable
    data class DolbyInfo(
        val audio: List<DashMediaInfo>? = null
    )

    @Serializable
    data class FlacInfo(
        val display: DisplayInfo? = null,
        val audio: DashMediaInfo? = null
    ) {
        @Serializable
        data class DisplayInfo(
            val display: Boolean = false
        )
    }
}

@Serializable
data class NavInfo(
    val isLogin: Boolean = false,
    val wbiImg: WbiImg? = null
) {
    @Serializable
    data class WbiImg(
        val imgUrl: String = "",
        val subUrl: String = ""
    )
}
