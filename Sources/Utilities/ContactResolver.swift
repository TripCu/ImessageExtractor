import Contacts
import Foundation

@MainActor
final class ContactResolver: ObservableObject {
    private var cache: [String: String] = [:]
    private var phoneIndex: [String: String] = [:]
    private var didBuildIndex = false
    private var isBuildingIndex = false

    func status() -> CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    func requestIfNeeded() async -> Bool {
        if status() == .authorized { return true }
        let store = CNContactStore()
        return await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func prepareIndexIfNeeded() async {
        guard status() == .authorized else { return }
        guard !didBuildIndex, !isBuildingIndex else { return }

        isBuildingIndex = true
        defer { isBuildingIndex = false }

        do {
            let index = try await Self.buildPhoneIndex()
            phoneIndex = index
            didBuildIndex = true
            AppLogger.info("Contacts", "Contact index prepared")
        } catch {
            didBuildIndex = false
            AppLogger.error("Contacts", "Failed preparing contact index")
        }
    }

    func resolve(handle: String) -> String {
        if let cached = cache[handle] { return cached }
        guard status() == .authorized, didBuildIndex else { return handle }

        let normalized = Self.normalize(handle)
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

    nonisolated private static func buildPhoneIndex() async throws -> [String: String] {
        try await Task.detached(priority: .userInitiated) {
            let store = CNContactStore()
            let keys: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactMiddleNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactNicknameKey as CNKeyDescriptor,
                CNContactOrganizationNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)

            var index: [String: String] = [:]
            try store.enumerateContacts(with: request) { contact, _ in
                let displayName = displayName(contact)
                guard !displayName.isEmpty else { return }

                for number in contact.phoneNumbers {
                    let digits = normalize(number.value.stringValue)
                    if !digits.isEmpty {
                        index[digits] = displayName
                    }
                }
            }
            return index
        }.value
    }

    nonisolated private static func normalize(_ value: String) -> String {
        value.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
    }

    nonisolated private static func displayName(_ contact: CNContact) -> String {
        let parts = [contact.givenName, contact.middleName, contact.familyName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !parts.isEmpty {
            return parts.joined(separator: " ")
        }

        let nickname = contact.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nickname.isEmpty { return nickname }

        return contact.organizationName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
