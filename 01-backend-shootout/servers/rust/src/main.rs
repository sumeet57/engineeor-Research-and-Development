use axum::{extract::Path, response::Json, routing::get, Router};
use flate2::{write::ZlibEncoder, Compression};
use rand::Rng;
use serde_json::{json, Value};
use sha2::{Digest, Sha256};
use std::collections::HashMap;
use std::io::Write;
use std::sync::Arc;

type Users = Arc<HashMap<u32, Value>>;

fn make_users() -> Users {
    let mut m = HashMap::new();
    for i in 1u32..=1000 {
        m.insert(
            i,
            json!({"id": i, "name": format!("User {}", i), "email": format!("user{}@example.com", i)}),
        );
    }
    Arc::new(m)
}

#[tokio::main]
async fn main() {
    let users = make_users();

    let app = Router::new()
        .route("/hello", get(hello))
        .route(
            "/user/:id",
            get({
                let users = users.clone();
                move |Path(id): Path<u32>| {
                    let users = users.clone();
                    async move {
                        let val = users
                            .get(&id)
                            .cloned()
                            .unwrap_or_else(|| json!({"error": "not found"}));
                        Json(val)
                    }
                }
            }),
        )
        .route("/cpu", get(cpu));

    println!("Rust (Axum) server running on port 3000");
    let listener = tokio::net::TcpListener::bind("0.0.0.0:3000").await.unwrap();
    axum::serve(listener, app).await.unwrap();
}

async fn hello() -> Json<Value> {
    Json(json!({"message": "Hello, World!"}))
}

async fn cpu() -> Json<Value> {
    let payload = vec![b'x'; 10000];
    // Hash
    let mut hasher = Sha256::new();
    hasher.update(&payload);
    let hash = format!("{:x}", hasher.finalize());
    // JSON
    let mut rng = rand::thread_rng();
    let items: Vec<Value> = (0..100)
        .map(|i| json!({"id": i, "val": rng.gen::<f64>()}))
        .collect();
    let data = json!({"items": items});
    let serialized = serde_json::to_string(&data).unwrap();
    let parsed: Value = serde_json::from_str(&serialized).unwrap();
    let item_count = parsed["items"].as_array().unwrap().len();
    // Compress
    let mut encoder = ZlibEncoder::new(Vec::new(), Compression::default());
    encoder.write_all(&payload).unwrap();
    let compressed = encoder.finish().unwrap();

    Json(json!({
        "hash": hash,
        "items": item_count,
        "compressed_size": compressed.len()
    }))
}
