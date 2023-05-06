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

class VideoDetailViewController: UIViewController {
    private var loadingView = UIActivityIndicatorView()
    var epid = 0
    var seasonId = 0
    var aid = 0
    var cid = 0
    private var data: VideoDetail?
    private var didSentCoins = 0 {
        didSet {
            if didSentCoins > 0 {
                coinButton.isOn = true
            }
        }
    }

    private var isBangumi = false
    private var startTime = 0
    private var pages = [VideoPage]()
    private var replys: Replys?
    private var subTitles: [SubtitleData]?

    private var allUgcEpisodes = [VideoDetail.Info.UgcSeason.UgcVideoInfo]()

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        Task { await fetchData() }

        pageCollectionView.register(BLTextOnlyCollectionViewCell.self, forCellWithReuseIdentifier: String(describing: BLTextOnlyCollectionViewCell.self))
        pageCollectionView.collectionViewLayout = makePageCollectionViewLayout()
        recommandCollectionView.register(RelatedVideoCell.self, forCellWithReuseIdentifier: String(describing: RelatedVideoCell.self))
        ugcCollectionView.register(RelatedVideoCell.self, forCellWithReuseIdentifier: String(describing: RelatedVideoCell.self))
        recommandCollectionView.collectionViewLayout = makeRelatedVideoCollectionViewLayout()
        ugcCollectionView.collectionViewLayout = makeRelatedVideoCollectionViewLayout()
        noteView.onPrimaryAction = {
            [weak self] note in
            let detail = ContentDetailViewController.createDesp(content: note.label.text ?? "")
            self?.present(detail, animated: true)
        }

        var focusGuide = UIFocusGuide()
        view.addLayoutGuide(focusGuide)
        NSLayoutConstraint.activate([
            focusGuide.topAnchor.constraint(equalTo: upButton.topAnchor),
            focusGuide.leftAnchor.constraint(equalTo: followButton.rightAnchor),
            focusGuide.rightAnchor.constraint(equalTo: coverImageView.leftAnchor),
            focusGuide.bottomAnchor.constraint(equalTo: upButton.bottomAnchor),
        ])
        focusGuide.preferredFocusEnvironments = [followButton]

