from __future__ import annotations

import os
import secrets

TOKEN_ENV_NAME = "APP_API_TOKEN"
MIN_TOKEN_LENGTH = 32


class AuthConfigError(RuntimeError):
    pass


def load_expected_token() -> str:
    token = os.getenv(TOKEN_ENV_NAME)
    if not token:
        raise AuthConfigError(f"Missing required environment variable: {TOKEN_ENV_NAME}")
    if len(token) < MIN_TOKEN_LENGTH:
        raise AuthConfigError(
            f"{TOKEN_ENV_NAME} must be at least {MIN_TOKEN_LENGTH} characters"
        )
    return token


def parse_bearer_header(header_value: str | None) -> str | None:
    if not header_value:
        return None
    parts = header_value.strip().split(" ", 1)
    if len(parts) != 2:
        return None
    scheme, token = parts
    if scheme.lower() != "bearer" or not token:
        return None
    return token


def is_token_authorized(header_value: str | None, expected_token: str) -> bool:
    candidate = parse_bearer_header(header_value)
    if candidate is None:
        return False
    return secrets.compare_digest(candidate, expected_token)
