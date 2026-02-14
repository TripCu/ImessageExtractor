from __future__ import annotations

from dataclasses import dataclass

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse


@dataclass
class AppError(Exception):
    status_code: int
    code: str
    detail: str


class NotFoundError(AppError):
    def __init__(self, detail: str = "Resource not found") -> None:
        super().__init__(status_code=404, code="not_found", detail=detail)


class InvalidRequestError(AppError):
    def __init__(self, detail: str = "Invalid request") -> None:
        super().__init__(status_code=400, code="invalid_request", detail=detail)


class ServiceBusyError(AppError):
    def __init__(self, detail: str = "Service busy") -> None:
        super().__init__(status_code=429, code="service_busy", detail=detail)


class InternalServiceError(AppError):
    def __init__(self, detail: str = "Internal service error") -> None:
        super().__init__(status_code=500, code="internal_error", detail=detail)


def install_error_handlers(app: FastAPI) -> None:
    @app.exception_handler(AppError)
    async def app_error_handler(_: Request, exc: AppError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"error": {"code": exc.code, "detail": exc.detail}},
        )

    @app.exception_handler(Exception)
    async def unhandled_exception_handler(_: Request, __: Exception) -> JSONResponse:
        return JSONResponse(
            status_code=500,
            content={
                "error": {
                    "code": "internal_error",
                    "detail": "An unexpected error occurred.",
                }
            },
        )
