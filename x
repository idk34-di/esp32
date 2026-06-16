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

// Mappa dei dispositivi connessi
const devices = new Map();

// Genera codice univoco per ESP32
function generateDeviceCode() {
  return crypto.randomBytes(6).toString('hex').toUpperCase();
}

// Gestione connessione Socket.IO
io.on('connection', (socket) => {
  console.log('✓ Nuovo client connesso:', socket.id);

  // Registrazione ESP32
  socket.on('register-esp32', (data) => {
    const deviceCode = generateDeviceCode();
    const deviceInfo = {
      id: socket.id,
      code: deviceCode,
      name: data.name || `ESP32_${deviceCode.substring(0, 4)}`,
      ip: data.ip || 'Unknown',
      status: 'online',
      connectedAt: new Date(),
      lastSeen: new Date(),
      sensorData: {}
    };

    devices.set(deviceCode, deviceInfo);
    socket.deviceCode = deviceCode;

    console.log(`\n📱 ESP32 Registrato:`);
    console.log(`   Codice: ${deviceCode}`);
    console.log(`   Nome: ${deviceInfo.name}\n`);

    socket.emit('device-registered', {
      success: true,
      deviceCode: deviceCode,
      message: `Dispositivo registrato con codice: ${deviceCode}`
    });

    // Aggiorna tutti i client
    io.emit('devices-updated', Array.from(devices.values()));
  });

  // Ricevi dati dai sensori dell'ESP32
  socket.on('send-data', (data) => {
    const deviceCode = socket.deviceCode;
    if (devices.has(deviceCode)) {
      const device = devices.get(deviceCode);
      device.sensorData = data.payload || {};
      device.lastSeen = new Date();
      device.status = 'online';

      console.log(`📊 Dati ricevuti da ${deviceCode}:`, device.sensorData);

      io.emit('devices-updated', Array.from(devices.values()));
      io.emit('data-received', {
        from: deviceCode,
        fromName: device.name,
        data: device.sensorData,
        timestamp: new Date()
      });
    }
  });

  // Invia comando a uno specifico dispositivo
  socket.on('send-command', (data) => {
    const { targetCode, command, params } = data;
    if (devices.has(targetCode)) {
      const target = devices.get(targetCode);
      io.to(target.id).emit('command-received', {
        command: command,
        params: params || {},
        timestamp: new Date()
      });
      console.log(`🔧 Comando inviato a ${targetCode}:`, command);
    } else {
      socket.emit('error', { message: `Dispositivo ${targetCode} non trovato` });
    }
  });

  // Broadcast di messaggio tra dispositivi
  socket.on('broadcast-message', (data) => {
    const senderCode = socket.deviceCode;
    const { message, type } = data;

    if (devices.has(senderCode)) {
      const sender = devices.get(senderCode);
      io.emit('message-received', {
        from: senderCode,
        fromName: sender.name,
        message: message,
        type: type || 'info',
        timestamp: new Date()
      });
      console.log(`💬 Messaggio da ${senderCode}: ${message}`);
    }
  });

  // Comunicazione tra due dispositivi specifici
  socket.on('device-to-device', (data) => {
    const { targetCode, message, data: payload } = data;
    const senderCode = socket.deviceCode;

    if (devices.has(targetCode) && devices.has(senderCode)) {
      const target = devices.get(targetCode);
      io.to(target.id).emit('device-message', {
        from: senderCode,
        fromName: devices.get(senderCode).name,
        message: message,
        data: payload,
        timestamp: new Date()
      });
      console.log(`🔗 Messaggio da ${senderCode} a ${targetCode}`);
    }
  });

  // Disconnessione
  socket.on('disconnect', () => {
    const deviceCode = socket.deviceCode;
    if (devices.has(deviceCode)) {
      const device = devices.get(deviceCode);
      device.status = 'offline';
      console.log(`\n❌ Dispositivo disconnesso: ${deviceCode}\n`);
      io.emit('devices-updated', Array.from(devices.values()));
    }
  });

  // Invia lista dispositivi al nuovo client
  socket.emit('devices-list', Array.from(devices.values()));
});

// ========== ROTTE HTTP ==========

// Ottieni lista di tutti i dispositivi
app.get('/api/devices', (req, res) => {
  res.json({
    success: true,
    count: devices.size,
    devices: Array.from(devices.values())
  });
});

// Ottieni info di uno specifico dispositivo
app.get('/api/device/:code', (req, res) => {
  const device = devices.get(req.params.code);
  if (device) {
    res.json({ success: true, device: device });
  } else {
    res.status(404).json({ success: false, error: 'Dispositivo non trovato' });
  }
});

// Invia comando HTTP a un dispositivo
app.post('/api/device/:code/command', (req, res) => {
  const device = devices.get(req.params.code);
  if (device) {
    io.to(device.id).emit('command-received', {
      command: req.body.command,
      params: req.body.params || {},
      timestamp: new Date()
    });
    res.json({ success: true, message: 'Comando inviato' });
  } else {
    res.status(404).json({ success: false, error: 'Dispositivo non trovato' });
  }
});

// Health check
app.get('/api/health', (req, res) => {
  res.json({
    status: 'online',
    timestamp: new Date(),
    connectedDevices: devices.size
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`\n🚀 Server avviato su http://localhost:${PORT}`);
  console.log(`📡 In attesa di ESP32...\n`);
});
