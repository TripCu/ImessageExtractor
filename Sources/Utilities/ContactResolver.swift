import Contacts
import Foundation

@MainActor
final class ContactResolver: ObservableObject {
    private var cache: [String: String] = [:]
    private var phoneIndex: [String: String] = [:]
    private var didBuildIndex = false
    private let store = CNContactStore()

    func status() -> CNAuthorizationStatus { CNContactStore.authorizationStatus(for: .contacts) }

    func requestIfNeeded() async -> Bool {
        if status() == .authorized { return true }
        return await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func resolve(handle: String) -> String {
        if let cached = cache[handle] { return cached }
        guard status() == .authorized else { return handle }

        buildIndexIfNeeded()
        let normalized = normalize(handle)
        let suffix8 = String(normalized.suffix(8))

        if let direct = phoneIndex[normalized] {
            cache[handle] = direct
        } else if let suffix = phoneIndex.first(where: { $0.key.hasSuffix(suffix8) })?.value {
            cache[handle] = suffix
        } else {
            cache[handle] = handle
        }
        return cache[handle] ?? handle
    }

    private func buildIndexIfNeeded() {
        guard !didBuildIndex else { return }
        didBuildIndex = true

        let keys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey
        ] as [CNKeyDescriptor]

        let request = CNContactFetchRequest(keysToFetch: keys)
        try? store.enumerateContacts(with: request) { contact, _ in
            let displayName = CNContactFormatter.string(from: contact, style: .fullName) ?? ""
            guard !displayName.isEmpty else { return }
            for number in contact.phoneNumbers {
                let digits = normalize(number.value.stringValue)
                if !digits.isEmpty {
                    phoneIndex[digits] = displayName
                }
            }
        }
    }

    private func normalize(_ value: String) -> String {
        value.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
    }
}
