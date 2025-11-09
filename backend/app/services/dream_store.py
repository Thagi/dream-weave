"""In-memory persistence primitives for dream entries."""

from __future__ import annotations

import re
from collections import Counter
from dataclasses import dataclass
from datetime import UTC, datetime, timedelta
from threading import Lock

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
    "once",
}

_SUMMARY_MAX_CHARACTERS = 280
_SUMMARY_SUFFIX = "..."
_SUMMARY_SUFFIX_LENGTH = len(_SUMMARY_SUFFIX)
_SUMMARY_BODY_LENGTH = _SUMMARY_MAX_CHARACTERS - _SUMMARY_SUFFIX_LENGTH
_MAX_AUTO_TAGS = 5
_MIN_KEYWORD_LENGTH = 4
_TIMESTAMP_INCREMENT = timedelta(seconds=1)
_TIMESTAMP_EPSILON = timedelta(microseconds=1)


@dataclass
class _DreamRecord:
    """Internal representation of a dream stored in memory."""

    dream: Dream


class DreamStore:
    """Simple, threadsafe registry used during the early MVP stage."""

    def __init__(self) -> None:
        self._records: dict[str, _DreamRecord] = {}
        self._lock = Lock()
        self._counter = 0
        self._last_created_at: datetime | None = None

    def create(self, payload: DreamCreate) -> Dream:
        """Persist a dream and return the stored representation."""

        # Pre-compute derived fields outside the lock to minimise contention.
        tags = list(payload.tags)
        auto_tags = _generate_tags(payload.transcript)
        if not tags:
            tags = auto_tags
        else:
            tags = list(dict.fromkeys([*tags, *auto_tags]))

        summary = _summarise(payload.transcript)
        now = datetime.now(UTC)

        with self._lock:
            self._counter += 1
            identifier = str(self._counter)

            timestamp = now
            if self._last_created_at is not None:
                minimum = self._last_created_at + _TIMESTAMP_INCREMENT
                timestamp = max(timestamp, minimum + _TIMESTAMP_EPSILON)

            dream = Dream(
                id=identifier,
                title=payload.title,
                transcript=payload.transcript,
                tags=tags,
                mood=payload.mood,
                summary=summary,
                created_at=timestamp,
                journal=None,
                journal_generated_at=None,
            )
            self._records[dream.id] = _DreamRecord(dream=dream)
            self._last_created_at = timestamp

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

        with self._lock:
            records_snapshot = list(self._records.values())

        dreams = sorted(
            (record.dream for record in records_snapshot),
            key=lambda dream: dream.created_at,
            reverse=True,
        )
        start_utc = _normalise_to_utc(start)
        end_utc = _normalise_to_utc(end)

        filtered: list[Dream] = []
        for dream in dreams:
            if tag and tag not in dream.tags:
                continue
            if mood and dream.mood != mood:
                continue
            if start_utc and dream.created_at < start_utc:
                continue
            if end_utc and dream.created_at > end_utc:
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

        with self._lock:
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

        with self._lock:
            dreams = [record.dream for record in self._records.values()]
        tag_counter: Counter[str] = Counter()
        mood_counter: Counter[str] = Counter()

        for dream in dreams:
            tag_counter.update(dream.tags)
            if dream.mood:
                mood_counter.update([dream.mood])

        top_tags = [
            TagCount(tag=tag, count=count)
            for tag, count in tag_counter.most_common(_MAX_AUTO_TAGS)
        ]
        mood_counts = [
            MoodCount(mood=mood, count=count)
            for mood, count in mood_counter.most_common()
        ]

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
    if len(combined) <= _SUMMARY_MAX_CHARACTERS:
        return combined
    return f"{combined[:_SUMMARY_BODY_LENGTH]}{_SUMMARY_SUFFIX}"


def _generate_tags(transcript: str) -> list[str]:
    """Derive lightweight keyword tags from a transcript."""

    words = re.findall(r"[A-Za-zÀ-ÖØ-öø-ÿ']+", transcript.lower())
    filtered = [
        word
        for word in words
        if len(word) >= _MIN_KEYWORD_LENGTH and word not in _STOPWORDS
    ]
    counter: Counter[str] = Counter(filtered)
    return [word for word, _ in counter.most_common(_MAX_AUTO_TAGS)]


def _normalise_to_utc(value: datetime | None) -> datetime | None:
    """Return a timezone-aware datetime in UTC for comparisons."""

    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=UTC)
    return value.astimezone(UTC)
