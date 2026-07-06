#include <iostream>
#include <string>
#include <vector>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <thread>
#include <atomic>
#include <chrono>
#include <fstream>
#include <sstream>
#include <map>
#include <algorithm>
#include <cstring>
#include <cstdlib>
#include <cctype>

#include <unistd.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

// OpenSSL is required for httplib.h if SSL is used
#define CPPHTTPLIB_OPENSSL_SUPPORT
#include "httplib.h"
#include "json.hpp"

#include "brain_core.h"

// Default Shakespeare Script
const std::string g_default_script = 
    "To be, or not to be, that is the question:\n"
    "Whether 'tis nobler in the mind to suffer\n"
    "The slings and arrows of outrageous fortune,\n"
    "Or to take arms against a sea of troubles\n"
    "And by opposing end them. To die—to sleep,\n"
    "No more; and by a sleep to say we end\n"
    "The heart-ache and the thousand natural shocks\n"
    "That flesh is heir to: 'tis a consummation\n"
    "Devoutly to be wish'd. To die, to sleep;\n"
    "To sleep, perchance to dream—ay, there's the rub:\n"
    "For in that sleep of death what dreams may come,\n"
    "When we have shuffled off this mortal coil,\n"
    "Must give us pause.";

// Script variables
std::mutex g_script_mutex;
std::string g_script_text = "";
std::vector<std::string> g_script_words;
int g_script_index = 0;
double g_script_threshold = 0.7; // default 70% accuracy

// Global / class-level state
AppArgs g_args;
std::mutex g_process_mutex;
std::atomic<bool> g_is_running{false};
pid_t g_pid_a = 0;
pid_t g_pid_b = 0;
std::thread g_read_thread_a;
std::thread g_read_thread_b;

std::mutex g_buffer_mutex;
std::vector<nlohmann::json> g_transcriptions;
std::vector<nlohmann::json> g_analysis_packets;

// SSE Client streams
std::mutex g_clients_mutex;
std::vector<std::shared_ptr<SafeQueue<std::string>>> g_client_queues;

// Duplicate helper functions removed - defined in brain_core.h

// Broadcast message to all EventSource clients
void broadcast_to_sse(const std::string& msg) {
    std::lock_guard<std::mutex> lock(g_clients_mutex);
    for (auto& queue : g_client_queues) {
        queue->push(msg);
    }
}

// Spawn process helper
bool spawn_process(const std::vector<std::string>& cmd, pid_t& out_pid, int& out_stdout_fd) {
    int stdout_pipe[2];
    if (pipe(stdout_pipe) < 0) return false;
    
    pid_t pid = fork();
    if (pid < 0) {
        close(stdout_pipe[0]);
        close(stdout_pipe[1]);
        return false;
    }
    
    if (pid == 0) {
        // Child process
        dup2(stdout_pipe[1], STDOUT_FILENO);
        close(stdout_pipe[0]);
        close(stdout_pipe[1]);
        
        std::vector<char*> args;
        for (const auto& arg : cmd) {
            args.push_back(const_cast<char*>(arg.c_str()));
        }
        args.push_back(nullptr);
        
        execvp(args[0], args.data());
        exit(127);
    } else {
        // Parent process
        close(stdout_pipe[1]);
        out_pid = pid;
        out_stdout_fd = stdout_pipe[0];
        return true;
    }
}

// Read lines from subprocess stdout
void read_stdout_loop(int fd, const std::string& name, std::function<void(const std::string&)> on_line) {
    char buf[2048];
    std::string line_buf;
    while (true) {
        ssize_t bytes = read(fd, buf, sizeof(buf));
        if (bytes <= 0) break;
        for (ssize_t i = 0; i < bytes; ++i) {
            if (buf[i] == '\n') {
                if (!line_buf.empty()) {
                    on_line(line_buf);
                    line_buf.clear();
                }
            } else {
                line_buf += buf[i];
            }
        }
    }
    close(fd);
}

