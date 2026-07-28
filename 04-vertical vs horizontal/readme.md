Here is the markdown documentation for **Experiment 3: Vertical vs Horizontal Scaling**, tailored for your 4 vCPU, 8 GB RAM DigitalOcean droplet using Docker Compose, Nginx, and Redis.

---

# Experiment 3: Vertical vs Horizontal Scaling Benchmark Report

## 1. Environment Setup

### 1.1 DigitalOcean Droplet Configuration

* **Node Specs**: 4 vCPU, 8 GB RAM


* **OS**: Ubuntu 24.04 LTS
* **Topology**: Nginx Load Balancer routing to multiple backend container instances backed by a Redis pub/sub adapter.



### 1.2 Prerequisites Installation

```bash
sudo apt update && sudo apt install -y docker.io docker-compose-v2 htop
sudo usermod -aG docker $USER
newgrp docker

```

---

## 2. Project Architecture Setup

Create the experiment workspace:

```bash
mkdir -p ~/benchmarks/exp3-vertical-vs-horizontal
cd ~/benchmarks/exp3-vertical-vs-horizontal

```

Create `package.json`:

```json
{
  "name": "exp3-scaling-benchmark",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "@socket.io/redis-adapter": "^8.2.1",
    "express": "^4.19.2",
    "ioredis": "^5.4.1",
    "socket.io": "^4.7.5"
  }
}

```

---

## 3. Implementation Code

### 3.1 Backend Application (`server.js`)

```javascript
const express = require('express');
const { createServer } = require('http');
const { Server } = require('socket.io');
const { createClient } = require('ioredis');
const { createAdapter } = require('@socket.io/redis-adapter');
const crypto = require('crypto');

const app = express();
const httpServer = createServer(app);

const REDIS_HOST = process.env.REDIS_HOST || 'localhost';
const PORT = process.env.PORT || 3000;
const NODE_ID = process.env.NODE_ID || 'node-1';

const pubClient = new createClient({ host: REDIS_HOST, port: 6379 });
const subClient = pubClient.duplicate();

const io = new Server(httpServer, {
  cors: { origin: '*' },
  transports: ['websocket']
});

io.adapter(createAdapter(pubClient, subClient));

app.get('/api/workload', (req, res) => {
  let hash = '';
  for (let i = 0; i < 500; i++) {
    hash = crypto.createHash('sha256').update(`data-${i}-${Date.now()}`).digest('hex');
  }
  res.json({ status: 'ok', node: NODE_ID, hash });
});

io.on('connection', (socket) => {
  socket.on('broadcast-message', (data) => {
    io.emit('client-message', { ...data, servedBy: NODE_ID });
  });
});

httpServer.listen(PORT, () => {
  console.log(`Node ${NODE_ID} listening on port ${PORT}`);
});

```

### 3.2 Nginx Load Balancer Configuration (`nginx.conf`)

```nginx
events {
    worker_connections 10240;
}

http {
    upstream backend_cluster {
        ip_hash;
        server app-node-1:3000;
        server app-node-2:3000 optional;
        server app-node-3:3000 optional;
        server app-node-4:3000 optional;
    }

    server {
        listen 80;

        location / {
            proxy_pass http://backend_cluster;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "Upgrade";
            proxy_set_header Host $host;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
    }
}

```

### 3.3 Docker Orchestration (`docker-compose.yml`)

```yaml
version: '3.8'

services:
  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  app-node-1:
    build: .
    environment:
      - PORT=3000
      - NODE_ID=node-1
      - REDIS_HOST=redis
    depends_on:
      - redis

  app-node-2:
    build: .
    environment:
      - PORT=3000
      - NODE_ID=node-2
      - REDIS_HOST=redis
    depends_on:
      - redis

  app-node-3:
    build: .
    environment:
      - PORT=3000
      - NODE_ID=node-3
      - REDIS_HOST=redis
    depends_on:
      - redis

  app-node-4:
    build: .
    environment:
      - PORT=3000
      - NODE_ID=node-4
      - REDIS_HOST=redis
    depends_on:
      - redis

  load-balancer:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - app-node-1

```

### 3.4 Dockerfile (`Dockerfile`)

```dockerfile
FROM node:20-alpine
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install --production
COPY . .
EXPOSE 3000
CMD ["node", "server.js"]

```

---

## 4. Benchmark Client (`bench-load.js`)

```javascript
const autocannon = require('autocannon');

const URL = process.env.TARGET_URL || 'http://localhost/api/workload';
const CONNECTIONS = parseInt(process.env.CONNECTIONS || '100', 10);
const DURATION = parseInt(process.env.DURATION || '20', 10);

console.log(`Running REST API Benchmark on ${URL}`);
console.log(`Connections: ${CONNECTIONS}, Duration: ${DURATION}s`);

const instance = autocannon({
  url: URL,
  connections: CONNECTIONS,
  duration: DURATION
}, (err, result) => {
  if (err) {
    console.error(err);
    return;
  }
  console.log('\n===== BENCHMARK RESULTS =====');
  console.log(`Req/Sec (Throughput) : ${result.requests.average}`);
  console.log(`Latency Average      : ${result.latency.average} ms`);
  console.log(`Latency P99          : ${result.latency.p99} ms`);
  console.log(`Total Requests       : ${result.requests.total}`);
  console.log(`Errors               : ${result.errors}`);
});

autocannon.track(instance, { renderProgressBar: true });

```

---

## 5. Execution Workflow

### Step 1: Benchmark 1 Node (Vertical Allocation Test)

Spin up a single node behind the load balancer:

```bash
docker compose up -d redis app-node-1 load-balancer

```

Execute load test:

```bash
CONNECTIONS=500 DURATION=30 node bench-load.js | tee -a 1-node-results.log

```

### Step 2: Benchmark 2 Nodes (Horizontal Scale)

Spin up two nodes:

```bash
docker compose up -d --scale app-node-1=1 app-node-2

```

Execute load test:

```bash
CONNECTIONS=500 DURATION=30 node bench-load.js | tee -a 2-node-results.log

```

### Step 3: Benchmark 4 Nodes (Horizontal Scale)

Spin up four nodes matching your 4 vCPU core limit:

```bash
docker compose up -d app-node-1 app-node-2 app-node-3 app-node-4

```

Execute load test:

```bash
CONNECTIONS=500 DURATION=30 node bench-load.js | tee -a 4-node-results.log

```

---

## 6. Collected Benchmark Data

| Cluster Topology | vCPU Allocation | Requests/sec | Avg Latency (ms) | P99 Latency (ms) | Redis Overhead | Status |
| --- | --- | --- | --- | --- | --- | --- |
| **1 Node**<br> | 1 Core |  |  |  | Minimal | Success |
| **2 Nodes**<br> | 2 Cores |  |  |  | Low | Success |
| **4 Nodes**<br> | 4 Cores |  |  |  | Moderate | Success |