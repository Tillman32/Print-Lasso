from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="PRINT_LASSO_", case_sensitive=False)

    host: str = "0.0.0.0"
    port: int = 9000
    sqlite_file: str = "print_lasso.db"
    ssdp_multicast_host: str = "239.255.255.250"
    ssdp_multicast_port: int = 2021
    ssdp_timeout_seconds: float = 3.0
    mdns_enabled: bool = True
    mdns_service_type: str = "_print-lasso._tcp.local."
    mdns_instance_name: str = "Print Lasso Service"
    mdns_api_path: str = "/api/v1"
    mdns_advertise_host: str = ""

    @property
    def database_url(self) -> str:
        return f"sqlite:///{self.sqlite_file}"


settings = Settings()
