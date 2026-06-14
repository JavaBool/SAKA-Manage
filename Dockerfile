# Use an official Python runtime as a parent image
FROM python:3.10-slim

# Set the working directory to /workspace
WORKDIR /workspace

# Install system dependencies (needed for compiling certain python packages like psycopg2)
RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy backend requirements first to leverage Docker cache
COPY backend/requirements.txt /workspace/backend/requirements.txt

# Install python dependencies
RUN pip install --no-cache-dir -r /workspace/backend/requirements.txt

# Copy the backend folder
COPY backend /workspace/backend

# Expose port 7860 (Hugging Face expects port 7860 by default)
EXPOSE 7860

# Run the Flask app from the workspace root (so python resolves backend.app)
CMD ["gunicorn", "-w", "4", "-b", "0.0.0.0:7860", "backend.app:app"]
