resource "aws_key_pair" "mini_project" {
  key_name   = "mini_project"
  public_key = file("~/.ssh/cloud2024.pem.pub")
}
resource "aws_vpc" "vpc" {
  cidr_block           = "172.16.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    name = "${var.prefix}-vpc"
  }
}
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.prefix}-igw"
  }
}
# resource "aws_eip" "eip" {
#   for_each = var.ec2
#   instance     = aws_instance.server[each.key].id
#   domain       = "vpc"
#   # depends_on                = [aws_internet_gateway.gw]
# }
resource "aws_route_table" "rt_public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.prefix}-rtb-public"
  }
}
# resource "aws_main_route_table_association" "rt_public" {
#   vpc_id = aws_vpc.vpc.id
#   route_table_id = aws_route_table.rt_public.id
  
# }
resource "aws_route_table" "rt_private" {
  vpc_id = aws_vpc.vpc.id
  for_each = var.private_subnets

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.nat[each.key].id
  }

  tags = {
    Name = "${var.prefix}-rtb-private"
  }
}
resource "aws_route_table_association" "rta_public" {
  for_each       = var.public_subnets
  subnet_id      = aws_subnet.public_subnets[each.key].id
  route_table_id = aws_route_table.rt_public.id
}
# resource "aws_route_table_association" "rt_public" {
#   subnet_id = aws_subnet.public_subnets[each.key]
#   route_table_id = aws_route_table.rt_public
#   }  
resource "aws_route_table_association" "rta_private" {
  for_each       = var.private_subnets
  subnet_id      = aws_subnet.private_subnets[each.key].id
  route_table_id = aws_route_table.rt_private[each.key].id
}
resource "aws_nat_gateway" "nat" {
  for_each = var.public_subnets
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public_subnets[each.key].id
  tags = {
    Name        = "nat"
    Environment = "${var.prefix}-nat"
  }
  # depends_on = [aws_internet_gateway.igw]
}

resource "aws_subnet" "public_subnets" {
  vpc_id                  = aws_vpc.vpc.id
  for_each                = var.public_subnets
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true # To ensure the instance gets a public IP

  tags = {
    Name = "${each.value.name}-public-subnet"
  }
}
resource "aws_subnet" "private_subnets" {
  vpc_id                  = aws_vpc.vpc.id
  for_each                = var.private_subnets
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  # map_public_ip_on_launch = true # To ensure the instance gets a public IP

  tags = {
    Name = "${each.value.name}-private-subnet"
  }
}
# resource "aws_nat_gateway" "m_p" {
#   allocation_id = aws_eip.lb.id
#   subnet_id     = aws_subnet.public_subnets[each.key].id

#   tags = {
#     Name = "gw NAT"
#   }
#   # To ensure proper ordering, it is recommended to add an explicit dependency
#   # on the Internet Gateway for the VPC.
# }
resource "aws_instance" "server" {

  for_each      = var.ec2
  ami           = "ami-0230bd60aa48260c6"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.mini_project.key_name

  subnet_id = aws_subnet.private_subnets[each.key].id
  #vpc_security_group_ids = [module.security_groups.security_group_id["cloud_2023_sg"]] 
  vpc_security_group_ids = [module.security-groups.security_group_id["Mini_proj_sg"]]
  user_data              = <<-EOF
              #!/bin/bash
              sudo yum update -y
              sudo yum install -y httpd
              sudo systemctl start httpd.service
              sudo systemctl enable httpd.service
              sudo echo "<h1> HELLO from ${each.value.server_name} </h1>" > /var/www/html/index.html                  
              EOF
  tags = {
    Name = join("_", [var.prefix, each.key])
  }
}
module "security-groups" {
  source          = "app.terraform.io/sanjarbey/security-groups/aws"
  version         = "2.0.0"
  vpc_id          = aws_vpc.vpc.id
  security_groups = var.security-groups
}
# resource "aws_nat_gateway" "ngw" {
#   for_each      = var.public_subnets
#   subnet_id     = aws_subnet.public_subnets[each.key].id
#   allocation_id = aws_eip.nat[each.key].id
# }
# resource "aws_route_table" "private_subnets" {
#   for_each       = var.private_subnets
#   vpc_id         = aws_vpc.vpc.id
#   cidr_block     = "0.0.0.0/0"
#   nat_gateway_id = aws_nat_gateway.ngw[each.key].id
# }
# resource "aws_route_table_association" "private_subnets" {
#   for_each       = var.private_subnets
#   subnet_id      = aws_subnet.private_subnets[each.key].id
#   route_table_id = aws_route_table.private_subnets[each.key].id
# }
resource "aws_eip" "nat" {
  for_each = var.private_subnets
  domain = "vpc"
}