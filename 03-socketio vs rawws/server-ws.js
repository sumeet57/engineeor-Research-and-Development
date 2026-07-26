const { WebSocketServer } = require('ws');

const wss = new WebSocketServer({ port: 8080 });

wss.on('connection', (ws) => {
  ws.on('message', (message) => {
    ws.send(message);
  });
});

console.log('Raw WebSocket server listening on port 8080');