// Handle incoming lines from stdout threads
void handle_incoming_line(const std::string& name, const std::string& line) {
    try {
        auto j = nlohmann::json::parse(line);
        
        // Broadcast to clients
        broadcast_to_sse(line);
        
        // Store in buffers
        std::lock_guard<std::mutex> lock(g_buffer_mutex);
        double now_sec = get_time_seconds();
        if (name == "engine-a") {
            if (j.contains("type") && j["type"] == "transcription") {
                j["time"] = now_sec;
                g_transcriptions.push_back(j);
                if (g_transcriptions.size() > 10) {
                    g_transcriptions.erase(g_transcriptions.begin());
                }
                
                // Perform script alignment
                std::string text = j.value("text", "");
                auto trans_words = tokenize_words(text);
                
                MatchResult match;
                bool following = false;
                int old_index = 0;
                {
                    std::lock_guard<std::mutex> lock_script(g_script_mutex);
                    old_index = g_script_index;
                    match = find_best_match(g_script_words, g_script_index, trans_words, g_script_threshold);
                    following = (match.best_similarity >= g_script_threshold);
                    if (following) {
                        g_script_index = g_script_index + match.best_offset + match.best_len;
                    }
                }
                
                std::string expected_slice = "";
                {
                    std::lock_guard<std::mutex> lock_script(g_script_mutex);
                    if (following) {
                        int start = old_index + match.best_offset;
                        int length = match.best_len;
                        for (int i = 0; i < length; ++i) {
                            if (start + i >= 0 && start + i < (int)g_script_words.size()) {
                                if (i > 0) expected_slice += " ";
                                expected_slice += g_script_words[start + i];
                            }
                        }
                    }
                }
                
                nlohmann::json align_packet = {
                    {"type", "alignment"},
                    {"status", following ? "following" : "deviating"},
                    {"accuracy", match.best_similarity},
                    {"script_index", g_script_index},
                    {"transcription", text},
                    {"expected_slice", expected_slice}
                };
                broadcast_to_sse(align_packet.dump());
            }
        } else if (name == "engine-b") {
            if (j.contains("type") && j["type"] == "analysis") {
                j["time"] = now_sec;
                g_analysis_packets.push_back(j);
                
                double cutoff = now_sec - 20.0;
                g_analysis_packets.erase(
                    std::remove_if(g_analysis_packets.begin(), g_analysis_packets.end(),
                                   [cutoff](const nlohmann::json& p) { return p.value("time", 0.0) < cutoff; }),
                    g_analysis_packets.end()
                );
            }
        }
    } catch (...) {
        // parsing error or invalid format, ignore
    }
}

// Stop Subprocesses
void stop_processes() {
    std::lock_guard<std::mutex> lock(g_process_mutex);
    if (!g_is_running) return;
    
    std::cerr << "Brain C++: Stopping backend processes...\n";
    g_is_running = false;
    
    if (g_pid_a > 0) {
        kill(g_pid_a, SIGTERM);
        waitpid(g_pid_a, nullptr, 0);
        g_pid_a = 0;
    }
    if (g_pid_b > 0) {
        kill(g_pid_b, SIGTERM);
        waitpid(g_pid_b, nullptr, 0);
        g_pid_b = 0;
    }
    
    if (g_read_thread_a.joinable()) g_read_thread_a.join();
    if (g_read_thread_b.joinable()) g_read_thread_b.join();
    
    nlohmann::json status_change = {
        {"type", "status"},
        {"status", "stopped"}
    };
    broadcast_to_sse(status_change.dump());
}

