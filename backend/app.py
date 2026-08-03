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
    import os

    import uvicorn

    # Look for the PORT environment variable, default to 8000 for local dev
    port = int(os.environ.get("PORT", "8000"))

    uvicorn.run(
        "app:app",
        host="0.0.0.0",
        port=port,
        workers=1,
        reload=False,
        log_level="info",
    )
