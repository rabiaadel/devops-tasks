# 🐾 Spring PetClinic Deployment with Ansible & Docker

This project automates the deployment of the [Spring PetClinic](https://github.com/spring-projects/spring-petclinic) application using **Ansible** and **Docker**. It provisions a remote VM, installs required dependencies, builds the application from source, and runs it alongside a MySQL container—all without manual intervention.

---

## 🚀 Key Features

### 🔧 Environment Setup
- Installs **Docker** and **OpenJDK 21** on the target VM.
- Ensures Docker service is running and accessible to the user.

### 🧰 Source Code Deployment
- Copies the Spring PetClinic source code, Maven wrapper, and configuration files to the remote VM.
- Ensures correct file permissions and executable access for Maven.

### 🐳 Docker Image Creation
- Uses a custom Dockerfile (`Dockerfile.bepr`) to build the PetClinic application image.
- Builds the image directly on the remote VM using the copied source.

### 🗄️ MySQL Container Provisioning
- Deploys a MySQL container with custom credentials and database name.
- Exposes port `3306` for internal communication with the PetClinic app.

### 🌐 Spring PetClinic Container Deployment
- Runs the PetClinic application in a Docker container.
- Connects to the MySQL container using environment variables.
- Maps port `9000` to allow external access to the application.

### 👤 User Privilege Configuration
- Adds the Ansible user to the `docker` group for permissionless Docker usage.
- Enables passwordless `sudo` access for seamless automation.

---

## 📁 Project Structure

Ensure your local project directory follows this layout:

```
/home/projects/
├── spring-petclinic/
│   ├── src/
│   ├── pom.xml
│   ├── mvnw
│   └── .mvn/
└── Dockerfile.bepr
```

---

## 📦 How to Use

### 1️⃣ Prepare Your Inventory File

Save the following as `inventory.ini`:

```ini
[wsl]
172.21.113.169 ansible_user=rabia

[vm]
192.168.1.228 ansible_user=rabia

[all:vars]
ansible_ssh_private_key_file=~/.ssh/id_ed25519
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

### 2️⃣ Enable Passwordless Sudo on the VM

Run this on the VM to allow Ansible to execute privileged commands:

```bash
echo "rabia ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/rabia
# Check with : sudo -v
```

### 3️⃣ Run the Ansible Playbook

```bash
ansible-playbook -i inventory.ini deploy-petclinic.yml
```

### 4️⃣ Access the Application

Once deployed, open your browser and visit:

```
http://192.168.1.228:9000
```

---

## ⚙️ Configuration Variables

You can customize the deployment by modifying these variables in your playbook:

| Variable               | Description                                | Default Value                        |
|------------------------|--------------------------------------------|--------------------------------------|
| `local_app_dir`        | Local path to Spring PetClinic source      | `/home/projects/spring-petclinic`    |
| `local_dockerfile`     | Path to custom Dockerfile                  | `/home/projects/Dockerfile.bepr`     |
| `remote_app_dir`       | Remote directory for deployment            | `/opt/spring-petclinic`              |
| `mysql_root_password`  | Root password for MySQL                    | `rootpassword`                       |
| `mysql_user`           | MySQL user for the app                     | `petclinic`                          |
| `mysql_password`       | Password for MySQL user                    | `petclinic`                          |
| `mysql_database`       | Name of the MySQL database                 | `petclinic`                          |
| `app_port`             | External port to access the application    | `9000`                               |

---

## ✅ Deployment Confirmation

At the end of a successful run, you’ll see:

```
Deployment completed!
Application: http://192.168.1.228:9000
Docker running: spring-petclinic-app
```

---
