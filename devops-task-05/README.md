# 🐳 Spring PetClinic - Multi Docker Setup

This project demonstrates a Dockerized setup of the **Spring PetClinic** application using **three different Docker strategies**:
- A **Base** image using `openjdk:17-alpine`
- A **Multi-stage** build for production optimization
- A **Bloated (Worse)** image showcasing what not to do

It also includes:
- Docker networks (`shared_base_worse`, `isolated_multi`)
- Volumes (`shared_data`, `isolated_data`)
- Separate MySQL databases per environment
- Runtime containers mapped to appropriate DBs and ports

---

## 📁 Project Structure

```bash
.
├── Dockerfile.base      # Optimized base image
├── Dockerfile.multi     # Multi-stage build (production-ready)
├── Dockerfile.worse     # Intentionally bloated build
├── .dockerignore        # Docker ignore rules
```

---

## 🐳 Dockerfiles Overview

### 1️⃣ Dockerfile.base
```dockerfile
FROM openjdk:17-alpine
WORKDIR /app
ARG JAR_FILE=target/spring-petclinic-3.5.0-SNAPSHOT.jar
COPY ${JAR_FILE} app.jar
ENV PORT=9090
EXPOSE 9090
ENTRYPOINT ["java", "-jar" , "app.jar"]
```

### 2️⃣ Dockerfile.multi
```dockerfile
# Builder Stage
FROM bellsoft/liberica-runtime-container:jdk-21-stream-musl as build
WORKDIR /app
COPY . /app
RUN ./mvnw clean package -Dmaven.test.skip=true

# Runtime Stage
FROM bellsoft/liberica-runtime-container:jre-21-slim-musl
WORKDIR /app
COPY --from=build /app/target/spring-petclinic-3.5.0-SNAPSHOT.jar /app/petclinic.jar
ENTRYPOINT ["java", "-jar", "/app/petclinic.jar"]
LABEL maintainer="Rabia" version="1.0" description="Spring Petclinic Application"
```

### 3️⃣ Dockerfile.worse
```dockerfile
FROM openjdk:17
WORKDIR /app
ARG VERSION
ARG JAR_FILE=target/spring-petclinic-3.5.0-SNAPSHOT.jar
ADD . .
COPY $JAR_FILE app.jar
ENV PORT=8081
EXPOSE 8081
ENV VERSION="app.1.0.5"
RUN echo "${VERSION}"
RUN echo " i got tired of tis file"
RUN echo "again"
ENTRYPOINT ["java", "-jar" , "app.jar"]
```

---

## 🚫 .dockerignore

```bash
.git/
.idea/
*.log
*.iml
Dockerfile
README.md
node_modules/
```

---

## 🐋 Built Docker Images

| Image               | Tag    | Size  |
|--------------------|--------|-------|
| `petclinic_multi`  | latest | 309MB |
| `petclinic_base`   | latest | 647MB |
| `petclinic_worse`  | latest | 995MB |

Check with:
```bash
docker images | grep petclinic
```

---

## 🚀 Running Containers

### Base Container
```bash
docker run -d --name petclinic_base \
  -p 9090:9090 \
  petclinic_base
```

### Multi-stage Container
```bash
docker run -d --name petclinic_multi \
  -p 9091:9000 \
  petclinic_multi
```

### Worse Container
```bash
docker run -d --name petclinic_worse \
  -p 8081:9090 \
  petclinic_worse
```

---

## 🔗 Networking, Volumes, and Databases

### Create Networks & Volumes

```bash
docker network create shared_base_worse
docker network create isolated_multi

docker volume create shared_data
docker volume create isolated_data
```

---

### Run MySQL Databases

#### Shared Network DBs
```bash
# Base DB
docker run -d --network shared_base_worse --name petclinic_base_db \
  -e MYSQL_USER=petclinic1 \
  -e MYSQL_PASSWORD=petclinic1 \
  -e MYSQL_ROOT_PASSWORD=root1 \
  -e MYSQL_DATABASE=petclinic1 \
  mysql:latest

# Worse DB
docker run -d --network shared_base_worse --name petclinic_worse_db \
  -e MYSQL_USER=petclinic2 \
  -e MYSQL_PASSWORD=petclinic2 \
  -e MYSQL_ROOT_PASSWORD=root2 \
  -e MYSQL_DATABASE=petclinic2 \
  mysql:latest
```

#### Isolated Network DB
```bash
docker run -d --network isolated_multi --name petclinic_multi_db \
  -e MYSQL_USER=petclinic3 \
  -e MYSQL_PASSWORD=petclinic3 \
  -e MYSQL_ROOT_PASSWORD=root3 \
  -e MYSQL_DATABASE=petclinic3 \
  mysql:latest
```

---

## 🧩 Run Application Containers with DB Integration

### Base Container (Shared Network + Shared Volume)
```bash
docker run -d --name petclinic_base1 \
  --network shared_base_worse \
  -v shared_data:/app/shared \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://petclinic_base_db:3306/petclinic1 \
  -e SPRING_DATASOURCE_USERNAME=petclinic1 \
  -e SPRING_DATASOURCE_PASSWORD=petclinic1 \
  -p 8082:9000 \
  petclinic_base
```

### Worse Container (Shared Network + Shared Volume)
```bash
docker run -d --name petclinic_worse1 \
  --network shared_base_worse \
  -v shared_data:/app/shared \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://petclinic_worse_db:3306/petclinic2 \
  -e SPRING_DATASOURCE_USERNAME=petclinic2 \
  -e SPRING_DATASOURCE_PASSWORD=petclinic2 \
  -p 8083:9000 \
  petclinic_worse
```

### Multi Container (Isolated Network + Own Volume)
```bash
docker run -d --name petclinic_multi1 \
  --network isolated_multi \
  -v isolated_data:/var/lib/mysql \
  -e SPRING_DATASOURCE_URL=jdbc:mysql://petclinic_multi_db:3306/petclinic3 \
  -e SPRING_DATASOURCE_USERNAME=petclinic3 \
  -e SPRING_DATASOURCE_PASSWORD=petclinic3 \
  -p 8084:9000 \
  petclinic_multi
```

---

## ✅ Verify MySQL Connections

Run the following for each DB:

```bash
docker exec <db_container_name> mysqladmin ping -u <user> -p<password>
```

Example:
```bash
docker exec petclinic_base_db mysqladmin ping -u petclinic1 -ppetclinic1
```

---

## 📌 Summary

- You built **3 Dockerized variants** of the Spring PetClinic app.
- Connected them to **MySQL DBs** with appropriate isolation.
- Used **Docker networks and volumes** for realistic dev/prod simulation.
- Optimized image sizes with a multi-stage build.

---

> 💡 Pro Tip: Always prefer multi-stage builds for production to minimize image size and attack surface.
