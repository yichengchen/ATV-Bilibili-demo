//
//  VideoDetailViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/17.
//

import AVKit
import Foundation
import UIKit

import Alamofire
import Kingfisher
import SwiftyJSON
import TVUIKit

class VideoDetailViewController: UIViewController {
    private var loadingView = UIActivityIndicatorView()
    @IBOutlet var backgroundImageView: UIImageView!
    @IBOutlet var effectContainerView: UIVisualEffectView!

    @IBOutlet var titleLabel: UILabel!

    @IBOutlet var upButton: BLCustomTextButton!
    @IBOutlet var noteLabel: UILabel!
    @IBOutlet var coverImageView: UIImageView!
    @IBOutlet var playButton: BLCustomButton!
    @IBOutlet var likeButton: BLCustomButton!
    @IBOutlet var coinButton: BLCustomButton!
    @IBOutlet var dislikeButton: BLCustomButton!

    @IBOutlet var durationLabel: UILabel!
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var favButton: BLCustomButton!
    @IBOutlet var pageCollectionView: UICollectionView!
    @IBOutlet var recommandCollectionView: UICollectionView!
    @IBOutlet var replysCollectionView: UICollectionView!
    @IBOutlet var pageView: UIView!

    private var epid = 0
    private var aid = 0
    private var cid = 0 { didSet { if oldValue != cid { fetchDataWithCid() } }}
    private var data: VideoDetail?
    private var didSentCoins = 0 {
        didSet {
            if didSentCoins > 0 {
                coinButton.isOn = true
            }
        }
    }

    private var startTime = 0
    private var pages = [VideoPage]()
    private var relateds = [VideoDetail]()
    private var replys: Replys?

    static func create(aid: Int, cid: Int) -> VideoDetailViewController {
        let vc = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(identifier: String(describing: self)) as! VideoDetailViewController
        vc.aid = aid
        vc.cid = cid
        return vc
    }

    static func create(epid: Int) -> VideoDetailViewController {
        let vc = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(identifier: String(describing: self)) as! VideoDetailViewController
        vc.epid = epid
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLoading()
        fetchData()
        pageCollectionView.register(BLTextOnlyCollectionViewCell.self, forCellWithReuseIdentifier: String(describing: BLTextOnlyCollectionViewCell.self))
        pageCollectionView.collectionViewLayout = makePageCollectionViewLayout()
    }

    override var preferredFocusedView: UIView? {
        return playButton
    }

    private func setupLoading() {
        effectContainerView.isHidden = true
        view.addSubview(loadingView)
        loadingView.color = .white
        loadingView.style = .large
        loadingView.startAnimating()
        loadingView.makeConstraintsBindToCenterOfSuperview()
    }

    func present(from vc: UIViewController) {
        if !Settings.direatlyEnterVideo {
            vc.present(self, animated: true)
        } else {
            vc.present(self, animated: false) { [self] in
                let player = VideoPlayerViewController()
                player.aid = aid
                player.cid = cid
                present(player, animated: true)
            }
        }
    }

