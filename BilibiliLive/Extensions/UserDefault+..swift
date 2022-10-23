//
//  UserDefault+..swift
//  BilibiliLive
//
//  Created by yicheng on 2022/10/19.
//

import Foundation

@propertyWrapper
struct UserDefault<T> {
    private let key: String
    private let defaultValue: T
    private let userDefaults: UserDefaults

    init(_ key: String, defaultValue: T, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }

    var wrappedValue: T {
        get {
            guard let value = userDefaults.object(forKey: key) else {
                return defaultValue
            }

            return value as? T ?? defaultValue
        }
        set {
            if let value = newValue as? OptionalProtocol, value.isNil() {
                userDefaults.removeObject(forKey: key)
            } else {
                userDefaults.set(newValue, forKey: key)
            }
        }
    }
}

@propertyWrapper
struct UserDefaultCodable<T: Codable> {
    private let key: String
    private let defaultValue: T
    private let userDefaults: UserDefaults

    init(_ key: String, defaultValue: T, userDefaults: UserDefaults = .standard) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }

    var wrappedValue: T {
        get {
            guard let value: T? = userDefaults.codable(forKey: key) else {
                return defaultValue
            }

            return value ?? defaultValue
        }
        set {
            if let value = newValue as? OptionalProtocol, value.isNil() {
                userDefaults.removeObject(forKey: key)
            } else {
                userDefaults.set(codable: newValue, forKey: key)
            }
        }
    }
}

private protocol OptionalProtocol {
    func isNil() -> Bool
}

extension Optional: OptionalProtocol {
    func isNil() -> Bool {
        return self == nil
    }
}

extension UserDefaults {
    func set<Element: Codable>(codable: Element, forKey key: String) {
        let data = try? JSONEncoder().encode(codable)
        UserDefaults.standard.setValue(data, forKey: key)
    }

    func codable<Element: Codable>(forKey key: String) -> Element? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        let element = try? JSONDecoder().decode(Element.self, from: data)
        return element
    }
}
