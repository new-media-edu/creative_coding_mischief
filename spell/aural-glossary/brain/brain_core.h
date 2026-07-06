#pragma once

#include <string>
#include <vector>
#include <queue>
#include <mutex>
#include <condition_variable>
#include <chrono>
#include <fstream>
#include <sstream>
#include <map>
#include <algorithm>
#include <cctype>
#include <cstring>
#include <cstdlib>
#include <iostream>

#include "json.hpp"

// Thread-safe Queue helper for SSE clients
template <typename T>
class SafeQueue {
private:
    std::queue<T> q;
    std::mutex m;
    std::condition_variable cv;
public:
    void push(T val) {
        std::lock_guard<std::mutex> lock(m);
        q.push(val);
        cv.notify_one();
    }
    
    bool pop(T& val, std::chrono::milliseconds timeout) {
        std::unique_lock<std::mutex> lock(m);
        if (cv.wait_for(lock, timeout, [this] { return !q.empty(); })) {
            val = std::move(q.front());
            q.pop();
            return true;
        }
        return false;
    }
    
    void clear() {
        std::lock_guard<std::mutex> lock(m);
        std::queue<T> empty;
        std::swap(q, empty);
    }
};

struct AppArgs {
    std::string whisper_bin = "aural-glossary/engine_a/whisper.cpp/build/bin/whisper-stream";
    std::string whisper_model = "aural-glossary/engine_a/whisper.cpp/models/ggml-tiny.en.bin";
    int whisper_device = -1;
    std::string engine_b_script = "aural-glossary/engine_b/engine_b.py";
    double engine_b_window = 5.0;
    double engine_b_step = 2.0;
    int engine_b_device = -1;
    std::string engine_b_labels = "";
    double interval = 5.0;
    std::string llm = "mock";
    std::string ollama_model = "llama3";
    std::string ollama_url = "http://localhost:11434";
    std::string gemini_model = "gemini-2.5-flash";
    std::string api_key = "";
    std::string context_file = "";
    std::string output_osc_ip = "";
    int output_osc_port = 7772;
    int http_port = 8080;
    bool auto_start = false;
};

// Helper to get time in seconds
inline double get_time_seconds() {
    auto now = std::chrono::system_clock::now();
    auto duration = now.time_since_epoch();
    return std::chrono::duration<double>(duration).count();
}

// Trim whitespace
inline std::string trim(const std::string& str) {
    size_t first = str.find_first_not_of(" \t\r\n");
    if (first == std::string::npos) return "";
    size_t last = str.find_last_not_of(" \t\r\n");
    return str.substr(first, (last - first + 1));
}

// Tokenize text into normalized lowercase alphanumeric words
inline std::vector<std::string> tokenize_words(const std::string& text) {
    std::vector<std::string> words;
    std::string current;
    for (char c : text) {
        if (std::isalnum(static_cast<unsigned char>(c))) {
            current += std::tolower(static_cast<unsigned char>(c));
        } else if (std::isspace(static_cast<unsigned char>(c)) || std::ispunct(static_cast<unsigned char>(c))) {
            if (!current.empty()) {
                words.push_back(current);
                current.clear();
            }
        }
    }
    if (!current.empty()) {
        words.push_back(current);
    }
    return words;
}

// Calculate Levenshtein edit distance between two word sequences
inline int get_edit_distance(const std::vector<std::string>& a, const std::vector<std::string>& b) {
    int n = a.size();
    int m = b.size();
    if (n == 0) return m;
    if (m == 0) return n;
    
    std::vector<std::vector<int>> dp(n + 1, std::vector<int>(m + 1, 0));
    for (int i = 0; i <= n; ++i) dp[i][0] = i;
    for (int j = 0; j <= m; ++j) dp[0][j] = j;
    
    for (int i = 1; i <= n; ++i) {
        for (int j = 1; j <= m; ++j) {
            int cost = (a[i - 1] == b[j - 1]) ? 0 : 1;
            dp[i][j] = std::min({
                dp[i - 1][j] + 1,
                dp[i][j - 1] + 1,
                dp[i - 1][j - 1] + cost
            });
        }
    }
    return dp[n][m];
}

