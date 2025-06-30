#!/bin/bash
# Update package lists
apt-get update -y

# Install PostgreSQL client only (no server)
apt-get install -y postgresql-client

# Optional: verify installation
psql --version