output "ecs_task_role_arn" { 

value = aws_iam_role.ecs_task_role.arn

}
output "ecs_task_execution_role_arn" {
  value = aws_iam_role.ecs_execution_role.arn
}

output "prometheus_role_arn" {
  value = aws_iam_role.prometheus_task_role.arn
}
