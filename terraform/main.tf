provider "aws" {
  region = "us-east-1"
}

resource "aws_security_group" "subcrawler_sg" {
  name        = "subcrawler_sg"
  description = "Allow inbound traffic for SubCrawler"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 5001
    to_port     = 5001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 16443
    to_port     = 16443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "subcrawler_instance" {
  ami                         = "ami-05cf1e9f73fbad2e2"
  instance_type               = "c7i-flex.large"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.subcrawler_sg.id]

  user_data = <<-EOF
              #!/bin/bash
              set -xe

              apt-get update -y
              apt-get upgrade -y
              apt-get install -y snapd curl ca-certificates

              systemctl enable --now snapd.socket
              ln -s /var/lib/snapd/snap /snap || true
              export PATH=/snap/bin:$PATH

              snap install core
              for i in {1..12}; do
                snap list core >/dev/null 2>&1 && break
                sleep 5
              done

              snap install microk8s --classic --channel=1.28/stable
              for i in {1..30}; do
                command -v microk8s >/dev/null 2>&1 && break
                sleep 5
              done

              microk8s status --wait-ready
              microk8s enable dns hostpath-storage

              snap install helm --classic

              usermod -a -G microk8s ubuntu
              mkdir -p /home/ubuntu/.kube
              chown -R ubuntu:ubuntu /home/ubuntu/.kube

              TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" \
                -H "X-aws-ec2-metadata-token-ttl-seconds: 21600" || true)

              if [ -n "$TOKEN" ]; then
                PUBLIC_IP=$(curl -fs -H "X-aws-ec2-metadata-token: $TOKEN" \
                  http://169.254.169.254/latest/meta-data/public-ipv4 || true)
              else
                PUBLIC_IP=$(curl -fs http://169.254.169.254/latest/meta-data/public-ipv4 || true)
              fi

              CSR_TEMPLATE=/var/snap/microk8s/current/certs/csr.conf.template

              for i in {1..60}; do
                [ -f "$CSR_TEMPLATE" ] && break
                sleep 2
              done

              if [ -n "$PUBLIC_IP" ] && [ -f "$CSR_TEMPLATE" ]; then
                echo "Using public IP: $PUBLIC_IP"
                cp "$CSR_TEMPLATE" "$CSR_TEMPLATE.bak"

                if grep -Eq "^[[:space:]]*IP\\.3[[:space:]]*=[[:space:]]*$PUBLIC_IP[[:space:]]*$" "$CSR_TEMPLATE"; then
                  echo "IP.3 already set correctly"
                else
                  if grep -q '^IP\.3[[:space:]]*=' "$CSR_TEMPLATE"; then
                    sed -i "s|^IP\.3[[:space:]]*=.*$|IP.3 = $PUBLIC_IP|" "$CSR_TEMPLATE"
                  elif grep -q '^#MOREIPS$' "$CSR_TEMPLATE"; then
                    sed -i "/^#MOREIPS$/i IP.3 = $PUBLIC_IP" "$CSR_TEMPLATE"
                  elif grep -q '^\[ v3_ext \]' "$CSR_TEMPLATE"; then
                    sed -i "/^\[ v3_ext \]/i IP.3 = $PUBLIC_IP" "$CSR_TEMPLATE"
                  else
                    echo "Could not find insertion point for IP.3 in $CSR_TEMPLATE" >&2
                  fi

                  echo "Updated csr.conf.template:"
                  sed -n '/^\[ alt_names \]/,/^\[ v3_ext \]/p' "$CSR_TEMPLATE"

                  microk8s stop
                  microk8s refresh-certs --cert server.crt || microk8s refresh-certs -e server.crt
                  microk8s start
                  microk8s status --wait-ready
                fi
              else
                echo "PUBLIC_IP is empty or csr.conf.template not found"
              fi

              echo "alias kubectl='microk8s kubectl'" >> /home/ubuntu/.bashrc
              chown ubuntu:ubuntu /home/ubuntu/.bashrc
              EOF

  tags = {
    Name = "SubCrawlerInstance"
  }
}

output "instance_public_ip" {
  value = aws_instance.subcrawler_instance.public_ip
}