from typing import Generator

from sqlmodel import Session, create_engine

from app.config import settings

engine = create_engine(settings.database_url, echo=False, connect_args={"check_same_thread": False})


def get_session() -> Generator[Session, None, None]:
    with Session(engine) as session:
        yield session
