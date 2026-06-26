#!/usr/bin/env python3
import os
import sys
import time
import json
import subprocess
import threading
import queue
import argparse
import requests
import http.server
import socketserver
import asyncio
import websockets

# Force PortAudio lib path if LD_LIBRARY_PATH isn't set
if "LD_LIBRARY_PATH" not in os.environ:
    os.environ["LD_LIBRARY_PATH"] = "/home/grayson/.local/share/mamba/envs/.mamba-env/lib"

class BrainOrchestrator:
    def __init__(self, args):
        self.args = args
        self.event_queue = queue.Queue()
        self.transcriptions = []  # sliding window of dicts: {"text": "...", "confidence": 0.9, "start_ms": 0, "end_ms": 1000}
        self.analysis_packets = []  # sliding window of dicts: {"rms": 0.05, "centroid": 1500.0, "labels": {...}}
        
        self.transcription_lock = threading.Lock()
        self.analysis_lock = threading.Lock()
        self.process_lock = threading.Lock()
        
        self.proc_a = None
        self.proc_b = None
        self.is_running = False
        
        self.ws_clients = set()
        self.ws_loop = None
        
        self.context_info = ""
        self._load_context_file()

        # OSC client for streaming LLM story output
        self.osc_client = None
        if args.output_osc_ip:
            try:
                from pythonosc import udp_client
                self.osc_client = udp_client.SimpleUDPClient(args.output_osc_ip, args.output_osc_port)
                print(f"Brain: OSC output enabled to {args.output_osc_ip}:{args.output_osc_port}", file=sys.stderr)
            except ImportError:
                print("python-osc is not installed. OSC output disabled.", file=sys.stderr)

    def _load_context_file(self):
        if self.args.context_file and os.path.exists(self.args.context_file):
            try:
                with open(self.args.context_file, "r") as f:
                    content = f.read()
                    if self.args.context_file.endswith(".json"):
                        data = json.loads(content)
                        self.context_info = json.dumps(data, indent=2)
                    else:
                        self.context_info = content
                print(f"Brain: Loaded context file: {self.args.context_file}", file=sys.stderr)
            except Exception as e:
                print(f"Brain: Error reading context file: {e}", file=sys.stderr)
        else:
            self.context_info = """
            AURAL GLOSSARY STYLE AND VOCABULARY GUIDELINES:
            - Focus on synesthetic descriptions (e.g. colors, textures, physical sensations).
            - Avoid technical words like "Centroid", "RMS", "Decibels", "BPM", "classifier".
            - Describe the spatial and qualitative character of sound.
            - Keep descriptions evocative, non-normative, and brief (1-2 sentences).
            """

    def start_processes(self, llm=None, labels=None):
        with self.process_lock:
            if self.is_running:
                return
            
            if llm:
                self.args.llm = llm
            if labels:
                self.args.engine_b_labels = labels

            # Spawn Engine A (C++ Whisper)
            whisper_cmd = [
                self.args.whisper_bin,
                "-m", self.args.whisper_model,
                "--json"
            ]
            if self.args.whisper_device is not None:
                whisper_cmd.extend(["-c", str(self.args.whisper_device)])

            print(f"Brain: Starting Engine A: {' '.join(whisper_cmd)}", file=sys.stderr)
            try:
                self.proc_a = subprocess.Popen(
                    whisper_cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    bufsize=1
                )
            except Exception as e:
                print(f"Brain: Failed to start Engine A: {e}", file=sys.stderr)
                return

            # Spawn Engine B (Python CLAP & DSP)
            engine_b_cmd = [
                sys.executable,
                self.args.engine_b_script,
                "--window", str(self.args.engine_b_window),
                "--step", str(self.args.engine_b_step)
            ]
            if self.args.engine_b_device is not None:
                engine_b_cmd.extend(["--device", str(self.args.engine_b_device)])
            if self.args.engine_b_labels:
                engine_b_cmd.extend(["--labels", self.args.engine_b_labels])

            print(f"Brain: Starting Engine B: {' '.join(engine_b_cmd)}", file=sys.stderr)
            try:
                env = os.environ.copy()
                env["LD_LIBRARY_PATH"] = "/home/grayson/.local/share/mamba/envs/.mamba-env/lib"
                self.proc_b = subprocess.Popen(
                    engine_b_cmd,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.PIPE,
                    text=True,
                    bufsize=1,
                    env=env
                )
            except Exception as e:
                print(f"Brain: Failed to start Engine B: {e}", file=sys.stderr)
                if self.proc_a:
                    self.proc_a.terminate()
                return

            self.is_running = True

            # Start stdout reader threads
            self.thread_a = threading.Thread(target=self._reader_loop, args=(self.proc_a, "engine-a"), daemon=True)
            self.thread_b = threading.Thread(target=self._reader_loop, args=(self.proc_b, "engine-b"), daemon=True)
            
            # Start stderr logging threads
            self.err_thread_a = threading.Thread(target=self._logging_loop, args=(self.proc_a.stderr, "[Engine A Stderr]"), daemon=True)
            self.err_thread_b = threading.Thread(target=self._logging_loop, args=(self.proc_b.stderr, "[Engine B Stderr]"), daemon=True)

            self.thread_a.start()
            self.thread_b.start()
            self.err_thread_a.start()
            self.err_thread_b.start()
            
            self.broadcast(json.dumps({"type": "status", "status": "started"}))

    def stop_processes(self):
        with self.process_lock:
            if not self.is_running:
                return
            
            print("Brain: Stopping backend engines...", file=sys.stderr)
            if self.proc_a:
                self.proc_a.terminate()
                self.proc_a = None
            if self.proc_b:
                self.proc_b.terminate()
                self.proc_b = None
                
            self.is_running = False
            
            # Clear buffers
            with self.transcription_lock:
                self.transcriptions.clear()
            with self.analysis_lock:
                self.analysis_packets.clear()

            self.broadcast(json.dumps({"type": "status", "status": "stopped"}))

    def _reader_loop(self, proc, name):
        for line in iter(proc.stdout.readline, ''):
            if not line:
                break
            line = line.strip()
            if line:
                try:
                    packet = json.loads(line)
                    # Forward packet directly to all connected WebSockets
                    self.broadcast(line)
                    # Queue locally for LLM sliding window
                    self.event_queue.put((name, packet))
                except json.JSONDecodeError:
                    pass
        proc.stdout.close()

    def _logging_loop(self, pipe, prefix):
        for line in iter(pipe.readline, ''):
            if not line:
                break
            line = line.strip()
            if line:
                print(f"{prefix} {line}", file=sys.stderr)
        pipe.close()

    def update_buffers(self):
        while not self.event_queue.empty():
            try:
                name, packet = self.event_queue.get_nowait()
                if name == "engine-a":
                    if packet.get("type") == "transcription":
                        with self.transcription_lock:
                            self.transcriptions.append({
                                "text": packet.get("text", "").strip(),
                                "confidence": packet.get("confidence", 0.0),
                                "start_ms": packet.get("start_ms", 0),
                                "end_ms": packet.get("end_ms", 0),
                                "time": time.time()
                            })
                            if len(self.transcriptions) > 10:
                                self.transcriptions.pop(0)
                elif name == "engine-b":
                    if packet.get("type") == "analysis":
                        with self.analysis_lock:
                            self.analysis_packets.append({
                                "rms": packet.get("rms", 0.0),
                                "centroid": packet.get("centroid", 0.0),
                                "zcr": packet.get("zcr", 0.0),
                                "tempo": packet.get("tempo", 0.0),
                                "labels": packet.get("labels", {}),
                                "time": time.time()
                            })
                            cutoff = time.time() - 20
                            self.analysis_packets = [p for p in self.analysis_packets if p["time"] > cutoff]
            except queue.Empty:
                break

    def get_summary_context(self):
        with self.transcription_lock:
            cutoff_t = time.time() - 60
            recent_trans = [t for t in self.transcriptions if t["time"] > cutoff_t]
            dialogue_text = "\n".join([f'- "{t["text"]}" (confidence: {t["confidence"]:.2f})' for t in recent_trans])
            if not dialogue_text:
                dialogue_text = "(No dialogue captured recently)"

        with self.analysis_lock:
            if not self.analysis_packets:
                return dialogue_text, "(No audio analysis data available)"
            
            avg_rms = sum(p["rms"] for p in self.analysis_packets) / len(self.analysis_packets)
            avg_centroid = sum(p["centroid"] for p in self.analysis_packets) / len(self.analysis_packets)
            avg_tempo = sum(p["tempo"] for p in self.analysis_packets) / len(self.analysis_packets)
            
            label_sums = {}
            for p in self.analysis_packets:
                for label, prob in p["labels"].items():
                    label_sums[label] = label_sums.get(label, 0.0) + prob
            
            avg_labels = {label: total / len(self.analysis_packets) for label, total in label_sums.items()}
            detected = [f"{label} ({prob:.2%})" for label, prob in avg_labels.items() if prob > 0.15]
            detected_str = ", ".join(detected) if detected else "no distinct sound patterns detected"

        features_summary = f"""
        - Loudness (RMS): {avg_rms:.4f} (0.0 is silent, 0.2+ is loud)
        - Brightness (Spectral Centroid): {avg_centroid:.1f} Hz (low is dark/muffled, high is bright/harsh)
        - Rhythmic Speed (Tempo): {avg_tempo:.1f} BPM
        - Character/Identity (CLAP zero-shot tags): {detected_str}
        """
        return dialogue_text, features_summary

    def query_llm(self, dialogue, features):
        prompt = f"""
You are "Aural Glossary", a live AI-driven captioning and translation engine designed to describe the qualitative and synesthetic parameters of sound for deaf and aural-diverse audiences.

{self.context_info}

Here is the recent audio analysis and dialogue from the last few seconds:

=== RECENT AUDIO ANALYSIS & FEATURES ===
{features}

=== RECENT SPOKEN DIALOGUE / LYRICS ===
{dialogue}

=== MISSION ===
Generate a brief, evocative, synesthetic description (1 to 2 sentences) of the current soundscape for the live audience teleprompter.
- Describe the qualitative feeling, movement, or texture of the sound.
- Integrate the spoken dialogue if it exists, explaining its acoustic context (e.g. "spoken clearly", "muffled whispers", "vocals rising over a drone").
- DO NOT use technical terms like "RMS", "BPM", "Centroid", "CLAP", or "Hz".
- DO NOT use prefixes or headers like "Aural Glossary:" or "Description:". Output ONLY the description itself.
"""

        if self.args.llm == "mock":
            return self._generate_mock_story(dialogue, features)
            
        elif self.args.llm == "gemini":
            api_key = self.args.api_key or os.environ.get("GEMINI_API_KEY")
            if not api_key:
                print("Brain: Gemini LLM selected but no API key provided. Falling back to mock LLM.", file=sys.stderr)
                return self._generate_mock_story(dialogue, features)
            
            url = f"https://generativelanguage.googleapis.com/v1beta/models/{self.args.gemini_model}:generateContent?key={api_key}"
            payload = {
                "contents": [{"parts": [{"text": prompt}]}]
            }
            try:
                res = requests.post(url, json=payload, timeout=10)
                res_data = res.json()
                story = res_data["candidates"][0]["content"]["parts"][0]["text"].strip()
                return story
            except Exception as e:
                print(f"Brain: Gemini API error: {e}. Falling back to mock LLM.", file=sys.stderr)
                return self._generate_mock_story(dialogue, features)
                
        elif self.args.llm == "ollama":
            url = f"{self.args.ollama_url}/api/generate"
            payload = {
                "model": self.args.ollama_model,
                "prompt": prompt,
                "stream": False,
                "options": {
                    "temperature": 0.7,
                    "num_predict": 100
                }
            }
            try:
                res = requests.post(url, json=payload, timeout=15)
                res_data = res.json()
                story = res_data["response"].strip()
                return story
            except Exception as e:
                print(f"Brain: Ollama error: {e}. Falling back to mock LLM.", file=sys.stderr)
                return self._generate_mock_story(dialogue, features)

        return "[Unsupported LLM type]"

    def _generate_mock_story(self, dialogue, features):
        dialogue_snippet = ""
        if "No dialogue captured" not in dialogue:
            lines = [line.strip("- \" ") for line in dialogue.split("\n") if line.strip()]
            if lines:
                last_line = lines[-1].split('" (confidence:')[0].strip('"')
                dialogue_snippet = f'a voice murmuring "{last_line}"'

        sound_desc = "a quiet, suspended stillness settles over the room"
        
        top_tag = ""
        if "zero-shot tags):" in features:
            tag_part = features.split("zero-shot tags):")[1].strip()
            if tag_part and "no distinct" not in tag_part:
                first_tag = tag_part.split(",")[0]
                top_tag = first_tag.split("(")[0].strip()

        if top_tag:
            if "drone" in top_tag or "noise" in top_tag:
                sound_desc = "a thick, dark cloud of static vibration hangs heavily in the air"
            elif "thud" in top_tag or "beat" in top_tag:
                sound_desc = "a deep, rhythmic pulse thrums in the chest, steady and low"
            elif "music" in top_tag or "melodic" in top_tag:
                sound_desc = "bright, warm harmonic waves drift and swell gracefully"
            elif "speaking" in top_tag or "talking" in top_tag:
                sound_desc = "the clear articulation of speech dominates the foreground"
            elif "vocals" in top_tag or "singing" in top_tag:
                sound_desc = "a resonant voice soaring above, filling the acoustic space"
            elif "silence" in top_tag or "quiet" in top_tag:
                sound_desc = "the atmosphere drops into a profound, breathless hush"
            elif "ambient" in top_tag or "synth" in top_tag:
                sound_desc = "a shimmering, nebulous texture floats and shivers in the background"
            elif "laughter" in top_tag or "giggling" in top_tag:
                sound_desc = "sparks of warm, fluttering human chatter and giggles burst through"
            elif "screaming" in top_tag or "shout" in top_tag:
                sound_desc = "a sharp, piercing tear of sound splits the air, tense and sudden"
            elif "animal" in top_tag or "chicken" in top_tag:
                sound_desc = "a rustic, unexpected animal cackle breaks the sonic field"
        
        if dialogue_snippet:
            return f"Underneath {dialogue_snippet}, {sound_desc}."
        else:
            return sound_desc[0].upper() + sound_desc[1:] + "."

    # WebSocket clients broadcast
    def broadcast(self, message):
        if not self.ws_clients or not self.ws_loop:
            return
        for client in list(self.ws_clients):
            try:
                asyncio.run_coroutine_threadsafe(client.send(message), self.ws_loop)
            except Exception as e:
                pass

    # WebSocket connection handler
    async def ws_handler(self, websocket):
        self.ws_clients.add(websocket)
        # Send initial status
        status = "started" if self.is_running else "stopped"
        await websocket.send(json.dumps({"type": "status", "status": status}))
        try:
            async for message in websocket:
                try:
                    data = json.loads(message)
                    cmd = data.get("cmd")
                    if cmd == "start":
                        self.start_processes(data.get("llm"), data.get("labels"))
                    elif cmd == "stop":
                        self.stop_processes()
                except Exception as e:
                    print(f"Brain WS Handler: Error parsing client message: {e}", file=sys.stderr)
        except websockets.exceptions.ConnectionClosed:
            pass
        finally:
            self.ws_clients.remove(websocket)

    def start_http_server(self):
        handler = lambda *args, **kwargs: http.server.SimpleHTTPRequestHandler(*args, directory="aural-glossary/web_ui", **kwargs)
        # Avoid "Address already in use" errors during quick restarts
        socketserver.TCPServer.allow_reuse_address = True
        try:
            with socketserver.TCPServer(("", self.args.http_port), handler) as httpd:
                print(f"Brain: Web Dashboard hosted at http://localhost:{self.args.http_port}", file=sys.stderr)
                httpd.serve_forever()
        except Exception as e:
            print(f"Brain HTTP Server Error: {e}", file=sys.stderr)

    def start_ws_server(self):
        self.ws_loop = asyncio.new_event_loop()
        asyncio.set_event_loop(self.ws_loop)
        
        async def main_server():
            async with websockets.serve(self.ws_handler, "0.0.0.0", self.args.ws_port):
                print(f"Brain: WebSocket server listening on port {self.args.ws_port}", file=sys.stderr)
                await asyncio.Future()  # run forever

        self.ws_loop.run_until_complete(main_server())

    def run_loop(self):
        # Start HTTP server thread
        http_thread = threading.Thread(target=self.start_http_server, daemon=True)
        http_thread.start()

        # Start WebSocket server thread
        ws_thread = threading.Thread(target=self.start_ws_server, daemon=True)
        ws_thread.start()

        # Auto-start if requested
        if self.args.auto_start:
            self.start_processes()

        print("Brain: Web UI and WebSocket gateways active. Waiting for client start command...", file=sys.stderr)
        
        last_generation = time.time()
        
        try:
            while True:
                # Update queue events and sliding buffers
                self.update_buffers()
                
                # Periodically generate commentary if running
                now = time.time()
                if self.is_running and (now - last_generation >= self.args.interval):
                    dialogue, features = self.get_summary_context()
                    has_activity = len(self.transcriptions) > 0 or len(self.analysis_packets) > 0
                    
                    if has_activity:
                        story = self.query_llm(dialogue, features)
                        
                        output_packet = {
                            "type": "story",
                            "timestamp_ms": int(time.time() * 1000),
                            "story": story
                        }
                        
                        # Print to stdout and broadcast to all web clients
                        packet_str = json.dumps(output_packet)
                        print(packet_str)
                        sys.stdout.flush()
                        self.broadcast(packet_str)

                        if self.osc_client:
                            try:
                                self.osc_client.send_message("/story", story)
                            except Exception as e:
                                print(f"Brain: OSC Story Send Error: {e}", file=sys.stderr)
                                
                    last_generation = now
                
                time.sleep(0.1)
        except KeyboardInterrupt:
            print("Brain shutting down...", file=sys.stderr)
        finally:
            self.stop_processes()

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Aural Glossary Brain: Subprocess Orchestration & LLM Generator")
    parser.add_argument("--whisper-bin", type=str, default="aural-glossary/engine_a/whisper.cpp/build/bin/whisper-stream", help="Path to whisper-stream binary")
    parser.add_argument("--whisper-model", type=str, default="aural-glossary/engine_a/whisper.cpp/models/ggml-tiny.en.bin", help="Path to ggml model")
    parser.add_argument("--whisper-device", type=int, default=None, help="Whisper audio capture device ID")
    
    parser.add_argument("--engine-b-script", type=str, default="aural-glossary/engine_b/engine_b.py", help="Path to engine_b.py script")
    parser.add_argument("--engine-b-window", type=float, default=5.0, help="Engine B analysis window size (seconds)")
    parser.add_argument("--engine-b-step", type=float, default=2.0, help="Engine B analysis step size (seconds)")
    parser.add_argument("--engine-b-device", type=int, default=None, help="Engine B audio capture device ID")
    parser.add_argument("--engine-b-labels", type=str, default=None, help="Comma-separated labels for Engine B")

    parser.add_argument("--interval", type=float, default=5.0, help="Commentary generation interval in seconds")
    parser.add_argument("--llm", type=str, choices=["ollama", "gemini", "mock"], default="mock", help="LLM engine to use")
    parser.add_argument("--ollama-model", type=str, default="llama3", help="Ollama model name")
    parser.add_argument("--ollama-url", type=str, default="http://localhost:11434", help="Ollama API base URL")
    parser.add_argument("--gemini-model", type=str, default="gemini-2.5-flash", help="Gemini API model name")
    parser.add_argument("--api-key", type=str, default=None, help="Gemini API key")
    
    parser.add_argument("--context-file", type=str, default=None, help="Performance context file (genre, vocabulary, setlist)")
    parser.add_argument("--output-osc-ip", type=str, default=None, help="OSC target IP address for story streaming")
    parser.add_argument("--output-osc-port", type=int, default=7772, help="OSC target port for story streaming")

    # Web Dashboard parameters
    parser.add_argument("--http-port", type=int, default=8080, help="HTTP port to host the dashboard UI on")
    parser.add_argument("--ws-port", type=int, default=8081, help="WebSocket port to host communication on")
    parser.add_argument("--auto-start", action="store_true", default=False, help="Automatically start capturing engines on script launch")

    args = parser.parse_args()
    
    orchestrator = BrainOrchestrator(args)
    orchestrator.run_loop()
