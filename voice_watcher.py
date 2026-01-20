#!/usr/bin/env python3
"""
Voice Transcription Watcher Service
Monitors a folder for audio files and transcribes them using Whisper on GPU.
Outputs Obsidian-compatible markdown files.

Author: Jim Finlon
Version: 1.0
Date: 2026-01-09
"""

import os
import sys
import time
import shutil
import subprocess
import logging
import yaml
from pathlib import Path
from datetime import datetime
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

# Windows toast notifications
try:
    from winotify import Notification, audio
    NOTIFICATIONS_AVAILABLE = True
except ImportError:
    NOTIFICATIONS_AVAILABLE = False
    print("Warning: winotify not installed. Notifications disabled.")
    print("Install with: pip install winotify")


class TranscriptionHandler(FileSystemEventHandler):
    """Handles new audio files in the watch folder."""
    
    def __init__(self, config):
        self.config = config
        self.supported_formats = tuple(config['processing']['supported_formats'])
        self.processing_queue = []
        self.is_processing = False
        
    def on_created(self, event):
        if event.is_directory:
            return
        
        file_path = Path(event.src_path)
        if file_path.suffix.lower() in self.supported_formats:
            logging.info(f"New audio file detected: {file_path.name}")
            self.processing_queue.append(file_path)
            self.process_queue()
    
    def on_moved(self, event):
        """Handle files moved into the watch folder."""
        if event.is_directory:
            return
        
        file_path = Path(event.dest_path)
        if file_path.suffix.lower() in self.supported_formats:
            logging.info(f"Audio file moved in: {file_path.name}")
            self.processing_queue.append(file_path)
            self.process_queue()

    def process_queue(self):
        """Process queued audio files sequentially."""
        if self.is_processing or not self.processing_queue:
            return
        
        self.is_processing = True
        
        while self.processing_queue:
            file_path = self.processing_queue.pop(0)
            
            # Wait for file to be fully written
            wait_time = self.config['processing']['file_write_wait_seconds']
            time.sleep(wait_time)
            if not file_path.exists():
                continue
                
            self.transcribe_file(file_path)
        
        self.is_processing = False
    
    def transcribe_file(self, file_path: Path):
        """Transcribe a single audio file."""
        config = self.config
        processing_folder = Path(config['paths']['processing_folder'])
        archive_folder = Path(config['paths']['archive_folder'])
        failed_folder = Path(config['paths']['failed_folder'])
        output_folder = Path(config['paths']['output_folder'])
        
        # Move to processing
        processing_path = processing_folder / file_path.name
        try:
            shutil.move(str(file_path), str(processing_path))
            logging.info(f"Moved to processing: {file_path.name}")
        except Exception as e:
            logging.error(f"Failed to move file: {e}")
            return
        
        # Get file metadata
        file_stat = processing_path.stat()
        created_time = datetime.fromtimestamp(file_stat.st_mtime)
        
        # Build WSL path
        wsl_path = str(processing_path).replace('\\', '/')
        if wsl_path[1] == ':':
            wsl_path = f"/mnt/{wsl_path[0].lower()}{wsl_path[2:]}"
        
        # Create temp output directory for whisper
        temp_output = processing_folder / config['paths']['whisper_temp_output']
        temp_output.mkdir(exist_ok=True)
        wsl_temp_output = str(temp_output).replace('\\', '/')
        if wsl_temp_output[1] == ':':
            wsl_temp_output = f"/mnt/{wsl_temp_output[0].lower()}{wsl_temp_output[2:]}"
        
        # Build whisper command
        model = config['whisper']['model']
        language = config['whisper']['language']
        venv_path = config['whisper']['venv_path']
        
        output_format = config['whisper']['output_format']
        cmd = [
            "wsl", "-e", "bash", "-c",
            f"source {venv_path}/bin/activate && whisper '{wsl_path}' "
            f"--model {model} --language {language} "
            f"--output_dir '{wsl_temp_output}' --output_format {output_format}"
        ]
        
        logging.info(f"Starting transcription: {file_path.name} (model: {model})")
        start_time = time.time()
        
        timeout = config['whisper']['command_timeout_seconds']
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
            elapsed = time.time() - start_time
            
            if result.returncode != 0:
                raise Exception(f"Whisper error: {result.stderr}")
            
            logging.info(f"Transcription complete in {elapsed:.1f}s")
            
            # Read transcription output
            txt_file = temp_output / f"{processing_path.stem}.txt"
            if not txt_file.exists():
                raise Exception("Transcription output file not found")
            
            transcription = txt_file.read_text(encoding='utf-8').strip()
            
            # Clean up temp files
            txt_file.unlink()
            
            # Generate output markdown
            self.create_obsidian_note(
                transcription=transcription,
                source_file=file_path.name,
                created_time=created_time,
                duration_seconds=elapsed,
                output_folder=output_folder
            )
            
            # Move to archive
            archive_path = archive_folder / file_path.name
            shutil.move(str(processing_path), str(archive_path))
            logging.info(f"Archived: {file_path.name}")
            
            # Notification
            self.notify_success(file_path.name, elapsed)
            
        except Exception as e:
            logging.error(f"Transcription failed: {e}")
            
            # Move to failed
            failed_path = failed_folder / file_path.name
            if processing_path.exists():
                shutil.move(str(processing_path), str(failed_path))
            
            self.notify_failure(file_path.name, str(e))

    def create_obsidian_note(self, transcription: str, source_file: str, 
                            created_time: datetime, duration_seconds: float,
                            output_folder: Path):
        """Create an Obsidian-compatible markdown note."""
        
        # Organize by date if configured
        output_config = self.config['output']
        if self.config['processing']['organize_by_date']:
            year_format = output_config['date_organization']['year_format']
            month_format = output_config['date_organization']['month_format']
            year_folder = output_folder / created_time.strftime(year_format)
            month_folder = year_folder / created_time.strftime(month_format)
            month_folder.mkdir(parents=True, exist_ok=True)
            target_folder = month_folder
        else:
            output_folder.mkdir(parents=True, exist_ok=True)
            target_folder = output_folder
        
        # Generate timestamp-based filename
        timestamp_format = output_config['filename_timestamp_format']
        filename_prefix = output_config['filename_prefix']
        filename_extension = output_config['filename_extension']
        timestamp = created_time.strftime(timestamp_format)
        filename = f"{timestamp}{filename_prefix}{filename_extension}"
        output_path = target_folder / filename
        
        # Handle duplicates
        counter = 1
        duplicate_format = output_config['duplicate_counter_format']
        while output_path.exists():
            filename = f"{timestamp}{duplicate_format.format(counter=counter)}{filename_extension}"
            output_path = target_folder / filename
            counter += 1
        
        # Create markdown content with YAML frontmatter
        output_config = self.config['output']
        frontmatter_format = output_config['frontmatter_datetime_format']
        header_format = output_config['header_datetime_format']
        header_prefix = output_config['header_prefix']
        footer_text = output_config['footer_text']
        default_tags = output_config['default_tags']
        command_type = output_config['command_type']
        
        tags_str = ", ".join(default_tags)
        content = f"""---
created: {created_time.strftime(frontmatter_format)}
source: {source_file}
processing_time: {duration_seconds:.1f}s
model: whisper-{self.config['whisper']['model']}
tags: [{tags_str}]
command_type: {command_type}
---

{header_prefix}{created_time.strftime(header_format)}

{transcription}

---
{footer_text}
"""
        
        output_path.write_text(content, encoding='utf-8')
        logging.info(f"Created note: {output_path}")
    
    def notify_success(self, filename: str, elapsed: float):
        """Send Windows toast notification on success."""
        if not NOTIFICATIONS_AVAILABLE or not self.config['notifications']['on_success']:
            return
        
        try:
            notif_config = self.config['notifications']
            toast = Notification(
                app_id=notif_config['app_id'],
                title=notif_config['success_title'],
                msg=f"{filename}\nProcessed in {elapsed:.1f} seconds",
                duration=notif_config['success_duration']
            )
            toast.set_audio(audio.Default, loop=False)
            toast.show()
        except Exception as e:
            logging.warning(f"Notification failed: {e}")
    
    def notify_failure(self, filename: str, error: str):
        """Send Windows toast notification on failure."""
        if not NOTIFICATIONS_AVAILABLE or not self.config['notifications']['on_failure']:
            return
        
        try:
            notif_config = self.config['notifications']
            toast = Notification(
                app_id=notif_config['app_id'],
                title=notif_config['failure_title'],
                msg=f"{filename}\n{error[:100]}",
                duration=notif_config['failure_duration']
            )
            toast.show()
        except Exception as e:
            logging.warning(f"Notification failed: {e}")


