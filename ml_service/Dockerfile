# Use official lightweight Python image
FROM python:3.9-slim

# Install system dependencies needed for OpenCV, PyTorch, and EasyOCR
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libgl1-mesa-glx \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# Set working directory inside container
WORKDIR /app

# Copy requirements file first to leverage Docker layer caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the ML service files
COPY . .

# Expose the service port
EXPOSE 8765

# Start the service on port 8765
CMD ["uvicorn", "ml_plate_service:app", "--host", "0.0.0.0", "--port", "8765"]
