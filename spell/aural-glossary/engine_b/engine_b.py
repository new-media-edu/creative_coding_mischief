#!/usr/bin/env python3
import os
import sys
import time
import argparse
import json
import threading
import numpy as np
import sounddevice as sd
import librosa
import torch
from transformers import AutoProcessor, ClapModel

# Force PortAudio lib path if LD_LIBRARY_PATH isn't set
if "LD_LIBRARY_PATH" not in os.environ:
    os.environ["LD_LIBRARY_PATH"] = "/home/grayson/.local/share/mamba/envs/.mamba-env/lib"

class RollingAudioBuffer:
    def __init__(self, capacity_seconds, sample_rate):
        self.capacity = capacity_seconds * sample_rate
        self.sample_rate = sample_rate
        self.buffer = np.zeros(self.capacity, dtype=np.float32)
        self.write_idx = 0
        self.lock = threading.Lock()
        self.has_data = False

    def extend(self, data):
        with self.lock:
            n = len(data)
            if n >= self.capacity:
                self.buffer = data[-self.capacity:].copy()
                self.write_idx = 0
            else:
                end_idx = self.write_idx + n
                if end_idx <= self.capacity:
                    self.buffer[self.write_idx:end_idx] = data
                    self.write_idx = end_idx % self.capacity
                else:
                    first_part = self.capacity - self.write_idx
                    second_part = n - first_part
                    self.buffer[self.write_idx:] = data[:first_part]
                    self.buffer[:second_part] = data[first_part:]
                    self.write_idx = second_part
            self.has_data = True

    def get_last(self, seconds):
        with self.lock:
            n_samples = int(seconds * self.sample_rate)
            n_samples = min(n_samples, self.capacity)
            
            # Read backwards from write_idx
            if self.write_idx >= n_samples:
                return self.buffer[self.write_idx - n_samples:self.write_idx].copy()
            else:
                part2 = self.buffer[:self.write_idx]
                part1 = self.buffer[-(n_samples - self.write_idx):]
                return np.concatenate([part1, part2])

def list_devices():
    print(sd.query_devices())
    sys.exit(0)

