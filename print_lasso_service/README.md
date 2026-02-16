# Print Lasso Service (Python MVP)

FastAPI + SQLModel service for 3D printer management with Bambu SSDP discovery.

## Docker
Run with Docker Compose:
```bash
docker compose up --build -d
```

This starts:
- `print-lasso-service` on port `9000`
- `go2rtc` relay API/UI on port `1984` (used by the Flutter camera feed for RTSP relay)
- `go2rtc` RTSP on `8554` and WebRTC signaling/media on `8555`

Stop it:
```bash
docker compose down
```

## API
- `GET /api/v1/status`
- `POST /api/v1/discover`
- `POST /api/v1/printer/add`
- `PUT /api/v1/printer/edit`
- `DELETE /api/v1/printer/remove`
- `GET /api/v1/printer/view?serial_number=...`
- `GET /api/v1/printer/list`

## Notes
- MVP runs as a foreground process.
- No authentication for MVP (trusted LAN).
- Cross-platform service wrappers planned pre-release.
- Service advertises itself via mDNS as `_print-lasso._tcp.local` for LAN discovery.
- `go2rtc` is configured via `go2rtc/go2rtc.yaml`.
- For camera relay debugging, open `http://localhost:1984`.
- If you run the service in Docker and need LAN printer discovery, use host networking
  on Linux: `docker compose -f docker-compose.yml -f docker-compose.host-network.yml up -d --build`.
  Docker bridge networks often block/limit multicast and broadcast SSDP traffic.
