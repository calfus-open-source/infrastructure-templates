#!/usr/bin/env bash
# Validate Liquid template syntax and variable references
# Usage: ./scripts/validate-liquid-templates.sh

set -e

echo "🔍 Validating Liquid templates..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

errors=0
warnings=0

# Find all .liquid files, excluding test fixtures
liquid_files=$(find . -name "*.liquid" -not -path "./.git/*" -not -path "./node_modules/*" -not -path "./tests/fixtures/*" -not -path "./tests/unit/fixtures/*")

if [ -z "$liquid_files" ]; then
  echo -e "${YELLOW}⚠️  No .liquid files found${NC}"
  exit 0
fi

echo "Found $(echo "$liquid_files" | wc -l | tr -d ' ') .liquid files"

# Check for unmatched Liquid tags
echo ""
echo "Checking for unmatched Liquid tags..."

for file in $liquid_files; do
  # Count opening and closing if tags
  if_count=$(grep -o '{%[[:space:]]*if[[:space:]]' "$file" 2>/dev/null | wc -l | tr -d ' ')
  endif_count=$(grep -o '{%[[:space:]]*endif[[:space:]]*%}' "$file" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$if_count" -ne "$endif_count" ]; then
    echo -e "${RED}✗ $file: Unmatched {% if %} tags (if: $if_count, endif: $endif_count)${NC}"
    ((errors++))
  fi

  # Count opening and closing for tags
  for_count=$(grep -o '{%[[:space:]]*for[[:space:]]' "$file" 2>/dev/null | wc -l | tr -d ' ')
  endfor_count=$(grep -o '{%[[:space:]]*endfor[[:space:]]*%}' "$file" 2>/dev/null | wc -l | tr -d ' ')

  if [ "$for_count" -ne "$endfor_count" ]; then
    echo -e "${RED}✗ $file: Unmatched {% for %} tags (for: $for_count, endfor: $endfor_count)${NC}"
    ((errors++))
  fi

  # Check for orphaned endif/endfor
  if grep -q '{%[[:space:]]*endif[[:space:]]*%}' "$file" 2>/dev/null || false; then
    if [ "$if_count" -eq 0 ] && [ "$endif_count" -gt 0 ]; then
      echo -e "${RED}✗ $file: Found {% endif %} without {% if %}${NC}"
      ((errors++))
    fi
  fi
done

# Check for common Liquid syntax errors
echo ""
echo "Checking for common syntax errors..."

for file in $liquid_files; do
  # Check for malformed variable interpolation
  if (grep -qE '\{\{[^}]*\{' "$file" 2>/dev/null || grep -qE '\}\}[^{]*\}' "$file" 2>/dev/null) || false; then
    echo -e "${YELLOW}⚠️  $file: Possible malformed variable interpolation${NC}"
    ((warnings++))
  fi

  # Check for single braces (might be typo)
  # Skip check for files that legitimately contain JSON, HCL, or YAML interpolation
  if grep -qE '\{[^{%#]' "$file" 2>/dev/null || false; then
    # Filter out valid patterns in Terraform, JSON, and YAML files
    # - .tf.liquid files contain HCL code with ${var.xxx} patterns
    # - .tfvars.liquid files contain Terraform variables with {{ }} Liquid syntax
    # - .json.liquid files contain JSON with ${...} references
    # - .yml.liquid files contain YAML with similar patterns
    # - Files with jsonencode/yamlencode functions
    if ! [[ "$file" =~ \.(tf|tfvars|json|ya?ml)\.liquid$ ]] && ! (grep -qE '(<<EOF|<<-EOF|jsonencode|yamlencode)' "$file" 2>/dev/null || false); then
      echo -e "${YELLOW}⚠️  $file: Found single '{' - might be a typo${NC}"
      ((warnings++))
    fi
  fi

  # Check for undefined filter usage (common mistake)
  if grep -qE '\{\{.*\|[[:space:]]*[a-z_]+[[:space:]]*\}\}' "$file" 2>/dev/null || false; then
    filters=$(grep -oE '\|[[:space:]]*([a-z_]+)' "$file" 2>/dev/null | sed 's/|[[:space:]]*//' | sort -u || true)
    for filter in $filters; do
      # List of known Liquid filters
      if ! echo "$filter" | grep -qE '^(replace|downcase|upcase|capitalize|strip|lstrip|rstrip|strip_html|strip_newlines|newline_to_br|escape|escape_once|url_encode|url_decode|slice|truncate|truncatewords|split|join|sort|sort_natural|reverse|uniq|compact|concat|map|where|group_by|size|first|last|abs|ceil|floor|round|plus|minus|times|divided_by|modulo|prepend|append|default|date|json)$'; then
        echo -e "${YELLOW}⚠️  $file: Unknown Liquid filter: '$filter' - verify it's supported${NC}"
        ((warnings++))
      fi
    done
  fi
done

# Summary
echo ""
echo "================================================"
if [ $errors -eq 0 ] && [ $warnings -eq 0 ]; then
  echo -e "${GREEN}✓ All Liquid templates are valid!${NC}"
  exit 0
elif [ $errors -eq 0 ]; then
  echo -e "${YELLOW}⚠️  Validation completed with $warnings warning(s)${NC}"
  exit 0
else
  echo -e "${RED}✗ Validation failed with $errors error(s) and $warnings warning(s)${NC}"
  exit 1
fi
