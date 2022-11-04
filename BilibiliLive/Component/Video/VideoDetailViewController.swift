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
import MarqueeLabel
import SnapKit
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
    @IBOutlet var ugcCollectionView: UICollectionView!

    @IBOutlet var pageView: UIView!

    @IBOutlet var ugcLabel: UILabel!
    @IBOutlet var ugcView: UIView!
    private var epid = 0
    private var aid = 0
    private var cid = 0
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
    private var replys: Replys?
    private var subTitles: [SubtitleData]?

    static func create(aid: Int, cid: Int?) -> VideoDetailViewController {
        let vc = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(identifier: String(describing: self)) as! VideoDetailViewController
        vc.aid = aid
        vc.cid = cid ?? 0
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
        recommandCollectionView.register(RelatedVideoCell.self, forCellWithReuseIdentifier: String(describing: RelatedVideoCell.self))
        ugcCollectionView.register(RelatedVideoCell.self, forCellWithReuseIdentifier: String(describing: RelatedVideoCell.self))
        recommandCollectionView.collectionViewLayout = makeRelatedVideoCollectionViewLayout()
        ugcCollectionView.collectionViewLayout = makeRelatedVideoCollectionViewLayout()
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
        alertVC.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: { [weak self] action in
            self?.dismiss(animated: true)
        }))
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
        Task {
            do {
                let data = try await WebRequest.requestDetailVideo(aid: self.aid)
                self.data = data
                self.update(with: data)
            } catch let err {
                self.exit(with: err)
            }
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

    private func update(with data: VideoDetail) {
        coinButton.title = data.View.stat.coin.string()
        favButton.title = data.View.stat.favorite.string()
        likeButton.title = data.View.stat.like.string()

        durationLabel.text = data.View.durationString
        titleLabel.text = data.title
        upButton.title = data.ownerName

        avatarImageView.kf.setImage(with: data.avatar, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])

        coverImageView.kf.setImage(with: data.pic)
        backgroundImageView.kf.setImage(with: data.pic)

        var notes = [String]()
        let status = data.View.dynamic ?? ""
        if status.count > 1 {
            notes.append(status)
        }
        notes.append(data.View.desc ?? "")
        noteLabel.text = notes.joined(separator: "\n")

        pages = data.View.pages ?? []
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

        ugcCollectionView.reloadData()
        ugcLabel.text = "合集 \(data.View.ugc_season?.title ?? "")  \(data.View.ugc_season?.sections.first?.title ?? "")"
        ugcView.isHidden = data.View.ugc_season?.sections.count ?? 0 == 0

        recommandCollectionView.reloadData()
    }

    @IBAction func actionShowUpSpace(_ sender: Any) {
        let upSpaceVC = UpSpaceViewController()
        upSpaceVC.mid = data?.View.owner.mid
        present(upSpaceVC, animated: true)
    }

    @IBAction func actionPlay(_ sender: Any) {
        let player = VideoPlayerViewController()
        player.aid = aid
        player.cid = cid
        player.data = data
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
            player.data = data
            present(player, animated: true, completion: nil)
        case replysCollectionView:
            break
        case ugcCollectionView:
            guard let video = data?.View.ugc_season?.sections.first?.episodes[indexPath.item] else { return }
            let detailVC = VideoDetailViewController.create(aid: video.aid, cid: video.cid)
            present(detailVC, animated: true, completion: nil)
        case recommandCollectionView:
            if let video = data?.Related[indexPath.item] {
                let detailVC = VideoDetailViewController.create(aid: video.aid, cid: video.cid)
                present(detailVC, animated: true, completion: nil)
            }
        default:
            break
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
        case ugcCollectionView:
            return data?.View.ugc_season?.sections.first?.episodes.count ?? 0
        case recommandCollectionView:
            return data?.Related.count ?? 0
        default:
            return 0
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
        case ugcCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: RelatedVideoCell.self), for: indexPath) as! RelatedVideoCell
            if let record = data?.View.ugc_season?.sections.first?.episodes[indexPath.row] {
                cell.update(data: record)
            }
            return cell
        case recommandCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: RelatedVideoCell.self), for: indexPath) as! RelatedVideoCell
            if let related = data?.Related[indexPath.row] {
                cell.update(data: related)
            }
            return cell
        default:
            return UICollectionViewCell()
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

    func makeRelatedVideoCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            _, _ in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .estimated(200))
            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(0.18), heightDimension: .estimated(200))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            let section = NSCollectionLayoutSection(group: group)
            section.contentInsets = .init(top: 40, leading: 0, bottom: 0, trailing: 0)
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

class RelatedVideoCell: BLMotionCollectionViewCell {
    let titleLabel = MarqueeLabel()
    let imageView = UIImageView()
    override func setup() {
        super.setup()
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        imageView.snp.makeConstraints { make in
            make.top.left.right.equalToSuperview()
            make.width.equalTo(imageView.snp.height).multipliedBy(14.0 / 9)
        }
        imageView.layer.cornerRadius = 12
        imageView.clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        titleLabel.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalTo(imageView.snp.bottom).offset(6)
        }
        titleLabel.setContentHuggingPriority(.required, for: .vertical)
        titleLabel.font = UIFont.systemFont(ofSize: 28)
        stopScroll()
    }

    func update(data: any DisplayData) {
        titleLabel.text = data.title
        imageView.kf.setImage(with: data.pic, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 360, height: 202)))])
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        if isFocused {
            startScroll()
        } else {
            stopScroll()
        }
    }

    private func startScroll() {
        titleLabel.restartLabel()
        titleLabel.holdScrolling = false
    }

    private func stopScroll() {
        titleLabel.shutdownLabel()
        titleLabel.holdScrolling = true
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        stopScroll()
    }
}
