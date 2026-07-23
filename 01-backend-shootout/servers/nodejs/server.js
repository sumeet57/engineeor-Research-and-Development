const http = require("http");
const crypto = require("crypto");
const zlib = require("zlib");

// Fake DB
const users = {};
for (let i = 1; i <= 1000; i++) {
  users[i] = { id: i, name: `User ${i}`, email: `user${i}@example.com` };
}

const PAYLOAD = "x".repeat(10000);

const server = http.createServer((req, res) => {
  const url = req.url;

  // GET /hello
  if (url === "/hello") {
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ message: "Hello, World!" }));
    return;
  }

  // GET /user/:id
  const userMatch = url.match(/^\/user\/(\d+)$/);
  if (userMatch) {
    const user = users[parseInt(userMatch[1])] || { error: "not found" };
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify(user));
    return;
  }

  // GET /cpu
  if (url === "/cpu") {
    // Hashing
    const hash = crypto.createHash("sha256").update(PAYLOAD).digest("hex");
    // JSON processing
    const data = { items: Array.from({ length: 100 }, (_, i) => ({ id: i, val: Math.random() })) };
    const json = JSON.stringify(data);
    const parsed = JSON.parse(json);
    // Compression
    const compressed = zlib.deflateSync(Buffer.from(PAYLOAD));
    res.writeHead(200, { "Content-Type": "application/json" });
    res.end(JSON.stringify({ hash, items: parsed.items.length, compressed_size: compressed.length }));
    return;
  }

  res.writeHead(404);
  res.end("Not found");
});

const PORT = 3000;
server.listen(PORT, () => console.log(`Node.js server running on port ${PORT}`));
