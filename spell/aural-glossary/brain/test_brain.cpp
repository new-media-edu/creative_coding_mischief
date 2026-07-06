#include <iostream>
#include <cassert>
#include <vector>
#include <string>
#include <thread>
#include "brain_core.h"

void test_trim() {
    assert(trim("   hello   ") == "hello");
    assert(trim("\n\r hello world \t") == "hello world");
    assert(trim("   ") == "");
    assert(trim("") == "");
    std::cout << "test_trim passed!\n";
}

void test_parse_args() {
    std::vector<std::string> args_vec = {
        "./aural-glossary-brain",
        "--whisper-bin", "my_whisper",
        "--whisper-model", "my_model.bin",
        "--whisper-device", "3",
        "--engine-b-window", "8.5",
        "--llm", "gemini",
        "--api-key", "my_secret_key",
        "--auto-start"
    };
    
    std::vector<char*> argv;
    for (auto& arg : args_vec) {
        argv.push_back(const_cast<char*>(arg.c_str()));
    }
    
    AppArgs parsed = parse_args(argv.size(), argv.data());
    
    assert(parsed.whisper_bin == "my_whisper");
    assert(parsed.whisper_model == "my_model.bin");
    assert(parsed.whisper_device == 3);
    assert(parsed.engine_b_window == 8.5);
    assert(parsed.llm == "gemini");
    assert(parsed.api_key == "my_secret_key");
    assert(parsed.auto_start == true);
    
    std::cout << "test_parse_args passed!\n";
}

void test_generate_mock_story() {
    std::string dialogue1 = "- \"hello world\" (confidence: 0.95)";
    std::string features1 = "- Character/Identity (CLAP zero-shot tags): heavy thud, impact or drum beat (85.2%)";
    
    std::string story1 = generate_mock_story(dialogue1, features1);
    assert(story1.find("hello world") != std::string::npos);
    assert(story1.find("deep, rhythmic pulse") != std::string::npos);
    
    std::string dialogue2 = "(No dialogue captured recently)";
    std::string features2 = "- Character/Identity (CLAP zero-shot tags): loud distorted drone or static noise (91.0%)";
    
    std::string story2 = generate_mock_story(dialogue2, features2);
    assert(story2.find("murmur") == std::string::npos);
    assert(story2.find("thick, dark cloud of static vibration") != std::string::npos);
    
    std::cout << "test_generate_mock_story passed!\n";
}

void test_safe_queue() {
    SafeQueue<int> q;
    
    // Test basic push and pop
    q.push(42);
    int val = 0;
    bool popped = q.pop(val, std::chrono::milliseconds(100));
    assert(popped);
    assert(val == 42);
    
    // Test timeout
    popped = q.pop(val, std::chrono::milliseconds(50));
    assert(!popped);
    
    // Test concurrent pushes and pops
    std::thread t1([&]() {
        for (int i = 0; i < 100; ++i) {
            q.push(i);
        }
    });
    
    std::thread t2([&]() {
        int expected = 0;
        for (int i = 0; i < 100; ++i) {
            int v = -1;
            while (!q.pop(v, std::chrono::milliseconds(10))) {}
            assert(v >= 0 && v < 100);
        }
    });
    
    t1.join();
    t2.join();
    
    std::cout << "test_safe_queue passed!\n";
}

int main() {
    std::cout << "Running C++ Brain Unit Tests...\n";
    test_trim();
    test_parse_args();
    test_generate_mock_story();
    test_safe_queue();
    std::cout << "All C++ Brain Unit Tests Passed Successfully!\n";
    return 0;
}
