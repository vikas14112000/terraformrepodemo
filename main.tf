############################
# Default VPC + Subnets
############################

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

############################
# Security Group
############################

resource "aws_security_group" "alb_sg" {
  name   = "alb-sg"
  vpc_id = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
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

############################
# EC2 Instances
############################

resource "aws_instance" "app" {
  count         = 2
  ami           = "ami-0b6c6ebed2801a5cb"
  instance_type = "t2.micro"

  subnet_id = element(data.aws_subnets.default.ids, count.index)

  vpc_security_group_ids = [aws_security_group.alb_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              yum install httpd -y
              systemctl start httpd
              echo "Hello from server ${count.index}" > /var/www/html/index.html
              EOF
}

############################
# Target Group
############################

resource "aws_lb_target_group" "tg" {
  name     = "app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
}

resource "aws_lb_target_group_attachment" "attach" {
  count            = 2
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.app[count.index].id
  port             = 80
}

############################
# Application Load Balancer
############################

resource "aws_lb" "alb" {
  name               = "my-alb"
  load_balancer_type = "application"
  internal           = false

  security_groups = [aws_security_group.alb_sg.id]
  subnets         = data.aws_subnets.default.ids
}

############################
# Listener
############################

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}