    private func exit(with error: Error) {
        print(error)
        let alertVC = UIAlertController(title: "获取失败", message: nil, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: nil))
        present(alertVC, animated: true, completion: nil)
    }

    private func fetchData() {
        guard aid != 0 else {
            WebRequest.requestBangumiInfo(epid: epid) { [weak self] epi in
                guard let self else { return }
                self.aid = epi.aid
                self.cid = epi.cid
                self.fetchData()
            }
            return
        }
        WebRequest.requestVideoInfo(aid: aid) { [weak self] response in
            guard let self else { return }
            switch response {
            case let .success(data):
                self.data = data
                self.update(with: data)
            case let .failure(err):
                self.exit(with: err)
            }
        }

        WebRequest.requestRelatedVideo(aid: aid) {
            [weak self] recommands in
            self?.relateds = recommands
            self?.recommandCollectionView.reloadData()
        }

        WebRequest.requestReplys(aid: aid) { [weak self] replys in
            self?.replys = replys
            self?.replysCollectionView.reloadData()
        }

        WebRequest.requestLikeStatus(aid: aid) { [weak self] isLiked in
            self?.likeButton.isOn = isLiked
        }

        WebRequest.requestCoinStatus(aid: aid) { [weak self] coins in
            self?.didSentCoins = coins
        }

        WebRequest.requestFavoriteStatus(aid: aid) { [weak self] isFavorited in
            self?.favButton.isOn = isFavorited
        }
    }

    private func fetchDataWithCid() {
        guard cid > 0 else { return }
        WebRequest.requestPlayerInfo(aid: aid, cid: cid) { [weak self] info in
            self?.startTime = info.playTimeInSecond
        }
    }

    private func update(with data: VideoDetail) {
        coinButton.title = data.stat.coin.string()
        favButton.title = data.stat.favorite.string()
        likeButton.title = data.stat.like.string()

        durationLabel.text = data.durationString
        titleLabel.text = data.title
        upButton.title = data.owner.name

        avatarImageView.kf.setImage(with: data.owner.face, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])

        coverImageView.kf.setImage(with: data.pic)
        backgroundImageView.kf.setImage(with: data.pic)

        var notes = [String]()
        let status = data.dynamic ?? ""
        if status.count > 1 {
            notes.append(status)
        }
        notes.append(data.desc)
        noteLabel.text = notes.joined(separator: "\n")

        pages = data.pages ?? []
        if pages.count > 1 {
            pageCollectionView.reloadData()
            pageView.isHidden = false
            let index = pages.firstIndex { $0.cid == cid } ?? 0
            pageCollectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .left, animated: false)
            if cid == 0 {
                cid = pages.first?.cid ?? 0
            }
        }
        loadingView.stopAnimating()
        loadingView.removeFromSuperview()
        effectContainerView.isHidden = false
        backgroundImageView.alpha = 0
        UIView.animate(withDuration: 0.25) {
            self.backgroundImageView.alpha = 1
        }
    }

    @IBAction func actionShowUpSpace(_ sender: Any) {
        let upSpaceVC = UpSpaceViewController()
        upSpaceVC.mid = data?.owner.mid
        present(upSpaceVC, animated: true)
    }

    @IBAction func actionPlay(_ sender: Any) {
        let player = VideoPlayerViewController()
        player.aid = aid
        player.cid = cid
        if startTime > 0 && data!.duration - startTime > 5 {
            player.playerStartPos = CMTime(seconds: Double(startTime), preferredTimescale: 1)
        }
        present(player, animated: true, completion: nil)
    }

    @IBAction func actionLike(_ sender: Any) {
        Task {
            if likeButton.isOn {
                likeButton.title? -= 1
            } else {
                likeButton.title? += 1
            }
            likeButton.isOn.toggle()
            let success = await WebRequest.requestLike(aid: aid, like: likeButton.isOn)
            if !success {
                likeButton.isOn.toggle()
            }
        }
    }

    @IBAction func actionCoin(_ sender: Any) {
        guard didSentCoins < 2 else { return }
        let alert = UIAlertController(title: "投币个数", message: nil, preferredStyle: .actionSheet)
        WebRequest.requestTodayCoins { todayCoins in
            alert.message = "今日已投(\(todayCoins / 10)/5)个币"
        }
        let aid = aid
        alert.addAction(UIAlertAction(title: "1", style: .default) { [weak self] _ in
            guard let self else { return }
            self.coinButton.title? += 1
            if !self.likeButton.isOn {
                self.likeButton.title? += 1
                self.likeButton.isOn = true
            }
            self.didSentCoins += 1
            WebRequest.requestCoin(aid: aid, num: 1)
        })
        if didSentCoins == 0 {
            alert.addAction(UIAlertAction(title: "2", style: .default) { [weak self] _ in
                guard let self else { return }
                self.coinButton.title? += 2
                if !self.likeButton.isOn {
                    self.likeButton.title? += 1
                    self.likeButton.isOn = true
                }
                self.likeButton.isOn = true
                self.didSentCoins += 2
                WebRequest.requestCoin(aid: aid, num: 2)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    @IBAction func actionFavorite(_ sender: Any) {
        Task {
            guard let favList = try? await WebRequest.requestFavVideosList() else {
                return
            }
            let alert = UIAlertController(title: "收藏", message: nil, preferredStyle: .actionSheet)
            let aid = aid
            for fav in favList {
                alert.addAction(UIAlertAction(title: fav.title, style: .default) { [weak self] _ in
                    self?.favButton.title? += 1
                    self?.favButton.isOn = true
                    WebRequest.requestFavorite(aid: aid, mlid: fav.id)
                })
            }
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            present(alert, animated: true)
        }
    }

    @IBAction func actionDislike(_ sender: Any) {
        dislikeButton.isOn.toggle()
        ApiRequest.requestDislike(aid: aid, dislike: dislikeButton.isOn)
    }
}

extension VideoDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch collectionView {
        case pageCollectionView:
            let page = pages[indexPath.item]
            let player = VideoPlayerViewController()
            player.aid = aid
            player.cid = page.cid
            present(player, animated: true, completion: nil)
        case replysCollectionView:
            break
        default:
            let video = relateds[indexPath.item]
            let detailVC = VideoDetailViewController.create(aid: video.aid, cid: video.cid)
            present(detailVC, animated: true, completion: nil)
        }
    }
}

extension VideoDetailViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch collectionView {
        case pageCollectionView:
            return pages.count
        case replysCollectionView:
            return replys?.replies.count ?? 0
        default:
            return relateds.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch collectionView {
        case pageCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "BLTextOnlyCollectionViewCell", for: indexPath) as! BLTextOnlyCollectionViewCell
            let page = pages[indexPath.item]
            cell.titleLabel.text = page.part
            return cell
        case replysCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: ReplyCell.self), for: indexPath) as! ReplyCell
            if let reply = replys?.replies[indexPath.item] {
                cell.config(replay: reply)
            }
            return cell
        default:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
            let label = cell.viewWithTag(2) as! UILabel
            let related = relateds[indexPath.row]
            let imageView = cell.viewWithTag(1) as! UIImageView
            label.text = related.title
            imageView.kf.setImage(with: related.pic)
            return cell
        }
    }
}

class BLCardView: TVCardView {
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        subviews.first?.subviews.first?.subviews.last?.subviews.first?.subviews.first?.layer.cornerRadius = 12
    }

    override func layoutSubviews() {
        super.layoutSubviews()
    }
}

extension VideoDetailViewController {
    func makePageCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1.0))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.14), heightDimension: .fractionalHeight(1))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous
            section.interGroupSpacing = 40
            return section
        }
    }
}

extension Int {
    func string() -> String {
        return String(self)
    }
}

class ReplyCell: UICollectionViewCell {
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var userNameLabel: UILabel!
    @IBOutlet var contenLabel: UILabel!

    func config(replay: Replys.Reply) {
        avatarImageView.kf.setImage(with: URL(string: replay.member.avatar), options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])
        userNameLabel.text = replay.member.uname
        contenLabel.text = replay.content.message
    }
}
