import hashlib, json, zlib, random
from fastapi import FastAPI
from fastapi.responses import JSONResponse

app = FastAPI()

# Fake DB
users = {i: {"id": i, "name": f"User {i}", "email": f"user{i}@example.com"} for i in range(1, 1001)}
PAYLOAD = b"x" * 10000

@app.get("/hello")
def hello():
    return {"message": "Hello, World!"}

@app.get("/user/{user_id}")
def get_user(user_id: int):
    return users.get(user_id, {"error": "not found"})

@app.get("/cpu")
def cpu():
    # Hashing
    h = hashlib.sha256(PAYLOAD).hexdigest()
    # JSON processing
    data = {"items": [{"id": i, "val": random.random()} for i in range(100)]}
    parsed = json.loads(json.dumps(data))
    # Compression
    compressed = zlib.compress(PAYLOAD)
    return {"hash": h, "items": len(parsed["items"]), "compressed_size": len(compressed)}
