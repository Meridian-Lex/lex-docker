# Inference Stack

Opt-in GPU inference services for the Stratavore knowledge system.

## Overview

This stack provides Ollama with the `granite-embedding:278m` model for semantic
vector indexing of the Lex knowledge base. It runs on a **separate GPU host** — not
the primary vessel.

The `stratavore-knowledge` indexer connects via `OLLAMA_HOST`. If unreachable,
the indexer degrades gracefully: it warns and skips embedding rather than crashing.

## Requirements

- NVIDIA GPU with 6 GB+ VRAM
- NVIDIA Container Toolkit installed on the host
- Docker + Docker Compose

## Deployment

### 1. Start Ollama

```bash
docker compose -f inference/docker-compose.yml up -d
```

### 2. Pull the embedding model (first time only)

```bash
docker compose -f inference/docker-compose.yml run --rm pull-models
```

This pulls `granite-embedding:278m` (~1.7 GB download, ~4-5 GB VRAM at runtime).

### 3. Verify

```bash
curl http://localhost:11434/api/tags
```

Should return the `granite-embedding:278m` model in the list.

## Connecting stratavore-knowledge

Set `OLLAMA_HOST` in your `stratavore-knowledge` environment to point at this host:

```yaml
environment:
  OLLAMA_HOST: http://<gpu-host-ip>:11434
```

The default is `http://localhost:11434` (assumes co-location).

## CPU-Only Mode

Remove the `deploy` block from the `ollama` service in `docker-compose.yml`.
Embedding will work but will be significantly slower (~10-30s per batch vs ~200ms on GPU).

## Model Details

| Field | Value |
|-------|-------|
| Model | granite-embedding:278m |
| Dimensions | 768 |
| Distance | Cosine |
| VRAM | 4-5 GB (FP16) |
| License | Apache 2.0 |
| MTEB rank | Top-tier |
