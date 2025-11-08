@testable import LanePulse_Coach

final class WidgetRefresherMock: WidgetRefreshing {
    private(set) var reloadAllCallCount = 0
    private(set) var reloadKindCallCount = 0
    private(set) var reloadedKinds: [String] = []

    func reloadAll() {
        reloadAllCallCount += 1
    }

    func reload(kind: String) {
        reloadKindCallCount += 1
        reloadedKinds.append(kind)
    }
}
