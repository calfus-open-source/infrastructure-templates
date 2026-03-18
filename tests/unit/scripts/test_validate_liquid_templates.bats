#!/usr/bin/env bats
# Unit tests for scripts/validate-liquid-templates.sh
# Tests the Liquid template validation script

setup() {
  load ../helpers
  setup_test_env

  # Create test workspace
  TEST_WORKSPACE=$(mktemp -d)
  export TEST_WORKSPACE

  # Script under test
  VALIDATOR="${REPO_ROOT}/scripts/validate-liquid-templates.sh"
}

teardown() {
  teardown_test_env
  [ -n "$TEST_WORKSPACE" ] && [ -d "$TEST_WORKSPACE" ] && rm -rf "$TEST_WORKSPACE"
}

# ============================================================================
# Test: Valid templates (script scans current directory)
# ============================================================================

@test "accepts valid liquid template with if block" {
  cp "${FIXTURES_DIR}/liquid/valid_template.liquid" "$TEST_WORKSPACE/"

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"valid"* ]]
}

@test "accepts empty liquid template" {
  cp "${FIXTURES_DIR}/liquid/valid_empty.liquid" "$TEST_WORKSPACE/empty.liquid"

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
}

@test "accepts multiple matching if blocks" {
  cat > "$TEST_WORKSPACE/multi_if.liquid" <<'EOF'
{% if condition_1 %}
  # block 1
{% endif %}

{% if condition_2 %}
  # block 2
{% endif %}
EOF

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
}

@test "accepts multiple matching for loops" {
  cat > "$TEST_WORKSPACE/multi_for.liquid" <<'EOF'
{% for item in list_1 %}
  # loop 1
{% endfor %}

{% for item in list_2 %}
  # loop 2
{% endfor %}
EOF

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
}

@test "accepts nested if and for tags" {
  cat > "$TEST_WORKSPACE/nested.liquid" <<'EOF'
{% if enable_subnets %}
  {% for az in azs %}
    resource "aws_subnet" "main" {
      availability_zone = az
    }
  {% endfor %}
{% endif %}
EOF

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
}

# ============================================================================
# Test: Unmatched if tags
# ============================================================================

@test "rejects unmatched if tag (missing endif)" {
  cp "${FIXTURES_DIR}/liquid/invalid_if_unmatched.liquid" "$TEST_WORKSPACE/"

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unmatched"* ]] || [[ "$output" == *"if"* ]] || [[ "$output" == *"endif"* ]]
}

@test "rejects multiple unmatched if tags" {
  cat > "$TEST_WORKSPACE/bad_if.liquid" <<'EOF'
{% if condition_1 %}
  block 1

{% if condition_2 %}
  block 2
{% endif %}
EOF

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -ne 0 ]
}

@test "rejects extra endif without matching if" {
  cat > "$TEST_WORKSPACE/bad_endif.liquid" <<'EOF'
resource "aws_vpc" "main" {}
{% endif %}
EOF

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -ne 0 ]
}

# ============================================================================
# Test: Unmatched for loops
# ============================================================================

@test "rejects unmatched for tag (missing endfor)" {
  cp "${FIXTURES_DIR}/liquid/invalid_for_unmatched.liquid" "$TEST_WORKSPACE/"

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Unmatched"* ]] || [[ "$output" == *"for"* ]] || [[ "$output" == *"endfor"* ]]
}

@test "rejects multiple unmatched for tags" {
  cat > "$TEST_WORKSPACE/bad_for.liquid" <<'EOF'
{% for item in list_1 %}
  item 1

{% for item in list_2 %}
  item 2
{% endfor %}
EOF

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -ne 0 ]
}

@test "rejects extra endfor without matching for" {
  cat > "$TEST_WORKSPACE/bad_endfor.liquid" <<'EOF'
resource "aws_vpc" "main" {}
{% endfor %}
EOF

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -ne 0 ]
}

# ============================================================================
# Test: Nested tag mismatches
# ============================================================================

@test "rejects nested tags with mismatched endif" {
  cp "${FIXTURES_DIR}/liquid/invalid_nested_mismatch.liquid" "$TEST_WORKSPACE/"

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -ne 0 ]
}

@test "rejects nested if inside for without proper closure" {
  cat > "$TEST_WORKSPACE/bad_nested1.liquid" <<'EOF'
{% for item in list %}
  {% if condition %}
    content
  # Missing endif
{% endfor %}
EOF

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -ne 0 ]
}

@test "rejects nested for inside if without proper closure" {
  cat > "$TEST_WORKSPACE/bad_nested2.liquid" <<'EOF'
{% if condition %}
  {% for item in list %}
    content
  # Missing endfor
{% endif %}
EOF

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -ne 0 ]
}

# ============================================================================
# Test: Edge cases
# ============================================================================

@test "handles liquid comments correctly" {
  cat > "$TEST_WORKSPACE/with_comments.liquid" <<'EOF'
{# This is a comment #}
{% if condition %}
  resource "aws_vpc" "main" {}
{% endif %}
EOF

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
}

@test "handles whitespace in tags" {
  cat > "$TEST_WORKSPACE/whitespace.liquid" <<'EOF'
{%  if   condition  %}
  content
{%  endif  %}

{%  for item  in  list  %}
  content
{%  endfor  %}
EOF

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
}

@test "finds no liquid files when directory is empty" {
  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No .liquid files found"* ]]
}

@test "processes multiple liquid files in directory" {
  cat > "$TEST_WORKSPACE/file1.liquid" <<'EOF'
{% if condition %}content{% endif %}
EOF

  cat > "$TEST_WORKSPACE/file2.liquid" <<'EOF'
{% for item in list %}content{% endfor %}
EOF

  cd "$TEST_WORKSPACE"
  run bash "$VALIDATOR"
  [ "$status" -eq 0 ]
}
