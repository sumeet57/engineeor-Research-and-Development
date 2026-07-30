## Here is the complete step-by-step guide for **Experiment 10: Load Balancer Benchmark** (comparing **Nginx**, **HAProxy**, and **Traefik**), starting from a fresh Ubuntu installation on your 4 vCPU, 8 GB RAM DigitalOcean droplet.

---

# Experiment 10: Load Balancer Benchmark Guide

## 1. Initial VPS Setup (Fresh Ubuntu)

### 1.1 System Update and Base Dependencies

Run these commands immediately after logging into your fresh Ubuntu instance:

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git htop build-essential unzip wrk

```

### 1.2 Docker & Docker Compose Installation

Install Docker to isolate and run Nginx, HAProxy, and Traefik cleanly side-by-side:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
newgrp docker

```

Install Node.js for benchmarking and backend services:

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt install -y nodejs

```

### 1.3 Kernel Network Tuning

Increase OS limits for high-concurrency proxy traffic:

```bash
sudo sysctl -w fs.file-max=2097152
sudo sysctl -w net.core.somaxconn=65535
sudo sysctl -w net.ipv4.ip_local_port_range="1024 65535"
sudo sysctl -w net.ipv4.tcp_tw_reuse=1
ulimit -n 100000

```

---

## 2. Workspace & Backend Setup

Create the workspace directory:

```bash
mkdir -p ~/exp10-lb-benchmark
cd ~/exp10-lb-benchmark

```

### 2.1 Backend Application (`backend.js`)

```javascript
const http = require('http');

const PORT = process.env.PORT || 5000;
const SERVER_ID = process.env.SERVER_ID || 'backend-1';

const server = http.createServer((req, res) => {
  if (req.url === '/api/test') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', server: SERVER_ID, timestamp: Date.now() }));
    return;
  }
  res.writeHead(404);
  res.end();
});

server.listen(PORT, () => {
  console.log(`Backend ${SERVER_ID} active on port ${PORT}`);
});

```

### 2.2 Dockerfile for Backends (`Dockerfile.backend`)

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY backend.js .
EXPOSE 5000
CMD ["node", "backend.js"]

```

---

## 3. Load Balancer Configurations

### 3.1 Nginx Config (`nginx.conf`)

```nginx
events {
    worker_connections 20480;
    multi_accept on;
}

http {
    access_log off;
    error_log /dev/null crit;

    upstream backend_nodes {
        server backend1:5000;
        server backend2:5000;
        keepalive 256;
    }

    server {
        listen 8080;

        location / {
            proxy_pass http://backend_nodes;
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
        }
    }
}

```

### 3.2 HAProxy Config (`haproxy.cfg`)

```haproxy
global
    maxconn 50000
    log stdout format raw local0

defaults
    mode http
    timeout connect 5s
    timeout client 50s
    timeout server 50s

frontend http_front
    bind *:8081
    default_backend http_back

backend http_back
    balance roundrobin
    server node1 backend1:5000 check
    server node2 backend2:5000 check

```

### 3.3 Traefik Dynamic Config (`traefik.yml`)

```yaml
entryPoints:
  web:
    address: ":8082"

providers:
  file:
    filename: "/etc/traefik/dynamic.yml"

api:
  insecure: true

```

Create dynamic routing config (`dynamic.yml`):

```yaml
http:
  routers:
    to-backends:
      rule: "PathPrefix(`/`)"
      service: backend-service
      entryPoints:
        - web

  services:
    backend-service:
      loadBalancer:
        servers:
          - url: "http://backend1:5000"
          - url: "http://backend2:5000"

```

---

## 4. Docker Compose Environment Setup

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  backend1:
    build:
      context: .
      dockerfile: Dockerfile.backend
    environment:
      - PORT=5000
      - SERVER_ID=node-1

  backend2:
    build:
      context: .
      dockerfile: Dockerfile.backend
    environment:
      - PORT=5000
      - SERVER_ID=node-2

  lb-nginx:
    image: nginx:alpine
    ports:
      - "8080:8080"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
    depends_on:
      - backend1
      - backend2

  lb-haproxy:
    image: haproxy:alpine
    ports:
      - "8081:8081"
    volumes:
      - ./haproxy.cfg:/usr/local/etc/haproxy/haproxy.cfg:ro
    depends_on:
      - backend1
      - backend2

  lb-traefik:
    image: traefik:v3.0
    ports:
      - "8082:8082"
    volumes:
      - ./traefik.yml:/etc/traefik/traefik.yml:ro
      - ./dynamic.yml:/etc/traefik/dynamic.yml:ro
    depends_on:
      - backend1
      - backend2

```

Build and launch the full environment:

```bash
docker compose up -d --build

```

---

## 5. Benchmarking Execution Script

Install `autocannon` globally:

```bash
npm install -g autocannon

```

Create test execution script (`run-tests.sh`):

```bash
mkdir -p results

echo "Starting Nginx Benchmark..."
autocannon -c 500 -d 30 http://localhost:8080/api/test > results/nginx.log

echo "Starting HAProxy Benchmark..."
autocannon -c 500 -d 30 http://localhost:8081/api/test > results/haproxy.log

echo "Starting Traefik Benchmark..."
autocannon -c 500 -d 30 http://localhost:8082/api/test > results/traefik.log

echo "Benchmark Complete! Results saved in ./results"

```

Make the script executable and run it:

```bash
chmod +x run-tests.sh
./run-tests.sh

```

---

## 6. Results Summary Matrix

| Load Balancer | Port | Req/sec | Avg Latency (ms) | P99 Latency (ms) | Peak RAM (MB) | CPU Usage (%) |
| --- | --- | --- | --- | --- | --- | --- |
| **Nginx**<br> | 8080 |  |  |  |  |  |
| **HAProxy**<br> | 8081 |  |  |  |  |  |
| **Traefik**<br> | 8082 |  |  |  |  |  |