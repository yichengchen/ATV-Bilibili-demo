//
//  SearchResultViewController.swift
//  BilibiliLive
//
//  Created by whw on 2022/11/2.
//

import Combine
import UIKit

class SearchResultViewController: UIViewController {
    let collectionVC = FeedCollectionViewController()
    var lastKey = ""
    var page = 1

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionVC.show(in: self)
        collectionVC.didSelect = {
            [weak self] in
            self?.goDetail(with: $0 as! SearchResult.Result)
        }
        collectionVC.loadMore = {
            [weak self] in
            self?.loadMore()
        }
    }

    func loadMore() {
        page += 1
        WebRequest.requestSearchResult(key: lastKey, page: page) { [weak self] searchResult in
            self?.collectionVC.appendData(displayData: searchResult.result)
        }
    }

    func goDetail(with data: SearchResult.Result) {
        let detailVC = VideoDetailViewController.create(aid: data.aid, cid: 0)
        detailVC.present(from: self)
    }
}

extension SearchResultViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        if let text = searchController.searchBar.text, lastKey != text {
            lastKey = text
            page = 1
            WebRequest.requestSearchResult(key: lastKey, page: page) { [weak self] searchResult in
                self?.collectionVC.displayDatas = searchResult.result
            }
        }
    }
}
