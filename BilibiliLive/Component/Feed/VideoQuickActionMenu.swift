//
//  VideoQuickActionMenu.swift
//  BilibiliLive
//
//  视频快捷操作菜单：加入/移出稍后再看、收藏视频、不感兴趣。
//  经典 Feed（FeedCollectionViewController）与沉浸式 Feed（FeedFlowBrowserViewController）共用。
//

import UIKit

@MainActor
final class VideoQuickActionMenu {
    static let shared = VideoQuickActionMenu()

    /// 本次运行中通过快捷菜单成功加入稍后再看的视频
    private var addedToViewAids = Set<Int>()
    private var inFlightAids = Set<Int>()

    private init() {}

    func present(aid: Int, title: String?, from presenter: UIViewController) {
        guard aid > 0 else { return }
        let alert = UIAlertController(title: title, message: nil, preferredStyle: .actionSheet)

        if addedToViewAids.contains(aid) {
            alert.addAction(UIAlertAction(title: "移出稍后再看", style: .destructive) { [weak self, weak presenter] _ in
                self?.removeFromToView(aid: aid, presenter: presenter)
            })
        } else {
            alert.addAction(UIAlertAction(title: "加入稍后再看", style: .default) { [weak self, weak presenter] _ in
                self?.addToView(aid: aid, presenter: presenter)
            })
        }

        alert.addAction(UIAlertAction(title: "收藏视频", style: .default) { [weak self, weak presenter] _ in
            self?.favorite(aid: aid, presenter: presenter)
        })

        alert.addAction(UIAlertAction(title: "不感兴趣", style: .default) { _ in
            ApiRequest.requestDislike(aid: aid, dislike: true)
        })

        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        presenter.present(alert, animated: true)
    }

    // MARK: - 稍后再看

    private func addToView(aid: Int, presenter: UIViewController?) {
        guard !inFlightAids.contains(aid) else { return }
        inFlightAids.insert(aid)
        Task { [weak self] in
            do {
                try await WebRequest.requestAddToView(aid: aid)
                self?.inFlightAids.remove(aid)
                self?.addedToViewAids.insert(aid)
            } catch let err {
                self?.inFlightAids.remove(aid)
                self?.showError(title: "加入稍后再看失败", error: err, presenter: presenter)
            }
        }
    }

    private func removeFromToView(aid: Int, presenter: UIViewController?) {
        guard !inFlightAids.contains(aid) else { return }
        inFlightAids.insert(aid)
        Task { [weak self] in
            do {
                try await WebRequest.requestRemoveToView(aid: aid)
                self?.inFlightAids.remove(aid)
                self?.addedToViewAids.remove(aid)
            } catch let err {
                self?.inFlightAids.remove(aid)
                self?.showError(title: "移出稍后再看失败", error: err, presenter: presenter)
            }
        }
    }

    // MARK: - 收藏

    private func favorite(aid: Int, presenter: UIViewController?) {
        Task { [weak self, weak presenter] in
            let favList: [FavListData]
            do {
                favList = try await WebRequest.requestFavVideosList()
            } catch let err {
                self?.showError(title: "获取收藏夹失败", error: err, presenter: presenter)
                return
            }
            guard let presenter, presenter.viewIfLoaded?.window != nil else { return }
            let alert = UIAlertController(title: "收藏", message: nil, preferredStyle: .actionSheet)
            for fav in favList {
                alert.addAction(UIAlertAction(title: fav.title, style: .default) { _ in
                    WebRequest.requestFavorite(aid: aid, mid: fav.id)
                })
            }
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            presenter.present(alert, animated: true)
        }
    }

    // MARK: - Helper

    private func showError(title: String, error: Error, presenter: UIViewController?) {
        guard let presenter, presenter.viewIfLoaded?.window != nil else { return }
        var message = "\(error)"
        if let requestError = error as? RequestError,
           case let .statusFail(code, msg) = requestError
        {
            message = "\(msg) (\(code))"
        }
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel))
        presenter.present(alert, animated: true)
    }
}

extension WebRequest {
    /// POST /x/v2/history/toview/add，参数 aid + csrf（csrf 由 requestData 自动附带）
    static func requestAddToView(aid: Int) async throws {
        _ = try await requestJSON(method: .post,
                                  url: "https://api.bilibili.com/x/v2/history/toview/add",
                                  parameters: ["aid": aid])
    }

    /// POST /x/v2/history/toview/del，参数 aid + csrf
    static func requestRemoveToView(aid: Int) async throws {
        _ = try await requestJSON(method: .post,
                                  url: "https://api.bilibili.com/x/v2/history/toview/del",
                                  parameters: ["aid": aid])
    }
}
