const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const cors = require('cors');

// Initialize Express App
const app = express();
const server = http.createServer(app);

// Socket.IO with CORS
const io = socketIO(server, {
  cors: {
    origin: '*', // Allow all origins (production: ganti dengan domain spesifik)
    methods: ['GET', 'POST']
  },
  transports: ['websocket', 'polling']
});

// Middleware
app.use(cors());
app.use(express.json());

// In-memory storage untuk active connections
const activeUsers = new Map(); // Map<userId, socketId>
const topicSubscribers = new Map(); // Map<topic, Set<socketId>>

// Health check endpoint
app.get('/', (req, res) => {
  res.json({
    status: 'online',
    message: 'OurEye Socket.IO Server',
    activeConnections: io.engine.clientsCount,
    activeUsers: activeUsers.size,
    topics: topicSubscribers.size,
    timestamp: new Date().toISOString()
  });
});

// Stats endpoint
app.get('/stats', (req, res) => {
  const stats = {
    totalConnections: io.engine.clientsCount,
    activeUsers: Array.from(activeUsers.keys()),
    topics: Array.from(topicSubscribers.keys()).map(topic => ({
      topic,
      subscribers: topicSubscribers.get(topic).size
    })),
    timestamp: new Date().toISOString()
  };
  res.json(stats);
});

// Socket.IO Connection Handler
io.on('connection', (socket) => {
  console.log(`✅ Client connected: ${socket.id}`);
  console.log(`📊 Total connections: ${io.engine.clientsCount}`);

  // ==================== USER EVENTS (Publisher) ====================

  /**
   * Location Update dari User
   * Payload: { user_id, lat, lng, heading, timestamp, topic }
   */
  socket.on('location_update', (data) => {
    console.log(`📍 Location update from user ${data.user_id}:`, {
      lat: data.lat,
      lng: data.lng,
      heading: data.heading,
      topic: data.topic
    });

    // Store user's socket ID
    activeUsers.set(data.user_id, socket.id);

    // Gunakan topic dari payload (dari database), jangan generate
    const userTopic = data.topic || `user_${data.user_id}`;
    
    // AUTO-JOIN: User otomatis join ke topic sendiri untuk menerima broadcast
    if (!topicSubscribers.has(userTopic) || !topicSubscribers.get(userTopic).has(socket.id)) {
      socket.join(userTopic);
      
      if (!topicSubscribers.has(userTopic)) {
        topicSubscribers.set(userTopic, new Set());
      }
      topicSubscribers.get(userTopic).add(socket.id);
      
      console.log(`🔑 User ${data.user_id} auto-joined topic: ${userTopic}`);
    }
    
    // Forward to topic subscribers dengan event 'update_ui'
    socket.to(userTopic).emit('update_ui', {
      user_id: data.user_id,
      lat: data.lat,
      lng: data.lng,
      heading: data.heading,
      timestamp: data.timestamp || new Date().toISOString()
    });

    console.log(`✉️ Broadcasted to topic: ${userTopic} (${topicSubscribers.get(userTopic).size} subscribers)`);
  });

  /**
   * SOS Alert dari User
   * Payload: { type, userId, guardianId, topic, location, timestamp }
   * Topic format: wali_{guardianId}
   */
  socket.on('sos_alert', (data) => {
    console.log(`🚨 SOS Alert from user ${data.userId} to guardian ${data.guardianId}:`, data);

    // Broadcast ke topic wali (semua yang subscribe ke wali_X akan terima)
    if (data.topic) {
      socket.to(data.topic).emit('sos_alert', data);
      console.log(`📢 SOS broadcasted to topic: ${data.topic}`);
      
      // Hitung berapa subscriber yang terima
      const subscriberCount = topicSubscribers.has(data.topic) ? topicSubscribers.get(data.topic).size : 0;
      console.log(`👥 ${subscriberCount} subscribers in ${data.topic}`);
    }

    // Save to database (TODO: integrate PostgreSQL)
    // await saveSOSAlertToDatabase(data);
  });

  // ==================== GUARDIAN EVENTS (Subscriber) ====================

  /**
   * Guardian Join Topic
   * Payload: { topic } atau { user_id }
   */
  socket.on('join_topic', (data) => {
    let topic = data.topic;
    
    // Support legacy format { user_id: 'xxx' }
    if (!topic && data.user_id) {
      topic = `user_${data.user_id}`;
    }

    if (topic) {
      socket.join(topic);
      
      // Track subscribers
      if (!topicSubscribers.has(topic)) {
        topicSubscribers.set(topic, new Set());
      }
      topicSubscribers.get(topic).add(socket.id);

      console.log(`👂 Socket ${socket.id} joined topic: ${topic}`);
      console.log(`📊 Topic "${topic}" now has ${topicSubscribers.get(topic).size} subscribers`);

      // Confirm to client
      socket.emit('topic_joined', { 
        topic, 
        success: true,
        message: `Successfully subscribed to ${topic}`
      });
    } else {
      console.log(`⚠️ Invalid join_topic request from ${socket.id}:`, data);
      socket.emit('error', { message: 'Invalid topic format' });
    }
  });

  /**
   * Guardian Leave Topic
   * Payload: { topic } atau { user_id }
   */
  socket.on('leave_topic', (data) => {
    let topic = data.topic;
    
    // Support legacy format
    if (!topic && data.user_id) {
      topic = `user_${data.user_id}`;
    }

    if (topic) {
      socket.leave(topic);

      // Remove from subscribers
      if (topicSubscribers.has(topic)) {
        topicSubscribers.get(topic).delete(socket.id);
        if (topicSubscribers.get(topic).size === 0) {
          topicSubscribers.delete(topic);
        }
      }

      console.log(`👋 Socket ${socket.id} left topic: ${topic}`);
      
      socket.emit('topic_left', { 
        topic, 
        success: true,
        message: `Successfully unsubscribed from ${topic}`
      });
    }
  });

  // ==================== DISCONNECT ====================

  socket.on('disconnect', (reason) => {
    console.log(`❌ Client disconnected: ${socket.id} (Reason: ${reason})`);
    console.log(`📊 Total connections: ${io.engine.clientsCount}`);

    // Remove from active users
    for (const [userId, socketId] of activeUsers.entries()) {
      if (socketId === socket.id) {
        activeUsers.delete(userId);
        console.log(`🗑️ Removed user ${userId} from active users`);
        break;
      }
    }

    // Remove from topic subscribers
    for (const [topic, subscribers] of topicSubscribers.entries()) {
      if (subscribers.has(socket.id)) {
        subscribers.delete(socket.id);
        console.log(`🗑️ Removed ${socket.id} from topic ${topic}`);
        if (subscribers.size === 0) {
          topicSubscribers.delete(topic);
        }
      }
    }
  });

  // Error handler
  socket.on('error', (error) => {
    console.error(`🔥 Socket error for ${socket.id}:`, error);
  });
});

// Start Server
const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log('\n🚀 OurEye Socket.IO Server Started!');
  console.log(`📡 Listening on http://0.0.0.0:${PORT}`);
  console.log(`📊 Health check: http://YOUR_DROPLET_IP:${PORT}`);
  console.log(`📈 Stats endpoint: http://YOUR_DROPLET_IP:${PORT}/stats`);
  console.log('✅ Ready to accept connections\n');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('⚠️ SIGTERM signal received: closing HTTP server');
  server.close(() => {
    console.log('✅ HTTP server closed');
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('\n⚠️ SIGINT signal received: closing HTTP server');
  server.close(() => {
    console.log('✅ HTTP server closed');
    process.exit(0);
  });
});
