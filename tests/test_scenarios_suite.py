"""Comprehensive Test Scenarios Suite for MOSS-Transcribe-Diarize Docker & Inference Setup.
Can run in any environment using Python standard library.
"""
import json
import os
import re
import subprocess
import sys
import unittest
from pathlib import Path

# Add project root to sys.path
PROJECT_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT_ROOT))

from moss_transcribe_diarize.transcript_parser import (
    TranscriptSegment,
    TranscriptStreamParser,
    parse_transcript,
)
from moss_transcribe_diarize.subtitle import (
    SubtitleSegment,
    SubtitleStyle,
    export_ass,
    export_json,
    export_srt,
    normalize_segments,
    subtitle_segments_from_transcript,
)


class TestScenario1DockerConfiguration(unittest.TestCase):
    """Scenario 1: Validate Dockerfile, Compose, and Environment files."""

    def test_dockerfile_exists_and_contains_gpu_runtime(self):
        dockerfile_path = PROJECT_ROOT / "Dockerfile"
        self.assertTrue(dockerfile_path.exists(), "Dockerfile must exist")
        content = dockerfile_path.read_text(encoding="utf-8")
        self.assertIn("cuda", content.lower(), "Dockerfile must use CUDA base image")
        self.assertIn("ffmpeg", content.lower(), "Dockerfile must install FFmpeg")
        self.assertIn("mtd-subtitle-web", content, "Dockerfile entrypoint must be mtd-subtitle-web")
        self.assertIn("7860", content, "Dockerfile must expose port 7860")

    def test_docker_compose_structure(self):
        compose_path = PROJECT_ROOT / "docker-compose.yml"
        self.assertTrue(compose_path.exists(), "docker-compose.yml must exist")
        content = compose_path.read_text(encoding="utf-8")
        self.assertIn("moss-app:", content, "Must define moss-app service")
        self.assertIn("cloudflared:", content, "Must define cloudflared service")
        self.assertIn("driver: nvidia", content, "Must configure NVIDIA GPU reservation")
        self.assertIn(":7860", content, "Must map port 7860")
        self.assertIn("hf_cache", content, "Must mount persistent cache for weights")

    def test_env_files_exist(self):
        env_example = PROJECT_ROOT / ".env.example"
        env_file = PROJECT_ROOT / ".env"
        self.assertTrue(env_example.exists(), ".env.example must exist")
        self.assertTrue(env_file.exists(), ".env must exist")


class TestScenario2TranscriptParsingAndDiarization(unittest.TestCase):
    """Scenario 2: Validate parsing of canonical MOSS timestamped & speaker-attributed transcripts."""

    def test_parse_multi_speaker_interview(self):
        raw_text = (
            "[0.48][S01]Hello and welcome to the podcast.[2.80]"
            "[3.20][S02]Thank you for having me today.[5.90]"
            "[6.10][S01]Let's dive into speech diarization.[9.45]"
        )
        segments = parse_transcript(raw_text)
        self.assertEqual(len(segments), 3)
        self.assertEqual(segments[0].speaker, "S01")
        self.assertEqual(segments[0].start, 0.48)
        self.assertEqual(segments[0].end, 2.80)
        self.assertEqual(segments[0].text, "Hello and welcome to the podcast.")

        self.assertEqual(segments[1].speaker, "S02")
        self.assertEqual(segments[1].start, 3.20)
        self.assertEqual(segments[1].text, "Thank you for having me today.")

    def test_streaming_token_arrival(self):
        """Simulate real-time streaming LLM tokens parsed on-the-fly."""
        stream = "[0.00][S01]Streaming audio text[1.50][1.80][S02]Response text[3.00]"
        parser = TranscriptStreamParser()
        emitted = []
        for char in stream:
            emitted.extend(parser.feed(char))
        emitted.extend(parser.close())

        self.assertEqual(len(emitted), 2)
        self.assertEqual(emitted[0].speaker, "S01")
        self.assertEqual(emitted[1].speaker, "S02")


class TestScenario3SubtitleGeneration(unittest.TestCase):
    """Scenario 3: Validate Subtitle export generation (SRT, ASS, JSON)."""

    def setUp(self):
        self.sample_transcript = (
            "[0.50][S01]Good morning everyone.[2.50]"
            "[3.00][S02]Good morning, let's review the quarterly results.[6.80]"
        )
        self.subtitles = subtitle_segments_from_transcript(self.sample_transcript)

    def test_export_srt(self):
        srt_output = export_srt(self.subtitles)
        self.assertIn("00:00:00,500 --> 00:00:02,500", srt_output)
        self.assertIn("S01: Good morning everyone.", srt_output)
        self.assertIn("00:00:03,000 -->", srt_output)
        self.assertIn("S02:", srt_output)

    def test_export_ass(self):
        ass_output = export_ass(self.subtitles, style=SubtitleStyle())
        self.assertIn("[Script Info]", ass_output)
        self.assertIn("Format: Layer, Start, End, Style", ass_output)
        self.assertIn("Dialogue:", ass_output)

    def test_export_json(self):
        json_str = export_json(self.subtitles)
        data = json.loads(json_str)
        self.assertIsInstance(data, list)
        self.assertGreaterEqual(len(data), 2)
        self.assertEqual(data[0]["speaker"], "S01")
        self.assertTrue(any(seg["speaker"] == "S02" for seg in data))


class TestScenario4HardwareAndVRAMCheck(unittest.TestCase):
    """Scenario 4: Verify GPU hardware detection and VRAM compatibility."""

    def test_nvidia_hardware_compatibility(self):
        try:
            res = subprocess.run(
                ["nvidia-smi", "--query-gpu=name,memory.total", "--format=csv,noheader"],
                capture_output=True,
                text=True,
                check=True,
            )
            output = res.stdout.strip()
            self.assertTrue(len(output) > 0, "nvidia-smi returned GPU info")
            # Parse memory
            parts = [p.strip() for p in output.split(",")]
            gpu_name = parts[0]
            vram_str = parts[1]
            vram_mb = int(re.search(r"(\d+)", vram_str).group(1))

            print(f"\n[GPU Detected] {gpu_name} with {vram_mb} MB VRAM")
            # MOSS 0.9B requires approx 1800MB weights + 1000MB activations = ~2.8GB VRAM
            self.assertGreaterEqual(vram_mb, 4000, "VRAM should be >= 4GB for comfortable inference")
        except FileNotFoundError:
            self.skipTest("nvidia-smi command not found on PATH")


class TestScenario5CloudflareTunnelReadiness(unittest.TestCase):
    """Scenario 5: Check Cloudflare Tunnel definition and port wiring."""

    def test_tunnel_routing_target(self):
        compose_content = (PROJECT_ROOT / "docker-compose.yml").read_text(encoding="utf-8")
        self.assertIn("http://moss-app:7860", compose_content, "Tunnel must target internal moss-app port 7860")
        self.assertIn("trycloudflare.com", compose_content, "Must support free Quick Tunnel fallback")


if __name__ == "__main__":
    unittest.main()
