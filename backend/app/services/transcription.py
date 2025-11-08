"""Utilities for converting recorded audio into transcripts."""

from __future__ import annotations

import base64
import io
from dataclasses import dataclass

from openai import NOT_GIVEN, OpenAI
from openai._types import NotGiven


class TranscriptionEngine:
    """Transcribe dream audio notes using Whisper when available."""

    def __init__(self, *, api_key: str | None, model: str = "gpt-4o-mini-transcribe") -> None:
        self._client = OpenAI(api_key=api_key) if api_key else None
        self._model = model

    def transcribe(self, *, audio: bytes, prompt: str | None = None) -> TranscriptionResult:
        """Return the transcribed text."""

        if self._client is None:
            text = _offline_decode(audio)
            return TranscriptionResult(transcript=text, engine="offline", confidence=0.4)

        if not audio:
            raise ValueError("Audio payload is empty")

        with io.BytesIO(audio) as handle:
            handle.name = "dream.m4a"
            response = self._client.audio.transcriptions.create(
                model=self._model,
                file=handle,
                prompt=_optional_prompt(prompt),
            )

        text: str | None = getattr(response, "text", None)
        if not text:
            raise RuntimeError("Transcription service returned no text")

        return TranscriptionResult(transcript=text.strip(), engine="openai", confidence=0.9)


def decode_audio(payload: str) -> bytes:
    """Decode a base64 audio string, raising when invalid."""

    try:
        return base64.b64decode(payload, validate=True)
    except (ValueError, base64.binascii.Error) as exc:  # type: ignore[attr-defined]
        raise ValueError("Audio payload is not valid base64") from exc


def _offline_decode(audio: bytes) -> str:
    if not audio:
        return ""
    try:
        return audio.decode("utf-8", errors="ignore")
    except Exception:  # pragma: no cover - defensive fallback
        return ""


def _optional_prompt(prompt: str | None) -> str | NotGiven:
    """Return a value compatible with the OpenAI transcription client."""

    if prompt is None:
        return NOT_GIVEN
    return prompt


@dataclass
class TranscriptionResult:
    """Structured transcription payload."""

    transcript: str
    engine: str
    confidence: float

