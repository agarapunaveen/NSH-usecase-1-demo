resource "aws_ecs_cluster" "main" {
  name = var.cluster_name
}

resource "aws_cloudwatch_log_group" "ecs_logs" {
  name              = "/ecs/${var.cluster_name}"
  retention_in_days = 30  # Adjust as needed
}

resource "aws_ecs_task_definition" "appointment_service" {
  family                   = var.task_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = var.execution_role
  memory     = var.task_memory
  cpu        = var.task_cpu  # Make sure this is an integer

  container_definitions    = jsonencode([{
    name       = var.appointment_container_name
    image      = var.image_url
    memory     = 512
    cpu        = 216  # Make sure this is an integer
    essential  = true
    portMappings = [
      {
        containerPort = 3001
        hostPort      = 3001
        protocol      = "tcp"
      }
    ]
  logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "appointment-service"
        }
      }  
  },
 {
    name  = "xray-daemon"
      image = "amazon/aws-xray-daemon"
      essential = true
      cpu    = 50
      memory = 128
       environment = [
  {
    name  = "AWS_XRAY_TRACING_NAME"
    value = "appointment-service-trace"
  },
  {
    name  = "AWS_XRAY_DAEMON_ADDRESS"
    value = "xray.us-east-1.amazonaws.com:2000"
  },
  {
    name  = "AWS_XRAY_DAEMON_DISABLE_METADATA"
    value = "true"
  }
]
logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "xray"
        }
      }
}
])

  tags = {
    Name = var.task_name
  }
}


resource "aws_ecs_task_definition" "patient_service" {
  family                   = var.task_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  execution_role_arn       = var.execution_role
  memory     = var.task_memory
  cpu        = var.task_cpu  # Make sure this is an integer
  container_definitions    = jsonencode([{
    name       = var.patient_container_name
    image      = var.image_url_patient
    memory     = 512
    cpu        = 216  # Make sure this is an integer
    essential  = true
    portMappings = [
      {
        containerPort = 2000
        hostPort      = 2000
        protocol      = "tcp"
      }
    ]
 logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "patient-service"
        }
      }
  },
{
    name  = "xray-daemon"
      image = "amazon/aws-xray-daemon"
      essential = true
      cpu    = 50
      memory = 128
       environment = [
  {
    name  = "AWS_XRAY_TRACING_NAME"
    value = "patient-service-trace"
  },
  {
    name  = "AWS_XRAY_DAEMON_ADDRESS"
    value = "xray.us-east-1.amazonaws.com:2000"
  },
  {
    name  = "AWS_XRAY_DAEMON_DISABLE_METADATA"
    value = "true"
  }
]
logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_logs.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "xray"
        }
      }
  }

])

  tags = {
    Name = var.task_name
  }
}


# ECS Service for Appointment Service
resource "aws_ecs_service" "appointment_service" {
  name            = var.appointment_service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.appointment_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_groups
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.appointment_tg_arn
    container_name   = var.appointment_container_name
    container_port   = 3001
  }
}

# ECS Service for Patient Service
resource "aws_ecs_service" "patient_service" {
  name            = var.patient_service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.patient_service.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnets
    security_groups  = var.security_groups
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.patient_tg_arn
    container_name   = var.patient_container_name
    container_port   = 2000
  }
}


# Prometheus Task Definition
resource "aws_ecs_task_definition" "prometheus" {
  family                   = "prometheus"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = 1024
  memory                  = 2048
  execution_role_arn      = var.ecs_task_execution_role
  task_role_arn           = var.ecs_promethes_execution_role

  container_definitions = jsonencode([
    {
      name  = "prometheus"
      image = "prom/prometheus:latest"
      memory= 512
      cpu= 216
      essential=true
      portMappings = [
        {
          containerPort = 9090
          hostPort      = 9090
          protocol      = "tcp"
        }
      ]
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/prometheus"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "prometheus"
        }
      }
    }
  ])

} 


# ECS Service for Appointment Service
resource "aws_ecs_service" "prometheus_service" {
  name            = "prometheus"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.prometheus.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnets
    security_groups  = var.security_groups
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.prometheus_tg_arn
    container_name   = "prometheus"
    container_port   = 9090
  }
} 




# Grafana Task Definition
resource "aws_ecs_task_definition" "grafana" {
  family                   = "grafana"
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = 256
  memory                  = 512
  execution_role_arn      = var.ecs_task_execution_role
  task_role_arn           = var.ecs_promethes_execution_role

  container_definitions = jsonencode([
    {
      name  = "grafana"
      image = "grafana/grafana:latest"
      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]
      environment = [
        {
          name  = "GF_SECURITY_ADMIN_PASSWORD"
          value = "admin"
        }
      ]
      essential = true
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/grafana"
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "grafana"
        }
      }
    }
  ])
} 
# ECS Service for Appointment Service
resource "aws_ecs_service" "grafana_service" {
  name            = "grafana"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.grafana.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.public_subnets
    security_groups  = var.security_groups
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = var.grafana_tg_arn
    container_name   = "grafana"
    container_port   = 3000
  }
} 
