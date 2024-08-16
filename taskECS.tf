provider "aws" {
  region = "us-east-1"
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
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "stas-security-group"
  }
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
          "ecr:BatchCheckLayerAvailability"
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
  name_prefix   = "stasec2-"
  image_id      = "ami-0c8e23f950c7725b9" # Amazon Linux 2 AMI
  instance_type = "t3.medium"
  iam_instance_profile {
    name = aws_iam_instance_profile.ecs_instance_profile.name
  }
  key_name = "alazze"
  
  network_interfaces {
    associate_public_ip_address = true
    security_groups             = [aws_security_group.stas_security_group.id]
  }

  user_data = base64encode(<<EOF
#!/bin/bash
# Update the package repository
sudo yum update -y

# Install Docker
sudo amazon-linux-extras install docker -y
sudo systemctl start docker
sudo systemctl enable docker

# Install ECS agent
sudo yum install -y ecs-init

# Enable and start the ECS service
sudo systemctl enable --now ecs.service

# Configure ECS
cat << ECS_CONFIG > /etc/ecs/ecs.config
ECS_CLUSTER=stasECStask
ECS_ENGINE_TASK_CLEANUP_WAIT_DURATION=5m
ECS_IMAGE_CLEANUP_INTERVAL=10m
ECS_AVAILABLE_LOGGING_DRIVERS=["json-file","awslogs"]
ECS_LOGFILE=/log/ecs-agent.log
ECS_CONFIG
EOF
  )
}

# Auto Scaling Group
resource "aws_autoscaling_group" "ecs_asg" {
  desired_capacity     = 1
  max_size             = 2
  min_size             = 1
  launch_template {
    id      = aws_launch_template.ecs_launch_template.id
    version = "$Latest"
  }
  vpc_zone_identifier = [aws_subnet.stas_subnet1.id, aws_subnet.stas_subnet2.id]
  health_check_type   = "EC2"
  health_check_grace_period = 300
  force_delete        = true
  tag {
    key                 = "Name"
    value               = "ecs-instance"
    propagate_at_launch = true
  }
}

# ECS Cluster
resource "aws_ecs_cluster" "stas_ecs_cluster" {
  name = "stasECStask"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "nginx_task" {
  family                   = "nginx"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  network_mode             = "bridge"
  container_definitions    = jsonencode([
    {
      name      = "nginx"
      image     = "nginx:latest"
      memory    = 512            
      memoryReservation = 256    
      cpu       = 256
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
  requires_compatibilities = ["EC2"]
}
