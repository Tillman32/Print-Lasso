from datetime import datetime, UTC
from typing import Any

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.exc import IntegrityError
from sqlmodel import Session, select

from app.db.engine import get_session
from app.discovery.ssdp import discover_bambu_printers
from app.integrations.go2rtc import ensure_camera_stream, remove_camera_streams
from app.models.printer import Printer, PrinterCreate, PrinterDelete, PrinterRead, PrinterUpdate

router = APIRouter()


@router.get("/status")
def status_check() -> dict[str, str]:
    return {"status": "ok"}


@router.post("/discover")
def discover(include_all: bool = Query(False)) -> dict[str, Any]:
    printers = discover_bambu_printers(include_all=include_all)
    return {"count": len(printers), "printers": printers}


@router.post("/printer/add", response_model=PrinterRead, status_code=status.HTTP_201_CREATED)
def add_printer(payload: PrinterCreate, session: Session = Depends(get_session)) -> Printer:
    printer = Printer.model_validate(payload)
    printer.updated_at = datetime.now(UTC)
    try:
        session.add(printer)
        session.commit()
        session.refresh(printer)
    except IntegrityError as exc:
        session.rollback()
        raise HTTPException(status_code=409, detail="Printer with this serial number already exists") from exc
    ensure_camera_stream(serial_number=printer.serial_number, camera_url=printer.camera_url)
    return printer


@router.put("/printer/edit", response_model=PrinterRead)
def edit_printer(payload: PrinterUpdate, session: Session = Depends(get_session)) -> Printer:
    printer = session.exec(select(Printer).where(Printer.serial_number == payload.serial_number)).first()
    if not printer:
        raise HTTPException(status_code=404, detail="Printer not found")

    old_camera_url = printer.camera_url
    update_data = payload.model_dump(exclude_unset=True)
    update_data.pop("serial_number", None)
    for field_name, value in update_data.items():
        setattr(printer, field_name, value)
    printer.updated_at = datetime.now(UTC)

    session.add(printer)
    session.commit()
    session.refresh(printer)
    if old_camera_url != printer.camera_url:
        remove_camera_streams(serial_number=printer.serial_number, camera_url=old_camera_url)
    ensure_camera_stream(serial_number=printer.serial_number, camera_url=printer.camera_url)
    return printer


@router.delete("/printer/remove")
def remove_printer(payload: PrinterDelete, session: Session = Depends(get_session)) -> dict[str, str]:
    printer = session.exec(select(Printer).where(Printer.serial_number == payload.serial_number)).first()
    if not printer:
        raise HTTPException(status_code=404, detail="Printer not found")

    remove_camera_streams(serial_number=printer.serial_number, camera_url=printer.camera_url)
    session.delete(printer)
    session.commit()
    return {"status": "deleted", "serial_number": payload.serial_number}


@router.get("/printer/view", response_model=PrinterRead)
def view_printer(serial_number: str = Query(...), session: Session = Depends(get_session)) -> Printer:
    printer = session.exec(select(Printer).where(Printer.serial_number == serial_number)).first()
    if not printer:
        raise HTTPException(status_code=404, detail="Printer not found")
    return printer


@router.get("/printer/list", response_model=list[PrinterRead])
def list_printers(session: Session = Depends(get_session)) -> list[Printer]:
    return list(session.exec(select(Printer).order_by(Printer.name, Printer.serial_number)))
