//
//  LiveDanmuHistoryPlugin.swift
//  BilibiliLive
//
//  直播间左滑呼出弹幕历史
//

import AVKit
import Combine
import Kingfisher
import SnapKit
import UIKit

class LiveDanmuHistoryPlugin: NSObject, CommonPlayerPlugin {
    private let store: LiveDanmuHistoryStore
    private weak var playerVC: AVPlayerViewController?
    private var swipeGesture: UISwipeGestureRecognizer?

    init(store: LiveDanmuHistoryStore) {
        self.store = store
    }

    func playerDidLoad(playerVC: AVPlayerViewController) {
        self.playerVC = playerVC
        guard swipeGesture == nil else { return }
        let swipe = UISwipeGestureRecognizer(target: self, action: #selector(actionSwipeLeft))
        swipe.direction = .left
        swipe.delegate = self
        playerVC.view.addGestureRecognizer(swipe)
        swipeGesture = swipe
    }

    func addMenuItems(current: inout [UIMenuElement]) -> [UIMenuElement] {
        let action = UIAction(title: "弹幕历史", image: UIImage(systemName: "text.bubble")) { [weak self] _ in
            self?.showHistory()
        }
        return [action]
    }

    @objc private func actionSwipeLeft() {
        showHistory()
    }

    private func showHistory() {
        guard let playerVC, playerVC.presentedViewController == nil, playerVC.view.window != nil else { return }
        let vc = LiveDanmuHistoryViewController(store: store)
        playerVC.present(vc, animated: false)
    }
}

extension LiveDanmuHistoryPlugin: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === swipeGesture else { return true }
        return !isPlayerControlFocused()
    }

    /// 菜单 / 信息面板 / 进度条弹出时，焦点会落在 AVKit 内部的按钮、Cell、进度条等可交互控件上，
    /// 此时左滑应交给系统处理焦点移动，不应呼出弹幕历史。
    private func isPlayerControlFocused() -> Bool {
        guard let playerVC, let window = playerVC.view.window,
              let focused = UIFocusSystem.focusSystem(for: window)?.focusedItem as? UIView
        else { return false }
        Logger.debug("[DanmuHistory] swipe left, focused: \(type(of: focused))")
        guard focused.isDescendant(of: playerVC.view) else { return true }
        if focused is UIControl || focused is UICollectionViewCell || focused is UITableViewCell {
            return true
        }
        let keywords = ["Button", "Cell", "Scrub", "TransportBar", "Menu", "Tab", "Panel", "Slider"]
        var view: UIView? = focused
        while let current = view, current !== playerVC.view {
            let name = NSStringFromClass(type(of: current))
            if keywords.contains(where: { name.contains($0) }) { return true }
            view = current.superview
        }
        return false
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        true
    }
}

// MARK: - ViewController

class LiveDanmuHistoryViewController: UIViewController {
    private static let panelWidth: CGFloat = 760

    private let store: LiveDanmuHistoryStore
    private let panel = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let titleLabel = UILabel()
    private let emptyLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var cancellable: AnyCancellable?
    private var focusedIndexPath: IndexPath?
    private var isDismissing = false

    private var lastIndexPath: IndexPath? {
        store.items.isEmpty ? nil : IndexPath(row: store.items.count - 1, section: 0)
    }

    init(store: LiveDanmuHistoryStore) {
        self.store = store
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        view.addSubview(panel)
        panel.snp.makeConstraints { make in
            make.top.bottom.trailing.equalToSuperview()
            make.width.equalTo(Self.panelWidth)
        }

        titleLabel.font = .systemFont(ofSize: 38, weight: .bold)
        titleLabel.textColor = .white
        panel.contentView.addSubview(titleLabel)
        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(60)
            make.leading.equalToSuperview().offset(40)
            make.trailing.equalToSuperview().offset(-40)
        }

