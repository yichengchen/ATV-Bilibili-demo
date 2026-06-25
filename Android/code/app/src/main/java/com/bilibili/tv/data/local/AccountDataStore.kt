package com.bilibili.tv.data.local

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import com.bilibili.tv.data.model.Account
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import javax.inject.Inject
import javax.inject.Singleton

private val Context.accountDataStore: DataStore<Preferences> by preferencesDataStore("accounts")

@Singleton
class AccountDataStore @Inject constructor(
    @ApplicationContext private val context: Context,
    private val json: Json
) {
    companion object {
        private val KEY_ACCOUNTS = stringPreferencesKey("accounts_list")
        private val KEY_ACTIVE_MID = intPreferencesKey("active_mid")
    }

    val accountsFlow: Flow<List<Account>> = context.accountDataStore.data.map { prefs ->
        prefs[KEY_ACCOUNTS]?.let { json.decodeFromString<List<Account>>(it) } ?: emptyList()
    }

    val activeAccountFlow: Flow<Account?> = context.accountDataStore.data.map { prefs ->
        val accounts = prefs[KEY_ACCOUNTS]?.let { json.decodeFromString<List<Account>>(it) } ?: emptyList()
        val mid = prefs[KEY_ACTIVE_MID] ?: return@map accounts.maxByOrNull { it.lastActiveAt }
        accounts.firstOrNull { it.profile.mid == mid } ?: accounts.maxByOrNull { it.lastActiveAt }
    }

    suspend fun isLoggedIn(): Boolean {
        val accounts = accountsFlow.first()
        return accounts.isNotEmpty()
    }

    suspend fun getActiveAccount(): Account? = activeAccountFlow.first()

    suspend fun upsertAccount(account: Account) {
        context.accountDataStore.edit { prefs ->
            val accounts = prefs[KEY_ACCOUNTS]?.let { json.decodeFromString<MutableList<Account>>(it) } ?: mutableListOf()
            val idx = accounts.indexOfFirst { it.profile.mid == account.profile.mid }
            if (idx >= 0) accounts[idx] = account else accounts.add(account)
            prefs[KEY_ACCOUNTS] = json.encodeToString(accounts)
            prefs[KEY_ACTIVE_MID] = account.profile.mid
        }
    }

    suspend fun setActiveMid(mid: Int) {
        context.accountDataStore.edit { it[KEY_ACTIVE_MID] = mid }
    }

    suspend fun removeAccount(mid: Int) {
        context.accountDataStore.edit { prefs ->
            val accounts = prefs[KEY_ACCOUNTS]?.let { json.decodeFromString<MutableList<Account>>(it) } ?: mutableListOf()
            accounts.removeAll { it.profile.mid == mid }
            prefs[KEY_ACCOUNTS] = json.encodeToString(accounts)
            if (prefs[KEY_ACTIVE_MID] == mid) {
                prefs[KEY_ACTIVE_MID] = accounts.maxByOrNull { it.lastActiveAt }?.profile?.mid ?: 0
            }
        }
    }

    suspend fun clear() {
        context.accountDataStore.edit { it.clear() }
    }
}
