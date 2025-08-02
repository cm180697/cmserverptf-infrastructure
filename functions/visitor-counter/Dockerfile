# Dockerfile in functions/visitor-counter/

# --- Build Stage ---
FROM python:3.10-slim as builder

WORKDIR /app

RUN pip install poetry

# --- THIS IS THE FIX ---
# Tell poetry to create the virtual env in the project directory
RUN poetry config virtualenvs.in-project true

# Copy the dependency files from the root of the context
COPY pyproject.toml poetry.lock ./

# Install only the production dependencies into a virtual environment
# This will now create a .venv folder inside /app
RUN poetry install --no-root --only main

# --- Final Stage ---
FROM python:3.10-slim

WORKDIR /app

# Copy the virtual environment with dependencies from the builder stage
COPY --from=builder /app/.venv ./.venv

# Set the PATH to use the virtual environment
ENV PATH="/app/.venv/bin:$PATH"

# Copy the application source code into the working directory
COPY functions/visitor-counter/ .

EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]