        focusGuide = UIFocusGuide()
        view.addLayoutGuide(focusGuide)
        NSLayoutConstraint.activate([
            focusGuide.topAnchor.constraint(equalTo: actionButtonSpaceView.topAnchor),
            focusGuide.leftAnchor.constraint(equalTo: actionButtonSpaceView.leftAnchor),
            focusGuide.rightAnchor.constraint(equalTo: actionButtonSpaceView.rightAnchor),
            focusGuide.bottomAnchor.constraint(equalTo: actionButtonSpaceView.bottomAnchor),
        ])
        focusGuide.preferredFocusEnvironments = [dislikeButton]
    }

    override var preferredFocusedView: UIView? {
        return playButton
    }

    private lazy var backgroundImageView = UIImageView()
    private lazy var titleLabel = UILabel()
    private lazy var coverImageView = UIImageView()
    private lazy var avatarImageView = UIImageView()
    private lazy var upButton = BLCustomTextButton()
    private lazy var followButton = BLCustomButton()
    private lazy var followersLabel = UILabel()
    private lazy var durationLabel = IconAndTextView()
    private lazy var baseInfoStackView = UIStackView()
    private lazy var noteView = NoteDetailView()
    private lazy var playCountLabel = IconAndTextView()
    private lazy var danmakuLabel = IconAndTextView()
    private lazy var viewReplys = UIView()
    private lazy var uploadTimeLabel = UILabel()
    private lazy var bvidLabel = UILabel()
    private lazy var videoDetailInfoStackView = UIStackView()
    private lazy var 介绍页 = UIView()
    private lazy var 交互选项 = UIStackView()
    private lazy var pageCollectionViewLayout = UICollectionViewFlowLayout()
    private lazy var pageCollectionView = UICollectionView(frame: CGRect(), collectionViewLayout: pageCollectionViewLayout)
    private lazy var label1 = UILabel()
    private lazy var pageView = UIView()
    private lazy var ugcCollectionViewLayout = UICollectionViewFlowLayout()
    private lazy var ugcCollectionView = UICollectionView(frame: CGRect(), collectionViewLayout: ugcCollectionViewLayout)
    private lazy var ugcLabel = UILabel()
    private lazy var ugcView = UIView()
    private lazy var recommandCollectionViewLayout = UICollectionViewFlowLayout()
    private lazy var recommandCollectionView = UICollectionView(frame: CGRect(), collectionViewLayout: recommandCollectionViewLayout)
    private lazy var label2 = UILabel()
    private lazy var viewRelatedVideo = UIView()
    private lazy var replysCollectionViewLayout = UICollectionViewFlowLayout()
    private lazy var replysCollectionView = UICollectionView(frame: CGRect(), collectionViewLayout: replysCollectionViewLayout)
    private lazy var label3 = UILabel()
    private lazy var viewComments = UIView()
    private lazy var mainStack = UIStackView()
    private lazy var scrollView = UIScrollView()
    private lazy var effectContainerView = UIVisualEffectView()
    let playButton = BLCustomButton()
    let likeButton = BLCustomButton()
    let coinButton = BLCustomButton()
    let favButton = BLCustomButton()
    let dislikeButton = BLCustomButton()
    let actionButtonSpaceView = UIView()

    func setupUI() {
        backgroundImageView.contentMode = .scaleAspectFit
        view.addSubview(backgroundImageView)
        backgroundImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        effectContainerView.translatesAutoresizingMaskIntoConstraints = false
        effectContainerView.effect = UIBlurEffect(style: .regular)
        view.addSubview(effectContainerView)
        effectContainerView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        effectContainerView.contentView.addSubview(scrollView)
        scrollView.snp.makeConstraints { make in
            make.left.right.top.bottom.equalToSuperview()
        }

        mainStack.axis = .vertical
        mainStack.alignment = .fill
        mainStack.distribution = .fill
        scrollView.addSubview(mainStack)
        mainStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(self.view.snp.width)
        }

        mainStack.addArrangedSubview(介绍页)

        titleLabel.contentMode = .left
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        titleLabel.numberOfLines = 2
        介绍页.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.right.equalToSuperview()
            make.left.equalTo(介绍页.safeAreaLayoutGuide.snp.left)
        }

        介绍页.addSubview(coverImageView)
        coverImageView.snp.makeConstraints { make in
            make.bottom.equalToSuperview()
            make.right.equalTo(介绍页.safeAreaLayoutGuide.snp.right)
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.height.equalTo(350)
            make.width.equalTo(622)
        }

        baseInfoStackView.alignment = .center
        baseInfoStackView.distribution = .equalSpacing
        baseInfoStackView.spacing = 30
        baseInfoStackView.axis = .horizontal
        介绍页.addSubview(baseInfoStackView)
        baseInfoStackView.snp.makeConstraints { make in
            make.left.equalTo(介绍页.safeAreaLayoutGuide.snp.left)
            make.height.equalTo(60)
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
        }

        upButton.setContentCompressionResistancePriority(.required, for: .vertical)
        upButton.tintColor = UIColor(named: "bgColor")

        avatarImageView.clipsToBounds = true
        avatarImageView.contentMode = .scaleAspectFit
        avatarImageView.snp.makeConstraints { make in
            make.width.equalTo(avatarImageView.snp.height)
        }

        baseInfoStackView.addArrangedSubview(avatarImageView)
        baseInfoStackView.addArrangedSubview(upButton)

        followButton.backgroundColor = UIColor(white: 0, alpha: 0)
        followButton.tintColor = UIColor(named: "bgColor")
        followButton.translatesAutoresizingMaskIntoConstraints = false
        followButton.image = UIImage(named: "heart")
        followButton.onImage = UIImage(named: "heart.fill")

        baseInfoStackView.addArrangedSubview(followButton)
        followButton.snp.makeConstraints {
            $0.width.equalTo(followButton.snp.height)
            $0.height.equalToSuperview()
        }

        followersLabel.contentMode = .left
        followersLabel.font = UIFont.systemFont(ofSize: 28)
        baseInfoStackView.addArrangedSubview(followersLabel)

        durationLabel.titleLabel.font = UIFont.systemFont(ofSize: 28)
        durationLabel.imageView.image = UIImage(systemName: "clock.fill")
        baseInfoStackView.addArrangedSubview(durationLabel)

        // detail info
        videoDetailInfoStackView.spacing = 30
        介绍页.addSubview(videoDetailInfoStackView)
        videoDetailInfoStackView.snp.makeConstraints { make in
            make.top.equalTo(baseInfoStackView.snp.bottom).offset(24)
            make.left.equalTo(介绍页.safeAreaLayoutGuide.snp.left)
        }

        playCountLabel.titleLabel.font = UIFont.systemFont(ofSize: 28)
        playCountLabel.imageView.image = UIImage(systemName: "play.square")
        videoDetailInfoStackView.addArrangedSubview(playCountLabel)

        danmakuLabel.imageView.image = UIImage(systemName: "list.bullet.rectangle")
        danmakuLabel.titleLabel.font = UIFont.systemFont(ofSize: 28)
        videoDetailInfoStackView.addArrangedSubview(danmakuLabel)

        bvidLabel.contentMode = .left
        bvidLabel.font = UIFont.systemFont(ofSize: 28)
        bvidLabel.setContentHuggingPriority(UILayoutPriority(rawValue: 251), for: .horizontal)
        videoDetailInfoStackView.addArrangedSubview(bvidLabel)

        uploadTimeLabel.contentMode = .left
        uploadTimeLabel.font = UIFont.systemFont(ofSize: 28)
        videoDetailInfoStackView.addArrangedSubview(uploadTimeLabel)

        // note
        noteView.backgroundColor = UIColor(white: 0, alpha: 0)
        介绍页.addSubview(noteView)
        noteView.snp.makeConstraints { make in
            make.top.equalTo(videoDetailInfoStackView.snp.bottom).offset(10)
            make.bottom.equalTo(-40)
            make.left.equalTo(介绍页.safeAreaLayoutGuide.snp.left)
        }

        交互选项.spacing = 20
        交互选项.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(交互选项)

        var space = UIView()
        space.backgroundColor = .clear
        交互选项.addArrangedSubview(space)
        space.snp.makeConstraints { make in
            make.width.equalTo(60)
        }

        playButton.image = UIImage(systemName: "play")
        playButton.highLightImage = UIImage(systemName: "play.fill")
        playButton.backgroundColor = UIColor(white: 0, alpha: 0)
        playButton.tintColor = UIColor(named: "bgColor")
        playButton.title = "播放"
        playButton.titleColor = UIColor.label
        playButton.addTarget(self, action: #selector(actionPlay(_:)), for: .primaryActionTriggered)
        交互选项.addArrangedSubview(playButton)
        playButton.snp.makeConstraints { make in
            make.width.equalTo(160)
        }

        likeButton.backgroundColor = UIColor(white: 0, alpha: 0)
        likeButton.tintColor = UIColor(named: "bgColor")
        likeButton.translatesAutoresizingMaskIntoConstraints = false
        likeButton.setValue("点赞", forKeyPath: "title")
        likeButton.setValue(UIColor(named: "titleColor"), forKeyPath: "titleColor")
        likeButton.setValue(UIImage(named: "hand.thumbsup"), forKeyPath: "image")
        交互选项.addArrangedSubview(likeButton)
        likeButton.snp.makeConstraints { make in
            make.width.equalTo(playButton)
        }

        coinButton.backgroundColor = UIColor(white: 0, alpha: 0)
        coinButton.tintColor = UIColor(named: "bgColor")
        coinButton.translatesAutoresizingMaskIntoConstraints = false
        coinButton.setValue("投币", forKeyPath: "title")
        coinButton.setValue(UIColor(named: "titleColor"), forKeyPath: "titleColor")
        coinButton.setValue(UIImage(named: "bitcoinsign.circle"), forKeyPath: "image")
        交互选项.addArrangedSubview(coinButton)
        coinButton.snp.makeConstraints { make in
            make.width.equalTo(playButton)
        }

        favButton.backgroundColor = UIColor(white: 0, alpha: 0)
        favButton.tintColor = UIColor(named: "bgColor")
        favButton.translatesAutoresizingMaskIntoConstraints = false

        favButton.setValue("收藏", forKeyPath: "title")
        favButton.setValue(UIColor(named: "titleColor"), forKeyPath: "titleColor")
        favButton.setValue(UIImage(named: "star"), forKeyPath: "image")
        交互选项.addArrangedSubview(favButton)
        favButton.snp.makeConstraints { make in
            make.width.equalTo(playButton)
        }

        dislikeButton.backgroundColor = UIColor(white: 0, alpha: 0)
        dislikeButton.tintColor = UIColor(named: "bgColor")
        dislikeButton.translatesAutoresizingMaskIntoConstraints = false
        dislikeButton.setValue("不喜欢", forKeyPath: "title")
        dislikeButton.setValue(UIColor(named: "titleColor"), forKeyPath: "titleColor")
        dislikeButton.setValue(UIImage(named: "hand.thumbsdown"), forKeyPath: "image")
        交互选项.addArrangedSubview(dislikeButton)
        dislikeButton.snp.makeConstraints { make in
            make.width.equalTo(playButton)
        }

        actionButtonSpaceView.backgroundColor = .clear
        交互选项.addArrangedSubview(actionButtonSpaceView)

        space = UIView()
        mainStack.addArrangedSubview(space)
        space.snp.makeConstraints { make in
            make.height.equalTo(20)
        }

        pageView.backgroundColor = UIColor(white: 0, alpha: 0)
        pageView.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(pageView)

        label1.contentMode = .left
        label1.font = UIFont.preferredFont(forTextStyle: .title3)
        label1.setContentHuggingPriority(UILayoutPriority(rawValue: 251), for: .horizontal)
        pageView.addSubview(label1)
        label1.snp.makeConstraints { make in
            make.top.equalTo(40)
        }

        pageCollectionView.delegate = self
        pageCollectionView.dataSource = self
        pageCollectionViewLayout.footerReferenceSize = CGSize(width: 0, height: 0)
        pageCollectionViewLayout.headerReferenceSize = CGSize(width: 0, height: 0)
        pageCollectionViewLayout.itemSize = CGSize(width: 350, height: 170)
        pageView.addSubview(pageCollectionView)
        pageCollectionView.snp.makeConstraints { make in
            make.top.equalTo(label1.snp.bottom).offset(30)
            make.height.equalTo(90)
            make.bottom.equalTo(-20)
            make.left.right.equalToSuperview()
        }

        ugcView.backgroundColor = UIColor(white: 0, alpha: 0)
        ugcView.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(ugcView)

        ugcLabel.contentMode = .left
        ugcLabel.font = UIFont.preferredFont(forTextStyle: .title3)
        ugcLabel.setContentHuggingPriority(UILayoutPriority(rawValue: 251), for: .horizontal)
        ugcView.addSubview(ugcLabel)
        ugcView.snp.makeConstraints { make in
            make.top.equalToSuperview()
        }

        ugcCollectionView.delegate = self
        ugcCollectionView.dataSource = self
        ugcCollectionView.backgroundColor = UIColor(white: 0, alpha: 0)
        ugcCollectionView.clipsToBounds = true
        ugcCollectionView.translatesAutoresizingMaskIntoConstraints = false
        ugcCollectionViewLayout.footerReferenceSize = CGSize(width: 0, height: 0)
        ugcCollectionViewLayout.headerReferenceSize = CGSize(width: 0, height: 0)
        ugcCollectionViewLayout.itemSize = CGSize(width: 361, height: 274)
        ugcView.addSubview(ugcCollectionView)
        ugcCollectionView.snp.makeConstraints { make in
            make.top.equalTo(ugcLabel.snp.bottom)
            make.left.right.bottom.equalToSuperview()
            make.height.equalTo(320)
        }

        viewRelatedVideo.backgroundColor = UIColor(white: 0, alpha: 0)
        viewRelatedVideo.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(viewRelatedVideo)

        label2.contentMode = .left
        label2.font = UIFont.preferredFont(forTextStyle: .title3)
        label2.setContentHuggingPriority(UILayoutPriority(rawValue: 251), for: .horizontal)
        viewRelatedVideo.addSubview(label2)
        label2.snp.makeConstraints { make in
            make.top.equalToSuperview()
        }

        recommandCollectionView.delegate = self
        recommandCollectionView.dataSource = self
        recommandCollectionView.backgroundColor = UIColor(white: 0, alpha: 0)
        recommandCollectionView.clipsToBounds = true
        recommandCollectionView.translatesAutoresizingMaskIntoConstraints = false
        recommandCollectionViewLayout.footerReferenceSize = CGSize(width: 0, height: 0)
        recommandCollectionViewLayout.headerReferenceSize = CGSize(width: 0, height: 0)
        recommandCollectionViewLayout.itemSize = CGSize(width: 361, height: 274)
        viewRelatedVideo.addSubview(recommandCollectionView)
        recommandCollectionView.snp.makeConstraints { make in
            make.top.equalTo(label2.snp.bottom)
            make.height.equalTo(300)
            make.left.right.bottom.equalToSuperview()
        }

        viewComments.backgroundColor = UIColor(white: 0, alpha: 0)
        viewComments.translatesAutoresizingMaskIntoConstraints = false
        mainStack.addArrangedSubview(viewComments)

        label3.contentMode = .left
        label3.font = UIFont.preferredFont(forTextStyle: .title3)
        label3.setContentHuggingPriority(UILayoutPriority(rawValue: 251), for: .horizontal)
        viewComments.addSubview(label3)
        label3.snp.makeConstraints { make in
            make.top.equalToSuperview()
        }

        replysCollectionView.delegate = self
        replysCollectionView.dataSource = self
        replysCollectionView.backgroundColor = UIColor(white: 0, alpha: 0)
        replysCollectionView.clipsToBounds = true
        replysCollectionView.translatesAutoresizingMaskIntoConstraints = false
        replysCollectionView.register(ReplyCell.self, forCellWithReuseIdentifier: String(describing: ReplyCell.self))
        replysCollectionViewLayout.footerReferenceSize = CGSize(width: 0, height: 0)
        replysCollectionViewLayout.headerReferenceSize = CGSize(width: 0, height: 0)
        replysCollectionViewLayout.itemSize = CGSize(width: 582, height: 360)
        viewComments.addSubview(replysCollectionView)
        replysCollectionView.snp.makeConstraints { make in
            make.top.equalTo(label3.snp.bottom).offset(20)
            make.height.equalTo(300)
            make.left.right.bottom.equalToSuperview()
        }
    }

    private func setupLoading() {
        effectContainerView.isHidden = true
        view.addSubview(loadingView)
        loadingView.color = .white
        loadingView.style = .large
        loadingView.startAnimating()
        loadingView.makeConstraintsBindToCenterOfSuperview()
    }

    func present(from vc: UIViewController = UIViewController.topMostViewController(), direatlyEnterVideo: Bool = Settings.direatlyEnterVideo) {
        if !direatlyEnterVideo {
            vc.present(self, animated: true)
        } else {
            vc.present(self, animated: false) { [weak self] in
                guard let self else { return }
                let player = VideoPlayerViewController(playInfo: PlayInfo(aid: self.aid, cid: self.cid))
                self.present(player, animated: true)
            }
        }
    }

    private func exit(with error: Error) {
        Logger.warn(error)
        let alertVC = UIAlertController(title: "获取失败", message: error.localizedDescription, preferredStyle: .alert)
        alertVC.addAction(UIAlertAction(title: "Ok", style: .cancel, handler: { [weak self] action in
            self?.dismiss(animated: true)
        }))
        present(alertVC, animated: true, completion: nil)
    }

    private func fetchData() async {
        scrollView.setContentOffset(.zero, animated: false)
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
        backgroundImageView.alpha = 0
        setupLoading()
        pageView.isHidden = true
        ugcView.isHidden = true
        do {
            if seasonId > 0 {
                isBangumi = true
                let info = try await WebRequest.requestBangumiInfo(seasonID: seasonId)
                if let epi = info.main_section.episodes.first ?? info.section.first?.episodes.first {
                    aid = epi.aid
                    cid = epi.cid
                }
                pages = info.main_section.episodes.map({ VideoPage(cid: $0.cid, page: $0.aid, from: "", part: $0.title) })
            } else if epid > 0 {
                isBangumi = true
                let info = try await WebRequest.requestBangumiInfo(epid: epid)
                if let epi = info.episodes.first(where: { $0.id == epid }) ?? info.episodes.first {
                    aid = epi.aid
                    cid = epi.cid
                } else {
                    throw NSError(domain: "get epi fail", code: -1)
                }
                pages = info.episodes.map({ VideoPage(cid: $0.cid, page: $0.aid, from: "", part: $0.title) })
            }
            let data = try await WebRequest.requestDetailVideo(aid: aid)
            self.data = data

            if let redirect = data.View.redirect_url?.lastPathComponent, redirect.starts(with: "ep"), let id = Int(redirect.dropFirst(2)), !isBangumi {
                isBangumi = true
                epid = id
                let info = try await WebRequest.requestBangumiInfo(epid: epid)
                pages = info.episodes.map({ VideoPage(cid: $0.cid, page: $0.aid, from: "", part: $0.title + " " + $0.long_title) })
            }
            update(with: data)
        } catch let err {
            self.exit(with: err)
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

        if isBangumi {
            favButton.isHidden = true
            recommandCollectionView.superview?.isHidden = true
            return
        }

        WebRequest.requestFavoriteStatus(aid: aid) { [weak self] isFavorited in
            self?.favButton.isOn = isFavorited
        }
    }

    private func update(with data: VideoDetail) {
        playCountLabel.text = data.View.stat.view.numberString()
        danmakuLabel.text = data.View.stat.danmaku.numberString()
        followersLabel.text = (data.Card.follower ?? 0).numberString() + "粉丝"
        uploadTimeLabel.text = data.View.date
        bvidLabel.text = data.View.bvid
        coinButton.title = data.View.stat.coin.numberString()
        favButton.title = data.View.stat.favorite.numberString()
        likeButton.title = data.View.stat.like.numberString()

        durationLabel.titleLabel.text = data.View.durationString
        titleLabel.text = data.title
        upButton.title = data.ownerName
        followButton.isOn = data.Card.following

        avatarImageView.kf.setImage(with: data.avatar, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])

        coverImageView.kf.setImage(with: data.pic)
        backgroundImageView.kf.setImage(with: data.pic)
        recommandCollectionView.superview?.isHidden = data.Related.count == 0

        var notes = [String]()
        let status = data.View.dynamic ?? ""
        if status.count > 1 {
            notes.append(status)
        }
        notes.append(data.View.desc ?? "")
        noteView.label.text = notes.joined(separator: "\n")
        if !isBangumi {
            pages = data.View.pages ?? []
        }
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
        UIView.animate(withDuration: 0.25) {
            self.backgroundImageView.alpha = 1
        }

        if let season = data.View.ugc_season {
            allUgcEpisodes = Array((season.sections.map { $0.episodes }.joined()))
        }
        ugcCollectionView.reloadData()
        ugcLabel.text = "合集 \(data.View.ugc_season?.title ?? "")  \(data.View.ugc_season?.sections.first?.title ?? "")"
        ugcView.isHidden = allUgcEpisodes.count == 0
        if allUgcEpisodes.count > 0 {
            ugcCollectionView.scrollToItem(at: IndexPath(item: allUgcEpisodes.map { $0.aid }.firstIndex(of: aid) ?? 0, section: 0), at: .left, animated: false)
        }

        recommandCollectionView.reloadData()
    }

    @objc func actionShowUpSpace(_ sender: Any) {
        let upSpaceVC = UpSpaceViewController()
        upSpaceVC.mid = data?.View.owner.mid
        present(upSpaceVC, animated: true)
    }

    @objc func actionFollow(_ sender: Any) {
        followButton.isOn.toggle()
        if let mid = data?.View.owner.mid {
            WebRequest.follow(mid: mid, follow: followButton.isOn)
        }
    }

    @objc func actionPlay(_ sender: Any) {
        let player = VideoPlayerViewController(playInfo: PlayInfo(aid: aid, cid: cid, isBangumi: isBangumi))
        player.data = data
        if pages.count > 0, let index = pages.firstIndex(where: { $0.cid == cid }) {
            let seq = pages.dropFirst(index).map({ PlayInfo(aid: aid, cid: $0.cid, isBangumi: isBangumi) })
            if seq.count > 0 {
                let nextProvider = VideoNextProvider(seq: seq)
                player.nextProvider = nextProvider
            }
        }
        present(player, animated: true, completion: nil)
    }

    @objc func actionLike(_ sender: Any) {
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

    @IBAction func actionCoin(_ sender: BLCustomButton) {
        guard didSentCoins < 2 else { return }
        let alert = UIAlertController(title: "投币个数", message: nil, preferredStyle: .actionSheet)
        alert.popoverPresentationController?.sourceView = sender
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

    @objc func actionFavorite(_ sender: BLCustomButton) {
        Task {
            guard let favList = try? await WebRequest.requestFavVideosList() else {
                return
            }
            let alert = UIAlertController(title: "收藏", message: nil, preferredStyle: .actionSheet)
            alert.popoverPresentationController?.sourceView = sender
            let aid = aid
            for fav in favList {
                alert.addAction(UIAlertAction(title: fav.title, style: .default) { [weak self] _ in
                    self?.favButton.title? += 1
                    self?.favButton.isOn = true
                    WebRequest.requestFavorite(aid: aid, mid: fav.id)
                })
            }
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            present(alert, animated: true)
        }
    }

    @objc func actionDislike(_ sender: Any) {
        dislikeButton.isOn.toggle()
        ApiRequest.requestDislike(aid: aid, dislike: dislikeButton.isOn)
    }
}

extension VideoDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch collectionView {
        case pageCollectionView:
            let page = pages[indexPath.item]
            let player = VideoPlayerViewController(playInfo: PlayInfo(aid: isBangumi ? page.page : aid, cid: page.cid, isBangumi: isBangumi))
            player.data = isBangumi ? nil : data

            let seq = pages.dropFirst(indexPath.item).map({ PlayInfo(aid: aid, cid: $0.cid, isBangumi: isBangumi) })
            if seq.count > 0 {
                let nextProvider = VideoNextProvider(seq: seq)
                player.nextProvider = nextProvider
            }
            present(player, animated: true, completion: nil)
        case replysCollectionView:
            guard let reply = replys?.replies?[indexPath.item] else { return }
            let detail = ContentDetailViewController.createReply(content: reply.content.message)
            present(detail, animated: true)
        case ugcCollectionView:
            let video = allUgcEpisodes[indexPath.item]
            if Settings.showRelatedVideoInCurrentVC {
                aid = video.aid
                cid = video.cid
                Task { await fetchData() }
            } else {
                let detailVC = VideoDetailViewController()
                detailVC.aid = video.aid
                detailVC.cid = video.cid
                detailVC.present(from: self)
            }
        case recommandCollectionView:
            if let video = data?.Related[indexPath.item] {
                if Settings.showRelatedVideoInCurrentVC {
                    aid = video.aid
                    cid = video.cid
                    Task { await fetchData() }
                } else {
                    let detailVC = VideoDetailViewController()
                    detailVC.aid = video.aid
                    detailVC.cid = video.cid
                    detailVC.present(from: self)
                }
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
            return replys?.replies?.count ?? 0
        case ugcCollectionView:
            return allUgcEpisodes.count
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
            if let reply = replys?.replies?[indexPath.item] {
                cell.config(replay: reply)
            }
            return cell
        case ugcCollectionView:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: String(describing: RelatedVideoCell.self), for: indexPath) as! RelatedVideoCell
            let record = allUgcEpisodes[indexPath.row]
            cell.update(data: record)
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

class ReplyCell: BLMotionCollectionViewCell {
    let avatarImageView = UIImageView()
    let userNameLabel = UILabel()
    let contenLabel = UILabel()

    override func setup() {
        super.setup()
        contentView.addSubview(avatarImageView)
        avatarImageView.snp.makeConstraints { make in
            make.width.height.equalTo(50)
            make.left.top.equalTo(20)
        }

        contentView.addSubview(userNameLabel)
        userNameLabel.snp.makeConstraints { make in
            make.centerY.equalTo(avatarImageView)
        }

        contentView.addSubview(contenLabel)
        contenLabel.snp.makeConstraints { make in
            make.top.equalTo(avatarImageView.snp.bottom)
            make.left.equalTo(20)
            make.right.equalTo(-20)
            make.bottom.equalToSuperview()
        }
    }

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
        imageView.kf.setImage(with: data.pic, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 360, height: 202))), .cacheOriginalImage])
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

