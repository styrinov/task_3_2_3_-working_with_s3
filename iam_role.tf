resource "aws_iam_policy" "s3_read_policy" {
  name        = "ReadDockerComposeBucketPolicy"
  description = "Allow read access to the Docker Compose bucket"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.docker_compose_bucket_name}",
          "arn:aws:s3:::${var.docker_compose_bucket_name}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role" "ec2_role" {
  name = "WebInstanceS3ReadRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach_s3_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

resource "aws_iam_instance_profile" "ec2_instance_profile" {
  name = "WebInstanceProfile"
  role = aws_iam_role.ec2_role.name
}
