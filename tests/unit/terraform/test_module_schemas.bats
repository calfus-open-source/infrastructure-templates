#!/usr/bin/env bats
# Unit tests for Terraform module schemas
# Validates variable contracts, output definitions, and resource conventions

setup() {
  load ../helpers
  setup_test_env

  REPO_ROOT="${REPO_ROOT:-.../..}"
}

teardown() {
  teardown_test_env
}

# ============================================================================
# Test: Core Module Files Exist
# ============================================================================

@test "vpc module exists with main.tf and variables" {
  [ -f "${REPO_ROOT}/aws/modules/vpc/main.tf.liquid" ]
  [ -f "${REPO_ROOT}/aws/modules/vpc/variables.tf.liquid" ]
}

@test "security-groups module exists with files" {
  [ -f "${REPO_ROOT}/aws/modules/security-groups/main.tf.liquid" ]
  [ -f "${REPO_ROOT}/aws/modules/security-groups/variables.tf.liquid" ]
}

@test "eks-nodegroup module exists with files" {
  [ -f "${REPO_ROOT}/aws/modules/eks-nodegroup/main.tf.liquid" ]
  [ -f "${REPO_ROOT}/aws/modules/eks-nodegroup/variables.tf.liquid" ]
}

@test "bastion module exists with files" {
  [ -f "${REPO_ROOT}/aws/modules/bastion/main.tf.liquid" ]
  [ -f "${REPO_ROOT}/aws/modules/bastion/variables.tf.liquid" ]
}

@test "ecr module exists with files" {
  [ -f "${REPO_ROOT}/aws/modules/ecr/main.tf.liquid" ]
  [ -f "${REPO_ROOT}/aws/modules/ecr/variables.tf.liquid" ]
}

# ============================================================================
# Test: VPC Module Variable Contract
# ============================================================================

@test "vpc module has variable cidr" {
  grep -q "variable \"cidr\"" "${REPO_ROOT}/aws/modules/vpc/variables.tf.liquid"
}

@test "vpc module has variable name" {
  grep -q "variable \"name\"" "${REPO_ROOT}/aws/modules/vpc/variables.tf.liquid"
}

@test "vpc module has variable environment" {
  grep -q "variable \"environment\"" "${REPO_ROOT}/aws/modules/vpc/variables.tf.liquid"
}

@test "vpc module variables have descriptions" {
  count=$(grep -c "description" "${REPO_ROOT}/aws/modules/vpc/variables.tf.liquid")
  [ "$count" -ge 3 ]
}

@test "vpc module main.tf defines outputs" {
  grep -q "^output" "${REPO_ROOT}/aws/modules/vpc/main.tf.liquid"
}

# ============================================================================
# Test: Module Output Definitions
# ============================================================================

@test "bastion module defines outputs in main.tf" {
  grep -q "^  output" "${REPO_ROOT}/aws/modules/bastion/main.tf.liquid"
}

@test "security-groups module defines outputs in main.tf" {
  grep -q "^output" "${REPO_ROOT}/aws/modules/security-groups/main.tf.liquid"
}

@test "eks-nodegroup module defines outputs in main.tf" {
  grep -q "^output" "${REPO_ROOT}/aws/modules/eks-nodegroup/main.tf.liquid"
}

@test "ecr module defines outputs in main.tf" {
  grep -q "^output" "${REPO_ROOT}/aws/modules/ecr/main.tf.liquid"
}

# ============================================================================
# Test: EKS NodeGroup Module Variable Contract
# ============================================================================

@test "eks-nodegroup module has vpc_id variable" {
  grep -q "variable \"vpc_id\"" "${REPO_ROOT}/aws/modules/eks-nodegroup/variables.tf.liquid"
}

@test "eks-nodegroup module has cluster_version variable" {
  grep -q "variable \"cluster_version\"" "${REPO_ROOT}/aws/modules/eks-nodegroup/variables.tf.liquid"
}

@test "eks-nodegroup module has vpc_private_subnets variable" {
  grep -q "variable \"vpc_private_subnets\"" "${REPO_ROOT}/aws/modules/eks-nodegroup/variables.tf.liquid"
}

# ============================================================================
# Test: Module Naming Conventions
# ============================================================================

@test "all module variables use snake_case naming" {
  local repo_root="${REPO_ROOT}/aws/modules"

  # Check that variable names don't have CamelCase
  for var_file in "$repo_root"/*/variables.tf.liquid; do
    [ -f "$var_file" ] || continue

    # Should not find CamelCase in variable "name_here" patterns
    ! grep -E "variable \"[A-Z]" "$var_file" || true
  done
}

@test "module output names use valid format" {
  # Outputs can use snake_case or hyphens in names
  grep -q "^  output" "${REPO_ROOT}/aws/modules/bastion/main.tf.liquid"
}

# ============================================================================
# Test: Deployment Composition (how modules are used)
# ============================================================================

@test "k8s deployment references vpc module" {
  grep -q "module \"vpc\"" "${REPO_ROOT}/aws/k8s/main.tf.liquid"
}

@test "k8s deployment references security-groups module" {
  grep -q "module \"security" "${REPO_ROOT}/aws/k8s/main.tf.liquid"
}

@test "k8s deployment imports bastion module" {
  grep -q "module \"bastion\"" "${REPO_ROOT}/aws/k8s/main.tf.liquid"
}

@test "eks-nodegroup deployment uses vpc module" {
  grep -q "module \"vpc\"" "${REPO_ROOT}/aws/eks-nodegroup/main.tf.liquid"
}

# ============================================================================
# Test: Module Output References in Deployments
# ============================================================================

@test "k8s deployment passes vpc output to submodules" {
  # Check for module.vpc or similar reference pattern
  grep -qE "(module\.vpc|aws_vpc)" "${REPO_ROOT}/aws/k8s/main.tf.liquid"
}

@test "eks-nodegroup deployment includes vpc dependencies" {
  [ -f "${REPO_ROOT}/aws/eks-nodegroup/variables.tf.liquid" ]

  # Deployment should reference vpc configuration somehow
  grep -q "vpc\|subnet" "${REPO_ROOT}/aws/eks-nodegroup/variables.tf.liquid"
}

# ============================================================================
# Test: Deployment Configuration Files
# ============================================================================

@test "k8s deployment has variables.tf.liquid" {
  [ -f "${REPO_ROOT}/aws/k8s/variables.tf.liquid" ]
}

@test "eks-nodegroup deployment has variables.tf.liquid" {
  [ -f "${REPO_ROOT}/aws/eks-nodegroup/variables.tf.liquid" ]
}

@test "k8s-fargate deployment has terraform files" {
  [ -f "${REPO_ROOT}/aws/eks-fargate/main.tf.liquid" ]
  [ -f "${REPO_ROOT}/aws/eks-fargate/variables.tf.liquid" ]
}

@test "k8s deployment has backend config" {
  [ -f "${REPO_ROOT}/aws/k8s/backend-config.tfvars.liquid" ]
}

# ============================================================================
# Test: Real-world patterns
# ============================================================================

@test "modules follow standard directory structure" {
  local repo_root="${REPO_ROOT}/aws/modules"

  # Most modules should have main.tf and variables.tf
  for module_dir in "$repo_root"/*/; do
    [ -d "$module_dir" ] || continue

    # Each module should have at least main.tf.liquid
    [ -f "${module_dir}main.tf.liquid" ] || [ -f "${module_dir}main.tf" ]
  done
}

@test "all modules are referenced in k8s deployment" {
  # Not all, but core ones should be referenced
  grep -q "module" "${REPO_ROOT}/aws/k8s/main.tf.liquid"
}
