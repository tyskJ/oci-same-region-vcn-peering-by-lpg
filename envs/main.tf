/************************************************************
Compartment
************************************************************/
module "compartment" {
  source = "../modules/compartments"

  tenancy_ocid = var.tenancy_ocid
  system_name  = var.system_name
}

/************************************************************
VCN
************************************************************/
module "vcn_a" {
  source = "../modules/vcn"

  compartment_id = module.compartment.id_compartment
  cidr           = var.vcn_a_cidr
  name           = "vcnA"
}