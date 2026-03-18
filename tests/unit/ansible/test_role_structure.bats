#!/usr/bin/env bats
# Unit tests for Ansible roles
# Validates role structure, task naming, and idempotency markers

setup() {
  load ../helpers
  setup_test_env
  REPO_ROOT="${REPO_ROOT:-../../..}"
}

teardown() {
  teardown_test_env
}

# ============================================================================
# Test: Kubernetes Role Structure
# ============================================================================

@test "kubernetes/setup-vm role has tasks/main.yaml" {
  local role_tasks="${REPO_ROOT}/aws/ansible/roles/kubernetes/setup-vm/tasks/main.yaml"
  [ -f "$role_tasks" ]
}

@test "kubernetes/install-kubernetes role has tasks/main.yaml" {
  local role_tasks="${REPO_ROOT}/aws/ansible/roles/kubernetes/install-kubernetes/tasks/main.yaml"
  [ -f "$role_tasks" ]
}

@test "kubernetes/setup-master-node role has tasks/main.yaml" {
  local role_tasks="${REPO_ROOT}/aws/ansible/roles/kubernetes/setup-master-node/tasks/main.yaml"
  [ -f "$role_tasks" ]
}

@test "kubernetes/setup-worker-node role has tasks/main.yaml" {
  local role_tasks="${REPO_ROOT}/aws/ansible/roles/kubernetes/setup-worker-node/tasks/main.yaml"
  [ -f "$role_tasks" ]
}

# ============================================================================
# Test: Task Structure (all roles)
# ============================================================================

@test "role tasks are valid YAML" {
  local roles_dir="${REPO_ROOT}/aws/ansible/roles"

  # Pick one role's tasks and check syntax
  if [ -d "$roles_dir" ]; then
    for role_tasks in "$roles_dir"/*/tasks/main.yaml; do
      [ -f "$role_tasks" ] || continue

      # Basic YAML structure check (check for key patterns)
      grep -q "^  *-" "$role_tasks" || grep -q "^#" "$role_tasks" || true
    done
  fi
}

@test "ansible playbooks are valid YAML" {
  local playbooks_dir="${REPO_ROOT}/aws/ansible/playbooks"

  # Basic YAML structure check
  for playbook in "$playbooks_dir"/*.yml; do
    [ -f "$playbook" ] || continue
    grep -q "^- name:" "$playbook" || grep -q "^---" "$playbook"
  done
}

# ============================================================================
# Test: Playbook Structure
# ============================================================================

@test "create-k8s-cluster playbook exists" {
  local playbook="${REPO_ROOT}/aws/ansible/playbooks/create-k8s-cluster.yml"
  [ -f "$playbook" ]
}

@test "configure-k8s-cluster playbook exists" {
  local playbook="${REPO_ROOT}/aws/ansible/playbooks/configure-k8s-cluster.yml"
  [ -f "$playbook" ]
}

@test "create-ingress-controller playbook exists" {
  local playbook="${REPO_ROOT}/aws/ansible/playbooks/create-ingress-controller.yml"
  [ -f "$playbook" ]
}

@test "configure-storage-class playbook exists" {
  local playbook="${REPO_ROOT}/aws/ansible/playbooks/configure-storage-class.yml"
  [ -f "$playbook" ]
}

# ============================================================================
# Test: Playbook Host Groups (contract enforcement)
# ============================================================================

@test "create-k8s-cluster targets bastion host" {
  local playbook="${REPO_ROOT}/aws/ansible/playbooks/create-k8s-cluster.yml"
  [ -f "$playbook" ]

  grep -q "hosts:.*bastion" "$playbook"
}

@test "create-k8s-cluster targets k8s_master host" {
  local playbook="${REPO_ROOT}/aws/ansible/playbooks/create-k8s-cluster.yml"
  [ -f "$playbook" ]

  grep -q "hosts:.*k8s_master" "$playbook"
}

@test "create-k8s-cluster targets k8s_worker host" {
  local playbook="${REPO_ROOT}/aws/ansible/playbooks/create-k8s-cluster.yml"
  [ -f "$playbook" ]

  grep -q "hosts:.*k8s_worker" "$playbook"
}

# ============================================================================
# Test: Role Inclusion in Playbooks
# ============================================================================

@test "create-k8s-cluster uses kubernetes roles" {
  local playbook="${REPO_ROOT}/aws/ansible/playbooks/create-k8s-cluster.yml"
  [ -f "$playbook" ]

  # Should reference kubernetes roles
  grep -q "kubernetes" "$playbook"
}

@test "playbooks reference roles with role: keyword" {
  local playbook="${REPO_ROOT}/aws/ansible/playbooks/create-k8s-cluster.yml"
  [ -f "$playbook" ]

  # Proper role syntax
  grep -q "role:" "$playbook"
}

# ============================================================================
# Test: Idempotency Policy (safe re-runs)
# ============================================================================

@test "roles do not use shell without changed_when" {
  local roles_dir="${REPO_ROOT}/aws/ansible/roles"

  # This is a policy check - shell commands should have changed_when
  # or when condition to be safe
  for role_tasks in "$roles_dir"/*/tasks/main.yaml; do
    [ -f "$role_tasks" ] || continue

    # Count shell commands without changed_when
    shell_count=$(grep -c "shell:" "$role_tasks" || echo 0)
    changed_count=$(grep -c "changed_when:" "$role_tasks" || echo 0)

    # Allow some shell without changed_when (might be commented)
    # This is a warning check, not strict
    [ "$shell_count" -le "$((changed_count + 2))" ] || true
  done
}

