# Deploy EasyOCR on AWS Lambda using Terraform

ชุดคำสั่ง Terraform สำหรับ Deploy **EasyOCR FastAPI** ขึ้น **AWS Lambda (Container Image) + Lambda Function URL** โดยปรับแต่งเน้น **ประหยัดค่าใช้จ่าย (Cost Optimization)** เป็นหลัก

---

## 💰 จุดเด่นด้าน Cost Optimization ในชุดนี้

1. **Lambda Function URL (ฟรี 100%):** ใช้ HTTPS Endpoint ตรงจาก Lambda โดยไม่ต้องเสียเงินรายเดือนหรือราย Request ให้กับ API Gateway
2. **สถาปัตยกรรม ARM64 (Graviton):** ค่าประมวลผลถูกกว่า x86_64 ถึง 20%
3. **Memory 2048 MB (Sweet Spot):** ให้ CPU ประมาณ 1.2 vCPU ทำให้ OCR รูปเสร็จเร็วขึ้น และกิน GB-seconds รวมน้อยลง
4. **ECR Lifecycle Policy:** ลบ Image เก่าอัตโนมัติ เหลือเก็บเพียง 2 เวอร์ชั่นล่าสุด เพื่อลดค่าเช่าพื้นที่ ECR
5. **Pre-baked Models:** ดาวน์โหลดและใส่โมเดลไว้ใน Image ตั้งแต่ตอนบิลด์ ทำให้ไม่มีปัญหา Read-Only บน Lambda และ Cold Start เร็วขึ้น
6. **Log Retention 7 วัน:** บันทึก CloudWatch Log เพียง 7 วัน ไม่เสียค่าเก็บ Log ระยะยาว

---

## 🛠️ ขั้นตอนการ Deploy ทีละสเต็ป

### ขั้นตอนที่ 1: สร้าง ECR Repository ด้วย Terraform

เนื่องจาก Lambda ต้องใช้ Docker Image ที่อยู่บน ECR ในครั้งแรกเราจะสร้าง ECR ขึ้นมาก่อน:

```bash
cd terraform

# 1. เริ่มต้น Terraform
terraform init

# 2. สร้าง ECR Repository ก่อน (โดย target ไปที่ ECR)
terraform apply -target=aws_ecr_repository.ocr_repo -target=aws_ecr_lifecycle_policy.ocr_repo_policy
```

---

### ขั้นตอนที่ 2: บิลด์และ Push Docker Image ขึ้น ECR

ดู URL ของ ECR จาก Output ของขั้นตอนที่ 1 แล้วรันคำสั่งบิลด์ (เลือก platform เป็น `linux/arm64`):

```bash
# กลับมาที่โฟลเดอร์ root ของโปรเจกต์
cd ..

# กำหนดตัวแปร ECR_URL (นำมาจาก terraform output)
ECR_URL=$(terraform -chdir=terraform output -raw ecr_repository_url)
AWS_REGION="ap-southeast-1"

# 1. Login เข้าสู่ AWS ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_URL

# 2. Build และ Push Image สำหรับ ARM64
docker buildx build --platform linux/arm64 -t $ECR_URL:latest --push .
```

---

### ขั้นตอนที่ 3: สร้าง Lambda Function และ Function URL

เมื่อมี Image บน ECR แล้ว ให้รันคำสั่งสร้าง Resource ทั้งหมด:

```bash
cd terraform
terraform apply
```

เมื่อคำสั่งทำงานเสร็จสิ้น คุณจะได้รับ **`lambda_function_url`** เช่น:
```text
lambda_function_url = "https://xxxxxx.lambda-url.ap-southeast-1.on.aws/"
```

---

## 🧪 การทดสอบเรียกใช้งาน API

คุณสามารถใช้ URL ที่ได้ไปเรียกทดสอบได้ทันที:

### 1. Health Check
```bash
curl -X GET "https://xxxxxx.lambda-url.ap-southeast-1.on.aws/"
```

### 2. ส่งรูปไปทำ OCR
```bash
curl -X POST "https://xxxxxx.lambda-url.ap-southeast-1.on.aws/api/v1/ocr" \
  -H "accept: application/json" \
  -H "Content-Type: multipart/form-data" \
  -F "file=@/path/to/your/image.jpg"
```

### 3. เปิดดู Swagger UI บน Browser
เข้า URL: `https://xxxxxx.lambda-url.ap-southeast-1.on.aws/docs`

---

## 🔄 การอัปเดตโค้ดในอนาคต (Deploy Update)

เมื่อมีการแก้โค้ดในอนาคต เพียงแค่บิลด์ image ใหม่แล้วสั่งอัปเดต Lambda ได้เลยโดยไม่ต้องรัน Terraform ซ้ำ:

```bash
# 1. Build & Push Image ใหม่
docker buildx build --platform linux/arm64 -t $ECR_URL:latest --push .

# 2. แจ้ง Lambda ให้อัปเดตโค้ด
aws lambda update-function-code \
  --function-name easyocr-api-prod \
  --image-uri $ECR_URL:latest \
  --region ap-southeast-1
```

---

## 💻 การทดลองรันใน Local ร่วมกับ Floci (Local AWS Emulator)

หากต้องการทดสอบการ Deploy และการทำงานของ Terraform ในเครื่อง Local โดย**ไม่ต้องใช้ AWS Account จริง และไม่มีค่าใช้จ่าย**:

### 1. เปิด Floci Container
```bash
docker run -d --name floci \
  -p 4566:4566 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  floci/floci:latest
```
*(ถ้าใช้ OrbStack บน macOS สามารถใช้ `-v ~/.orbstack/run/docker.sock:/var/run/docker.sock`)*

### 2. รัน Terraform กับ Floci
ใช้ไฟล์คอนฟิก `floci.tfvars` ที่เตรียมไว้ให้:
```bash
cd terraform
terraform init
terraform apply -var-file="floci.tfvars"
```

### 3. ลบ Resource บน Floci หลังทดสอบเสร็จ
```bash
terraform destroy -var-file="floci.tfvars"
```

---

## 🧹 การลบ Resource ทั้งหมดบน AWS จริง (Clean up)

เมื่อไม่ต้องการใช้งานแล้ว และต้องการลบทุกอย่างออกจาก AWS เพื่อไม่ให้มีค่าใช้จ่ายหลงเหลือ:

```bash
cd terraform
terraform destroy
```

