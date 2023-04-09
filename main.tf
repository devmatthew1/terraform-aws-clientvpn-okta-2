terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  profile = "shola"
  region = "us-west-2"
}

# Step 1: Upload the server certificate and the client certificate to ACM from my computer
resource "aws_acm_certificate" "server_cert" {
  private_key = file("certs/server.key")
  certificate_body = file("certs/server.crt")
  certificate_chain = file("certs/ca.crt")
  tags = {
    Name = "server_cert"
  }
}

resource "aws_acm_certificate" "client_cert" {
  private_key = file("certs/client1.domain.tld.key")
  certificate_body = file("certs/client1.domain.tld.crt")
  certificate_chain = file("certs/ca.crt")
  tags = {
    Name = "client_cert"
  }
}

resource "aws_iam_saml_provider" "default" {
  name                   = "myprovider"
  saml_metadata_document = file("certs/okta-app.xml")
}

resource "aws_iam_saml_provider" "default-two" {
  name                   = "myprovider-two"
  saml_metadata_document = file("certs/okta-self-service.xml")
}

# Step 2: Create a Client VPN endpoint   
resource "aws_ec2_client_vpn_endpoint" "my_vpn_endpoint" {
  server_certificate_arn = aws_acm_certificate.server_cert.arn
 
  
  authentication_options {
    
    type = "federated-authentication"
    saml_provider_arn = aws_iam_saml_provider.default.arn
    self_service_saml_provider_arn = aws_iam_saml_provider.default-two.arn
  
  }

//ip address given to clients after they connect
  client_cidr_block = "10.1.0.0/16"
  dns_servers       = ["8.8.8.8"]
  transport_protocol = "udp"
  split_tunnel = true
  self_service_portal = "enabled"
  connection_log_options {
    enabled = false
   
  }
}

# Step 3: Associate a target network
resource "aws_ec2_client_vpn_network_association" "target_network" {
  count = length(aws_subnet.sn_az)  
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.my_vpn_endpoint.id
  subnet_id = aws_subnet.sn_az[count.index].id
  security_groups = [aws_security_group.vpn_access.id]

  lifecycle {
    
    ignore_changes = [subnet_id]
  }
}

# Step 4: Add an authorization rule for the VPC
resource "aws_ec2_client_vpn_authorization_rule" "vpc_authorization_rule" {
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.my_vpn_endpoint.id

  //ip address of clients that should be able to connect
  target_network_cidr = aws_vpc.main.cidr_block

  authorize_all_groups = true
 
}

# Step 5: Provide access to the internet
resource "aws_ec2_client_vpn_route" "internet_access_route" {
  count = length(aws_subnet.sn_az)  
  client_vpn_endpoint_id = aws_ec2_client_vpn_endpoint.my_vpn_endpoint.id
  destination_cidr_block = "0.0.0.0/0"
  target_vpc_subnet_id   = aws_ec2_client_vpn_network_association.target_network[count.index].subnet_id
}


# Step 6: Verify security group requirements

resource "aws_security_group" "vpn_access" {
  vpc_id = aws_vpc.main.id
  name = "vpn-example-sg"

  ingress {
    from_port = 443
    protocol = "UDP"
    to_port = 443
    cidr_blocks = [
      "0.0.0.0/0"]
    description = "Incoming VPN connection"
  }

  egress {
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [
      "0.0.0.0/0"]
  }

}


