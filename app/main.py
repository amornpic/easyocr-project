import os
import base64
import urllib.request
import ssl
from fastapi import FastAPI, UploadFile, File, HTTPException
from pydantic import BaseModel
import easyocr
import numpy as np
import cv2

app = FastAPI(
    title="EasyOCR Microservice",
    description="API สำหรับประมวลผลภาพเป็นข้อความด้วย EasyOCR",
    version="1.0.0"
)

model_storage_dir = os.getenv("EASYOCR_MODULE_PATH")
if not model_storage_dir and os.path.exists("/app/models"):
    model_storage_dir = "/app/models"

if model_storage_dir:
    reader = easyocr.Reader(["th", "en"], gpu=False, model_storage_directory=model_storage_dir)
else:
    reader = easyocr.Reader(["th", "en"], gpu=False)


def _run_ocr(img_bytes: bytes, filename: str = "image") -> dict:
    nparr = np.frombuffer(img_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="ไม่สามารถอ่านไฟล์ภาพได้")
    h, w = img.shape[:2]
    max_dim = 1600
    scale = 1.0
    if max(h, w) > max_dim:
        scale = max_dim / max(h, w)
        img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)
    results = reader.readtext(img)
    inv_scale = 1.0 / scale
    extracted_data = []
    for idx, (bbox, text, prob) in enumerate(results, 1):
        top_left = [int(bbox[0][0] * inv_scale), int(bbox[0][1] * inv_scale)]
        bottom_right = [int(bbox[2][0] * inv_scale), int(bbox[2][1] * inv_scale)]
        raw_bbox = [[int(pt[0] * inv_scale), int(pt[1] * inv_scale)] for pt in bbox]
        extracted_data.append({"id": idx, "text": text, "confidence": round(float(prob), 4),
            "top_left": top_left, "bottom_right": bottom_right, "raw_bbox": raw_bbox})
    return {"success": True, "filename": filename, "total_blocks": len(extracted_data), "data": extracted_data}


@app.get("/")
def health_check():
    return {"status": "ok", "message": "OCR Service is running"}


@app.post("/api/v1/ocr")
async def process_image_file(file: UploadFile = File(...)):
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="ไฟล์ที่อัปโหลดต้องเป็นรูปภาพเท่านั้น")
    try:
        contents = await file.read()
        return _run_ocr(contents, file.filename or "upload")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"เกิดข้อผิดพลาดในการประมวลผล: {str(e)}")


class OcrBase64Request(BaseModel):
    image_base64: str
    filename: str = "image.png"


@app.post("/api/v1/ocr/base64")
def process_image_base64(req: OcrBase64Request):
    try:
        img_bytes = base64.b64decode(req.image_base64)
        return _run_ocr(img_bytes, req.filename)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"เกิดข้อผิดพลาดในการประมวลผล: {str(e)}")


class OcrUrlRequest(BaseModel):
    image_url: str
    filename: str = "image.png"


@app.post("/api/v1/ocr/url")
def process_image_url(req: OcrUrlRequest):
    try:
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        with urllib.request.urlopen(req.image_url, context=ctx, timeout=15) as resp:
            img_bytes = resp.read()
        return _run_ocr(img_bytes, req.filename or req.image_url.split("/")[-1])
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"ไม่สามารถดาวน์โหลดหรือประมวลผลภาพ: {str(e)}")
