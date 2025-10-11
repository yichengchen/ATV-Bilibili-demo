//
//  FeedCollectionViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/5.
//

import SnapKit
import TVUIKit
import UIKit

let sornerRadius = 8.0
let littleSornerRadius = 24.0
let moreLittleSornerRadius = 18.0
let normailSornerRadius = 25.0
let lessBigSornerRadius = 35.0
let bigSornerRadius = 45.0

let EVENT_COLLECTION_TO_TOP = NSNotification.Name("EVENT_COLLECTION_TO_TOP")
let EVENT_COLLECTION_TO_SHOW_MENU = NSNotification.Name("EVENT_COLLECTION_TO_SHOW_MENU")

protocol DisplayData: Hashable {
    var title: String { get }
    var ownerName: String { get }
    var pic: URL? { get }
    var avatar: URL? { get }
    var date: String? { get }
}

extension DisplayData {
    var avatar: URL? { return nil }
    var date: String? { return nil }
}

struct AnyDispplayData: Hashable {
    let data: any DisplayData

    static func == (lhs: AnyDispplayData, rhs: AnyDispplayData) -> Bool {
        func eq<T: Equatable>(lhs: T, rhs: any Equatable) -> Bool {
            lhs == rhs as? T
        }
        return eq(lhs: lhs.data, rhs: rhs.data)
    }

    func hash(into hasher: inout Hasher) {
        data.hash(into: &hasher)
    }
}

class FeedCollectionViewController: UIViewController {
    var collectionView: BLCollectionView!

    private enum Section: CaseIterable {
        case main
    }

    private var coverViewIsShowing = false

    var styleOverride: FeedDisplayStyle?
    var didSelect: ((any DisplayData) -> Void)?
    var didLongPress: ((any DisplayData) -> Void)?
    var loadMore: (() -> Void)?
    var finished = false
    var pageSize = 20
    var showHeader: Bool = true
    var headerText = ""
    var coverViewHeight = 500.0
    let collectionEdgeInsetTop = 200.0
    var isShowCove = false
    var timer = Timer()
    let coverView = BLCoverView()
    var nextFocusedIndexPath: IndexPath?

    let bgImageView = UIImageView()

    var backMenuAction: (() -> Void)?
    var didUpdateFocus: (() -> Void)?

    var didSelectToLastLeft: (() -> Void)?
    private var beforeSeleteIndex: IndexPath?

    var displayDatas: [any DisplayData] {
        set {
            _displayData = newValue.map { AnyDispplayData(data: $0) }.uniqued()
            finished = false
        }
        get {
            _displayData.map { $0.data }
        }
    }

    private var _displayData = [AnyDispplayData]() {
        didSet {
            var snapshot = NSDiffableDataSourceSnapshot<Section, AnyDispplayData>()
            snapshot.appendSections(Section.allCases)
            snapshot.appendItems(_displayData, toSection: .main)
            dataSource.apply(snapshot)
        }
    }

    private var isLoading = false

    typealias DisplayCellRegistration = UICollectionView.CellRegistration<FeedCollectionViewCell, AnyDispplayData>
    private lazy var dataSource = makeDataSource()

    // MARK: - Public

    func show(in vc: UIViewController) {
        vc.addChild(self)
        vc.view.addSubview(view)
        view.makeConstraintsToBindToSuperview()
        didMove(toParent: vc)
        vc.setContentScrollView(collectionView)
    }

