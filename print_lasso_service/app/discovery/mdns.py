import logging
import socket

from zeroconf import IPVersion, ServiceInfo
from zeroconf.asyncio import AsyncZeroconf

from app.config import settings

logger = logging.getLogger("print_lasso")

_zeroconf: AsyncZeroconf | None = None
_service_info: ServiceInfo | None = None


def _resolve_advertise_ip() -> str:
    if settings.mdns_advertise_host:
        return settings.mdns_advertise_host

    if settings.host and settings.host not in {"0.0.0.0", "::"}:
        return settings.host

    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.connect(("8.8.8.8", 80))
            return str(sock.getsockname()[0])
    except OSError:
        return "127.0.0.1"


async def register_mdns_service() -> None:
    global _zeroconf, _service_info

    if not settings.mdns_enabled or _zeroconf is not None:
        return

    advertise_ip = _resolve_advertise_ip()
    service_type = settings.mdns_service_type
    service_name = f"{settings.mdns_instance_name}.{service_type}"

    info = ServiceInfo(
        type_=service_type,
        name=service_name,
        addresses=[socket.inet_aton(advertise_ip)],
        port=settings.port,
        properties={
            "version": "0.1.0",
            "api_path": settings.mdns_api_path,
        },
        server=f"{socket.gethostname().split('.')[0]}.local.",
    )

    try:
        zeroconf = AsyncZeroconf(ip_version=IPVersion.V4Only)
        await zeroconf.async_register_service(info, allow_name_change=True)
        _zeroconf = zeroconf
        _service_info = info
        logger.info("mDNS service advertised: %s at %s:%s", info.name, advertise_ip, settings.port)
    except Exception:
        logger.exception("Failed to register mDNS service")
        await unregister_mdns_service()


async def unregister_mdns_service() -> None:
    global _zeroconf, _service_info

    if _zeroconf is None:
        return

    try:
        if _service_info is not None:
            await _zeroconf.async_unregister_service(_service_info)
    except Exception:
        logger.exception("Failed to unregister mDNS service cleanly")
    finally:
        await _zeroconf.async_close()
        _zeroconf = None
        _service_info = None
