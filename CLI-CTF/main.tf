locals {
  prefix       = "awscli-ctf"
  ecs_vcpu     = "256"
  ecs_memory   = "512"
  rds_user     = "ctfd_admin"
  rds_pass     = "StrongPasswordHere"
  region       = "us-east-1"
  current_date = formatdate("MMDDYYYY", timestamp())
}

provider "aws" {
  region = "us-east-1" # Set your desired AWS region
}

#Create the Hello-World Bucket
resource "aws_s3_bucket" "S3HelloWorldBucket" {
  bucket = "bucketsofunsandomstuffasdf1234567890-flag-h3llow0rld" # Flag Bucket
  #bucket = "testbucket-jslkdfja123810923u0us08afd8af08sad0"
  tags = {
    Note = "Great_Job_you_found_the_first_flag"
  }
}

resource "aws_s3_bucket" "awsctf_files_bucket" {
  bucket = "awsctffiles-bucket-${local.current_date}-1234567890"
  tags = {
    Note = "Nothing_to_see_here_i_promise"
  }
}


#Upload CTF Files


resource "aws_s3_object" "awsctf_files_bucket_ctf_flag_png" {
  bucket = aws_s3_bucket.awsctf_files_bucket.id
  key    = "download-me.png"
  source = "./download-me.png" # Set the local file path
}

#Setup CTF Network

resource "aws_vpc" "this" {
  cidr_block = "10.255.255.0/24"
  tags = {
    Name = "${local.prefix}_Network"
  }
}

# Setup Internet for Public Subnets
resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.prefix}-internet-gateway"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.prefix}-public-route-table"
  }
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public_subnet" {
  subnet_id      = aws_subnet.ctf_public_subnet.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "ctf_public_subnet" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.255.255.0/25"
  availability_zone = "us-east-1a" # Set the desired availability zone
  tags = {
    Name = "Public Subnet"
  }
}

resource "aws_subnet" "ctf_private_subnet" {
  vpc_id            = aws_vpc.this.id
  cidr_block        = "10.255.255.128/25"
  availability_zone = "us-east-1a" # Set the desired availability zone
  tags = {
    Name = "Private Subnet"
  }
}

resource "aws_eip" "ctf_ec2_web_eip" {
  vpc = true
}

#Create an EC2 Web Server
data "aws_ami" "latest_amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "ctf_web_ec2" {
  ami                         = data.aws_ami.latest_amazon_linux.id
  instance_type               = "t2.micro"                      # Replace with the desired instance type
  subnet_id                   = aws_subnet.ctf_public_subnet.id #put in Public Subnet
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.ctf_web_sg.id]

  user_data = <<-EOF
    #!/bin/bash
    sudo su
    yum update -y
    yum install -y httpd.x86_64
    yum install -y jq
    REGION_AV_ZONE=`curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq .availabilityZone`
    systemctl start httpd.service
    systemctl enable httpd.service
    echo "<h1>Welcome CloudSource! </h1>" > /var/www/html/index.html
    echo "<br>The Flag is the Availability Zone: <b>$REGION_AV_ZONE </b>" >> /var/www/html/index.html
    service httpd start
  EOF

  tags = {
    Name = "CTF_Web_EC2"
  }
}

resource "aws_security_group" "ctf_web_sg" {
  name        = "ctf-web-sg"
  description = "Security group for CTF web server"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}