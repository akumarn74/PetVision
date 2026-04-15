from pydantic_settings import BaseSettings, SettingsConfigDict

class Settings(BaseSettings):
    PROJECT_NAME: str = "PetVision API"
    ENVIRONMENT: str = "development"
    
    # Core DB
    DATABASE_URL: str = "postgresql+asyncpg://postgres:postgres@localhost:5432/petvision"
    
    # Secrets
    JWT_SECRET_KEY: str = "b4ad_s3cret_dev_only_change_in_prod"
    
    # AI 
    OPENAI_API_KEY: str
    
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="allow"
    )

settings = Settings()
