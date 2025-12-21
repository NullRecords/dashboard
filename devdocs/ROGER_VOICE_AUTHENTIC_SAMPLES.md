# Roger Voice: Authentic Battle Droid Samples

## Overview
Roger now uses authentic Star Wars battle droid voice samples for signature phrases, making the assistant sound more like an actual B1 battle droid from the movies.

## Architecture

### Audio Sample Storage
```
data/voice_models/battle_droid/
├── roger-roger__1_.wav         # Primary signature phrase
├── oh-no.wav                   # Expressions of concern
├── hold-it.wav                 # Commands
├── you-re-welcome.wav          # Polite responses
├── surrender-jedi.wav          # Dramatic phrases
├── don-t-even-think.wav        # Warnings
├── my-programming.wav          # Technical responses
├── stupid-astro-droid.wav      # Character interactions
└── you-re-welcome__1_.wav      # Alternate version
```

### Sample Specifications
- **Format**: WAV (converted from MP3)
- **Sample Rate**: 22.05 kHz
- **Channels**: Mono
- **Bit Depth**: 16-bit PCM
- **Size Range**: 39KB - 130KB per file

## Implementation

### Voice System Enhancement
The `VoiceSystem` class in `src/voice.py` now includes:

1. **Sample Phrase Mapping**
   ```python
   sample_phrases = {
       "roger roger": "roger-roger__1_.wav",
       "oh no": "oh-no.wav",
       "hold it": "hold-it.wav",
       "you're welcome": "you-re-welcome.wav",
       "surrender": "surrender-jedi.wav"
   }
   ```

2. **Authentic Sample Playback**
   - Case-insensitive phrase matching
   - Substring matching for flexibility
   - Falls back to Piper TTS if no sample available
   - Uses `ffplay` for audio playback

3. **Configuration**
   ```python
   VoiceSystem(
       use_authentic_samples=True,  # Enable authentic samples
       default_style="droid",        # Battle droid effects
       speed=0.75,                   # Slightly slower for clarity
       pitch=0.85                    # Lower pitch for droid character
   )
   ```

### Say Method Behavior

When Roger speaks:

1. **Check for Authentic Sample**: If the text matches a known phrase (like "roger roger"), play the authentic sample
2. **Fallback to Synthesis**: If no sample exists, use Piper TTS with battle droid effects
3. **Signature Phrases**: For messages with `add_signature=True`, play authentic "roger roger" sample first

### Audio Effects Chain

When synthesizing speech (not using samples):
- **Bitcrushing**: Reduces bit depth for digital droid sound
- **Tremolo**: Adds oscillating amplitude for mechanical quality
- **Compression**: Even out volume levels
- **Echo**: Slight metallic reverberation
- **Vibrato**: Subtle pitch oscillation

## Usage

### Basic Speech
```python
from voice import get_voice

voice = get_voice()
voice.say("Dashboard online")  # Will synthesize with droid effects
```

### Signature Phrases
```python
voice.say("roger roger")  # Will use authentic sample
voice.say("All systems operational", add_signature=True)  # Plays sample + message
```

### Testing
Run the comprehensive test:
```bash
./test_roger_voice.py
```

This tests:
- Authentic sample playback for known phrases
- Synthesis for custom messages
- Combined signature + message

## Settings UI

Users can toggle authentic samples in the Voice Settings modal:

1. Click "Voice Settings" in sidebar
2. Toggle "🎬 Authentic Battle Droid Samples"
3. Adjust Speed and Pitch sliders
4. Click "Save Settings"

Settings persist in `data/voice_settings.json`:
```json
{
  "default_style": "droid",
  "speed": 0.75,
  "pitch": 0.85,
  "use_authentic_samples": true
}
```

## API Endpoints

### Get Voice Settings
```bash
GET /api/voice/settings
```

Returns:
```json
{
  "voice": {
    "default_style": "droid",
    "speed": 0.75,
    "pitch": 0.85,
    "use_authentic_samples": true
  }
}
```

### Update Voice Settings
```bash
POST /api/voice/settings
Content-Type: application/json

{
  "default_style": "droid",
  "speed": 0.75,
  "pitch": 0.85,
  "use_authentic_samples": true
}
```

## Adding New Samples

To add new authentic samples:

1. **Add MP3 to Source**
   ```bash
   cp new-sample.mp3 assets/roger_voices/
   ```

2. **Convert to WAV**
   ```bash
   ffmpeg -i assets/roger_voices/new-sample.mp3 \
          -ar 22050 -ac 1 \
          data/voice_models/battle_droid/new-sample.wav
   ```

3. **Update Phrase Mapping** in `src/voice.py`:
   ```python
   sample_phrases = {
       ...
       "new phrase": "new-sample.wav"
   }
   ```

## Benefits

### Authenticity
- Real Star Wars battle droid voice for signature phrases
- Maintains character immersion
- Professional movie-quality audio

### Performance
- Pre-recorded samples load instantly
- No synthesis delay for common phrases
- Reduced CPU usage for frequent responses

### Flexibility
- Seamless fallback to TTS for custom messages
- Configurable via UI (can disable if preferred)
- Easy to add new samples

## Troubleshooting

### Sample Not Playing
1. Check file exists: `ls data/voice_models/battle_droid/`
2. Verify format: `file data/voice_models/battle_droid/*.wav`
3. Check console logs for playback errors
4. Ensure ffplay is installed: `which ffplay`

### Quality Issues
- Authentic samples are 22.05kHz (intentionally lower for droid character)
- Adjust system volume if too quiet
- Check that `use_authentic_samples` is enabled in settings

### Missing Files
Run conversion command:
```bash
mkdir -p data/voice_models/battle_droid
for f in assets/roger_voices/*.mp3; do
    base=$(basename "$f" .mp3 | tr ' ()' '___')
    ffmpeg -i "$f" -ar 22050 -ac 1 \
           "data/voice_models/battle_droid/${base}.wav"
done
```

## Future Enhancements

Potential improvements:
- **Context-aware samples**: Different samples based on message type (error, success, info)
- **Sample sequences**: Chain multiple samples for complex responses
- **User uploads**: Allow users to record their own Roger samples
- **Volume normalization**: Ensure consistent volume across all samples
- **Sample library UI**: Browse and preview available samples in settings

## References

- Voice system implementation: [src/voice.py](../src/voice.py)
- Test script: [test_roger_voice.py](../test_roger_voice.py)
- Voice settings endpoint: [src/main.py](../src/main.py) (line 3456)
- Original samples: [assets/roger_voices/](../assets/roger_voices/)
