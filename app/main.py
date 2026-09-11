import os
from fastapi import FastAPI, UploadFile, File, HTTPException
import easyocr
import numpy as np
import cv2

app = FastAPI(
    title="EasyOCR Microservice",
    description="API สำหรับประมวลผลภาพเป็นข้อความด้วย EasyOCR",
    version="1.0.0"
)

# 1. กำหนดโฟลเดอร์สำหรับโหลดโมเดล:
# - หากรันใน Container/Lambda จะใช้ '/app/models' (ที่อบโมเดลไว้ล่วงหน้า) หรือตามที่ระบุใน EASYOCR_MODULE_PATH
# - หากรัน Local จะใช้ค่าเริ่มต้นของ EasyOCR (~/.EasyOCR)
model_storage_dir = os.getenv("EASYOCR_MODULE_PATH")
if not model_storage_dir and os.path.exists("/app/models"):
    model_storage_dir = "/app/models"

# โหลด EasyOCR Model ไว้ตอนสปินอัปแอปพลิเคชัน (โหลดครั้งเดียวใช้งานยาวๆ)
if model_storage_dir:
    reader = easyocr.Reader(['th', 'en'], gpu=False, model_storage_directory=model_storage_dir)
else:
    reader = easyocr.Reader(['th', 'en'], gpu=False)

@app.get("/")
def health_check():
    return {"status": "ok", "message": "OCR Service is running"}

@app.post("/api/v1/ocr")
def process_image_ocr(file: UploadFile = File(...)):
    # 1. ตรวจสอบชนิดไฟล์เบื้องต้น
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="ไฟล์ที่อัปโหลดต้องเป็นรูปภาพเท่านั้น")

    try:
        # 2. อ่านไฟล์รูปภาพจาก Request Bytes
        contents = file.file.read()
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
            raise HTTPException(status_code=400, detail="ไม่สามารถอ่านไฟล์ภาพได้")

        # ปรับขนาดภาพลงหากขนาดใหญ่เกินไป เพื่อลดระยะเวลาประมวลผล CPU และประหยัด Cost บน Lambda
        h, w = img.shape[:2]
        max_dim = 1600
        scale = 1.0
        if max(h, w) > max_dim:
            scale = max_dim / max(h, w)
            img = cv2.resize(img, (int(w * scale), int(h * scale)), interpolation=cv2.INTER_AREA)

        # 3. รัน EasyOCR ประมวลผลภาพ
        results = reader.readtext(img)

        # 4. จัดโครงสร้างข้อมูล JSON สำหรับ Response (แปลงพิกัดกลับสู่ขนาดรูปภาพต้นฉบับ)
        inv_scale = 1.0 / scale
        extracted_data = []
        for idx, (bbox, text, prob) in enumerate(results, 1):
            top_left = [int(bbox[0][0] * inv_scale), int(bbox[0][1] * inv_scale)]
            bottom_right = [int(bbox[2][0] * inv_scale), int(bbox[2][1] * inv_scale)]
            raw_bbox = [[int(pt[0] * inv_scale), int(pt[1] * inv_scale)] for pt in bbox]

            extracted_data.append({
                "id": idx,
                "text": text,
                "confidence": round(float(prob), 4),
                "top_left": top_left,
                "bottom_right": bottom_right,
                "raw_bbox": raw_bbox
            })

        return {
            "success": True,
            "filename": file.filename,
            "total_blocks": len(extracted_data),
            "data": extracted_data
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"เกิดข้อผิดพลาดในการประมวลผล: {str(e)}")