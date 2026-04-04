//
//  TabBarCustomizationViewController.swift
//  BilibiliLive
//

import SnapKit
import UIKit

class TabBarCustomizationViewController: UIViewController {
    // MARK: - State

    /// The page currently being reordered. `nil` means browse mode.
    private var editingPage: TabBarPage?
    private var pendingFocusIndexPath: IndexPath?
    private var focusedIndexPath: IndexPath?

    private var tabbarPlacements = [Settings.TabBarPagePlacement]()
    private var minePlacements = [Settings.TabBarPagePlacement]()

    private var originalPlacements = [Settings.TabBarPagePlacement]()

    override var preferredFocusEnvironments: [any UIFocusEnvironment] {
        return [collectionView]
    }

    // MARK: - Views

    private let hintLabel: UILabel = {
        let label = UILabel()
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = UIColor.white
        return label
    }()

    private let restoreDefaultButton: BLCustomTextButton = {
        let button = BLCustomTextButton()
        button.title = "恢复默认"
        button.titleFont = .systemFont(ofSize: 30, weight: .semibold)
        button.titleColor = UIColor.white
        return button
    }()

    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        cv.remembersLastFocusedIndexPath = false
        cv.dataSource = self
        cv.delegate = self
        cv.clipsToBounds = false
        cv.register(TabBarTileCell.self, forCellWithReuseIdentifier: TabBarTileCell.reuseID)
        cv.register(TabBarSectionHeaderView.self,
                    forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
                    withReuseIdentifier: TabBarSectionHeaderView.reuseID)
        return cv
    }()

    // MARK: - Layout

    private func makeLayout() -> UICollectionViewCompositionalLayout {
        UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            self?.makeSection(environment: environment)
        }
    }

    private func makeSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(widthDimension: .absolute(200),
                                              heightDimension: .absolute(120))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(widthDimension: .estimated(200),
                                               heightDimension: .absolute(120))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.orthogonalScrollingBehavior = .continuous
        section.interGroupSpacing = 30
        section.contentInsets = NSDirectionalEdgeInsets(top: 20, leading: 0, bottom: 30, trailing: 40)

        let headerSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0),
                                                heightDimension: .absolute(50))
        let header = NSCollectionLayoutBoundarySupplementaryItem(layoutSize: headerSize,
                                                                 elementKind: UICollectionView.elementKindSectionHeader,
                                                                 alignment: .top)
        section.boundarySupplementaryItems = [header]
        return section
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "选中项目后按播放键开始排序"
        view.backgroundColor = .black

        setupUI()
        reloadPlacementsFromSettings()
        updateHintLabel()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if editingPage != nil { stopEditing() }
    }

    // MARK: - Press handling

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let press = presses.first else {
            super.pressesEnded(presses, with: event)
            return
        }

        switch press.type {
        case .playPause, .select:
            editingPage != nil ? stopEditing() : startEditing()
        default:
            super.pressesEnded(presses, with: event)
        }
    }

    // MARK: - Editing

    private func startEditing() {
        guard let ip = focusedIndexPath,
              let p = placement(at: ip)
        else { return }
        editingPage = p.page
        updateHintLabel()
        collectionView.reconfigureItems(at: collectionView.indexPathsForVisibleItems)
    }

    private func stopEditing() {
        editingPage = nil
        updateHintLabel()
        commitIfNeeded()
        collectionView.reconfigureItems(at: collectionView.indexPathsForVisibleItems)
    }

    // MARK: - Move

    private func moveEditingItem(from: IndexPath, to: IndexPath) -> Bool {
        guard var editItem = placement(at: from) else { return false }

        let tabBarCount = tabbarPlacements.count

        let fromSection = pageSection(for: from)
        let toSection = pageSection(for: to)

        if toSection == fromSection {
            // 同一层
            switch fromSection {
            case .tabBar:
                tabbarPlacements.swapAt(from.item, to.item)
            case .personal:
                minePlacements.swapAt(from.item, to.item)
            }
            return true
        }

        // 不同层
        editItem.section = toSection
        switch toSection {
        case .tabBar:
            if tabBarCount >= Settings.maxTabBarPageCount {
                let alert = UIAlertController(title: "导航栏最多保留 \(Settings.maxTabBarPageCount) 个页面", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "知道了", style: .cancel))
                present(alert, animated: true)
                return false
            }
            minePlacements.remove(at: from.item)
            tabbarPlacements.insert(editItem, at: to.item)
            print(minePlacements)
            print(tabbarPlacements)
        case .personal:
            if editItem.page.isFixedInTabBar {
                let alert = UIAlertController(title: "该项目只允许在导航栏展示", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "知道了", style: .cancel))
                present(alert, animated: true)
                return false
            }
            if tabBarCount <= Settings.minTabBarPageCount {
                let alert = UIAlertController(title: "导航栏至少保留 \(Settings.minTabBarPageCount) 个页面", message: nil, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "知道了", style: .cancel))
                present(alert, animated: true)
                return false
            }
            tabbarPlacements.remove(at: from.item)
            minePlacements.insert(editItem, at: to.item)
        }
        return true
    }

    // MARK: - UI helpers

    private func setupUI() {
        view.addSubview(hintLabel)
        view.addSubview(restoreDefaultButton)
        view.addSubview(collectionView)
        restoreDefaultButton.addTarget(self, action: #selector(didTapRestoreDefault), for: .primaryActionTriggered)

        hintLabel.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(12)
            make.leading.equalToSuperview().offset(80)
            make.trailing.lessThanOrEqualTo(restoreDefaultButton.snp.leading).offset(-24)
        }

        let focusGuide = UIFocusGuide()
        view.addLayoutGuide(focusGuide)
        NSLayoutConstraint.activate([
            focusGuide.topAnchor.constraint(equalTo: view.topAnchor),
            focusGuide.leftAnchor.constraint(equalTo: view.leftAnchor),
            focusGuide.rightAnchor.constraint(equalTo: view.rightAnchor),
            focusGuide.bottomAnchor.constraint(equalTo: collectionView.topAnchor),
        ])
        focusGuide.preferredFocusEnvironments = [restoreDefaultButton]

        restoreDefaultButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(4)
            make.trailing.equalToSuperview().offset(-80)
            make.height.equalTo(72)
        }

        collectionView.snp.makeConstraints { make in
            make.top.equalTo(hintLabel.snp.bottom).offset(12)
            make.top.greaterThanOrEqualTo(restoreDefaultButton.snp.bottom).offset(12)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
            make.leading.equalToSuperview().offset(80)
            make.trailing.equalToSuperview().offset(-80)
        }
    }

    private func updateHintLabel() {
        hintLabel.text = editingPage != nil
            ? "排序中：左右移动排序，上下跨区移动；按确认键或播放键完成"
            : "选中项目后按播放键开始排序"
    }

    private func commitIfNeeded() {
        let newPlacement = tabbarPlacements + minePlacements
        if newPlacement != originalPlacements {
            Settings.setPlacements(newPlacement)
            originalPlacements = newPlacement
        }
    }

    private func reloadPlacementsFromSettings() {
        let placements = Settings.currentPlacements
        tabbarPlacements = placements.filter { $0.section == .tabBar }
        minePlacements = placements.filter { $0.section == .personal }
        originalPlacements = tabbarPlacements + minePlacements
        collectionView.reloadData()
    }

    @objc
    private func didTapRestoreDefault() {
        if editingPage != nil {
            stopEditing()
        }
        let placements = Settings.defaultPlacements
        tabbarPlacements = placements.filter { $0.section == .tabBar }
        minePlacements = placements.filter { $0.section == .personal }
        updateHintLabel()
        collectionView.reloadData()
        commitIfNeeded()
    }

    // MARK: - Data helpers

    private func pageSection(for indexpath: IndexPath) -> Settings.TabBarPageSection {
        return indexpath.section == 0 ? .tabBar : .personal
    }

    private func placement(at indexPath: IndexPath) -> Settings.TabBarPagePlacement? {
        switch pageSection(for: indexPath) {
        case .tabBar:
            return tabbarPlacements[indexPath.item]
        case .personal:
            return minePlacements[indexPath.item]
        }
    }
}

