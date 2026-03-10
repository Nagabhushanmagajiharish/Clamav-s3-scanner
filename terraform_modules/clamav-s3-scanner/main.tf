data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iam_policy_document" "task_execution_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "scan_queue" {
  statement {
    sid     = "AllowSourceBucketEvents"
    actions = ["sqs:SendMessage"]

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    resources = [aws_sqs_queue.scan.arn]

    condition {
      test     = "ArnEquals"
      variable = "aws:SourceArn"
      values   = [var.source_bucket_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

data "aws_iam_policy_document" "scanner_task" {
  statement {
    sid = "ListBuckets"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket"
    ]
    resources = [
      var.source_bucket_arn,
      aws_s3_bucket.clean.arn,
      aws_s3_bucket.infected.arn
    ]
  }

  statement {
    sid = "ManageObjects"
    actions = [
      "s3:AbortMultipartUpload",
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:GetObjectTagging",
      "s3:PutObject",
      "s3:PutObjectTagging"
    ]
    resources = [
      "${var.source_bucket_arn}/*",
      "${aws_s3_bucket.clean.arn}/*",
      "${aws_s3_bucket.infected.arn}/*"
    ]
  }

  statement {
    sid = "ConsumeScanQueue"
    actions = [
      "sqs:ChangeMessageVisibility",
      "sqs:DeleteMessage",
      "sqs:GetQueueAttributes",
      "sqs:ReceiveMessage"
    ]
    resources = [aws_sqs_queue.scan.arn]
  }
}

locals {
  name = "${var.resource_prefix}-${var.environment}-clamav"

  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Service     = "clamav-s3-scanner"
  }
}

resource "aws_s3_bucket" "clean" {
  bucket = "${local.name}-clean"
  tags   = merge(local.common_tags, { Name = "${local.name}-clean" })
}

resource "aws_s3_bucket" "infected" {
  bucket = "${local.name}-infected"
  tags   = merge(local.common_tags, { Name = "${local.name}-infected" })
}

resource "aws_s3_bucket_public_access_block" "clean" {
  bucket = aws_s3_bucket.clean.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "infected" {
  bucket = aws_s3_bucket.infected.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_sqs_queue" "dlq" {
  name                      = "${local.name}-dlq"
  message_retention_seconds = 1209600
  tags                      = local.common_tags
}

resource "aws_sqs_queue" "scan" {
  name                       = "${local.name}-scan"
  visibility_timeout_seconds = 900
  receive_wait_time_seconds  = 20
  message_retention_seconds  = 345600
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dlq.arn
    maxReceiveCount     = 5
  })
  tags = local.common_tags
}

resource "aws_sqs_queue_policy" "scan" {
  queue_url = aws_sqs_queue.scan.id
  policy    = data.aws_iam_policy_document.scan_queue.json
}

resource "aws_s3_bucket_notification" "source_events" {
  bucket = var.source_bucket_name

  queue {
    queue_arn     = aws_sqs_queue.scan.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = var.object_prefix
  }

  depends_on = [aws_sqs_queue_policy.scan]
}

resource "aws_cloudwatch_log_group" "scanner" {
  name              = "/ecs/${local.name}"
  retention_in_days = 14
  tags              = local.common_tags
}

resource "aws_security_group" "scanner" {
  name        = "${local.name}-sg"
  description = "Security group for the ClamAV scanner service"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_iam_role" "execution" {
  name               = "${local.name}-execution"
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "task" {
  name               = "${local.name}-task"
  assume_role_policy = data.aws_iam_policy_document.task_execution_assume_role.json
  tags               = local.common_tags
}

resource "aws_iam_policy" "task" {
  name   = "${local.name}-task"
  policy = data.aws_iam_policy_document.scanner_task.json
  tags   = local.common_tags
}

resource "aws_iam_role_policy_attachment" "task" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task.arn
}

resource "aws_ecs_task_definition" "scanner" {
  family                   = local.name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.scanner_cpu)
  memory                   = tostring(var.scanner_memory)
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    {
      name      = "scanner"
      image     = var.scanner_image
      essential = true
      environment = [
        { name = "AWS_REGION", value = data.aws_region.current.name },
        { name = "QUEUE_URL", value = aws_sqs_queue.scan.id },
        { name = "SOURCE_BUCKET", value = var.source_bucket_name },
        { name = "CLEAN_BUCKET", value = aws_s3_bucket.clean.bucket },
        { name = "INFECTED_BUCKET", value = aws_s3_bucket.infected.bucket },
        { name = "OBJECT_PREFIX", value = var.object_prefix },
        { name = "DELETE_SOURCE_OBJECT", value = tostring(var.delete_source_object) }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.scanner.name
          awslogs-region        = data.aws_region.current.name
          awslogs-stream-prefix = "scanner"
        }
      }
    }
  ])

  tags = local.common_tags
}

resource "aws_ecs_service" "scanner" {
  name                               = local.name
  cluster                            = var.ecs_cluster_arn
  task_definition                    = aws_ecs_task_definition.scanner.arn
  desired_count                      = var.desired_count
  launch_type                        = "FARGATE"
  enable_execute_command             = true
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200
  tags                               = local.common_tags

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.scanner.id]
    assign_public_ip = var.assign_public_ip
  }
}
