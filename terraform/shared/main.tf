module "ecr_repository" {
  source = "git::ssh://git@github.com/paidy/terraform-aws-ecr.git?ref=v1.3.0"

  name = "nexus3"
}

resource "aws_ecr_lifecycle_policy" "mcp_tools_ecr_repo_lifecycle_policy" {
  repository = module.ecr_repository.repository_name

  policy = <<EOF
  {
  "rules": [
    {
      "rulePriority": 1,
      "description": "Expire images older than 30 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 30
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}
