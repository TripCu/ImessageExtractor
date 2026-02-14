from __future__ import annotations

import io
import json
import zipfile
from typing import Mapping

from cryptography.exceptions import InvalidTag
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from cryptography.hazmat.primitives.kdf.scrypt import Scrypt
from os import urandom

MAGIC = b"IMEXPV1\x00"
SALT_SIZE = 16
NONCE_SIZE = 12


class CryptoError(Exception):
    pass


def secure_erase(buffer: bytearray) -> None:
    for index in range(len(buffer)):
        buffer[index] = 0


def derive_key(passphrase: str, salt: bytes) -> bytes:
    kdf = Scrypt(salt=salt, length=32, n=2**15, r=8, p=1)
    return kdf.derive(passphrase.encode("utf-8"))


def encrypt_bytes(plaintext: bytes, passphrase: str) -> bytes:
    if len(passphrase) < 8:
        raise CryptoError("Passphrase must be at least 8 characters")

    salt = urandom(SALT_SIZE)
    nonce = urandom(NONCE_SIZE)
    key = derive_key(passphrase, salt)
    key_buffer = bytearray(key)
    try:
        aesgcm = AESGCM(bytes(key_buffer))
        ciphertext = aesgcm.encrypt(nonce, plaintext, MAGIC)
        return MAGIC + salt + nonce + ciphertext
    finally:
        secure_erase(key_buffer)


def decrypt_bytes(payload: bytes, passphrase: str) -> bytes:
    if len(payload) < len(MAGIC) + SALT_SIZE + NONCE_SIZE + 16:
        raise CryptoError("Encrypted payload is malformed")
    if payload[: len(MAGIC)] != MAGIC:
        raise CryptoError("Invalid encrypted package header")

    offset = len(MAGIC)
    salt = payload[offset : offset + SALT_SIZE]
    offset += SALT_SIZE
    nonce = payload[offset : offset + NONCE_SIZE]
    offset += NONCE_SIZE
    ciphertext = payload[offset:]

    key = derive_key(passphrase, salt)
    key_buffer = bytearray(key)
    try:
        aesgcm = AESGCM(bytes(key_buffer))
        try:
            return aesgcm.decrypt(nonce, ciphertext, MAGIC)
        except InvalidTag as exc:
            raise CryptoError("Decryption failed; passphrase or ciphertext is invalid") from exc
    finally:
        secure_erase(key_buffer)


def build_plain_package(files: Mapping[str, bytes | bytearray]) -> bytes:
    archive_buffer = io.BytesIO()
    with zipfile.ZipFile(archive_buffer, mode="w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, content in files.items():
            archive.writestr(name, bytes(content))
    return archive_buffer.getvalue()


def read_plain_package(package: bytes) -> dict[str, bytes]:
    result: dict[str, bytes] = {}
    with zipfile.ZipFile(io.BytesIO(package), mode="r") as archive:
        for name in archive.namelist():
            result[name] = archive.read(name)
    return result


def encrypt_package(files: Mapping[str, bytes | bytearray], passphrase: str) -> bytes:
    plaintext = build_plain_package(files)
    plaintext_buffer = bytearray(plaintext)
    try:
        return encrypt_bytes(bytes(plaintext_buffer), passphrase)
    finally:
        secure_erase(plaintext_buffer)


def decrypt_package(payload: bytes, passphrase: str) -> dict[str, bytes]:
    plaintext = decrypt_bytes(payload, passphrase)
    plaintext_buffer = bytearray(plaintext)
    try:
        return read_plain_package(bytes(plaintext_buffer))
    finally:
        secure_erase(plaintext_buffer)


def build_manifest(
    conversation_id: int,
    message_count: int,
    transcript_name: str,
    includes_attachments: bool,
) -> bytes:
    manifest = {
        "version": 1,
        "conversation_id": conversation_id,
        "message_count": message_count,
        "transcript": transcript_name,
        "includes_attachments": includes_attachments,
    }
    return json.dumps(manifest, ensure_ascii=False, indent=2).encode("utf-8")
