# ALB output dns name.
output "alb_sa" {
  value = aws_alb.node_appliaction_load_balancer.dns_name

}

# ecs task outputs
output "sa" {
  value = aws_ecs_task_definition.my-node-app-task.arn
}
output "wa" {
  value = aws_ecs_task_definition.my-node-app-task.tags
}


# DB Related Output
output "sg-id" {
  value = aws_security_group.db-sg-lab.id
}

output "db-access-endpoint" {
  value = element(split(":", aws_db_instance.node_student_db_postgresql.endpoint), 0)
}
