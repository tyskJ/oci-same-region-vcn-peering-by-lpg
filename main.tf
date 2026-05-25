/************************************************************
Compartment
************************************************************/
module "compartment" {
  source = "./modules/compartments"

  tenancy_ocid = var.tenancy_ocid
  system_name  = var.system_name
}