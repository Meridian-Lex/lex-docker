#!/bin/sh
# Pull required embedding models into Ollama.
# Run via: docker compose -f inference/docker-compose.yml run --rm pull-models
#
# Models pulled:
#   granite-embedding:278m  768-dim cosine embeddings, Apache 2.0
#                           ~4-5 GB VRAM (FP16), top-tier MTEB score
#
# OLLAMA_HOST must be set (injected by docker-compose or set manually).

set -e

OLLAMA="${OLLAMA_HOST:-http://localhost:11434}"
MODEL="granite-embedding:278m"

echo "Pulling ${MODEL} from Ollama at ${OLLAMA} ..."
ollama pull "${MODEL}"
echo "Done. ${MODEL} is ready for use."