def main():
    parser = argparse.ArgumentParser(description="Engine B: Sound & Music Analysis (DSP & CLAP)")
    parser.add_argument("--list-devices", action="store_true", help="List available audio input devices and exit")
    parser.add_argument("--device", type=int, default=None, help="Audio input device index")
    parser.add_argument("--model", type=str, default="laion/clap-htsat-fused", help="HuggingFace CLAP model path")
    parser.add_argument("--window", type=float, default=5.0, help="Audio analysis window size in seconds")
    parser.add_argument("--step", type=float, default=2.0, help="Audio analysis step size in seconds")
    parser.add_argument("--labels", type=str, default=None, help="Comma-separated list of target semantic labels")
    parser.add_argument("--osc-ip", type=str, default=None, help="OSC target IP address (to enable OSC streaming)")
    parser.add_argument("--osc-port", type=int, default=7771, help="OSC target port")
    
    args = parser.parse_args()

    if args.list_devices:
        list_devices()

    # Define default candidate text labels for zero-shot classification
    if args.labels:
        candidate_labels = [label.strip() for label in args.labels.split(",")]
    else:
        candidate_labels = [
            "silence or absolute quiet",
            "ambient texture or synth pad",
            "loud distorted drone or static noise",
            "heavy thud, impact or drum beat",
            "acoustic music or melodic sound",
            "singing voice or vocals",
            "a person speaking or talking",
            "laughter, giggling or crowd noise",
            "screaming, shouting or high pitched screech",
            "animal sound or chicken clucking"
        ]

    # Prepend 'sound of ' to help the CLAP text encoder map better to audio
    processed_labels = []
    for label in candidate_labels:
        if not label.lower().startswith("sound of") and not label.lower().startswith("a "):
            processed_labels.append(f"sound of {label}")
        else:
            processed_labels.append(label)

    print(f"Engine B: Loading CLAP model '{args.model}'...", file=sys.stderr)
    device = "cuda" if torch.cuda.is_available() else "cpu"
    
    try:
        model = ClapModel.from_pretrained(args.model).to(device)
        processor = AutoProcessor.from_pretrained(args.model)
        model.eval()
        print(f"Engine B: CLAP loaded on device: {device}", file=sys.stderr)
    except Exception as e:
        print(f"Error loading CLAP model: {e}", file=sys.stderr)
        sys.exit(1)

    # Optional OSC publisher
    osc_client = None
    if args.osc_ip:
        try:
            from pythonosc import udp_client
            osc_client = udp_client.SimpleUDPClient(args.osc_ip, args.osc_port)
            print(f"Engine B: OSC output enabled to {args.osc_ip}:{args.osc_port}", file=sys.stderr)
        except ImportError:
            print("python-osc is not installed. OSC output disabled.", file=sys.stderr)

    # Audio capturing parameters
    sample_rate = 48000  # CLAP native sample rate
    buffer_capacity = 15  # seconds
    audio_buffer = RollingAudioBuffer(buffer_capacity, sample_rate)

    def audio_callback(indata, frames, time_info, status):
        if status:
            print(f"Audio Callback Warning: {status}", file=sys.stderr)
        audio_buffer.extend(indata[:, 0])

    print("Engine B: Starting audio stream...", file=sys.stderr)
    try:
        stream = sd.InputStream(
            device=args.device,
            channels=1,
            samplerate=sample_rate,
            callback=audio_callback,
            blocksize=2048
        )
    except Exception as e:
        print(f"Failed to open audio input stream: {e}", file=sys.stderr)
        sys.exit(1)

    # Print status indicating ready
    print(json.dumps({"type": "status", "status": "ready"}))
    sys.stdout.flush()

    with stream:
        while True:
            time.sleep(args.step)
            
            if not audio_buffer.has_data:
                continue

            # Extract window
            y = audio_buffer.get_last(args.window)
            if len(y) < int(args.window * sample_rate * 0.8):
                continue  # wait for buffer to fill

            # Calculate DSP features
            rms = float(np.sqrt(np.mean(y**2)))
            
            # Avoid divide-by-zero or warning in librosa features if silent
            if rms < 1e-4:
                spectral_centroid = 0.0
                zcr = 0.0
                tempo = 0.0
            else:
                try:
                    # Calculate spectral centroid
                    centroids = librosa.feature.spectral_centroid(y=y, sr=sample_rate, n_fft=1024, hop_length=512)
                    spectral_centroid = float(np.mean(centroids))
                    
                    # Zero crossing rate (noisiness)
                    zcrs = librosa.feature.zero_crossing_rate(y=y, hop_length=512)
                    zcr = float(np.mean(zcrs))
                    
                    # Rhythm/tempo estimation (onset strength)
                    onset_env = librosa.onset.onset_strength(y=y, sr=sample_rate, hop_length=512)
                    tempo_values = librosa.feature.tempo(onset_envelope=onset_env, sr=sample_rate, hop_length=512)
                    tempo = float(tempo_values[0]) if len(tempo_values) > 0 else 0.0
                except Exception as e:
                    print(f"DSP Feature Extraction Error: {e}", file=sys.stderr)
                    spectral_centroid = 0.0
                    zcr = 0.0
                    tempo = 0.0

            # Run CLAP Inference
            try:
                # CLAP is zero-shot, we pass both audio and candidate text labels
                inputs = processor(audio=y, return_tensors="pt", sampling_rate=sample_rate)
                text_inputs = processor(text=processed_labels, return_tensors="pt", padding=True)
                
                # Move to GPU/CPU
                inputs = {k: v.to(device) for k, v in inputs.items()}
                text_inputs = {k: v.to(device) for k, v in text_inputs.items()}

                with torch.no_grad():
                    outputs = model(
                        input_features=inputs["input_features"],
                        is_longer=inputs["is_longer"],
                        input_ids=text_inputs["input_ids"],
                        attention_mask=text_inputs["attention_mask"]
                    )
                    probs = outputs.logits_per_audio.softmax(dim=-1).cpu().numpy()[0]
                
                # Map probabilities back to user-facing candidate labels
                label_probs = {candidate_labels[i]: float(probs[i]) for i in range(len(candidate_labels))}
            except Exception as e:
                print(f"CLAP Inference Error: {e}", file=sys.stderr)
                label_probs = {label: 0.0 for label in candidate_labels}

            # Compile result packet
            packet = {
                "type": "analysis",
                "timestamp_ms": int(time.time() * 1000),
                "rms": rms,
                "centroid": spectral_centroid,
                "zcr": zcr,
                "tempo": tempo,
                "labels": label_probs
            }

            # Write JSON line to stdout
            print(json.dumps(packet))
            sys.stdout.flush()

            # Optional OSC send
            if osc_client:
                try:
                    osc_client.send_message("/audio/rms", rms)
                    osc_client.send_message("/audio/centroid", spectral_centroid)
                    osc_client.send_message("/audio/tempo", tempo)
                    for k, v in label_probs.items():
                        osc_client.send_message(f"/audio/label/{k.replace(' ', '_')}", v)
                except Exception as e:
                    print(f"OSC Send Error: {e}", file=sys.stderr)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("Engine B stopped.", file=sys.stderr)
        sys.exit(0)
