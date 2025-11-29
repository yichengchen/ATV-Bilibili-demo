//
//  SegmentViewController.swift
//  BilibiliLive
//
//  Created by bitxeno on 2025/11/29.
//

import Foundation
import SnapKit
import UIKit

class SegmentViewController: UIViewController, BLTabBarContentVCProtocol {
    struct CategoryDisplayModel {
        let title: String
        let contentVC: UIViewController
        var autoSelect: Bool? = true
    }

    var segmentedControl: UISegmentedControl!
    var categories = [CategoryDisplayModel]()
    let contentView = UIView()
    weak var currentViewController: UIViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        if categories.isEmpty {
        } else {
            initSegmentedControl()
        }
    }

    func initSegmentedControl() {
        if segmentedControl != nil {
            return
        }

        let items = categories.map { $0.title }
        segmentedControl = UISegmentedControl(items: items)
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentChanged(_:)), for: .valueChanged)

        view.addSubview(segmentedControl)
        segmentedControl.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualToSuperview().inset(40)
        }

        let leftFocusGuide = UIFocusGuide()
        view.addLayoutGuide(leftFocusGuide)
        leftFocusGuide.snp.makeConstraints { make in
            make.top.bottom.equalTo(segmentedControl)
            make.right.equalTo(segmentedControl.snp.left)
            make.left.equalToSuperview()
        }
        leftFocusGuide.preferredFocusEnvironments = [segmentedControl]

        let rightFocusGuide = UIFocusGuide()
        view.addLayoutGuide(rightFocusGuide)
        rightFocusGuide.snp.makeConstraints { make in
            make.top.bottom.equalTo(segmentedControl)
            make.left.equalTo(segmentedControl.snp.right)
            make.right.equalToSuperview()
        }
        rightFocusGuide.preferredFocusEnvironments = [segmentedControl]

        view.addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(segmentedControl.snp.bottom)
            make.left.right.bottom.equalToSuperview()
        }

        // Load initial view controller
        if !categories.isEmpty {
            setViewController(vc: categories[0].contentVC)
        }
    }

    @objc func segmentChanged(_ sender: UISegmentedControl) {
        let index = sender.selectedSegmentIndex
        if index >= 0 && index < categories.count {
            setViewController(vc: categories[index].contentVC)
        }
    }

    func setViewController(vc: UIViewController) {
        currentViewController?.willMove(toParent: nil)
        currentViewController?.view.removeFromSuperview()
        currentViewController?.removeFromParent()
        currentViewController = vc
        addChild(vc)
        contentView.addSubview(vc.view)
        vc.view.makeConstraintsToBindToSuperview()
        vc.didMove(toParent: self)
    }

    func reloadData() {
        (currentViewController as? BLTabBarContentVCProtocol)?.reloadData()
    }
}
