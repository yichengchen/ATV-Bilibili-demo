package com.bilibili.tv.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.settingsDataStore: DataStore<Preferences> by preferencesDataStore("settings")

@Singleton
class SettingsDataStore @Inject constructor(
    @ApplicationContext private val context: Context
) {
    companion object {
        private val KEY_QUALITY = intPreferencesKey("quality")
        private val KEY_DANMU_ENABLED = booleanPreferencesKey("danmu_enabled")
        private val KEY_DANMU_AI_LEVEL = intPreferencesKey("danmu_ai_level")
        private val KEY_PLAYBACK_SPEED_INDEX = intPreferencesKey("playback_speed_index")
    }

    val qualityFlow: Flow<Int> = context.settingsDataStore.data.map { it[KEY_QUALITY] ?: 80 }

    val danmuEnabledFlow: Flow<Boolean> = context.settingsDataStore.data.map { it[KEY_DANMU_ENABLED] ?: true }

    val danmuAiLevelFlow: Flow<Int> = context.settingsDataStore.data.map { it[KEY_DANMU_AI_LEVEL] ?: 1 }

    val playbackSpeedIndexFlow: Flow<Int> = context.settingsDataStore.data.map { it[KEY_PLAYBACK_SPEED_INDEX] ?: 2 }

    suspend fun setQuality(qn: Int) {
        context.settingsDataStore.edit { it[KEY_QUALITY] = qn }
    }

    suspend fun setDanmuEnabled(enabled: Boolean) {
        context.settingsDataStore.edit { it[KEY_DANMU_ENABLED] = enabled }
    }

    suspend fun setDanmuAiLevel(level: Int) {
        context.settingsDataStore.edit { it[KEY_DANMU_AI_LEVEL] = level }
    }

    suspend fun setPlaybackSpeedIndex(index: Int) {
        context.settingsDataStore.edit { it[KEY_PLAYBACK_SPEED_INDEX] = index }
    }
}
