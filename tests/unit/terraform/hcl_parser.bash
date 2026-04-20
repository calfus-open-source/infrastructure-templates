#!/usr/bin/env bash
# Helper functions for Terraform HCL parsing
# Used by Terraform unit tests

# Extract variable blocks from a Terraform file
# Usage: tf_extract_variables "file.tf.liquid"
tf_extract_variables() {
  local file="$1"
  grep -E '^variable\s+' "$file" | sed 's/.*"\([^"]*\)".*/\1/'
}

# Check if a variable has a description
# Usage: tf_variable_has_description "file.tf.liquid" "var_name"
tf_variable_has_description() {
  local file="$1"
  local var_name="$2"

  # Find the variable block and check for description
  awk -v var="$var_name" '
    /^variable\s+"'"$var_name"'"/ {in_var=1}
    in_var && /description\s*=/ {print "yes"; exit}
    in_var && /^}/ {exit}
  ' "$file" | grep -q "yes"
}

# Check if a variable has a type
# Usage: tf_variable_has_type "file.tf.liquid" "var_name"
tf_variable_has_type() {
  local file="$1"
  local var_name="$2"

  awk -v var="$var_name" '
    /^variable\s+"'"$var_name"'"/ {in_var=1}
    in_var && /type\s*=/ {print "yes"; exit}
    in_var && /^}/ {exit}
  ' "$file" | grep -q "yes"
}

# Check if a variable is marked as required
# Usage: tf_variable_is_required "file.tf.liquid" "var_name"
tf_variable_is_required() {
  local file="$1"
  local var_name="$2"

  # If variable has no default, it's required
  awk -v var="$var_name" '
    /^variable\s+"'"$var_name"'"/ {in_var=1}
    in_var && /default\s*=/ {print "has_default"; exit}
    in_var && /^}/ {print "no_default"; exit}
  ' "$file" | grep -q "no_default"
}

# Extract all resource types from a file
# Usage: tf_extract_resource_types "file.tf.liquid"
tf_extract_resource_types() {
  local file="$1"
  grep -E '^resource\s+' "$file" | sed 's/.*"\([^"]*\)".*/\1/' | sort -u
}

# Count resources of a type
# Usage: tf_count_resources "file.tf.liquid" "aws_vpc"
tf_count_resources() {
  local file="$1"
  local resource_type="$2"
  grep -c "^resource \"${resource_type}\"" "$file" || echo "0"
}

# Check if all resources have tags
# Usage: tf_resources_have_tags "file.tf.liquid"
tf_resources_have_tags() {
  local file="$1"

  # Extract all resource blocks and check for tags
  awk '
    /^resource\s+/ {in_resource=1; resource=$0}
    in_resource && /^\s*tags\s*=/ {found_tags=1}
    /^}/ && in_resource {
      if (!found_tags) {
        print "Missing tags in: " resource
      }
      in_resource=0
      found_tags=0
    }
  ' "$file" | wc -l
}

# Extract output names
# Usage: tf_extract_output_names "file.tf.liquid"
tf_extract_output_names() {
  local file="$1"
  grep -E '^output\s+' "$file" | sed 's/.*"\([^"]*\)".*/\1/'
}

# Check if output has a value
# Usage: tf_output_has_value "file.tf.liquid" "output_name"
tf_output_has_value() {
  local file="$1"
  local output_name="$2"

  awk -v out="$output_name" '
    /^output\s+"'"$output_name"'"/ {in_output=1}
    in_output && /value\s*=/ {print "yes"; exit}
    in_output && /^}/ {exit}
  ' "$file" | grep -q "yes"
}

# Check if file uses a module
# Usage: tf_uses_module "file.tf.liquid" "module_name"
tf_uses_module() {
  local file="$1"
  local module_name="$2"

  grep -q "^module \"${module_name}\"" "$file"
}

# Extract module source
# Usage: tf_get_module_source "file.tf.liquid" "module_name"
tf_get_module_source() {
  local file="$1"
  local module_name="$2"

  awk -v mod="$module_name" '
    /^module\s+"'"$module_name"'"/ {in_module=1}
    in_module && /source\s*=/ {
      match($0, /source\s*=\s*"([^"]*)"/, arr)
      print arr[1]
      exit
    }
    in_module && /^}/ {exit}
  ' "$file"
}