// Start Subprocesses
bool start_processes(const std::string& override_llm, const std::string& override_labels) {
    std::lock_guard<std::mutex> lock(g_process_mutex);
    if (g_is_running) return true;
    
    if (!override_llm.empty()) {
        g_args.llm = override_llm;
    }
    std::string labels_to_use = g_args.engine_b_labels;
    if (!override_labels.empty()) {
        labels_to_use = override_labels;
    }
    
    // 1. Whisper Command
    std::vector<std::string> whisper_cmd = {
        g_args.whisper_bin,
        "-m", g_args.whisper_model,
        "--json"
    };
    if (g_args.whisper_device >= 0) {
        whisper_cmd.push_back("-c");
        whisper_cmd.push_back(std::to_string(g_args.whisper_device));
    }
    
    // 2. Engine B Command
    std::vector<std::string> engine_b_cmd = {
        "/home/grayson/workbench/spell/.venv/bin/python3",
        g_args.engine_b_script,
        "--window", std::to_string(g_args.engine_b_window),
        "--step", std::to_string(g_args.engine_b_step)
    };
    if (g_args.engine_b_device >= 0) {
        engine_b_cmd.push_back("--device");
        engine_b_cmd.push_back(std::to_string(g_args.engine_b_device));
    }
    if (!labels_to_use.empty()) {
        engine_b_cmd.push_back("--labels");
        engine_b_cmd.push_back(labels_to_use);
    }
    
    std::cerr << "Brain C++: Starting Engine A: ";
    for (auto& s : whisper_cmd) std::cerr << s << " ";
    std::cerr << "\n";
    
    std::cerr << "Brain C++: Starting Engine B: ";
    for (auto& s : engine_b_cmd) std::cerr << s << " ";
    std::cerr << "\n";
    
    int fd_a = -1;
    if (!spawn_process(whisper_cmd, g_pid_a, fd_a)) {
        std::cerr << "Brain C++: Failed to start Engine A\n";
        return false;
    }
    
    int fd_b = -1;
    if (!spawn_process(engine_b_cmd, g_pid_b, fd_b)) {
        std::cerr << "Brain C++: Failed to start Engine B\n";
        kill(g_pid_a, SIGTERM);
        waitpid(g_pid_a, nullptr, 0);
        g_pid_a = 0;
        return false;
    }
    
    g_is_running = true;
    
    // Clear old buffers
    {
        std::lock_guard<std::mutex> lock2(g_buffer_mutex);
        g_transcriptions.clear();
        g_analysis_packets.clear();
    }
    
    // Start read threads
    g_read_thread_a = std::thread([fd_a]() {
        read_stdout_loop(fd_a, "engine-a", [](const std::string& line) {
            handle_incoming_line("engine-a", line);
        });
    });
    
    g_read_thread_b = std::thread([fd_b]() {
        read_stdout_loop(fd_b, "engine-b", [](const std::string& line) {
            handle_incoming_line("engine-b", line);
        });
    });
    
    // Broadcast status change
    nlohmann::json status_change = {
        {"type", "status"},
        {"status", "started"}
    };
    broadcast_to_sse(status_change.dump());
    
    return true;
}

// Check Subprocesses
void check_subprocesses() {
    if (g_is_running) {
        if (g_pid_a > 0) {
            pid_t res = waitpid(g_pid_a, nullptr, WNOHANG);
            if (res > 0) {
                std::cerr << "Brain C++: Engine A terminated unexpectedly.\n";
                stop_processes();
                return;
            }
        }
        if (g_pid_b > 0) {
            pid_t res = waitpid(g_pid_b, nullptr, WNOHANG);
            if (res > 0) {
                std::cerr << "Brain C++: Engine B terminated unexpectedly.\n";
                stop_processes();
                return;
            }
        }
    }
}

