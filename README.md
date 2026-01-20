# Voice Transcription Watcher

Automated voice transcription service that monitors a folder for audio files and transcribes them using OpenAI Whisper via WSL. Outputs Obsidian-compatible markdown files.

## Features

- **Folder Watching**: Monitors `incoming/` folder for new audio files
- **Whisper Integration**: Uses OpenAI Whisper (via WSL) for transcription
- **Obsidian Output**: Generates markdown files with YAML frontmatter
- **Windows Notifications**: Toast notifications for success/failure
- **File Organization**: Automatically organizes by date (year/month)
- **Error Handling**: Moves failed files to `failed/` folder
- **Archive**: Archives processed files to `archive/` folder

## Requirements

- Python 3.9+
- WSL (Windows Subsystem for Linux) with Whisper installed
- Windows 10/11

## Installation

1. **Clone the repository**:
   ```bash
   git clone git@github.com:jim-finlon/voice-dropbox.git
   cd voice-dropbox
   ```

2. **Create virtual environment**:
   ```bash
   python -m venv venv
   venv\Scripts\activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure Whisper in WSL**:
   - Install Whisper in your WSL environment
   - Update `venv_path` in `config.yaml` to point to your WSL Whisper venv

5. **Configure paths**:
   - Edit `config.yaml` to set your paths
   - Update `output_folder` to your Obsidian vault location

## Configuration

Edit `config.yaml`:

```yaml
paths:
  watch_folder: "D:/VoiceDropbox/incoming"
  processing_folder: "D:/VoiceDropbox/processing"
  archive_folder: "D:/VoiceDropbox/archive"
  failed_folder: "D:/VoiceDropbox/failed"
  output_folder: "//RaspiDesktop/Documents/Obsidian Shared/Voice Notes"

whisper:
  model: "large"  # Options: tiny, base, small, medium, large
  language: "en"
  venv_path: "~/whisper/venv"  # WSL path to Whisper venv

processing:
  supported_formats: [".mp3", ".wav", ".m4a", ".flac", ".ogg", ".webm"]
  organize_by_date: true  # Organize output by year/month

notifications:
  enabled: true
  on_success: true
  on_failure: true
```

## Usage

### Start the Watcher

**Option 1: Use the batch file** (easiest):
```bash
start_watcher.bat
```

**Option 2: Manual start**:
```bash
venv\Scripts\activate
python voice_watcher.py
```

### Drop Audio Files

Simply drop audio files (MP3, WAV, M4A, FLAC, OGG, WEBM) into the `incoming/` folder. The watcher will:

1. Detect the new file
2. Move it to `processing/`
3. Transcribe using Whisper
4. Generate Obsidian markdown note
5. Move file to `archive/`
6. Send Windows notification

### Output Format

Transcriptions are saved as Obsidian markdown files with YAML frontmatter:

```markdown
---
created: 2026-01-09T14:48:00
source: 260109_1448.mp3
processing_time: 45.2s
model: whisper-large
tags: [voice-note, transcription]
command_type: note
---

# Voice Note - 2026-01-09 14:48

[Transcription text here]

---
*Transcribed automatically by Voice Transcription System*
```

## Project Structure

```
voice-dropbox/
├── voice_watcher.py      # Main watcher script
├── config.yaml           # Configuration file
├── requirements.txt      # Python dependencies
├── start_watcher.bat     # Windows launcher
├── transcription.log     # Log file
├── incoming/             # Drop audio files here
├── processing/           # Temporary processing folder
│   └── whisper_output/   # Whisper temp output
├── archive/              # Processed files
└── failed/               # Failed transcriptions
```

## Troubleshooting

### Whisper Not Found
- Ensure WSL is installed and Whisper is set up
- Check `venv_path` in `config.yaml` points to correct WSL path
- Test Whisper manually in WSL: `whisper --help`

### Files Not Processing
- Check `transcription.log` for errors
- Ensure file format is supported
- Check Windows notifications for error messages

### WSL Path Issues
- WSL paths are auto-converted from Windows paths
- Format: `/mnt/d/Path/To/File` for `D:\Path\To\File`
- Ensure paths in config.yaml use forward slashes

## License

MIT License

## Author

Jim Finlon
