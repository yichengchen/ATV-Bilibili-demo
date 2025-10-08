import Foundation
import SwiftyJSON

final class AccountManager {
    struct Profile: Codable, Equatable {
        let mid: Int
        var username: String
        var avatar: String
    }

    struct Account: Codable, Equatable {
        var token: LoginToken
        var profile: Profile
        var cookies: [StoredCookie]
        var lastActiveAt: Date
    }

    static let shared = AccountManager()
    static let didUpdateNotification = Notification.Name("AccountManagerDidUpdate")

    private let accountsKey = "app.multiple.accounts"
    private let activeKey = "app.multiple.accounts.active"
    private let storage = UserDefaults.standard

    private var storedAccounts: [Account] = []
    private var activeMID: Int?

    private init() {
        loadFromStorage()
    }

    // MARK: - Public

    var accounts: [Account] {
        storedAccounts.sorted(by: { $0.lastActiveAt > $1.lastActiveAt })
    }

    var activeAccount: Account? {
        guard let activeMID else { return nil }
        return storedAccounts.first(where: { $0.profile.mid == activeMID })
    }

    var isLoggedIn: Bool { activeAccount != nil }

    func bootstrap() {
        if activeAccount == nil, let first = storedAccounts.sorted(by: { $0.lastActiveAt > $1.lastActiveAt }).first {
            activeMID = first.profile.mid
            persistActiveMID()
        }
        applyActiveAccountCookies()
    }

    func registerAccount(token: LoginToken, cookies: [HTTPCookie], completion: @escaping (Account) -> Void) {
        let storedCookies = cookies.map(StoredCookie.init)
        fetchProfile { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                let profile: Profile
                switch result {
                case let .success(json):
                    profile = Profile(mid: json["mid"].intValue,
                                      username: json["uname"].stringValue,
                                      avatar: json["face"].stringValue)
                case .failure:
                    profile = Profile(mid: token.mid,
                                      username: "UID \(token.mid)",
                                      avatar: "")
                }
                var newAccount = Account(token: token,
                                         profile: profile,
                                         cookies: storedCookies,
                                         lastActiveAt: Date())
                self.upsert(account: newAccount)
                self.setActiveAccount(mid: newAccount.profile.mid, applyingCookies: false, notify: false)
                self.updateAccount(mid: newAccount.profile.mid) { account in
                    account.cookies = storedCookies
                    account.lastActiveAt = Date()
                    newAccount = account
                }
                self.applyActiveAccountCookies()
                self.persistAll()
                self.notifyChange()
                completion(newAccount)
            }
        }
    }

    func setActiveAccount(_ account: Account) {
        setActiveAccount(mid: account.profile.mid)
    }

    func setActiveAccount(mid: Int, applyingCookies: Bool = true, notify: Bool = true) {
        guard storedAccounts.contains(where: { $0.profile.mid == mid }) else { return }
        activeMID = mid
        persistActiveMID()
        updateAccount(mid: mid) { account in
            account.lastActiveAt = Date()
        }
        if applyingCookies {
            applyActiveAccountCookies()
        }
        persistAll()
        if notify {
            notifyChange()
        }
    }

    func updateActiveAccount(token: LoginToken, cookies: [HTTPCookie]? = nil) {
        guard let mid = activeAccount?.profile.mid else { return }
        updateAccount(mid: mid) { account in
            account.token = token
            account.lastActiveAt = Date()
            if let cookies {
                account.cookies = cookies.map(StoredCookie.init)
            }
        }
        persistAll()
        notifyChange()
    }

    func updateActiveProfile(username: String, avatar: String) {
        guard let mid = activeAccount?.profile.mid else { return }
        updateAccount(mid: mid) { account in
            account.profile.username = username
            account.profile.avatar = avatar
        }
        persistAll()
        notifyChange()
    }

    func refreshActiveAccountProfile() {
        fetchProfile { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case let .success(json):
                    self.updateActiveProfile(username: json["uname"].stringValue,
                                             avatar: json["face"].stringValue)
                case .failure:
                    break
                }
            }
        }
    }

    func syncActiveAccountCookies() {
        guard let mid = activeAccount?.profile.mid else { return }
        let cookies = CookieHandler.shared.currentStoredCookies()
        updateAccount(mid: mid) { account in
            account.cookies = cookies
        }
        persistAll()
    }

    @discardableResult
    func removeAccount(_ account: Account) -> Bool {
        storedAccounts.removeAll(where: { $0.profile.mid == account.profile.mid })
        persistAccounts()
        let removedActive = activeMID == account.profile.mid
        if removedActive {
            activeMID = nil
            persistActiveMID()
            if let next = storedAccounts.sorted(by: { $0.lastActiveAt > $1.lastActiveAt }).first {
                setActiveAccount(mid: next.profile.mid)
            } else {
                CookieHandler.shared.removeCookie()
                notifyChange()
            }
        } else {
            notifyChange()
        }
        return !storedAccounts.isEmpty
    }

    func removeAllAccounts() {
        storedAccounts.removeAll()
        persistAccounts()
        activeMID = nil
        persistActiveMID()
        CookieHandler.shared.removeCookie()
        notifyChange()
    }

    func handleAuthenticationFailure() {
        guard let account = activeAccount else { return }
        _ = removeAccount(account)
    }

    // MARK: - Private helpers

    private func fetchProfile(completion: @escaping (Result<JSON, RequestError>) -> Void) {
        WebRequest.requestLoginInfo(complete: completion)
    }

    private func applyActiveAccountCookies() {
        guard let cookies = activeAccount?.cookies else { return }
        CookieHandler.shared.replaceCookies(with: cookies)
    }

    private func loadFromStorage() {
        if let data = storage.data(forKey: accountsKey) {
            do {
                storedAccounts = try JSONDecoder().decode([Account].self, from: data)
            } catch {
                storedAccounts = []
            }
        }
        if storage.object(forKey: activeKey) != nil {
            let mid = storage.integer(forKey: activeKey)
            activeMID = storedAccounts.contains(where: { $0.profile.mid == mid }) ? mid : nil
        }
    }

    private func persistAll() {
        persistAccounts()
        persistActiveMID()
    }

    private func persistAccounts() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(storedAccounts) {
            storage.set(data, forKey: accountsKey)
        } else {
            storage.removeObject(forKey: accountsKey)
        }
    }

    private func persistActiveMID() {
        if let activeMID {
            storage.set(activeMID, forKey: activeKey)
        } else {
            storage.removeObject(forKey: activeKey)
        }
    }

    private func upsert(account: Account) {
        if let index = storedAccounts.firstIndex(where: { $0.profile.mid == account.profile.mid }) {
            storedAccounts[index] = account
        } else {
            storedAccounts.append(account)
        }
    }

    private func updateAccount(mid: Int, update: (inout Account) -> Void) {
        guard let index = storedAccounts.firstIndex(where: { $0.profile.mid == mid }) else { return }
        update(&storedAccounts[index])
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: AccountManager.didUpdateNotification, object: self)
    }
}
