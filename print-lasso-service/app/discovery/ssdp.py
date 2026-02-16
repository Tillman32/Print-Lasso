import socket
import time
from typing import Dict, List

from app.config import settings

MULTICAST_GROUP = "239.255.255.250"
BAMBU_ST = "urn:bambulab-com:device:3dprinter:1"
BAMBU_PORTS = (2021, 1990)
DISCOVERY_TIMEOUT_SECONDS = 6.0


def build_msearch_payload(port: int) -> bytes:
    lines = [
        "M-SEARCH * HTTP/1.1",
        f"HOST: {MULTICAST_GROUP}:{port}",
        'MAN: "ssdp:discover"',
        "MX: 2",
        f"ST: {BAMBU_ST}",
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
    st = headers.get("st") or headers.get("nt") or ""
    if BAMBU_ST not in st:
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


def _discover_on_port(port: int, timeout_seconds: float) -> List[Dict[str, str]]:
    printers: Dict[str, Dict[str, str]] = {}
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP) as sock:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        if hasattr(socket, "SO_REUSEPORT"):
            try:
                sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEPORT, 1)
            except OSError:
                pass
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        sock.bind(("", port))

        membership = socket.inet_aton(MULTICAST_GROUP) + socket.inet_aton("0.0.0.0")
        sock.setsockopt(socket.IPPROTO_IP, socket.IP_ADD_MEMBERSHIP, membership)

        for destination_port in BAMBU_PORTS:
            payload = build_msearch_payload(destination_port)
            sock.sendto(payload, (MULTICAST_GROUP, destination_port))

        sock.settimeout(timeout_seconds)
        deadline = time.monotonic() + timeout_seconds

        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            sock.settimeout(min(1.0, remaining))
            try:
                data, addr = sock.recvfrom(4096)
            except socket.timeout:
                break

            headers = parse_ssdp_response(data, addr)
            parsed = _parse_bambu_response(headers, addr[0])
            if parsed and parsed.get("serial_number"):
                printers[parsed["serial_number"]] = parsed

    return list(printers.values())


def discover_bambu_printers(timeout_seconds: float | None = None, include_all: bool = False) -> List[Dict[str, str]]:
    timeout = timeout_seconds if timeout_seconds is not None else max(settings.ssdp_timeout_seconds, DISCOVERY_TIMEOUT_SECONDS)

    if include_all:
        all_devices: Dict[str, Dict[str, str]] = {}
        for port in BAMBU_PORTS:
            try:
                with socket.socket(socket.AF_INET, socket.SOCK_DGRAM, socket.IPPROTO_UDP) as sock:
                    sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                    sock.bind(("", port))
                    for destination_port in BAMBU_PORTS:
                        sock.sendto(build_msearch_payload(destination_port), (MULTICAST_GROUP, destination_port))
                    sock.settimeout(timeout)
                    deadline = time.monotonic() + timeout
                    while True:
                        remaining = deadline - time.monotonic()
                        if remaining <= 0:
                            break
                        sock.settimeout(min(1.0, remaining))
                        try:
                            data, addr = sock.recvfrom(4096)
                        except socket.timeout:
                            break
                        parsed = parse_ssdp_response(data, addr)
                        key = parsed.get("usn") or parsed.get("location") or f"{addr[0]}:{addr[1]}"
                        all_devices[key] = {
                            "serial_number": parsed.get("usn", ""),
                            "model": parsed.get("server", ""),
                            "name": parsed.get("usn", ""),
                            "ip_address": addr[0],
                            "port": str(addr[1]),
                            "st": parsed.get("st", ""),
                            "location": parsed.get("location", ""),
                            "server": parsed.get("server", ""),
                        }
            except OSError:
                continue
        return list(all_devices.values())

    for port in BAMBU_PORTS:
        try:
            printers = _discover_on_port(port, timeout)
            if printers:
                return printers
        except OSError:
            continue
    return []
