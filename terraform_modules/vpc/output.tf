output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = [for subnet_key in sort(keys(aws_subnet.subnet)) : aws_subnet.subnet[subnet_key].id]
}
