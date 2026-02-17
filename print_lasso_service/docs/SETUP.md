# Setup

## Prerequisites
- Python 3.13+
- pip
- Docker Desktop (optional, for containerized hosting)

## Local setup
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Run service
```bash
uvicorn app.main:app --host 0.0.0.0 --port 9000
```

## Run with Docker Compose
```bash
docker compose up --build -d
```

This starts:
- Print Lasso API: `http://localhost:9000`
- go2rtc relay API/UI: `http://localhost:1984`
- go2rtc RTSP: `rtsp://localhost:8554`
- go2rtc WebRTC: `localhost:8555`

The Flutter printers camera view uses go2rtc to relay Bambu RTSP feeds to MJPEG.
By default it targets `http://<active-service-host>:1984`.
The bundled `go2rtc.yaml` sets `api.origin: "*"` so browser clients can load relay
streams from a different origin (for example `http://localhost:58404`).
When a printer is added or updated with an RTSP camera URL, the service
automatically upserts matching go2rtc streams via the go2rtc HTTP API.

For LAN SSDP printer discovery on Linux hosts, use host networking:
```bash
docker compose -f docker-compose.yml -f docker-compose.host-network.yml up --build -d
```

Note: Docker bridge networking often blocks multicast/broadcast discovery traffic.
On Docker Desktop (macOS/Windows), run the service directly on the host for reliable discovery.

View logs:
```bash
docker compose logs -f
```

Stop:
```bash
docker compose down
```

## Quick checks
```bash
curl http://localhost:9000/api/v1/status
curl -X POST http://localhost:9000/api/v1/discover
curl -X POST http://localhost:9000/api/v1/printer/add \
  -H "Content-Type: application/json" \
  -d '{"serial_number":"SN-1","name":"Lab Printer"}'
```

Check go2rtc health/UI:
```bash
curl http://localhost:1984/
```

Optional relay test (replace `...` with your encoded RTSP URL):
```bash
curl -I "http://localhost:1984/api/stream.mjpeg?src=rtsps%3A%2F%2Fbblp%3A...%40192.168.1.50%3A322%2Fstreaming%2Flive%2F1"
```