// Calculate similarity ratio
inline double get_similarity(const std::vector<std::string>& a, const std::vector<std::string>& b) {
    int max_len = std::max(a.size(), b.size());
    if (max_len == 0) return 1.0;
    int dist = get_edit_distance(a, b);
    return 1.0 - static_cast<double>(dist) / max_len;
}

struct MatchResult {
    int best_offset = 0;
    int best_len = 0;
    double best_similarity = 0.0;
};

// Locate best alignment window for transcribed text in the script
inline MatchResult find_best_match(const std::vector<std::string>& script, int current_idx, const std::vector<std::string>& transcribed, double threshold) {
    MatchResult res;
    if (transcribed.empty()) return res;
    
    int t_size = transcribed.size();
    
    // 1. Scan locally (offset -5 to 15)
    for (int offset = -5; offset <= 15; ++offset) {
        int start_idx = current_idx + offset;
        if (start_idx < 0 || start_idx >= (int)script.size()) continue;
        
        for (int len = std::max(1, t_size - 3); len <= t_size + 3; ++len) {
            if (start_idx + len > (int)script.size()) continue;
            
            std::vector<std::string> slice(script.begin() + start_idx, script.begin() + start_idx + len);
            double sim = get_similarity(transcribed, slice);
            if (sim > res.best_similarity) {
                res.best_similarity = sim;
                res.best_offset = offset;
                res.best_len = len;
            }
        }
    }
    
    // 2. Recovery search: scan up to 100 words ahead if local match fails
    if (res.best_similarity < threshold) {
        for (int offset = 16; offset <= 100; ++offset) {
            int start_idx = current_idx + offset;
            if (start_idx + t_size > (int)script.size()) break;
            
            std::vector<std::string> slice(script.begin() + start_idx, script.begin() + start_idx + t_size);
            double sim = get_similarity(transcribed, slice);
            if (sim > res.best_similarity && sim >= threshold) {
                res.best_similarity = sim;
                res.best_offset = offset;
                res.best_len = t_size;
            }
        }
    }
    
    return res;
}

// Generate Mock Story
inline std::string generate_mock_story(const std::string& dialogue, const std::string& features) {
    std::string dialogue_snippet = "";
    if (dialogue.find("No dialogue captured") == std::string::npos) {
        size_t last_quote = dialogue.rfind('"');
        if (last_quote != std::string::npos && last_quote > 0) {
            size_t prev_quote = dialogue.rfind('"', last_quote - 1);
            if (prev_quote != std::string::npos) {
                std::string line = dialogue.substr(prev_quote + 1, last_quote - prev_quote - 1);
                dialogue_snippet = "a voice murmuring \"" + line + "\"";
            }
        }
    }
    
    std::string sound_desc = "a quiet, suspended stillness settles over the room";
    
    if (features.find("drone") != std::string::npos || features.find("noise") != std::string::npos) {
        sound_desc = "a thick, dark cloud of static vibration hangs heavily in the air";
    } else if (features.find("thud") != std::string::npos || features.find("beat") != std::string::npos) {
        sound_desc = "a deep, rhythmic pulse thrums in the chest, steady and low";
    } else if (features.find("music") != std::string::npos || features.find("melodic") != std::string::npos) {
        sound_desc = "bright, warm harmonic waves drift and swell gracefully";
    } else if (features.find("speaking") != std::string::npos || features.find("talking") != std::string::npos) {
        sound_desc = "the clear articulation of speech dominates the foreground";
    } else if (features.find("vocals") != std::string::npos || features.find("singing") != std::string::npos) {
        sound_desc = "a resonant voice soaring above, filling the acoustic space";
    } else if (features.find("silence") != std::string::npos || features.find("quiet") != std::string::npos) {
        sound_desc = "the atmosphere drops into a profound, breathless hush";
    } else if (features.find("ambient") != std::string::npos || features.find("synth") != std::string::npos) {
        sound_desc = "a shimmering, nebulous texture floats and shivers in the background";
    } else if (features.find("laughter") != std::string::npos || features.find("giggling") != std::string::npos) {
        sound_desc = "sparks of warm, fluttering human chatter and giggles burst through";
    } else if (features.find("screaming") != std::string::npos || features.find("shout") != std::string::npos) {
        sound_desc = "a sharp, piercing tear of sound splits the air, tense and sudden";
    } else if (features.find("animal") != std::string::npos || features.find("chicken") != std::string::npos) {
        sound_desc = "a rustic, unexpected animal cackle breaks the sonic field";
    }
    
    if (!dialogue_snippet.empty()) {
        return "Underneath " + dialogue_snippet + ", " + sound_desc + ".";
    } else {
        std::string upper_desc = sound_desc;
        if (!upper_desc.empty()) upper_desc[0] = toupper(upper_desc[0]);
        return upper_desc + ".";
    }
}

