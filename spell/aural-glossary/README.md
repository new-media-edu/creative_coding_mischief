# Aural Glossary

Applied Sound and Music Computing for Radical Accessibility.

**Aural Glossary** is a live, AI-driven captioning and translation ecosystem designed to describe the synesthetic and qualitative parameters of sound. Moving beyond utilitarian automatic speech recognition (ASR) and generic captions like `[dramatic music playing]`, this project develops a non-normative, community-driven sensory description language for deaf and aural-diverse audiences.

---

## 1. System Architecture

The ecosystem consists of three decoupled components coordinating over local network and process pipes:

```
                  ┌────────────────────────────────────────┐
                  │              Audio Input               │
                  └──────┬──────────────────────────┬──────┘
                         │ 16kHz PCM                │ 44.1kHz PCM
                         ▼                          ▼
               ┌───────────────────┐      ┌───────────────────┐
               │     Engine A      │      │     Engine B      │
               │   Whisper (C++)   │      │  CLAP & DSP (Py)  │
               └─────────┬─────────┘      └─────────┬─────────┘
                         │ Dialogue                 │ DSP & Tags
                         └───────────┬──────────────┘
                                     ▼
                        ┌─────────────────────────┐
                        │    Brain Orchestrator   │
                        │          (C++)          │
                        └────────────┬────────────┘
                                     │ Query
                                     ▼
                            ┌─────────────────┐
                            │    Local/API    │
                            │       LLM       │
                            └────────┬────────┘
                                     │ Sensory Narrative
                                     ▼
                         ┌───────────────────────┐
                         │   Web browser / UI    │
                         │   OSC / Teleprompter  │
                         └───────────────────────┘
```

1. **Engine A (C++ Whisper)**: Real-time, offline audio transcription using `whisper.cpp`, optimized for low latency and high CPU portability. Produces dialogue text and confidence scores.
2. **Engine B (Python DSP + CLAP)**: Extracts loudness (RMS), brightness (Spectral Centroid), and tempo, and runs zero-shot audio classification against custom sound taxonomies using Contrastive Language-Audio Pretraining (CLAP).
3. **The Brain (C++ Orchestrator)**: Spawns and manages Engine A and Engine B as subprocesses, handles rolling window buffers, coordinates queries to local LLMs (Ollama) or cloud APIs (Gemini), serves the web UI static files, and streams live telemetry via Server-Sent Events (SSE).

---

## 2. Compilation and Setup

### Prerequisites

All compilation tools, Python dependencies, and runtime libraries are managed using a local `micromamba` virtual environment located at `.mamba-env` and `.venv`.

To compile the C++ binaries:
1. Ensure the conda environment is active.
2. Target the local compilers in your build commands.

### Build Engine A (Whisper.cpp)

Build the customized whisper stream command line:
```bash
# Configure CMake for whisper.cpp
./bin/micromamba run -n .mamba-env cmake -B aural-glossary/engine_a/whisper.cpp/build -S aural-glossary/engine_a/whisper.cpp -DCMAKE_BUILD_TYPE=Release

# Build whisper-stream binary
./bin/micromamba run -n .mamba-env cmake --build aural-glossary/engine_a/whisper.cpp/build --config Release
```

### Build The Brain (C++ Orchestrator)

Build the main orchestrator program and its unit tests:
```bash
# Configure CMake for the brain
./bin/micromamba run -n .mamba-env cmake -B aural-glossary/brain/build -S aural-glossary/brain -DCMAKE_BUILD_TYPE=Release

# Build brain executable and test suite
./bin/micromamba run -n .mamba-env cmake --build aural-glossary/brain/build --config Release
```

---

## 3. Running the System

To run the unified C++ app (which hosts the dashboard and runs both capturing pipelines):
```bash
./aural-glossary/brain/build/aural-glossary-brain [flags]
```

### Supported Flags

| Flag | Type | Default | Description |
|:---|:---|:---|:---|
| `--whisper-bin` | string | `aural-glossary/engine_a/whisper.cpp/build/bin/whisper-stream` | Path to whisper-stream binary |
| `--whisper-model` | string | `aural-glossary/engine_a/whisper.cpp/models/ggml-tiny.en.bin` | Path to whisper ggml weights |
| `--whisper-device` | int | `-1` | Whisper audio capture device index |
| `--engine-b-script` | string | `aural-glossary/engine_b/engine_b.py` | Path to Engine B python analyzer |
| `--engine-b-window` | float | `5.0` | Analysis window length in seconds |
| `--engine-b-step` | float | `2.0` | Analysis step rate in seconds |
| `--engine-b-device` | int | `-1` | Engine B audio capture device index |
| `--engine-b-labels` | string | `""` | Comma-separated zero-shot classification labels |
| `--interval` | float | `5.0` | Story narration update interval (sec) |
| `--llm` | string | `mock` | LLM service: `mock`, `gemini`, `ollama` |
| `--ollama-model` | string | `llama3` | Ollama model name |
| `--ollama-url` | string | `http://localhost:11434` | Local Ollama port endpoint |
| `--gemini-model` | string | `gemini-2.5-flash` | Gemini model name |
| `--api-key` | string | `""` | Gemini API Key (or export `GEMINI_API_KEY`) |
| `--context-file` | string | `""` | Vocabulary, genre, and track details |
| `--output-osc-ip` | string | `""` | Target IP address for OSC output |
| `--output-osc-port`| int | `7772` | Target Port for OSC output |
| `--http-port` | int | `8080` | Local HTTP Web Dashboard port |
| `--auto-start` | none | (false) | Automatically run Engines on startup |

Open a browser window to `http://localhost:8080` to access the Control Dashboard and view live metrics, transcription streams, CLAP probabilities, and sensory narratives.

---

## 4. Test Suites

The codebase is backed by Python and C++ test suites ensuring 80%+ test coverage.

### Run C++ Tests
```bash
./aural-glossary/brain/build/test_brain
```

### Run Python Tests
```bash
LD_LIBRARY_PATH=/home/grayson/.local/share/mamba/envs/.mamba-env/lib ./.venv/bin/python3 -m unittest aural-glossary/tests/test_aural_glossary.py
```
*(Requires `LD_LIBRARY_PATH` prepended to resolve `PortAudio` libraries inside the conda virtual environment.)*
