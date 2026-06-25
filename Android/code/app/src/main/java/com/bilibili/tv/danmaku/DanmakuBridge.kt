package com.bilibili.tv.danmaku

import android.content.Context
import android.graphics.Color
import android.util.AttributeSet
import android.util.Log
import master.flame.danmaku.danmaku.model.BaseDanmaku
import master.flame.danmaku.danmaku.model.DanmakuTimer
import master.flame.danmaku.danmaku.model.android.DanmakuContext
import master.flame.danmaku.danmaku.model.android.Danmakus
import master.flame.danmaku.controller.DrawHandler
import master.flame.danmaku.danmaku.parser.BaseDanmakuParser
import master.flame.danmaku.ui.widget.DanmakuView

class DanmakuBridge : DanmakuView {
    constructor(context: Context) : super(context)
    constructor(context: Context, attrs: AttributeSet?) : super(context, attrs)

    private val danmakuContext = DanmakuContext.create()
    private var isPrepared = false
    private val pendingDanmus = mutableListOf<Danmu>()

    private companion object {
        private const val TV_TEXT_SCALE = 1.6f
        private const val DEFAULT_TEXT_SIZE = 40f
        private const val MIN_TEXT_SIZE = 36f
        private const val MAX_PENDING_DANMUS = 300
    }

    fun prepareAndStart() {
        Log.d("DanmakuBridge", "prepareAndStart")
        isPrepared = false
        val parser = object : BaseDanmakuParser() {
            override fun parse(): Danmakus = Danmakus()
        }
        setCallback(object : DrawHandler.Callback {
            override fun prepared() {
                isPrepared = true
                start()
                show()
                flushPendingDanmus()
                Log.d("DanmakuBridge", "prepared and started")
            }

            override fun updateTimer(timer: DanmakuTimer?) = Unit

            override fun danmakuShown(danmaku: BaseDanmaku?) = Unit

            override fun drawingFinished() = Unit
        })
        enableDanmakuDrawingCache(false)
        prepare(parser, danmakuContext)
    }

    fun shootDanmu(danmu: Danmu) {
        if (!isPrepared) {
            if (pendingDanmus.size >= MAX_PENDING_DANMUS) {
                pendingDanmus.removeAt(0)
            }
            pendingDanmus.add(danmu)
            return
        }

        val type = when (danmu.mode) {
            4 -> BaseDanmaku.TYPE_FIX_BOTTOM
            5 -> BaseDanmaku.TYPE_FIX_TOP
            else -> BaseDanmaku.TYPE_SCROLL_RL
        }

        val danmaku = danmakuContext.mDanmakuFactory.createDanmaku(type) ?: return
        danmaku.text = if (danmu.isUp) "UP: ${danmu.text}" else danmu.text
        danmaku.textColor = danmu.color.toInt().let { c ->
            if (c == 0) Color.WHITE else c or 0xFF000000.toInt()
        }
        danmaku.textSize = danmu.fontSize.toFloat()
            .let { if (it <= 0) DEFAULT_TEXT_SIZE else it * TV_TEXT_SCALE }
            .coerceAtLeast(MIN_TEXT_SIZE)
        danmaku.isLive = true
        danmaku.setTime(getCurrentTime() + 100)
        danmaku.priority = if (danmu.isUp) 1 else 0
        addDanmaku(danmaku)
    }

    fun shootDanmuList(danmus: List<Danmu>) {
        danmus.forEach { shootDanmu(it) }
    }

    private fun flushPendingDanmus() {
        if (pendingDanmus.isEmpty()) return
        val danmus = pendingDanmus.toList()
        pendingDanmus.clear()
        danmus.forEach { shootDanmu(it) }
    }

    fun toggleVisibility() {
        if (isShown) hide() else show()
    }
}
