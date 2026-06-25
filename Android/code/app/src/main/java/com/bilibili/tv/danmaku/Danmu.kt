package com.bilibili.tv.danmaku

data class Danmu(
    val text: String,
    val time: Double,
    val mode: Int = 1,
    val fontSize: Int = 25,
    val color: Long = 0xFFFFFF,
    val isUp: Boolean = false,
    val aiLevel: Int = 0
) {
    companion object {
        fun fromElem(elem: com.bilibili.tv.data.proto.DmProto.DanmakuElem): Danmu {
            return Danmu(
                text = elem.content,
                time = elem.progress / 1000.0,
                mode = elem.mode,
                fontSize = elem.fontsize,
                color = elem.color.toLong(),
                aiLevel = elem.weight
            )
        }

        fun fromCommandDm(cmd: com.bilibili.tv.data.proto.DmViewProto.CommandDm): Danmu {
            return Danmu(
                text = cmd.content,
                time = cmd.progress / 1000.0,
                isUp = cmd.command == "#UP#"
            )
        }
    }
}