// Summarize Context for LLM
void get_summary_context(std::string& out_dialogue, std::string& out_features) {
    std::lock_guard<std::mutex> lock(g_buffer_mutex);
    double now_sec = get_time_seconds();
    
    // 1. Dialogue
    double cutoff_dialogue = now_sec - 60.0;
    std::string dialogue_str = "";
    for (const auto& t : g_transcriptions) {
        if (t.value("time", 0.0) > cutoff_dialogue) {
            std::string txt = t.value("text", "");
            double conf = t.value("confidence", 0.0);
            char conf_str[32];
            snprintf(conf_str, sizeof(conf_str), "%.2f", conf);
            dialogue_str += "- \"" + txt + "\" (confidence: " + std::string(conf_str) + ")\n";
        }
    }
    if (dialogue_str.empty()) {
        dialogue_str = "(No dialogue captured recently)";
    }
    out_dialogue = dialogue_str;
    
    // 2. Features
    if (g_analysis_packets.empty()) {
        out_features = "(No audio analysis data available)";
        return;
    }
    
    double sum_rms = 0.0;
    double sum_centroid = 0.0;
    double sum_tempo = 0.0;
    std::map<std::string, double> label_sums;
    
    for (const auto& p : g_analysis_packets) {
        sum_rms += p.value("rms", 0.0);
        sum_centroid += p.value("centroid", 0.0);
        sum_tempo += p.value("tempo", 0.0);
        
        if (p.contains("labels") && p["labels"].is_object()) {
            for (auto& el : p["labels"].items()) {
                label_sums[el.key()] += el.value().get<double>();
            }
        }
    }
    
    double avg_rms = sum_rms / g_analysis_packets.size();
    double avg_centroid = sum_centroid / g_analysis_packets.size();
    double avg_tempo = sum_tempo / g_analysis_packets.size();
    
    std::string detected_str = "";
    for (auto const& [label, sum] : label_sums) {
        double avg_prob = sum / g_analysis_packets.size();
        if (avg_prob > 0.15) {
            if (!detected_str.empty()) detected_str += ", ";
            char pct[32];
            snprintf(pct, sizeof(pct), "%.1f%%", avg_prob * 100.0);
            detected_str += label + " (" + std::string(pct) + ")";
        }
    }
    if (detected_str.empty()) {
        detected_str = "no distinct sound patterns detected";
    }
    
    char rms_str[32], centroid_str[32], tempo_str[32];
    snprintf(rms_str, sizeof(rms_str), "%.4f", avg_rms);
    snprintf(centroid_str, sizeof(centroid_str), "%.1f", avg_centroid);
    snprintf(tempo_str, sizeof(tempo_str), "%.1f", avg_tempo);
    
    out_features = 
        "        - Loudness (RMS): " + std::string(rms_str) + " (0.0 is silent, 0.2+ is loud)\n"
        "        - Brightness (Spectral Centroid): " + std::string(centroid_str) + " Hz (low is dark/muffled, high is bright/harsh)\n"
        "        - Rhythmic Speed (Tempo): " + std::string(tempo_str) + " BPM\n"
        "        - Character/Identity (CLAP zero-shot tags): " + detected_str + "\n";
}

// generate_mock_story defined in brain_core.h

