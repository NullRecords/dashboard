#!/usr/bin/env python3
"""
Test Roger's voice with authentic battle droid samples
"""
import sys
import logging
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / 'src'))

from voice import VoiceSystem

logging.basicConfig(level=logging.INFO)

def main():
    print("🤖 Testing Roger Voice with Battle Droid Samples\n")
    
    # Initialize voice system
    voice = VoiceSystem(
        default_style="droid",
        speed=0.75,
        pitch=0.85,
        use_authentic_samples=True
    )
    
    # Check if samples exist
    samples_dir = Path("data/voice_models/battle_droid")
    if not samples_dir.exists():
        print("❌ Battle droid samples not found!")
        print(f"   Expected location: {samples_dir.absolute()}")
        return 1
    
    sample_files = list(samples_dir.glob("*.wav"))
    print(f"✓ Found {len(sample_files)} battle droid samples\n")
    
    # Test signature phrases (should use authentic samples)
    test_phrases = [
        "roger roger",
        "roger, roger",
        "oh no",
        "hold it",
        "you're welcome",
    ]
    
    print("Testing signature phrases with authentic samples:\n")
    for phrase in test_phrases:
        print(f"  Testing: '{phrase}'")
        success = voice.say(phrase, blocking=True)
        if success:
            print(f"    ✓ Played")
        else:
            print(f"    ✗ Failed")
        print()
    
    # Test synthesized speech (should use Piper TTS with effects)
    print("\nTesting synthesized speech with battle droid effects:\n")
    test_messages = [
        "Dashboard online",
        "Three tasks detected",
        "System ready",
    ]
    
    for msg in test_messages:
        print(f"  Testing: '{msg}'")
        success = voice.say(msg, add_signature=False, blocking=True)
        if success:
            print(f"    ✓ Generated and played")
        else:
            print(f"    ✗ Failed")
        print()
    
    # Test combined (signature + message)
    print("\nTesting signature + message:\n")
    print("  Playing with signature...")
    voice.say("All systems operational", add_signature=True, blocking=True)
    
    print("\n✅ Voice test complete!")
    return 0

if __name__ == "__main__":
    sys.exit(main())
