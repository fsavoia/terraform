#--------------------------------------------
# Deploy ECS Cluster
#--------------------------------------------
resource "aws_ecs_cluster" "ecs_cluster" {
  name               = var.ecs_cluster_name
  capacity_providers = var.capacity_providers

  setting {
    name  = "containerInsights"
    value = var.containerInsights
  }
}

#--------------------------------------------
# Deploy ECS Service
#--------------------------------------------
resource "aws_ecs_service" "service" {
  name                               = var.ecs_service_name
  cluster                            = aws_ecs_cluster.ecs_cluster.arn
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  desired_count                      = 1
  enable_ecs_managed_tags            = true
  enable_execute_command             = false
  health_check_grace_period_seconds  = 0
  launch_type                        = var.launch_type
  platform_version                   = var.ecs_platform_version
  task_definition                    = "${aws_ecs_task_definition.main.family}:${max(
    aws_ecs_task_definition.main.revision,
    data.aws_ecs_task_definition.main.revision,
  )}"

  deployment_controller {
    type = var.deployment_controller
  }

  load_balancer {
    container_name   = var.container_name
    container_port   = var.container_port
    target_group_arn = aws_lb_target_group.tg_http.arn
  }

  network_configuration {
    assign_public_ip = false
    security_groups  = [ aws_security_group.ecs_service.id ]
    subnets          = var.private_subnets
  }
}

# Create a data source to pull the latest active revision from
data "aws_ecs_task_definition" "main" {
  task_definition = aws_ecs_task_definition.main.family
  depends_on      = [aws_ecs_task_definition.main] # ensures at least one task def exists
}

#--------------------------------------------
# Deploy ECS Task Definition
#--------------------------------------------
resource "aws_ecs_task_definition" "main" {
  container_definitions = jsonencode(
    [
      {
        image = var.image
        logConfiguration = {
          logDriver = "awslogs"
          options = {
            awslogs-group         = "/ecs/${var.family}"
            awslogs-region        = var.region
            awslogs-stream-prefix = "ecs"
          }
        }
        memoryReservation = var.memory_reservation
        name              = var.container_name
        essential         = true
        portMappings = [
          {
            containerPort = var.container_port
            hostPort      = var.host_port
            protocol      = "tcp"
          }
        ]
      },
    ]
  )
  cpu                      = var.cpu
  task_role_arn            = aws_iam_role.task_role.arn
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  family                   = var.family
  memory                   = var.memory
  network_mode             = var.network_mode
  requires_compatibilities = var.requires_compatibilities
}