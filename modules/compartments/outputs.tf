output "compartment_id" {
  description = "Created Compartment ID"
  value       = oci_identity_compartment.workload.id
}