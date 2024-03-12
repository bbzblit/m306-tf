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


resource "aws_key_pair" "deplpoyment_key" {
  key_name   = "deployer-key"
  public_key = var.ssh_key
}


resource "aws_instance" "webapp" {
  ami           = "ami-058bd2d568351da34"
  instance_type = "t2.micro"
  key_name = aws_key_pair.deplpoyment_key.key_name
  
  security_groups = [
    aws_security_group.app_sg.id
  ]

  tags = {
    Name = "webapp"
  }
}

resource "aws_db_instance" "appdb" {
  allocated_storage    = 10
  db_name = "oursql"
  engine = "mysql"
  engine_version = "8.0.35"
  username = "oursql_app_user"
  password = var.db_password
  instance_class = "db.t3.micro"

  vpc_security_group_ids = [
    aws_security_group.db_sg.id
  ]
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

resource "aws_subnet" "app_net" {
  vpc_id     = aws_default_vpc.default.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "AppNet"
  }
}
resource "aws_subnet" "db_net" {
  vpc_id     = aws_default_vpc.default.id
  cidr_block = "10.0.2.0/24"

  tags = {
    Name = "DBNet"
  }
}

resource "aws_network_acl" "db_acl" {
  vpc_id = aws_default_vpc.default.id
  egress = [{
    from_port   = 0
    to_port     = 0
    action = "allow"
    rule_no = 100
    protocol = -1

    ipv6_cidr_block = null
    icmp_code = null
    icmp_type = null
    cidr_block = null
  }]

  ingress = [ {
    from_port   = 0
    to_port     = 0
    action = "allow"
    rule_no = 100
    cidr_block  = "10.0.1.0/24"
    protocol = -1

    ipv6_cidr_block = null
    icmp_code = null
    icmp_type = null
  }]

  subnet_ids = [
    aws_subnet.db_net.id
  ]
}


resource "aws_network_acl" "app_acl" {
  vpc_id = aws_default_vpc.default.id
  egress = [{
    from_port   = 0
    to_port     = 0
    action = "allow"
    rule_no = 100
    protocol = -1

    cidr_block = null
    icmp_code = null
    icmp_type = null
    ipv6_cidr_block = null 
  }]

  ingress = [{
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    action  = "allow"
    rule_no = 100
    
    cidr_block = null
    icmp_code = null
    icmp_type = null
    ipv6_cidr_block = null 
  }]

  subnet_ids = [
    aws_subnet.app_net.id
  ]  
}


resource "aws_security_group" "db_sg" {
  name = "db-sg"
  description = "Security group for the App DB"
  vpc_id = aws_default_vpc.default.id


  ingress = [{
    from_port = 0
    to_port = 3306
    protocol = "tcp"
    cidr_blocks = ["10.0.1.0/24"]
    description = "Allow access to db from appnet"

    ipv6_cidr_blocks = []
    prefix_list_ids = []
    security_groups = []
    self = false
  }]
}


resource "aws_security_group" "app_sg" {
  name = "app-sg"
  description = "Security group for the App"
  vpc_id = aws_default_vpc.default.id

  ingress = [
    {
      from_port = 0
      to_port = 80
      protocol = "tcp"
      cidr_blocks = []
      ipv6_cidr_blocks = []
      prefix_list_ids = []
      security_groups = []
      self = false
      description = "Allo http traffic"
    }
  ]
}


resource "aws_lb" "app_alb" {
  name = "app-alb"
  internal = false
  load_balancer_type = "application"
  subnets = [
    aws_subnet.app_net.id 
  ]

  tags = {
    Environment = "production"
  }
}