// MARK: - UICollectionViewDataSource

extension TabBarCustomizationViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        2
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        let modelSection: Settings.TabBarPageSection = section == 0 ? .tabBar : .personal

        switch modelSection {
        case .tabBar:
            return tabbarPlacements.count
        case .personal:
            return minePlacements.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: TabBarTileCell.reuseID, for: indexPath) as! TabBarTileCell
        if let placement = placement(at: indexPath) {
            let page = placement.page
            cell.configure(title: page.title,
                           isBeingEdited: page == editingPage)
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView,
                        viewForSupplementaryElementOfKind kind: String,
                        at indexPath: IndexPath) -> UICollectionReusableView
    {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }
        let view = collectionView.dequeueReusableSupplementaryView(ofKind: kind,
                                                                   withReuseIdentifier: TabBarSectionHeaderView.reuseID,
                                                                   for: indexPath) as! TabBarSectionHeaderView
        let section: Settings.TabBarPageSection = indexPath.section == 0 ? .tabBar : .personal
        view.label.text = section.title
        return view
    }
}

// MARK: - UICollectionViewDelegate

extension TabBarCustomizationViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView,
                        shouldUpdateFocusIn context: UICollectionViewFocusUpdateContext) -> Bool
    {
        guard editingPage != nil else { return true }

        // For swipe gestures that bypass pressesBegan, derive direction and trigger move.
        if let from = context.previouslyFocusedIndexPath,
           let to = context.nextFocusedIndexPath
        {
            if pendingFocusIndexPath == from {
                return false
            }
            pendingFocusIndexPath = to

            if moveEditingItem(from: from, to: to) == false {
                return false
            }
            collectionView.performBatchUpdates {
                collectionView.moveItem(at: from, to: to)

            } completion: { [weak self] _ in
                self?.pendingFocusIndexPath = nil
            }
        }
        return false
    }

    func collectionView(_ collectionView: UICollectionView,
                        didUpdateFocusIn context: UICollectionViewFocusUpdateContext,
                        with coordinator: UIFocusAnimationCoordinator)
    {
        focusedIndexPath = context.nextFocusedIndexPath
        if focusedIndexPath == pendingFocusIndexPath {
            pendingFocusIndexPath = nil
        }
    }
}

