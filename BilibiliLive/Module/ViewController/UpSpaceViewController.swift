//
//  UpSpaceViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/20.
//

import Foundation
import Kingfisher
import SnapKit
import UIKit

class UpSpaceViewController: StandardVideoCollectionViewController<ApiRequest.UpSpaceListData> {
    var mid: Int!

    private var lastAid: Int?
    private var info: WebRequest.UpSpaceInfo?
    private var relation: WebRequest.UpSpaceRelation?
    private let blockedMessageLabel = UILabel()

    override func setupCollectionView() {
        super.setupCollectionView()
        setupBlockedMessageLabel()
        collectionVC.showHeader = true
        collectionVC.customHeaderConfig = FeedHeaderConfig(
            viewType: UpSpaceTitleSupplementaryView.self,
            estimatedHeight: 80
        ) { [weak self] headerView, indexPath in
            headerView.nameLabel.text = self?.info?.name ?? "-"
            headerView.despLabel.text = self?.info?.sign ?? "-"
            if let face = self?.info?.face {
                headerView.imageView.kf.setImage(with: face, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])
            }
            headerView.mid = self?.mid
            headerView.followButton.isOn = self?.info?.is_followed ?? false
            headerView.blockButton.isOn = self?.relation?.is_blocked ?? false
            headerView.followButton.isHidden = self?.relation?.is_blocked ?? false
            headerView.onBlockTapped = { [weak self, weak headerView] isBlocked in
                headerView?.followButton.isHidden = isBlocked
                self?.reloadData()
            }
        }
        collectionVC.pageSize = 20
    }

    private func setupBlockedMessageLabel() {
        view.addSubview(blockedMessageLabel)
        blockedMessageLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(40)
            make.trailing.lessThanOrEqualToSuperview().offset(-40)
        }
        blockedMessageLabel.text = "无法查看空间内容，请将该用户移除黑名单"
        blockedMessageLabel.font = UIFont.systemFont(ofSize: 28, weight: .medium)
        blockedMessageLabel.textColor = UIColor(named: "titleColor") ?? .white
        blockedMessageLabel.textAlignment = .center
        blockedMessageLabel.numberOfLines = 0
        blockedMessageLabel.isHidden = true
    }

    private func updateBlockedState() {
        let isBlocked = relation?.is_blocked ?? false
        blockedMessageLabel.isHidden = !isBlocked
    }

    override func request(page: Int) async throws -> [ApiRequest.UpSpaceListData] {
        if page == 1 { lastAid = nil }

        async let infoTask = WebRequest.requestUpSpaceInfo(mid: mid)
        async let relationTask = WebRequest.requestUpSpaceRelation(mid: mid)

        info = try await infoTask
        relation = try await relationTask

        // Update UI on main thread
        await MainActor.run {
            updateBlockedState()
        }

        // If user is blocked, return empty array
        if relation?.is_blocked == true {
            return []
        }

        let res = try await ApiRequest.requestUpSpaceVideo(mid: mid, lastAid: lastAid)
        lastAid = res.last?.aid
        return res
    }
}