    func appendData(displayData: [any DisplayData]) {
        isLoading = false
        _displayData.append(contentsOf: displayData.map { AnyDispplayData(data: $0) }.filter({ !_displayData.contains($0) }))
        if displayData.count < pageSize - 5 || displayData.count == 0 {
            finished = true
            return
        }

        if _displayData.count < 12 {
            isLoading = true
            loadMore?()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(bgImageView)
        bgImageView.snp.makeConstraints { make in
            make.left.right.bottom.equalToSuperview()
            make.top.equalToSuperview().offset(-60)
        }
        bgImageView.setBlurEffectView()

        collectionView = BLCollectionView(frame: .zero, collectionViewLayout: makeCollectionViewLayout())
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        collectionView.contentInset = UIEdgeInsets(top: collectionEdgeInsetTop, left: 0, bottom: 0, right: 0)

        collectionView.dataSource = dataSource
        collectionView.delegate = self

        view.addSubview(coverView)
        coverView.setBlurEffectView()
        coverView.setCornerRadius(cornerRadius: bigSornerRadius)
        coverView.snp.makeConstraints { make in
            make.left.equalTo(48)
            make.right.equalTo(-48)
            make.height.equalTo(coverViewHeight)
            make.bottom.equalTo(view).offset(coverViewHeight)
        }

        NotificationCenter.default.addObserver(forName: EVENT_COLLECTION_TO_TOP, object: nil, queue: .main) { [weak self] _ in
            self?.handleMenuPress()
        }
    }

    func handleMenuPress() {
        if collectionView.contentOffset.y > 100 {
            let indexPath = IndexPath(item: 0, section: 0)
//            collectionView.scrollToItem(at: indexPath, at: .top, animated: true)
//            collectionView.setContentOffset(CGPoint(x: 0, y: -collectionEdgeInsetTop), animated: true)
            collectionView.selectItem(at: indexPath, animated: true, scrollPosition: .top)
            collectionView.reloadData()

        } else {
            NotificationCenter.default.post(name: EVENT_COLLECTION_TO_SHOW_MENU, object: nil)
        }
        if coverViewIsShowing {
            hiddenCoverView()
        }
    }

    // MARK: - Private

    private func makeCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            [weak self] _, _ in
            self?.makeGridLayoutSection()
        }
    }

    private func makeGridLayoutSection() -> NSCollectionLayoutSection {
        let style = styleOverride ?? Settings.displayStyle

        // top
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(style.fractionalWidth),

            heightDimension: .fractionalHeight(1)

        ))
        let hSpacing = style.hSpacing
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: hSpacing, bottom: 0, trailing: hSpacing)

        let group = NSCollectionLayoutGroup.horizontal(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .fractionalHeight(style.groupFractionalHeight)
        ), repeatingSubitem: item, count: style.feedColCount)

        let vSpacing: CGFloat = style == .large ? 34 : 26
        let baseSpacing: CGFloat = style == .sideBar ? 34 : 0

        group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: .fixed(baseSpacing), top: .fixed(vSpacing), trailing: .fixed(0), bottom: .fixed(vSpacing))

        // section
        let section = NSCollectionLayoutSection(group: group)
        if baseSpacing > 0 {
            section.contentInsets = NSDirectionalEdgeInsets(top: baseSpacing, leading: 0, bottom: 0, trailing: 0)
        }

        let titleSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                               heightDimension: .estimated(44))
        if showHeader {
            let titleSupplementary = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: titleSize,
                elementKind: TitleSupplementaryView.reuseIdentifier,
                alignment: .top
            )
            section.boundarySupplementaryItems = [titleSupplementary]
        }

        return section
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, AnyDispplayData> {
        let dataSource = UICollectionViewDiffableDataSource<Section, AnyDispplayData>(collectionView: collectionView, cellProvider: makeCellRegistration().cellProvider)

        let supplementaryRegistration = UICollectionView.SupplementaryRegistration<TitleSupplementaryView>(elementKind: TitleSupplementaryView.reuseIdentifier) {
            [weak self] supplementaryView, _, _ in
            guard let self else { return }
            supplementaryView.label.text = self.headerText
        }

        dataSource.supplementaryViewProvider = { _, _, index in
            self.collectionView.dequeueConfiguredReusableSupplementary(
                using: supplementaryRegistration, for: index
            )
        }

        return dataSource
    }

    private func makeCellRegistration() -> DisplayCellRegistration {
        DisplayCellRegistration { [weak self] cell, index, displayData in
            cell.styleOverride = self?.styleOverride
            cell.setup(data: displayData.data, indexPath: index)
            cell.onLongPress = {
                self?.didLongPress?(displayData.data)
            }
        }
    }

    private func showCoverView(viewHeight: CGFloat? = 0, bottom: CGFloat? = -20, isListenBack: Bool? = true, withDuration: TimeInterval? = 0.4) {
        if isListenBack! {
            timer.invalidate()
        }

        setCoverView(indexPath: nextFocusedIndexPath!)
        coverView.isHidden = false
        UIView.animate(withDuration: withDuration!, delay: 0, options: .curveEaseOut) {
            self.coverView.snp.updateConstraints { make in
                make.bottom.equalTo(self.view).offset(bottom!)
                make.height.equalTo(viewHeight! > 0 ? viewHeight! : self.coverViewHeight)
            }
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.coverView.setCornerRadius(cornerRadius: bigSornerRadius, shadowColor: .black, shadowAlpha: 0.2, tag: 1001)
            self.coverViewIsShowing = true
        }
    }

    private func hiddenCoverView(completion: (() -> Void)? = nil) {
        UIView.animate(withDuration: 0.4, delay: 0, options: .curveEaseOut) {
            self.coverView.snp.updateConstraints { make in
                make.bottom.equalTo(self.view).offset(self.coverViewHeight)
                make.height.equalTo(self.coverViewHeight)
            }
            self.view.layoutIfNeeded()
        } completion: { _ in
            self.coverViewIsShowing = false
        }
    }

    @objc func timerTimeout() {
        showCoverView()
    }
}

