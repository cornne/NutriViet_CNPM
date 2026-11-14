"""
PythonAnywhere WSGI configuration template for NutriViet Backend (`v2.0.0`).
Copy these contents into your PythonAnywhere Web tab WSGI file, e.g.:
  /var/www/ngobinh2006_pythonanywhere_com_wsgi.py
"""

import os
import sys

BACKEND_PATH = "/home/ngobinh2006/NutriViet_CNPM/src/backend"
if BACKEND_PATH not in sys.path:
    sys.path.insert(0, BACKEND_PATH)

# Recommended: set SMTP & DB path via PythonAnywhere WSGI env or `.env` in `src/backend/`:
# os.environ["NUTRIVIET_GMAIL_USER"] = "your-sender@gmail.com"
# os.environ["NUTRIVIET_GMAIL_PASS"] = "your-16-char-app-password"
# os.environ["NUTRIVIET_DB_PATH"] = "/home/ngobinh2006/NutriViet_CNPM/src/backend/nutriviet.db"
# os.environ["NUTRIVIET_PUBLIC_BASE_URL"] = "https://ngobinh2006.pythonanywhere.com"

from wsgi_app import application  # noqa: E402,F401

