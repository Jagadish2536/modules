#creating VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  tags = merge(
    var.common_tags,
    var.vpc_tags,
    {
        Name = local.name
    }
  )
}


#creating Internet Gateway
resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.main.id
    tags = merge(
        var.common_tags,
        var.igw_tags,
        {
            Name = local.name
        }
    )
}


#Creating Public Subnets
resource "aws_subnet" "public" {
    count = length(var.public_subnets_cidr)
    vpc_id = aws_vpc.main.id
    cidr_block = var.public_subnets_cidr[count.index]
    availability_zone = local.az_names[count.index]
    tags = merge(
        var.common_tags,
        var.public_subnet_tags,
        {
            Name = "${local.name}-public-${local.az_names[count.index]}"
        }
    )
}


#Creating Private Subnets
resource "aws_subnet" "private" {
    count = length(var.private_subnets_cidr)
    vpc_id = aws_vpc.main.id
    cidr_block = var.private_subnets_cidr[count.index]
    availability_zone = local.az_names[count.index]
    tags = merge(
        var.common_tags,
        var.private_subnet_tags,
        {
            Name = "${local.name}-private-${local.az_names[count.index]}"
        }
    )
}


#Creating Database Subnets
resource "aws_subnet" "database" {
    count = length(var.database_subnet_tags)
    vpc_id = aws_vpc.main.id
    cidr_block = var.database_subnets_cidr[count.index]
    availability_zone = local.az_names[count.index]
    tags = merge(
        var.common_tags,
        var.database_subnet_tags,
        {
            Name = "${local.name}-database-${local.az_names[count.index]}"
        }
    )
}


#creating Elastic IP
resource "aws_eip" "eip" {
    domain = "vpc"
}


#creating NAT Gateway
resource "aws_nat_gateway" "main" {
    allocation_id = aws_eip.eip.id
    subnet_id = aws_subnet.public[0].id
    tags = merge(
        var.common_tags,
        var.nat_gateway_tags,
        {
            Name = "${local.name}"
        }
    )
    depends_on = [ aws_internet_gateway.gw ]
}


#creating Public Route Table
resource "aws_route_table" "public" {
    vpc_id = aws_vpc.main.id
    tags = merge(
        var.common_tags,
        var.public_route_table_tags,
        {
            Name = "${local.name}-public"
        }
    )
}


#Creating public routes
resource "aws_route" "public_route" {
    route_table_id = aws_route_table.public.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
}


#creating private Route Table
resource "aws_route_table" "private" {
    vpc_id = aws_vpc.main.id
    tags = merge(
        var.common_tags,
        var.private_route_table_tags,
        {
            Name = "${local.name}-private"
        }
    )
}


#Creating private routes
resource "aws_route" "private_route" {
    route_table_id = aws_route_table.private.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
    nat_gateway_id = aws_nat_gateway.main.id
}


#creating database Route Table
resource "aws_route_table" "database" {
    vpc_id = aws_vpc.main.id
    tags = merge(
        var.common_tags,
        var.database_route_table_tags,
        {
            Name = "${local.name}-database"
        }
    )
}


#Creating database routes
resource "aws_route" "database_route" {
    route_table_id = aws_route_table.database.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
    nat_gateway_id = aws_nat_gateway.main.id
}

#Public Route table association
resource "aws_route_table_association" "public" {
    count = length(var.public_subnets_cidr)
    subnet_id = element(aws_subnet.public[*].id, count.index)
    route_table_id = aws_route_table.public.id
}

#private Route table association
resource "aws_route_table_association" "private" {
    count = length(var.private_subnets_cidr)
    subnet_id = element(aws_subnet.private[*].id, count.index)
    route_table_id = aws_route_table.private.id
}

#database Route table association
resource "aws_route_table_association" "database" {
    count = length(var.database_subnets_cidr)
    subnet_id = element(aws_subnet.database[*].id, count.index)
    route_table_id = aws_route_table.database.id
}
