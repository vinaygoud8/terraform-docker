# variables.tf


variable "key_name" {
  description = "key pair to lanch ec2 instance"
  default = "docker-newkey.pem"
  type = string
}

variable "docker_hub_username" {
  description = "Docker Hub username"
  type        = string
  default = "vinaydocker08"
}

variable "docker_hub_password" {
  description = "Docker Hub password"
  default = "VIHAa@160424"
  type        = string
  sensitive   = true
}

variable "docker_image_name" {
  description = "Name of the Docker image to build and push to Docker Hub"
  default     = "nginx-static"
  type        = string
}
variable "docker_image_tag" {
  description = "The Docker image tag to use"
  type        = string
  default     = "latest"
}
variable "docker_file_path" {
  description = "The path to the Dockerfile directory"
  default = "."
  type        = string
}
# Defining CIDR Block for VPC
variable "vpc_cidr" {
  default = "30.0.0.0/16"
}
# Defining CIDR Block for 1st Subnet
variable "subnet1_cidr" {
  default = "30.0.1.0/24"
}
# Defining CIDR Block for 2nd Subnet
variable "subnet2_cidr" {
  default = "30.0.2.0/24"
}
# Defining CIDR Block for 3rd Subnet
variable "subnet3_cidr" {
  default = "30.0.3.0/24"
}
variable "availability_zones" {
  description = "List of availability zones to use for the subnets"
  default     = ["us-west-2a", "us-west-2b"]
}

variable "instance_type" {
  description = "Instance type to use for the EC2 instance"
  default     = "t2.micro"
}

variable "ssh_allowed_ip" {
  description = "IP address allowed to SSH into the EC2 instance"
  default     = "0.0.0.0/0"  # Replace with your actual IP address in CIDR notation, e.g., "123.45.67.89/32"
}
