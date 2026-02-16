PYTHON := python3
VENV := .venv
VENV_BIN := $(VENV)/bin
VENV_PY := $(VENV_BIN)/python
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
	$(VENV_PY) -m ensurepip --upgrade
	$(VENV_PY) -m pip install --upgrade pip

install: venv
	$(VENV_PY) -m pip install -r requirements.txt

setup: install

run: install
	$(VENV_PY) -m uvicorn app.main:app --host 0.0.0.0 --port 9000

test:
	$(PYTEST) -q

clean:
	rm -rf $(VENV) .pytest_cache __pycache__ app/__pycache__ app/api/__pycache__ app/db/__pycache__ app/models/__pycache__ app/discovery/__pycache__ tests/__pycache__
