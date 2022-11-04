//
//  RankingViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/29.
//

import Foundation
import UIKit

struct CategoryInfo {
    let title: String
    let rid: Int

    static let all = [CategoryInfo(title: "全站", rid: 0),
                      CategoryInfo(title: "动画", rid: 1),
                      CategoryInfo(title: "番剧", rid: 13),
                      CategoryInfo(title: "国创", rid: 167),
                      CategoryInfo(title: "音乐", rid: 3),
                      CategoryInfo(title: "舞蹈", rid: 129),
                      CategoryInfo(title: "游戏", rid: 4),
                      CategoryInfo(title: "知识", rid: 39),
                      CategoryInfo(title: "科技", rid: 188),
                      CategoryInfo(title: "运动", rid: 234),
                      CategoryInfo(title: "汽车", rid: 233),
                      CategoryInfo(title: "生活", rid: 160),
                      CategoryInfo(title: "美食", rid: 211),
                      CategoryInfo(title: "动物圈", rid: 217),
                      CategoryInfo(title: "鬼畜", rid: 119),
                      CategoryInfo(title: "时尚", rid: 155),
                      CategoryInfo(title: "娱乐", rid: 5),
                      CategoryInfo(title: "影视", rid: 181),
                      CategoryInfo(title: "纪录片", rid: 177),
                      CategoryInfo(title: "电影", rid: 23),
                      CategoryInfo(title: "电视剧", rid: 11)]
}

class RankingViewController: UIViewController, BLTabBarContentVCProtocol {
    struct CategoryDisplayModel {
        let title: String
        let contentVC: UIViewController
    }

    var typeCollectionView: UICollectionView!
    var categories = [CategoryDisplayModel]()
    let contentView = UIView()
    weak var currentViewController: UIViewController?
    override func viewDidLoad() {
        super.viewDidLoad()
        categories = CategoryInfo.all
            .map {
                CategoryDisplayModel(title: $0.title, contentVC: RankingContentViewController(rid: $0.rid))
            }
        typeCollectionView = UICollectionView(frame: .zero, collectionViewLayout: BLSettingLineCollectionViewCell.makeLayout())
        typeCollectionView.register(BLSettingLineCollectionViewCell.self, forCellWithReuseIdentifier: "cell")
        view.addSubview(typeCollectionView)
        typeCollectionView.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.width.equalTo(500)
        }
        typeCollectionView.dataSource = self
        typeCollectionView.delegate = self

        view.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.bottom.right.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.left.equalTo(typeCollectionView.snp.right)
        }
        typeCollectionView.selectItem(at: IndexPath(item: 0, section: 0), animated: false, scrollPosition: .top)
        collectionView(typeCollectionView, didSelectItemAt: IndexPath(item: 0, section: 0))
    }

    func reloadData() {
        (currentViewController as? BLTabBarContentVCProtocol)?.reloadData()
    }

    func setViewController(vc: UIViewController) {
        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()
        currentViewController = vc
        addChild(vc)
        contentView.addSubview(vc.view)
        vc.view.makeConstraintsToBindToSuperview()
        vc.didMove(toParent: self)
    }
}

extension RankingViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return categories.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! BLSettingLineCollectionViewCell
        cell.titleLabel.text = categories[indexPath.item].title
        return cell
    }
}

extension RankingViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        setViewController(vc: categories[indexPath.item].contentVC)
    }
}

class RankingContentViewController: UIViewController, BLTabBarContentVCProtocol {
    let collectionVC = FeedCollectionViewController()
    let rid: Int

    init(rid: Int) {
        self.rid = rid
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionVC.styleOverride = .sideBar
        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] in
            self?.goDetail(with: $0 as! VideoDetail.Info)
        }
        reloadData()
    }

    func reloadData() {
        Task {
            let res = try? await WebRequest.requestRank(for: rid)
            collectionVC.displayDatas = res ?? []
        }
    }

    func goDetail(with record: VideoDetail.Info) {
        let detailVC = VideoDetailViewController.create(aid: record.aid, cid: record.cid)
        detailVC.present(from: self)
    }
}

extension WebRequest.EndPoint {
    static let rank = "https://api.bilibili.com/x/web-interface/ranking/v2"
}

extension WebRequest {
    static func requestRank(for category: Int) async throws -> [VideoDetail.Info] {
        struct RankResp: Codable {
            let list: [VideoDetail.Info]
        }
        let resp: RankResp = try await request(url: EndPoint.rank, parameters: ["rid": category, "type": "all"])
        return resp.list
    }
}
