package com.bilibili.tv.ui.screen.player

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.net.Uri
import android.util.Base64
import android.view.LayoutInflater
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.focusable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.key.Key
import androidx.compose.ui.input.key.KeyEventType
import androidx.compose.ui.input.key.key
import androidx.compose.ui.input.key.onKeyEvent
import androidx.compose.ui.input.key.type
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.ViewModel
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.PlaybackException
import androidx.media3.common.Player
import androidx.media3.common.MimeTypes
import androidx.media3.common.util.UnstableApi
import androidx.media3.datasource.DefaultDataSource
import androidx.media3.datasource.DefaultHttpDataSource
import androidx.media3.exoplayer.DefaultLoadControl
import androidx.media3.exoplayer.DefaultRenderersFactory
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.exoplayer.dash.DashMediaSource
import androidx.media3.exoplayer.trackselection.DefaultTrackSelector
import androidx.media3.common.MediaItem
import androidx.media3.ui.PlayerView
import androidx.tv.material3.ExperimentalTvMaterial3Api
import androidx.tv.material3.Icon
import androidx.tv.material3.Text
import com.bilibili.tv.R
import com.bilibili.tv.danmaku.DanmakuBridge
import com.bilibili.tv.danmaku.VideoDanmakuProvider
import com.bilibili.tv.data.local.SettingsDataStore
import com.bilibili.tv.data.remote.Constants
import com.bilibili.tv.data.model.PlayUrlInfo
import com.bilibili.tv.data.repository.FeedRepository
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import timber.log.Timber
import javax.inject.Inject

data class PlayerUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val title: String = "",
    val ownerName: String = "",
    val cid: Long = 0,
    val requestedQuality: Int = 80,
    val playUrlInfo: PlayUrlInfo? = null
)

data class SpeedOption(val label: String, val value: Float)

private data class PlayerOverlayState(
    val toast: String? = null,
    val controlsVisible: Boolean = false
)

val SPEED_OPTIONS = listOf(
    SpeedOption("0.5x", 0.5f),
    SpeedOption("0.75x", 0.75f),
    SpeedOption("1x", 1.0f),
    SpeedOption("1.25x", 1.25f),
    SpeedOption("1.5x", 1.5f),
    SpeedOption("2x", 2.0f)
)

@HiltViewModel
class PlayerViewModel @Inject constructor(
    private val feedRepository: FeedRepository,
    private val danmakuProvider: VideoDanmakuProvider,
    private val settingsDataStore: SettingsDataStore
) : ViewModel() {
    var uiState by mutableStateOf(PlayerUiState())
        private set

    suspend fun loadPlayUrl(aid: Long, cid: Long) {
        uiState = uiState.copy(isLoading = true, error = null)
        try {
            val detail = withContext(Dispatchers.IO) { feedRepository.getVideoDetail(aid) }
            val view = detail.view
            val realCid = if (cid == 0L) (view.pages?.firstOrNull()?.cid ?: aid) else cid
            val quality = settingsDataStore.qualityFlow.first()
            val playInfo = withContext(Dispatchers.IO) {
                feedRepository.getPlayUrl(aid = aid, cid = realCid, qn = quality, fnval = 4048)
            }
            uiState = uiState.copy(
                isLoading = false,
                title = view.title,
                ownerName = view.owner.name,
                cid = realCid,
                requestedQuality = quality,
                playUrlInfo = playInfo
            )
            withContext(Dispatchers.IO) { danmakuProvider.init(realCid) }
        } catch (e: Exception) {
            Timber.e(e, "Load play URL failed")
            uiState = uiState.copy(isLoading = false, error = e.message)
        }
    }

    fun getDanmakuProvider() = danmakuProvider
    suspend fun isDanmuEnabled() = settingsDataStore.danmuEnabledFlow.first()
    suspend fun getPlaybackSpeedIndex() = settingsDataStore.playbackSpeedIndexFlow.first()
    suspend fun setPlaybackSpeedIndex(index: Int) = settingsDataStore.setPlaybackSpeedIndex(index)
    suspend fun setDanmuEnabled(enabled: Boolean) = settingsDataStore.setDanmuEnabled(enabled)

    override fun onCleared() {
        danmakuProvider.release()
        super.onCleared()
    }
}

