# DreamWeave Backend

FastAPI service providing APIs for the DreamWeave mobile applications. The backend delivers
an in-memory dream journal API so the Flutter client can create and browse dream entries while
storage and AI integrations are still being validated.

## Prerequisites
- Python 3.11+
- [uv](https://github.com/astral-sh/uv) or `pip` for dependency management

## Setup
```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -e .[dev]
```

Alternatively, if you prefer [`uv`](https://github.com/astral-sh/uv):
```bash
cd backend
uv venv
source .venv/bin/activate
uv pip install -e .[dev]
```

## Run the API locally
```bash
uvicorn app.main:app --reload
```

The service exposes a health check at `http://localhost:8000/health` and a Dream management
resource at `http://localhost:8000/dreams/`.

### Dream API endpoints

| Method | Path                 | Description                                                                 |
| ------ | -------------------- | --------------------------------------------------------------------------- |
| GET    | `/dreams/`           | List dreams ordered by newest first. Supports `tag`, `query`, `mood`, `start`, `end`, `limit`. |
| GET    | `/dreams/highlights` | Return aggregate counts for tags and moods.                                 |
| POST   | `/dreams/`           | Create a new dream entry with automatic summary + tag drafting.             |
| GET    | `/dreams/{id}`       | Retrieve a single dream by its identifier.                                  |
| PUT    | `/dreams/{id}`       | Update a dream. Transcript changes trigger summary regeneration + tag merge.|
| DELETE | `/dreams/{id}`       | Remove a dream entry from the in-memory store.                              |
| POST   | `/dreams/transcribe` | Transcribe base64 audio via Whisper (OpenAI) or local fallback.             |
| POST   | `/dreams/{id}/journal` | Generate and persist a long-form journal entry for the dream.            |

#### Sample request

```bash
curl -X POST http://localhost:8000/dreams/ \
  -H 'Content-Type: application/json' \
  -d '{
        "title": "Flying above mountains",
        "transcript": "I was gliding over snowy peaks...",
        "tags": ["flight", "mountain"],
        "mood": "calm"
      }'
```

The response includes:
- An auto-generated `summary` that captures the first one or two sentences of the transcript.
- AI-inspired keyword suggestions merged into the `tags` array when a user does not provide tags. On updates the backend merges existing tags with regenerated keywords.
- The ISO formatted `created_at` timestamp.
- Optional `journal` content and `journal_generated_at` timestamps once the narrative endpoint has been invoked for the entry.

### Highlights response

```json
{
  "total_count": 12,
  "top_tags": [
    {"tag": "forest", "count": 4},
    {"tag": "ocean", "count": 3}
  ],
  "moods": [
    {"mood": "calm", "count": 5},
    {"mood": "energised", "count": 2}
  ]
}
```

Use this endpoint to drive dashboards or personalised summaries in the mobile client.

## Testing
```bash
pytest
```

## Code Quality
- `ruff check .`
- `mypy .`

All rules are configured in `pyproject.toml`.

## Configuration notes
- **OpenAI**: Set `OPENAI_API_KEY` before launching the server to enable Whisper/GPT-4o-mini integrations. Without a key the
  backend falls back to deterministic offline heuristics useful for local development and unit tests.
- **CORS**: During early exploration the API accepts requests from any origin. Tighten
  `allow_origins` in `app/main.py` before exposing the service publicly.
- **Persistence**: The dream store currently keeps data in memory. Replace `DreamStore` with a
  database-backed implementation (Supabase/PostgreSQL) when the infrastructure is ready.
- **Supabase**: `../supabase/README.md` にローカル環境の起動手順と `config.toml` を用意しています。PostgreSQL移行時はこの設定をベースに接続してください。
