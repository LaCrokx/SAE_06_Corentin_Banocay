# Use official Python 3.8 slim image
FROM python:3.8-slim

# Set working directory
WORKDIR /app

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libc6-dev \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements file
COPY requirements.txt .

# Install Python dependencies
# --no-cache-dir to keep image small
RUN pip install --upgrade pip wheel setuptools && \
    pip install --no-cache-dir --no-build-isolation -r requirements.txt

# Copy project files
COPY . .

# Expose port from config
EXPOSE 8080

# Command to run the application
CMD ["python", "-m", "addrservice.tornado.server", "-c", "configs/addressbook-local.yaml"]
