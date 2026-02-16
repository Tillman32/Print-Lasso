from pathlib import Path

from fastapi.testclient import TestClient

from app import config
from app.db import engine as db_engine

DB_FILE = Path("test_print_lasso.db")

# Point app config and engine to test DB before importing app.main
config.settings.sqlite_file = str(DB_FILE)
db_engine.engine = db_engine.create_engine(
    config.settings.database_url,
    echo=False,
    connect_args={"check_same_thread": False},
)

from app.main import app  # noqa: E402

client = TestClient(app)


def setup_module() -> None:
    if DB_FILE.exists():
        DB_FILE.unlink()


def teardown_module() -> None:
    if DB_FILE.exists():
        DB_FILE.unlink()


def test_printer_crud_flow() -> None:
    with TestClient(app) as startup_client:
        create_resp = startup_client.post(
            "/api/v1/printer/add",
            json={
                "serial_number": "SN-1000",
                "name": "Bench Printer",
                "model": "X1C",
                "ip_address": "192.168.1.22",
                "port": 80,
                "camera_url": "http://192.168.1.22/cam",
            },
        )
        assert create_resp.status_code == 201

        view_resp = startup_client.get("/api/v1/printer/view", params={"serial_number": "SN-1000"})
        assert view_resp.status_code == 200
        assert view_resp.json()["name"] == "Bench Printer"

        edit_resp = startup_client.put(
            "/api/v1/printer/edit",
            json={"serial_number": "SN-1000", "name": "Renamed Printer"},
        )
        assert edit_resp.status_code == 200
        assert edit_resp.json()["name"] == "Renamed Printer"

        delete_resp = startup_client.request(
            "DELETE",
            "/api/v1/printer/remove",
            json={"serial_number": "SN-1000"},
        )
        assert delete_resp.status_code == 200

        missing_resp = startup_client.get("/api/v1/printer/view", params={"serial_number": "SN-1000"})
        assert missing_resp.status_code == 404
