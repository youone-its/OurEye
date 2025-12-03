# OurEye Socket.IO Server - Digital Ocean Deployment Guide

## 📋 Prerequisites
- Digital Ocean Droplet (Ubuntu 22.04 LTS)
- Domain atau IP Public Droplet
- SSH access ke droplet

---

## 🚀 Step-by-Step Deployment

### **1. Setup Digital Ocean Droplet**

#### A. Create Droplet
1. Login ke [Digital Ocean](https://cloud.digitalocean.com/)
2. Click **Create** → **Droplets**
3. Pilih konfigurasi:
   - **Image:** Ubuntu 22.04 LTS
   - **Plan:** Basic ($6/month - 1GB RAM, 1 vCPU, 25GB SSD)
   - **Datacenter:** Singapore (terdekat dengan Indonesia)
   - **Authentication:** SSH Key atau Password
4. Click **Create Droplet**

#### B. Connect via SSH
```bash
ssh root@YOUR_DROPLET_IP
# Ganti YOUR_DROPLET_IP dengan IP droplet (contoh: 178.128.122.114)
```

---

### **2. Install Node.js & npm**

```bash
# Update sistem
sudo apt update && sudo apt upgrade -y

# Install Node.js 20.x (LTS)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

# Verify installation
node -v   # Should show v20.x.x
npm -v    # Should show 10.x.x
```

---

### **3. Setup Firewall**

```bash
# Enable UFW firewall
sudo ufw enable

# Allow SSH (penting!)
sudo ufw allow 22/tcp

# Allow HTTP & HTTPS
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Allow port 3000 (Socket.IO server)
sudo ufw allow 3000/tcp

# Check status
sudo ufw status
```

---

### **4. Upload Server Files**

#### Option A: Git Clone (Recommended)
```bash
# Install git
sudo apt install -y git

# Clone repository
cd /opt
git clone https://github.com/youone-its/OurEye.git
cd OurEye/server

# Install dependencies
npm install
```

#### Option B: Manual Upload via SCP
```powershell
# Di komputer lokal (PowerShell)
cd C:\Users\rizki\code\OurEye\server

# Upload files
scp -r * root@YOUR_DROPLET_IP:/opt/oureye-server/
```

---

### **5. Install PM2 (Process Manager)**

PM2 akan menjaga server tetap running bahkan setelah SSH disconnect.

```bash
# Install PM2 globally
sudo npm install -g pm2

# Start server dengan PM2
cd /opt/OurEye/server  # atau /opt/oureye-server
pm2 start server.js --name oureye-socket

# Setup auto-restart on reboot
pm2 startup
pm2 save

# Check status
pm2 status
pm2 logs oureye-socket
```

---

### **6. Configure Nginx (Optional - Recommended for Production)**

Nginx akan handle HTTPS dan proxy ke Node.js.

```bash
# Install Nginx
sudo apt install -y nginx

# Create Nginx config
sudo nano /etc/nginx/sites-available/oureye-socket
```

Paste konfigurasi ini:

```nginx
server {
    listen 80;
    server_name YOUR_DOMAIN_OR_IP;  # Contoh: socket.oureye.com atau 178.128.122.114

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        
        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        
        # Headers
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable site dan restart Nginx:

```bash
# Enable site
sudo ln -s /etc/nginx/sites-available/oureye-socket /etc/nginx/sites-enabled/

# Test config
sudo nginx -t

# Restart Nginx
sudo systemctl restart nginx
```

---

### **7. Setup SSL dengan Let's Encrypt (Optional - untuk HTTPS)**

```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d YOUR_DOMAIN

# Auto-renewal sudah otomatis ter-setup
# Test renewal:
sudo certbot renew --dry-run
```

---

### **8. Test Server**

#### A. Health Check
```bash
# Via curl di droplet
curl http://localhost:3000

# Via browser
http://YOUR_DROPLET_IP:3000
```

Expected response:
```json
{
  "status": "online",
  "message": "OurEye Socket.IO Server",
  "activeConnections": 0,
  "activeUsers": 0,
  "topics": 0,
  "timestamp": "2025-12-04T05:45:00.000Z"
}
```

#### B. Stats Endpoint
```bash
curl http://YOUR_DROPLET_IP:3000/stats
```

---

### **9. Update Flutter App dengan IP Droplet**

Edit file `lib/services/socket_service.dart`:

```dart
// Ganti dengan IP droplet atau domain
static const String _serverUrl = 'http://YOUR_DROPLET_IP:3000';
// atau jika pakai Nginx + SSL:
// static const String _serverUrl = 'https://socket.oureye.com';
```

Rebuild app:
```bash
flutter build apk --release
flutter install -d YOUR_DEVICE_ID
```

---

## 🔧 PM2 Commands Cheat Sheet

```bash
# Start server
pm2 start server.js --name oureye-socket

# Stop server
pm2 stop oureye-socket

# Restart server
pm2 restart oureye-socket

# View logs
pm2 logs oureye-socket

# Monitor real-time
pm2 monit

# List all processes
pm2 list

# Delete process
pm2 delete oureye-socket

# View detailed info
pm2 show oureye-socket
```

---

## 📊 Monitoring & Debugging

### Check Server Logs
```bash
# PM2 logs
pm2 logs oureye-socket --lines 100

# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# System logs
sudo journalctl -u nginx -f
```

### Check Server Status
```bash
# PM2 status
pm2 status

# Check port 3000
sudo netstat -tulpn | grep 3000

# Check Nginx
sudo systemctl status nginx
```

### Test Socket.IO Connection
```bash
# Install socket.io-client tester
npm install -g socket.io-client

# Test connection
node
```
```javascript
const io = require('socket.io-client');
const socket = io('http://YOUR_DROPLET_IP:3000');

socket.on('connect', () => {
  console.log('✅ Connected!');
  
  // Test location update
  socket.emit('location_update', {
    user_id: '2',
    lat: -7.2917403,
    lng: 112.7965594,
    heading: 45.0,
    timestamp: new Date().toISOString()
  });
});

socket.on('disconnect', () => {
  console.log('❌ Disconnected');
});
```

---

## 🔐 Security Best Practices

### 1. Change Root Password
```bash
passwd
```

### 2. Create Non-Root User
```bash
adduser nodeuser
usermod -aG sudo nodeuser
```

### 3. Disable Root Login
```bash
sudo nano /etc/ssh/sshd_config
# Set: PermitRootLogin no
sudo systemctl restart sshd
```

### 4. Configure CORS (Production)
Edit `server.js`:
```javascript
const io = socketIO(server, {
  cors: {
    origin: 'https://yourdomain.com', // Ganti dengan domain spesifik
    methods: ['GET', 'POST'],
    credentials: true
  }
});
```

### 5. Rate Limiting (Optional)
```bash
npm install express-rate-limit
```

Add to `server.js`:
```javascript
const rateLimit = require('express-rate-limit');

const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});

