#!/usr/bin/env python3
import os
import sys
import unittest
import numpy as np
import json
import time

# Add project root to path so we can import modules
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..")))

from engine_b.engine_b import RollingAudioBuffer
from brain.brain import BrainOrchestrator

class TestRollingAudioBuffer(unittest.TestCase):
    def test_buffer_capacity_and_write(self):
        sample_rate = 1000
        capacity_seconds = 2
        buf = RollingAudioBuffer(capacity_seconds, sample_rate)
        
        self.assertEqual(buf.capacity, 2000)
        self.assertFalse(buf.has_data)
        
        # Write small chunk
        data1 = np.ones(500, dtype=np.float32)
        buf.extend(data1)
        self.assertTrue(buf.has_data)
        
        # Get last 1 second (1000 samples)
        # Since we only wrote 500, it should return 500 ones padded with 500 zeros
        out1 = buf.get_last(1.0)
        self.assertEqual(len(out1), 1000)
        self.assertEqual(np.sum(out1 == 1.0), 500)
        self.assertEqual(np.sum(out1 == 0.0), 500)

    def test_buffer_wrap_around(self):
        sample_rate = 1000
        capacity_seconds = 2
        buf = RollingAudioBuffer(capacity_seconds, sample_rate)
        
        # Write more than capacity
        data1 = np.arange(2500, dtype=np.float32)
        buf.extend(data1)
        
        # Should keep only the last 2000 samples (from 500 to 2499)
        out1 = buf.get_last(2.0)
        self.assertEqual(len(out1), 2000)
        self.assertEqual(out1[0], 500)
        self.assertEqual(out1[-1], 2499)

class TestBrainOrchestrator(unittest.TestCase):
    class MockArgs:
        def __init__(self):
            self.context_file = None
            self.output_osc_ip = None
            self.output_osc_port = 7772
            self.llm = "mock"
            self.interval = 3.0
            self.whisper_bin = "dummy"
            self.whisper_model = "dummy"
            self.whisper_device = None
            self.engine_b_script = "dummy"
            self.engine_b_window = 5.0
            self.engine_b_step = 2.0
            self.engine_b_device = None
            self.engine_b_labels = None
            self.ollama_model = "dummy"
            self.ollama_url = "dummy"
            self.gemini_model = "dummy"
            self.api_key = None

    def setUp(self):
        self.args = self.MockArgs()
        self.brain = BrainOrchestrator(self.args)

    def test_transcription_sliding_window(self):
        # Push 12 transcription packets
        for i in range(12):
            packet = {
                "type": "transcription",
                "text": f"Line {i}",
                "confidence": 0.85,
                "start_ms": i * 1000,
                "end_ms": (i + 1) * 1000
            }
            self.brain.event_queue.put(("engine-a", packet))
            
        self.brain.update_buffers()
        
        # Should slide and keep only the last 10
        self.assertEqual(len(self.brain.transcriptions), 10)
        self.assertEqual(self.brain.transcriptions[0]["text"], "Line 2")
        self.assertEqual(self.brain.transcriptions[-1]["text"], "Line 11")

    def test_mock_story_generation(self):
        # Setup transcription
        self.brain.transcriptions.append({
            "text": "Hello world",
            "confidence": 0.95,
            "start_ms": 0,
            "end_ms": 1000,
            "time": time.time()
        })
        
        # Setup analysis with "loud distorted drone" CLAP tag
        self.brain.analysis_packets.append({
            "rms": 0.15,
            "centroid": 5000.0,
            "zcr": 0.02,
            "tempo": 120.0,
            "labels": {
                "silence or absolute quiet": 0.01,
                "loud distorted drone or static noise": 0.95,
                "heavy thud, impact or drum beat": 0.04
            },
            "time": time.time()
        })
        
        dialogue, features = self.brain.get_summary_context()
        story = self.brain._generate_mock_story(dialogue, features)
        
        # Story should contain the dialogue and description of the drone
        self.assertIn("Hello world", story)
        self.assertIn("thick, dark cloud of static vibration", story.lower())

if __name__ == "__main__":
    unittest.main()
