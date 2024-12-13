//
//  FeedCollectionViewController.swift
//  BilibiliLive
//
//  Created by yicheng on 2021/4/5.
//

import SnapKit
import TVUIKit
import UIKit

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
    var collectionView: UICollectionView!

    private enum Section: CaseIterable {
        case main
    }

    var styleOverride: FeedDisplayStyle?
    var didSelect: ((any DisplayData) -> Void)?
    var didLongPress: ((any DisplayData) -> Void)?
    var loadMore: (() -> Void)?
    var finished = false
    var pageSize = 20
    var showHeader: Bool = false
    var headerText = ""

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
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeCollectionViewLayout())
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        collectionView.dataSource = dataSource
        collectionView.delegate = self
    }

    // MARK: - Private

    private func makeCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            [weak self] _, _ in
            return self?.makeGridLayoutSection()
        }
    }

    private func makeGridLayoutSection() -> NSCollectionLayoutSection {
        let style = styleOverride ?? Settings.displayStyle
        let heightDimension = NSCollectionLayoutDimension.estimated(style.heightEstimated)
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(style.fractionalWidth),
            heightDimension: heightDimension
        ))
        let hSpacing: CGFloat = style == .large ? 35 : 30
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: hSpacing, bottom: 0, trailing: hSpacing)
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: heightDimension
            ),
            repeatingSubitem: item,
            count: style.feedColCount
        )
        let vSpacing: CGFloat = style == .large ? 24 : 16
        let baseSpacing: CGFloat = style == .sideBar ? 24 : 0
        group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: .fixed(baseSpacing), top: .fixed(vSpacing), trailing: .fixed(0), bottom: .fixed(vSpacing))
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
            [weak self] supplementaryView, string, indexPath in
            guard let self else { return }
            supplementaryView.label.text = self.headerText
        }

        dataSource.supplementaryViewProvider = { view, kind, index in
            return self.collectionView.dequeueConfiguredReusableSupplementary(
                using: supplementaryRegistration, for: index
            )
        }

        return dataSource
    }

    private func makeCellRegistration() -> DisplayCellRegistration {
        DisplayCellRegistration { [weak self] cell, indexPath, displayData in
            cell.styleOverride = self?.styleOverride
            cell.setup(data: displayData.data)
            cell.onLongPress = {
                self?.didLongPress?(displayData.data)
            }
        }
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
}

extension FeedDisplayStyle {
    var feedColCount: Int {
        switch self {
        case .normal: return 4
        case .large, .sideBar: return 3
        }
    }
}
