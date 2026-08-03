# IAM role assumed by the private app EC2 instance.
# Demonstrates least-privilege: read-only access to a single, specific S3 bucket
# instead of using long-lived access keys on the instance.

resource "aws_iam_role" "app_instance_role" {
  name = "${var.project_name}-app-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "s3_read_only" {
  name = "${var.project_name}-s3-read-only"
  role = aws_iam_role.app_instance_role.id

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
          "arn:aws:s3:::${var.project_name}-demo-bucket",
          "arn:aws:s3:::${var.project_name}-demo-bucket/*"
        ]
      }
    ]
  })
}

# Attach the AWS-managed SSM policy so you can also connect via Session Manager
# instead of SSH — no bastion or open port 22 required.
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.app_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "app_instance_profile" {
  name = "${var.project_name}-app-instance-profile"
  role = aws_iam_role.app_instance_role.name
}
