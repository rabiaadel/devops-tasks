# 🛠️ Ansible Setup Guide: From Zero to Ping

This guide documents all the steps to set up Ansible for managing your WSL and VM before creating playbooks.

---

## 📋 Prerequisites

- Windows machine with WSL2 (Ubuntu)
- VirtualBox with Ubuntu 22.04 VM
- Basic Linux command line knowledge

---

## 🔌 Step 1: Network Configuration

### 🔍 Find IP Addresses

**On WSL:**
```bash
ip addr show or ifconfig
# Look for 'inet' address ( secret)
```

**On VM:**
```bash
ip addr show or ifconfig
# Look for 'inet' address ( secret)
```

### 🔧 Set VM Network Mode

1. Shut down VM in VirtualBox  
2. Go to **Settings → Network**  
3. Change **"Attached to:"** from `NAT` to `Bridged Adapter`  
4. Start VM and check new IP address

---

## 🔐 Step 2: SSH Key Setup

### 🔑 Generate SSH Key (on WSL)
```bash
ssh-keygen
# (accept defaults, no passphrase)
```

### 📤 Copy Public Key to Targets
```bash
# Copy to WSL itself
ssh-copy-id -i ~/.ssh/id_ed25519.pub rabia@any

# Copy to VM
ssh-copy-id -i ~/.ssh/id_ed25519.pub rabia@any
```

### ✅ Test SSH Connection
```bash
ssh rabia@any
# Should connect without password prompt
```

---

## 📁 Step 3: Ansible Inventory Setup

Create a `hosts.ini` file:
```ini
[wsl]
secret

[vm]
secret

[all:vars]
ansible_ssh_private_key_file=~/.ssh/id_ed25519
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
```

---

## 🔓 Step 4: Passwordless Sudo on VM

On your VM terminal:
```bash
echo "rabia ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/rabia
sudo -v  # Test it works
```

---

## 📡 Step 5: Test Ansible Connectivity

### 🟢 Test Ping
```bash
ansible all -i hosts.ini -m ping
```

**Expected Output:**
```json
any | SUCCESS => {
    "changed": false,
    "ping": "pong"
}
any | SUCCESS => {
    "changed": false, 
    "ping": "pong"
}
```

### ⚙️ Test Ad-Hoc Commands
```bash
# Run command on all hosts
ansible all -i hosts.ini -m command -a "uname -a"

# Check disk space on VM only
ansible vm -i hosts.ini -m command -a "df -h"

# Install package on VM
ansible vm -i hosts.ini -m apt -a "name=nginx state=present" --become
```

---

## 📦 Step 6: File Management with Ansible

### 📤 Copy Files from WSL to VM
```bash
# Copy single file
ansible vm -i hosts.ini -m copy -a "src=/path/local/file.txt dest=/remote/path/"

# Copy entire directory
ansible vm -i hosts.ini -m copy -a "src=/local/dir/ dest=/remote/dir/"
```

### 📥 Fetch Files from VM to WSL
```bash
ansible vm -i hosts.ini -m fetch -a "src=/remote/file.txt dest=/local/path/ flat=yes"
```

---

## 🔐 Step 7: Firewall Rules (UFW)

```bash
# Allow SSH
ansible all -i hosts.ini -m ufw -a "rule=allow name=OpenSSH" --become

# Allow HTTP traffic
ansible vm -i hosts.ini -m ufw -a "rule=allow port=80 proto=tcp" --become

# Check firewall status
ansible all -i hosts.ini -m command -a "ufw status" --become
```

---

## 🧯 Troubleshooting

### ⚠️ Common Issues

- **Connection timeout**: Wrong IP or VM not running  
- **Permission denied**: SSH keys not copied properly  
- **Sudo password required**: Passwordless sudo not configured  
- **Package not found**: Run `sudo apt update` on VM first

### 🧪 Diagnostic Commands

```bash
# Test SSH connection
ssh -v rabia@any

# Check Ansible version
ansible --version

# Verify inventory file
ansible all -i hosts.ini --list-hosts
```

---

## 🚀 Next Steps

Once ping and basic commands work, you're ready to explore:

- **Playbooks**: Automated multi-task deployments  
- **Roles**: Reusable configuration components  
- **Variables**: Dynamic configuration management  
- **Templates**: Configuration file management

---

✅ Your Ansible setup is now complete! You can manage both WSL and VM seamlessly.