def load_config(config_path: str = None) -> dict:
    """Load configuration from YAML file."""
    if config_path is None:
        config_path = Path(__file__).parent / "config.yaml"
    
    with open(config_path, 'r') as f:
        return yaml.safe_load(f)


def setup_logging(config: dict):
    """Configure logging."""
    log_file = config['logging']['file']
    log_level = getattr(logging, config['logging']['level'].upper())
    
    logging.basicConfig(
        level=log_level,
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.FileHandler(log_file),
            logging.StreamHandler(sys.stdout)
        ]
    )


def main():
    """Main entry point."""
    print("=" * 60)
    print("Voice Transcription Watcher Service")
    print("=" * 60)
    
    # Load config
    config = load_config()
    setup_logging(config)
    
    watch_folder = Path(config['paths']['watch_folder'])
    
    # Ensure folders exist
    for folder_key in ['watch_folder', 'processing_folder', 'archive_folder', 'failed_folder']:
        Path(config['paths'][folder_key]).mkdir(parents=True, exist_ok=True)
    
    logging.info(f"Watching folder: {watch_folder}")
    logging.info(f"Whisper model: {config['whisper']['model']}")
    logging.info(f"Output folder: {config['paths']['output_folder']}")
    logging.info(f"Supported formats: {config['processing']['supported_formats']}")
    
    # Check for existing files in watch folder
    handler = TranscriptionHandler(config)
    
    existing_files = list(watch_folder.glob("*"))
    audio_files = [f for f in existing_files if f.suffix.lower() in handler.supported_formats]
    if audio_files:
        logging.info(f"Found {len(audio_files)} existing audio file(s) to process")
        for f in audio_files:
            handler.processing_queue.append(f)
        handler.process_queue()
    
    # Start watching
    observer = Observer()
    observer.schedule(handler, str(watch_folder), recursive=False)
    observer.start()
    
    logging.info("Watcher started. Press Ctrl+C to stop.")
    
    if NOTIFICATIONS_AVAILABLE and config['notifications']['enabled']:
        notif_config = config['notifications']
        toast = Notification(
            app_id=notif_config['app_id'],
            title=notif_config['startup_title'],
            msg=f"Monitoring: {watch_folder}",
            duration=notif_config['startup_duration']
        )
        toast.show()
    
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logging.info("Shutting down...")
        observer.stop()
    
    observer.join()
    logging.info("Watcher stopped.")


if __name__ == "__main__":
    main()
