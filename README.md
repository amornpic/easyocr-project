# EasyOCR API

REST API สำหรับประมวลผลรูปภาพและแปลงเป็นข้อความ (Optical Character Recognition - OCR) รองรับภาษาไทย (`th`) และภาษาอังกฤษ (`en`) พัฒนาด้วย **FastAPI**, **EasyOCR**, และ **uv** พร้อมรองรับการรันผ่าน **Docker** และ **Docker Compose**

---

## 🌟 ฟีเจอร์หลัก (Features)

- **Fast & Lightweight:** พัฒนาด้วย FastAPI ให้ประสิทธิภาพสูง พร้อมระบบ Interactive API Docs (Swagger UI)
- **Multi-language OCR:** รองรับการตรวจจับและอ่านข้อความภาษาไทยและภาษาอังกฤษ
- **Detailed Bounding Box:** ส่งกลับพิกัดตำแหน่งของข้อความทั้งแบบ `top_left`, `bottom_right` และ `raw_bbox` (พิกัด 4 จุด) เพื่อนำไปวาดกรอบหรือทำ Image Processing ต่อได้ทันที
- **Model Caching:** มีการโหลดโมเดลขึ้นหน่วยความจำตอนเริ่มต้น Service และรองรับการทำ Docker Volume Cache เพื่อไม่ให้ต้องโหลดโมเดลซ้ำเมื่อ Restart Container
- **Modern Python Tooling:** จัดการ Dependency ด้วย `uv` รวดเร็วและแม่นยำ

---

## 📁 โครงสร้างโปรเจกต์ (Project Structure)

```text
easyocr-project/
├── app/
│   ├── __init__.py
│   └── main.py              # โค้ดหลักของ FastAPI และการเรียกใช้ EasyOCR
├── Dockerfile                # คำสั่งสำหรับสร้าง Docker Image (Python 3.13-slim)
├── docker-compose.yml        # คอนฟิกสำหรับรัน Container พร้อม Volume สำหรับ Cache โมเดล
├── pyproject.toml            # รายการ Dependencies และการตั้งค่าโปรเจกต์
├── uv.lock                   # Lockfile ของ Dependencies
└── README.md
```

---

## 🚀 การติดตั้งและเริ่มใช้งาน (Getting Started)

### วิธีที่ 1: รันด้วย Docker Compose (แนะนำ)

เหมาะสำหรับ Production หรือการรันแบบไม่ต้องติดตั้ง Python และ Library ลงในเครื่องโดยตรง:

1. **สั่ง Build และ Start Container:**
   ```bash
   docker compose up --build
   ```
   *(หรือ `docker compose up -d --build` เพื่อรันเป็น Background Process)*