class DetailLabel: UILabel {
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            if self.isFocused {
                self.backgroundColor = .white
            } else {
                self.backgroundColor = .clear
            }
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        isUserInteractionEnabled = true
    }

    override var canBecomeFocused: Bool {
        return true
    }

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: 0, left: 5, bottom: 0, right: 5)
        super.drawText(in: rect.inset(by: insets))
    }
}

class IconAndTextView: UIView {
    let imageView = UIImageView()
    let titleLabel = UILabel()
    var text: String? {
        set {
            titleLabel.text = newValue
        }
        get {
            return titleLabel.text
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        let stackView = UIStackView(arrangedSubviews: [imageView, titleLabel])
        addSubview(stackView)
        stackView.snp.makeConstraints { $0.edges.equalToSuperview() }
        stackView.spacing = 10
        titleLabel.textColor = .white
        imageView.snp.makeConstraints { $0.width.equalTo(imageView.snp.height) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class NoteDetailView: UIControl {
    let label = UILabel()
    var onPrimaryAction: ((NoteDetailView) -> Void)?
    private let backgroundView = UIView()
    init() {
        super.init(frame: .zero)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func setup() {
        addSubview(backgroundView)
        backgroundView.backgroundColor = UIColor(named: "bgColor")
        backgroundView.layer.shadowOffset = CGSizeMake(0, 10)
        backgroundView.layer.shadowOpacity = 0.15
        backgroundView.layer.shadowRadius = 16.0
        backgroundView.layer.cornerRadius = 20
        backgroundView.layer.cornerCurve = .continuous
        backgroundView.isHidden = !isFocused
        backgroundView.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview()
            make.left.equalToSuperview().offset(-20)
            make.right.equalToSuperview().offset(20)
        }

        addSubview(label)
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 29)
        label.textColor = UIColor(named: "titleColor")
        label.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview().offset(14)
            make.bottom.lessThanOrEqualToSuperview().offset(-14)
        }
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        backgroundView.isHidden = !isFocused
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)
        if presses.first?.type == .select {
            sendActions(for: .primaryActionTriggered)
            onPrimaryAction?(self)
        }
    }
}

class ContentDetailViewController: UIViewController {
    private let titleLabel = UILabel()
    private let contentTextView = UITextView()

    static func createDesp(content: String) -> ContentDetailViewController {
        let vc = ContentDetailViewController()
        vc.titleLabel.text = "简介"
        vc.contentTextView.text = content
        return vc
    }

    static func createReply(content: String) -> ContentDetailViewController {
        let vc = ContentDetailViewController()
        vc.titleLabel.text = "评论"
        vc.contentTextView.text = content
        return vc
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        [contentTextView]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(titleLabel)
        view.addSubview(contentTextView)
        titleLabel.font = UIFont.systemFont(ofSize: 60, weight: .semibold)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(80)
            make.centerX.equalToSuperview()
        }
        contentTextView.panGestureRecognizer.allowedTouchTypes = [NSNumber(value: UITouch.TouchType.indirect.rawValue)]
        contentTextView.isScrollEnabled = true
        contentTextView.isUserInteractionEnabled = true
        contentTextView.isSelectable = true
        contentTextView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom)
            make.centerX.equalToSuperview()
            make.leading.equalToSuperview().offset(60)
            make.trailing.equalToSuperview().inset(60)
            make.bottom.equalToSuperview().inset(80)
        }
    }
}
