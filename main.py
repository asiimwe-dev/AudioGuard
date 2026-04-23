"""
AudioGuard Phase 1 - Spectral Encoder Demonstration

This script demonstrates the core capabilities of the AudioGuard engine:
- Loading audio files in various formats
- Embedding watermarks using STFT-based bit-spreading
- Preserving audio quality while ensuring inaudibility
- Outputting watermarked audio with original format preserved

Example Usage:
    python main.py --input sample.wav --output watermarked.wav --message "AUTHOR_001"
"""

import argparse
import sys
from pathlib import Path
from engine import AudioGuardEncoder
import numpy as np
import soundfile as sf


def create_demo_audio(output_path: str, duration: float = 3.0, sample_rate: int = 44100):
    """
    Create a demo audio file for testing.

    Generates a simple musical phrase (sine waves at different frequencies)
    to demonstrate watermark encoding on realistic audio.

    Args:
        output_path: Where to save demo audio
        duration: Length in seconds
        sample_rate: Sample rate in Hz
    """
    print(f"Creating demo audio: {duration}s @ {sample_rate}Hz...")
    t = np.linspace(0, duration, int(sample_rate * duration))

    # Create a simple melody (C-E-G chord progression with minor variations)
    frequencies = [262, 330, 392]  # C4, E4, G4
    audio = np.zeros_like(t)

    segment_length = duration / len(frequencies)
    for i, freq in enumerate(frequencies):
        start_idx = int(i * segment_length * sample_rate)
        end_idx = int((i + 1) * segment_length * sample_rate)
        segment = t[start_idx:end_idx] - t[start_idx]
        audio[start_idx:end_idx] += 0.2 * np.sin(2 * np.pi * freq * segment)

    # Add slight envelope to avoid clicks
    envelope = np.linspace(1, 0.3, len(audio))
    audio = audio * envelope

    # Save
    audio = audio.astype(np.float32)
    sf.write(output_path, audio, sample_rate)
    print(f"✓ Demo audio created: {output_path}")
    return audio, sample_rate


