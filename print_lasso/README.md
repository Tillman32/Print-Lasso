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
- `GET /printer/list`

## Camera Relay (go2rtc)

For Bambu RTSP camera feeds, run go2rtc alongside the service (included in
`print_lasso_service/docker-compose.yml`).

Default app behavior:
- If `GO2RTC_BASE_URL` is provided, the app uses it.
- Otherwise it uses `http://<active-service-host>:1984`.
- RTSP stream registration is handled by the Print Lasso service on printer save
  (users do not need to edit go2rtc YAML stream entries manually).

Override example:
```bash
flutter run --dart-define=GO2RTC_BASE_URL=http://192.168.1.50:1984
```
