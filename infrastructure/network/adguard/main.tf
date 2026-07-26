terraform {
  required_providers {
    adguard = {
      source  = "gmichels/adguard"
      version = "1.7.0"
    }
  }
}

variable "adguard_host" {
  type = string
}

variable "adguard_scheme" {
  type = string
}

variable "adguard_username" {
  type      = string
  sensitive = true
}

variable "adguard_password" {
  type      = string
  sensitive = true
}

variable "domain_maps" {
  type = map(string)
}

provider "adguard" {
  host     = var.adguard_host
  username = var.adguard_username
  password = var.adguard_password
  scheme   = var.adguard_scheme
  timeout  = 10
  insecure = true
}

resource "adguard_rewrite" "domains" {
  for_each = var.domain_maps

  domain = each.key
  answer = each.value
}
