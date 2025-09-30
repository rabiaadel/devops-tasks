Certainly! Here's a comprehensive README file that consolidates all your provided files, instructions, and context into a single, clear document:

```markdown
# Spring Petclinic DevOps Deployment Guide

This guide walks you through setting up a full CI/CD pipeline for the Spring Petclinic application, including building Docker images, deploying on AWS EC2, and orchestrating with Docker Compose. It includes the necessary Terraform infrastructure, Jenkins pipeline, Dockerfile, and deployment steps.

---

## Table of Contents
1. Overview
2. Infrastructure Setup with Terraform
3. Jenkins Pipeline Configuration
4. Dockerfile for Petclinic
5. Docker Compose Setup
6. Deployment on AWS EC2
7. Prerequisites
8. Usage Instructions
9. Troubleshooting & Tips
10. Cleanup
11. Files Summary
12. References & Notes

---

## 1. Overview

- **Application**: Spring Petclinic
- **CI/CD**: Jenkins pipeline builds, tests, tags, and pushes Docker images to Docker Hub.
- **Infrastructure**: Terraform provisions VPC, subnets, security groups, and EC2 instance.
- **Deployment**: Pulls Docker image and runs container on EC2 port 8092.
- **Orchestration**: Docker Compose manages multi-container environment locally.

---

## 2. Infrastructure Setup with Terraform

Your Terraform files in the `infra/` directory define:

### provider.tf
```hcl
provider "aws" {
  region = "us-east-1"
}
```

### vpc.tf
```hcl
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = { Name = "petclinic-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags = { Name = "petclinic-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
  tags = { Name = "public-subnet" }
}

resource "aws_subnet" "private" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1a"
  tags = { Name = "private-subnet" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "public-rt" }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}
```

### security.tf
```hcl
resource "aws_security_group" "app_sg" {
  name   = "petclinic-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 8092
    to_port     = 8092
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "petclinic-sg" }
}
```

### ec2.tf
```hcl
resource "aws_instance" "petclinic" {
  ami                         = "ami-0c02fb55956c7d316" # Amazon Linux 2
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.private.id
  key_name                    = var.key_name
  vpc_security_group_ids      = [aws_security_group.app_sg.id]

  tags = { Name = "PetclinicApp" }
}
```

### variables.tf
```hcl
variable "key_name" {
  description = "Name of the AWS key pair for SSH"
  type        = string
}
```

### outputs.tf
```hcl
output "public_ip" {
  value = aws_instance.petclinic.public_ip
}
output "private_ip" {
  value = aws_instance.petclinic.private_ip
}
```

**Note:** Run `terraform init`, then `terraform apply` in the `infra/` directory to provision resources.

---

## 3. Jenkins Pipeline

Your Jenkins pipeline (defined in the `Jenkinsfile`) automates:

- Cloning the repo
- Running Maven tests
- Building the application JAR
- Building Docker image
- Pushing Docker image to Docker Hub
- Deploying the container locally for testing

### Jenkinsfile contents:
```groovy
pipeline {
    agent any

    environment {
        DOCKERHUB_REPO = 'rabiaadel/petclinic-app'
    }

    stages {
        stage('Checkout') {
            steps {
                git branch: 'main',
                    credentialsId: 'github-creds',
                    url: 'https://github.com/rabiaadel/cicd-petclinic.git'
            }
        }
        stage('Unit Tests') {
            steps {
                sh './mvnw test'
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                }
            }
        }
        stage('Build with Maven') {
            steps {
                sh './mvnw clean package -DskipTests'
            }
        }
        stage('Build Docker Image') {
            steps {
                sh 'docker build -t $DOCKERHUB_REPO:${BUILD_NUMBER} .'
                sh 'docker tag $DOCKERHUB_REPO:${BUILD_NUMBER} $DOCKERHUB_REPO:latest'
            }
        }
        stage('Push to Docker Hub') {
            steps {
                withCredentials([usernamePassword(credentialsId: 'dockerhub-creds', usernameVariable: 'DOCKER_USER', passwordVariable: 'DOCKER_PASS')]) {
                    sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
                    sh 'docker push $DOCKERHUB_REPO:${BUILD_NUMBER}'
                    sh 'docker push $DOCKERHUB_REPO:latest'
                }
            }
        }
        stage('Deploy to Local Docker') {
            steps {
                sh '''
                  docker rm -f petclinic-app || true
                  docker run -d --name petclinic-app -p 8090:8090 $DOCKERHUB_REPO:latest
                '''
            }
        }
    }
    post {
        success { echo "✅ Build ${BUILD_NUMBER} successful!" }
        failure { echo "❌ Build ${BUILD_NUMBER} failed!" }
    }
}
```

---

## 4. Dockerfile for Petclinic

Your multi-stage Dockerfile:
```dockerfile
# Build stage
FROM bellsoft/liberica-runtime-container:jdk-21-stream-musl AS build
WORKDIR /app
COPY mvnw .
COPY .mvn .mvn
COPY pom.xml .
RUN chmod +x mvnw
RUN ./mvnw dependency:go-offline -B --no-transfer-progress -DskipTests=true
COPY src src
RUN ./mvnw clean package -DskipTests --no-transfer-progress

