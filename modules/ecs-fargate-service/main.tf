# Fetch the default VPC and subnets for our account
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# 1. ECR: Container Registry
resource "aws_ecr_repository" "app" {
  name                 = "portfolio-visitor-counter"
  image_tag_mutability = "MUTABLE"
}

# 2. ECS: Cluster
resource "aws_ecs_cluster" "main" {
  name = "portfolio-cluster"
}

# 3. IAM: Role for the ECS Task
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [{
      Action    = "sts:AssumeRole",
      Effect    = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# 4. Networking: Security Groups
resource "aws_security_group" "lb_sg" {
  name        = "portfolio-lb-sg"
  description = "Allow HTTP traffic to the load balancer"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_sg" {
  name        = "portfolio-ecs-sg"
  description = "Allow traffic from the LB to the ECS tasks"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    protocol        = "tcp"
    from_port       = 8000
    to_port         = 8000
    security_groups = [aws_security_group.lb_sg.id]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 5. Networking: Load Balancer
resource "aws_lb" "app" {
  name               = "portfolio-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

resource "aws_lb_target_group" "app" {
  name        = "portfolio-app-tg"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

# 6. ECS: Task Definition and Service
resource "aws_ecs_task_definition" "app" {
  family                   = "visitor-counter-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"  # 0.25 vCPU
  memory                   = "512"  # 512 MB
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([{
    name      = "visitor-counter-container"
    image     = "${aws_ecr_repository.app.repository_url}:latest" # We'll push an image with the 'latest' tag
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
    }]
    environment = [
      { name = "TABLE_NAME", value = "visitor-counter-table" },
      { name = "PRIMARY_KEY", value = "visitor_count" },
      { name = "AWS_REGION", value = var.aws_region }
    ]
  }])
}

resource "aws_ecs_service" "main" {
  name            = "visitor-counter-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = data.aws_subnets.default.ids
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app.arn
    container_name   = "visitor-counter-container"
    container_port   = 8000
  }

  # This ensures the service waits for the load balancer to be ready.
  depends_on = [aws_lb_listener.http]
}