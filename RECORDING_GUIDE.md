# Recording Duration Guide for VoiceDropbox

## Current Configuration

- **Timeout:** 600 seconds (10 minutes)
- **Whisper Model:** Large
- **Device:** CUDA (GPU)

## The Problem

Your hour-long MP3 timed out because:
- Whisper Large model processes audio at approximately **0.5-1x real-time** on GPU
- 1 hour of audio = 30-60 minutes of processing time
- Your timeout is only **10 minutes** (600 seconds)

## Safe Recording Duration

### Conservative Recommendation: **8 minutes per recording**

**Calculation:**
- Timeout: 600 seconds (10 minutes)
- Processing time: ~0.5-1x real-time
- Safe duration: **8 minutes** (leaves 2-minute buffer for overhead)

### Aggressive Recommendation: **9 minutes per recording**

**Calculation:**
- Assumes faster GPU processing (~0.5x real-time)
- Leaves minimal buffer
- **Risk:** May still timeout on slower systems

## Sony IC Recorder File Sizes

### Standard Quality (128 kbps MP3)
- **1 minute** = ~1 MB
- **8 minutes** = ~8 MB
- **9 minutes** = ~9 MB
- **1 hour** = ~57 MB

### High Quality (192 kbps MP3)
- **1 minute** = ~1.4 MB
- **8 minutes** = ~11 MB
- **9 minutes** = ~12.5 MB

## Recommendations

### Option 1: Increase Timeout (Recommended)
Update `config.yaml`:

```yaml
whisper:
  command_timeout_seconds: 3600  # 1 hour for processing
```

This allows processing up to **30-60 minutes** of audio.

### Option 2: Split Recordings (Current Setup)
**Stop and restart every 8 minutes** to ensure processing completes within timeout.

**Workflow:**
1. Record for 8 minutes
2. Stop recording
3. File auto-processes
4. Start new recording
5. Repeat

### Option 3: Use Smaller Model
Switch to `medium` or `base` model for faster processing:

```yaml
whisper:
  model: "medium"  # Faster, slightly less accurate
```

This allows longer recordings with the same timeout.

## Processing Time Estimates

| Audio Duration | Processing Time (Large GPU) | Fits in 600s? |
|----------------|---------------------------|---------------|
| 5 minutes      | 2.5-5 minutes             | ✅ Yes        |
| 8 minutes      | 4-8 minutes               | ✅ Yes (tight)|
| 10 minutes     | 5-10 minutes              | ⚠️ Maybe      |
| 15 minutes     | 7.5-15 minutes            | ❌ No         |
| 30 minutes     | 15-30 minutes             | ❌ No         |
| 60 minutes     | 30-60 minutes             | ❌ No         |

## Best Practice

**For Sony IC Recorder with current timeout:**

1. **Set a timer for 8 minutes**
2. **Stop recording** when timer goes off
3. **Wait for processing** (usually completes in 2-5 minutes)
4. **Start new recording**
5. **Repeat**

This ensures:
- ✅ No timeouts
- ✅ Reliable processing
- ✅ Natural break points
- ✅ Easier to manage/organize

## Alternative: Post-Processing Split

If you record longer files, you can split them before processing:

```bash
# Using FFmpeg (if installed)
ffmpeg -i long_recording.mp3 -f segment -segment_time 480 -c copy output_%03d.mp3
```

This splits into 8-minute chunks (480 seconds).

## Summary

**With current 600-second timeout:**
- **Maximum safe duration: 8 minutes**
- **Sony IC Standard Quality: ~8 MB per file**
- **Stop and restart every 8 minutes**

**Recommended: Increase timeout to 3600 seconds** to handle longer recordings without splitting.
