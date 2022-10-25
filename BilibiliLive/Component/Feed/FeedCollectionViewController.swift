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

    var didSelect: ((any DisplayData) -> Void)?
    var didLongPress: ((any DisplayData) -> Void)?
    var loadMore: (() -> Void)?
    var finished = false
    var pageSize = 20
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
        vc.tabBarObservedScrollView = collectionView
    }

    func appendData(displayData: [any DisplayData]) {
        _displayData.append(contentsOf: displayData.map { AnyDispplayData(data: $0) }.filter({ !_displayData.contains($0) }))
        if displayData.count < pageSize {
            finished = true
        }
        isLoading = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: makeCollectionViewLayout())
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        collectionView.register(FeedCollectionViewCell.self, forCellWithReuseIdentifier: "1")
        collectionView.dataSource = dataSource
        collectionView.delegate = self
        collectionView.remembersLastFocusedIndexPath = true
    }

    // MARK: - Private

    private func makeCollectionViewLayout() -> UICollectionViewLayout {
        UICollectionViewCompositionalLayout {
            [weak self] _, _ in
            return self?.makeGridLayoutSection()
        }
    }

    private var selfSizeingEnable: Bool {
        if #available(tvOS 16.0, *) {
            return true
        }
        return false
    }

    private func makeGridLayoutSection() -> NSCollectionLayoutSection {
        let heightDimension = NSCollectionLayoutDimension.estimated(Settings.displayStyle.heightEstimated)
        let item = NSCollectionLayoutItem(layoutSize: NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(Settings.displayStyle.fractionalWidth),
            heightDimension: selfSizeingEnable ? heightDimension : .fractionalHeight(1)
        ))
        let hSpacing: CGFloat = Settings.displayStyle == .large ? 35 : 30
        item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: hSpacing, bottom: 0, trailing: hSpacing)
        let group = NSCollectionLayoutGroup.horizontal(
            layoutSize: NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1),
                heightDimension: selfSizeingEnable ? heightDimension : .fractionalWidth(Settings.displayStyle.fractionalHeight)
            ),
            subitem: item,
            count: Settings.displayStyle == .large ? 3 : 4
        )
        let vSpacing: CGFloat = Settings.displayStyle == .large ? 24 : 16
        group.edgeSpacing = NSCollectionLayoutEdgeSpacing(leading: .fixed(0), top: .fixed(vSpacing), trailing: .fixed(0), bottom: .fixed(vSpacing))
        return NSCollectionLayoutSection(group: group)
    }

    private func makeDataSource() -> UICollectionViewDiffableDataSource<Section, AnyDispplayData> {
        return UICollectionViewDiffableDataSource(collectionView: collectionView, cellProvider: makeCellRegistration().cellProvider)
    }

    private func makeCellRegistration() -> DisplayCellRegistration {
        DisplayCellRegistration { cell, indexPath, displayData in
            cell.setup(data: displayData.data)
            cell.onLongPress = {
                [weak self] in
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
}