// Query LLM
std::string query_llm(const AppArgs& args, const std::string& dialogue, const std::string& features, const std::string& context_info) {
    if (args.llm == "none") {
        return "";
    }
    std::string prompt = 
        "You are \"Aural Glossary\", a live AI-driven captioning and translation engine designed to describe the qualitative and synesthetic parameters of sound for deaf and aural-diverse audiences.\n\n"
        + context_info + "\n\n"
        "Here is the recent audio analysis and dialogue from the last few seconds:\n\n"
        "=== RECENT AUDIO ANALYSIS & FEATURES ===\n" + features + "\n\n"
        "=== RECENT SPOKEN DIALOGUE / LYRICS ===\n" + dialogue + "\n\n"
        "=== MISSION ===\n"
        "Generate a brief, evocative, synesthetic description (1 to 2 sentences) of the current soundscape for the live audience teleprompter.\n"
        "- Describe the qualitative feeling, movement, or texture of the sound.\n"
        "- Integrate the spoken dialogue if it exists, explaining its acoustic context (e.g. \"spoken clearly\", \"muffled whispers\", \"vocals rising over a drone\").\n"
        "- DO NOT use technical terms like \"RMS\", \"BPM\", \"Centroid\", \"CLAP\", or \"Hz\".\n"
        "- DO NOT use prefixes or headers like \"Aural Glossary:\" or \"Description:\". Output ONLY the description itself.\n";

    if (args.llm == "mock") {
        return generate_mock_story(dialogue, features);
    } else if (args.llm == "gemini") {
        if (args.api_key.empty()) {
            std::cerr << "Brain C++: Gemini API key not provided, using mock fallback.\n";
            return generate_mock_story(dialogue, features);
        }
        
        std::string host = "generativelanguage.googleapis.com";
        std::string path = "/v1beta/models/" + args.gemini_model + ":generateContent?key=" + args.api_key;
        
        nlohmann::json req_body = {
            {"contents", {
                {{"parts", {
                    {{"text", prompt}}
                }}}
            }}
        };
        
        httplib::SSLClient cli(host);
        cli.set_connection_timeout(10, 0);
        cli.set_read_timeout(10, 0);
        
        auto res = cli.Post(path.c_str(), req_body.dump(), "application/json");
        if (res && res->status == 200) {
            try {
                auto res_json = nlohmann::json::parse(res->body);
                std::string story = res_json["candidates"][0]["content"]["parts"][0]["text"].get<std::string>();
                return trim(story);
            } catch (std::exception& e) {
                std::cerr << "Brain C++: Error parsing Gemini response: " << e.what() << ", using mock fallback.\n";
            }
        } else {
            std::cerr << "Brain C++: Gemini request failed. Status: " << (res ? std::to_string(res->status) : "Failed to connect") << ", using mock fallback.\n";
        }
        return generate_mock_story(dialogue, features);
        
    } else if (args.llm == "ollama") {
        std::string url = args.ollama_url;
        std::string host = "localhost";
        int port = 11434;
        if (url.rfind("http://", 0) == 0) {
            url = url.substr(7);
        }
        size_t colon = url.find(':');
        if (colon != std::string::npos) {
            host = url.substr(0, colon);
            port = std::stoi(url.substr(colon + 1));
        } else {
            host = url;
            port = 80;
        }
        
        nlohmann::json req_body = {
            {"model", args.ollama_model},
            {"prompt", prompt},
            {"stream", false},
            {"options", {
                {"temperature", 0.7},
                {"num_predict", 100}
            }}
        };
        
        httplib::Client cli(host, port);
        cli.set_connection_timeout(15, 0);
        cli.set_read_timeout(15, 0);
        
        auto res = cli.Post("/api/generate", req_body.dump(), "application/json");
        if (res && res->status == 200) {
            try {
                auto res_json = nlohmann::json::parse(res->body);
                std::string story = res_json["response"].get<std::string>();
                return trim(story);
            } catch (std::exception& e) {
                std::cerr << "Brain C++: Error parsing Ollama response: " << e.what() << ", using mock fallback.\n";
            }
        } else {
            std::cerr << "Brain C++: Ollama request failed. Status: " << (res ? std::to_string(res->status) : "Failed to connect") << ", using mock fallback.\n";
        }
        return generate_mock_story(dialogue, features);
    }
    
    return "[Unsupported LLM type]";
}

// load_context_file defined in brain_core.h

// Send OSC string message over UDP
void send_osc_string(const std::string& ip, int port, const std::string& address, const std::string& value) {
    std::vector<char> buf;
    
    // Address
    buf.insert(buf.end(), address.begin(), address.end());
    buf.push_back('\0');
    while (buf.size() % 4 != 0) buf.push_back('\0');
    
    // Type tags
    std::string tags = ",s";
    buf.insert(buf.end(), tags.begin(), tags.end());
    buf.push_back('\0');
    while (buf.size() % 4 != 0) buf.push_back('\0');
    
    // Value
    buf.insert(buf.end(), value.begin(), value.end());
    buf.push_back('\0');
    while (buf.size() % 4 != 0) buf.push_back('\0');
    
    int fd = socket(AF_INET, SOCK_DGRAM, 0);
    if (fd < 0) return;
    
    sockaddr_in addr;
    memset(&addr, 0, sizeof(addr));
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    inet_pton(AF_INET, ip.c_str(), &addr.sin_addr);
    
    sendto(fd, buf.data(), buf.size(), 0, (struct sockaddr*)&addr, sizeof(addr));
    close(fd);
}

