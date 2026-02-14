import CryptoSwift
import Foundation

struct EncryptedPackage {
    private static let magic = "IMEXPORT1"

    static func encrypt(plaintext: Data, passphrase: String) throws -> Data {
        let salt = AES.randomIV(16)
        let nonce = AES.randomIV(12)
        let key = try Scrypt(password: Array(passphrase.utf8), salt: salt, dkLen: 32, N: 16384, r: 8, p: 1).calculate()
        let gcm = GCM(iv: nonce, mode: .combined)
        let aes = try AES(key: key, blockMode: gcm, padding: .noPadding)
        let encrypted = try aes.encrypt(Array(plaintext))
        var out = Data(magic.utf8)
        out.append(Data(salt))
        out.append(Data(nonce))
        out.append(Data(encrypted))
        return out
    }

    static func decrypt(package: Data, passphrase: String) throws -> Data {
        let headerCount = magic.utf8.count
        guard package.count > headerCount + 16 + 12 else { throw CryptoError.invalidData }
        guard String(data: package.prefix(headerCount), encoding: .utf8) == magic else { throw CryptoError.invalidData }
        let payload = package.dropFirst(headerCount)
        let salt = Array(payload.prefix(16))
        let nonce = Array(payload.dropFirst(16).prefix(12))
        let ciphertext = Array(payload.dropFirst(28))
        let key = try Scrypt(password: Array(passphrase.utf8), salt: salt, dkLen: 32, N: 16384, r: 8, p: 1).calculate()
        let gcm = GCM(iv: nonce, mode: .combined)
        let aes = try AES(key: key, blockMode: gcm, padding: .noPadding)
        return Data(try aes.decrypt(ciphertext))
    }
}

enum CryptoError: Error {
    case invalidData
}
