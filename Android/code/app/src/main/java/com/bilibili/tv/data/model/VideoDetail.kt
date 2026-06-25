package com.bilibili.tv.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class VideoDetail(
    @SerialName("View") val view: Info,
    @SerialName("Related") val related: List<Info> = emptyList(),
    @SerialName("Card") val card: Card = Card()
) {
    @Serializable
    data class Info(
        val aid: Long = 0,
        val cid: Long = 0,
        val title: String = "",
        val pic: String? = null,
        val desc: String? = null,
        val dynamic: String? = null,
        val owner: VideoOwner = VideoOwner(),
        val duration: Int = 0,
        val pubdate: Long = 0,
        val stat: Stat = Stat(),
        val pages: List<VideoPage>? = null,
        val bvid: String? = null,
        @SerialName("ugc_season") val ugcSeason: UgcSeason? = null
    )

    @Serializable
    data class VideoOwner(
        val mid: Long = 0,
        val name: String = "",
        val face: String? = null
    )

    @Serializable
    data class Stat(
        val view: Long = 0,
        val danmaku: Long = 0,
        val like: Long = 0,
        val coin: Long = 0,
        val favorite: Long = 0,
        val share: Long = 0,
        val reply: Long = 0
    )

    @Serializable
    data class VideoPage(
        val cid: Long = 0,
        val page: Int = 0,
        val part: String = "",
        val duration: Int = 0
    )

    @Serializable
    data class UgcSeason(
        val id: Long = 0,
        val title: String = "",
        val cover: String? = null,
        val mid: Long = 0,
        val sections: List<Section> = emptyList()
    ) {
        @Serializable
        data class Section(
            @SerialName("season_id") val seasonId: Long = 0,
            val id: Long = 0,
            val title: String = "",
            val episodes: List<UgcEpisode> = emptyList()
        )

        @Serializable
        data class UgcEpisode(
            val id: Long = 0,
            val aid: Long = 0,
            val cid: Long = 0,
            val title: String = "",
            val arc: Arc = Arc()
        ) {
            @Serializable
            data class Arc(
                val pic: String = "",
                val ctime: Long = 0
            )
        }
    }

    @Serializable
    data class Card(
        val card: CardInfo? = null,
        val following: Boolean = false,
        val follower: Long = 0
    ) {
        @Serializable
        data class CardInfo(
            val mid: String = "",
            val name: String = "",
            val face: String = "",
            val fans: Long = 0,
            val attention: Long = 0,
            val sign: String = ""
        )
    }
}

@Serializable
data class Replys(
    val replies: List<Reply>? = null
) {
    @Serializable
    data class Reply(
        val rpid: Long = 0,
        val mid: Long = 0,
        val like: Long = 0,
        val rcount: Long = 0,
        val ctime: Long = 0,
        val member: Member = Member(),
        val content: Content = Content(),
        val replies: List<Reply>? = null
    ) {
        @Serializable
        data class Member(
            val uname: String = "",
            val avatar: String = ""
        )

        @Serializable
        data class Content(
            val message: String = "",
            val pictures: List<Picture>? = null
        ) {
            @Serializable
            data class Picture(
                @SerialName("img_src") val imgSrc: String = ""
            )
        }
    }
}
