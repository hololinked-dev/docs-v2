FROM python:3.11-slim

# workdir
WORKDIR /app

# OS dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN pip install uv mkdocs-material

COPY . .

# Create a virtual environment and sync dependencies
RUN uv venv && \
    . .venv/bin/activate && \
    uv sync --no-install-project

RUN . .venv/bin/activate && mkdocs build

CMD ["/bin/sh", "-c", ". .venv/bin/activate && mkdocs serve -a 0.0.0.0:8000"]