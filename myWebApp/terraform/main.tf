data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Providing a reference to our default VPC
resource "aws_vpc" "vpc" {
  cidr_block           = var.aws_vpc_cidr_block
  enable_dns_support   = "true"
  enable_dns_hostnames = "true"

  tags = {
    Name        = "glamorous-devops-${terraform.workspace}"
    environment = terraform.workspace
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name        = "glamorous-devops-igw-${terraform.workspace}"
    environment = terraform.workspace
  }
}

resource "aws_eip" "nat_gw" {
  vpc = true

  tags = {
    Name        = "glamorous-devops-eip-${terraform.workspace}"
    environment = terraform.workspace
    application = "glamorous-devops"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_gw.id
  subnet_id     = aws_subnet.public-1.id
  depends_on    = [aws_internet_gateway.igw]

  tags = {
    Name        = "glamorous-devops-NAT-gateway-${terraform.workspace}"
    environment = terraform.workspace
    application = "glamorous-devops"
  }
}

/*
Our *public* subnets. Let's define two in different availability zones
so we can define redundant services in the future
*/
resource "aws_subnet" "public-1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.aws_vpc_public_cidr_block[0]
  availability_zone = "${data.aws_region.current.name}${var.availability_zones[0]}"

  tags = {
    Name        = "Public_1a-1_${terraform.workspace}"
    layer       = "Public"
    environment = terraform.workspace
  }
}

resource "aws_subnet" "public-2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.aws_vpc_public_cidr_block[1]
  availability_zone = "${data.aws_region.current.name}${var.availability_zones[1]}"

  tags = {
    Name        = "Public_1b-1_${terraform.workspace}"
    layer       = "Public"
    environment = terraform.workspace
  }
}

/*
Our *private* subnets. Let's define two in different availability zones
so we can define redundant services in the future
*/
resource "aws_subnet" "private-1" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.aws_vpc_private_cidr_block[0]
  availability_zone = "${data.aws_region.current.name}${var.availability_zones[0]}"

  tags = {
    Name        = "Private_1a-1_${terraform.workspace}"
    layer       = "Private"
    environment = terraform.workspace
  }
}

resource "aws_subnet" "private-2" {
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = var.aws_vpc_private_cidr_block[1]
  availability_zone = "${data.aws_region.current.name}${var.availability_zones[1]}"

  tags = {
    Name        = "Private_1b-1_${terraform.workspace}"
    layer       = "Private"
    environment = terraform.workspace
    application = "glamorous-devops"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name        = "Public_route_table_${terraform.workspace}"
    environment = terraform.workspace
    application = "member-experience"
  }
}

# The private subnets need to route all traffic to the NAT Gateway
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }

  tags = {
    Name        = "Private_route_table_${terraform.workspace}"
    environment = terraform.workspace
    application = "member-experience"
  }
}

resource "aws_route_table_association" "public-1" {
  subnet_id      = aws_subnet.public-1.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "public-2" {
  subnet_id      = aws_subnet.public-2.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private-1" {
  subnet_id      = aws_subnet.private-1.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private-2" {
  subnet_id      = aws_subnet.private-2.id
  route_table_id = aws_route_table.private.id
}

resource "aws_ecs_cluster" "cluster" {
  name = "glamorous-devops-cluster"
}

resource "aws_ecs_task_definition" "task" {
  family                   = "glamorous-devops-${terraform.workspace}-task"
  container_definitions    = <<DEFINITION
  [
    {
      "name": "hello-world-dotnet",
      "image": "${var.glamorous_devops_app_image}",
      "essential": true,
      "portMappings": [
        {
          "containerPort": 80,
          "hostPort": 80
        }
      ],
      "memory": 512,
      "cpu": 256
    }
  ]
  DEFINITION
  requires_compatibilities = ["FARGATE"] # Stating that we are using ECS Fargate
  network_mode             = "awsvpc"    # Using awsvpc as our network mode as this is required for Fargate
  memory                   = 512         # Specifying the memory our container requires
  cpu                      = 256         # Specifying the CPU our container requires
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
}

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRole-${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_alb" "application_load_balancer" {
  name               = "glamorous-devops-${terraform.workspace}"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public-1.id, aws_subnet.public-2.id]
  security_groups    = [aws_security_group.load_balancer_security_group.id]
}

# Creating a security group for the load balancer:
resource "aws_security_group" "load_balancer_security_group" {
  name   = "glamorous-devops-lb-${terraform.workspace}-sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Allowing traffic in from all sources
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "glamorous-devops-${terraform.workspace}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.arn
  port              = "80"
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.arn
  }
}

resource "aws_ecs_service" "service" {
  name            = "hello-world-dotnet"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.task.arn
  launch_type     = "FARGATE"
  desired_count   = 1

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "hello-world-dotnet"
    container_port   = 80
  }

  network_configuration {
    subnets          = [aws_subnet.private-1.id, aws_subnet.private-1.id]
    assign_public_ip = false
    security_groups  = [aws_security_group.service_security_group.id]
  }
}


resource "aws_security_group" "service_security_group" {
  name   = "glamorous-devops-service-${terraform.workspace}-sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.load_balancer_security_group.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
