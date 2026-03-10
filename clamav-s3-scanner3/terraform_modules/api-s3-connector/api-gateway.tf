#=======================================================================
# 01 API gateway 
#=======================================================================

resource "aws_apigatewayv2_api" "api" {
  name          = "${var.resource_prefix}-api"
  protocol_type = "HTTP"
}

#=======================================================================
# 02 API gateway Integration with Lambda
#=======================================================================

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.presign_lambda.invoke_arn
  payload_format_version = "2.0"
}


#=======================================================================
# 03 API gateway Route
#=======================================================================

resource "aws_apigatewayv2_route" "get_upload_url" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /upload-url"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

#=======================================================================
# 03 API gateway Deploy Stage
#=======================================================================
resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}