FROM python:3.12-slim

WORKDIR /app

# curl is required for the ECS container health check
RUN apt-get update && apt-get install -y --no-install-recommends curl \
    && rm -rf /var/lib/apt/lists/*

# Install dependencies first (layer cached unless requirements.txt changes)
COPY sample-api/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY sample-api/ .

EXPOSE 8080

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8080", "--workers", "1"]
