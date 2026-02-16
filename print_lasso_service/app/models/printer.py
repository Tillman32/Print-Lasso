from datetime import datetime, UTC
from typing import Optional

from sqlmodel import Field, SQLModel


class PrinterBase(SQLModel):
    serial_number: str = Field(index=True)
    name: str
    model: Optional[str] = None
    ip_address: Optional[str] = None
    port: int = 0
    camera_url: Optional[str] = None


class Printer(PrinterBase, table=True):
    __tablename__ = "printers"

    id: Optional[int] = Field(default=None, primary_key=True)
    serial_number: str = Field(unique=True, nullable=False)
    name: str = Field(nullable=False)
    created_at: datetime = Field(default_factory=lambda: datetime.now(UTC))
    updated_at: datetime = Field(default_factory=lambda: datetime.now(UTC))


class PrinterCreate(PrinterBase):
    serial_number: str
    name: str


class PrinterUpdate(SQLModel):
    serial_number: str
    name: Optional[str] = None
    model: Optional[str] = None
    ip_address: Optional[str] = None
    port: Optional[int] = None
    camera_url: Optional[str] = None


class PrinterDelete(SQLModel):
    serial_number: str


class PrinterRead(PrinterBase):
    id: int
    created_at: datetime
    updated_at: datetime
