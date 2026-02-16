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
