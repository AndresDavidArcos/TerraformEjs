resource "aws_security_group" "lb-allow-http" {
    name = "lb-allow-http"
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
  tags = {
    Name = "lb allowing internet egress and http ingress"
  }
}

resource "aws_security_group" "ec2-allow-lb-http" {
    name = "ec2-allow-lb-http"
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

        ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = [aws_security_group.lb-allow-http.id]
    }
  tags = {
    Name = "ec2 instance http ingress for load balancer"
  }
}

resource "aws_elb" "lb-forAutoscalingGroup" {
  name = "lb-forAutoscalingGroup"
  subnets = ["subnet-01d91d2ce977dbc86", "subnet-01aa9927e65e2fe20"]
  security_groups = [aws_security_group.lb-allow-http.id]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:80/"
    interval = 30
  }

  cross_zone_load_balancing = true
  connection_draining = true
  connection_draining_timeout = 200

    tags = {
        Name = "lb-forautoscalingGroup"
    }
}



