data "aws_ami" "this" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_vpc" "this" {
  tags = { "Name" : "eksctl-basic-cilium-cluster/VPC" }
}

data "aws_subnets" "this" {
  filter {
    name   = "tag:alpha.eksctl.io/cluster-name"
    values = ["basic-cilium"]
  }
}

resource "aws_instance" "this" {
  ami           = data.aws_ami.this.id
  instance_type = "t3.micro"
  subnet_id     = data.aws_subnets.this.ids[0]

  tags = {
    Name = "HelloWorld"
  }

  vpc_security_group_ids = [aws_security_group.this.id]

  user_data = <<-EOF
   #!/bin/bash
   yum install -y nginx
   systemctl start nginx
   EOF
}

resource "aws_security_group" "this" {
  name        = "web_80"
  description = "Allow web inbound traffic"
  vpc_id      = data.aws_vpc.this.id

  ingress {
    description = "80 from VPC"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "web_80"
  }
}

output "security_group_id" {
  description = "security group id"
  value       = aws_security_group.this.id
}

output "private_ip" {
  description = "private ip"
  value       = aws_instance.this.private_ip
}
