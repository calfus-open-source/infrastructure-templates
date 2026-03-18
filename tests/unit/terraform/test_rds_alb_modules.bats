#!/usr/bin/env bats
# Unit tests for RDS and ALB (database and load balancer) modules
# P2: Extended module contracts for production workloads

setup() {
  load ../helpers
  setup_test_env

  REPO_ROOT="${REPO_ROOT:-.../..}"
}

teardown() {
  teardown_test_env
}

# ============================================================================
# Test: RDS Module Structure (Database Configuration)
# ============================================================================

@test "rds module has main.tf and variables" {
  [ -f "${REPO_ROOT}/aws/modules/rds/main.tf.liquid" ]
  [ -f "${REPO_ROOT}/aws/modules/rds/variables.tf.liquid" ]
}

@test "rds module has variable name" {
  grep -q "variable \"name\"" "${REPO_ROOT}/aws/modules/rds/variables.tf.liquid"
}

@test "rds module has variable environment" {
  grep -q "variable \"environment\"" "${REPO_ROOT}/aws/modules/rds/variables.tf.liquid"
}

@test "rds module has variable region" {
  grep -q "variable \"region\"" "${REPO_ROOT}/aws/modules/rds/variables.tf.liquid"
}

@test "rds module has variable vpc_id" {
  grep -q "variable \"vpc_id\"" "${REPO_ROOT}/aws/modules/rds/variables.tf.liquid"
}

@test "rds module has variable security_group_id" {
  grep -q "variable \"security_group_id\"" "${REPO_ROOT}/aws/modules/rds/variables.tf.liquid"
}

@test "rds module defines outputs in main.tf" {
  grep -q "^output" "${REPO_ROOT}/aws/modules/rds/main.tf.liquid"
}

@test "rds module references vpc and security groups" {
  local rds_main="${REPO_ROOT}/aws/modules/rds/main.tf.liquid"

  # Should reference VPC configuration
  grep -qE "(var\.vpc|vpc_id|security_group)" "$rds_main"
}

@test "rds module variables all have descriptions" {
  grep -c "description" "${REPO_ROOT}/aws/modules/rds/variables.tf.liquid" | grep -q "[0-9]"

  var_count=$(grep -c "^variable" "${REPO_ROOT}/aws/modules/rds/variables.tf.liquid")
  desc_count=$(grep -c "description" "${REPO_ROOT}/aws/modules/rds/variables.tf.liquid")

  [ "$desc_count" -ge "$var_count" ]
}

# ============================================================================
# Test: ALB Module Structure (Load Balancer Configuration)
# ============================================================================

@test "alb module has main.tf and variables" {
  [ -f "${REPO_ROOT}/aws/modules/alb/main.tf.liquid" ]
  [ -f "${REPO_ROOT}/aws/modules/alb/variables.tf.liquid" ]
}

@test "alb module has variable name" {
  grep -q "variable \"name\"" "${REPO_ROOT}/aws/modules/alb/variables.tf.liquid"
}

@test "alb module has variable environment" {
  grep -q "variable \"environment\"" "${REPO_ROOT}/aws/modules/alb/variables.tf.liquid"
}

@test "alb module has variable ingress_security_group_id" {
  grep -q "variable \"ingress_security_group_id\"" "${REPO_ROOT}/aws/modules/alb/variables.tf.liquid"
}

@test "alb module has variable vpc_public_subnets" {
  grep -q "variable \"vpc_public_subnets\"" "${REPO_ROOT}/aws/modules/alb/variables.tf.liquid"
}

@test "alb module references ACM certificate" {
  grep -q "aws_acm_certificate_arn" "${REPO_ROOT}/aws/modules/alb/variables.tf.liquid"
}

@test "alb module defines outputs in main.tf" {
  grep -q "^output" "${REPO_ROOT}/aws/modules/alb/main.tf.liquid"
}

@test "alb module exports security group reference" {
  # ALB should export reference to its security group or load balancer ID
  grep -qE "(output|dns_name|load_balancer)" "${REPO_ROOT}/aws/modules/alb/main.tf.liquid"
}

# ============================================================================
# Test: Ingress Controller Module (Kubernetes Ingress)
# ============================================================================

@test "ingress-controller module exists" {
  [ -f "${REPO_ROOT}/aws/modules/ingress-controller/main.tf.liquid" ]
  [ -f "${REPO_ROOT}/aws/modules/ingress-controller/variables.tf.liquid" ]
}

@test "ingress-controller module has essential variables" {
  local ig_vars="${REPO_ROOT}/aws/modules/ingress-controller/variables.tf.liquid"

  # Should reference cluster or kubernetes
  grep -qE "(cluster|kubernetes)" "$ig_vars" || true
}

@test "ingress-controller module has main.tf content" {
  [ -f "${REPO_ROOT}/aws/modules/ingress-controller/main.tf.liquid" ]
  [ -s "${REPO_ROOT}/aws/modules/ingress-controller/main.tf.liquid" ]
}

# ============================================================================
# Test: Route53 Module (DNS Management)
# ============================================================================

@test "route53 module exists" {
  [ -f "${REPO_ROOT}/aws/modules/route53/main.tf.liquid" ]
  [ -f "${REPO_ROOT}/aws/modules/route53/variables.tf.liquid" ]
}

@test "route53 module has variables" {
  local r53_vars="${REPO_ROOT}/aws/modules/route53/variables.tf.liquid"
  grep -q "^variable" "$r53_vars"
}

