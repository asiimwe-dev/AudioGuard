"""
AudioGuard REST API Application

Run with: uvicorn app:app --reload

Or use Docker:
  docker-compose up -d
"""

from api import create_app

# Create FastAPI application
app = create_app(debug=False)

if __name__ == "__main__":
    import uvicorn

    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=8000,
        workers=1,
        reload=False,
        log_level="info",
    )
