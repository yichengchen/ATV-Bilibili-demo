import Kingfisher
import UIKit

final class AccountSwitcherViewController: UIViewController {
    private enum Section: Int, CaseIterable {
        case accounts
        case actions
    }

    private let containerView = UIVisualEffectView(effect: UIBlurEffect(style: .dark))
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 40
        layout.minimumInteritemSpacing = 30
        layout.sectionInset = UIEdgeInsets(top: 40, left: 60, bottom: 40, right: 60)
        layout.itemSize = CGSize(width: 300, height: 320)
        let collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collection.backgroundColor = .clear
        collection.remembersLastFocusedIndexPath = true
        collection.register(AccountSwitcherCell.self, forCellWithReuseIdentifier: AccountSwitcherCell.reuseIdentifier)
        collection.register(AccountSwitcherAddCell.self, forCellWithReuseIdentifier: AccountSwitcherAddCell.reuseIdentifier)
        collection.dataSource = self
        collection.delegate = self
        return collection
    }()

    private var accounts: [AccountManager.Account] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        setupContainer()
        setupHeader()
        setupCollectionView()
        reloadData()
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleAccountUpdate),
                                               name: AccountManager.didUpdateNotification,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        return [collectionView]
    }

    private func setupContainer() {
        containerView.clipsToBounds = true
        containerView.layer.cornerRadius = 36
        containerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            containerView.widthAnchor.constraint(equalToConstant: 1100),
            containerView.heightAnchor.constraint(equalToConstant: 720),
        ])
    }

    private func setupHeader() {
        let contentView = containerView.contentView
        titleLabel.text = "账号管理"
        titleLabel.font = UIFont.systemFont(ofSize: 48, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = "快速切换登录账号或添加新的账号"
        subtitleLabel.font = UIFont.systemFont(ofSize: 26, weight: .regular)
        subtitleLabel.textColor = UIColor.white.withAlphaComponent(0.8)
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        closeButton.setTitle("关闭", for: .normal)
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 30, weight: .medium)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .primaryActionTriggered)

        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        contentView.addSubview(closeButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 60),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 50),

            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),

            closeButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -60),
            closeButton.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
        ])
    }

    private func setupCollectionView() {
        let contentView = containerView.contentView
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            collectionView.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 30),
        ])
    }

    private func reloadData() {
        accounts = AccountManager.shared.accounts
        collectionView.reloadData()
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    @objc private func handleAccountUpdate() {
        reloadData()
    }

    private func presentLogin() {
        dismiss(animated: true) {
            AppDelegate.shared.showLogin()
        }
    }

    private func switchToAccount(_ account: AccountManager.Account) {
        let currentMID = AccountManager.shared.activeAccount?.profile.mid
        AccountManager.shared.setActiveAccount(account)
        dismiss(animated: true) {
            if currentMID == account.profile.mid {
                AccountManager.shared.refreshActiveAccountProfile()
            } else {
                AppDelegate.shared.resetTabBar()
            }
        }
    }
}

extension AccountSwitcherViewController: UICollectionViewDataSource {
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        Section.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let section = Section(rawValue: section) else { return 0 }
        switch section {
        case .accounts:
            return accounts.count
        case .actions:
            return 1
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let section = Section(rawValue: indexPath.section) else { return UICollectionViewCell() }
        switch section {
        case .accounts:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AccountSwitcherCell.reuseIdentifier, for: indexPath) as! AccountSwitcherCell
            let account = accounts[indexPath.item]
            cell.configure(with: account, active: account.profile.mid == AccountManager.shared.activeAccount?.profile.mid)
            return cell
        case .actions:
            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AccountSwitcherAddCell.reuseIdentifier, for: indexPath) as! AccountSwitcherAddCell
            return cell
        }
    }
}

extension AccountSwitcherViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let section = Section(rawValue: indexPath.section) else { return }
        switch section {
        case .accounts:
            let account = accounts[indexPath.item]
            guard account.profile.mid != AccountManager.shared.activeAccount?.profile.mid else { return }
            switchToAccount(account)
        case .actions:
            presentLogin()
        }
    }
}

