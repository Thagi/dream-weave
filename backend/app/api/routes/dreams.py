"""API routes for managing dream entries."""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, Query, Request, Response, status

from ...schemas.dreams import (
    Dream,
    DreamCreate,
    DreamHighlights,
    DreamJournalRequest,
    DreamJournalResponse,
    DreamListResponse,
    DreamTranscriptionRequest,
    DreamTranscriptionResponse,
    DreamUpdate,
)
from ...services.dream_store import DreamStore
from ...services.narrative import NarrativeEngine
from ...services.transcription import TranscriptionEngine, TranscriptionResult, decode_audio

router = APIRouter()


def get_store(request: Request) -> DreamStore:
    """Return the dream store attached to the FastAPI application."""

    store = getattr(request.app.state, "dream_store", None)
    if store is None:
        raise RuntimeError("Dream store is not initialised on the application state")
    if not isinstance(store, DreamStore):
        raise RuntimeError("Invalid dream store configured on the application state")
    return store


def get_narrative_engine(request: Request) -> NarrativeEngine:
    """Return the configured narrative engine."""

    engine = getattr(request.app.state, "narrative_engine", None)
    if engine is None:
        raise RuntimeError("Narrative engine is not configured on the application state")
    if not isinstance(engine, NarrativeEngine):
        raise RuntimeError("Invalid narrative engine configured on the application state")
    return engine


def get_transcription_engine(request: Request) -> TranscriptionEngine:
    """Return the configured transcription engine."""

    engine = getattr(request.app.state, "transcription_engine", None)
    if engine is None:
        raise RuntimeError("Transcription engine is not configured on the application state")
    if not isinstance(engine, TranscriptionEngine):
        raise RuntimeError("Invalid transcription engine configured on the application state")
    return engine


@router.post("/", status_code=status.HTTP_201_CREATED, response_model=Dream)
async def create_dream(payload: DreamCreate, store: DreamStore = Depends(get_store)) -> Dream:
    """Create a dream entry and return the stored representation."""

    return store.create(payload)


@router.get("/", response_model=DreamListResponse)
async def list_dreams(
    store: DreamStore = Depends(get_store),
    tag: str | None = Query(None, description="Filter dreams that include the provided tag"),
    query: str | None = Query(
        None, description="Search recorded dreams by title, transcript, summary, or journal"
    ),
    mood: str | None = Query(None, description="Filter by the recorded mood"),
    start: datetime | None = Query(None, description="Limit to dreams recorded after this time"),
    end: datetime | None = Query(None, description="Limit to dreams recorded before this time"),
    limit: int = Query(20, ge=1, le=100, description="Number of items to return"),
) -> DreamListResponse:
    """Return recorded dreams optionally filtered by tag."""

    dreams = store.list(tag=tag, query=query, mood=mood, start=start, end=end)
    return DreamListResponse(dreams=dreams[:limit], total=len(dreams))


@router.get("/highlights", response_model=DreamHighlights)
async def get_highlights(store: DreamStore = Depends(get_store)) -> DreamHighlights:
    """Return aggregate insight for recorded dreams."""

    return store.highlights()


@router.get("/{dream_id}", response_model=Dream)
async def get_dream(dream_id: str, store: DreamStore = Depends(get_store)) -> Dream:
    """Return the details of a single dream."""

    dream = store.get(dream_id)
    if dream is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Dream not found")
    return dream


@router.put("/{dream_id}", response_model=Dream)
async def update_dream(
    dream_id: str, payload: DreamUpdate, store: DreamStore = Depends(get_store)
) -> Dream:
    """Update an existing dream entry."""

    dream = store.update(dream_id, payload)
    if dream is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Dream not found")
    return dream


@router.delete("/{dream_id}", status_code=status.HTTP_204_NO_CONTENT)
async def delete_dream(dream_id: str, store: DreamStore = Depends(get_store)) -> Response:
    """Delete an existing dream entry."""

    removed = store.delete(dream_id)
    if not removed:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Dream not found")
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post("/{dream_id}/journal", response_model=DreamJournalResponse)
async def generate_journal(
    dream_id: str,
    payload: DreamJournalRequest,
    store: DreamStore = Depends(get_store),
    engine: NarrativeEngine = Depends(get_narrative_engine),
) -> DreamJournalResponse:
    """Generate a dream journal narrative for the provided entry."""

    dream = store.get(dream_id)
    if dream is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Dream not found")

    result = engine.journal(
        title=dream.title,
        transcript=dream.transcript,
        mood=dream.mood,
        focus_points=payload.focus_points,
        tone=payload.tone,
    )
    updated = store.set_journal(
        dream_id,
        narrative=result.narrative,
        generated_at=datetime.now(timezone.utc),
    )
    if updated is None:  # pragma: no cover - defensive path
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Dream not found")
    return DreamJournalResponse(dream=updated, narrative=result.narrative, engine=result.engine)


@router.post("/transcribe", response_model=DreamTranscriptionResponse)
async def transcribe_audio(
    payload: DreamTranscriptionRequest,
    engine: TranscriptionEngine = Depends(get_transcription_engine),
) -> DreamTranscriptionResponse:
    """Convert uploaded dream audio into text."""

    audio = decode_audio(payload.audio_base64)
    result: TranscriptionResult = engine.transcribe(audio=audio, prompt=payload.prompt)
    return DreamTranscriptionResponse(
        transcript=result.transcript,
        engine=result.engine,
        confidence=result.confidence,
    )
