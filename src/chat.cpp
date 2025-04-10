#include "llama.h"
#include <crow.h>
#include <nlohmann/json.hpp>
#include <yaml-cpp/yaml.h>
#include <mutex>
#include <unordered_map>
#include <chrono>
#include <atomic>
#include <sstream>
#include <csignal>
// #include <prometheus/exposer.h>
// #include <prometheus/registry.h>

using namespace std::chrono;
using json = nlohmann::json;

struct Config {
    std::string model_path;
    std::string api_key;
    std::vector<std::string> cors_origins;
    int rate_limit;
    int session_expiry;
    std::string log_level;
};

Config g_config;
std::atomic<bool> running{true};

struct Session {
    std::vector<std::string> history;
    time_point<steady_clock> last_active;
    std::atomic<int> request_count{0};
};

std::mutex g_mutex;
std::unordered_map<std::string, Session> g_sessions;

// class Metrics {
// public:
//     prometheus::Family<prometheus::Counter>& requests = prometheus::BuildCounter()
//         .Name("http_requests_total")
//         .Help("Total HTTP Requests")
//         .Register(*registry);

//     prometheus::Family<prometheus::Gauge>& active_sessions = prometheus::BuildGauge()
//         .Name("active_sessions")
//         .Help("Currently Active Sessions")
//         .Register(*registry);

//     std::shared_ptr<prometheus::Registry> registry = std::make_shared<prometheus::Registry>();
// } g_metrics;

Config load_config(const std::string& path) {
    YAML::Node config = YAML::LoadFile(path);
    return Config{
        config["model_path"].as<std::string>(),
        config["api_key"].as<std::string>(),
        config["cors_allowed_origins"].as<std::vector<std::string>>(),
        config["rate_limit"].as<int>(120),
        config["session_expiry"].as<int>(1800),
        config["log_level"].as<std::string>("warning")
    };
}

void signal_handler(int) {
    running = false;
}

class ChatProcessor {
    llama_model* model;
    llama_context* ctx;

public:
    ChatProcessor(const Config& config) {
        llama_model_params model_params = llama_model_default_params();
        model = llama_load_model_from_file(config.model_path.c_str(), model_params);
        if (!model) throw std::runtime_error("Failed to load model");

        llama_context_params ctx_params = llama_context_default_params();
        ctx_params.n_ctx = 4096;
        ctx = llama_new_context_with_model(model, ctx_params);
        if (!ctx) throw std::runtime_error("Failed to create context");
    }

    ~ChatProcessor() {
        llama_free(ctx);
        llama_free_model(model);
    }

    std::string process_message(const std::string& input, std::vector<std::string>& history) {
        history.push_back(input + " [/INST] ");
        std::string prompt;
        for (const auto& msg : history) prompt += msg;

        auto tokens = llama_tokenize(ctx, prompt, true);
        const int max_ctx = llama_n_ctx(ctx);
        
        while (tokens.size() > max_ctx - 128) {
            if (history.size() > 2) {
                history.erase(history.begin() + 1);
                history.erase(history.begin() + 1);
            }
            prompt.clear();
            for (const auto& msg : history) prompt += msg;
            tokens = llama_tokenize(ctx, prompt, true);
        }

        if (llama_eval(ctx, tokens.data(), tokens.size(), 0, 4)) {
            throw std::runtime_error("Evaluation failed");
        }

        std::string response;
        for (int i = 0; i < 512; ++i) {
            llama_token id = llama_sample_token(ctx, nullptr, nullptr, 40, 0.8, 0.95);
            if (id == llama_token_eos(ctx)) break;
            response += llama_token_to_piece(ctx, id);
            if (llama_eval(ctx, &id, 1, llama_get_kv_cache_token_count(ctx), 4)) break;
        }

        history.push_back(response + " [INST] ");
        return response;
    }
};

class AuthMiddleware : public crow::ILocalMiddleware {
public:
    struct context {};

