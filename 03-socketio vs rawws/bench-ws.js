const WebSocket = require('ws');

const TARGET_CONNECTIONS = parseInt(process.env.CONNECTIONS || '1000', 10);
const URL = 'ws://localhost:8080';

let connectedCount = 0;
let latencies = [];
const sockets = [];

console.log(`Starting Raw WS Test for ${TARGET_CONNECTIONS} connections...`);

async function run() {
  for (let i = 0; i < TARGET_CONNECTIONS; i++) {
    const ws = new WebSocket(URL);

    ws.on('open', () => {
      connectedCount++;
      sockets.push(ws);
      if (connectedCount === TARGET_CONNECTIONS) {
        startMessagingPhase();
      }
    });

    ws.on('message', (data) => {
      const payload = JSON.parse(data.toString());
      const latency = Date.now() - payload.ts;
      latencies.push(latency);
    });

    ws.on('error', () => {});

    if (i % 500 === 0) {
      await new Promise((r) => setTimeout(r, 50));
    }
  }
}

function startMessagingPhase() {
  console.log(`All ${TARGET_CONNECTIONS} connections established. Measuring latency...`);
  
  const startTime = Date.now();
  let sentMessages = 0;

  const interval = setInterval(() => {
    if (sentMessages >= TARGET_CONNECTIONS) {
      clearInterval(interval);
      setTimeout(printResults, 2000);
      return;
    }

    const ws = sockets[sentMessages];
    if (ws && ws.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ ts: Date.now() }));
      sentMessages++;
    }
  }, 1);
}

function printResults() {
  const avgLatency = latencies.reduce((a, b) => a + b, 0) / (latencies.length || 1);
  const memUsage = process.memoryUsage().rss / 1024 / 1024;
  
  console.log('--- Raw WebSocket Results ---');
  console.log(`Connected Users : ${connectedCount}`);
  console.log(`Messages Echoed : ${latencies.length}`);
  console.log(`Average Latency : ${avgLatency.toFixed(2)} ms`);
  console.log(`Client Memory   : ${memUsage.toFixed(2)} MB`);
  process.exit(0);
}

run();