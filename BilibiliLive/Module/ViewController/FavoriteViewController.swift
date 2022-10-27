//
//  FavoriteViewController.swift
//  BilibiliLive
//
//  Created by whw on 2022/10/18.
//

import SnapKit
import SwiftyJSON
import UIKit

class FavoriteViewController: UIViewController {
    var collectionView: UICollectionView!
    var dataSource: UICollectionViewDiffableDataSource<FavListData, FavData>!
    var currentSnapshot: NSDiffableDataSourceSnapshot<FavListData, FavData>!
    static let titleElementKind = "titleElementKind"

    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        collectionView.delegate = self
        collectionView.remembersLastFocusedIndexPath = true
        tabBarObservedScrollView = collectionView
        view.addSubview(collectionView)
        collectionView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        configureDataSource()
        reloadData()
    }

    @MainActor func applyData(for list: FavListData, content: [FavData]) {
        currentSnapshot.appendItems(content, toSection: list)
        dataSource.apply(currentSnapshot)
    }
}

extension FavoriteViewController: BLTabBarContentVCProtocol {
    func reloadData() {
        Task {
            guard let favList = try? await WebRequest.requestFavVideosList() else {
                return
            }
            currentSnapshot.deleteAllItems()
            currentSnapshot.appendSections(favList)
            favList.forEach { list in
                Task {
                    if let content = try? await WebRequest.requestFavVideos(mid: String(list.id)) {
                        applyData(for: list, content: content)
                    }
                }
            }
        }
    }
}

extension FavoriteViewController {
    private func createLayout() -> UICollectionViewLayout {
        let sectionProvider = {
            (sectionIndex: Int, layoutEnvironment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection? in
            let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                  heightDimension: .fractionalHeight(1))

            let item = NSCollectionLayoutItem(layoutSize: itemSize)
            let hSpacing: CGFloat = Settings.displayStyle == .large ? 35 : 30
            item.contentInsets = NSDirectionalEdgeInsets(top: 0, leading: hSpacing, bottom: 0, trailing: hSpacing)

            let groupFractionalWidth = Settings.displayStyle.fractionalWidth
            let groupFractionalHeight = Settings.displayStyle == .large ? 0.26 : 0.2

            let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(groupFractionalWidth),
                                                   heightDimension: .fractionalWidth(groupFractionalHeight))
            let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
            group.edgeSpacing = .init(leading: .fixed(0), top: .fixed(40), trailing: .fixed(0), bottom: .fixed(10))
            let section = NSCollectionLayoutSection(group: group)
            section.orthogonalScrollingBehavior = .continuous

            let titleSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                   heightDimension: .estimated(44))
            let titleSupplementary = NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: titleSize,
                elementKind: FavoriteViewController.titleElementKind,
                alignment: .top
            )
            section.boundarySupplementaryItems = [titleSupplementary]
            return section
        }

        let config = UICollectionViewCompositionalLayoutConfiguration()
        config.interSectionSpacing = 0

        let layout = UICollectionViewCompositionalLayout(
            sectionProvider: sectionProvider, configuration: config
        )
        return layout
    }

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<FeedCollectionViewCell, FavData> {
            $0.setup(data: $2)
        }
        dataSource = UICollectionViewDiffableDataSource<FavListData, FavData>(collectionView: collectionView, cellProvider: cellRegistration.cellProvider)

        let supplementaryRegistration = UICollectionView.SupplementaryRegistration<TitleSupplementaryView>(elementKind: FavoriteViewController.titleElementKind) {
            supplementaryView, string, indexPath in
            if let snapshot = self.currentSnapshot {
                let videoCategory = snapshot.sectionIdentifiers[indexPath.section]
                supplementaryView.label.text = videoCategory.title
            }
        }

        dataSource.supplementaryViewProvider = { view, kind, index in
            return self.collectionView.dequeueConfiguredReusableSupplementary(
                using: supplementaryRegistration, for: index
            )
        }

        currentSnapshot = NSDiffableDataSourceSnapshot<FavListData, FavData>()
    }
}

extension FavoriteViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let d = dataSource.itemIdentifier(for: indexPath) else { return }
        let vc = VideoDetailViewController.create(aid: d.id, cid: 0)
        vc.present(from: UIViewController.topMostViewController())
    }

    func indexPathForPreferredFocusedView(in collectionView: UICollectionView) -> IndexPath? {
        return IndexPath(item: 0, section: 0)
    }
}
