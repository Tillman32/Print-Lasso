# Print Lasso Flutter App

Flutter client for the Print Lasso local service.

## Local Service Discovery

The app can discover a local Print Lasso service advertised over mDNS/Bonjour:

- Service type: `_print-lasso._tcp.local`
- Expected metadata: `api_path=/api/v1`

App startup flow:

1. Load saved service details from local storage.
2. Health-check `GET /status` on saved service.
3. If unavailable, scan LAN for mDNS services and validate health.
4. Allow manual service address fallback.
5. Save selected service details locally for next launch.

## API usage

API client supports:

- `GET /status`
- `POST /discover`
- `POST /printer/add`
- `PUT /printer/edit`
- `DELETE /printer/remove`
- `GET /printer/view`
