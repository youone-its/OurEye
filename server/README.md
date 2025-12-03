# OurEye Socket.IO Server

Real-time Socket.IO server untuk aplikasi OurEye - sistem tracking lokasi dan SOS alert untuk tunanetra.

## 🚀 Quick Start

### Local Development
```bash
npm install
npm start
```

Server akan running di `http://localhost:3000`

### Production Deployment
Lihat panduan lengkap di [DEPLOYMENT.md](./DEPLOYMENT.md)

## 📡 API Endpoints

### HTTP Endpoints

#### Health Check
```bash
GET http://YOUR_SERVER:3000/
```
Response:
```json
{
  "status": "online",
  "message": "OurEye Socket.IO Server",
  "activeConnections": 5,
  "activeUsers": 3,
  "topics": 2,
  "timestamp": "2025-12-04T05:45:00.000Z"
}
```

#### Statistics
```bash
GET http://YOUR_SERVER:3000/stats
```
Response:
```json
{
  "totalConnections": 5,
  "activeUsers": ["2", "3"],
  "topics": [
    { "topic": "user_2_1733301234567", "subscribers": 2 },
    { "topic": "user_1_1733301234568", "subscribers": 1 }
  ],
  "timestamp": "2025-12-04T05:45:00.000Z"
}
```

### Socket.IO Events

#### User (Publisher) Events

**location_update**
```javascript
socket.emit('location_update', {
  user_id: '2',
  lat: -7.2917403,
  lng: 112.7965594,
  heading: 45.0,
  timestamp: '2025-12-04T05:45:00.000Z'
});
```

**sos_alert**
```javascript
socket.emit('sos_alert', {
  type: 'SOS',
  userId: '2',
  topic: 'user_2_1733301234567',
  guardianIds: [3],
  location: {
    lat: -7.2917403,
    lng: 112.7965594,
    address: '-7.2917403, 112.7965594'
  },
  timestamp: 1733301234567,
  timestampISO: '2025-12-04T05:45:00.000Z'
});
```

#### Guardian (Subscriber) Events

**join_topic**
```javascript
socket.emit('join_topic', {
  topic: 'user_2_1733301234567'
});
```

**leave_topic**
```javascript
socket.emit('leave_topic', {
  topic: 'user_2_1733301234567'
});
```

**Listen for updates**
```javascript
socket.on('update_ui', (data) => {
  console.log('Location update:', data);
  // { user_id, lat, lng, heading, timestamp }
});

socket.on('sos_alert', (data) => {
  console.log('SOS Alert:', data);
  // { type, userId, topic, guardianIds, location, timestamp }
});
```

## 🏗️ Architecture

```
User (Tunanetra)              Socket.IO Server           Guardian (Wali)
      |                              |                           |
      |--- location_update --------->|                           |
      |    every 5 seconds           |                           |
      |                              |--- update_ui ------------>|
      |                              |    (broadcast to topic)   |
      |                              |                           |
      |--- sos_alert --------------->|                           |
      |                              |--- sos_alert ------------>|
      |                              |    (to guardianIds)       |
```

## 📁 File Structure

```
server/
├── server.js           # Main server file
├── package.json        # Dependencies
├── DEPLOYMENT.md       # Deployment guide
├── README.md          # This file
└── .gitignore         # Git ignore rules
```

## 🔧 Environment Variables

Create `.env` file:
```bash
PORT=3000
NODE_ENV=production
```

## 📦 Dependencies

- **express** - Web framework
- **socket.io** - Real-time bidirectional communication
- **cors** - CORS middleware

## 🧪 Testing

### Test dengan curl
```bash
# Health check
curl http://localhost:3000

# Stats
curl http://localhost:3000/stats
```

### Test Socket.IO connection
```javascript
// test-client.js
const io = require('socket.io-client');
const socket = io('http://localhost:3000');

socket.on('connect', () => {
  console.log('Connected!');
  
  // Join topic
  socket.emit('join_topic', { topic: 'user_2_test' });
  
  // Send location
  socket.emit('location_update', {
    user_id: '2',
    lat: -7.2917403,
    lng: 112.7965594,
    heading: 45.0,
    timestamp: new Date().toISOString()
  });
});

socket.on('update_ui', (data) => {
  console.log('Received location:', data);
});

socket.on('sos_alert', (data) => {
  console.log('Received SOS:', data);
});
```

Run:
```bash
node test-client.js
```

## 🚀 Deployment

Lihat panduan lengkap deployment ke Digital Ocean di [DEPLOYMENT.md](./DEPLOYMENT.md)

Quick commands:
```bash
# Install PM2
npm install -g pm2

# Start server
pm2 start server.js --name oureye-socket

# View logs
pm2 logs oureye-socket

# Monitor
pm2 monit

# Restart
pm2 restart oureye-socket
```

## 📊 Monitoring

### PM2 Monitoring
```bash
pm2 monit
pm2 logs oureye-socket
```

### Server Logs
Server akan log semua events:
- ✅ Client connected/disconnected
- 📍 Location updates
- 🚨 SOS alerts
- 👂 Topic join/leave
- ❌ Errors

## 🔒 Security

1. **Firewall:** Enable UFW dan allow port 3000
2. **CORS:** Production harus set specific origin
3. **SSL:** Pakai Nginx reverse proxy dengan Let's Encrypt
4. **Rate Limiting:** Implement untuk prevent abuse

## 🐛 Troubleshooting

### Port already in use
```bash
# Find process
sudo lsof -i :3000

# Kill process
sudo kill -9 PID
```

### Connection timeout
```bash
# Check firewall
sudo ufw status

# Check if server running
pm2 status

# Check logs
pm2 logs oureye-socket
```

### High memory usage
```bash
# Set memory limit
pm2 start server.js --max-memory-restart 500M
```

## 📝 License

MIT

## 👥 Contributors

- OurEye Team

## 📞 Support

- Server Status: http://YOUR_SERVER:3000
- GitHub Issues: https://github.com/youone-its/OurEye/issues
