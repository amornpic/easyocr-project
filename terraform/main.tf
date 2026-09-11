terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # การตั้งค่าสำหรับ Floci / LocalStack (ใช้เฉพาะเมื่อกำหนด floci_endpoint)
  access_key                  = var.floci_endpoint != "" ? "mock_key" : null
  secret_key                  = var.floci_endpoint != "" ? "mock_secret" : null
  skip_credentials_validation = var.floci_endpoint != ""
  skip_metadata_api_check     = var.floci_endpoint != ""
  skip_requesting_account_id  = var.floci_endpoint != ""

  dynamic "endpoints" {
    for_each = var.floci_endpoint != "" ? [1] : []
    content {
      ecr    = var.floci_endpoint
      lambda = var.floci_endpoint
      iam    = var.floci_endpoint
      logs   = var.floci_endpoint
      sts    = var.floci_endpoint
    }
  }

  default_tags {
    tags = {
      Project     = var.app_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}


# -----------------------------------------------------------------------------
# 1. ECR Repository (จัดเก็บ Docker Image)
# -----------------------------------------------------------------------------
resource "aws_ecr_repository" "ocr_repo" {
  name                 = "${var.app_name}-${var.environment}"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# กำหนด Lifecycle Policy เพื่อลบ Image เก่าทิ้งอัตโนมัติ ช่วยลดค่าจัดเก็บ ECR (Cost Optimization)
resource "aws_ecr_lifecycle_policy" "ocr_repo_policy" {
  repository = aws_ecr_repository.ocr_repo.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep only last 2 images to minimize ECR storage cost"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 2
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# 2. IAM Role สำหรับ Lambda
# -----------------------------------------------------------------------------
resource "aws_iam_role" "lambda_role" {
  name = "${var.app_name}-${var.environment}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# ให้สิทธิ์ Lambda เขียน CloudWatch Logs
resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# -----------------------------------------------------------------------------
# 3. CloudWatch Log Group (ตั้งวันหมดอายุ 7 วัน เพื่อลดค่าเก็บ Log)
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.app_name}-${var.environment}"
  retention_in_days = 7
}

# -----------------------------------------------------------------------------
# 4. AWS Lambda Function (ARM64 + Container Image)
# -----------------------------------------------------------------------------
resource "aws_lambda_function" "ocr_function" {
  function_name = "${var.app_name}-${var.environment}"
  role          = aws_iam_role.lambda_role.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.ocr_repo.repository_url}:${var.image_tag}"

  # สถาปัตยกรรม arm64 (Graviton) ราคาประหยัดกว่า x86_64 ถึง 20%
  architectures = ["arm64"]

  # Memory 2048 MB ได้ประมาณ 1.2 vCPU เป็นจุดคุ้มค่า (ประมวลผล OCR เร็วและลด GB-seconds รวม)
  memory_size = var.lambda_memory_size
  timeout     = var.lambda_timeout

  environment {
    variables = {
      PORT                 = "8000"
      EASYOCR_MODULE_PATH  = "/app/models"
      PYTHONUNBUFFERED     = "1"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.lambda_basic_execution,
    aws_cloudwatch_log_group.lambda_logs
  ]
}

# -----------------------------------------------------------------------------
# 5. Lambda Function URL (ฟรี 100% แทน API Gateway)
# -----------------------------------------------------------------------------
resource "aws_lambda_function_url" "ocr_url" {
  function_name      = aws_lambda_function.ocr_function.function_name
  authorization_type = "NONE"

  cors {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["*"]
    allow_headers     = ["*"]
    expose_headers    = ["*"]
    max_age           = 86400
  }
}

# เปิดสิทธิ์ Public เข้าถึง Function URL (จำเป็นสำหรับ AWS จริง แต่ Floci จะสร้างให้อัตโนมัติอยู่แล้ว)
resource "aws_lambda_permission" "public_function_url" {
  count = var.floci_endpoint != "" ? 0 : 1

  statement_id           = "FunctionURLAllowPublicAccess"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.ocr_function.function_name
  principal              = "*"
  function_url_auth_type = "NONE"
}
