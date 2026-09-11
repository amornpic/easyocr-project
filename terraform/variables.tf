variable "aws_region" {
  description = "AWS Region to deploy resources"
  type        = string
  default     = "ap-southeast-1" # Singapore (ใกล้ไทย ค่า latency ต่ำ)
}

variable "app_name" {
  description = "Application and resource naming prefix"
  type        = string
  default     = "easyocr-api"
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
  default     = "prod"
}

variable "image_tag" {
  description = "Docker image tag in ECR"
  type        = string
  default     = "latest"
}

variable "lambda_memory_size" {
  description = "Memory size for Lambda function in MB (2048 MB provides ~1.2 vCPU, optimal price/performance for OCR)"
  type        = number
  default     = 2048
}

variable "lambda_timeout" {
  description = "Lambda execution timeout in seconds"
  type        = number
  default     = 60
}

variable "floci_endpoint" {
  description = "Endpoint URL for Floci or LocalStack local emulator (e.g. http://localhost:4566). Leave empty for real AWS."
  type        = string
  default     = ""
}

