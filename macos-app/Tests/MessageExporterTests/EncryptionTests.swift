import Foundation
import Testing
@testable import MessageExporterApp

@Test func encryptionRoundTrip() throws {
    let data = Data("secret".utf8)
    let encrypted = try EncryptedPackage.encrypt(plaintext: data, passphrase: "pass123")
    let decrypted = try EncryptedPackage.decrypt(package: encrypted, passphrase: "pass123")
    #expect(decrypted == data)
}

@Test func encryptionTamperDetection() throws {
    let data = Data("secret".utf8)
    var encrypted = try EncryptedPackage.encrypt(plaintext: data, passphrase: "pass123")
    encrypted[encrypted.count - 1] ^= 0x01
    #expect(throws: (any Error).self) {
        _ = try EncryptedPackage.decrypt(package: encrypted, passphrase: "pass123")
    }
}
