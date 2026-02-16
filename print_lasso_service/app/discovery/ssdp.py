import select
import socket
import time
from contextlib import suppress
from typing import Iterable
from typing import Dict, List

from app.config import settings

MULTICAST_GROUP = "239.255.255.250"
BAMBU_ST = "urn:bambulab-com:device:3dprinter:1"
BAMBU_ST_FALLBACK = "ssdp:all"
BAMBU_PORTS = (1900, 2021, 1990)
DISCOVERY_TIMEOUT_SECONDS = 6.0


def build_msearch_payload(port: int, *, st: str = BAMBU_ST) -> bytes:
    lines = [
        "M-SEARCH * HTTP/1.1",
        f"HOST: {MULTICAST_GROUP}:{port}",
        'MAN: "ssdp:discover"',
        "MX: 2",
        f"ST: {st}",
        "",
        "",
    ]
    return "\r\n".join(lines).encode("utf-8")


def parse_ssdp_response(data: bytes, addr: tuple[str, int]) -> Dict[str, str]:
    text = data.decode("utf-8", errors="ignore")
    headers: Dict[str, str] = {}
    for line in text.splitlines():
        if ":" in line:
            key, value = line.split(":", 1)
            headers[key.strip().lower()] = value.strip()
    headers["__ip"] = addr[0]
    return headers


def _extract_host(location: str) -> str:
    if not location:
        return ""
    location = location.replace("http://", "").replace("https://", "")
    if "/" in location:
        location = location.split("/", 1)[0]
    if ":" in location:
        location = location.split(":", 1)[0]
    return location


def _extract_serial(usn: str) -> str:
    if not usn:
        return ""
    usn = usn.removeprefix("uuid:")
    if "::" in usn:
        return usn.split("::", 1)[0]
    return usn


def _parse_bambu_response(headers: Dict[str, str], fallback_host: str) -> Dict[str, str] | None:
    if not _looks_like_bambu(headers):
        return None

    location = headers.get("location", "")
    ip_address = _extract_host(location) or fallback_host
    serial = _extract_serial(headers.get("usn", ""))

    if not serial:
        return None

    return {
        "brand": "Bambu Lab",
        "serial_number": serial,
        "name": headers.get("devname.bambu.com", ""),
        "model": headers.get("devmodel.bambu.com", ""),
        "ip_address": ip_address,
        "port": "8883",
        "dev_version": headers.get("devversion.bambu.com", ""),
        "dev_signal": headers.get("devsignal.bambu.com", ""),
        "dev_connect": headers.get("devconnect.bambu.com", ""),
        "st": headers.get("st", ""),
        "location": location,
        "server": headers.get("server", ""),
    }


def _looks_like_bambu(headers: Dict[str, str]) -> bool:
    st = (headers.get("st") or "").lower()
    nt = (headers.get("nt") or "").lower()
    usn = (headers.get("usn") or "").lower()
    server = (headers.get("server") or "").lower()
    model = (headers.get("devmodel.bambu.com") or "").lower()

    needle = BAMBU_ST.lower()
    return (
        needle in st
        or needle in nt
        or needle in usn
        or "bambu" in server
        or "bambu" in model
    )


def _open_discovery_socket(bind_port: int = 0) -> socket.socket:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    if hasattr(socket, "SO_REUSEPORT"):
        with suppress(OSError):
            sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.bind(("", bind_port))
    return sock


def _open_multicast_listener(port: int) -> socket.socket:
    sock = _open_discovery_socket(bind_port=port)
    membership = socket.inet_aton(MULTICAST_GROUP) + socket.inet_aton("0.0.0.0")
    with suppress(OSError):
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, membership)
    return sock


def _send_probes(sock: socket.socket, search_targets: Iterable[str]) -> None:
    destinations = (MULTICAST_GROUP, "255.255.255.255")
    for destination_host in destinations:
        for destination_port in BAMBU_PORTS:
            for search_target in search_targets:
                payload = build_msearch_payload(destination_port, st=search_target)
                with suppress(OSError):
                    sock.sendto(payload, (destination_host, destination_port))


def _discover_on_socket(timeout_seconds: float, include_all: bool) -> List[Dict[str, str]]:
    printers: Dict[str, Dict[str, str]] = {}
    passive_listeners: List[socket.socket] = []
    with _open_discovery_socket() as sock:
        listener_sockets: List[socket.socket] = [sock]
        for listen_port in BAMBU_PORTS:
            try:
                passive_sock = _open_multicast_listener(listen_port)
            except OSError:
                continue
            passive_listeners.append(passive_sock)
            listener_sockets.append(passive_sock)

        # First pass: exact Bambu ST, second pass: broad SSDP search.
        _send_probes(sock, (BAMBU_ST, BAMBU_ST_FALLBACK))
        deadline = time.monotonic() + timeout_seconds

        try:
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    break

                ready, _, _ = select.select(listener_sockets, [], [], min(1.0, remaining))
                if not ready:
                    continue

                for ready_sock in ready:
                    try:
                        data, addr = ready_sock.recvfrom(4096)
                    except OSError:
                        continue

                    # Ignore our own discovery probes that may be looped back by the
                    # local network stack/container bridge.
                    if data.lstrip().upper().startswith(b"M-SEARCH"):
                        continue

                    parsed_headers = parse_ssdp_response(data, addr)
                    if include_all:
                        if not (
                            parsed_headers.get("usn")
                            or parsed_headers.get("location")
                            or parsed_headers.get("server")
                            or parsed_headers.get("nt")
                        ):
                            continue
                        key = (
                            parsed_headers.get("usn")
                            or parsed_headers.get("location")
                            or f"{addr[0]}:{addr[1]}"
                        )
                        printers[key] = {
                            "serial_number": parsed_headers.get("usn", ""),
                            "model": parsed_headers.get("server", ""),
                            "name": parsed_headers.get("usn", ""),
                            "ip_address": addr[0],
                            "port": str(addr[1]),
                            "st": parsed_headers.get("st", ""),
                            "location": parsed_headers.get("location", ""),
                            "server": parsed_headers.get("server", ""),
                        }
                        continue

                    parsed = _parse_bambu_response(parsed_headers, addr[0])
                    if parsed and parsed.get("serial_number"):
                        printers[parsed["serial_number"]] = parsed
        finally:
            for passive_sock in passive_listeners:
                with suppress(OSError):
                    passive_sock.close()

    return list(printers.values())


def discover_bambu_printers(timeout_seconds: float | None = None, include_all: bool = False) -> List[Dict[str, str]]:
    timeout = timeout_seconds if timeout_seconds is not None else max(
        settings.ssdp_timeout_seconds,
        DISCOVERY_TIMEOUT_SECONDS,
    )
    try:
        return _discover_on_socket(timeout, include_all=include_all)
    except OSError:
        return []
