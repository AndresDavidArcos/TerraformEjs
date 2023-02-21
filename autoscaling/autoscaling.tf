provider "aws" {
  access_key = {}
  secret_key = {}
  region = "us-east-1"
}

data "aws_ami" "ubuntu" {
    most_recent = true
    owners = ["099720109477"]
    filter {
        name = "name"
        values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-20230208"]
    }
}

resource "aws_key_pair" "scalingKey" {
  key_name = "scalingKey"
  public_key = file("../keypairs/test0ec2key.pub")
}

resource "aws_security_group" "ssh" {
  name        = "ssh_security_group"
  description = "Security group for SSH access"
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_launch_configuration" "launchGroup0" {
  name = "launchGroup0"
  image_id = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.scalingKey.key_name
  security_groups = [aws_security_group.ec2-allow-lb-http.id]
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update
              sudo apt-get install -y apache2
              INSTANCE_NUM=$((1 + RANDOM % 100))
              echo "Esta instancia tiene tiene el numero $INSTANCE_NUM" > /var/www/html/index.html
              sudo systemctl start apache2
              sudo systemctl enable apache2
              EOF
}


resource "aws_autoscaling_group" "scalingGroup0"{
    name = "scalingGroup0"
    vpc_zone_identifier = ["subnet-01d91d2ce977dbc86", "subnet-01aa9927e65e2fe20"]
    launch_configuration = aws_launch_configuration.launchGroup0.name
    min_size = 1
    max_size = 3
    health_check_grace_period = 60
    health_check_type = "EC2"
    load_balancers = [aws_elb.lb-forAutoscalingGroup.name]
    force_delete = true
    tag {
        key = "Name"
        value = "ec2FromScaling"
        propagate_at_launch = true
    }
}

resource "aws_autoscaling_policy" "cpu-policy"{
    name = "cpuPolicy-sacleUp"
    autoscaling_group_name = aws_autoscaling_group.scalingGroup0.name
    adjustment_type = "ChangeInCapacity"
    scaling_adjustment = 1
    cooldown = 15
    policy_type = "SimpleScaling"
    }

resource "aws_cloudwatch_metric_alarm" "alarmForHighCPU"{
    alarm_name = "alarmForHighCPU"
    alarm_description = "treshold detector"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = 1
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = 10
    statistic = "Average"
    threshold = 20

    dimensions = {
        "AutoScalingGroupName": aws_autoscaling_group.scalingGroup0.name
    }
    actions_enabled = true
    alarm_actions = [aws_autoscaling_policy.cpu-policy.arn]
}    


resource "aws_autoscaling_policy" "cpu-policy-scaledown"{
    name = "cpuPolicy-scaleDown"
    autoscaling_group_name = aws_autoscaling_group.scalingGroup0.name
    adjustment_type = "ChangeInCapacity"
    scaling_adjustment = -1
    cooldown = 15
    policy_type = "SimpleScaling"
    }

resource "aws_cloudwatch_metric_alarm" "alarmForHighCPU-scaledown"{
    alarm_name = "normalCpuDetector"
    alarm_description = "alarm for normal cpu levels"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = 1
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = 60
    statistic = "Average"
    threshold = 30

    dimensions = {
        "AutoScalingGroupName": aws_autoscaling_group.scalingGroup0.name
    }
    actions_enabled = true
    alarm_actions = [aws_autoscaling_policy.cpu-policy-scaledown.arn]
}    
