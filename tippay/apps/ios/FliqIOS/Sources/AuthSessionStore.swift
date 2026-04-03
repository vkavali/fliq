import Foundation

final class AuthSessionStore {
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let key = "fliq_native_ios_session"

    func save(_ session: AuthSession) {
        guard let data = try? encoder.encode(session) else { return }
        defaults.set(data, forKey: key)
    }

    func load() -> AuthSession? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(AuthSession.self, from: data)
    }

    func clear() {
        defaults.removeObject(forKey: key)
    }
}
