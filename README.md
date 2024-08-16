# Terraform AWS ECS Setup

This project uses Terraform to set up AWS infrastructure, including VPC, subnets, security groups, an application load balancer, an Auto Scaling Group, an ECS cluster, task definitions, and ECS services.

## Components Overview

- **VPC (Virtual Private Cloud)**: Creates a VPC with CIDR block `10.0.0.0/16`.
- **Subnets**: Two subnets in different availability zones.
- **Internet Gateway**: Attaches an internet gateway to the VPC.
- **Route Table**: Configures a route for internet access.
- **Security Group**: Configures a security group allowing all TCP traffic.
- **Application Load Balancer (ALB)**: Sets up an ALB for distributing traffic to ECS tasks.
- **Target Group**: Configures a target group for the ALB.
- **IAM Roles and Policies**: Creates IAM roles and policies for ECS task execution and EC2 instances.
- **Launch Template**: Creates a launch template for EC2 instances.
- **Auto Scaling Group**: Configures an Auto Scaling Group for ECS instances.
- **ECS Cluster**: Creates an ECS cluster.
- **ECS Task Definition**: Defines an ECS task with a NGINX container.
- **ECS Service**: Sets up an ECS service with three instances of the task.

## Setup

1. **Install Terraform**

   Follow the [official Terraform documentation](https://learn.hashicorp.com/terraform) for installation instructions.

2. **Prerequisites**

   - AWS CLI configured with the correct credentials.
   - Permissions to create the required resources in AWS.

3. **Configuration and Deployment**

   Clone the repository and navigate to the Terraform configuration folder:

   ```bash
   git clone <REPOSITORY-URL>
   cd <REPOSITORY-FOLDER>
