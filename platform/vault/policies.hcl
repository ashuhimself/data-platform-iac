# Database Policies
path "secret/data/database/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/metadata/database/*" {
  capabilities = ["list"]
}

# Airflow Application Policy
path "secret/data/airflow/*" {
  capabilities = ["read", "list"]
}

path "secret/data/database/postgresql" {
  capabilities = ["read"]
}

path "secret/data/database/redis" {
  capabilities = ["read"]
}

# Superset Application Policy
path "secret/data/superset/*" {
  capabilities = ["read", "list"]
}

path "secret/data/database/postgresql" {
  capabilities = ["read"]
}

path "secret/data/database/redis" {
  capabilities = ["read"]
}

# Trino Application Policy
path "secret/data/trino/*" {
  capabilities = ["read", "list"]
}

path "secret/data/database/trino" {
  capabilities = ["read"]
}

# ClickHouse Application Policy
path "secret/data/clickhouse/*" {
  capabilities = ["read", "list"]
}

path "secret/data/database/clickhouse" {
  capabilities = ["read"]
}

# Ranger Application Policy
path "secret/data/ranger/*" {
  capabilities = ["read", "list"]
}

path "secret/data/database/postgresql" {
  capabilities = ["read"]
}

# Monitoring Stack Policy
path "secret/data/monitoring/*" {
  capabilities = ["read", "list"]
}

# General Application Policy for Data Platform
path "secret/data/dataplatform/*" {
  capabilities = ["read", "list"]
}

# Certificate Management
path "secret/data/certificates/*" {
  capabilities = ["read", "list"]
}

# API Keys and External Service Credentials
path "secret/data/api-keys/*" {
  capabilities = ["read", "list"]
}