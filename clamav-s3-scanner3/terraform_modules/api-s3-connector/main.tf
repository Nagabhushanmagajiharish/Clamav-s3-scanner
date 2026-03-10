#=======================================================================
# Lambda Python
#=======================================================================

resource "aws_s3_bucket" "upload-bucket-bushan-2001" {
  bucket = "${var.resource_prefix}-s3-bucket"
  tags = {
    Name = "upload-bucket"
  }
}

resource "aws_s3_bucket_cors_configuration" "upload_cors" {
  bucket = aws_s3_bucket.upload-bucket-bushan-2001.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"] # Required for uploads
    allowed_origins = ["*"]   # Replace with your frontend domain
    max_age_seconds = 3000
  }
}

#=======================================================================
# Lambda Python
#=======================================================================

resource "aws_iam_role" "lambda_role" {
  name = "${var.resource_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "s3_upload_policy" {
  name = "${var.resource_prefix}-lambda-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = [
        "s3:PutObject",
        "s3:GetObject"
      ]
      Effect   = "Allow"
      Resource = "${aws_s3_bucket.upload-bucket-bushan-2001.arn}/*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.s3_upload_policy.arn
}


data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_function.py"
  output_path = "${path.module}/function.zip"
}

resource "aws_lambda_function" "presign_lambda" {
  function_name = "${var.resource_prefix}-lambda"

  role    = aws_iam_role.lambda_role.arn
  handler = "lambda_function.lambda_handler"
  runtime = "python3.11"

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      BUCKET_NAME = aws_s3_bucket.upload-bucket-bushan-2001.bucket
      REGION      = data.aws_region.current.name
    }
  }
}

# Allow API Gateway to Invoke Lambda

resource "aws_lambda_permission" "api_gw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presign_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}