FROM python:3.12-slim-bookworm

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

COPY requirements.txt .
# Set PIP_TRUSTED_HOSTS=1 at build time (TF_VAR_pip_trusted_host_build=true) if PyPI HTTPS fails
# behind a corporate proxy or with incomplete CA chains.
# checkov:skip=CKV2_DOCKER_4: Trusted-host is opt-in via ARG only; default build uses full TLS verification.
ARG PIP_TRUSTED_HOSTS=
RUN if [ "$PIP_TRUSTED_HOSTS" = "1" ]; then \
        pip install --no-cache-dir --trusted-host pypi.org --trusted-host files.pythonhosted.org -r requirements.txt; \
    else \
        pip install --no-cache-dir -r requirements.txt; \
    fi

COPY main.py .

RUN useradd --create-home --uid 1000 appuser \
    && chown -R appuser:appuser /app

USER appuser

ENV PYTHONUNBUFFERED=1

EXPOSE 8000

HEALTHCHECK --interval=15s --timeout=5s --retries=5 \
    CMD curl -fsS http://127.0.0.1:8000/health || exit 1

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
