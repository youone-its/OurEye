// Test client untuk testing Socket.IO server
const io = require('socket.io-client');

// Ganti dengan server URL
const SERVER_URL = 'http://localhost:3000'; // atau 'http://YOUR_DROPLET_IP:3000'

console.log(`🔌 Connecting to ${SERVER_URL}...`);

const socket = io(SERVER_URL, {
  transports: ['websocket', 'polling']
});

// Connection events
socket.on('connect', () => {
  console.log('✅ Connected to server!');
  console.log(`Socket ID: ${socket.id}\n`);
  
  // Test 1: Join topic sebagai guardian
  console.log('📌 Test 1: Join topic');
  socket.emit('join_topic', { topic: 'user_2_test' });
});

socket.on('topic_joined', (data) => {
  console.log('✅ Topic joined:', data);
  
  // Test 2: Send location update sebagai user
  console.log('\n📌 Test 2: Send location update');
  socket.emit('location_update', {
    user_id: '2',
    lat: -7.2917403,
    lng: 112.7965594,
    heading: 45.0,
    timestamp: new Date().toISOString()
  });
  
  // Test 3: Send SOS alert setelah 2 detik
  setTimeout(() => {
    console.log('\n📌 Test 3: Send SOS alert');
    socket.emit('sos_alert', {
      type: 'SOS',
      userId: '2',
      topic: 'user_2_test',
      guardianIds: [3],
      location: {
        lat: -7.2917403,
        lng: 112.7965594,
        address: 'Test Location'
      },
      timestamp: Date.now(),
      timestampISO: new Date().toISOString()
    });
  }, 2000);
  
  // Test 4: Leave topic setelah 5 detik
  setTimeout(() => {
    console.log('\n📌 Test 4: Leave topic');
    socket.emit('leave_topic', { topic: 'user_2_test' });
    
    // Disconnect setelah 1 detik
    setTimeout(() => {
      console.log('\n👋 Disconnecting...');
      socket.disconnect();
    }, 1000);
  }, 5000);
});

// Listen for location updates
socket.on('update_ui', (data) => {
  console.log('📍 Received location update:', {
    user_id: data.user_id,
    lat: data.lat,
    lng: data.lng,
    heading: data.heading
  });
});

// Listen for SOS alerts
socket.on('sos_alert', (data) => {
  console.log('🚨 Received SOS alert:', {
    type: data.type,
    userId: data.userId,
    location: data.location
  });
});

socket.on('topic_left', (data) => {
  console.log('✅ Topic left:', data);
});

socket.on('disconnect', (reason) => {
  console.log(`\n❌ Disconnected: ${reason}`);
  process.exit(0);
});

socket.on('connect_error', (error) => {
  console.error('❌ Connection error:', error.message);
  process.exit(1);
});

socket.on('error', (error) => {
  console.error('🔥 Socket error:', error);
});

// Handle Ctrl+C
process.on('SIGINT', () => {
  console.log('\n⚠️ Interrupted, disconnecting...');
  socket.disconnect();
  process.exit(0);
});
