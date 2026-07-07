terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket = "prod-aws-tf-state-save"
    key    = "state/terraform.tfstate"
    region = "ap-southeast-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# ─── RUNNER VARIABLES ───
variable "public_key_data" {
  type        = string
  description = "Content of your aws_new_key.pub file"
}

variable "private_key_pub_data" {
  type        = string
  description = "Content of your isg_rsa.pub file"
}

# ─── AWS KEY PAIRS ───
resource "aws_key_pair" "aws_course_key_pair_public" {
  key_name   = "aws-course-key-public"
  public_key = var.public_key_data
}

resource "aws_key_pair" "aws_course_key_pair_private" {
  key_name   = "aws-course-key-private"
  public_key = var.private_key_pub_data
}

# ─── NETWORKING FOUNDATION ───
resource "aws_vpc" "aws_course_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "aws-course-vpc" }
}

resource "aws_subnet" "aws_course_public_subnet" {
  vpc_id                  = aws_vpc.aws_course_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "ap-southeast-2a"
  tags                    = { Name = "aws-course-public-subnet" }
}

resource "aws_subnet" "aws_course_private_subnet" {
  vpc_id                  = aws_vpc.aws_course_vpc.id
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "ap-southeast-2b"
  tags                    = { Name = "aws-course-private-subnet" }
}

resource "aws_internet_gateway" "aws_course_igw" {
  vpc_id = aws_vpc.aws_course_vpc.id
  tags   = { Name = "aws-course-igw" }
}

resource "aws_eip" "aws_course_nat_eip" {
  domain     = "vpc"
  tags       = { Name = "aws-course-nat-eip" }
  depends_on = [aws_internet_gateway.aws_course_igw]
}

resource "aws_nat_gateway" "aws_course_nat_gw" {
  allocation_id = aws_eip.aws_course_nat_eip.id
  subnet_id     = aws_subnet.aws_course_public_subnet.id
  tags          = { Name = "aws-course-nat-gw" }
  depends_on    = [aws_internet_gateway.aws_course_igw]
}

# ─── ROUTE TABLES ───
resource "aws_route_table" "aws_course_public_rt" {
  vpc_id = aws_vpc.aws_course_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.aws_course_igw.id
  }
  tags = { Name = "aws-course-public-rt" }
}

resource "aws_route_table_association" "aws_course_public_rt_assoc" {
  subnet_id      = aws_subnet.aws_course_public_subnet.id
  route_table_id = aws_route_table.aws_course_public_rt.id
}

resource "aws_route_table" "aws_course_private_rt" {
  vpc_id = aws_vpc.aws_course_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.aws_course_nat_gw.id
  }
  tags = { Name = "aws-course-private-rt" }
}

resource "aws_route_table_association" "aws_course_private_rt_assoc" {
  subnet_id      = aws_subnet.aws_course_private_subnet.id
  route_table_id = aws_route_table.aws_course_private_rt.id
}

# ─── SECURITY GROUPS ───
resource "aws_security_group" "aws_course_public_sg" {
  name        = "aws-course-sg"
  description = "Security group for AWS course"
  vpc_id      = aws_vpc.aws_course_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "aws-course-sg" }
}

resource "aws_security_group" "aws_course_private_sg" {
  name        = "aws-course-private-sg"
  description = "Security group for AWS course private subnet"
  vpc_id      = aws_vpc.aws_course_vpc.id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.aws_course_public_sg.id]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.aws_course_public_sg.id]
  }

  ingress {
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.1.0/24"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "aws-course-private-sg" }
}

# ─── EC2 INSTANCES ───
resource "aws_instance" "aws_course_public_instance" {
  ami                         = "ami-0a59248a6294cece2"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.aws_course_public_subnet.id
  key_name                    = aws_key_pair.aws_course_key_pair_public.key_name
  vpc_security_group_ids      = [aws_security_group.aws_course_public_sg.id]
  associate_public_ip_address = true

  tags = { Name = "aws-course-public-instance" }
}

resource "aws_instance" "aws_course_private_instance" {
  ami                         = "ami-0a59248a6294cece2"
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.aws_course_private_subnet.id
  key_name                    = aws_key_pair.aws_course_key_pair_private.key_name
  vpc_security_group_ids      = [aws_security_group.aws_course_private_sg.id]
  associate_public_ip_address = false

  tags = { Name = "aws-course-private-instance" }
}

# ─── OUTPUTS ───
output "public_instance_public_ip" {
  value = aws_instance.aws_course_public_instance.public_ip
}
output "public_instance_private_ip" {
  value = aws_instance.aws_course_public_instance.private_ip
}
output "private_instance_private_ip" {
  value = aws_instance.aws_course_private_instance.private_ip
}