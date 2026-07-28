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