"""LLM backed helpers for generating dream narratives."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Iterable, Sequence

from openai import OpenAI


class NarrativeEngine:
    """Generate narrative dream journals using OpenAI if available."""

    def __init__(
        self,
        *,
        api_key: str | None,
        model: str = "gpt-4o-mini",
        offline_fallback: "OfflineNarrative" | None = None,
    ) -> None:
        self._client = OpenAI(api_key=api_key) if api_key else None
        self._model = model
        self._fallback = offline_fallback or OfflineNarrative()

    def journal(
        self,
        *,
        title: str,
        transcript: str,
        mood: str | None,
        focus_points: Sequence[str],
        tone: str | None,
    ) -> NarrativeResult:
        """Return a structured journal derived from the transcript."""

        if not transcript.strip():
            raise ValueError("A transcript is required to generate a journal entry")

        if self._client is None:
            return self._fallback.generate(
                title=title,
                transcript=transcript,
                mood=mood,
                focus_points=focus_points,
                tone=tone,
            )

        user_prompt = _build_prompt(
            title=title,
            transcript=transcript,
            mood=mood,
            focus_points=focus_points,
            tone=tone,
        )
        response = self._client.chat.completions.create(
            model=self._model,
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a compassionate dream archivist. "
                        "Weave vivid 300-500 character narratives that preserve the user's voice, "
                        "highlight emotional beats, and close with a reflective line."
                    ),
                },
                {"role": "user", "content": user_prompt},
            ],
            max_tokens=600,
            temperature=0.85,
        )

        text = response.choices[0].message.content if response.choices else None
        if not text:
            raise RuntimeError("No content returned from the language model")

        return NarrativeResult(narrative=text.strip(), engine="openai")


def _build_prompt(
    *,
    title: str,
    transcript: str,
    mood: str | None,
    focus_points: Sequence[str],
    tone: str | None,
) -> str:
    """Compose a descriptive prompt for the LLM."""

    focus_block = "" if not focus_points else "\n\nFocus on: " + ", ".join(focus_points)
    mood_block = "" if not mood else f"\n\nMood upon waking: {mood}."
    tone_block = "" if not tone else f" Desired tone: {tone}."
    return (
        f"Title: {title}\n\nVerbatim transcript:\n{transcript}\n"
        f"{mood_block}{focus_block}{tone_block}\n\n"
        "Write a first-person dream journal entry that flows naturally."
    )


@dataclass
class NarrativeResult:
    """Structured response returned from the narrative engine."""

    narrative: str
    engine: str


class OfflineNarrative:
    """Heuristic fallback when no API key is configured."""

    def generate(
        self,
        *,
        title: str,
        transcript: str,
        mood: str | None,
        focus_points: Iterable[str],
        tone: str | None,
    ) -> NarrativeResult:
        summary = transcript.strip().replace("\n", " ")
        excerpt = summary[:450]
        mood_fragment = f"I woke feeling {mood}." if mood else "I paused to steady my breathing."
        if len(summary) > len(excerpt):
            excerpt = f"{excerpt}…"
        focus_line = " "
        focus_list = [item for item in focus_points if item]
        if focus_list:
            focus_line = " I keep thinking about " + ", ".join(focus_list) + "."
        tone_hint = f" The memory sits with a {tone} glow." if tone else ""
        narrative = (
            f"{title}: {excerpt} {mood_fragment}{focus_line}{tone_hint}"
            " I promise to revisit these symbols tonight."
        )
        return NarrativeResult(narrative=narrative, engine="offline")

