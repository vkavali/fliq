import Foundation

struct PendingTipDraft: Codable, Identifiable {
    let id: String
    let providerId: String
    let providerName: String
    let providerCategory: String?
    let amountPaise: Int
    let source: TipSourceOption
    let intent: TipIntentOption
    let message: String?
    let rating: Int
    let idempotencyKey: String
    let createdAt: String
}

final class PendingTipQueueStore {
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func load(userId: String) -> [PendingTipDraft] {
        guard let data = defaults.data(forKey: key(for: userId)) else { return [] }
        return (try? decoder.decode([PendingTipDraft].self, from: data)) ?? []
    }

    func save(_ drafts: [PendingTipDraft], userId: String) {
        guard let data = try? encoder.encode(drafts) else { return }
        defaults.set(data, forKey: key(for: userId))
    }

    func enqueue(_ draft: PendingTipDraft, userId: String) {
        var drafts = load(userId: userId)
        drafts.insert(draft, at: 0)
        save(drafts, userId: userId)
    }

    func remove(draftId: String, userId: String) {
        let drafts = load(userId: userId).filter { $0.id != draftId }
        save(drafts, userId: userId)
    }

    func clear(userId: String) {
        defaults.removeObject(forKey: key(for: userId))
    }

    private func key(for userId: String) -> String {
        "fliq_native_ios_pending_tips_\(userId)"
    }
}
