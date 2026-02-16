# Print Lasso Service (Python MVP)

FastAPI + SQLModel service for 3D printer management with Bambu SSDP discovery.

## Docker
Run with Docker Compose:
```bash
docker compose up --build -d
```

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

## Notes
- MVP runs as a foreground process.
- No authentication for MVP (trusted LAN).
- Cross-platform service wrappers planned pre-release.
- Service advertises itself via mDNS as `_print-lasso._tcp.local` for LAN discovery.
