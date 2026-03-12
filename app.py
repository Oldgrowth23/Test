import os
import subprocess
import tempfile
import uuid
from pathlib import Path

from flask import Flask, jsonify, render_template, request, send_file

app = Flask(__name__)
app.config["MAX_CONTENT_LENGTH"] = 50 * 1024 * 1024  # 50 MB limit

ALLOWED_EXTENSIONS = {".doc", ".docx"}
UPLOAD_DIR = Path(tempfile.gettempdir()) / "word2pdf_uploads"
OUTPUT_DIR = Path(tempfile.gettempdir()) / "word2pdf_outputs"
UPLOAD_DIR.mkdir(exist_ok=True)
OUTPUT_DIR.mkdir(exist_ok=True)


def allowed_file(filename: str) -> bool:
    return Path(filename).suffix.lower() in ALLOWED_EXTENSIONS


@app.route("/")
def index():
    return render_template("index.html")


@app.route("/convert", methods=["POST"])
def convert():
    if "file" not in request.files:
        return jsonify({"error": "No file provided"}), 400

    file = request.files["file"]
    if not file.filename:
        return jsonify({"error": "No file selected"}), 400

    if not allowed_file(file.filename):
        return jsonify({"error": "Only .doc and .docx files are supported"}), 400

    # Save uploaded file with a unique name to avoid conflicts
    suffix = Path(file.filename).suffix.lower()
    unique_name = f"{uuid.uuid4().hex}{suffix}"
    input_path = UPLOAD_DIR / unique_name

    try:
        file.save(input_path)

        # Run LibreOffice headless conversion
        result = subprocess.run(
            [
                "libreoffice",
                "--headless",
                "--convert-to",
                "pdf",
                "--outdir",
                str(OUTPUT_DIR),
                str(input_path),
            ],
            capture_output=True,
            text=True,
            timeout=60,
        )

        if result.returncode != 0:
            return jsonify({"error": f"Conversion failed: {result.stderr.strip()}"}), 500

        output_filename = Path(unique_name).stem + ".pdf"
        output_path = OUTPUT_DIR / output_filename

        if not output_path.exists():
            return jsonify({"error": "Conversion produced no output file"}), 500

        # Use the original filename for the download
        download_name = Path(file.filename).stem + ".pdf"

        return send_file(
            output_path,
            mimetype="application/pdf",
            as_attachment=True,
            download_name=download_name,
        )

    except subprocess.TimeoutExpired:
        return jsonify({"error": "Conversion timed out (file may be too large)"}), 500
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        # Clean up uploaded file
        if input_path.exists():
            input_path.unlink()


if __name__ == "__main__":
    app.run(debug=True, host="0.0.0.0", port=5000)
