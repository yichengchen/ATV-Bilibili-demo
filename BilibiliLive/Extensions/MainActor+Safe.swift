// https://onevcat.com/2024/07/swift-6/
extension MainActor {
    static func callSafely(_ block: @escaping @MainActor () -> Void) {
        if Thread.isMainThread {
            return MainActor.assumeIsolated { block() }
        } else {
            return DispatchQueue.main.async {
                MainActor.assumeIsolated { block() }
            }
        }
    }
}