// Periodic story generation loop running in a background thread
void background_loop() {
    double last_generation = get_time_seconds();
    while (true) {
        check_subprocesses();
        
        double now = get_time_seconds();
        if (g_is_running && (now - last_generation >= g_args.interval)) {
            std::string dialogue;
            std::string features;
            get_summary_context(dialogue, features);
            
            bool has_activity = false;
            {
                std::lock_guard<std::mutex> lock(g_buffer_mutex);
                has_activity = !g_transcriptions.empty() || !g_analysis_packets.empty();
            }
            
            if (has_activity && g_args.llm != "none") {
                std::string context_info = load_context_file(g_args.context_file);
                std::string story = query_llm(g_args, dialogue, features, context_info);
                
                nlohmann::json output_packet = {
                    {"type", "story"},
                    {"timestamp_ms", static_cast<long long>(now * 1000)},
                    {"story", story}
                };
                
                std::cout << output_packet.dump() << std::endl;
                broadcast_to_sse(output_packet.dump());
                
                if (!g_args.output_osc_ip.empty()) {
                    send_osc_string(g_args.output_osc_ip, g_args.output_osc_port, "/story", story);
                }
            }
            last_generation = now;
        }
        std::this_thread::sleep_for(std::chrono::milliseconds(100));
    }
}

