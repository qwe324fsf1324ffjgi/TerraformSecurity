output "instance_public_ip" {
  value = aws_instance.python_app.public_ip
}