        tableView.backgroundColor = .clear
        // 面板始终跟随最新弹幕滚动，滚动条无意义；且频繁滚动会触发 UIKit 滚动条 UIAttachmentBehavior 警告刷屏
        tableView.showsVerticalScrollIndicator = false
        tableView.register(LiveDanmuHistoryCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.remembersLastFocusedIndexPath = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 120
        tableView.contentInset = UIEdgeInsets(top: 10, left: 0, bottom: 40, right: 0)
        panel.contentView.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(20)
            make.leading.trailing.bottom.equalToSuperview()
        }

        emptyLabel.text = "本场直播暂无弹幕"
        emptyLabel.font = .systemFont(ofSize: 30)
        emptyLabel.textColor = .lightGray
        emptyLabel.textAlignment = .center
        panel.contentView.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(tableView)
        }

        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(actionClose))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeRight)

        updateHeader()
        // store 只在主线程变更并同步发送事件；不能用 receive(on:) 异步派发，
        // 否则事件处理时 store.items 可能已多出若干条，insertRows 行数校验失败崩溃
        cancellable = store.onChange
            .sink { [weak self] in self?.handle(change: $0) }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        panel.transform = CGAffineTransform(translationX: Self.panelWidth, y: 0)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        scrollToBottom(animated: false)
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseOut) {
            self.panel.transform = .identity
        }
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        [tableView]
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        if presses.contains(where: { $0.type == .menu }) {
            actionClose()
            return
        }
        super.pressesBegan(presses, with: event)
    }

    @objc private func actionClose() {
        guard !isDismissing else { return }
        isDismissing = true
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
            self.panel.transform = CGAffineTransform(translationX: Self.panelWidth, y: 0)
        } completion: { _ in
            self.dismiss(animated: false)
        }
    }

    private func updateHeader() {
        titleLabel.text = "弹幕历史 · \(store.items.count) 条"
        emptyLabel.isHidden = !store.items.isEmpty
    }

    private func handle(change: LiveDanmuHistoryStore.Change) {
        // 用户正停留在最新一条时，自动跟随新弹幕
        let oldCount = tableView.numberOfRows(inSection: 0)
        let wasAtBottom = focusedIndexPath == nil || focusedIndexPath == IndexPath(row: oldCount - 1, section: 0)
        switch change {
        case let .appended(range) where range.lowerBound == oldCount && range.upperBound == store.items.count:
            tableView.insertRows(at: range.map { IndexPath(row: $0, section: 0) }, with: .none)
        default:
            // 行数对不上（或批量删除）时整体刷新，保证与数据源一致
            tableView.reloadData()
        }
        updateHeader()
        if wasAtBottom {
            scrollToBottom(animated: false)
            if focusedIndexPath != nil {
                setNeedsFocusUpdate()
                updateFocusIfNeeded()
            }
        }
    }

    private func scrollToBottom(animated: Bool) {
        tableView.layoutIfNeeded()
        // 以 tableView 当前的行数为准，避免滚动到不存在的行
        let rows = tableView.numberOfRows(inSection: 0)
        guard rows > 0 else { return }
        tableView.scrollToRow(at: IndexPath(row: rows - 1, section: 0), at: .bottom, animated: animated)
    }
}

extension LiveDanmuHistoryViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        store.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! LiveDanmuHistoryCell
        cell.update(with: store.items[indexPath.row])
        return cell
    }

    func indexPathForPreferredFocusedView(in tableView: UITableView) -> IndexPath? {
        lastIndexPath
    }

    func tableView(_ tableView: UITableView, didUpdateFocusIn context: UITableViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        focusedIndexPath = context.nextFocusedIndexPath
    }
}

// MARK: - Cell

class LiveDanmuHistoryCell: UITableViewCell {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()

    private let bgView = UIView()
    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let contentLabel = UILabel()
    private let scLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        focusStyle = .custom
        selectionStyle = .none

