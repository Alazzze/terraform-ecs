provider "aws" {
  region = "us-east-1"
}

# Оголошення змінних
variable "name" {
  description = "Prefix for resource names"
  type        = string
  default     = "myapp"
}

variable "image_id" {
  description = "The AMI ID for the instances"
  type        = string
  default     = "ami-04a81a99f5ec58529"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "iam_instance_profile" {
  description = "IAM instance profile name"
  type        = string
  default     = "ecsInstanceProfile"
}

variable "key_name" {
  description = "SSH key name for the instances"
  type        = string
  default     = "alazze"
}

variable "associate_public_ip_address" {
  description = "Associate a public IP address with the instance"
  type        = bool
  default     = true
}

variable "volume_size" {
  description = "Size of the EBS volume in GB"
  type        = number
  default     = 20
}

# VPC
resource "aws_vpc" "stas_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "stas-vpc"
  }
}

# Subnets
resource "aws_subnet" "stas_subnet1" {
  vpc_id            = aws_vpc.stas_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "stas-subnet1"
  }
}

resource "aws_subnet" "stas_subnet2" {
  vpc_id            = aws_vpc.stas_vpc.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "stas-subnet2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "stas_internet_gateway" {
  vpc_id = aws_vpc.stas_vpc.id

  tags = {
    Name = "stas-internet-gateway"
  }
}

# Route Table
resource "aws_route_table" "stas_route_table" {
  vpc_id = aws_vpc.stas_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.stas_internet_gateway.id
  }

  tags = {
    Name = "stas-route-table"
  }
}

# Route Table Association
resource "aws_route_table_association" "stas_route_table_association1" {
  subnet_id      = aws_subnet.stas_subnet1.id
  route_table_id = aws_route_table.stas_route_table.id
}

resource "aws_route_table_association" "stas_route_table_association2" {
  subnet_id      = aws_subnet.stas_subnet2.id
  route_table_id = aws_route_table.stas_route_table.id
}

# Security Group
resource "aws_security_group" "stas_security_group" {
  vpc_id = aws_vpc.stas_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "stas-security-group"
  }
}

resource "aws_security_group_rule" "allow_all_tcp_from_sg" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "tcp"
  security_group_id        = aws_security_group.stas_security_group.id
  source_security_group_id = aws_security_group.stas_security_group.id
}

# Application Load Balancer
resource "aws_lb" "stas_load_balancer" {
  name                        = "stas-load-balancer"
  internal                    = false
  load_balancer_type          = "application"
  security_groups             = [aws_security_group.stas_security_group.id]
  subnets                     = [aws_subnet.stas_subnet1.id, aws_subnet.stas_subnet2.id]
  enable_deletion_protection  = false
  enable_cross_zone_load_balancing = true
  idle_timeout                = 60
  drop_invalid_header_fields  = true

  tags = {
    Name = "stas-load-balancer"
  }
}

# Target Group
resource "aws_lb_target_group" "nginx_target_group" {
  name       = "nginx-target-group"
  port       = 80
  protocol   = "HTTP"
  vpc_id     = aws_vpc.stas_vpc.id
  target_type = "instance"

  health_check {
    interval            = 30
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "nginx-target-group"
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "nginx_listener" {
  load_balancer_arn = aws_lb.stas_load_balancer.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_target_group.arn
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ecs-task-execution-role"
  }
}

resource "aws_iam_policy" "ecs_task_execution_policy" {
  name        = "ecsTaskExecutionPolicy"
  description = "IAM policy for ECS task execution"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_policy.arn
}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_role" {
  name = "ecsTaskRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ecs-task-role"
  }
}

resource "aws_iam_policy" "ecs_task_policy" {
  name        = "ecsTaskPolicy"
  description = "IAM policy for ECS task"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_role_policy_attachment" {
  role       = aws_iam_role.ecs_task_role.name
  policy_arn = aws_iam_policy.ecs_task_policy.arn
}

# IAM Role for ECS Instances
resource "aws_iam_role" "ecs_instance_role" {
  name = "ecsInstanceRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "ecs-instance-role"
  }
}

resource "aws_iam_policy" "ecs_instance_policy" {
  name        = "ecsInstancePolicy"
  description = "IAM policy for ECS instances"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:CreateCluster",
          "ecs:DeregisterContainerInstance",
          "ecs:DiscoverPollEndpoint",
          "ecs:ListContainerInstances",
          "ecs:ListClusters",
          "ecs:RegisterContainerInstance",
          "ecs:StartTelemetrySession",
          "ecs:UpdateContainerInstancesState",
          "ecs:SubmitTaskStateChange"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_instance_role_policy_attachment" {
  role       = aws_iam_role.ecs_instance_role.name
  policy_arn = aws_iam_policy.ecs_instance_policy.arn
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecsInstanceProfile"
  role = aws_iam_role.ecs_instance_role.name
}

# Launch Template
resource "aws_launch_template" "ecs_launch_template" {
  name_prefix   = "${var.name}-ecs-"
  image_id      = var.image_id
  instance_type = var.instance_type
  iam_instance_profile {
    name = var.iam_instance_profile
  }
  key_name  = var.key_name

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Оновлюємо пакети
    sudo apt-get update -y
    sudo apt-get upgrade -y

    # Встановлюємо Docker
    sudo apt-get install -y docker.io
    sudo systemctl start docker
    sudo systemctl enable docker

    # Завантажуємо та встановлюємо Amazon ECS агент
    curl -O https://s3.us-east-1.amazonaws.com/amazon-ecs-agent-us-east-1/amazon-ecs-init-latest.amd64.deb
    sudo dpkg -i amazon-ecs-init-latest.amd64.deb

    # Налаштовуємо конфігурацію ECS
    echo "ECS_CLUSTER=my-ecs-cluster" | sudo tee /etc/ecs/ecs.config

    # Запускаємо ecs.service
    sudo systemctl enable --now ecs.service --no-block
  EOF
  )

  network_interfaces {
    associate_public_ip_address = var.associate_public_ip_address
    security_groups             = [aws_security_group.stas_security_group.id]
  }

  block_device_mappings {
    device_name = "/dev/xvda"

    ebs {
      volume_size           = var.volume_size
      volume_type           = "gp2"
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs_asg" {
  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.stas_subnet1.id, aws_subnet.stas_subnet2.id]
  min_size             = 1
  max_size             = 2
  desired_capacity     = 1

  tag {
    key                 = "Name"
    value               = "${var.name}-ecs-instance"
    propagate_at_launch = true
  }

  depends_on = [
    aws_launch_template.ecs_launch_template
  ]
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "nginx_task_definition" {
  family                   = "nginx"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn
  network_mode             = "bridge"
  container_definitions    = jsonencode([{
    name      = "nginx"
    image     = "nginx:latest"
    cpu       = 256
    memory    = 512
    essential = true
    portMappings = [
      {
        containerPort = 80
        hostPort      = 80
      }
    ]
  }])
}

# ECS Service
resource "aws_ecs_service" "nginx_service" {
  name            = "nginx-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.nginx_task_definition.arn
  desired_count   = 3
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = aws_lb_target_group.nginx_target_group.arn
    container_name   = "nginx"
    container_port   = 80
  }

  depends_on = [
    aws_lb_listener.nginx_listener
  ]
}
