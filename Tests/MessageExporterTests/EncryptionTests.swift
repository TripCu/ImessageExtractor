import Foundation
import XCTest
@testable import MessageExporterApp

final class EncryptionTests: XCTestCase {
    func testEncryptionRoundTrip() throws {
        let data = Data("secret".utf8)
        let encrypted = try EncryptedPackage.encrypt(plaintext: data, passphrase: "pass123")
        let decrypted = try EncryptedPackage.decrypt(package: encrypted, passphrase: "pass123")
        XCTAssertEqual(decrypted, data)
    }

    func testEncryptionTamperDetection() throws {
        let data = Data("secret".utf8)
        var encrypted = try EncryptedPackage.encrypt(plaintext: data, passphrase: "pass123")
        encrypted[encrypted.count - 1] ^= 0x01
        XCTAssertThrowsError(try EncryptedPackage.decrypt(package: encrypted, passphrase: "pass123"))
    }
}
