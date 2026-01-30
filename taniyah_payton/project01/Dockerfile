# Use Python as a base image
FROM python:3.12-slim

# Set working directory inside the container
WORKDIR /app

# Copy python program into container
COPY hello.py .

# Run program dynamically with a name argument
ENTRYPOINT ["python", "hello.py"]
