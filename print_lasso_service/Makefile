PYTHON := python3
VENV := .venv
VENV_BIN := $(VENV)/bin
PIP := $(VENV_BIN)/pip
PYTEST := $(VENV_BIN)/pytest
UVICORN := $(VENV_BIN)/uvicorn

.PHONY: help venv install setup run test clean

help:
	@echo "Targets:"
	@echo "  make setup   - Create venv and install dependencies"
	@echo "  make run     - Run FastAPI app on port 9000"
	@echo "  make test    - Run pytest"
	@echo "  make clean   - Remove virtualenv and caches"

venv:
	$(PYTHON) -m venv $(VENV)

install: venv
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt

setup: install

run:
	$(UVICORN) app.main:app --host 0.0.0.0 --port 9000

test:
	$(PYTEST) -q

clean:
	rm -rf $(VENV) .pytest_cache __pycache__ app/__pycache__ app/api/__pycache__ app/db/__pycache__ app/models/__pycache__ app/discovery/__pycache__ tests/__pycache__
