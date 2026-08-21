# Redshift VPC
resource "aws_vpc" "redshift_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Redshift VPC"
  }
}

# Redshift Subnet
resource "aws_subnet" "redshift_subnet" {
  cidr_block = "10.0.1.0/24"
  vpc_id     = aws_vpc.redshift_vpc.id

  tags = {
    Name = "Redshift Subnet"
  }
}

# Internet Gateway attached to the VPC
resource "aws_internet_gateway" "redshift_igw" {
  vpc_id = aws_vpc.redshift_vpc.id

  tags = {
    Name = "Redshift Internet Gateway"
  }
}

# Route table
resource "aws_route_table" "redshift_route_table" {
  vpc_id = aws_vpc.redshift_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.redshift_igw.id
  }

  tags = {
    Name = "Redshift Route Table"
  }
}

# Associates the route table with the subnet
resource "aws_route_table_association" "redshift_route_table_association" {
  subnet_id      = aws_subnet.redshift_subnet.id
  route_table_id = aws_route_table.redshift_route_table.id
}

# Security group controlling access to the data warehouse
resource "aws_security_group" "redshift_sg" {
  name        = "redshift_sg"
  description = "Allow Redshift traffic"
  vpc_id      = aws_vpc.redshift_vpc.id

  ingress {
    from_port   = 5439
    to_port     = 5439
    protocol    = "tcp"
    cidr_blocks = [var.allowed_cidr]
  }

  tags = {
    Name = "Redshift Security Group"
  }
}

# Redshift subnet group
resource "aws_redshift_subnet_group" "redshift_subnet_group" {
  name       = "redshift-subnet-group"
  subnet_ids = [aws_subnet.redshift_subnet.id]

  tags = {
    Name = "Redshift Subnet Group"
  }
}

# Redshift cluster
resource "aws_redshift_cluster" "redshift_cluster" {
  cluster_identifier = "redshift-cluster"
  database_name      = "db"
  master_username     = "adminuser"
  master_password     = var.db_master_password
  node_type           = "ra3.large"
  number_of_nodes     = 1
  publicly_accessible = true

  vpc_security_group_ids    = [aws_security_group.redshift_sg.id]
  cluster_subnet_group_name = aws_redshift_subnet_group.redshift_subnet_group.name

  iam_roles = [aws_iam_role.redshift_role.arn]

  skip_final_snapshot = true
}
