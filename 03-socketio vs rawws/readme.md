

# Experiment 2: Socket.IO vs Raw WebSocket Benchmark Report

## 1. Environment Setup

### 1.1 DigitalOcean Droplet Provisioning

* **OS**: Ubuntu 24.04 LTS (or Ubuntu 22.04 LTS)
* **Specs**: 4 vCPU, 8 GB RAM
* **Region**: Choose the closest region to minimize local administrative SSH latency.

### 1.2 OS-Level Kernel Tuning

By default, Linux limits file descriptors and network queues, which caps concurrent WebSocket connections around 1,024. Open `/etc/security/limits.conf` and append:

```text
* soft nofile 100000
* hard nofile 100000
root soft nofile 100000
root hard nofile 100000

```

Apply runtime kernel parameters for high-concurrency networking:

```bash
sudo sysctl -w fs.file-max=2097152
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w net.ipv4.ip_local_port_range="1024 65535"
sudo sysctl -w net.ipv4.tcp_max_syn_backlog=65535
ulimit -n 100000

```

### 1.3 Node.js Installation

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs htop
node -v

```

---

## 2. Project Architecture Setup

Create the experiment directory:

```bash
mkdir -p ~/benchmarks/exp2-websocket-vs-socketio
cd ~/benchmarks/exp2-websocket-vs-socketio
npm init -y
npm install ws socket.io socket.io-client

```

---

## 3. Implementation Code

### 3.1 Raw WebSocket Server (`server-ws.js`)

```javascript
const { WebSocketServer } = require('ws');

const PORT = 8080;
const wss = new WebSocketServer({ port: PORT });

let activeConnections = 0;

wss.on('connection', (ws) => {
  activeConnections++;

  ws.on('message', (message) => {
    ws.send(message);
  });

  ws.on('close', () => {
    activeConnections--;
  });

  ws.on('error', () => {});
});

console.log(`Raw WebSocket Server listening on port ${PORT}`);

```

### 3.2 Socket.IO Server (`server-socketio.js`)

```javascript
const { Server } = require('socket.io');

const PORT = 8081;
const io = new Server(PORT, {
  cors: { origin: '*' },
  transports: ['websocket'],
  perMessageDeflate: false
});

io.on('connection', (socket) => {
  socket.on('ping-event', (data) => {
    socket.emit('pong-event', data);
  });
});

console.log(`Socket.IO Server listening on port ${PORT}`);

```

### 3.3 Raw WebSocket Client Load Script (`bench-ws.js`)

```javascript
const WebSocket = require('ws');

const TARGET = parseInt(process.env.CONNECTIONS || '1000', 10);
const URL = 'ws://localhost:8080';

let connectedCount = 0;
let latencies = [];
const sockets = [];

console.log(`[Raw WS] Attempting ${TARGET} connections...`);

async function connect() {
  for (let i = 0; i < TARGET; i++) {
    const ws = new WebSocket(URL);

    ws.on('open', () => {
      connectedCount++;
      sockets.push(ws);
      if (connectedCount === TARGET) {
        runBenchmark();
      }
    });

    ws.on('message', (data) => {
      const payload = JSON.parse(data.toString());
      latencies.push(Date.now() - payload.ts);
    });

    ws.on('error', () => {});

    if (i % 500 === 0) {
      await new Promise((r) => setTimeout(r, 20));
    }
  }
}

function runBenchmark() {
  console.log(`[Raw WS] ${connectedCount} connections ready. Sending payloads...`);
  let index = 0;

  const interval = setInterval(() => {
    if (index >= TARGET) {
      clearInterval(interval);
      setTimeout(printResults, 2000);
      return;
    }

    const ws = sockets[index];
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ ts: Date.now() }));
      index++;
    }
  }, 1);
}

function printResults() {
  const avg = latencies.reduce((a, b) => a + b, 0) / (latencies.length || 1);
  const memMB = (process.memoryUsage().rss / 1024 / 1024).toFixed(2);

  console.log('\n===== RAW WEBSOCKET RESULTS =====');
  console.log(`Total Target       : ${TARGET}`);
  console.log(`Active Connections : ${connectedCount}`);
  console.log(`Messages Echoed    : ${latencies.length}`);
  console.log(`Average Latency    : ${avg.toFixed(2)} ms`);
  console.log(`Client RSS Memory  : ${memMB} MB`);
  process.exit(0);
}

