
####################
# AWS Networking
####################

# Providing a reference to our default VPC
resource "aws_default_vpc" "default_vpc" {
}

# Providing a reference to our default subnets
resource "aws_default_subnet" "default_subnet_a" {
  availability_zone = "us-east-1a"
}

resource "aws_default_subnet" "default_subnet_b" {
  availability_zone = "us-east-1b"
}

resource "aws_default_subnet" "default_subnet_c" {
  availability_zone = "us-east-1c"
}


####################
# ALB Craeting
####################


# application load balancer craetion

resource "aws_alb" "node_appliaction_load_balancer" {
  name               = "node-test-alb"
  load_balancer_type = "application"
  # referencing subnets
  subnets = [
    "${aws_default_subnet.default_subnet_a.id}",
    "${aws_default_subnet.default_subnet_b.id}",
    "${aws_default_subnet.default_subnet_c.id}"
  ]

  #refenrencing the sucurity group
  security_groups = ["${aws_security_group.node-alb-sg.id}"]




}

resource "aws_security_group" "node-alb-sg" {

  name = "node_app_loadblancer_sg"
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



# alb target group

resource "aws_lb_target_group" "node-app-target-group" {
  name        = "nodeAppTargetGroup"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_default_vpc.default_vpc.id
  health_check {
    matcher = "200,301,302"
    path    = "/"
  }

}


resource "aws_lb_listener" "node-app-lb-listner" {
  load_balancer_arn = aws_alb.node_appliaction_load_balancer.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.node-app-target-group.arn
  }
}




####################
# RDS Instance
####################


resource "aws_security_group" "db-sg-lab" {
  name = "db-sg-lab"
  ingress {
    from_port   = 5432
    to_port     = 5432
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

resource "aws_db_instance" "node_student_db_postgresql" {

  engine                 = "postgres"
  identifier             = "mylabrdsinstance"
  allocated_storage      = 20
  instance_class         = "db.t3.micro"
  username               = var.rds_username
  password               = var.database_master_password
  vpc_security_group_ids = ["${aws_security_group.db-sg-lab.id}"]
  skip_final_snapshot    = true
  publicly_accessible    = true

}


####################
# SSM Parameter
####################


resource "aws_ssm_parameter" "secret" {
  name        = "/DT/DATABASE/URL"
  description = "Terraform created databaseurl"
  type        = "String"
  # value       = aws_db_instance.node_student_db_postgresql.endpoint
  value = element(split(":", aws_db_instance.node_student_db_postgresql.endpoint), 0)

  tags = {
    environment = "production"
  }
}

resource "aws_ssm_parameter" "secret1" {
  name        = "/DT/DATABASE/USERNAME"
  description = "The parameter description"
  type        = "String"
  value       = var.rds_username

  tags = {
    environment = "production"
  }
}

resource "aws_ssm_parameter" "secret2" {
  name        = "/DT/DATABASE/PASSWORD"
  description = "The parameter description"
  type        = "SecureString"
  value       = var.database_master_password

  tags = {
    environment = "production"
  }
}




####################
# ECR Repo
####################

# query our aws existing ecr repo in aws account. 

data "aws_ecr_repository" "myrepo" {
  name = var.ecrRepoName
}



####################
# IAM Role 
####################

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "ecsTaskExecutionRoleNodeApp"
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



# task-role  created 

resource "aws_iam_role" "ecsTaskRole" {
  name               = "ecsTaskRoleNodeApp"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy1.json
}

data "aws_iam_policy_document" "assume_role_policy1" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskRole_policy" {
  role       = aws_iam_role.ecsTaskRole.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonECS_FullAccess"
}



####################
# ECS Creating
####################

resource "aws_ecs_cluster" "my-node_app_cluster" {
  name = "my_node_app_cluster"
}

resource "aws_ecs_service" "my-node-app-service" {

  name            = "my_node_app_service"
  cluster         = aws_ecs_cluster.my-node_app_cluster.id
  task_definition = aws_ecs_task_definition.my-node-app-task.arn
  launch_type     = "FARGATE"
  desired_count   = 3


  network_configuration {
    subnets          = ["${aws_default_subnet.default_subnet_a.id}", "${aws_default_subnet.default_subnet_b.id}", "${aws_default_subnet.default_subnet_c.id}"]
    assign_public_ip = true
    security_groups  = ["${aws_security_group.ecs-alb-only-sg.id}"]
  }

  load_balancer {

    target_group_arn = aws_lb_target_group.node-app-target-group.arn
    container_name   = aws_ecs_task_definition.my-node-app-task.family
    container_port   = 8000
  }


}


#ecs security group because ecs want to acess alb traffic only

resource "aws_security_group" "ecs-alb-only-sg" {
  name = "ecs-alb-only-sg"
  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = ["${aws_security_group.node-alb-sg.id}"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

}



resource "aws_ecs_task_definition" "my-node-app-task" {
  family = "my_node_app_task"
  container_definitions = jsonencode([
    {
      "name" : "my_node_app_task",
      # "image" : "${data.aws_ecr_repository.my-node-repo.repository_url}:latest",
      "image" : "${data.aws_ecr_repository.myrepo.repository_url}:latest",
      "essential" : true,
      "portMappings" : [
        {
          "containerPort" : 8000,
          "hostPort" : 8000
        }
      ],
      "environment" : [
        {
          "name" : "AWS_ACCESS_KEY_ID",
          "value" : var.access_key
        },
        {
          "name" : "AWS_SECRET_ACCESS_KEY",
          "value" : var.secret_key
        }
      ],
      "memory" : 500,
      "cpu" : 256

    }
  ])

  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = 512
  cpu                      = 256
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskRole.arn
  depends_on               = [aws_db_instance.node_student_db_postgresql, aws_ssm_parameter.secret]
}










