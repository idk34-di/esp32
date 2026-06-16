const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');
const crypto = require('crypto');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

app.use(cors());
app.use(express.json());
app.use(express.static('public'));

// Store connected devices
const devices = new Map();

// Generate unique code for ESP32
function generateDeviceCode() {
  return crypto.randomBytes(8).toString('hex').toUpperCase();
}

// Socket.IO connection handling
io.on('connection', (socket) => {
  console.log('New client connected:', socket.id);

  // ESP32 registration
  socket.on('register-esp32', (data) => {
    const deviceCode = generateDeviceCode();
    const deviceInfo = {
      id: socket.id,
      code: deviceCode,
      name: data.name || `ESP32_${deviceCode.substring(0, 4)}`,
      ip: data.ip || 'Unknown',
      status: 'online',
      lastSeen: new Date(),
      data: {}
    };

    devices.set(deviceCode, deviceInfo);
    socket.deviceCode = deviceCode;

    console.log(`ESP32 registered: ${deviceCode} - ${deviceInfo.name}`);
    socket.emit('device-registered', {
      success: true,
      deviceCode: deviceCode,
      message: `Device registered with code: ${deviceCode}`
    });

    // Broadcast update to all clients
    io.emit('devices-updated', Array.from(devices.values()));
  });

  // Receive data from ESP32
  socket.on('send-data', (data) => {
    const deviceCode = socket.deviceCode;
    if (devices.has(deviceCode)) {
      const device = devices.get(deviceCode);
      device.data = data.payload || {};
      device.lastSeen = new Date();
      device.status = 'online';

      console.log(`Data received from ${deviceCode}:`, device.data);

      // Broadcast to all clients
      io.emit('devices-updated', Array.from(devices.values()));
    }
  });

  // Send command to specific device
  socket.on('send-command', (data) => {
    const { targetCode, command } = data;
    if (devices.has(targetCode)) {
      const target = devices.get(targetCode);
      io.to(target.id).emit('command-received', command);
      console.log(`Command sent to ${targetCode}:`, command);
    }
  });

  // Broadcast message from one device to others
  socket.on('broadcast-message', (data) => {
    const senderCode = socket.deviceCode;
    const { message, type } = data;

    if (devices.has(senderCode)) {
      const sender = devices.get(senderCode);
      io.emit('message-received', {
        from: senderCode,
        senderName: sender.name,
        message: message,
        type: type || 'info',
        timestamp: new Date()
      });
      console.log(`Message from ${senderCode}: ${message}`);
    }
  });

  // Handle disconnection
  socket.on('disconnect', () => {
    const deviceCode = socket.deviceCode;
    if (devices.has(deviceCode)) {
      const device = devices.get(deviceCode);
      device.status = 'offline';
      console.log(`Device disconnected: ${deviceCode}`);
      io.emit('devices-updated', Array.from(devices.values()));
    }
  });

  // Send current devices list to new client
  socket.emit('devices-list', Array.from(devices.values()));
});

// HTTP Routes
app.get('/api/devices', (req, res) => {
  res.json(Array.from(devices.values()));
});

app.get('/api/device/:code', (req, res) => {
  const device = devices.get(req.params.code);
  if (device) {
    res.json(device);
  } else {
    res.status(404).json({ error: 'Device not found' });
  }
});

app.post('/api/device/:code/command', express.json(), (req, res) => {
  const device = devices.get(req.params.code);
  if (device) {
    io.to(device.id).emit('command-received', req.body.command);
    res.json({ success: true, message: 'Command sent' });
  } else {
    res.status(404).json({ error: 'Device not found' });
  }
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
x
