provider "aws" {
  region = "us-east-1"
}

# Create a new VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "MyVPC"
  }
}

# Create an internet gateway
resource "aws_internet_gateway" "my_internet_gateway" {
  vpc_id = aws_vpc.my_vpc.id
}

# Create a subnet
resource "aws_subnet" "my_subnet" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.0.0/27"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "MySubnet"
  }
}

# Route table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_internet_gateway.id
  }

  tags = {
    Name = "MyRouteTable"
  }
}

# Route table association
resource "aws_route_table_association" "my_route_table_association" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

# Security Group for EC2 instance
resource "aws_security_group" "python_sg" {
  name        = "python_app_sg"
  description = "Allow SSH, HTTP, and HTTPS traffic"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

# IAM Role for EC2 instance to push logs to CloudWatch
resource "aws_iam_role" "cloudwatch_role" {
  name = "cloudwatch-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach CloudWatch Logs Full Access policy
resource "aws_iam_role_policy_attachment" "cloudwatch_logs" {
  role       = aws_iam_role.cloudwatch_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# IAM Role for EC2 Instance Connect
resource "aws_iam_role" "ec2_connect_role" {
  name = "ec2-connect-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach EC2 Instance Connect policy to the role
resource "aws_iam_role_policy_attachment" "ec2_connect_policy" {
  role       = aws_iam_role.ec2_connect_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess" # Fallback policy
}

# IAM Instance Profile for EC2
resource "aws_iam_instance_profile" "ec2_connect_profile" {
  name = "ec2-connect-profile"
  role = aws_iam_role.ec2_connect_role.name
}

# EC2 Instance
resource "aws_instance" "python_app" {
  ami                    = "ami-0e2c8caa4b6378d8c" 
  instance_type          = "t2.micro"
  key_name               = "Terraform"
  subnet_id              = aws_subnet.my_subnet.id
  vpc_security_group_ids = [aws_security_group.python_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2_connect_profile.name

  user_data = <<-EOF
    #!/bin/bash

# Update the system and install necessary packages
sudo apt update -y
sudo apt upgrade -y
sudo apt install -y python3-pip python3-dev git wget curl python3-venv python3-full

# Fix potential issues with CloudWatch Agent installation
sudo apt remove --purge amazon-cloudwatch-agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb -P /tmp
sudo dpkg -i /tmp/amazon-cloudwatch-agent.deb

# Check if CloudWatch agent installed successfully
if ! command -v amazon-cloudwatch-agent-config-wizard &>/dev/null; then
    echo "CloudWatch Agent configuration wizard not found. Installing CloudWatch agent again."
    sudo apt install amazon-cloudwatch-agent
fi

# Create and activate virtual environment
python3 -m venv ~/flask_venv
source ~/flask_venv/bin/activate

# Upgrade pip and install Flask and Gunicorn
pip install --upgrade pip
pip install flask gunicorn

# Clone Flask app repository
cd /home/ubuntu
rm -rf flask-app
git clone https://github.com/qwe324fsf1324ffjgi/flask-app.git
cd flask-app

# Create Flask app file (app.py)
echo 'from flask import Flask, render_template
app = Flask(__name__)

@app.route("/")
def hello_world():
    return render_template("index.html")

@app.route("/about")
def about():
    return render_template("about.html")

@app.route("/contact")
def contact():
    return render_template("contact.html")

@app.errorhandler(404)
def page_not_found(e):
    return render_template("404.html"), 404

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=80, debug=True)' > app.py

# Ensure correct permissions for app.py file
sudo chmod +x app.py

# Start Flask app using Gunicorn in the foreground with sudo
echo "Starting Flask app with Gunicorn..."
sudo ~/flask_venv/bin/gunicorn -w 4 -b 0.0.0.0:80 app:app

echo "Creating CloudWatch agent configuration file..."

# Ensure the directory exists
sudo mkdir -p /opt/aws/amazon-cloudwatch-agent/etc/

# Create the configuration file
sudo bash -c 'cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << EOF
{
  "agent": {
    "metrics_collection_interval": 60,
    "run_as_user": "root"
  },
  "metrics": {
    "append_dimensions": {
      "InstanceId": "$${aws:InstanceId}"
    },
    "aggregation_dimensions": [["InstanceId"]],
    "metrics_collected": {
      "CPU": {
        "measurement": ["cpu_usage_idle", "cpu_usage_iowait"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      },
      "Disk": {
        "measurement": ["disk_used", "disk_free"],
        "metrics_collection_interval": 60,
        "resources": ["*"]
      }
    }
  }
}
EOF'

# Check if the file was created successfully
if [ -f "/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json" ]; then
    echo "CloudWatch agent configuration file created successfully."
else
    echo "Failed to create the CloudWatch agent configuration file. Exiting script."
    exit 1
fi

# Start the CloudWatch agent service
echo "Starting CloudWatch agent service..."
sudo systemctl start amazon-cloudwatch-agent

# Enable the CloudWatch agent to start on boot
echo "Enabling CloudWatch agent to start on boot..."
sudo systemctl enable amazon-cloudwatch-agent

# Verify CloudWatch agent status
echo "Verifying CloudWatch agent status..."
sudo systemctl status amazon-cloudwatch-agent

# Final message
echo "CloudWatch agent has been configured and started successfully."
      EOF

  tags = {
    Name = "PythonAppServer"
  }

  depends_on = [
    aws_iam_role_policy_attachment.cloudwatch_logs,
    aws_iam_role_policy_attachment.ec2_connect_policy
  ]
}