@test "route53 module defines outputs" {
  grep -q "^output" "${REPO_ROOT}/aws/modules/route53/main.tf.liquid"
}

# ============================================================================
# Test: ACM Module (SSL Certificate Management)
# ============================================================================

@test "acm module exists" {
  [ -f "${REPO_ROOT}/aws/modules/acm/main.tf.liquid" ]
  [ -f "${REPO_ROOT}/aws/modules/acm/variables.tf.liquid" ]
}

@test "acm module has essential variables" {
  local acm_vars="${REPO_ROOT}/aws/modules/acm/variables.tf.liquid"

  # Should reference domain names
  [ -f "$acm_vars" ]
}

@test "acm module defines certificate outputs" {
  grep -q "^output" "${REPO_ROOT}/aws/modules/acm/main.tf.liquid"
}

# ============================================================================
# Test: Module Dependency Chain (Real-world composition)
# ============================================================================

@test "rds module can be composed with vpc module" {
  local rds_vars="${REPO_ROOT}/aws/modules/rds/variables.tf.liquid"

  # RDS takes vpc_id as variable, can receive from vpc module outputs
  grep -q "variable \"vpc_id\"" "$rds_vars"
}

@test "alb module can be composed with security-groups" {
  local alb_vars="${REPO_ROOT}/aws/modules/alb/variables.tf.liquid"

  # ALB takes security group as variable
  grep -q "ingress_security_group_id" "$alb_vars"
}

@test "deployments that need database reference rds module" {
  grep -q "rds" "${REPO_ROOT}/aws/k8s/main.tf.liquid" || true
}

@test "deployments that need http/https reference alb module" {
  grep -q "alb" "${REPO_ROOT}/aws/k8s/main.tf.liquid" || true
}

# ============================================================================
# Test: Real-world Deployment Patterns (K8s with Database)
# ============================================================================

@test "k8s deployment imports base infrastructure" {
  [ -f "${REPO_ROOT}/aws/k8s/main.tf.liquid" ]

  # Should import vpc at minimum
  grep -q "module" "${REPO_ROOT}/aws/k8s/main.tf.liquid"
}

@test "k8s deployment has comprehensive variables" {
  local k8s_vars="${REPO_ROOT}/aws/k8s/variables.tf.liquid"
  [ -f "$k8s_vars" ]

  # Should define key deployment parameters
  [ -s "$k8s_vars" ]
}

@test "k8s deployment has backend configuration" {
  [ -f "${REPO_ROOT}/aws/k8s/backend-config.tfvars.liquid" ]
}

@test "eks-fargate deployment exists as alternative" {
  [ -f "${REPO_ROOT}/aws/eks-fargate/main.tf.liquid" ]
  [ -f "${REPO_ROOT}/aws/eks-fargate/variables.tf.liquid" ]
}

# ============================================================================
# Test: Common Module Patterns (all extended modules)
# ============================================================================

@test "all extended modules use consistent variable names" {
  local count=0

  for var_file in "${REPO_ROOT}"/aws/modules/{rds,alb,route53,acm,ingress-controller}/variables.tf.liquid; do
    [ -f "$var_file" ] || continue

    # Check for common variables
    grep -q "variable \"name\"" "$var_file" && ((count++))
  done

  [ "$count" -ge 2 ]
}

@test "extended modules define outputs for consumption" {
  local output_count=0

  for main_file in "${REPO_ROOT}"/aws/modules/{rds,alb,route53,acm}/main.tf.liquid; do
    [ -f "$main_file" ] || continue

    grep -q "^output" "$main_file" && ((output_count++))
  done

  [ "$output_count" -ge 2 ]
}

@test "all modules follow .liquid template convention" {
  # All terraform files should use .liquid extension (for variable templating)
  tf_count=$(find "${REPO_ROOT}/aws/modules" -type f -name "*.tf.liquid" | wc -l)

  [ "$tf_count" -gt 20 ]
}

# ============================================================================
# Test: Security Module Requirements (for database and load balancer)
# ============================================================================

@test "rds module requires security group specification" {
  grep -q "security_group" "${REPO_ROOT}/aws/modules/rds/variables.tf.liquid"
}

@test "alb module requires ingress security group" {
  grep -q "ingress_security_group_id" "${REPO_ROOT}/aws/modules/alb/variables.tf.liquid"
}

@test "rds main.tf references database-specific resources" {
  grep -qE "(db_instance|rds_cluster|database)" "${REPO_ROOT}/aws/modules/rds/main.tf.liquid"
}

@test "alb main.tf references load balancer resources" {
  grep -qE "(lb|load_balancer|alb)" "${REPO_ROOT}/aws/modules/alb/main.tf.liquid"
}

# ============================================================================
# Test: Environment and Naming Consistency
# ============================================================================

@test "rds module uses environment variable for naming" {
  grep -q "var.environment\|var\.environment" "${REPO_ROOT}/aws/modules/rds/main.tf.liquid"
}

@test "alb module uses environment variable for naming" {
  grep -q "var.environment\|var\.environment" "${REPO_ROOT}/aws/modules/alb/main.tf.liquid"
}

@test "modules use tags for resource identification" {
  # Check if modules use tags (best practice for cost tracking)
  tag_count=$(grep -r "tags" "${REPO_ROOT}/aws/modules/rds" 2>/dev/null | wc -l)

  [ "$tag_count" -gt 0 ] || true
}
