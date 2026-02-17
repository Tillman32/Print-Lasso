import logging
import re
from urllib.parse import urlparse

import httpx

from app.config import settings

logger = logging.getLogger("print_lasso")
_VALID_ALIAS_CHARS = re.compile(r"[^a-z0-9_-]+")


def _is_rtsp_url(url: str | None) -> bool:
    if not url:
        return False
    scheme = urlparse(url).scheme.lower()
    return scheme in {"rtsp", "rtsps"}


def _stream_alias_for_serial(serial_number: str) -> str:
    normalized = _VALID_ALIAS_CHARS.sub("-", serial_number.lower()).strip("-")
    if not normalized:
        normalized = "printer"
    return f"printer-{normalized}"


def _client() -> httpx.Client:
    return httpx.Client(timeout=settings.go2rtc_timeout_seconds)


def _upsert_stream(name: str, source_url: str) -> None:
    with _client() as client:
        response = client.put(
            f"{settings.go2rtc_base_url.rstrip('/')}/api/streams",
            params={"name": name, "src": source_url},
        )
        response.raise_for_status()


def _delete_stream(name: str) -> None:
    with _client() as client:
        response = client.delete(
            f"{settings.go2rtc_base_url.rstrip('/')}/api/streams",
            params={"src": name},
        )
        # go2rtc may return 404 when stream doesn't exist; that is safe.
        if response.status_code not in (200, 404):
            response.raise_for_status()


def ensure_camera_stream(serial_number: str, camera_url: str | None) -> None:
    if not settings.go2rtc_enabled or not _is_rtsp_url(camera_url):
        return

    alias = _stream_alias_for_serial(serial_number)
    assert camera_url is not None  # guarded by _is_rtsp_url
    try:
        # Keep both keys in sync:
        # - camera_url matches current Flutter relay lookup (`src=<rtsp_url>`)
        # - alias gives a stable key for future UI usage.
        _upsert_stream(name=camera_url, source_url=camera_url)
        _upsert_stream(name=alias, source_url=camera_url)
    except httpx.HTTPError as exc:
        logger.warning("go2rtc stream upsert failed for %s: %s", serial_number, exc)


def remove_camera_streams(serial_number: str, camera_url: str | None) -> None:
    if not settings.go2rtc_enabled:
        return

    names: list[str] = [_stream_alias_for_serial(serial_number)]
    if _is_rtsp_url(camera_url) and camera_url is not None:
        names.append(camera_url)

    for name in names:
        try:
            _delete_stream(name)
        except httpx.HTTPError as exc:
            logger.warning("go2rtc stream delete failed for %s (%s): %s", serial_number, name, exc)