def main():
    """Main CLI interface for AudioGuard encoder."""
    parser = argparse.ArgumentParser(
        description="AudioGuard Phase 1: STFT-Based Spectral Watermarking Engine",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Watermark an existing audio file
  python main.py --input voice.wav --output watermarked.wav --message "AUTHOR_001"

  # Create and watermark demo audio
  python main.py --demo --output demo_watermarked.wav --message "AudioGuard"

  # Use custom encoding parameters
  python main.py --input audio.wav --output out.wav --message "MSG" --amplitude 0.1

  # Extract watermark info (metadata display)
  python main.py --analyze watermarked.wav
        """,
    )

    parser.add_argument(
        "--input",
        type=str,
        help="Input audio file to watermark (wav, mp3, flac, etc.)",
    )
    parser.add_argument(
        "--output",
        type=str,
        help="Output path for watermarked audio (will be saved as WAV)",
    )
    parser.add_argument(
        "--message",
        type=str,
        help="Message to embed (text string, e.g., AUTHOR_ID_001)",
    )
    parser.add_argument(
        "--demo",
        action="store_true",
        help="Generate and watermark a demo audio file (overrides --input)",
    )
    parser.add_argument(
        "--frame-size",
        type=int,
        default=2048,
        help="STFT frame size (default: 2048)",
    )
    parser.add_argument(
        "--amplitude",
        type=float,
        default=0.05,
        help="Watermark amplitude factor 0.0-1.0 (default: 0.05)",
    )
    parser.add_argument(
        "--bits-per-frame",
        type=int,
        default=4,
        help="Bits per frame for redundancy (default: 4)",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for deterministic bit-spreading (default: 42)",
    )
    parser.add_argument(
        "--analyze",
        type=str,
        help="Analyze audio file and display properties (no watermarking)",
    )

    args = parser.parse_args()

    # Validate arguments
    if args.analyze:
        # Analyze mode
        analyze_audio(args.analyze)
        return

    if not args.demo and not args.input:
        parser.error("Either --input or --demo must be specified")

    if not args.output:
        parser.error("--output is required")

    if not args.message:
        parser.error("--message is required")

    # Prepare input file
    if args.demo:
        input_path = Path("demo_audio_temp.wav")
        create_demo_audio(str(input_path))
    else:
        input_path = Path(args.input)
        if not input_path.exists():
            print(f"ERROR: Input file not found: {input_path}", file=sys.stderr)
            sys.exit(1)

    output_path = Path(args.output)

    print("=" * 80)
    print("AudioGuard Phase 1 - Spectral Watermark Encoder")
    print("=" * 80)

    # Initialize encoder
    encoder = AudioGuardEncoder(
        frame_size=args.frame_size,
        amplitude_factor=args.amplitude,
        seed=args.seed,
    )

    print(f"\nEncoder Configuration:")
    print(f"  Frame Size:        {args.frame_size} samples")
    print(f"  Hop Size:          {args.frame_size // 2} samples (50% overlap)")
    print(f"  Amplitude Factor:  {args.amplitude:.4f}")
    print(f"  Bits per Frame:    {args.bits_per_frame}")
    print(f"  Random Seed:       {args.seed}")

    print(f"\nWatermark Configuration:")
    print(f"  Message:           '{args.message}'")
    print(f"  Input Audio:       {input_path}")
    print(f"  Output Audio:      {output_path}")

    print("\n" + "-" * 80)

    # Encode
    try:
        metadata = encoder.encode(
            input_audio_path=str(input_path),
            output_audio_path=str(output_path),
            message=args.message,
            bits_per_frame=args.bits_per_frame,
        )

        print("-" * 80)
        print("\nEncoding Summary:")
        print(f"  Duration:          {metadata['duration']:.2f} seconds")
        print(f"  Sample Rate:       {metadata['sample_rate']} Hz")
        print(f"  Frames Processed:  {metadata['frame_count']}")
        print(f"  Binary Message:    {metadata['bit_sequence']}")
        print(f"  Message Length:    {len(args.message)} chars ({len(metadata['bit_sequence'])} bits)")
        print(f"  Spread Config:     {metadata['spread_info']}")

        # Verify output
        output_info = output_path.stat()
        watermarked, sr = sf.read(str(output_path), dtype="float32")

        print(f"\nOutput File Verification:")
        print(f"  File Size:         {output_info.st_size / 1024 / 1024:.2f} MB")
        print(f"  Sample Rate:       {sr} Hz")
        print(f"  Samples:           {len(watermarked)}")
        print(f"  Max Amplitude:     {np.max(np.abs(watermarked)):.6f}")
        print(f"  RMS Level:         {np.sqrt(np.mean(watermarked**2)):.6f}")

        print("\n" + "=" * 80)
        print("✓ Watermarking complete! Audio is ready for distribution.")
        print("=" * 80)

        # Cleanup demo file if used
        if args.demo:
            input_path.unlink()

    except Exception as e:
        print(f"\nERROR: {e}", file=sys.stderr)
        if args.demo:
            input_path.unlink(missing_ok=True)
        sys.exit(1)


def analyze_audio(audio_path: str):
    """Analyze and display audio file properties."""
    path = Path(audio_path)

    if not path.exists():
        print(f"ERROR: File not found: {audio_path}", file=sys.stderr)
        sys.exit(1)

    print("=" * 80)
    print(f"Audio Analysis: {audio_path}")
    print("=" * 80)

    audio, sr = sf.read(audio_path, dtype="float32")
    duration = len(audio) / sr

    print(f"\nFile Properties:")
    print(f"  Format:            {path.suffix}")
    print(f"  File Size:         {path.stat().st_size / 1024 / 1024:.2f} MB")

    print(f"\nAudio Properties:")
    print(f"  Sample Rate:       {sr} Hz")
    print(f"  Duration:          {duration:.2f} seconds")
    print(f"  Samples:           {len(audio)}")
    print(f"  Channels:          {'Mono' if audio.ndim == 1 else 'Stereo'}")

    print(f"\nSignal Statistics:")
    print(f"  Max Amplitude:     {np.max(np.abs(audio)):.6f}")
    print(f"  Min Amplitude:     {np.min(np.abs(audio)):.6f}")
    print(f"  Mean Amplitude:    {np.mean(np.abs(audio)):.6f}")
    print(f"  RMS Level:         {np.sqrt(np.mean(audio**2)):.6f}")
    print(f"  Peak dB:           {20 * np.log10(np.max(np.abs(audio)) + 1e-10):.2f} dB")

    print("=" * 80)


if __name__ == "__main__":
    main()
