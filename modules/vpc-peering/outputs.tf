output "id" {
  description = "ID of the peering connection."
  value       = aws_vpc_peering_connection.this.id
}

output "status" {
  description = "Status of the connection. A cross-account one sits at pending-acceptance until the other side accepts."
  value       = aws_vpc_peering_connection.this.accept_status
}

output "requester_route_ids" {
  description = "Route IDs created on this side, keyed by the name given to each route table."
  value       = { for table_id, route in aws_route.requester : table_id => route.id }
}

output "accepter_route_ids" {
  description = "Route IDs created on the other side, keyed by the name given to each route table."
  value       = { for table_id, route in aws_route.accepter : table_id => route.id }
}
