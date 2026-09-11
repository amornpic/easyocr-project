from fastapi import FastAPI, UploadFile, File, HTTPException
import easyocr
import numpy as np
import cv2

app = FastAPI(
    title="EasyOCR Microservice",
    description="API สำหรับประมวลผลภาพเป็นข้อความด้วย EasyOCR",
    version="1.0.0"
)

# โหลด EasyOCR Model ไว้ตอนสปินอัปแอปพลิเคชัน (โหลดครั้งเดียวใช้งานยาวๆ)
# gpu=False สำหรับรันบน CPU ใน Container มาตรฐาน
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

        # 3. รัน EasyOCR ประมวลผลภาพ
        results = reader.readtext(img)

        # 4. จัดโครงสร้างข้อมูล JSON สำหรับ Response
        extracted_data = []
        for idx, (bbox, text, prob) in enumerate(results, 1):
            extracted_data.append({
                "id": idx,
                "text": text,
                "confidence": round(float(prob), 4),
                "top_left": [int(bbox[0][0]), int(bbox[0][1])],
                "bottom_right": [int(bbox[2][0]), int(bbox[2][1])],
                "raw_bbox": [[int(pt[0]), int(pt[1])] for pt in bbox]
            })

        return {
            "success": True,
            "filename": file.filename,
            "total_blocks": len(extracted_data),
            "data": extracted_data
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"เกิดข้อผิดพลาดในการประมวลผล: {str(e)}")