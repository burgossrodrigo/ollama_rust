# ── Stage 1: build ────────────────────────────────────────────────────────────
FROM rust:1.92.0-slim-bookworm AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y pkg-config libssl-dev && rm -rf /var/lib/apt/lists/*

# Cache dependencies before copying real source
COPY Cargo.toml Cargo.lock* ./
RUN mkdir src && echo 'fn main(){}' > src/main.rs && \
    cargo build --release && \
    rm -rf src

# Build real binary
COPY src ./src
RUN touch src/main.rs && cargo build --release

# ── Stage 2: runtime ──────────────────────────────────────────────────────────
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y ca-certificates libssl3 && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/target/release/ollama_api /usr/local/bin/ollama_api

EXPOSE 8080

ENV RUST_LOG=error \
    OLLAMA_URL=http://ollama:11434 \
    SEMAPHORE_LIMIT=3 \
    PORT=8080

CMD ["ollama_api"]
