"""
Local EasyOCR server for CIN and driving license document scanning.
Run: python server.py
Default: http://127.0.0.1:8765
"""
import base64
import io
import os

from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)

# Lazy-load EasyOCR on first request to speed up startup
_reader = None

def get_reader():
    global _reader
    if _reader is None:
        import easyocr
        _reader = easyocr.Reader(["fr", "en", "ar"], gpu=False)
    return _reader


@app.route("/health", methods=["GET"])
def health():
    """Health check for Flutter app to detect server status."""
    return jsonify({"status": "ok"})


@app.route("/ocr", methods=["POST"])
def ocr():
    """
    Expects multipart/form-data with key 'file' (image) or 'image' (base64).
    Accepts JPG, PNG.
    Returns {"text": "extracted text"} or {"error": "..."}.
    """
    try:
        image_bytes = None
        if "file" in request.files:
            f = request.files["file"]
            if f.filename:
                image_bytes = f.read()
        if image_bytes is None and "image" in request.form:
            image_bytes = base64.b64decode(request.form["image"])
        if not image_bytes:
            return jsonify({"error": "No file or image provided"}), 400

        reader = get_reader()
        # EasyOCR expects image as numpy array or path; from bytes use PIL
        import numpy as np
        from PIL import Image
        img = Image.open(io.BytesIO(image_bytes))
        img = img.convert("RGB")
        arr = np.array(img)
        result = reader.readtext(arr)
        text = " ".join([item[1] for item in result])
        return jsonify({"text": text or ""})
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    port = int(os.environ.get("OCR_SERVER_PORT", 8765))
    app.run(host="0.0.0.0", port=port, debug=False)