int main(int argc, char* argv[]) {
    // Force PortAudio lib path for Engine B and libwhisper for Engine A
    char cwd[1024];
    std::string ld_lib_path = "/home/grayson/.local/share/mamba/envs/.mamba-env/lib";
    if (getcwd(cwd, sizeof(cwd)) != nullptr) {
        ld_lib_path += ":" + std::string(cwd) + "/aural-glossary/engine_a/whisper.cpp/build/bin";
    }
    char* existing_ld = std::getenv("LD_LIBRARY_PATH");
    if (existing_ld) {
        ld_lib_path += ":" + std::string(existing_ld);
    }
    setenv("LD_LIBRARY_PATH", ld_lib_path.c_str(), 1);
    
    // Initialize script state
    {
        std::lock_guard<std::mutex> lock(g_script_mutex);
        g_script_text = g_default_script;
        g_script_words = tokenize_words(g_default_script);
        g_script_index = 0;
        g_script_threshold = 0.7;
    }
    
    g_args = parse_args(argc, argv);
    
    // Check environment for Gemini API Key if missing
    if (g_args.api_key.empty()) {
        char* env_key = std::getenv("GEMINI_API_KEY");
        if (env_key) {
            g_args.api_key = env_key;
        }
    }
    
    // Auto-start if requested
    if (g_args.auto_start) {
        start_processes("", "");
    }
    
    // Start background processor loop thread
    std::thread bg_thread(background_loop);
    bg_thread.detach();
    
    httplib::Server svr;
    
    // Serve Web UI dashboard
    svr.set_mount_point("/", "aural-glossary/web_ui");
    
    // Serve empty response for favicon.ico to prevent 404 noise
    svr.Get("/favicon.ico", [](const httplib::Request&, httplib::Response& res) {
        res.status = 204;
    });
    
    // SSE Stream
    svr.Get("/events", [&](const httplib::Request& req, httplib::Response& res) {
        res.set_header("Content-Type", "text/event-stream");
        res.set_header("Cache-Control", "no-cache");
        res.set_header("Connection", "keep-alive");
        
        auto queue = std::make_shared<SafeQueue<std::string>>();
        {
            std::lock_guard<std::mutex> lock(g_clients_mutex);
            g_client_queues.push_back(queue);
        }
        
        // Push current status immediately on connect
        nlohmann::json init_status = {
            {"type", "status"},
            {"status", g_is_running ? "started" : "stopped"}
        };
        queue->push(init_status.dump());
        
        res.set_content_provider(
            "text/event-stream",
            [queue](size_t offset, httplib::DataSink &sink) {
                if (!sink.is_writable()) {
                    return false;
                }
                std::string msg;
                if (queue->pop(msg, std::chrono::milliseconds(200))) {
                    std::string frame = "data: " + msg + "\n\n";
                    if (!sink.write(frame.data(), frame.size())) {
                        return false;
                    }
                } else {
                    std::string frame = ": ping\n\n";
                    if (!sink.write(frame.data(), frame.size())) {
                        return false;
                    }
                }
                return true;
            },
            [queue](bool success) {
                std::lock_guard<std::mutex> lock(g_clients_mutex);
                g_client_queues.erase(std::remove(g_client_queues.begin(), g_client_queues.end(), queue), g_client_queues.end());
            }
        );
    });
    
    // HTTP API Endpoints
    svr.Get("/api/script", [&](const httplib::Request& req, httplib::Response& res) {
        std::lock_guard<std::mutex> lock(g_script_mutex);
        nlohmann::json data = {
            {"script", g_script_text},
            {"words", g_script_words},
            {"script_index", g_script_index},
            {"threshold", g_script_threshold}
        };
        res.set_content(data.dump(), "application/json");
    });
    
    svr.Post("/api/script", [&](const httplib::Request& req, httplib::Response& res) {
        nlohmann::json body;
        try {
            body = nlohmann::json::parse(req.body);
        } catch(...) {
            res.status = 400;
            res.set_content("{\"error\":\"Invalid JSON\"}", "application/json");
            return;
        }
        
        std::string new_script = body.value("script", "");
        {
            std::lock_guard<std::mutex> lock(g_script_mutex);
            g_script_text = new_script;
            g_script_words = tokenize_words(new_script);
            g_script_index = 0;
        }
        
        nlohmann::json response = {
            {"success", true},
            {"word_count", g_script_words.size()}
        };
        
        nlohmann::json reset_packet = {
            {"type", "script_reset"},
            {"script", g_script_text},
            {"words", g_script_words},
            {"threshold", g_script_threshold}
        };
        broadcast_to_sse(reset_packet.dump());
        
        res.set_content(response.dump(), "application/json");
    });
    
    svr.Post("/api/set_threshold", [&](const httplib::Request& req, httplib::Response& res) {
        nlohmann::json body;
        try {
            body = nlohmann::json::parse(req.body);
        } catch(...) {
            res.status = 400;
            res.set_content("{\"error\":\"Invalid JSON\"}", "application/json");
            return;
        }
        
        double th = body.value("threshold", 0.7);
        {
            std::lock_guard<std::mutex> lock(g_script_mutex);
            g_script_threshold = th;
        }
        
        nlohmann::json response = {
            {"success", true},
            {"threshold", g_script_threshold}
        };
        res.set_content(response.dump(), "application/json");
    });
    
    svr.Post("/api/reset_script", [&](const httplib::Request& req, httplib::Response& res) {
        {
            std::lock_guard<std::mutex> lock(g_script_mutex);
            g_script_index = 0;
        }
        nlohmann::json response = {{"success", true}};
        
        nlohmann::json reset_packet = {
            {"type", "script_reset"},
            {"script", g_script_text},
            {"words", g_script_words},
            {"threshold", g_script_threshold}
        };
        broadcast_to_sse(reset_packet.dump());
        
        res.set_content(response.dump(), "application/json");
    });

    svr.Get("/api/status", [&](const httplib::Request& req, httplib::Response& res) {
        nlohmann::json status = {
            {"status", g_is_running ? "started" : "stopped"}
        };
        res.set_content(status.dump(), "application/json");
    });
    
    svr.Post("/api/start", [&](const httplib::Request& req, httplib::Response& res) {
        std::string override_llm = "";
        std::string override_labels = "";
        try {
            if (!req.body.empty()) {
                auto body = nlohmann::json::parse(req.body);
                override_llm = body.value("llm", "");
                override_labels = body.value("labels", "");
            }
        } catch (...) {}
        
        bool success = start_processes(override_llm, override_labels);
        nlohmann::json status = {
            {"success", success},
            {"status", g_is_running ? "started" : "stopped"}
        };
        res.set_content(status.dump(), "application/json");
    });
    
    svr.Post("/api/stop", [&](const httplib::Request& req, httplib::Response& res) {
        stop_processes();
        nlohmann::json status = {
            {"success", true},
            {"status", "stopped"}
        };
        res.set_content(status.dump(), "application/json");
    });
    
    std::cerr << "Brain C++ Server: Web Dashboard hosted at http://localhost:" << g_args.http_port << std::endl;
    
    // Bind and listen
    svr.listen("0.0.0.0", g_args.http_port);
    
    // Shut down gracefully on exit
    stop_processes();
    return 0;
}
