FROM python:3.13-slim

# 1. ติดตั้ง AWS Lambda Web Adapter (ทำงานอัตโนมัติเมื่อรันบน Lambda, ไม่มีผลเมื่อรัน Local)
COPY --from=public.ecr.aws/awslabs/aws-lambda-web-adapter:0.8.4 /lambda-adapter /opt/extensions/lambda-adapter

# 2. ดึง uv binary
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# 3. ติดตั้ง System dependencies สำหรับ OpenCV
RUN apt-get update && apt-get install -y --no-install-recommends \
    libglib2.0-0 \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# 4. คัดลอกและซิงก์ Dependency
COPY pyproject.toml uv.lock ./
RUN uv sync --frozen --no-install-project

# 5. คัดลอกโค้ดทั้งหมดเข้า Container
COPY . .

# 6. ดาวน์โหลดโมเดล EasyOCR ล่วงหน้าลงใน Image (เพื่อป้องกันปัญหา Read-Only บน Lambda และเร่งความเร็ว Cold Start)
RUN mkdir -p /app/models && \
    uv run python -c "import easyocr; easyocr.Reader(['th', 'en'], gpu=False, model_storage_directory='/app/models')"

ENV PORT=8000
ENV EASYOCR_MODULE_PATH=/app/models

EXPOSE 8000

# รัน FastAPI ด้วย Uvicorn ผ่าน uv
CMD ["uv", "run", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]