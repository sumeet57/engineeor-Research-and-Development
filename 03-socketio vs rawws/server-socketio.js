const { Server } = require('socket.io');

const io = new Server(8081, {
  cors: { origin: '*' }
});

io.on('connection', (socket) => {
  socket.on('ping-event', (data) => {
    socket.emit('pong-event', data);
  });
});

console.log('Socket.IO server listening on port 8081');