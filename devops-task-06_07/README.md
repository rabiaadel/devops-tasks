# 🚀 Docker Compose Setup with MySQL, App, and NGINX Load Balancer

This project demonstrates two Docker Compose setups:
1. **Simple setup** → One application container + one MySQL database.
2. **Scaling setup** → Multiple application replicas + NGINX load balancer + MySQL database.

The stack includes:
- **App Service** → Your application (built from `Dockerfile.bepr`).
- **MySQL Database** → Persistent relational database.
- **NGINX Load Balancer** → Routes traffic to multiple app replicas (only in scaling setup).
- **Healthchecks** → Ensure containers are alive and responsive.
- **Networks** → To isolate traffic between frontend (user ↔ app) and backend (app ↔ db).
- **Volumes** → To persist MySQL data.

---

## 📂 Project Structure

```
my_project/
│── .env                       # Environment variables
│── docker-compose.yml          # Simple setup (1 app + 1 db)
│── docker-compose.scale.yml    # Scaling setup (multiple app replicas + load balancer + db)
│── nginx.conf                  # Load balancer configuration
│── Dockerfile.bepr         # Custom Dockerfile for building the app
│── src/                    # Your application source code
```

---

## ⚙️ Configuration Files

### 1️⃣ `.env`
This file centralizes sensitive and configurable values so they don’t have to be hard-coded.

```env
MYSQL_ROOT_PASSWORD=supersecret   # Root password for MySQL
MYSQL_DATABASE=myappdb            # Database name
MYSQL_USER=myuser                 # Application DB user
MYSQL_PASSWORD=mypassword         # Password for application DB user
APP_PORT=5000                     # External port to expose the app or load balancer
```

**Why:**  
- Keeps secrets out of `docker-compose.yml`.  
- Makes switching environments (dev, prod, test) easy.  
- Can be replaced with `.env.prod`, `.env.dev` for different setups.  

---

### 2️⃣ `nginx.conf`
Configures NGINX as a load balancer for multiple application containers.

```nginx
events {}

http {
    upstream app_servers {
        server app:9000;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://app_servers;
        }
    }
}
```

**Explanation:**
- `events {}` → Required NGINX block, even if empty.  
- `upstream app_servers` → Defines a group of backend servers. Here it points to the `app` service on port `5000`.  
- `server { listen 80; }` → NGINX listens on port 80 (container-internal).  
- `location / { proxy_pass http://app_servers; }` → Routes incoming requests to the upstream group.  

**Enhancements:**
- Enable health checks, caching . 

---

### 3️⃣ `docker-compose.yml` (Simple Setup)
Runs **one app** and **one db**.

```yaml
version: "3.8"

services:
  app:
    build: 
      context: .
      dockerfile: Dockerfile.bepr
    container_name: my_app
    ports:
      - "${APP_PORT}:9000"
    environment:
      - DATABASE_HOST=db
      - DATABASE_USER=${MYSQL_USER}
      - DATABASE_PASSWORD=${MYSQL_PASSWORD}
      - DATABASE_NAME=${MYSQL_DATABASE}
    depends_on:
      - db
    networks:
      - frontend   # app <-> user/browser
      - backend    # app <-> db
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  db:
    image: mysql:8.0
    container_name: my_db
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - backend
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  db_data:

networks:
  frontend:
  backend:
```

**Explanation:**
- `version: "3.8"` → Docker Compose file format version (3.8 is widely supported).  
- `build.context` → Folder with source and Dockerfile.  
- `build.dockerfile` → Custom Dockerfile name (`Dockerfile.bepr`).  
- `ports` → Maps external port (`APP_PORT=5000`) to internal app port `5000`.  
- `environment` → Injects DB credentials and connection info from `.env`.  
- `depends_on` → Ensures DB starts before the app.  
- `healthcheck` → Checks if the service is alive (curl for app, mysqladmin for db).  
- `volumes` → `db_data` persists database files across container restarts.  
- `networks` → Isolates traffic (frontend for users, backend for db).  

---

### 4️⃣ `docker-compose.scale.yml` (Scaling Setup)
Adds **NGINX load balancer** and allows **multiple app replicas**.

```yaml
version: "3.8"

services:
  app:
    build: 
      context: .
      dockerfile: Dockerfile.bepr
    environment:
      - DATABASE_HOST=db
      - DATABASE_USER=${MYSQL_USER}
      - DATABASE_PASSWORD=${MYSQL_PASSWORD}
      - DATABASE_NAME=${MYSQL_DATABASE}
    networks:
      - frontend
      - backend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  load_balancer:
    image: nginx:latest
    ports:
      - "${APP_PORT}:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app
    networks:
      - frontend
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost/"]
      interval: 30s
      timeout: 10s
      retries: 3

  db:
    image: mysql:8.0
    restart: always
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
    volumes:
      - db_data:/var/lib/mysql
    networks:
      - backend
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 30s
      timeout: 10s
      retries: 5

volumes:
  db_data:

networks:
  frontend:
  backend:
```

**Explanation:**
- `app` → Same as before, but now it doesn’t expose ports directly. Only the load balancer can reach it.  
- `load_balancer` → Runs NGINX, mounts custom `nginx.conf`, exposes `APP_PORT=5000` to outside world.  
- `depends_on` → Starts load balancer after `app`.  
- `healthcheck` → Ensures NGINX is responding.  
- `networks` → Load balancer only connects to `frontend`. DB only connects to `backend`. App connects to both.  

---

## ▶️ Usage

### 1. Start the **simple setup**
```bash
docker-compose up --build -d
```
- Access app at: [http://localhost:5000](http://localhost:5000)

### 2. Stop it
```bash
docker-compose down
```

### 3. Start the **scaling setup**
```bash
docker-compose -f docker-compose.scale.yml up --build --scale app=3 -d
```
- Access app through load balancer: [http://localhost:5000](http://localhost:5000)  
- Requests are distributed across 3 app replicas.

### 4. Stop it
```bash
docker-compose -f docker-compose.scale.yml down
```

---

## 🔮 Future Enhancements
- **Secrets** → Use `docker secrets` instead of `.env` for sensitive data.  
- **Production-ready NGINX** → Traefic
- **Scaling beyond Compose** → Use Docker Swarm or Kubernetes for production.  
2025-08-23T15:32:40.025Z  INFO 1 --- [nio-9000-exec-2] o.apache.coyote.http11.Http11Processor   : The host [app_servers] is not valid
[emerg] invalid number of arguments in "upstream" directive in /etc/nginx/nginx.conf:4
  

---