private final class AccountSwitcherCell: UICollectionViewCell {
    static let reuseIdentifier = "AccountSwitcherCell"

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let badgeLabel = UILabel()
    private let background = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.image = nil
        badgeLabel.isHidden = true
        avatarView.backgroundColor = .clear
        avatarView.tintColor = nil
        background.layer.borderWidth = 0
        background.transform = .identity
    }

    private func configure() {
        contentView.clipsToBounds = false
        background.translatesAutoresizingMaskIntoConstraints = false
        background.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        background.layer.cornerRadius = 28
        background.layer.borderWidth = 0
        contentView.addSubview(background)

        avatarView.translatesAutoresizingMaskIntoConstraints = false
        avatarView.contentMode = .scaleAspectFill
        avatarView.layer.cornerRadius = 80
        avatarView.clipsToBounds = true

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.font = UIFont.systemFont(ofSize: 30, weight: .medium)
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.numberOfLines = 2

        badgeLabel.translatesAutoresizingMaskIntoConstraints = false
        badgeLabel.text = "当前使用"
        badgeLabel.font = UIFont.systemFont(ofSize: 22, weight: .semibold)
        badgeLabel.textColor = .white
        badgeLabel.backgroundColor = UIColor.systemBlue
        badgeLabel.layer.cornerRadius = 16
        badgeLabel.clipsToBounds = true
        badgeLabel.textAlignment = .center
        badgeLabel.isHidden = true

        background.addSubview(avatarView)
        background.addSubview(nameLabel)
        background.addSubview(badgeLabel)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            background.topAnchor.constraint(equalTo: contentView.topAnchor),
            background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            avatarView.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            avatarView.topAnchor.constraint(equalTo: background.topAnchor, constant: 36),
            avatarView.widthAnchor.constraint(equalToConstant: 160),
            avatarView.heightAnchor.constraint(equalTo: avatarView.widthAnchor),

            nameLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 24),
            nameLabel.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
            nameLabel.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),

            badgeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 16),
            badgeLabel.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            badgeLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 140),
            badgeLabel.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        let isFocused = (context.nextFocusedView == self)
        coordinator.addCoordinatedAnimations {
            self.background.layer.borderWidth = isFocused ? 4 : 0
            self.background.layer.borderColor = isFocused ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
            self.background.transform = isFocused ? CGAffineTransform(scaleX: 1.06, y: 1.06) : .identity
        }
    }

    func configure(with account: AccountManager.Account, active: Bool) {
        nameLabel.text = account.profile.username
        if let url = URL(string: account.profile.avatar), !account.profile.avatar.isEmpty {
            avatarView.kf.setImage(with: url)
        } else {
            avatarView.image = UIImage(systemName: "person.crop.circle.fill")
            avatarView.tintColor = UIColor.white.withAlphaComponent(0.8)
            avatarView.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        }
        badgeLabel.isHidden = !active
    }
}

private final class AccountSwitcherAddCell: UICollectionViewCell {
    static let reuseIdentifier = "AccountSwitcherAddCell"

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let background = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        background.layer.borderWidth = 0
        background.transform = .identity
    }

    private func configure() {
        contentView.clipsToBounds = false
        background.translatesAutoresizingMaskIntoConstraints = false
        background.backgroundColor = UIColor.white.withAlphaComponent(0.08)
        background.layer.cornerRadius = 28
        contentView.addSubview(background)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentMode = .scaleAspectFit
        iconView.image = UIImage(systemName: "plus.circle.fill")
        iconView.tintColor = .systemBlue

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.text = "添加账号"
        titleLabel.font = UIFont.systemFont(ofSize: 30, weight: .medium)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center

        background.addSubview(iconView)
        background.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            background.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            background.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            background.topAnchor.constraint(equalTo: contentView.topAnchor),
            background.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            iconView.topAnchor.constraint(equalTo: background.topAnchor, constant: 80),
            iconView.centerXAnchor.constraint(equalTo: background.centerXAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 120),
            iconView.heightAnchor.constraint(equalTo: iconView.widthAnchor),

            titleLabel.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
        ])
    }

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)
        let isFocused = (context.nextFocusedView == self)
        coordinator.addCoordinatedAnimations {
            self.background.layer.borderWidth = isFocused ? 4 : 0
            self.background.layer.borderColor = isFocused ? UIColor.systemBlue.cgColor : UIColor.clear.cgColor
            self.background.transform = isFocused ? CGAffineTransform(scaleX: 1.06, y: 1.06) : .identity
        }
    }
}