// MARK: - Tile Cell

class TabBarTileCell: BLMotionCollectionViewCell {
    static let reuseID = String(describing: TabBarTileCell.self)
    private var isBeingEdited = false

    private let titleLabel: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 28, weight: .medium)
        l.textAlignment = .center
        l.numberOfLines = 2
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.7
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, isBeingEdited: Bool) {
        titleLabel.text = title
        self.isBeingEdited = isBeingEdited
        setShaking(isBeingEdited)
        updateAppearance()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.layer.removeAnimation(forKey: "shake")
        transform = .identity
        isBeingEdited = false
    }

    // MARK: - Private

    private func setShaking(_ shaking: Bool) {
        if shaking {
            guard contentView.layer.animation(forKey: "shake") == nil else { return }
            let anim = CAKeyframeAnimation(keyPath: "transform.rotation.z")
            anim.values = [-0.015, 0.015, -0.015]
            anim.duration = 0.22
            anim.repeatCount = .infinity
            contentView.layer.add(anim, forKey: "shake")
        } else {
            contentView.layer.removeAnimation(forKey: "shake")
        }
    }

    private func setupView() {
        contentView.layer.cornerRadius = 16
        contentView.layer.cornerCurve = .continuous
        contentView.clipsToBounds = true

        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 8)
        layer.shadowRadius = 12
        layer.shadowOpacity = 0

        contentView.addSubview(titleLabel)

        titleLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(12)
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }
        updateAppearance()
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        coordinator.addCoordinatedAnimations {
            self.updateAppearance()
        }
    }

    private func updateAppearance() {
        if isFocused {
            contentView.backgroundColor = .white
            titleLabel.textColor = .black
            layer.shadowOpacity = 0.3
        } else {
            contentView.backgroundColor = UIColor(white: 0.15, alpha: 1)
            titleLabel.textColor = .white
            layer.shadowOpacity = 0
        }
    }
}

// MARK: - Section Header

class TabBarSectionHeaderView: UICollectionReusableView {
    static let reuseID = String(describing: TabBarSectionHeaderView.self)

    let label: UILabel = {
        let l = UILabel()
        l.font = .systemFont(ofSize: 30, weight: .bold)
        l.textColor = .white
        return l
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(label)
        label.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.bottom.equalToSuperview().offset(-4)
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
