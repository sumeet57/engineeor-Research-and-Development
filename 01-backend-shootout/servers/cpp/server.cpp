#include "crow.h"
#include <openssl/sha.h>
#include <zlib.h>
#include <sstream>
#include <iomanip>
#include <random>
#include <map>

// Simple hex encode
std::string sha256hex(const std::string& input) {
    unsigned char hash[SHA256_DIGEST_LENGTH];
    SHA256(reinterpret_cast<const unsigned char*>(input.data()), input.size(), hash);
    std::ostringstream oss;
    for (auto b : hash) oss << std::hex << std::setw(2) << std::setfill('0') << (int)b;
    return oss.str();
}

std::string zlibCompress(const std::string& input) {
    uLong srcLen = input.size();
    uLong dstLen = compressBound(srcLen);
    std::string out(dstLen, '\0');
    compress(reinterpret_cast<Bytef*>(&out[0]), &dstLen,
             reinterpret_cast<const Bytef*>(input.data()), srcLen);
    out.resize(dstLen);
    return out;
}

int main() {
    crow::SimpleApp app;

    // Fake DB
    std::map<int, crow::json::wvalue> users;
    for (int i = 1; i <= 1000; i++) {
        crow::json::wvalue u;
        u["id"] = i;
        u["name"] = "User " + std::to_string(i);
        u["email"] = "user" + std::to_string(i) + "@example.com";
        users[i] = std::move(u);
    }

    CROW_ROUTE(app, "/hello")([]{
        crow::json::wvalue res;
        res["message"] = "Hello, World!";
        return crow::response(res);
    });

    CROW_ROUTE(app, "/user/<int>")([&users](int id){
        crow::json::wvalue res;
        auto it = users.find(id);
        if (it == users.end()) {
            res["error"] = "not found";
        } else {
            res["id"] = id;
            res["name"] = "User " + std::to_string(id);
            res["email"] = "user" + std::to_string(id) + "@example.com";
        }
        return crow::response(res);
    });

    CROW_ROUTE(app, "/cpu")([]{
        std::string payload(10000, 'x');
        // Hash
        auto hash = sha256hex(payload);
        // JSON - build manually (no heavy dep)
        std::mt19937 rng(42);
        std::uniform_real_distribution<double> dist(0.0, 1.0);
        std::ostringstream items;
        items << "[";
        for (int i = 0; i < 100; i++) {
            if (i) items << ",";
            items << "{\"id\":" << i << ",\"val\":" << dist(rng) << "}";
        }
        items << "]";
        // Compress
        auto compressed = zlibCompress(payload);
        crow::json::wvalue res;
        res["hash"] = hash;
        res["items"] = 100;
        res["compressed_size"] = (int)compressed.size();
        return crow::response(res);
    });

    app.port(3000).multithreaded().run();
}