extension FeedCollectionViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let data = dataSource.itemIdentifier(for: indexPath) {
            didSelect?(data.data)
        }
    }

    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        let indexPath = IndexPath(item: 0, section: 0)
        return indexPath
    }

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard _displayData.count > 0 else { return }
        guard indexPath.row == _displayData.count - 1, !isLoading, !finished else {
            return
        }
        isLoading = true
        loadMore?()
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        collectionView.visibleCells.compactMap { $0 as? BLMotionCollectionViewCell }.forEach { cell in
            cell.updateTransform()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didUpdateFocusIn context: UICollectionViewFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        print("didUpdateFocusIn")

        if let indexPath = context.nextFocusedIndexPath {
            if let data = dataSource.itemIdentifier(for: indexPath), bgImageView.image == nil {
                bgImageView.kf.setImage(with: data.data.pic, placeholder: nil, options: nil) { _ in
                }
            }

            if let indexPath = nextFocusedIndexPath {
                let cell = collectionView.cellForItem(at: indexPath)
                if let cell = cell as? FeedCollectionViewCell {
//                    cell.infoView.isHidden = true
                    cell.infoView.alpha = 0.8
                }
            }

            let cell = collectionView.cellForItem(at: indexPath)
            if let cell = cell as? FeedCollectionViewCell {
//                cell.infoView.isHidden = false
                cell.infoView.alpha = 1
            }

            // 焦点在第二行
            nextFocusedIndexPath = indexPath

            guard isShowCove else {
                return
            }

            if Settings.showCover {
                if coverViewIsShowing {
                    hiddenCoverView {}
                } else {}

                timer.invalidate()

                BLAnimate(withDuration: 0.4) {
                    self.timer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(self.timerTimeout), userInfo: nil, repeats: true)

                    self.view.layoutIfNeeded()
                }
            }
        }
    }

    func setCoverView(indexPath: IndexPath) {
        if let data = dataSource.itemIdentifier(for: indexPath) {
            coverView.coverImageView.kf.setImage(with: data.data.pic, placeholder: nil, options: nil) { _ in
            }

            if let avatar = data.data.avatar {
                coverView.headImage.kf.setImage(with: avatar)
            } else {
                coverView.headImage.image = UIImage(named: "Bili")
            }
            coverView.nameLabel.text = data.data.ownerName
            if let date = data.data.date {
                coverView.timeLabel.isHidden = false
                coverView.timeLabel.text = "⌚️:\(date)"
            } else {
                coverView.timeLabel.isHidden = true
            }
            coverView.titleLabel.text = data.data.title
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesEnded(presses, with: event)

        // 检测“左方向键”
        guard presses.contains(where: { $0.type == .leftArrow }) else { return }

        // 当前获得焦点的 view
        guard let focused = UIScreen.main.focusedView as? UICollectionViewCell,
              let indexPath = collectionView.indexPath(for: focused) else { return }

        // 当前 item 是最左边？
        let style = styleOverride ?? Settings.displayStyle

        print("⬅️ indexPath.item = \(indexPath.item)")
        if indexPath.item % style.feedColCount == 0 && beforeSeleteIndex == indexPath {
            print("⬅️ 焦点在最左边，再按左键！")
            // 👉 这里执行你想要的逻辑，比如：
            // showPreviousPage()
            // moveToLeftMenu()
            didSelectToLastLeft?()
        }
        beforeSeleteIndex = indexPath
    }
}

extension FeedDisplayStyle {
    var feedColCount: Int {
        switch self {
        case .big: return bigItmeCount
        case .normal: return normalItmeCount
        case .large, .sideBar: return largeItmeCount
        }
    }
}
