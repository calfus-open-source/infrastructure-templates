#!/usr/bin/env bash
# Check Terraform resource naming conventions
# Usage: ./scripts/check-terraform-naming.sh

set -e

echo "🔍 Checking Terraform naming conventions..."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

errors=0
warnings=0

# Find all .tf.liquid files
tf_files=$(find . -name "*.tf.liquid" -not -path "./.git/*" -not -path "./node_modules/*")

if [ -z "$tf_files" ]; then
  echo -e "${YELLOW}⚠️  No .tf.liquid files found${NC}"
  exit 0
fi

echo "Found $(echo "$tf_files" | wc -l | tr -d ' ') Terraform files"

# Check for hardcoded strings that should use variables
echo ""
echo "Checking for hardcoded values..."

for file in $tf_files; do
  # Check for hardcoded region (skip files with "warning_" in name - intentional)
  if grep -qE '(us-east-1|us-west-2|eu-west-1|ap-south-1)' "$file" 2>/dev/null; then
    if ! grep -q 'var.aws_region\|var.region\|{{ aws_region }}' "$file"; then
      if ! echo "$file" | grep -q 'warning_'; then
        echo -e "${YELLOW}⚠️  $file: Hardcoded AWS region found - consider using var.aws_region${NC}"
        ((++warnings))
      fi
    fi
  fi

  # Check for common naming pattern
  if grep -qE 'resource[[:space:]]+"[^"]+".+"[^"]+".+\{' "$file"; then
    # Extract resource definitions and check naming
    resources=$(grep -E 'resource[[:space:]]+"[^"]+"[[:space:]]+"[^"]+"' "$file" | sed 's/resource[[:space:]]*"//' | sed 's/"[[:space:]]*"/|/' | sed 's/".*//')

    while IFS='|' read -r _resource_type resource_name; do
      # Check if name uses snake_case
      if ! echo "$resource_name" | grep -qE '^[a-z][a-z0-9_]*$'; then
        echo -e "${YELLOW}⚠️  $file: Resource '$resource_name' should use snake_case${NC}"
        ((++warnings))
      fi
    done <<< "$resources"
  fi
done

# Check for required tags in AWS resources
echo ""
echo "Checking for required tags..."

for file in $tf_files; do
  if echo "$file" | grep -q "aws/"; then
    # Check if file has resource definitions
    if grep -qE 'resource[[:space:]]+"aws_' "$file"; then
      # Check for tags block
      if ! grep -qE 'tags[[:space:]]*=' "$file"; then
        echo -e "${YELLOW}⚠️  $file: AWS resources should have tags${NC}"
        ((++warnings))
      else
        # Check for required tag keys
        required_tags=("Name" "environment" "terraform")
        for tag in "${required_tags[@]}"; do
          if ! grep -qE "${tag}[[:space:]]*=" "$file" && ! grep -qE "\"${tag}\"[[:space:]]*=" "$file"; then
            echo -e "${YELLOW}⚠️  $file: Missing recommended tag: $tag${NC}"
            ((++warnings))
          fi
        done
      fi
    fi
  fi
done

# Check for security group rules with 0.0.0.0/0
echo ""
echo "Checking security group rules..."

for file in $tf_files; do
  if grep -qE 'cidr_blocks.*=.*\["?0\.0\.0\.0/0"?\]' "$file"; then
    # Allow 0.0.0.0/0 in ALB, ingress, bastion, and security-groups modules
    if ! echo "$file" | grep -qE '(alb|ingress|bastion|security-groups)'; then
      echo -e "${YELLOW}⚠️  $file: Found 0.0.0.0/0 CIDR - ensure this is intentional${NC}"
      ((++warnings))
    fi
  fi
done

# Summary
echo ""
echo "================================================"
if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
  echo -e "${GREEN}✓ All naming conventions are followed!${NC}"
  exit 0
elif [ $errors -eq 0 ]; then
  echo -e "${YELLOW}⚠️  Found $warnings warning(s) - review recommended${NC}"
  exit 0
else
  echo -e "${RED}✗ Found $errors error(s) and $warnings warning(s)${NC}"
  exit 1
fi
