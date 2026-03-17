# TFLint configuration for infrastructure-templates
# https://github.com/terraform-linters/tflint

config {
  # Enable all rules by default
  module = false
  force = false
}

# Terraform plugin for general best practices
plugin "terraform" {
  enabled = true

  preset = "recommended"
}

# AWS plugin for AWS-specific checks
plugin "aws" {
  enabled = true
  version = "0.29.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

# Azure plugin for Azure-specific checks
plugin "azurerm" {
  enabled = true
  version = "0.25.1"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Custom rule configurations
rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true

  variable {
    format = "snake_case"
  }

  locals {
    format = "snake_case"
  }

  output {
    format = "snake_case"
  }

  resource {
    format = "snake_case"
  }

  module {
    format = "snake_case"
  }

  data {
    format = "snake_case"
  }
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_standard_module_structure" {
  enabled = false  # Disabled for liquid templates
}

# Disable rules that conflict with .liquid template files
rule "terraform_module_pinned_source" {
  enabled = false  # Many modules use registry without version
}
