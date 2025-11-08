"""Main FastAPI application for DreamWeave backend."""

from __future__ import annotations

import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .api.routes import dreams
from .services.dream_store import DreamStore
from .services.narrative import NarrativeEngine
from .services.transcription import TranscriptionEngine


def create_app() -> FastAPI:
    """Create and configure the FastAPI application instance."""

    app = FastAPI(title="DreamWeave API", version="0.1.0")

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=True,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    api_key = os.getenv("OPENAI_API_KEY")

    app.state.dream_store = DreamStore()
    app.state.narrative_engine = NarrativeEngine(api_key=api_key)
    app.state.transcription_engine = TranscriptionEngine(api_key=api_key)

    @app.get("/health", tags=["Health"])
    async def health_check() -> dict[str, str]:
        """Return a simple response confirming the API is running."""

        return {"status": "ok"}

    app.include_router(dreams.router, prefix="/dreams", tags=["Dreams"])

    return app


app = create_app()