@UnstableApi
@OptIn(ExperimentalTvMaterial3Api::class)
@Composable
fun PlayerScreen(
    aid: Long,
    cid: Long,
    onBack: () -> Unit,
    viewModel: PlayerViewModel = hiltViewModel()
) {
    val context = LocalContext.current
    val composeView = LocalView.current
    val playerFocusRequester = remember { FocusRequester() }
    val coroutineScope = rememberCoroutineScope()
    var isDanmuVisible by remember { mutableStateOf(true) }
    var isPlaying by remember { mutableStateOf(true) }
    var isBuffering by remember { mutableStateOf(false) }
    var currentPosition by remember { mutableLongStateOf(0L) }
    var duration by remember { mutableLongStateOf(0L) }
    var speedIndex by remember { mutableStateOf(2) }
    var overlayState by remember { mutableStateOf(PlayerOverlayState()) }
    var overlayAutoHideToken by remember { mutableLongStateOf(0L) }
    var playbackError by remember { mutableStateOf<String?>(null) }
    val speedOption = SPEED_OPTIONS[speedIndex]
    val showTimedOverlay: (String?) -> Unit = { toast ->
        overlayState = PlayerOverlayState(toast = toast, controlsVisible = true)
        overlayAutoHideToken++
    }

    val danmakuBridge = remember { DanmakuBridge(context) }

    DisposableEffect(context, composeView) {
        val activity = context.findActivity()
        val window = activity?.window
        val hadKeepScreenOnFlag = window
            ?.attributes
            ?.flags
            ?.let { it and WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON != 0 }
            ?: false
        val oldViewKeepScreenOn = composeView.keepScreenOn

        composeView.keepScreenOn = true
        window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        onDispose {
            composeView.keepScreenOn = oldViewKeepScreenOn
            if (!hadKeepScreenOnFlag) {
                window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    LaunchedEffect(aid, cid) {
        playbackError = null
        viewModel.loadPlayUrl(aid, cid)
        isDanmuVisible = viewModel.isDanmuEnabled()
        speedIndex = viewModel.getPlaybackSpeedIndex().coerceIn(SPEED_OPTIONS.indices)
    }

    BackHandler { onBack() }

    val state = viewModel.uiState

    if (state.isLoading) {
        Box(Modifier.fillMaxSize().background(Color.Black), Alignment.Center) {
            Text("加载中...", color = Color.White, fontSize = 20.sp)
        }
        return
    }
    if (state.error != null) {
        Box(Modifier.fillMaxSize().background(Color.Black), Alignment.Center) {
            Text("播放失败: ${state.error}", color = Color.White)
        }
        return
    }

    val playUrlInfo = state.playUrlInfo
    val dashInfo = playUrlInfo?.dash
    if (dashInfo == null) {
        Box(Modifier.fillMaxSize().background(Color.Black), Alignment.Center) {
            Text("无可用播放地址", color = Color.White)
        }
        return
    }

    val loadControl = remember {
        DefaultLoadControl.Builder()
            .setBufferDurationsMs(
                10_000,
                30_000,
                1_500,
                3_000
            )
            .build()
    }
    val exoPlayer = remember {
        val trackSelector = DefaultTrackSelector(context).apply {
            setParameters(
                buildUponParameters()
                    .setPreferredVideoMimeTypes(MimeTypes.VIDEO_H264, MimeTypes.VIDEO_H265)
                    .setAllowVideoMixedMimeTypeAdaptiveness(false)
                    .setExceedRendererCapabilitiesIfNecessary(false)
                    .setForceHighestSupportedBitrate(false)
            )
        }
        ExoPlayer.Builder(context)
            .setRenderersFactory(
                DefaultRenderersFactory(context)
                    .setEnableDecoderFallback(true)
            )
            .setTrackSelector(trackSelector)
            .setLoadControl(loadControl)
            .build()
    }
    val danmuProvider = viewModel.getDanmakuProvider()

    DisposableEffect(danmuProvider, danmakuBridge) {
        danmakuBridge.post { danmakuBridge.prepareAndStart() }
        danmuProvider.onDanmuReady = { danmus ->
            danmakuBridge.post { danmakuBridge.shootDanmuList(danmus) }
        }

        onDispose {
            danmuProvider.onDanmuReady = null
            danmakuBridge.release()
        }
    }

    // ExoPlayer lifecycle
    DisposableEffect(Unit) {
        val listener = object : Player.Listener {
            override fun onIsPlayingChanged(playing: Boolean) {
                isPlaying = playing
                if (playing) {
                    danmuProvider.resume()
                    danmakuBridge.resume()
                } else {
                    danmuProvider.pause()
                    danmakuBridge.pause()
                }
            }
            override fun onPositionDiscontinuity(oldPos: Player.PositionInfo, newPos: Player.PositionInfo, reason: Int) {
                if (reason == Player.DISCONTINUITY_REASON_SEEK) {
                    danmuProvider.playerTimeChanged(newPos.positionMs / 1000.0)
                    danmakuBridge.seekTo(newPos.positionMs)
                }
            }
            override fun onPlaybackStateChanged(playbackState: Int) {
                isBuffering = playbackState == Player.STATE_BUFFERING
                Timber.d(
                    "[player] state=${playbackStateName(playbackState)}, playWhenReady=${exoPlayer.playWhenReady}, " +
                        "pos=${exoPlayer.currentPosition}, buffered=${exoPlayer.bufferedPosition}, duration=${exoPlayer.duration}"
                )
                if (playbackState == Player.STATE_READY) {
                    playbackError = null
                    duration = exoPlayer.duration.coerceAtLeast(0L)
                }
            }

            override fun onPlayerError(error: PlaybackException) {
                playbackError = error.localizedMessage ?: "播放失败"
                Timber.e(error, "[player] playback error")
                showTimedOverlay(playbackError ?: "播放失败")
            }
        }
        exoPlayer.addListener(listener)

        onDispose {
            exoPlayer.removeListener(listener)
            exoPlayer.release()
        }
    }

    LaunchedEffect(exoPlayer, danmuProvider) {
        while (true) {
            if (exoPlayer.isPlaying) {
                currentPosition = exoPlayer.currentPosition
                duration = exoPlayer.duration.coerceAtLeast(0L)
                danmuProvider.playerTimeChanged(exoPlayer.currentPosition / 1000.0)
            }
            delay(500)
        }
    }

    // Media source
    LaunchedEffect(dashInfo) {
        val mpd = buildBiliDashManifest(dashInfo)
        if (mpd == null) {
            playbackError = "无可用 DASH 轨道"
            showTimedOverlay(playbackError)
            return@LaunchedEffect
        }
        Timber.d(
            "[player] dash reps video=${dashInfo.video.size}, audio=${dashInfo.audio?.size ?: 0}, " +
                "quality=${state.requestedQuality}, duration=${dashInfo.duration}"
        )
        val httpFactory = DefaultHttpDataSource.Factory()
            .setDefaultRequestProperties(mapOf("User-Agent" to Constants.USER_AGENT, "Referer" to Constants.REFERER))
        val dsFactory = DefaultDataSource.Factory(context, httpFactory)
        val mpdUri = Uri.parse(
            "data:application/dash+xml;base64," +
                Base64.encodeToString(mpd.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)
        )
        val source = DashMediaSource.Factory(dsFactory).createMediaSource(MediaItem.fromUri(mpdUri))
        exoPlayer.setMediaSource(source)
        exoPlayer.prepare()
        exoPlayer.playWhenReady = true
    }

    LaunchedEffect(speedOption) { exoPlayer.playbackParameters = PlaybackParameters(speedOption.value) }

    LaunchedEffect(overlayAutoHideToken) {
        if (overlayAutoHideToken > 0) {
            delay(2000)
            overlayState = PlayerOverlayState()
        }
    }

    LaunchedEffect(state.cid) {
        if (state.cid == 0L) return@LaunchedEffect
        withFrameNanos { }
        playerFocusRequester.requestFocus()
        overlayState = PlayerOverlayState(controlsVisible = true)
        delay(2500)
        overlayState = PlayerOverlayState()
    }

    Box(
        Modifier
            .fillMaxSize()
            .background(Color.Black)
    ) {
        // ── Video surface (Compose AndroidView) ──
        AndroidView(
            factory = {
                (LayoutInflater.from(context).inflate(R.layout.player_view_texture, null) as PlayerView).apply {
                    player = exoPlayer
                    setBackgroundColor(android.graphics.Color.BLACK)
                    setShutterBackgroundColor(android.graphics.Color.BLACK)
                    layoutParams = FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT)
                }
            },
            modifier = Modifier
                .fillMaxSize()
                .focusRequester(playerFocusRequester)
                .onKeyEvent { event ->
                    if (event.type != KeyEventType.KeyDown) return@onKeyEvent false
                    when (event.key) {
                        Key.Back, Key.Escape -> { onBack(); true }
                        Key.DirectionCenter, Key.Enter -> {
                            exoPlayer.playWhenReady = !exoPlayer.playWhenReady
                            showTimedOverlay(if (exoPlayer.playWhenReady) "播放" else "暂停")
                            true
                        }
                        Key.DirectionLeft -> {
                            val t = maxOf(0L, exoPlayer.currentPosition - 10000); exoPlayer.seekTo(t)
                            currentPosition = t; showTimedOverlay(fmtTime(t)); true
                        }
                        Key.DirectionRight -> {
                            val t = if (duration > 0) minOf(duration, exoPlayer.currentPosition + 10000) else exoPlayer.currentPosition + 10000
                            exoPlayer.seekTo(t)
                            currentPosition = t; showTimedOverlay(fmtTime(t)); true
                        }
                        Key.DirectionUp -> {
                            isDanmuVisible = !isDanmuVisible
                            if (isDanmuVisible) danmakuBridge.show() else danmakuBridge.hide()
                            coroutineScope.launch { viewModel.setDanmuEnabled(isDanmuVisible) }
                            showTimedOverlay(if (isDanmuVisible) "弹幕 ON" else "弹幕 OFF"); true
                        }
                        Key.DirectionDown -> {
                            speedIndex = (speedIndex + 1) % SPEED_OPTIONS.size
                            coroutineScope.launch { viewModel.setPlaybackSpeedIndex(speedIndex) }
                            showTimedOverlay("倍速 ${SPEED_OPTIONS[speedIndex].label}"); true
                        }
                        else -> false
                    }
                }
                .focusable()
        )

        AndroidView(
            factory = {
                danmakuBridge.apply {
                    isFocusable = false
                    isClickable = false
                    layoutParams = FrameLayout.LayoutParams(
                        ViewGroup.LayoutParams.MATCH_PARENT,
                        ViewGroup.LayoutParams.MATCH_PARENT
                    )
                }
            },
            update = {
                if (isDanmuVisible) it.show() else it.hide()
            },
            modifier = Modifier.fillMaxSize()
        )

        // ── OSD ──
        AnimatedVisibility(visible = overlayState.toast != null, enter = fadeIn(), exit = fadeOut(), modifier = Modifier.align(Alignment.Center)) {
            Box(Modifier.clip(RoundedCornerShape(12.dp)).background(Color.Black.copy(alpha = 0.7f)).padding(horizontal = 32.dp, vertical = 16.dp)) {
                Text(overlayState.toast.orEmpty(), color = Color.White, fontSize = 28.sp, fontWeight = FontWeight.Bold)
            }
        }

        // ── Bottom bar ──
        AnimatedVisibility(visible = overlayState.controlsVisible || !isPlaying || isBuffering || playbackError != null, enter = fadeIn(), exit = fadeOut(), modifier = Modifier.align(Alignment.BottomCenter).fillMaxWidth()) {
        Column(Modifier.fillMaxWidth().background(Brush.verticalGradient(listOf(Color.Transparent, Color.Black.copy(alpha = 0.8f)))).padding(horizontal = 48.dp, vertical = 24.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.CenterVertically) {
                Text(state.title, color = Color.White, fontSize = 18.sp, fontWeight = FontWeight.Medium, maxLines = 1, modifier = Modifier.weight(1f))
                if (speedOption.value != 1.0f) Text(speedOption.label, color = Color(0xFF00A1D6), fontSize = 16.sp, fontWeight = FontWeight.Bold)
            }
            Spacer(Modifier.height(12.dp))
            val progress = if (duration > 0) currentPosition.toFloat() / duration else 0f
            Box(Modifier.fillMaxWidth().height(4.dp).clip(RoundedCornerShape(2.dp)).background(Color.White.copy(alpha = 0.2f))) {
                Box(Modifier.fillMaxWidth(fraction = progress).height(4.dp).clip(RoundedCornerShape(2.dp)).background(Color(0xFF00A1D6)))
            }
            Spacer(Modifier.height(8.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text(fmtTime(currentPosition), color = Color.White.copy(alpha = 0.8f), fontSize = 14.sp)
                Text(fmtTime(duration), color = Color.White.copy(alpha = 0.8f), fontSize = 14.sp)
            }
            Spacer(Modifier.height(8.dp))
            val statusText = playbackError ?: if (isBuffering) "缓冲中..." else "←/→ 快进退  ↑弹幕  ↓倍速  确认 暂停"
            Text(statusText, color = if (playbackError != null) Color(0xFFFF6B6B) else Color.White.copy(alpha = 0.4f), fontSize = 12.sp)
        }
    }

    if (!isPlaying && overlayState.toast == null) {
        Box(Modifier.fillMaxSize(), Alignment.Center) {
            Box(Modifier.clip(RoundedCornerShape(50)).background(Color.Black.copy(alpha = 0.5f)).padding(24.dp)) {
                Icon(Icons.Default.PlayArrow, contentDescription = null, tint = Color.White, modifier = Modifier.size(48.dp))
            }
        }
    }
    } // end outer Box
}

private fun fmtTime(ms: Long): String {
    val s = ms / 1000; val h = s / 3600; val m = (s % 3600) / 60; val sec = s % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, sec) else "%d:%02d".format(m, sec)
}

private fun buildBiliDashManifest(dashInfo: PlayUrlInfo.DashInfo): String? {
    val videoReps = dashInfo.video.filter { it.baseUrl.isNotBlank() }
    val audioReps = buildList {
        dashInfo.audio.orEmpty().forEach(::add)
        dashInfo.dolby?.audio.orEmpty().forEach(::add)
        dashInfo.flac?.audio?.let(::add)
    }.distinctBy { it.baseUrl }.filter { it.baseUrl.isNotBlank() }

    if (videoReps.isEmpty()) return null

    val durationSeconds = dashInfo.duration.coerceAtLeast(1)
    return buildString {
        appendLine("""<?xml version="1.0" encoding="UTF-8"?>""")
        appendLine(
            """<MPD xmlns="urn:mpeg:dash:schema:mpd:2011" profiles="urn:mpeg:dash:profile:isoff-on-demand:2011" type="static" minBufferTime="PT1.5S" mediaPresentationDuration="PT${durationSeconds}S">"""
        )
        appendLine("""  <Period id="0" duration="PT${durationSeconds}S">""")
        appendAdaptationSet(
            id = 0,
            contentType = "video",
            mimeTypeFallback = "video/mp4",
            representations = videoReps
        )
        if (audioReps.isNotEmpty()) {
            appendAdaptationSet(
                id = 1,
                contentType = "audio",
                mimeTypeFallback = "audio/mp4",
                representations = audioReps
            )
        }
        appendLine("  </Period>")
        appendLine("</MPD>")
    }
}

private fun StringBuilder.appendAdaptationSet(
    id: Int,
    contentType: String,
    mimeTypeFallback: String,
    representations: List<PlayUrlInfo.DashMediaInfo>
) {
    appendLine("""    <AdaptationSet id="$id" contentType="$contentType" segmentAlignment="true">""")
    representations.forEachIndexed { index, media ->
        val mimeType = media.mimeType.ifBlank { mimeTypeFallback }.xmlEscaped()
        val codecs = media.codecs.xmlEscaped()
        val width = media.width?.let { """ width="$it"""" }.orEmpty()
        val height = media.height?.let { """ height="$it"""" }.orEmpty()
        val frameRate = media.frameRate?.toDashFrameRate()?.let { """ frameRate="$it"""" }.orEmpty()
        val representationId = "${contentType}_${media.id}_$index".xmlEscaped()
        appendLine(
            """      <Representation id="$representationId" bandwidth="${media.bandwidth}" mimeType="$mimeType" codecs="$codecs"$width$height$frameRate>"""
        )
        media.playbackUrls().forEach { url ->
            appendLine("""        <BaseURL>${url.xmlEscaped()}</BaseURL>""")
        }
        appendSegmentBase(media.segmentBase)
        appendLine("      </Representation>")
    }
    appendLine("    </AdaptationSet>")
}

private fun StringBuilder.appendSegmentBase(segmentBase: PlayUrlInfo.DashSegmentBase?) {
    if (segmentBase == null) return
    val initialization = segmentBase.initialization
    val indexRange = segmentBase.indexRange
    if (initialization.isBlank() && indexRange.isBlank()) return

    val indexAttribute = indexRange.takeIf { it.isNotBlank() }?.let { """ indexRange="${it.xmlEscaped()}"""" }.orEmpty()
    appendLine("""        <SegmentBase$indexAttribute>""")
    if (initialization.isNotBlank()) {
        appendLine("""          <Initialization range="${initialization.xmlEscaped()}"/>""")
    }
    appendLine("        </SegmentBase>")
}

private fun PlayUrlInfo.DashMediaInfo.playbackUrls(): List<String> =
    buildList {
        if (baseUrl.isNotBlank()) add(baseUrl)
        backupUrl.orEmpty().filterTo(this) { it.isNotBlank() }
    }.distinct()

private fun String.xmlEscaped(): String =
    replace("&", "&amp;")
        .replace("\"", "&quot;")
        .replace("'", "&apos;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")

private fun String.toDashFrameRate(): String? {
    val value = trim()
    if (value.isBlank()) return null
    if (value.matches(Regex("""\d+(/\d+)?"""))) return value
    val numeric = value.toDoubleOrNull() ?: return null
    return numeric.toInt().coerceAtLeast(1).toString()
}

private fun playbackStateName(state: Int): String = when (state) {
    Player.STATE_IDLE -> "IDLE"
    Player.STATE_BUFFERING -> "BUFFERING"
    Player.STATE_READY -> "READY"
    Player.STATE_ENDED -> "ENDED"
    else -> state.toString()
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