connect();

```

### 3.4 Socket.IO Client Load Script (`bench-socketio.js`)

```javascript
const { io } = require('socket.io-client');

const TARGET = parseInt(process.env.CONNECTIONS || '1000', 10);
const URL = 'http://localhost:8081';

let connectedCount = 0;
let latencies = [];
const sockets = [];

console.log(`[Socket.IO] Attempting ${TARGET} connections...`);

async function connect() {
  for (let i = 0; i < TARGET; i++) {
    const socket = io(URL, {
      transports: ['websocket'],
      forceNew: true,
      reconnection: false
    });

    socket.on('connect', () => {
      connectedCount++;
      sockets.push(socket);
      if (connectedCount === TARGET) {
        runBenchmark();
      }
    });

    socket.on('pong-event', (payload) => {
      latencies.push(Date.now() - payload.ts);
    });

    if (i % 500 === 0) {
      await new Promise((r) => setTimeout(r, 20));
    }
  }
}

function runBenchmark() {
  console.log(`[Socket.IO] ${connectedCount} connections ready. Sending payloads...`);
  let index = 0;

  const interval = setInterval(() => {
    if (index >= TARGET) {
      clearInterval(interval);
      setTimeout(printResults, 2000);
      return;
    }

    const socket = sockets[index];
    if (socket && socket.connected) {
      socket.emit('ping-event', { ts: Date.now() });
      index++;
    }
  }, 1);
}

function printResults() {
  const avg = latencies.reduce((a, b) => a + b, 0) / (latencies.length || 1);
  const memMB = (process.memoryUsage().rss / 1024 / 1024).toFixed(2);

  console.log('\n===== SOCKET.IO RESULTS =====');
  console.log(`Total Target       : ${TARGET}`);
  console.log(`Active Connections : ${connectedCount}`);
  console.log(`Messages Echoed    : ${latencies.length}`);
  console.log(`Average Latency    : ${avg.toFixed(2)} ms`);
  console.log(`Client RSS Memory  : ${memMB} MB`);
  process.exit(0);
}

connect();

```

---

## 4. Execution Workflow

### Step 1: Initialize System Monitoring

Open a secondary SSH window to track CPU utilization, memory pressure, and open file limits during tests:

```bash
htop

```

### Step 2: Benchmarking Raw WebSocket

Run the server process:

```bash
node server-ws.js

```

In your main window, execute the test iterations sequentially:

```bash
CONNECTIONS=1000 node bench-ws.js | tee -a ws-results.log
CONNECTIONS=5000 node bench-ws.js | tee -a ws-results.log
CONNECTIONS=10000 node bench-ws.js | tee -a ws-results.log
CONNECTIONS=25000 node bench-ws.js | tee -a ws-results.log

```

Stop the server (`Ctrl+C`).

### Step 3: Benchmarking Socket.IO

Run the server process:

```bash
node server-socketio.js

```

In your main window, execute the test iterations sequentially:

```bash
CONNECTIONS=1000 node bench-socketio.js | tee -a socketio-results.log
CONNECTIONS=5000 node bench-socketio.js | tee -a socketio-results.log
CONNECTIONS=10000 node bench-socketio.js | tee -a socketio-results.log
CONNECTIONS=25000 node bench-socketio.js | tee -a socketio-results.log

```

---

## 5. Collected Benchmark Findings

Fill in your metrics table after running the suite:

| Target Connections | Framework | Connected Count | Avg Latency (ms) | Peak Server RAM | CPU Load | Result |
| --- | --- | --- | --- | --- | --- | --- |
| **1,000** | Raw WebSocket |  |  |  |  | Success |
| **1,000** | Socket.IO |  |  |  |  | Success |
| **5,000** | Raw WebSocket |  |  |  |  | Success |
| **5,000** | Socket.IO |  |  |  |  | Success |
| **10,000** | Raw WebSocket |  |  |  |  | Success |
| **10,000** | Socket.IO |  |  |  |  | Success |
| **25,000** | Raw WebSocket |  |  |  |  |  |
| **25,000** | Socket.IO |  |  |  |  |  |