app.use(limiter);
```

---

## 🚨 Troubleshooting

### Server tidak start
```bash
# Check PM2 logs
pm2 logs oureye-socket

# Check port already in use
sudo lsof -i :3000
# Kill process if needed:
sudo kill -9 PID
```

### Connection timeout dari Flutter
```bash
# Verify firewall
sudo ufw status

# Test dari luar
telnet YOUR_DROPLET_IP 3000

# Check Nginx proxy
sudo nginx -t
sudo systemctl status nginx
```

### High Memory Usage
```bash
# Check memory
free -h

# Restart PM2
pm2 restart oureye-socket

# Set memory limit
pm2 start server.js --max-memory-restart 500M
```

---

## 📈 Production Checklist

- [ ] Server running dengan PM2
- [ ] Firewall configured (UFW)
- [ ] Nginx reverse proxy setup
- [ ] SSL certificate installed (Let's Encrypt)
- [ ] PM2 startup script enabled
- [ ] CORS restricted to domain
- [ ] Rate limiting enabled
- [ ] Monitoring setup (PM2 monitoring)
- [ ] Backup strategy
- [ ] Domain DNS configured (optional)

---

## 🎯 Quick Deploy Script

Save as `deploy.sh`:

```bash
#!/bin/bash

# Quick deploy script
echo "🚀 Deploying OurEye Socket Server..."

# Update code
cd /opt/OurEye/server
git pull origin main

# Install dependencies
npm install --production

# Restart PM2
pm2 restart oureye-socket

# Show status
pm2 status

echo "✅ Deployment complete!"
```

Make executable:
```bash
chmod +x deploy.sh
./deploy.sh
```

---

## 📞 Support

- **Server IP:** YOUR_DROPLET_IP
- **Port:** 3000
- **Health Check:** http://YOUR_DROPLET_IP:3000
- **Stats:** http://YOUR_DROPLET_IP:3000/stats

---

## 🔄 Auto-Deployment dengan GitHub Actions (Advanced)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Digital Ocean

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Deploy to Droplet
        uses: appleboy/ssh-action@master
        with:
          host: ${{ secrets.DROPLET_IP }}
          username: root
          key: ${{ secrets.SSH_KEY }}
          script: |
            cd /opt/OurEye/server
            git pull origin main
            npm install --production
            pm2 restart oureye-socket
```

---

**Selamat! Server Socket.IO sudah ready di Digital Ocean! 🎉**