2. **ทดสอบการทำงาน:**
   เปิดเบราว์เซอร์ไปที่ [http://localhost:8000/docs](http://localhost:8000/docs)

3. **สั่งหยุดการทำงาน:**
   ```bash
   docker compose down
   ```

> [!TIP]
> โมเดล EasyOCR จะถูกดาวน์โหลดในครั้งแรกและบันทึกไว้ใน Docker Volume ชื่อ `easyocr_model_cache` ทำให้การ Start หรือ Rebuild ในครั้งถัดไปไม่ต้องเสียเวลาดาวน์โหลดใหม่

---

### วิธีที่ 2: รันบนเครื่อง Local ด้วย `uv`

เหมาะสำหรับการพัฒนา (Development) และแก้ไขโค้ด:

#### 1. ติดตั้ง `uv` (หากยังไม่มี)
```bash
# macOS / Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows (PowerShell)
powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

#### 2. ติดตั้ง Dependencies
```bash
uv sync
```

#### 3. รัน Development Server
```bash
uv run uvicorn app.main:app --reload --port 8000
```

---

## 📖 API Documentation

เมื่อเซิร์ฟเวอร์เริ่มทำงาน สามารถเข้าดูเอกสารและทดสอบ API แบบ Interactive ได้ที่:
- **Swagger UI:** [http://localhost:8000/docs](http://localhost:8000/docs)
- **ReDoc:** [http://localhost:8000/redoc](http://localhost:8000/redoc)

---

## 🔌 รายละเอียด Endpoint (API Endpoints)

### 1. Health Check
ตรวจสอบสถานะความพร้อมของเซิร์ฟเวอร์

- **Method:** `GET`
- **Path:** `/`
- **ตัวอย่าง Response:**
  ```json
  {
    "status": "ok",
    "message": "OCR Service is running"
  }
  ```

---

### 2. Process Image OCR
อัปโหลดไฟล์รูปภาพเพื่อประมวลผลข้อความ

- **Method:** `POST`
- **Path:** `/api/v1/ocr`
- **Header:** `Content-Type: multipart/form-data`
- **Body:**
  - `file`: ไฟล์รูปภาพ (`.jpg`, `.jpeg`, `.png`, ฯลฯ)

#### ตัวอย่างการเรียกใช้งานด้วย cURL:
```bash
curl -X POST "http://localhost:8000/api/v1/ocr" \
  -H "accept: application/json" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@/path/to/your/image.jpg"
```

#### ตัวอย่าง Response:
```json
{
  "success": true,
  "filename": "sample.jpg",
  "total_blocks": 2,
  "data": [
    {
      "id": 1,
      "text": "ยินดีต้อนรับ",
      "confidence": 0.9842,
      "top_left": [50, 100],
      "bottom_right": [220, 140],
      "raw_bbox": [
        [50, 100],
        [220, 100],
        [220, 140],
        [50, 140]
      ]
    },
    {
      "id": 2,
      "text": "Welcome to EasyOCR",
      "confidence": 0.9915,
      "top_left": [50, 150],
      "bottom_right": [310, 185],
      "raw_bbox": [
        [50, 150],
        [310, 150],
        [310, 185],
        [50, 185]
      ]
    }
  ]
}
```

---

## 📐 คำอธิบายข้อมูล Bounding Box ใน Response

| Field | ชนิดข้อมูล | คำอธิบาย |
| :--- | :--- | :--- |
| `id` | `int` | ลำดับข้อความที่ตรวจพบ |
| `text` | `string` | ข้อความที่ถอดรหัสได้จากภาพ |
| `confidence` | `float` | ค่าความเชื่อมั่นในการอ่าน (0.0 - 1.0) |
| `top_left` | `[x, y]` | พิกัดจุดบนซ้ายของกล่องข้อความ |
| `bottom_right` | `[x, y]` | พิกัดจุดล่างขวาของกล่องข้อความ |
| `raw_bbox` | `[[x, y], ...]` | พิกัดมุมทั้ง 4 จุดตามลำดับเข็มนาฬิกา (บนซ้าย, บนขวา, ล่างขวา, ล่างซ้าย) เหมาะกับข้อความที่ถ่ายมาเอียง |

---

## ☁️ การ Deploy ขึ้น AWS Lambda ด้วย Terraform (เน้นประหยัด Cost)

โปรเจกต์นี้มีชุดคำสั่ง **Terraform** สำหรับ Deploy ขึ้น **AWS Lambda (Container Image) + Lambda Function URL** อยู่ในโฟลเดอร์ [terraform/](file:///Users/amornpic/code/easyocr-project/terraform/):

- **Free HTTPS Endpoint:** ใช้ Lambda Function URL แทน API Gateway (ประหยัดค่า API Gateway 100%)
- **ARM64 Architecture:** ประมวลผลบน Graviton ประหยัดกว่า x86_64 ถึง 20%
- **Pre-baked Model Image:** อบโมเดลไว้ใน Docker Image ป้องกันปัญหา Read-only และลดเวลา Cold Start
- **Auto Image Cleanup:** ตั้ง ECR Lifecycle Policy เก็บเพียง 2 Images ล่าสุด ประหยัดค่า Storage

📖 ดูขั้นตอนการ Deploy อย่างละเอียดได้ที่ [terraform/README.md](file:///Users/amornpic/code/easyocr-project/terraform/README.md)

---

## ⚙️ การตั้งค่าเพิ่มเติม (Configuration)

หากต้องการเปลี่ยนภาษาหรือเปิดใช้งาน GPU สามารถปรับแต่งได้ในไฟล์ app/main.py


```python
# ตัวอย่าง: ปรับเปลี่ยนภาษาที่รองรับ และเปิดใช้งาน GPU หากเครื่องมี CUDA
reader = easyocr.Reader(['th', 'en'], gpu=True)
```
