# CLAUDE.md - ACR1252 NFC GUI Project

## Project Overview

This is a PyQt5-based desktop application for reading and writing NFC tags using the ACS ACR1252U USB NFC Reader on Linux systems. The application provides a graphical interface for managing NDEF-formatted NFC tags, with support for URL reading/writing and batch operations.

## Core Functionality

**Read Mode:**
- Continuous NFC tag scanning
- Automatic URL extraction from NDEF records
- Browser integration (auto-opens URLs)
- Clipboard integration

**Write Mode:**
- URL writing to NFC tags with NDEF formatting
- Batch writing capability (multiple tags with same URL)
- Optional permanent tag locking
- Overwrite protection

## Technical Architecture

**Technology Stack:**
- Python 3.8+
- PyQt5 (GUI framework)
- pyscard (PC/SC smartcard library interface)
- ndeflib (NDEF message encoding/decoding)
- pyperclip (clipboard operations)

**Project Structure:**
- `nfc_gui/gui.py` - PyQt5 GUI implementation with material design styling
- `nfc_gui/nfc_handler.py` - Core NFC operations (reader communication, NDEF operations)
- `run-gui.sh` - Launch script with automated venv setup
- `build.sh` - Build/deployment script

## Hardware Requirements

**Required:**
- ACS ACR1252U USB NFC Reader/Writer
- Linux system with USB support
- PC/SC daemon (pcscd)

**Validated Tags:**
- NXP NTAG213 (recommended, ~144 bytes NDEF capacity)
- NTAG215/216 (compatible)

## Setup and Running

The project uses a virtual environment approach. The `run-gui.sh` script handles:
1. Virtual environment creation (`.venv` directory)
2. Dependency installation from `requirements.txt`
3. Application launch

Manual setup:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python -m nfc_gui.gui
```

## System Requirements

**Permissions:**
- User must be in `scard` group for PC/SC access
- USB device access for ACR1252U reader

**Services:**
- pcscd daemon must be running

## Development Context

This project builds upon VladoPortos's ACR1252 implementation, adding a modern GUI layer and extended functionality for URL management and batch operations.

## Key Features Implementation

**Safety Mechanisms:**
- Overwrite protection (default: disabled, requires explicit enable)
- Tag locking warnings (irreversible operation)
- Batch write confirmation

**User Experience:**
- Real-time activity logging with timestamps
- Clipboard integration for URL operations
- Browser auto-launch for read URLs
- Material design inspired interface

## Working with This Repository

When modifying this project:
1. NFC operations are handled in `nfc_handler.py` - PC/SC communication, NDEF formatting
2. GUI logic is in `gui.py` - PyQt5 widgets, event handlers, UI state management
3. Test with actual hardware (ACR1252U + NTAG213 tags recommended)
4. Consider tag locking operations carefully (irreversible)

## Dependencies Management

Dependencies are specified in `requirements.txt`:
- PyQt5 (GUI)
- pyscard (hardware interface)
- ndeflib (NDEF protocol)
- pyperclip (clipboard)

The virtual environment approach ensures isolated dependencies without system Python pollution.
