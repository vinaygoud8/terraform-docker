# main.tf

# Configure the AWS provider
provider "aws" {
  region = "us-west-2"  
}

# Data source to fetch the latest Amazon Linux 2 AMI ID
data "aws_ami" "amazon_linux_2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

# Creating VPC
resource "aws_vpc" "my-vpc" {
  cidr_block       = "${var.vpc_cidr}"
  instance_tenancy = "default"
tags = {
  Name = "VPC-terradock"
}
}
# Creating 1st public subnet 
resource "aws_subnet" "public-SN-1" {
  vpc_id                  = "${aws_vpc.my-vpc.id}"
  cidr_block             = "${var.subnet1_cidr}"
  map_public_ip_on_launch = true
  availability_zone = "us-west-2a"
tags = {
  Name = "PUB-Subnet-1"
}
}
# Creating 2nd public subnet 
resource "aws_subnet" "public-SN-2" {
  vpc_id                  = "${aws_vpc.my-vpc.id}"
  cidr_block             = "${var.subnet2_cidr}"
  map_public_ip_on_launch = true
  availability_zone = "us-west-2b"
tags = {
  Name = "Pub-Subnet-2"
}
}
# Creating 1st private subnet 
resource "aws_subnet" "PRIVATE-SN-1" {
  vpc_id                  = "${aws_vpc.my-vpc.id}"
  cidr_block             = "${var.subnet3_cidr}"
  map_public_ip_on_launch = false
  availability_zone = "us-west-2b"
tags = {
  Name = "PRIVATE-SN-1"
}
}
# Creating Internet Gateway 
resource "aws_internet_gateway" "IGway" {
  vpc_id = "${aws_vpc.my-vpc.id}"
}
# Creating Custum Route Table 
resource "aws_route_table" "Custum" {
  vpc_id = "${aws_vpc.my-vpc.id}"
route {
      cidr_block = "0.0.0.0/0"
      gateway_id = "${aws_internet_gateway.IGway.id}"
  }
tags = {
      Name = "Public-RT"
  }
}
# Associating Route Table
resource "aws_route_table_association" "RT1" {
  subnet_id = "${aws_subnet.public-SN-1.id}"
  route_table_id = "${aws_route_table.Custum.id}"
}
resource "aws_route_table_association" "RT2" {
  subnet_id = "${aws_subnet.public-SN-2.id}"
  route_table_id = "${aws_route_table.Custum.id}"
}
# Create a security group allowing HTTP traffic and specific IP for SSH
resource "aws_security_group" "nginx_sg" {
  name        = "nginx-sg"
  description = "Security group for Nginx server"
  vpc_id      = "${aws_vpc.my-vpc.id}"

  ingress {
    description = "Allow HTTP inbound traffic"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH access from specific IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "nginx-sg"
  }
}

# Create a target group for the load balancer
resource "aws_lb_target_group" "nginx_tg" {
  name     = "nginx-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "${aws_vpc.my-vpc.id}"

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# Create an ALB
resource "aws_lb" "nginx_alb" {
  name               = "nginx-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.nginx_sg.id]
  subnets            = [aws_subnet.public-SN-1.id, aws_subnet.public-SN-2.id]

  tags = {
    Name = "nginx-alb"
  }
}

# Create a listener for the ALB
resource "aws_lb_listener" "nginx_listener" {
  load_balancer_arn = aws_lb.nginx_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nginx_tg.arn
  }
}

# EC2 instance to run Dockerized Nginx server
resource "aws_instance" "nginx_instance" {
  ami             = data.aws_ami.amazon_linux_2.id
  instance_type   = var.instance_type
  key_name        = var.key_name
  subnet_id       = "${aws_subnet.public-SN-1.id}"
  security_groups = [aws_security_group.nginx_sg.id]
  tags = {
    Name = "nginx-instance"
  }
  user_data = <<-EOF
 #!/bin/bash
              yum update -y
              amazon-linux-extras install docker -y
              service docker start
              usermod -a -G docker ec2-user

              # Log in to Docker Hub
              docker login -u ${var.docker_hub_username} -p ${var.docker_hub_password}

              # Pull the Docker image from Docker Hub
              docker pull ${var.docker_hub_username}/${var.docker_image_name}:${var.docker_image_tag}

              # Run the Docker container
              docker run -d -p 80:80 ${var.docker_hub_username}/${var.docker_image_name}:${var.docker_image_tag}
 EOF
  
}
# Resource to log in to Docker Hub
resource "null_resource" "docker_hub_login" {
  provisioner "local-exec" {
    # Use echo to pipe the password into the Docker login command
    command = <<EOT
      echo ${var.docker_hub_password} | docker login -u ${var.docker_hub_username} -p ${var.docker_hub_password}
    EOT

    # Only run the command if the username or password changes
    environment = {
      DOCKER_HUB_USERNAME = var.docker_hub_username
      DOCKER_HUB_PASSWORD = var.docker_hub_password
    }
  }

  triggers = {
    docker_hub_username = var.docker_hub_username
    docker_hub_password = var.docker_hub_password
  }
}
# Locally build the Docker image
resource "null_resource" "build_docker_image" {
  provisioner "local-exec" {
    command = <<EOT
      docker build -t ${var.docker_hub_username}/${var.docker_image_name}:${var.docker_image_tag} ${var.docker_file_path}
    EOT
  }

  triggers = {
    image = "${var.docker_hub_username}/${var.docker_image_name}:${var.docker_image_tag}"
  }
}

# push the image to docker registry
resource "null_resource" "push_docker_image" {
  provisioner "local-exec" {
    command = <<EOT
      docker push ${var.docker_hub_username}/${var.docker_image_name}:${var.docker_image_tag}
    EOT
  }

  depends_on = [null_resource.build_docker_image]

  triggers = {
    image = "${var.docker_hub_username}/${var.docker_image_name}:${var.docker_image_tag}"
  }
}
# pull the image from docker registry
resource "null_resource" "pull_docker_image" {
  provisioner "local-exec" {
    command = <<EOT
      docker pull ${var.docker_hub_username}/${var.docker_image_name}:${var.docker_image_tag}
      docker run -d -p 80:80 ${var.docker_hub_username}/${var.docker_image_name}:${var.docker_image_tag}
     EOT
  }

  depends_on = [null_resource.build_docker_image]

  triggers = {
    image = "${var.docker_hub_username}/${var.docker_image_name}:${var.docker_image_tag}"
  }
}
output "docker_image_uri" {
  value = "${var.docker_hub_username}/${var.docker_image_name}:${var.docker_image_tag}"
}
# Attach the EC2 instance to the target group
resource "aws_lb_target_group_attachment" "nginx_attachment" {
  target_group_arn = aws_lb_target_group.nginx_tg.arn
  target_id        = aws_instance.nginx_instance.id
  port             = 80
}
