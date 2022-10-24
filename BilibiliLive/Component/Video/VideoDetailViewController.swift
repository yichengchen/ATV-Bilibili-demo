//
//  VideoDetailViewController.swift
//  BilibiliLive
//
//  Created by Etan Chen on 2021/4/17.
//

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

    @IBOutlet var durationLabel: UILabel!
    @IBOutlet var avatarImageView: UIImageView!
    @IBOutlet var favButton: BLCustomButton!
    @IBOutlet var pageCollectionView: UICollectionView!
    @IBOutlet var recommandCollectionView: UICollectionView!

    private var aid: Int!
    private var cid: Int!
    private var mid = 0
    private var didSentCoins = 0 {
        didSet {
            if didSentCoins > 0 {
                coinButton.isOn = true
            }
        }
    }

    private var pages = [PageData]()
    private var relateds = [VideoDetail]()

    static func create(aid: Int, cid: Int) -> VideoDetailViewController {
        let vc = UIStoryboard(name: "Main", bundle: .main).instantiateViewController(identifier: "VideoDetailViewController") as! VideoDetailViewController
        vc.aid = aid
        vc.cid = cid
        return vc
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupLoading()
        fetchData()
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
        AF.request("http://api.bilibili.com/x/web-interface/view", parameters: ["aid": aid]).responseData {
            [weak self] resp in
            guard let self = self else { return }
            switch resp.result {
            case let .success(data):
                let json = JSON(data)
                self.update(with: json)
            case let .failure(err):
                self.exit(with: err)
            }
        }

        WebRequest.requestRelatedVideo(aid: aid) {
            [weak self] recommands in
            self?.relateds = recommands
            self?.recommandCollectionView.reloadData()
        }

        WebRequest.requestLikeStatus(aid: aid) { [weak self] isLiked in
            self?.likeButton.isOn = isLiked
        }

        WebRequest.requestCoinStatus(aid: aid) { [weak self] coins in
            self?.didSentCoins = coins
        }
    }

    private func update(with json: JSON) {
        let data = json["data"]
        mid = data["owner"]["mid"].intValue
        likeButton.title = data["stat"]["favorite"].stringValue
        coinButton.title = data["stat"]["coin"].stringValue
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .brief
        let formattedString = formatter.string(from: TimeInterval(data["duration"].intValue)) ?? ""
        durationLabel.text = formattedString
        favButton.title = data["stat"]["favorite"].stringValue
        titleLabel.text = data["title"].stringValue
        upButton.title = data["owner"]["name"].stringValue

        avatarImageView.kf.setImage(with: data["owner"]["face"].url, options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))), .processor(RoundCornerImageProcessor(radius: .widthFraction(0.5))), .cacheSerializer(FormatIndicatedCacheSerializer.png)])

        let image = URL(string: data["pic"].stringValue)
        coverImageView.kf.setImage(with: image)
        backgroundImageView.kf.setImage(with: image)

        var notes = [String]()
        let status = data["dynamic"].stringValue
        if status.count > 1 {
            notes.append(status)
        }
        notes.append(data["desc"].stringValue)
        noteLabel.text = notes.joined(separator: "\n")

        pages = data["pages"].arrayValue.map {
            PageData(cid: $0["cid"].intValue, name: $0["part"].stringValue)
        }
        if pages.count > 1 {
            pageCollectionView.reloadData()
            pageCollectionView.isHidden = false
            let index = pages.firstIndex { $0.cid == cid } ?? 0
            pageCollectionView.scrollToItem(at: IndexPath(row: index, section: 0), at: .left, animated: false)
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
        upSpaceVC.mid = mid
        present(upSpaceVC, animated: true)
    }

    @IBAction func actionPlay(_ sender: Any) {
        let player = VideoPlayerViewController()
        player.aid = aid
        player.cid = cid
        present(player, animated: true, completion: nil)
    }

    @IBAction func actionLike(_ sender: Any) {
        Task {
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
        let aid = aid!
        alert.addAction(UIAlertAction(title: "1", style: .default) { [weak self] _ in
            self?.likeButton.isOn = true
            self?.didSentCoins += 1
            WebRequest.requestCoin(aid: aid, num: 1)
        })
        if didSentCoins == 0 {
            alert.addAction(UIAlertAction(title: "2", style: .default) { [weak self] _ in
                self?.likeButton.isOn = true
                self?.didSentCoins += 2
                WebRequest.requestCoin(aid: aid, num: 2)
            })
        }
        alert.addAction(UIAlertAction(title: "取消", style: .default))
        present(alert, animated: true)
    }

    @IBAction func actionFavorite(_ sender: Any) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "待开发", style: .default))
        present(alert, animated: true)
    }
}

extension VideoDetailViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView == pageCollectionView {
            let page = pages[indexPath.item]
            let player = VideoPlayerViewController()
            player.aid = aid
            player.cid = page.cid
            present(player, animated: true, completion: nil)
        } else {
            let video = relateds[indexPath.item]
            let detailVC = VideoDetailViewController.create(aid: video.aid, cid: video.cid)
            present(detailVC, animated: true, completion: nil)
        }
    }
}

extension VideoDetailViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == pageCollectionView {
            return pages.count
        }
        return relateds.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath)
        let label = cell.viewWithTag(2) as! UILabel
        if collectionView == pageCollectionView {
            let page = pages[indexPath.item]
            label.text = page.name
            return cell
        }
        let related = relateds[indexPath.row]
        let imageView = cell.viewWithTag(1) as! UIImageView
        label.text = related.title
        imageView.kf.setImage(with: URL(string: related.pic))
        return cell
    }
}

struct PageData {
    let cid: Int
    let name: String
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

class BLImageView: UIImageView {
    var on: Bool = false {
        didSet {
            tintColor = on ? UIColor.biliblue : UIColor.black
        }
    }
}
