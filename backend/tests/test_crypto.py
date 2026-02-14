from __future__ import annotations

import pytest

from app.crypto import CryptoError, decrypt_bytes, decrypt_package, encrypt_bytes, encrypt_package


def test_encrypt_decrypt_round_trip() -> None:
    plaintext = b"high sensitivity transcript"
    passphrase = "CorrectHorseBatteryStaple!"

    encrypted = encrypt_bytes(plaintext, passphrase)

    assert encrypted != plaintext
    assert decrypt_bytes(encrypted, passphrase) == plaintext


def test_encrypt_package_round_trip() -> None:
    files = {
        "transcript.json": b'{"messages": 2}',
        "manifest.json": b'{"version": 1}'
    }
    passphrase = "VeryStrongPassphrase#2026"

    encrypted = encrypt_package(files, passphrase)
    decrypted = decrypt_package(encrypted, passphrase)

    assert set(decrypted) == {"transcript.json", "manifest.json"}
    assert decrypted["transcript.json"] == files["transcript.json"]


def test_tamper_detection_rejects_modified_ciphertext() -> None:
    payload = bytearray(encrypt_bytes(b"sensitive payload", "TamperCheckPassphrase1!"))
    payload[-1] ^= 0xFF

    with pytest.raises(CryptoError):
        decrypt_bytes(bytes(payload), "TamperCheckPassphrase1!")
