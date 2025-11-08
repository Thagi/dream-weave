"""In-memory persistence primitives for dream entries."""

from __future__ import annotations

from collections import Counter
from dataclasses import dataclass
from datetime import datetime, timezone
import re
from threading import Lock
from typing import Dict

from ..schemas.dreams import (
    Dream,
    DreamCreate,
    DreamHighlights,
    DreamUpdate,
    MoodCount,
    TagCount,
)

_STOPWORDS = {
    "the",
    "and",
    "that",
    "with",
    "have",
    "this",
    "from",
    "there",
    "were",
    "they",
    "their",
    "about",
    "would",
    "could",
    "should",
    "while",
    "where",
    "which",
    "into",
    "after",
    "before",
    "through",
    "over",
    "under",
    "again",
    "dream",
    "dreams",
    "like",
    "just",
    "then",
    "some",
    "when",
    "your",
    "into",
    "once",
}


@dataclass
class _DreamRecord:
    """Internal representation of a dream stored in memory."""

    dream: Dream


class DreamStore:
    """Simple, threadsafe registry used during the early MVP stage."""

    def __init__(self) -> None:
        self._records: Dict[str, _DreamRecord] = {}
        self._lock = Lock()
        self._counter = 0

    def create(self, payload: DreamCreate) -> Dream:
        """Persist a dream and return the stored representation."""

        with self._lock:
            self._counter += 1
            identifier = str(self._counter)

        tags = list(payload.tags)
        if not tags:
            tags = _generate_tags(payload.transcript)
        else:
            auto_tags = _generate_tags(payload.transcript)
            tags = list(dict.fromkeys([*tags, *auto_tags]))

        dream = Dream(
            id=identifier,
            title=payload.title,
            transcript=payload.transcript,
            tags=tags,
            mood=payload.mood,
            summary=_summarise(payload.transcript),
            created_at=datetime.now(timezone.utc),
            journal=None,
            journal_generated_at=None,
        )
        self._records[dream.id] = _DreamRecord(dream=dream)
        return dream

    def list(
        self,
        *,
        tag: str | None = None,
        query: str | None = None,
        mood: str | None = None,
        start: datetime | None = None,
        end: datetime | None = None,
    ) -> list[Dream]:
        """Return stored dreams ordered by creation time descending."""

        dreams = sorted(
            (record.dream for record in self._records.values()),
            key=lambda dream: dream.created_at,
            reverse=True,
        )
        filtered: list[Dream] = []
        for dream in dreams:
            if tag and tag not in dream.tags:
                continue
            if mood and dream.mood != mood:
                continue
            if start and dream.created_at < start:
                continue
            if end and dream.created_at > end:
                continue
            if query:
                haystack = " ".join(
                    filter(
                        None,
                        [
                            dream.title,
                            dream.transcript,
                            dream.summary,
                            dream.journal,
                        ],
                    )
                ).lower()
                if query.lower() not in haystack:
                    continue
            filtered.append(dream)
        return filtered

    def get(self, dream_id: str) -> Dream | None:
        """Retrieve a specific dream by its identifier if available."""

        record = self._records.get(dream_id)
        return record.dream if record else None

    def update(self, dream_id: str, payload: DreamUpdate) -> Dream | None:
        """Mutate an existing dream entry with the provided payload."""

        with self._lock:
            record = self._records.get(dream_id)
            if record is None:
                return None

            current = record.dream
            title = payload.title if payload.title is not None else current.title
            transcript = (
                payload.transcript
                if payload.transcript is not None
                else current.transcript
            )
            mood = payload.mood if payload.mood is not None else current.mood

            auto_tags = _generate_tags(transcript)
            if payload.tags is None:
                base_tags = current.tags
                tags = list(dict.fromkeys([*base_tags, *auto_tags]))
            elif payload.tags:
                tags = list(dict.fromkeys([*payload.tags, *auto_tags]))
            else:
                tags = auto_tags

            summary = (
                _summarise(transcript)
                if payload.transcript is not None
                else current.summary
            )
            transcript_changed = (
                payload.transcript is not None and payload.transcript != current.transcript
            )

            updated = Dream(
                id=current.id,
                title=title,
                transcript=transcript,
                tags=tags,
                mood=mood,
                summary=summary,
                created_at=current.created_at,
                journal=None if transcript_changed else current.journal,
                journal_generated_at=(
                    None if transcript_changed else current.journal_generated_at
                ),
            )
            record.dream = updated
            return updated

    def delete(self, dream_id: str) -> bool:
        """Remove a dream entry from the registry."""

        with self._lock:
            return self._records.pop(dream_id, None) is not None

    def set_journal(
        self, dream_id: str, *, narrative: str, generated_at: datetime
    ) -> Dream | None:
        """Persist the generated journal on the stored dream."""

        with self._lock:
            record = self._records.get(dream_id)
            if record is None:
                return None
            current = record.dream
            updated = Dream(
                id=current.id,
                title=current.title,
                transcript=current.transcript,
                tags=current.tags,
                mood=current.mood,
                summary=current.summary,
                created_at=current.created_at,
                journal=narrative,
                journal_generated_at=generated_at,
            )
            record.dream = updated
            return updated

    def highlights(self) -> DreamHighlights:
        """Calculate lightweight insights for the recorded dreams."""

        dreams = [record.dream for record in self._records.values()]
        tag_counter: Counter[str] = Counter()
        mood_counter: Counter[str] = Counter()

        for dream in dreams:
            tag_counter.update(dream.tags)
            if dream.mood:
                mood_counter.update([dream.mood])

        top_tags = [TagCount(tag=tag, count=count) for tag, count in tag_counter.most_common(5)]
        mood_counts = [MoodCount(mood=mood, count=count) for mood, count in mood_counter.most_common()]

        return DreamHighlights(total_count=len(dreams), top_tags=top_tags, moods=mood_counts)


def _summarise(transcript: str) -> str:
    """Generate a short summary from the provided transcript."""

    cleaned = " ".join(chunk.strip() for chunk in transcript.splitlines() if chunk.strip())
    if not cleaned:
        return ""
    sentences = re.split(r"(?<=[.!?])\s+", cleaned)
    primary = sentences[0]
    if len(sentences) > 1:
        secondary = sentences[1]
        combined = f"{primary} {secondary}"
    else:
        combined = primary
    if len(combined) <= 280:
        return combined
    return f"{combined[:277]}..."


def _generate_tags(transcript: str) -> list[str]:
    """Derive lightweight keyword tags from a transcript."""

    words = re.findall(r"[A-Za-zÀ-ÖØ-öø-ÿ']+", transcript.lower())
    filtered = [word for word in words if len(word) >= 4 and word not in _STOPWORDS]
    counter: Counter[str] = Counter(filtered)
    return [word for word, _ in counter.most_common(5)]
