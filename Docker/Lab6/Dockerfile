FROM python:3.12-slim

# Unbuffered stdout so `docker logs` shows output immediately; no .pyc clutter.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Dependencies first: this layer is only rebuilt when requirements.txt changes.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Non-root user, created before the app is copied so COPY --chown can use it.
RUN useradd --create-home --shell /bin/bash appuser

COPY --chown=appuser:appuser app.py .

USER appuser
EXPOSE 5000
CMD ["python", "app.py"]