    void before_handle(crow::request& req, crow::response& res, context& ctx) override {
        const auto& api_key = req.get_header_value("X-API-Key");
        if(api_key != g_config.api_key) {
            res.code = 401;
            res.write(json{{"error", "Invalid API key"}}.dump());
            res.end();
        }
    }
};

int main(int argc, char** argv) {
    // g_config = load_config("/app/config.yaml");
    g_config = load_config("config.yaml");
    ChatProcessor processor(g_config);

    crow::SimpleApp app;
    app.loglevel(g_config.log_level == "debug" ? crow::LogLevel::DEBUG : crow::LogLevel::WARNING)
       .template set_header("Access-Control-Allow-Origin", g_config.cors_origins)
       .template set_header("Access-Control-Allow-Methods", "POST, GET, OPTIONS")
       .template set_header("Access-Control-Allow-Headers", "X-API-Key, Content-Type");

    std::thread([&]{
        while(running) {
            std::this_thread::sleep_for(1min);
            std::lock_guard<std::mutex> lock(g_mutex);
            auto now = steady_clock::now();
            
            for (auto it = g_sessions.begin(); it != g_sessions.end();) {
                if (now - it->second.last_active > seconds(g_config.session_expiry)) {
                    it = g_sessions.erase(it);
                    g_metrics.active_sessions.Dec();
                } else {
                    ++it;
                }
            }
        }
    }).detach();

    CROW_ROUTE(app, "/health")([]{ return crow::response(200); });

    // CROW_ROUTE(app, "/metrics")([]{
    //     return crow::response(prometheus::TextSerializer().Serialize(g_metrics.registry->Collect()));
    // });

    // CROW_ROUTE(app, "/chat")
    //     .CROW_MIDDLEWARES(app, AuthMiddleware)
    //     .methods("POST"_method)([&](const crow::request& req){
    //         // g_metrics.requests.Add({}).Increment();
    //         json response;
    //         try {
    //             auto data = json::parse(req.body);
    //             std::string session_id = data["session_id"];
    //             std::string message = data.value("message", "");

    //             std::lock_guard<std::mutex> lock(g_mutex);
    //             auto& session = g_sessions[session_id];
                
    //             if (session.request_count++ > g_config.rate_limit) {
    //                 return crow::response(429, {{"error", "Rate limit exceeded"}});
    //             }
    //             session.last_active = steady_clock::now();

    //             std::string assistant_response = processor.process_message(message, session.history);
    //             size_t pos = assistant_response.find("</s>");
    //             if (pos != std::string::npos) assistant_response.erase(pos);

    //             response = {
    //                 {"response", assistant_response},
    //                 {"session_id", session_id},
    //                 {"tokens_used", session.history.size()}
    //             };
    //         }
    //         catch (const std::exception& e) {
    //             response["error"] = e.what();
    //             return crow::response(500, response);
    //         }
    //         return crow::response(response);
    //     });
    CROW_ROUTE(app, "/chat")
    .methods("POST"_method)([&](const crow::request& req){
        // API Key validation
        const auto& api_key = req.get_header_value("X-API-Key");
        if(api_key != std::getenv("CHATBOT_API_KEY")) {
            return crow::response(401, {{"error", "Invalid API key"}});
        }
    
        // Process request
        auto data = json::parse(req.body);
        std::string message = data.value("message", "");
        std::string session_id = data.value("session_id", "default");
    
        std::lock_guard<std::mutex> lock(g_mutex);
        auto& session = g_sessions[session_id];
        
        // Rate limiting
        if (session.request_count++ > 100) {
            return crow::response(429, {{"error", "Rate limit exceeded"}});
        }
    
        // Generate response
        std::string response_text = processor.process_message(message, session.history);
        
        // Format response for Express compatibility
        return crow::response(json{
            {"text", response_text},
            {"buttons", json::array()},
            {"showOptions", true}
        }.dump());
    });

    signal(SIGINT, signal_handler);
    signal(SIGTERM, signal_handler);
    app.port(8080).multithreaded().run();
    return 0;
}