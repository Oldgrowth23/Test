# Word to PDF Converter

A web application that converts `.doc` and `.docx` files to PDF using LibreOffice as the conversion engine.

## Requirements

- Python 3.8+
- LibreOffice Writer (`libreoffice-writer`)

### Install system dependency (Debian/Ubuntu)

```bash
sudo apt-get install libreoffice-writer
```

## Setup

```bash
pip install -r requirements.txt
```

## Run

```bash
python app.py
```

Then open [http://localhost:5000](http://localhost:5000) in your browser.

## Features

- Drag-and-drop or click-to-browse file selection
- Supports `.doc` and `.docx` formats
- Max file size: 50 MB
- Converted PDF is downloaded automatically
- Uploaded files are deleted from the server after conversion
