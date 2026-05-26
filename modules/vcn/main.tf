/************************************************************
VCN
************************************************************/
resource "oci_core_vcn" "vcn" {
  compartment_id = var.compartment_id
  cidr_block     = var.cidr
  display_name   = var.name
  # 最大15文字の英数字
  # 文字から始めること
  # ハイフンとアンダースコアは使用不可
  # 後から変更不可
  dns_label = var.name
  # defined_tags = local.common_defined_tags
}