# Runtime stage
FROM bellsoft/liberica-runtime-container:jre-21-stream-musl
WORKDIR /app
COPY --from=build /app/target/*-SNAPSHOT.jar app.jar
EXPOSE 8090
ENTRYPOINT ["java", "-jar", "app.jar"]
```
**To run on port 8090**, set environment variable `SERVER_PORT=8090` and map ports accordingly during `docker run`.

---

## 5. Docker Compose Setup

Your `docker-compose.yml` orchestrates services:
```yaml
version: '3.8'
services:
  spring-petclinic:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "8090:8090"
    environment:
      SPRING_PROFILES_ACTIVE: mysql
      SPRING_DATASOURCE_URL: jdbc:mysql://mysql:3306/petclinic?useSSL=false&serverTimezone=UTC&allowPublicKeyRetrieval=true
      SPRING_DATASOURCE_USERNAME: petclinic
      SPRING_DATASOURCE_PASSWORD: petclinic
      SPRING_JPA_HIBERNATE_DDL_AUTO: validate
    depends_on:
      mysql:
        condition: service_healthy
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8090/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  mysql:
    image: mysql:9.2
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE: petclinic
      MYSQL_USER: petclinic
      MYSQL_PASSWORD: petclinic
    ports:
      - "3306:3306"
    volumes:
      - mysql_data:/var/lib/mysql
      - "./conf.d:/etc/mysql/conf.d:ro"
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "petclinic", "-ppetclinic"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus-data:/prometheus
    command: 
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    networks:
      - app-network
    depends_on:
      - spring-petclinic
  grafana:
    image: grafana/grafana:latest 
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:  
      - grafana-storage:/var/lib/grafana
      - ./grafana/provisioning:/etc/grafana/provisioning
    networks:
      - app-network
    depends_on: 
      - prometheus
volumes:
  grafana-storage:
  prometheus-data:
  mysql_data:
networks:
  app-network:
    driver: bridge
```

---

## 6. Deployment on AWS EC2

### Prerequisites:
- Create AWS IAM user with programmatic access and attach necessary permissions.
- Create an EC2 Key Pair (`my-keypair.pem`) and store securely.
- Configure AWS CLI with your credentials.

### Deployment steps:
1. Run Terraform:
```bash
cd infra
terraform init
terraform apply
```
2. Retrieve public IP:
```bash
terraform output public_ip
```
3. SSH into the EC2 instance:
```bash
ssh -i ~/.ssh/my-keypair.pem ec2-user@<EC2_PUBLIC_IP>
```
4. Install Docker:
- **Amazon Linux 2:**
```bash
sudo yum update -y
sudo amazon-linux-extras install docker -y
sudo service docker start
sudo usermod -aG docker ec2-user
# Re-log or run newgrp docker
```
- **Ubuntu:**
```bash
sudo apt-get update
sudo apt-get install -y docker.io
sudo usermod -aG docker $USER
```
5. Pull and run your app:
```bash
docker pull rabiaadel/petclinic-app:latest
docker run -d --name petclinic -p 8092:8090 -e SERVER_PORT=8092 rabiaadel/petclinic-app:latest
```
6. Access at `http://<EC2_PUBLIC_IP>:8092`.

---

## 7. Cleanup

### Local Docker & Compose
```bash
docker-compose down -v
docker rm -f petclinic-app || true
docker rmi rabiaadel/petclinic-app:latest || true
```

### AWS Resources
```bash
cd infra
terraform destroy -auto-approve
```

### Additional
Remove Terraform state files:
```bash
rm -rf .terraform
rm terraform.tfstate*
```

---

## 8. Tips & Best Practices
- Never commit secrets or state files.
- Use least-privilege IAM policies.
- Use remote backend for Terraform in collaborative environments.
- Tag Docker images with version numbers.
- Regularly destroy unused resources to avoid charges.
- Monitor AWS billing.

---

## 9. Files Summary
- **Terraform**: `infra/provider.tf`, `infra/vpc.tf`, `infra/security.tf`, `infra/ec2.tf`, `infra/variables.tf`, `infra/outputs.tf`.
- **Jenkins**: `Jenkinsfile`.
- **Docker**: `Dockerfile`.
- **Docker Compose**: `docker-compose.yml`.
- **AWS**: Key Pair (`my-keypair.pem`), IAM user.

---

## 10. Additional Notes
- Adjust your `application.properties` if you want to change the default port.
- For production, consider setting up a load balancer, private subnets, and more restrictive security policies.

---

## Final Words
Follow this guide step-by-step to build, test, deploy, and manage your Spring Petclinic app using modern DevOps practices. Feel free to extend and customize as needed!

---

**Questions or help?** Reach out or modify these instructions as per your environment.
```

This README incorporates all your files, setup instructions, commands, and best practices, providing a complete guide for your project. Just replace placeholders where needed, and you're all set!