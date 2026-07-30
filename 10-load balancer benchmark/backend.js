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