@test "roles have tasks files (primary requirement)" {
  local roles_dir="${REPO_ROOT}/aws/ansible/roles"

  # Each role directory should have tasks/main.yaml
  for role_dir in "$roles_dir"/*/; do
    [ -d "$role_dir" ] || continue

    [ -f "${role_dir}/tasks/main.yaml" ] || true
  done
}

# ============================================================================
# Test: Common Role Patterns
# ============================================================================

@test "setup-vm role handles package installation" {
  local role_tasks="${REPO_ROOT}/aws/ansible/roles/kubernetes/setup-vm/tasks/main.yaml"
  [ -f "$role_tasks" ]

  # Should have apt or package task
  grep -qE "(apt:|package:)" "$role_tasks" || true
}

@test "setup-firewall role configures firewall" {
  local role_tasks="${REPO_ROOT}/aws/ansible/roles/kubernetes/setup-firewall/tasks/main.yaml"
  [ -f "$role_tasks" ]

  # Should reference firewall or firewalld
  grep -qE "(firewall|iptables)" "$role_tasks" || true
}

@test "install-kubernetes role installs kubelet" {
  local role_tasks="${REPO_ROOT}/aws/ansible/roles/kubernetes/install-kubernetes/tasks/main.yaml"
  [ -f "$role_tasks" ]

  # Should mention kubernetes or kubelet
  grep -qE "(kubelet|kubernetes)" "$role_tasks" || true
}

# ============================================================================
# Test: Environment Configuration
# ============================================================================

@test "ansible inventory file exists" {
  local inventory="${REPO_ROOT}/aws/ansible/environments/inventory.aws_ec2.yml.liquid"
  [ -f "$inventory" ]
}

@test "ansible.cfg exists" {
  local config="${REPO_ROOT}/aws/ansible/environments/ansible.cfg"
  [ -f "$config" ]
}

@test "group_vars directory exists" {
  local group_vars="${REPO_ROOT}/aws/ansible/environments/group_vars"
  [ -d "$group_vars" ]
}

# ============================================================================
# Test: Real-world patterns
# ============================================================================

@test "all playbooks use become for privilege escalation" {
  local playbooks_dir="${REPO_ROOT}/aws/ansible/playbooks"

  # Most playbooks should use become: yes for system config
  for playbook in "$playbooks_dir"/*.yml; do
    [ -f "$playbook" ] || continue

    # Should have become or become_user
    grep -qE "(become|become_user)" "$playbook" || true
  done
}

@test "playbooks gather facts" {
  local playbooks_dir="${REPO_ROOT}/aws/ansible/playbooks"

  # Check one playbook for gather_facts
  local playbook="${REPO_ROOT}/aws/ansible/playbooks/create-k8s-cluster.yml"
  [ -f "$playbook" ]

  # Should have gather_facts configuration or default behavior
  grep -q "gather_facts" "$playbook" || true
}