// Parse Command Line Args
inline AppArgs parse_args(int argc, char* argv[]) {
    AppArgs args;
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--whisper-bin" && i + 1 < argc) {
            args.whisper_bin = argv[++i];
        } else if (arg == "--whisper-model" && i + 1 < argc) {
            args.whisper_model = argv[++i];
        } else if (arg == "--whisper-device" && i + 1 < argc) {
            args.whisper_device = std::stoi(argv[++i]);
        } else if (arg == "--engine-b-script" && i + 1 < argc) {
            args.engine_b_script = argv[++i];
        } else if (arg == "--engine-b-window" && i + 1 < argc) {
            args.engine_b_window = std::stod(argv[++i]);
        } else if (arg == "--engine-b-step" && i + 1 < argc) {
            args.engine_b_step = std::stod(argv[++i]);
        } else if (arg == "--engine-b-device" && i + 1 < argc) {
            args.engine_b_device = std::stoi(argv[++i]);
        } else if (arg == "--engine-b-labels" && i + 1 < argc) {
            args.engine_b_labels = argv[++i];
        } else if (arg == "--interval" && i + 1 < argc) {
            args.interval = std::stod(argv[++i]);
        } else if (arg == "--llm" && i + 1 < argc) {
            args.llm = argv[++i];
        } else if (arg == "--ollama-model" && i + 1 < argc) {
            args.ollama_model = argv[++i];
        } else if (arg == "--ollama-url" && i + 1 < argc) {
            args.ollama_url = argv[++i];
        } else if (arg == "--gemini-model" && i + 1 < argc) {
            args.gemini_model = argv[++i];
        } else if (arg == "--api-key" && i + 1 < argc) {
            args.api_key = argv[++i];
        } else if (arg == "--context-file" && i + 1 < argc) {
            args.context_file = argv[++i];
        } else if (arg == "--output-osc-ip" && i + 1 < argc) {
            args.output_osc_ip = argv[++i];
        } else if (arg == "--output-osc-port" && i + 1 < argc) {
            args.output_osc_port = std::stoi(argv[++i]);
        } else if (arg == "--http-port" && i + 1 < argc) {
            args.http_port = std::stoi(argv[++i]);
        } else if (arg == "--auto-start") {
            args.auto_start = true;
        }
    }
    return args;
}

// Load performance context
inline std::string load_context_file(const std::string& path) {
    if (path.empty() || !std::ifstream(path).good()) {
        return 
            "AURAL GLOSSARY STYLE AND VOCABULARY GUIDELINES:\n"
            "- Focus on synesthetic descriptions (e.g. colors, textures, physical sensations).\n"
            "- Avoid technical words like \"Centroid\", \"RMS\", \"Decibels\", \"BPM\", \"classifier\".\n"
            "- Describe the spatial and qualitative character of sound.\n"
            "- Keep descriptions evocative, non-normative, and brief (1-2 sentences).";
    }
    try {
        std::ifstream f(path);
        std::stringstream buffer;
        buffer << f.rdbuf();
        std::string content = buffer.str();
        if (path.rfind(".json") != std::string::npos) {
            auto j = nlohmann::json::parse(content);
            return j.dump(2);
        }
        return content;
    } catch (std::exception& e) {
        std::cerr << "Brain C++: Error loading context file: " << e.what() << "\n";
    }
    return "";
}
