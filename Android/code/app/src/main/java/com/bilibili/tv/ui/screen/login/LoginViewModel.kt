package com.bilibili.tv.ui.screen.login

import androidx.compose.runtime.getValue
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.bilibili.tv.data.repository.AuthRepository
import com.bilibili.tv.data.repository.LoginState
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import timber.log.Timber
import javax.inject.Inject

data class LoginUiState(
    val qrUrl: String = "",
    val isLoading: Boolean = true,
    val status: String = "",
    val isSuccess: Boolean = false
)

@HiltViewModel
class LoginViewModel @Inject constructor(
    private val authRepository: AuthRepository
) : ViewModel() {

    private val _uiState = MutableStateFlow(LoginUiState())
    val uiState: StateFlow<LoginUiState> = _uiState

    private var authCode: String = ""
    private var pollJob: Job? = null

    init {
        generateQrCode()
    }

    fun generateQrCode() {
        viewModelScope.launch {
            try {
                _uiState.value = LoginUiState(isLoading = true)
                val (code, url) = authRepository.getLoginQrCode()
                authCode = code
                _uiState.value = LoginUiState(qrUrl = url, isLoading = false)
                startPolling()
            } catch (e: Exception) {
                Timber.e(e, "Failed to get QR code")
                _uiState.value = LoginUiState(isLoading = false, status = "生成二维码失败，请重试")
            }
        }
    }

    private fun startPolling() {
        pollJob?.cancel()
        pollJob = viewModelScope.launch {
            var count = 0
            while (count < 150) {
                delay(4000)
                count++
                try {
                    when (authRepository.pollLogin(authCode)) {
                        LoginState.Success -> {
                            _uiState.value = _uiState.value.copy(isSuccess = true, status = "登录成功")
                            return@launch
                        }
                        LoginState.Waiting -> { /* keep polling */ }
                        LoginState.Expired -> {
                            _uiState.value = _uiState.value.copy(status = "二维码已过期，请重新生成")
                            return@launch
                        }
                        LoginState.Failed -> {
                            _uiState.value = _uiState.value.copy(status = "登录失败")
                            return@launch
                        }
                    }
                } catch (e: Exception) {
                    Timber.e(e, "Poll error")
                }
            }
            _uiState.value = _uiState.value.copy(status = "二维码已过期，请重新生成")
        }
    }

    override fun onCleared() {
        pollJob?.cancel()
        super.onCleared()
    }
}
