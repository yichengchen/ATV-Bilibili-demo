package com.bilibili.tv.danmaku

import com.bilibili.tv.data.remote.DanmakuApi
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class VideoDanmakuProvider @Inject constructor(
    private val danmakuApi: DanmakuApi
) {
    companion object {
        private const val SEGMENT_DURATION = 360
        private const val ADVANCE_LOAD_SECONDS = 30
        private const val MAX_CACHED_SEGMENTS = 3
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    private var cid: Long = 0
    private var upDanmus = listOf<Danmu>()
    private val segmentCache = mutableMapOf<Int, List<Danmu>>()
    private val fetchStatus = mutableMapOf<Int, Boolean>()
    private var danmuIndex = 0
    private var upDanmuIndex = 0
    private var lastTime = 0.0
    private var lastSegmentIdx = 0

    var onDanmuReady: ((List<Danmu>) -> Unit)? = null
    var isInitialized = false
        private set

    private val fetchJobs = mutableMapOf<Int, Job>()

    suspend fun init(cid: Long, startPos: Int = 0) {
        this.cid = cid
        fetchJobs.values.forEach { it.cancel() }
        fetchJobs.clear()
        segmentCache.clear()
        fetchStatus.clear()
        upDanmus = emptyList()
        danmuIndex = 0
        upDanmuIndex = 0
        lastTime = 0.0
        lastSegmentIdx = 0
        isInitialized = false

        try {
            // Fetch UP danmu
            val viewReply = danmakuApi.getDanmakuWebView(cid)
            if (viewReply != null) {
                upDanmus = viewReply.commandDmsList
                    .filter { it.command == "#UP#" }
                    .map { Danmu.fromCommandDm(it) }
                    .sortedBy { it.time }
            }

            // Fetch first segment
            val startSegment = getSegmentIdx(startPos.toDouble())
            fetchSegment(cid, startSegment)

            isInitialized = true
            Timber.d("[dm] cid=$cid initialized, up=${upDanmus.size}")
        } catch (e: Exception) {
            Timber.e(e, "[dm] cid=$cid init failed")
        }
    }

    fun playerTimeChanged(time: Double) {
        if (!isInitialized || cid == 0L) return

        // Pre-fetch nearby segments
        prefetchSegments(time)

        val segmentIdx = getSegmentIdx(time)
        val segmentDanmus = segmentCache[segmentIdx] ?: return

        // Handle seek
        val diff = time - lastTime
        if (diff > 5 || diff < 0) {
            danmuIndex = segmentDanmus.indexOfFirst { it.time > time }.let { if (it == -1) segmentDanmus.size else it }
            upDanmuIndex = upDanmus.indexOfFirst { it.time > time }.let { if (it == -1) upDanmus.size else it }
            lastTime = time
            lastSegmentIdx = segmentIdx
            return
        } else if (segmentIdx == lastSegmentIdx + 1) {
            danmuIndex = 0
        }

        val fromTime = lastTime
        lastTime = time
        lastSegmentIdx = segmentIdx

        val ready = mutableListOf<Danmu>()

        // Dispatch UP danmu
        while (upDanmuIndex < upDanmus.size) {
            val dm = upDanmus[upDanmuIndex]
            if (dm.time > time) break
            upDanmuIndex++
            if (dm.time > fromTime) ready.add(dm)
        }

        // Dispatch regular danmu
        while (danmuIndex < segmentDanmus.size) {
            val dm = segmentDanmus[danmuIndex]
            if (dm.time > time) break
            danmuIndex++
            if (dm.time > fromTime) ready.add(dm)
        }

        if (ready.isNotEmpty()) {
            Timber.d("[dm] dispatching ${ready.size} danmu at t=${"%.1f".format(time)}")
            onDanmuReady?.invoke(ready)
        }
    }

    private fun prefetchSegments(time: Double) {
        val currentSeg = getSegmentIdx(time)
        pruneSegmentCache(currentSeg)
        val remaining = SEGMENT_DURATION - (time % SEGMENT_DURATION)

        if (segmentCache[currentSeg] == null && fetchStatus[currentSeg] != true) {
            launchFetch(currentSeg)
        }

        if (remaining < ADVANCE_LOAD_SECONDS && segmentCache[currentSeg + 1] == null && fetchStatus[currentSeg + 1] != true) {
            launchFetch(currentSeg + 1)
        }

        val elapsed = time % SEGMENT_DURATION
        if (elapsed < ADVANCE_LOAD_SECONDS && currentSeg > 1 && segmentCache[currentSeg - 1] == null && fetchStatus[currentSeg - 1] != true) {
            launchFetch(currentSeg - 1)
        }
    }

    private fun pruneSegmentCache(currentSeg: Int) {
        val keepFrom = currentSeg - 1
        val keepTo = currentSeg + 1
        if (segmentCache.size <= MAX_CACHED_SEGMENTS && fetchStatus.size <= MAX_CACHED_SEGMENTS) return
        segmentCache.keys
            .filter { it < keepFrom || it > keepTo }
            .forEach { segmentCache.remove(it) }
        fetchStatus.keys
            .filter { it < keepFrom || it > keepTo }
            .forEach { fetchStatus.remove(it) }
    }

    private fun launchFetch(segmentIdx: Int) {
        fetchStatus[segmentIdx] = true
        fetchJobs[segmentIdx] = scope.launch {
            try {
                fetchSegment(cid, segmentIdx)
            } finally {
                fetchJobs.remove(segmentIdx)
            }
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
            Timber.d("[dm] cid=$cid segment=$segmentIdx loaded ${dms.size} danmu")
        } catch (e: Exception) {
            fetchStatus.remove(segmentIdx)
            Timber.e(e, "[dm] cid=$cid segment=$segmentIdx fetch error")
        }
    }

    fun pause() {
        // No-op for now
    }

    fun resume() {
        // No-op for now
    }

    fun release() {
        fetchJobs.values.forEach { it.cancel() }
        fetchJobs.clear()
        segmentCache.clear()
        fetchStatus.clear()
        upDanmus = emptyList()
        cid = 0
        isInitialized = false
    }

    private fun getSegmentIdx(time: Double): Int {
        return (time / SEGMENT_DURATION).toInt() + 1
    }
}
