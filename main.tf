terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
  token = var.aws_access_token
}


data "aws_key_pair" "deplpoyment_key" {
  key_name   = "deployer-key"
}

data "aws_availability_zones" "available" {}

resource "aws_instance" "webapp" {
  ami           = "ami-058bd2d568351da34"
  instance_type = "t2.micro"
  associate_public_ip_address = true
  key_name = data.aws_key_pair.deplpoyment_key.key_name
  subnet_id = aws_subnet.app_net[0].id
  availability_zone = data.aws_availability_zones.available.names[0]
  vpc_security_group_ids = [
    aws_security_group.app_sg.id
  ]

  tags = {
    Name = "webapp"
  }
}

resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "db_subnet_group"
  subnet_ids = [for subnet in aws_subnet.db_net : subnet.id]
}

resource "aws_db_instance" "appdb" {
  allocated_storage    = 10
  db_name = "oursql"
  engine = "mysql"
  engine_version = "8.0.35"
  username = "oursql_app_user"
  password = var.db_password
  instance_class = "db.t3.micro"
  skip_final_snapshot = true
  db_subnet_group_name = aws_db_subnet_group.db_subnet_group.name
  vpc_security_group_ids = [
    aws_security_group.db_sg.id
  ]
}

resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_subnet" "app_net" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "10.0.${10+count.index}.0/24"  
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count = "${length(data.aws_availability_zones.available.names)}"
  tags = {
    Name = "app_net"
  }
}


resource "aws_subnet" "db_net" {
  vpc_id     = aws_vpc.default.id
  cidr_block = "10.0.${20+count.index}.0/24"  
  availability_zone = "${data.aws_availability_zones.available.names[count.index]}"
  count = "${length(data.aws_availability_zones.available.names)}"
  tags = {
    Name = "db_net"
  }
}

resource "aws_network_acl" "db_acl" {
  vpc_id = aws_vpc.default.id
  
  egress {
    from_port = 0
    to_port = 0
    action = "allow"
    rule_no = 100
    protocol = -1
    cidr_block = "0.0.0.0/0"
  }

  subnet_ids = [
    for subnet in aws_subnet.db_net : subnet.id
  ]
}


resource "aws_network_acl" "app_acl" {
  vpc_id = aws_vpc.default.id
  
  egress {
    from_port = 0
    to_port = 0
    action = "allow"
    rule_no = 100
    protocol = -1
    cidr_block = "0.0.0.0/0"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    action  = "allow"
    rule_no = 100
    cidr_block = "0.0.0.0/0"
  }

  subnet_ids = [
    for subnet in aws_subnet.app_net : subnet.id
  ]  
}


resource "aws_security_group" "db_sg" {
  name = "db-sg"
  description = "Security group for the App DB"
  vpc_id = aws_vpc.default.id
}


resource "aws_security_group_rule" "db_allow_all_app_traffic" {
  type = "ingress"
  from_port = 0
  to_port = 3306
  protocol = "tcp"
  cidr_blocks = [for subnet in aws_subnet.app_net : subnet.cidr_block]
  security_group_id = aws_security_group.db_sg.id
}

resource "aws_security_group" "app_sg" {
  name = "app-sg"
  description = "Security group for the App"
  vpc_id = aws_vpc.default.id
}