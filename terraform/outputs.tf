output "ecr_repository_url" {
  description = "ECR Repository URL for pushing the Docker image"
  value       = aws_ecr_repository.ocr_repo.repository_url
}

output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.ocr_function.function_name
}

output "lambda_function_url" {
  description = "Direct HTTPS endpoint for EasyOCR API (Free, no API Gateway charges)"
  value       = aws_lambda_function_url.ocr_url.function_url
}

output "deploy_commands" {
  description = "Commands to build and push Docker image to ECR"
  value       = <<EOT
# 1. Login to ECR
aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${aws_ecr_repository.ocr_repo.repository_url}

# 2. Build Docker Image (ARM64 สำหรับ Lambda Graviton ประหยัดกว่า 20%)
docker buildx build --platform linux/arm64 -t ${aws_ecr_repository.ocr_repo.repository_url}:${var.image_tag} --push .

# 3. Update Lambda with new image
aws lambda update-function-code --function-name ${aws_lambda_function.ocr_function.function_name} --image-uri ${aws_ecr_repository.ocr_repo.repository_url}:${var.image_tag} --region ${var.aws_region}
EOT
}
