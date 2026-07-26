const { io } = require('socket.io-client');

const TARGET_CONNECTIONS = parseInt(process.env.CONNECTIONS || '1000', 10);
const URL = 'http://localhost:8081';

let connectedCount = 0;
let latencies = [];
const sockets = [];

console.log(`Starting Socket.IO Test for ${TARGET_CONNECTIONS} connections...`);

async function run() {
  for (let i = 0; i < TARGET_CONNECTIONS; i++) {
    const socket = io(URL, {
      transports: ['websocket'],
      forceNew: true
    });

    socket.on('connect', () => {
      connectedCount++;
      sockets.push(socket);
      if (connectedCount === TARGET_CONNECTIONS) {
        startMessagingPhase();
      }
    });

    socket.on('pong-event', (payload) => {
      const latency = Date.now() - payload.ts;
      latencies.push(latency);
    });

    if (i % 500 === 0) {
      await new Promise((r) => setTimeout(r, 50));
    }
  }
}

function startMessagingPhase() {
  console.log(`All ${TARGET_CONNECTIONS} connections established. Measuring latency...`);

  let sentMessages = 0;

  const interval = setInterval(() => {
    if (sentMessages >= TARGET_CONNECTIONS) {
      clearInterval(interval);
      setTimeout(printResults, 2000);
      return;
    }

    const socket = sockets[sentMessages];
    if (socket && socket.connected) {
      socket.emit('ping-event', { ts: Date.now() });
      sentMessages++;
    }
  }, 1);
}

function printResults() {
  const avgLatency = latencies.reduce((a, b) => a + b, 0) / (latencies.length || 1);
  const memUsage = process.memoryUsage().rss / 1024 / 1024;

  console.log('--- Socket.IO Results ---');
  console.log(`Connected Users : ${connectedCount}`);
  console.log(`Messages Echoed : ${latencies.length}`);
  console.log(`Average Latency : ${avgLatency.toFixed(2)} ms`);
  console.log(`Client Memory   : ${memUsage.toFixed(2)} MB`);
  process.exit(0);
}

run();