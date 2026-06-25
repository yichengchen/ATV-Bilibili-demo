package com.bilibili.tv.data.model

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class DynamicFeedInfo(
    val items: List<DynamicFeedData> = emptyList(),
    val offset: String = "",
    val has_more: Boolean = false,
    @SerialName("update_num") val updateNum: Int = 0
) {
    val videoFeeds: List<DynamicFeedData>
        get() = items.filter {
            it.modules.module_dynamic.major?.archive != null ||
                it.modules.module_dynamic.major?.pgc != null
        }
}

@Serializable
data class DynamicFeedData(
    val type: String = "",
    val id_str: String = "",
    val modules: Modules = Modules()
) {
    val aid: Long
        get() = modules.module_dynamic.major?.archive?.aid?.toLongOrNull() ?: 0
    val title: String
        get() = modules.module_dynamic.major?.archive?.title
            ?: modules.module_dynamic.major?.pgc?.title ?: ""
    val ownerName: String
        get() = modules.module_author.name
    val pic: String?
        get() = modules.module_dynamic.major?.archive?.cover
            ?: modules.module_dynamic.major?.pgc?.cover
    val avatar: String?
        get() = modules.module_author.face
    val date: String?
        get() = modules.module_author.pub_time

    @Serializable
    data class Modules(
        val module_author: ModuleAuthor = ModuleAuthor(),
        val module_dynamic: ModuleDynamic = ModuleDynamic()
    ) {
        @Serializable
        data class ModuleAuthor(
            val face: String = "",
            val mid: Long = 0,
            val name: String = "",
            val pub_time: String = ""
        )

        @Serializable
        data class ModuleDynamic(
            val major: Major? = null
        ) {
            @Serializable
            data class Major(
                val archive: Archive? = null,
                val pgc: Pgc? = null
            ) {
                @Serializable
                data class Archive(
                    val aid: String? = null,
                    val cover: String? = null,
                    val title: String? = null,
                    val duration_text: String? = null,
                    val stat: Stat? = null
                ) {
                    @Serializable
                    data class Stat(
                        val danmaku: String? = null,
                        val play: String? = null
                    )
                }

                @Serializable
                data class Pgc(
                    val epid: Long? = null,
                    val title: String? = null,
                    val cover: String? = null
                )
            }
        }
    }
}
