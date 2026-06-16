# 📡 ESP32 Communication Hub

Un sistema centrale per la gestione e comunicazione tra multiple schede **ESP32**. Ogni dispositivo riceve un **codice univoco** e può comunicare con altri dispositivi e il server centrale.

## 🎯 Caratteristiche

- ✅ **Codici univoci**: Ogni ESP32 ottiene un codice esadecimale univoco
- ✅ **Real-time Communication**: Socket.IO per comunicazione istantanea
- ✅ **Dashboard Web**: Interfaccia moderna per monitorare e controllare i dispositivi
- ✅ **Comandi remoti**: Invia comandi personalizzati ai dispositivi
- ✅ **Lettura sensori**: Monitora i dati in tempo reale dai sensori
- ✅ **API REST**: Endpoint HTTP per integrazione con altri sistemi

## 📋 Requisiti

### Server Backend
- Node.js (v14 o superiore)
- npm

### ESP32
- Arduino IDE
- Librerie richieste:
  - ArduinoJson
  - SocketIoClient
  - WiFi (inclusa)

## 🚀 Installazione

### 1. Setup Server

```bash
# Clona il repository
git clone https://github.com/idk34-di/code.git
cd code

# Installa dipendenze
npm install

# Avvia il server
npm start
