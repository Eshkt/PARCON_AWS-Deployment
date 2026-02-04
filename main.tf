#Connect AWS acc to compiler/tf

provider "aws" {
    region = "us-east-1"
    #secret keys were configure in aws configure using AWS CLI
}

#1.Create VPC
resource "aws_vpc" "lab" {
    cidr_block = "10.0.0.0/16"
    enable_dns_hostnames = true
    enable_dns_support = true
    tags = {
        Name = "practice"
    }
}

#2.Create Internet Gateway
resource "aws_internet_gateway" "gateway" {
    vpc_id = aws_vpc.lab.id
}

#3. Create Custom Route Table

resource "aws_route_table" "route" {
    vpc_id = aws_vpc.lab.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.gateway.id
    }
    route {
        ipv6_cidr_block = "::/0"
        gateway_id = aws_internet_gateway.gateway.id
    }

    tags = {
        Name = "route_lab"
    }
  
}
#4. Create a subnet
resource "aws_subnet" "sn_prac" {
    vpc_id = aws_vpc.lab.id
    cidr_block = "10.0.1.0/24"
    availability_zone = "us-east-1a"

    tags = {
        Name = "subnet for prac"
    }
  
}

#5. Associate subent with Route Table
resource "aws_route_table_association" "r_table" {
    subnet_id = aws_subnet.sn_prac.id
    route_table_id = aws_route_table.route.id
}

# 6. Create Security Group to allow port 22,80,443
resource "aws_security_group" "allow_http" {
    name = "allow_web_traffic"
    description =  "To allow TLS, HTTP and HTTPS"
    vpc_id = aws_vpc.lab.id 

    ingress {
        description = "HTTPS from VPC"
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "SSH from VPC"
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        description = "Allow HTTP"
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]

    }

    tags = {
      Name = "allow_web"
    }

}

# 7. Create a network interface from the ip of the subnet from num.4

resource "aws_network_interface" "test" {
    subnet_id = aws_subnet.sn_prac.id
    private_ip = "10.0.1.200"
    security_groups = [aws_security_group.allow_http.id]
}

#8. Create an elastic IP to the network interface created in step 7

resource "aws_eip" "eip" {
    network_interface = aws_network_interface.test.id
    domain = "vpc"
    depends_on = [aws_internet_gateway.gateway, aws_instance.prac_instance]
}
# 9. Creata an Amazon AMI server and install/enable apache

resource "aws_instance" "prac_instance" {
    ami = "ami-0532be01f26a3de55"
    instance_type = "t3.micro"
    availability_zone = "us-east-1a"
    key_name = "prac-key"

    network_interface {
      device_index = 0
      network_interface_id = aws_network_interface.test.id
    }

user_data = <<-EOF
    #!/bin/bash
    # 1. Update and Install Apache
    sudo dnf update -y
    sudo dnf install httpd -y

    # 2. Start and Enable (so it persists after reboots)
    sudo systemctl start httpd
    sudo systemctl enable httpd

    # 3. Create the web content
    # Using 'tee' ensures we have the right permissions to write to the folder
    echo "<h1>Success!</h1><p>The lab is fully automated on Amazon Linux using Terraform. FUCK ASS SOFTWARE</p>" | sudo tee /var/www/html/index.html

    # 4. Final check: Ensure permissions are correct for Apache to read the file
    sudo chmod 644 /var/www/html/index.html
    EOF

    tags = {
      Name = "First-infrastructure"
    }
}

output "web_public_ip" {
    value = "http://${aws_eip.eip.public_ip}"
    description = "<h1>This is my first deployed Infrastructure using Terraform</h1>"
}