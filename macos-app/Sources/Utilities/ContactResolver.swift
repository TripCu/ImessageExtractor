import Contacts
import Foundation

@MainActor
final class ContactResolver: ObservableObject {
    private var cache: [String: String] = [:]
    private let store = CNContactStore()

    func status() -> CNAuthorizationStatus { CNContactStore.authorizationStatus(for: .contacts) }

    func requestIfNeeded() async -> Bool {
        if status() == .authorized { return true }
        return await withCheckedContinuation { continuation in
            store.requestAccess(for: .contacts) { granted, _ in continuation.resume(returning: granted) }
        }
    }

    func resolve(handle: String) -> String {
        if let cached = cache[handle] { return cached }
        guard status() == .authorized else { return handle }
        let normalized = handle.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        let keys = [CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey] as [CNKeyDescriptor]
        let request = CNContactFetchRequest(keysToFetch: keys)
        var name: String?
        try? store.enumerateContacts(with: request) { contact, stop in
            for number in contact.phoneNumbers {
                let digits = number.value.stringValue.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
                if digits.hasSuffix(normalized.suffix(8)) {
                    name = CNContactFormatter.string(from: contact, style: .fullName)
                    stop.pointee = true
                    break
                }
            }
        }
        cache[handle] = name ?? handle
        return cache[handle] ?? handle
    }
}
