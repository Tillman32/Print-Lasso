from app.discovery.ssdp import _parse_bambu_response, parse_ssdp_response


def test_parse_ssdp_response_extracts_headers() -> None:
    payload = (
        b"HTTP/1.1 200 OK\r\n"
        b"ST: urn:bambulab-com:device:3dprinter:1\r\n"
        b"USN: uuid:ABC123::urn:bambulab-com:device:3dprinter:1\r\n"
        b"DevName.bambu.com: Office Printer\r\n"
        b"DevModel.bambu.com: P1S\r\n"
        b"\r\n"
    )
    parsed = parse_ssdp_response(payload, ("192.168.1.10", 2021))

    assert parsed["st"] == "urn:bambulab-com:device:3dprinter:1"
    assert parsed["usn"] == "uuid:ABC123::urn:bambulab-com:device:3dprinter:1"
    assert parsed["devname.bambu.com"] == "Office Printer"
    assert parsed["devmodel.bambu.com"] == "P1S"
    assert parsed["__ip"] == "192.168.1.10"


def test_parse_bambu_response_accepts_only_bambu_st() -> None:
    non_bambu = {
        "st": "upnp:rootdevice",
        "usn": "uuid:roku:abc123::upnp:rootdevice",
    }
    parsed_non_bambu = _parse_bambu_response(non_bambu, "192.168.1.115")
    assert parsed_non_bambu is None

    bambu_headers = {
        "st": "urn:bambulab-com:device:3dprinter:1",
        "usn": "uuid:ABCDEF123::urn:bambulab-com:device:3dprinter:1",
        "location": "http://192.168.1.67/description.xml",
        "devname.bambu.com": "P1S",
        "devmodel.bambu.com": "P1S",
    }
    parsed_bambu = _parse_bambu_response(bambu_headers, "192.168.1.67")

    assert parsed_bambu is not None
    assert parsed_bambu["serial_number"] == "ABCDEF123"
    assert parsed_bambu["name"] == "P1S"
    assert parsed_bambu["model"] == "P1S"
    assert parsed_bambu["ip_address"] == "192.168.1.67"


def test_parse_bambu_response_accepts_bambu_usn_with_ssdp_all() -> None:
    headers = {
        "st": "ssdp:all",
        "usn": "uuid:ABCDEF456::urn:bambulab-com:device:3dprinter:1",
        "server": "Bambu Lab",
        "location": "http://192.168.1.88/description.xml",
        "devname.bambu.com": "X1C",
        "devmodel.bambu.com": "X1 Carbon",
    }

    parsed = _parse_bambu_response(headers, "192.168.1.88")

    assert parsed is not None
    assert parsed["serial_number"] == "ABCDEF456"
    assert parsed["name"] == "X1C"
    assert parsed["model"] == "X1 Carbon"
    assert parsed["ip_address"] == "192.168.1.88"
