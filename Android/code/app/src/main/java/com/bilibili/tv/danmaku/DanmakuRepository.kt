package com.bilibili.tv.danmaku

import com.bilibili.tv.data.remote.DanmakuApi
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class DanmakuRepository @Inject constructor(
    private val danmakuApi: DanmakuApi
) {
    companion object {
        private const val SEGMENT_DURATION = 360
    }

    private val segmentCache = mutableMapOf<Int, List<Danmu>>()
    private val fetchStatus = mutableMapOf<Int, Boolean>()
    private var upDanmus = listOf<Danmu>()

    suspend fun init(cid: Long) {
        segmentCache.clear()
        fetchStatus.clear()
        upDanmus = emptyList()

        coroutineScope {
            val viewJob = async { fetchUpDanmus(cid) }
            val segmentIdx = 1
            fetchStatus[segmentIdx] = true
            val listJob = async { fetchSegment(cid, segmentIdx) }
            viewJob.await()
            listJob.await()
        }
    }

    private suspend fun fetchUpDanmus(cid: Long) {
        try {
            val reply = danmakuApi.getDanmakuWebView(cid) ?: return
            upDanmus = reply.commandDmsList
                .filter { it.command == "#UP#" }
                .map { Danmu.fromCommandDm(it) }
                .sortedBy { it.time }
            Timber.d("[dm] cid=$cid up danmu count: ${upDanmus.size}")
        } catch (e: Exception) {
            Timber.e(e, "[dm] cid=$cid fetchUpDanmus error")
        }
    }

    private suspend fun fetchSegment(cid: Long, segmentIdx: Int) {
        try {
            val reply = danmakuApi.getDanmakuList(cid, segmentIdx) ?: return
            val dms = reply.elemsList
                .filter { it.mode <= 5 }
                .map { Danmu.fromElem(it) }
                .sortedBy { it.time }
            segmentCache[segmentIdx] = dms
            Timber.d("[dm] cid=$cid segment=$segmentIdx danmu count: ${dms.size}")
        } catch (e: Exception) {
            fetchStatus.remove(segmentIdx)
            Timber.e(e, "[dm] cid=$cid segment=$segmentIdx fetch error")
        }
    }

    fun getDanmuAtTime(time: Double, aiLevel: Int = 1): List<Danmu> {
        val segmentIdx = getSegmentIdx(time)
        ensureSegmentLoaded(segmentIdx)

        val result = mutableListOf<Danmu>()

        // UP danmu
        upDanmus.filter { it.time <= time && it.time > time - 1.0 }.forEach { result.add(it) }

        // Regular danmu from current segment
        segmentCache[segmentIdx]?.filter {
            it.time <= time && it.time > time - 1.0 && it.aiLevel >= aiLevel
        }?.forEach { result.add(it) }

        return result
    }

    fun getAllDanmuForSegment(segmentIdx: Int): List<Danmu> {
        return segmentCache[segmentIdx] ?: emptyList()
    }

    fun getSegmentCount(): Int {
        return segmentCache.keys.maxOrNull() ?: 0
    }

    private fun ensureSegmentLoaded(segmentIdx: Int) {
        // This is a placeholder - actual fetching happens in VideoDanmakuProvider
    }

    private fun getSegmentIdx(time: Double): Int {
        return (time / SEGMENT_DURATION).toInt() + 1
    }
}
