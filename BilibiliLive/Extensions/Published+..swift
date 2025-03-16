//
//  Published+..swift
//  BilibiliLive
//
//  Created by yicheng on 2024/6/10.
//

import Combine
import Foundation

fileprivate var cancellables = [String: AnyCancellable]()

public extension Published {
    init(wrappedValue defaultValue: Value, key: String) {
        let value = UserDefaults.standard.object(forKey: key) as? Value ?? defaultValue
        self.init(initialValue: value)
        cancellables[key] = projectedValue.sink { val in
            UserDefaults.standard.set(val, forKey: key)
        }
    }
}
