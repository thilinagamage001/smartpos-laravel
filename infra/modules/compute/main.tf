data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.sg_id]
  key_name               = var.key_name
  iam_instance_profile   = var.instance_profile

  # AWS Free Tier includes up to 30 GB of gp2/gp3 EBS storage
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<-USERDATA
#!/bin/bash
set -e

# Provision 2GB swap file so t3.micro (1GB RAM) never hits OOM during Docker builds or queue jobs
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# Wait for apt lock to be released (unattended-upgrades runs on first boot)
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
  echo "Waiting for apt lock..."
  sleep 5
done

# Install runtime dependencies
apt-get update -y
apt-get install -y docker.io git netcat-openbsd curl
apt-get install -y docker-compose-v2 || true

# Ensure docker compose CLI plugin is ready
if ! docker compose version >/dev/null 2>&1; then
  mkdir -p /usr/local/lib/docker/cli-plugins
  curl -fsSL https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Clone repository
rm -rf /home/ubuntu/smartpos
git clone -b ${var.git_branch} ${var.git_repo_url} /home/ubuntu/smartpos

cd /home/ubuntu/smartpos

# Generate 32-byte base64 APP_KEY
APP_KEY_VAL="base64:$(openssl rand -base64 32)"

# Create production .env connecting to RDS PostgreSQL
cat <<EOF > /home/ubuntu/smartpos/.env
APP_NAME=SmartPOS
APP_ENV=production
APP_KEY=$APP_KEY_VAL
APP_DEBUG=false
APP_URL=http://localhost

DB_CONNECTION=pgsql
DB_HOST=${var.db_host}
DB_PORT=5432
DB_DATABASE=smartpos
DB_USERNAME=${var.db_username}
DB_PASSWORD=${var.db_password}

SESSION_DRIVER=database
CACHE_STORE=database
QUEUE_CONNECTION=database
FILESYSTEM_DISK=local
EOF

# Ensure docker-compose.prod.yml exists even if not yet pushed to git
if [ ! -f /home/ubuntu/smartpos/docker-compose.prod.yml ]; then
cat <<'COMPOSE_EOF' > /home/ubuntu/smartpos/docker-compose.prod.yml
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile
    image: smartpos-app:latest
    restart: unless-stopped
    ports:
      - "80:80"
    env_file:
      - .env
    command: >
      sh -c "php artisan config:cache &&
             php artisan route:cache &&
             php artisan view:cache &&
             php artisan migrate --force &&
             /start.sh"
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  worker:
    image: smartpos-app:latest
    restart: unless-stopped
    env_file:
      - .env
    command: php artisan queue:work --sleep=3 --tries=3 --timeout=90 --memory=64
    depends_on:
      - app
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
COMPOSE_EOF
fi

chown -R ubuntu:ubuntu /home/ubuntu/smartpos

# Wait for RDS PostgreSQL port 5432 to accept connections
echo "Waiting for RDS PostgreSQL at ${var.db_host}:5432..."
while ! nc -z -w5 ${var.db_host} 5432; do
  echo "Waiting for PostgreSQL..."
  sleep 5
done
echo "RDS PostgreSQL is reachable!"

# Build and launch production Docker containers
docker compose -f docker-compose.prod.yml up -d --build

# Wait for container startup and seed default database & admin user
sleep 10
docker compose -f docker-compose.prod.yml exec -T app php artisan db:seed --force || true

echo "user_data complete" > /tmp/user_data_done.txt
USERDATA

  tags = {
    Name    = "${var.project}-app"
    Project = var.project
  }
}

resource "aws_eip" "app" {
  instance = aws_instance.app.id
  domain   = "vpc"

  tags = {
    Name    = "${var.project}-eip"
    Project = var.project
  }
}
