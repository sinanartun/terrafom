provider "aws" {
  region  = "eu-west-1"
  profile = "terraform"
}

resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-terraform-vpc"
  }
}

data "aws_availability_zones" "available" {}


resource "aws_subnet" "public" {
  count                                       = 3
  vpc_id                                      = aws_vpc.main.id
  cidr_block                                  = cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)
  map_public_ip_on_launch                     = true
  availability_zone                           = data.aws_availability_zones.available.names[count.index % length(data.aws_availability_zones.available.names)]
  enable_resource_name_dns_a_record_on_launch = true

  tags = {
    Name = "public-subnet-terraform-${count.index + 1}"
  }
}


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main2-igw"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "public-route-table"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  count          = 3
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}


resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow SSH and HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}


resource "aws_key_pair" "deployer" {
  key_name   = "deployer-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

resource "aws_instance" "host" {
  ami           = "ami-04e49d62cf88738f1"  # Replace with your desired AMI ID
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public[0].id
  key_name      = aws_key_pair.deployer.key_name

  vpc_security_group_ids = [aws_security_group.web_sg.id]  # Use security group ID instead of name

  user_data = file("user_data.sh")  # Reference to the external bash script

  tags = {
    Name = "terraform-instance"
  }
}