        bgView.layer.cornerRadius = 16
        bgView.layer.cornerCurve = .continuous
        contentView.addSubview(bgView)
        bgView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 6, left: 24, bottom: 6, right: 24))
        }

        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = 30
        avatarView.clipsToBounds = true
        avatarView.tintColor = .lightGray
        bgView.addSubview(avatarView)
        avatarView.snp.makeConstraints { make in
            make.leading.top.equalToSuperview().offset(16)
            make.size.equalTo(60)
            make.bottom.lessThanOrEqualToSuperview().offset(-16)
        }

        timeLabel.font = .monospacedDigitSystemFont(ofSize: 22, weight: .regular)
        timeLabel.textColor = UIColor(white: 1, alpha: 0.5)
        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        bgView.addSubview(timeLabel)

        nameLabel.font = .systemFont(ofSize: 24, weight: .medium)
        nameLabel.textColor = UIColor(red: 0.98, green: 0.45, blue: 0.6, alpha: 1)
        bgView.addSubview(nameLabel)

        scLabel.font = .systemFont(ofSize: 20, weight: .bold)
        scLabel.textColor = .black
        scLabel.backgroundColor = UIColor(red: 1, green: 0.8, blue: 0.3, alpha: 1)
        scLabel.layer.cornerRadius = 6
        scLabel.clipsToBounds = true
        scLabel.textAlignment = .center
        scLabel.setContentHuggingPriority(.required, for: .horizontal)
        scLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        bgView.addSubview(scLabel)

        nameLabel.snp.makeConstraints { make in
            make.leading.equalTo(avatarView.snp.trailing).offset(16)
            make.top.equalToSuperview().offset(14)
        }
        scLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel.snp.trailing).offset(10)
            make.centerY.equalTo(nameLabel)
            make.height.equalTo(30)
        }
        timeLabel.snp.makeConstraints { make in
            make.leading.greaterThanOrEqualTo(scLabel.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalTo(nameLabel)
        }

        contentLabel.font = .systemFont(ofSize: 30)
        contentLabel.textColor = .white
        contentLabel.numberOfLines = 0
        bgView.addSubview(contentLabel)
        contentLabel.snp.makeConstraints { make in
            make.leading.equalTo(nameLabel)
            make.trailing.equalToSuperview().offset(-16)
            make.top.equalTo(nameLabel.snp.bottom).offset(6)
            make.bottom.equalToSuperview().offset(-14)
        }
        updateBackground()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var isSuperChat = false

    func update(with item: LiveDanmuHistoryItem) {
        nameLabel.text = item.name.isEmpty ? "UID:\(item.uid)" : item.name
        contentLabel.text = item.text
        timeLabel.text = Self.timeFormatter.string(from: Date(timeIntervalSince1970: item.time))
        isSuperChat = item.isSuperChat
        if let price = item.superChatPrice {
            scLabel.isHidden = false
            scLabel.text = "  SC ¥\(price)  "
        } else {
            scLabel.isHidden = true
            scLabel.text = nil
        }
        let placeholder = UIImage(systemName: "person.crop.circle.fill")
        if let url = item.faceURL {
            avatarView.kf.setImage(with: url,
                                   placeholder: placeholder,
                                   options: [.processor(DownsamplingImageProcessor(size: CGSize(width: 80, height: 80))),
                                             .cacheOriginalImage])
        } else {
            avatarView.kf.cancelDownloadTask()
            avatarView.image = placeholder
        }
        updateBackground()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.kf.cancelDownloadTask()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations { [weak self] in
            self?.updateBackground()
        }
    }

    private func updateBackground() {
        if isFocused {
            bgView.backgroundColor = UIColor(white: 1, alpha: 0.25)
        } else if isSuperChat {
            bgView.backgroundColor = UIColor(red: 1, green: 0.75, blue: 0.2, alpha: 0.18)
        } else {
            bgView.backgroundColor = .clear
        }
    }
}
