FROM python:3.13-slim

# ดึง uv binary
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# ติดตั้ง System dependencies สำหรับ OpenCV
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# คัดลอกและซิงก์ Dependency
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project

# คัดลอกโค้ดทั้งหมดเข้า Container
COPY . .

EXPOSE 8000

# รัน FastAPI ด้วย Uvicorn ผ่าน uv
CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]