output "ec2_public_ip" {
  value = aws_instance.webapp.public_ip
}

output "db_endpoint" {
  value = aws_db_instance.appdb.endpoint
}