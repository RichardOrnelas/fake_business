############################
#########   VPC   ##########
############################
### @note VPC ###
resource "aws_vpc" "primary" {
  cidr_block           = local.vpc_cidr_blocks[terraform.workspace]
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project}-${terraform.workspace}"
  }
}

### @note PUBLIC NETWORK ###

resource "aws_internet_gateway" "primary" {
  vpc_id = aws_vpc.primary.id

  tags = {
    Name    = var.project
    Network = "public"
  }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.primary.id
  cidr_block              = cidrsubnet(aws_vpc.primary.cidr_block, 6, count.index + 40)
  availability_zone       = local.availability_zones[count.index]
  count                   = local.az_count
  map_public_ip_on_launch = true

  tags = {
    Name             = "public-${local.availability_zones[count.index]}"
    Network          = "public"
    Access           = "public"
    AvailabilityZone = local.availability_zones[count.index]
  }
}

resource "aws_route_table_association" "public" {
  count          = local.az_count
  subnet_id      = element(aws_subnet.public[*].id, count.index)
  route_table_id = aws_route_table.primary_public.id
}

resource "aws_route_table" "primary_public" {
  vpc_id = aws_vpc.primary.id

  tags = {
    Name    = "primary_public"
    Network = "public"
    Access  = "public"
  }
}

resource "aws_route" "primary_internet_public" {
  depends_on             = [aws_route_table.primary_public]
  route_table_id         = aws_route_table.primary_public.id
  gateway_id             = aws_internet_gateway.primary.id
  destination_cidr_block = "0.0.0.0/0"
}

### @note PRIVATE NETWORK ###

resource "aws_nat_gateway" "primary" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name    = "nat-${var.project}"
    Network = "public"
  }
}

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name    = "nat-${var.project}"
    Network = "public"
  }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.primary.id
  cidr_block        = cidrsubnet(aws_vpc.primary.cidr_block, 6, count.index + 20)
  availability_zone = local.availability_zones[count.index]
  count             = local.az_count
  # map_private_ip_on_launch = true

  tags = {
    Name             = "private-${local.availability_zones[count.index]}"
    Network          = "private"
    Access           = "private"
    AvailabilityZone = local.availability_zones[count.index]
  }
}

resource "aws_route_table_association" "private" {
  count          = local.az_count
  subnet_id      = element(aws_subnet.private[*].id, count.index)
  route_table_id = aws_route_table.primary_private.id
}

resource "aws_route_table" "primary_private" {
  vpc_id = aws_vpc.primary.id

  tags = {
    Name    = "primary_private"
    Network = "private"
    Access  = "private"
  }
}

resource "aws_route" "primary_nat_private" {
  depends_on             = [aws_route_table.primary_private]
  route_table_id         = aws_route_table.primary_private.id
  nat_gateway_id         = aws_nat_gateway.primary.id
  destination_cidr_block = "0.0.0.0/0"
}


############################
######## FLOW LOGS #########
############################

resource "aws_flow_log" "primary" {
  log_destination      = aws_s3_bucket.flow_logs.arn
  log_destination_type = "s3"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.primary.id
  destination_options {
    file_format        = "parquet"
    per_hour_partition = true
  }
}

resource "aws_flow_log" "flow_logs" {
  iam_role_arn    = aws_iam_role.flow_logs.arn
  log_destination = aws_cloudwatch_log_group.flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.primary.id
}

resource "aws_cloudwatch_log_group" "flow_logs" {
  name = "${var.project}-vpc-flow-logs"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["vpc-flow-logs.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "flow_logs" {
  name               = "${var.project}-vpc-flow-logs"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "aws_iam_policy_document" "flow_logs" {
  statement {
    effect = "Allow"

    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams",
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "flow_logs" {
  name   = "${var.project}-flow-logs"
  role   = aws_iam_role.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs.json
}

resource "aws_s3_bucket" "flow_logs" {
  bucket = "${var.project}-vpc-flow-logs-${terraform.workspace}"
}

resource "aws_s3_bucket_logging" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id

  target_bucket = aws_s3_bucket.flow_logs.id
  target_prefix = "_bucket_access_logs"
}

resource "aws_s3_bucket_policy" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  policy = data.aws_iam_policy_document.flow_logs_bucket.json
}

resource "aws_s3_bucket_ownership_controls" "flow_logs" {
  bucket = aws_s3_bucket.flow_logs.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "flow_logs" {
  depends_on = [aws_s3_bucket_ownership_controls.flow_logs]

  bucket = aws_s3_bucket.flow_logs.id
  acl    = "private"
}

data "aws_iam_policy_document" "flow_logs_bucket" {
  statement {

    actions = ["s3:*"]
    resources = [
      "${aws_s3_bucket.flow_logs.arn}/*",
      aws_s3_bucket.flow_logs.arn
    ]
    principals {
      type = "Service"
      identifiers = [
        "delivery.logs.amazonaws.com",
        "logdelivery.elasticloadbalancing.amazonaws.com",
        "vpc-flow-logs.amazonaws.com"
      ]
    }
  }
}
