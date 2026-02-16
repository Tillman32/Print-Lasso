from sqlmodel import SQLModel

from app.db.engine import engine


def create_db_and_tables() -> None:
    SQLModel.metadata.create_all(engine)
