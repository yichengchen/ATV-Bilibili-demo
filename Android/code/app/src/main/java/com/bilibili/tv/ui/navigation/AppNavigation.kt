package com.bilibili.tv.ui.navigation

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.platform.LocalContext
import androidx.navigation.NavType
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import com.bilibili.tv.data.repository.AuthRepository
import com.bilibili.tv.ui.screen.detail.VideoDetailScreen
import com.bilibili.tv.ui.screen.feed.FeedScreen
import com.bilibili.tv.ui.screen.follows.FollowsScreen
import com.bilibili.tv.ui.screen.followups.FollowUpsScreen
import com.bilibili.tv.ui.screen.history.HistoryScreen
import com.bilibili.tv.ui.screen.home.HomeScreen
import com.bilibili.tv.ui.screen.hot.HotScreen
import com.bilibili.tv.ui.screen.login.LoginScreen
import com.bilibili.tv.ui.screen.player.PlayerScreen
import com.bilibili.tv.ui.screen.ranking.RankingScreen
import com.bilibili.tv.ui.screen.settings.SettingsScreen
import com.bilibili.tv.ui.screen.toview.ToViewScreen
import com.bilibili.tv.ui.screen.upspace.UpSpaceScreen

@Composable
fun AppNavigation(authRepository: AuthRepository) {
    val context = LocalContext.current
    val navController = rememberNavController()
    var startDestination by remember { mutableStateOf<String?>(null) }
    var homeSelectedTab by remember { mutableIntStateOf(0) }
    val homeContentFocusRequesters = remember { List(7) { FocusRequester() } }

    LaunchedEffect(Unit) {
        val cookiesValid = authRepository.loadAccountCookies()
        startDestination = if (cookiesValid) "home" else "login"
    }

    if (startDestination == null) return

    NavHost(navController = navController, startDestination = startDestination!!) {
        composable("login") {
            LoginScreen(
                onLoginSuccess = {
                    navController.navigate("home") {
                        popUpTo("login") { inclusive = true }
                    }
                }
            )
        }

        composable("home") {
            HomeScreen(
                selectedTab = homeSelectedTab,
                onSelectedTabChange = { homeSelectedTab = it },
                contentFocusRequesters = homeContentFocusRequesters,
                onVideoClick = { aid ->
                    navController.navigate("detail/$aid")
                },
                feedContent = { upFocusRequester ->
                    FeedScreen(
                        restoreFocusRequester = homeContentFocusRequesters[0],
                        upFocusRequester = upFocusRequester,
                        onVideoClick = { aid ->
                            navController.navigate("detail/$aid")
                        }
                    )
                },
                hotContent = { upFocusRequester ->
                    HotScreen(
                        restoreFocusRequester = homeContentFocusRequesters[1],
                        upFocusRequester = upFocusRequester,
                        onVideoClick = { aid ->
                            navController.navigate("detail/$aid")
                        }
                    )
                },
                followsContent = { upFocusRequester ->
                    FollowsScreen(
                        restoreFocusRequester = homeContentFocusRequesters[2],
                        upFocusRequester = upFocusRequester,
                        onVideoClick = { navController.navigate("detail/$it") }
                    )
                },
                rankingContent = { upFocusRequester ->
                    RankingScreen(
                        restoreFocusRequester = homeContentFocusRequesters[3],
                        upFocusRequester = upFocusRequester,
                        onVideoClick = { navController.navigate("detail/$it") }
                    )
                },
                followUpsContent = { upFocusRequester ->
                    FollowUpsScreen(
                        restoreFocusRequester = homeContentFocusRequesters[4],
                        upFocusRequester = upFocusRequester,
                        onUpClick = { mid ->
                            navController.navigate("upspace/$mid")
                        }
                    )
                },
                toViewContent = { upFocusRequester ->
                    ToViewScreen(
                        restoreFocusRequester = homeContentFocusRequesters[5],
                        upFocusRequester = upFocusRequester,
                        onVideoClick = { navController.navigate("detail/$it") }
                    )
                },
                historyContent = { upFocusRequester ->
                    HistoryScreen(
                        restoreFocusRequester = homeContentFocusRequesters[6],
                        upFocusRequester = upFocusRequester,
                        onVideoClick = { navController.navigate("detail/$it") }
                    )
                },
                settingsContent = { settingsTabFocusRequester ->
                    SettingsScreen(
                        topFocusRequester = settingsTabFocusRequester,
                        onLogout = {
                            navController.navigate("login") {
                                popUpTo(0) { inclusive = true }
                            }
                        }
                    )
                },
                onExitConfirmed = {
                    context.findActivity()?.finish()
                }
            )
        }

        composable(
            "detail/{aid}",
            arguments = listOf(navArgument("aid") { type = NavType.LongType })
        ) { backStackEntry ->
            val aid = backStackEntry.arguments?.getLong("aid") ?: 0L
            VideoDetailScreen(
                aid = aid,
                onPlay = { playAid, cid ->
                    navController.navigate("player/$playAid/$cid")
                },
                onVideoClick = { videoAid ->
                    navController.navigate("detail/$videoAid")
                },
                onBack = { navController.popBackStack() }
            )
        }

        composable(
            "upspace/{mid}",
            arguments = listOf(navArgument("mid") { type = NavType.LongType })
        ) { backStackEntry ->
            val mid = backStackEntry.arguments?.getLong("mid") ?: 0L
            UpSpaceScreen(
                mid = mid,
                onVideoClick = { aid ->
                    navController.navigate("detail/$aid")
                }
            )
        }

        composable(
            "player/{aid}/{cid}",
            arguments = listOf(
                navArgument("aid") { type = NavType.LongType },
                navArgument("cid") { type = NavType.LongType }
            )
        ) { backStackEntry ->
            val aid = backStackEntry.arguments?.getLong("aid") ?: 0L
            val cid = backStackEntry.arguments?.getLong("cid") ?: 0L
            PlayerScreen(
                aid = aid,
                cid = cid,
                onBack = { navController.popBackStack() }
            )
        }
    }
}

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is ContextWrapper -> baseContext.findActivity()
    else -> null
}
